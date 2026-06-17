import Accelerate
import AVFoundation
import ClapFinderKitData
import Observation
import OSLog

// MARK: - ClapDetector

/// Detects a double-clap using the device microphone.
///
/// A 1024-sample input tap (~23 ms) yields per-buffer energy (dBFS) and crest
/// factor (peak ÷ RMS). A clap "peak" is loud (dBFS > threshold) AND impulsive
/// (crest > `minCrestFactor`); two such peaks, separated by a release and
/// `minClapGapSeconds`, within `clapWindowSeconds` fire `onClapDetected`, then
/// a `cooldownSeconds` lockout prevents duplicates. The crest test is what
/// distinguishes a clap from loud-but-flat sounds (speech, sustained noise).
///
/// Background: requires `UIBackgroundModes = ["audio"]`; auto-stops/restarts
/// around AVAudioSession interruptions via async notification streams.
/// Concurrency: all public API + `@Observable` state are `@MainActor`; the tap
/// runs on the audio thread and hops to the main actor per buffer.
@Observable
@MainActor
public final class ClapDetector {

    // MARK: - Public state

    /// `true` while the engine is running and actively sampling the microphone.
    public private(set) var isListening = false

    // MARK: - Configuration

    /// Called on the main actor every time a double-clap is detected.
    public var onClapDetected: (@MainActor @Sendable () -> Void)?

    // MARK: - Constants

    /// Two peaks must occur within this window (seconds) to count as a double-clap.
    public let clapWindowSeconds: TimeInterval = 0.5
    /// The two claps must be at least this far apart (seconds). Rejects two
    /// consecutive buffers of one continuous sound being read as a double-clap.
    public let minClapGapSeconds: TimeInterval = 0.08
    /// After a double-clap fires, detection is suppressed for this long (seconds).
    public let cooldownSeconds: TimeInterval = 1.0
    /// Loudness floor (dBFS) — only rejects near-silence (where crest is
    /// meaningless); above it, crest decides. A far clap (~−50 dBFS) clears it.
    public let dBFloor: Float = -55.0

    // MARK: - Private — AVFoundation (non-Sendable, main-actor access only)

    // All `engine` access is on the main actor, so `nonisolated(unsafe)` (which
    // opts out of the Swift 6 check) is safe here.
    nonisolated(unsafe) private let engine = AVAudioEngine()

    // MARK: - Private — detection state

    private var firstClapTime: Date?
    /// `true` once a non-peak follows the first clap. A second clap only counts
    /// after such a "release", so one sustained sound can't fake a double-clap.
    private var releasedSinceFirstClap = false
    private var inCooldown = false
    private var currentCrestThreshold: Float = Sensitivity.medium.clapCrestThreshold
    /// When set, the tap forwards each above-floor buffer's crest here instead
    /// of running detection — used by calibration capture.
    private var calibrationHandler: (@MainActor (Float) -> Void)?
    /// Notification observers, cancelled in `tearDown()`.
    private var interruptionTask: Task<Void, Never>?
    private var routeChangeTask: Task<Void, Never>?

#if DEBUG
    /// Measure-first instrumentation (CLAP_DIAGNOSTICS.md). DEBUG-only; absent
    /// from Release. Observes the decision path, never alters it. The `diag(_:)`
    /// emit helper + test hook live in `ClapDetector+Diagnostics.swift`.
    let diagnostics = ClapDiagnostics.Session()
#endif

