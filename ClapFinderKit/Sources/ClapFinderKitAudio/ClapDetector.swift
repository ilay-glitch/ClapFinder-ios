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
    /// Fixed loudness floor (dBFS) — only rejects near-silence (where crest is
    /// meaningless). Far above this, the crest factor decides. NOT a loudness
    /// gate for distance: a far clap (~−50 dBFS) is well above this floor.
    public let dBFloor: Float = -55.0

    // MARK: - Private — AVFoundation (non-Sendable, main-actor access only)

    // `nonisolated(unsafe)` lets Swift 6 compile without errors.
    // All accesses to `engine` happen on the main actor (start / stop), so
    // there is no real data race — the annotation opts out of the compiler check.
    nonisolated(unsafe) private let engine = AVAudioEngine()

    // MARK: - Private — detection state

    private var firstClapTime: Date?
    /// `true` once the signal has dropped below threshold after the first clap.
    /// A second clap only counts after such a "release" — so one sustained
    /// sound (speech, the engine-start transient) can't fake a double-clap.
    private var releasedSinceFirstClap = false
    private var inCooldown = false
    private var currentCrestThreshold: Float = Sensitivity.medium.clapCrestThreshold
    /// Retained so we can cancel notification observers when the detector stops.
    /// Both tasks are cancelled in `tearDown()` (called by `stop()`).
    private var interruptionTask: Task<Void, Never>?
    private var routeChangeTask: Task<Void, Never>?

    // MARK: - Logging

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "ClapDetector"
    )

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Activates the microphone and starts clap detection.
    ///
    /// - Parameter sensitivity: Detection sensitivity (default `.medium`).
    /// - Throws: `ClapDetectorError` if the audio session or engine cannot start.
    public func start(sensitivity: Sensitivity = .medium) throws {
        guard !isListening else { return }

        currentCrestThreshold = sensitivity.clapCrestThreshold
        Self.logger.debug("Starting — min crest \(sensitivity.clapCrestThreshold), floor \(self.dBFloor) dBFS")

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

        isListening = true
        Self.logger.info("Listening started")
    }

    /// Stops the engine and tears down the input tap.
    public func stop() {
        guard isListening else { return }
        tearDown()
        Self.logger.info("Listening stopped")
    }

    // MARK: - Private — setup / teardown

    private func installTap() {
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        // The tap block runs on a real-time AUDIO thread — must be `@Sendable`
        // (nonisolated) or Swift 6 traps with `_dispatch_assert_queue_fail`.
        // We compute energy (dBFS) + crest factor (peak ÷ RMS) here — both
        // nonisolated static work — then hop to the main actor with the result.
        let onBuffer: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { [weak self] buffer, _ in
            let rms = ClapDetector.rmsAmplitude(buffer: buffer)
            let peak = ClapDetector.peakAmplitude(buffer: buffer)
            let dBFS = 20.0 * log10(max(rms, Float(1e-10)))
            let crest = peak / max(rms, Float(1e-10))
            Task { @MainActor in
                self?.processSample(dBFS: dBFS, crest: crest)
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
    /// A clap "peak" is a buffer that is both **loud** (dBFS > threshold) and
    /// **impulsive** (crest factor > `minCrestFactor`). The impulsive test is
    /// the clap-vs-noise discriminator: a clap is a sharp spike (high crest),
    /// while speech / sustained sounds are flatter (low crest) and are ignored
    /// even when loud.
    ///
    /// A double-clap requires two *separate* clap peaks: after the first, the
    /// signal must drop below threshold (a "release") and at least
    /// `minClapGapSeconds` must pass before the second counts.
    /// `crest` defaults to a clearly-impulsive value so gesture unit tests
    /// (which exercise timing, not the impulse gate) can omit it.
    func processSample(dBFS: Float, crest: Float = 100, at now: Date = Date()) {
        guard isListening, !inCooldown else { return }

        // A clap peak = above the silence floor AND impulsive (sharp crest).
        // Loudness is NOT the discriminator (it falls off with distance);
        // crest is. Anything that isn't a peak — quiet OR loud-but-flat
        // (speech, sustained noise) — counts as the "release" gap between claps.
        let isPeak = dBFS > dBFloor && crest > currentCrestThreshold
        guard isPeak else {
            if firstClapTime != nil {
                releasedSinceFirstClap = true
            }
            return
        }

        // A clap peak from here on.
        guard let first = firstClapTime else {
            Self.logger.debug("First clap (crest \(crest, format: .fixed(precision: 1)))")
            firstClapTime = now
            releasedSinceFirstClap = false
            return
        }

        let delta = now.timeIntervalSince(first)

        // Stale window — restart with this sample as a fresh first clap.
        guard delta <= clapWindowSeconds else {
            firstClapTime = now
            releasedSinceFirstClap = false
            return
        }

        // Same continuous sound, or claps too close together — not a real pair.
        guard releasedSinceFirstClap, delta >= minClapGapSeconds else {
            return
        }

        // ✅ Genuine second clap.
        Self.logger.debug("Double-clap detected (Δt \(delta, format: .fixed(precision: 3))s)")
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
        interruptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.observeInterruptions()
        }
        routeChangeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.observeRouteChanges()
        }
    }

    private func observeInterruptions() async {
        let notifications = NotificationCenter.default.notifications(
            named: AVAudioSession.interruptionNotification
        )
        for await notification in notifications {
            guard !Task.isCancelled else { return }
            handleInterruption(notification)
        }
    }

    private func observeRouteChanges() async {
        let notifications = NotificationCenter.default.notifications(
            named: AVAudioSession.routeChangeNotification
        )
        for await notification in notifications {
            guard !Task.isCancelled else { return }
            handleRouteChange(notification)
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
            Self.logger.info("Audio session interrupted — pausing engine")
            // Pause the engine without fully tearing down (keeps isListening true
            // so we know we should resume when the interruption ends).
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
    }

    // MARK: - Static DSP helpers

    /// Computes the root-mean-square amplitude of channel 0 in `buffer`.
    ///
    /// Uses `vDSP_measqv` (mean square) so only one `sqrt` is needed.
    /// Returns 0 when the buffer is empty or has no float data.
    nonisolated static func rmsAmplitude(buffer: AVAudioPCMBuffer) -> Float {
        guard
            let data = buffer.floatChannelData,
            buffer.frameLength > 0
        else { return 0 }

        var meanSquare: Float = 0
        vDSP_measqv(data[0], 1, &meanSquare, vDSP_Length(buffer.frameLength))
        return sqrt(meanSquare)
    }

    /// Peak absolute amplitude of channel 0 in `buffer` (for crest factor).
    /// Returns 0 when the buffer is empty or has no float data.
    nonisolated static func peakAmplitude(buffer: AVAudioPCMBuffer) -> Float {
        guard
            let data = buffer.floatChannelData,
            buffer.frameLength > 0
        else { return 0 }

        var peak: Float = 0
        vDSP_maxmgv(data[0], 1, &peak, vDSP_Length(buffer.frameLength))
        return peak
    }
}
