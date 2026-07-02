import ClapFinderKitActivity
import ClapFinderKitData
import Foundation
import Observation
import OSLog

#if os(iOS)
import ActivityKit
#endif

// MARK: - ResponseCoordinator

/// Wires `ClapDetector` → `SoundPlayer` + `FlashlightController`.
///
/// Typical usage:
/// ```swift
/// let coordinator = ResponseCoordinator()
/// try coordinator.start(animal: catalogStore.selectedAnimal!, sensitivity: catalogStore.sensitivity)
/// // …
/// coordinator.stop()
/// ```
///
/// The coordinator owns the `ClapDetector`. It registers `onClapDetected`,
/// starts detection, and on each double-clap triggers sound and flashlight
/// concurrently on the main actor.
@Observable
@MainActor
public final class ResponseCoordinator {

    // MARK: Public state

    /// `true` while clap detection is running.
    public private(set) var isActive = false

    /// The last animal that triggered a response (for UI feedback).
    public private(set) var lastTriggeredAnimal: Animal?

    // MARK: Dependencies

    public let detector: ClapDetector
    /// Shared response pipeline (sound + flashlight). Also consumed by
    /// the touch-alert coordinator — see AlarmResponder.
    public let responder: AlarmResponder

    /// Convenience accessors (pre-AlarmResponder public API, kept stable).
    public var soundPlayer: SoundPlayer { responder.soundPlayer }
    public var flashlight: FlashlightController { responder.flashlight }

    /// Bundle used to resolve sound files. Defaults to `Bundle.main`;
    /// inject a custom bundle in tests.
    public var soundBundle: Bundle

#if os(iOS)
    // Non-Sendable, main-actor-only — same escape hatch as ClapDetector's engine.
    nonisolated(unsafe) private var listeningActivity: Activity<ClapListeningActivityAttributes>?
#endif

    // MARK: Logging

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "ResponseCoordinator"
    )

    // MARK: Init

    /// Creates a coordinator with default-constructed components.
    ///
    /// - Parameter soundBundle: Bundle containing the `.caf` audio files
    ///   (default: `Bundle.main`).
    public init(soundBundle: Bundle = .main) {
        self.detector = ClapDetector()
        self.responder = AlarmResponder(soundPlayer: SoundPlayer(), flashlight: FlashlightController())
        self.soundBundle = soundBundle
    }

    /// Dependency-injection init for tests.
    public init(
        detector: ClapDetector,
        soundPlayer: SoundPlayer,
        flashlight: FlashlightController,
        soundBundle: Bundle = .main
    ) {
        self.detector = detector
        self.responder = AlarmResponder(soundPlayer: soundPlayer, flashlight: flashlight)
        self.soundBundle = soundBundle
    }

    // MARK: Public API

    /// Starts clap detection for the given animal and sensitivity.
    ///
    /// - Parameter crestOverride: Personalised crest threshold from calibration
    ///   (nil = use the sensitivity-derived value).
    /// - Throws: `ClapDetectorError` if the audio session or engine cannot start.
    public func start(animal: Animal, sensitivity: Sensitivity = .medium, crestOverride: Float? = nil) throws {
        guard !isActive else { return }
        wireDetector(for: animal)
        // HARD feed gate: while the response plays (+tail grace), the detector
        // drops buffers before the FSM — playback can't seed or pair anything.
        detector.feedGate = { [weak self] in
            guard let self else { return false }
            return self.suppression.shouldSuppress(
                isPlaying: self.soundPlayer.isPlaying,
                playbackEndedAt: self.soundPlayer.lastPlaybackEndedAt,
                now: Date()
            )
        }
        try detector.start(sensitivity: sensitivity, crestOverride: crestOverride)
        isActive = true

        // Live Activity Stop button → this coordinator.
        ClapListeningControl.register { [weak self] in self?.stop() }
        startLiveActivity(animal: animal)

        Self.logger.info("Started — animal: \(animal.name), sensitivity: \(sensitivity.rawValue)")
    }

    /// Stops detection and cancels any in-progress sound.
    public func stop() {
        guard isActive else { return }
        detector.stop()
        soundPlayer.stop()
        isActive = false

        endLiveActivity()
        ClapListeningControl.clear()

        Self.logger.info("Stopped")
    }

    // MARK: Live Activity (clap "Listening…" card)

#if os(iOS)
    private struct ActivityBox: @unchecked Sendable {
        let activity: Activity<ClapListeningActivityAttributes>
    }

    private func startLiveActivity(animal: Animal) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            listeningActivity = try Activity.request(
                attributes: ClapListeningActivityAttributes(animalName: animal.name),
                content: .init(
                    state: ClapListeningActivityAttributes.ContentState(animalEmoji: animal.emoji),
                    staleDate: nil
                )
            )
        } catch {
            Self.logger.error("Clap Live Activity start failed: \(error.localizedDescription)")
        }
    }

    private func endLiveActivity() {
        guard let live = listeningActivity else { return }
        listeningActivity = nil
        let box = ActivityBox(activity: live)
        Task { await box.activity.end(nil, dismissalPolicy: .immediate) }
    }
#else
    private func startLiveActivity(animal: Animal) {}
    private func endLiveActivity() {}
#endif

    // MARK: Private

    private func wireDetector(for animal: Animal) {
        let capturedAnimal = animal
        let capturedBundle = soundBundle
        detector.onClapDetected = { [weak self] in
            self?.handleTrigger(animal: capturedAnimal, bundle: capturedBundle)
        }
    }

    /// Feedback-loop guard state (see ResponseSuppression).
    private var suppression = ResponseSuppression()

    /// UX rate limit: at most one response per this interval, regardless of
    /// how many triggers arrive (a lost phone doesn't need to croak every 4 s).
    /// Named constant — tunable.
    static let minResponseInterval: TimeInterval = 10.0
    private var lastResponseAt = Date.distantPast

    /// Feedback-loop guard: a trigger arriving while the response sound plays —
    /// or within the tail grace after it — is the alert re-triggering itself
    /// through the mic, not a user clap. Ignored. `now` injectable for tests.
    func handleTrigger(animal: Animal, bundle: Bundle, now: Date = Date()) {
        let suppressed = suppression.shouldSuppress(
            isPlaying: soundPlayer.isPlaying,
            playbackEndedAt: soundPlayer.lastPlaybackEndedAt,
            now: now
        )
        guard !suppressed else {
            Self.logger.info("Trigger suppressed — response playing / tail grace")
            return
        }
        guard now >= lastResponseAt.addingTimeInterval(Self.minResponseInterval) else {
            Self.logger.info("Trigger rate-limited — last response < \(Self.minResponseInterval)s ago")
            return
        }
        respond(to: animal, bundle: bundle)
        lastResponseAt = now
        suppression.responseStarted(now: now)
    }

    private func respond(to animal: Animal, bundle: Bundle) {
        lastTriggeredAnimal = animal
        Self.logger.info("Clap response triggered — \(animal.name)")
        responder.respondOnce(animal: animal, in: bundle)
    }

    // MARK: Testing support

    /// Starts the coordinator without launching the real AVAudioEngine.
    /// **Only call this from test code.**
    func startForTesting(animal: Animal, sensitivity: Sensitivity = .medium) {
        guard !isActive else { return }
        wireDetector(for: animal)
        detector.setListeningForTesting(true, sensitivity: sensitivity)
        isActive = true
    }
}
