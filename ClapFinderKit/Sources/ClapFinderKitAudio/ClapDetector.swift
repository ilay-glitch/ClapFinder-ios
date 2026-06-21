import Accelerate
import AVFoundation
import ClapFinderKitData
import Observation
import OSLog

// MARK: - ClapDetector

/// Detects a double-clap using the device microphone.
///
/// A 1024-sample tap yields per-buffer energy (dBFS) + crest (peak ÷ RMS). A
/// clap peak is loud AND impulsive (crest > threshold), then confirmed by a
/// reject-only spectral stage that vetoes knocks/speech
/// (SOUND_RECOGNITION_DESIGN.md v3). Two confirmed peaks — a release and
/// `minClapGapSeconds` apart, within `clapWindowSeconds` — fire `onClapDetected`,
/// then a `cooldownSeconds` lockout. Requires `UIBackgroundModes = ["audio"]`.
/// Concurrency: public API + `@Observable` state are `@MainActor`; the tap runs
/// on the audio thread and hops to the main actor per buffer.
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
    /// The two claps must be at least this far apart (seconds), rejecting one
    /// continuous sound read across consecutive buffers as a double-clap.
    public let minClapGapSeconds: TimeInterval = 0.08
    /// After a double-clap fires, detection is suppressed for this long (seconds).
    public let cooldownSeconds: TimeInterval = 1.0
    /// Loudness floor (dBFS) — rejects only near-silence; above it crest decides.
    public let dBFloor: Float = -55.0

    // MARK: - Private — AVFoundation (non-Sendable, main-actor access only)

    // All `engine` access is on the main actor → `nonisolated(unsafe)` is safe.
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

    /// Stage-2 spectral confirm (v3). Immutable after init → audio-tap safe.
    private let spectralAnalyzer = ClapSpectralAnalyzer()
    /// `false` on Bluetooth/non-built-in mics → crest-only fallback (§11).
    var routeAllowsSpectral = true

#if DEBUG
    /// Measure-first instrumentation (CLAP_DIAGNOSTICS.md). DEBUG-only, additive.
    /// Emit helper + test hook live in `ClapDetector+Diagnostics.swift`.
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
        updateSpectralRouteEligibility()
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

    /// Forwards each above-floor buffer's crest to `onCrest` (no detection) to
    /// learn the user's clap. Call `stopCalibration()` when done.
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

        // The tap runs on a real-time AUDIO thread — must be `@Sendable`. Compute
        // features here, then hop to the main actor with the results.
        let analyzer = spectralAnalyzer
        let onBuffer: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { [weak self] buffer, _ in
            let rms = ClapDSP.rmsAmplitude(buffer: buffer)
            let peak = ClapDSP.peakAmplitude(buffer: buffer)
            let dBFS = 20.0 * log10(max(rms, Float(1e-10)))
            let crest = peak / max(rms, Float(1e-10))
            // Stage-2 features only when impulsive (rare); −1 = not measured.
            let (hfr, sfm): (Float, Float) = crest > ClapSpectral.preCheckCrest
                ? analyzer.features(buffer: buffer) : (-1, -1)
#if DEBUG
            // Sample-resolution transient shape for diagnostics (no decision effect).
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
                    self.processSample(dBFS: dBFS, crest: crest, hfr: hfr, sfm: sfm)
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

    /// Core detection state machine — main actor only. A peak is loud + impulsive
    /// (crest > threshold) then spectrally confirmed; two peaks with a release and
    /// `minClapGapSeconds` gap within `clapWindowSeconds` fire. `crest`/`hfr`/`sfm`
    /// default clap-like so timing-only tests can omit them (confirm passes through).
    func processSample(dBFS: Float, crest: Float = 100, hfr: Float = 1, sfm: Float = 1, at now: Date = Date()) {
        guard isListening, !inCooldown else { return }

        let isPeak = dBFS > dBFloor && crest > currentCrestThreshold
        // Stage 2 (additive, reject-only): confirm the crest peak isn't knock/speech.
        let confirmed = ClapSpectral.confirm(
            crestPeak: isPeak, hfr: hfr, sfm: sfm, routeAllowsSpectral: routeAllowsSpectral
        )
        guard confirmed else {
            if firstClapTime != nil {
                releasedSinceFirstClap = true
            }
            if dBFS > dBFloor { diag(isPeak ? .spectralVeto : .lowCrest, dBFS, crest, hfr: hfr, sfm: sfm) }
            return
        }

        guard let first = firstClapTime else {
            Self.logger.debug("First clap (crest \(crest, format: .fixed(precision: 1)))")
            firstClapTime = now
            releasedSinceFirstClap = false
            diag(.firstClap, dBFS, crest, hfr: hfr, sfm: sfm)
            return
        }

        let delta = now.timeIntervalSince(first)

        // Stale window — restart with this sample as a fresh first clap.
        guard delta <= clapWindowSeconds else {
            firstClapTime = now
            releasedSinceFirstClap = false
            diag(.staleWindow, dBFS, crest, hfr: hfr, sfm: sfm, dtMs: delta * 1000)
            return
        }

        // Same continuous sound, or claps too close together — not a real pair.
        guard releasedSinceFirstClap, delta >= minClapGapSeconds else {
            diag(releasedSinceFirstClap ? .tooClose : .noRelease, dBFS, crest, hfr: hfr, sfm: sfm, dtMs: delta * 1000)
            return
        }

        // ✅ Genuine second clap.
        Self.logger.debug("Double-clap detected (Δt \(delta, format: .fixed(precision: 3))s)")
        diag(.accept, dBFS, crest, hfr: hfr, sfm: sfm, dtMs: delta * 1000)
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

        updateSpectralRouteEligibility()   // built-in ↔ BT may have swapped

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
