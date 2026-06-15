import Accelerate
import AVFoundation
import ClapFinderKitData
import Observation
import OSLog

// MARK: - ClapDetector

/// Detects a double-clap using the device microphone.
///
/// ## Algorithm
/// 1. A 1024-sample input tap fires ~23ms callbacks (44 100 Hz).
/// 2. Each buffer is reduced to an RMS value, then converted to dBFS:
///    `dBFS = 20 × log10(rms)`.
/// 3. If `dBFS > threshold`, a "peak" is registered.
/// 4. Two peaks within `clapWindowSeconds` (0.5 s) trigger `onClapDetected`.
/// 5. A `cooldownSeconds` (1.0 s) lockout prevents duplicate fires.
///
/// ## Background operation
/// Requires `UIBackgroundModes = ["audio"]` in `Info.plist`. When that key is
/// present the engine keeps running with the screen off or the app backgrounded.
/// The detector automatically stops and restarts around AVAudioSession
/// interruptions (phone calls, Siri) using async notification streams.
///
/// ## Usage
/// ```swift
/// let detector = ClapDetector()
/// detector.onClapDetected = { … }
/// try detector.start(sensitivity: .medium)
/// // … later …
/// detector.stop()
/// ```
///
/// ## Concurrency
/// All public methods and `@Observable` properties are `@MainActor`.
/// AVAudioEngine callbacks are bridged to `@MainActor` via `Task { @MainActor in }`.
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

    // MARK: - Private — AVFoundation (non-Sendable, main-actor access only)

    // `nonisolated(unsafe)` lets Swift 6 compile without errors.
    // All accesses to `engine` happen on the main actor (start / stop), so
    // there is no real data race — the annotation opts out of the compiler check.
    nonisolated(unsafe) private let engine = AVAudioEngine()

    /// On-device clap recognition (SoundAnalysis). Supplies the confidence
    /// stream that feeds the gesture machine (SOUND_RECOGNITION_DESIGN.md).
    private let classifier = ClapClassifier()

    // MARK: - Private — detection state

    private var firstClapTime: Date?
    /// `true` once the signal has dropped below threshold after the first clap.
    /// A second clap only counts after such a "release" — so one sustained
    /// sound (speech, the engine-start transient) can't fake a double-clap.
    private var releasedSinceFirstClap = false
    private var inCooldown = false
    private var currentThreshold: Float = Sensitivity.medium.threshold
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

        // Clap mode now thresholds classifier confidence, not energy.
        currentThreshold = Float(sensitivity.clapConfidenceThreshold)
        Self.logger.debug("Starting — clap confidence threshold \(sensitivity.clapConfidenceThreshold)")

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

        // Start the classifier and route its confidence stream into the
        // gesture machine. onClap already hops to the main actor.
        classifier.start(format: format)
        classifier.onClap = { [weak self] confidence, when in
            self?.processSample(dBFS: Float(confidence), at: when)
        }

        // The tap block runs on a real-time AUDIO thread — must be `@Sendable`
        // (nonisolated) or Swift 6 traps with `_dispatch_assert_queue_fail`.
        // It only forwards buffers to the classifier (a nonisolated call).
        let classifier = self.classifier
        let onBuffer: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, when in
            classifier.analyze(buffer, at: when)
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: onBuffer)
    }

    private func tearDown() {
        classifier.onClap = nil
        classifier.stop()
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
    /// A double-clap requires two *separate* transients: after the first clap
    /// the signal must drop below threshold (a "release") and at least
    /// `minClapGapSeconds` must pass before a second above-threshold sample
    /// counts. Without this, two consecutive ~23 ms buffers of one continuous
    /// sound — speech, ambient noise, the engine-start pop — were read as a
    /// double-clap and fired the instant listening began.
    func processSample(dBFS: Float, at now: Date = Date()) {
        guard isListening, !inCooldown else { return }

        // Below threshold: this is the gap between claps. Mark the release.
        guard dBFS > currentThreshold else {
            if firstClapTime != nil {
                releasedSinceFirstClap = true
            }
            return
        }

        // Above threshold from here on.
        guard let first = firstClapTime else {
            // First clap of a potential pair.
            Self.logger.debug("First clap registered (dBFS \(dBFS, format: .fixed(precision: 1)))")
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

    /// ⚠️ TEST-ONLY. Sets `isListening` and `currentThreshold` directly
    /// without starting the AVAudioEngine. SPI-gated: callers must use
    /// `@_spi(Testing) import ClapFinderKitAudio`.
    @_spi(Testing)
    public func setListeningForTesting(_ listening: Bool, sensitivity: Sensitivity) {
        isListening = listening
        currentThreshold = sensitivity.threshold
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
}