    // MARK: - Logging

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "ClapDetector"
    )

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Activates the microphone and starts clap detection. `crestOverride` (from
    /// calibration), when non-nil, replaces the sensitivity-derived crest threshold.
    /// - Throws: `ClapDetectorError` if the audio session or engine cannot start.
    public func start(sensitivity: Sensitivity = .medium, crestOverride: Float? = nil) throws {
        guard !isListening else { return }

        currentCrestThreshold = crestOverride ?? sensitivity.clapCrestThreshold
        let calibrated = crestOverride != nil
        Self.logger.debug("Starting — min crest \(self.currentCrestThreshold) (calibrated: \(calibrated))")
#if DEBUG
        diagnostics.configure(threshold: currentCrestThreshold, calibrated: calibrated, sensitivity: sensitivity)
#endif

        try activateEngine()
        isListening = true
        Self.logger.info("Listening started")
    }

    /// Stops the engine and tears down the input tap.
    public func stop() {
        guard isListening else { return }
        tearDown()
        Self.logger.info("Listening stopped")
    }

    // MARK: - Calibration capture

    /// Starts the mic and forwards each above-floor buffer's crest to `onCrest`
    /// (no detection) to learn the user's clap. Call `stopCalibration()` when done.
    public func startCalibration(onCrest: @escaping @MainActor (Float) -> Void) throws {
        guard !isListening && calibrationHandler == nil else { return }
        calibrationHandler = onCrest
        do {
            try activateEngine()
        } catch {
            calibrationHandler = nil
            throw error
        }
        Self.logger.info("Calibration capture started")
    }

    public func stopCalibration() {
        guard calibrationHandler != nil else { return }
        calibrationHandler = nil
        tearDown()
        Self.logger.info("Calibration capture stopped")
    }

    // MARK: - Private — engine bring-up

    private func activateEngine() throws {
#if os(iOS)
        do {
            try configureAudioSession()
        } catch {
            throw ClapDetectorError.audioSessionConfigFailed(underlying: error)
        }
        startNotificationObservers()
#endif

        installTap()

        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            interruptionTask?.cancel()
            throw ClapDetectorError.engineStartFailed(underlying: error)
        }
    }

    // MARK: - Private — setup / teardown

    private func installTap() {
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        // The tap block runs on a real-time AUDIO thread — must be `@Sendable`
        // or Swift 6 traps. Compute dBFS + crest (nonisolated static), then hop
        // to the main actor with the result.
        let onBuffer: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { [weak self] buffer, _ in
            let rms = ClapDSP.rmsAmplitude(buffer: buffer)
            let peak = ClapDSP.peakAmplitude(buffer: buffer)
            let dBFS = 20.0 * log10(max(rms, Float(1e-10)))
            let crest = peak / max(rms, Float(1e-10))
#if DEBUG
            // Sample-resolution transient shape for diagnostics (no effect on
            // the decision path). Computed here so the audio thread does the
            // one scan; the result rides along to the main actor below.
            let shape = ClapDiagnostics.transientShape(buffer: buffer)
#endif
            Task { @MainActor in
                guard let self else { return }
                if let capture = self.calibrationHandler {
                    if dBFS > self.dBFloor { capture(crest) }
                } else {
#if DEBUG
                    self.diagnostics.stage(rms: rms, peak: peak, shape: shape)
#endif
                    self.processSample(dBFS: dBFS, crest: crest)
                }
            }
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: onBuffer)
    }

    private func tearDown() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        interruptionTask?.cancel()
        interruptionTask = nil
        routeChangeTask?.cancel()
        routeChangeTask = nil
        reset()
        isListening = false
    }

    // MARK: - Core detection state machine

    /// Core detection state machine — must be called on the main actor.
    ///
    /// A clap "peak" is a buffer above the silence floor AND impulsive (crest >
    /// threshold). Crest — not loudness, which falls off with distance — is the
    /// clap-vs-noise discriminator: claps spike, speech/sustained sounds are flat.
    /// A double-clap needs two *separate* peaks: after the first, the signal must
    /// drop to a non-peak ("release") and at least `minClapGapSeconds` must pass.
    /// `crest` defaults high so timing-only unit tests can omit it.
    func processSample(dBFS: Float, crest: Float = 100, at now: Date = Date()) {
        guard isListening, !inCooldown else { return }

        let isPeak = dBFS > dBFloor && crest > currentCrestThreshold
        guard isPeak else {
            if firstClapTime != nil {
                releasedSinceFirstClap = true
            }
            if dBFS > dBFloor { diag(.lowCrest, dBFS, crest) }
            return
        }

        // A clap peak from here on.
        guard let first = firstClapTime else {
            Self.logger.debug("First clap (crest \(crest, format: .fixed(precision: 1)))")
            firstClapTime = now
            releasedSinceFirstClap = false
            diag(.firstClap, dBFS, crest)
            return
        }

        let delta = now.timeIntervalSince(first)

        // Stale window — restart with this sample as a fresh first clap.
        guard delta <= clapWindowSeconds else {
            firstClapTime = now
            releasedSinceFirstClap = false
            diag(.staleWindow, dBFS, crest, dtMs: delta * 1000)
            return
        }

        // Same continuous sound, or claps too close together — not a real pair.
        guard releasedSinceFirstClap, delta >= minClapGapSeconds else {
            diag(releasedSinceFirstClap ? .tooClose : .noRelease, dBFS, crest, dtMs: delta * 1000)
            return
        }

        // ✅ Genuine second clap.
        Self.logger.debug("Double-clap detected (Δt \(delta, format: .fixed(precision: 3))s)")
        diag(.accept, dBFS, crest, dtMs: delta * 1000)
        reset()
        inCooldown = true
        onClapDetected?()

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.cooldownSeconds))
            self.inCooldown = false
        }
    }

    private func reset() {
        firstClapTime = nil
        releasedSinceFirstClap = false
    }

