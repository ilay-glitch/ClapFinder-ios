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
    nonisolated(unsafe) let engine = AVAudioEngine()   // internal: +AudioSession ext

    // MARK: - Private — detection state

    private var firstClapTime: Date?
    /// `true` once a non-peak follows the first clap. A second clap only counts
    /// after such a "release", so one sustained sound can't fake a double-clap.
    private var releasedSinceFirstClap = false
    private var inCooldown = false
    private var currentCrestThreshold: Float = Sensitivity.medium.clapCrestThreshold
    /// When set, the tap forwards each above-floor buffer's crest here instead
    /// of running detection — used by calibration capture.
    var calibrationHandler: (@MainActor (Float) -> Void)?   // internal: +Calibration ext
    /// Notification observers, cancelled in `tearDown()`.
    var interruptionTask: Task<Void, Never>?   // internal: +AudioSession ext
    var routeChangeTask: Task<Void, Never>?

    /// Stage-2 spectral confirm (v3). Immutable after init → audio-tap safe.
    private let spectralAnalyzer = ClapSpectralAnalyzer()
    /// Hard feed gate (set by ResponseCoordinator): while true, buffers are
    /// dropped before the FSM — playback + tail can't seed or pair anything.
    var feedGate: (@MainActor () -> Bool)?
    /// Engine-start moment; buffers in the first `startTransientGrace` are
    /// dropped (the tap start-up transient was seeding firstClap at t≈0.3–1.0).
    private var engineStartedAt = Date.distantPast
    /// Grace after engine start during which all buffers are dropped.
    public let startTransientGrace: TimeInterval = 1.0
    /// Veto master switch — OFF until thresholds are tuned (then flip true).
    var spectralVetoEnabled = false
    /// `false` on Bluetooth/non-built-in mics → crest-only fallback (§11).
    var routeAllowsSpectral = true

#if DEBUG
    /// Measure-first instrumentation (CLAP_DIAGNOSTICS.md), DEBUG-only/additive.
    let diagnostics = ClapDiagnostics.Session()
    /// SoundAnalysis experiment probe — logs alongside crest, never gates
    /// (SOUND_ANALYSIS_INVESTIGATION.md §5). DEBUG-only.
    let snProbe = ClapClassifierProbe()
#endif

    // MARK: - Logging

    nonisolated static let logger = Logger(   // internal: extensions log too
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
        engineStartedAt = Date()
        isListening = true
        Self.logger.info("Listening started")
    }

    /// Stops the engine and tears down the input tap.
    public func stop() {
        guard isListening else { return }
        tearDown()
        Self.logger.info("Listening stopped")
    }

    // Calibration capture (startCalibration/stopCalibration) lives in
    // ClapDetector+Calibration.swift.

    // MARK: - Private — engine bring-up

    func activateEngine() throws {
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

    func installTap() {   // internal: +AudioSession ext
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        // The tap runs on a real-time AUDIO thread — must be `@Sendable`. Compute
        // features here, then hop to the main actor with the results.
        let analyzer = spectralAnalyzer
#if DEBUG
        let probe = snProbe   // measurement-only; feeds the same buffers
        if calibrationHandler == nil { probe.start(format: format) }
#endif
        let onBuffer: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { [weak self] buffer, when in
#if DEBUG
            probe.analyze(buffer, at: when)
#endif
            let rms = ClapDSP.rmsAmplitude(buffer: buffer)
            let peak = ClapDSP.peakAmplitude(buffer: buffer)
            let dBFS = 20.0 * log10(max(rms, Float(1e-10)))
            let crest = peak / max(rms, Float(1e-10))
            // Stage-2 features only when impulsive (rare); .notMeasured = -1s.
            let feats = crest > ClapSpectral.preCheckCrest
                ? analyzer.features(buffer: buffer) : .notMeasured
#if DEBUG
            let shape = ClapDiagnostics.transientShape(buffer: buffer)   // diagnostics only
#endif
            Task { @MainActor in
                guard let self else { return }
                if let capture = self.calibrationHandler {
                    if dBFS > self.dBFloor { capture(crest) }
                } else {
#if DEBUG
                    self.diagnostics.stage(rms: rms, peak: peak, shape: shape, spectral: feats)
#endif
                    self.processSample(dBFS: dBFS, crest: crest, hfr: feats.hfr, sfm: feats.sfm)
                }
            }
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: onBuffer)
    }

    func tearDown() {   // internal: +Calibration ext
#if DEBUG
        snProbe.stop()
#endif
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

        // HARD GATE: drop the buffer entirely while a response plays (+tail
        // grace) or during the engine-start transient. Unlike output-filtering,
        // gated buffers can't even seed firstClap for a later pair.
        if now < engineStartedAt.addingTimeInterval(startTransientGrace) || feedGate?() == true {
            reset()
            if dBFS > dBFloor { diag(.gated, dBFS, crest, hfr: hfr, sfm: sfm) }
            return
        }

        let isPeak = dBFS > dBFloor && crest > currentCrestThreshold
        let confirmed = spectralVetoEnabled   // stage 2 veto (reject-only); off → crest-only
            ? ClapSpectral.confirm(crestPeak: isPeak, hfr: hfr, sfm: sfm, routeAllowsSpectral: routeAllowsSpectral)
            : isPeak
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

    func reset() {   // internal: +AudioSession ext
        firstClapTime = nil
        releasedSinceFirstClap = false
    }

    // AVAudioSession config + interruption/route observers live in
    // ClapDetector+AudioSession.swift.

    // MARK: - Testing support

    /// ⚠️ TEST-ONLY. Sets `isListening` and the crest threshold directly
    /// without starting the AVAudioEngine. SPI-gated: callers must use
    /// `@_spi(Testing) import ClapFinderKitAudio`.
    @_spi(Testing)
    public func setListeningForTesting(_ listening: Bool, sensitivity: Sensitivity) {
        isListening = listening
        currentCrestThreshold = sensitivity.clapCrestThreshold
        engineStartedAt = .distantPast   // timing tests bypass the start gate
#if DEBUG
        diagnostics.configure(threshold: currentCrestThreshold, calibrated: false, sensitivity: sensitivity)
#endif
    }

    /// ⚠️ TEST-ONLY. Sets the engine-start stamp for start-transient-gate tests.
    @_spi(Testing)
    public func setEngineStartedForTesting(at date: Date) {
        engineStartedAt = date
    }

}