#if os(iOS)
    // MARK: - AVAudioSession configuration

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker]
        )
        try session.setActive(true)
    }

    // MARK: - Notification observers

    /// Subscribes to AVAudioSession interruption and route-change notifications
    /// using Swift Concurrency async streams (no @objc needed, Swift 6 safe).
    private func startNotificationObservers() {
        interruptionTask?.cancel()
        interruptionTask = observe(AVAudioSession.interruptionNotification) { [weak self] in
            self?.handleInterruption($0)
        }
        routeChangeTask = observe(AVAudioSession.routeChangeNotification) { [weak self] in
            self?.handleRouteChange($0)
        }
    }

    private func observe(
        _ name: Notification.Name,
        _ handle: @escaping @MainActor (Notification) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            for await notification in NotificationCenter.default.notifications(named: name) {
                guard !Task.isCancelled else { return }
                handle(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch interruptionType {
        case .began:
            // Pause without tearing down (keep isListening true to resume later).
            Self.logger.info("Audio session interrupted — pausing engine")
            engine.pause()
            reset()

        case .ended:
            guard
                let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
                AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            else {
                Self.logger.info("Interruption ended — shouldResume not set, stopping")
                tearDown()
                return
            }
            Self.logger.info("Interruption ended — resuming engine")
            resumeAfterInterruption()

        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        switch reason {
        case .oldDeviceUnavailable:
            // e.g. Bluetooth headset disconnected; engine may stall — restart tap
            Self.logger.info("Audio route changed (old device unavailable) — restarting tap")
            restartTap()
        default:
            break
        }
    }

    private func resumeAfterInterruption() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            Self.logger.info("Engine resumed after interruption")
        } catch {
            Self.logger.error("Failed to resume after interruption: \(error)")
            tearDown()
        }
    }

    private func restartTap() {
        engine.inputNode.removeTap(onBus: 0)
        installTap()
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                Self.logger.error("Failed to restart engine after route change: \(error)")
                tearDown()
            }
        }
    }
#endif

    // MARK: - Testing support

    /// ⚠️ TEST-ONLY. Sets `isListening` and the crest threshold directly
    /// without starting the AVAudioEngine. SPI-gated: callers must use
    /// `@_spi(Testing) import ClapFinderKitAudio`.
    @_spi(Testing)
    public func setListeningForTesting(_ listening: Bool, sensitivity: Sensitivity) {
        isListening = listening
        currentCrestThreshold = sensitivity.clapCrestThreshold
#if DEBUG
        diagnostics.configure(threshold: currentCrestThreshold, calibrated: false, sensitivity: sensitivity)
#endif
    }

}
