import ClapFinderKitActivity
import ClapFinderKitAds
@_spi(Testing) import ClapFinderKitAudio
import ClapFinderKitData
import Foundation
import Observation
import OSLog

#if canImport(UserNotifications)
import UserNotifications
#endif

#if os(iOS)
import ActivityKit
#endif

// MARK: - TouchAlertCoordinator

/// Wires `MotionDetector` → `MotionAlertLogic` → `AlarmResponder`
/// (TOUCH_ALERT_DESIGN.md §6).
///
/// ## Background keep-alive (§4)
/// CoreMotion only delivers while the process executes, and iOS has no
/// motion background mode. Arming therefore also starts a `ClapDetector`
/// with no clap callback: its AVAudioEngine mic tap + active
/// `.playAndRecord` session keep the process alive when the screen locks
/// or the app backgrounds — the same mechanism clap detection uses.
///
/// ## System-stop watchdog (§4.2)
/// If the audio session dies unresumably while armed (`keepAlive.isListening`
/// flips false), the next motion sample fires a local notification
/// ("monitoring stopped") and disarms, so the user is never falsely confident.
@Observable
@MainActor
public final class TouchAlertCoordinator {

    // MARK: Public state

    public var state: MotionAlertLogic.State { logic.state }

    /// Whole seconds left in the grace countdown (UI ring).
    public private(set) var graceRemaining = 0

    /// The animal that will sound (and is sounding) on trigger.
    public private(set) var armedAnimal: Animal?

    // MARK: Dependencies

    public let detector: MotionDetector
    public let responder: AlarmResponder
    /// Audio-session keep-alive — a ClapDetector with no clap callback (§4.1).
    public let keepAlive: ClapDetector
    public var soundBundle: Bundle

    private let analytics: AnalyticsClient
    private var logic = MotionAlertLogic()
    private var graceTask: Task<Void, Never>?

#if os(iOS)
    // `Activity` is not Sendable in this SDK; all access is main-actor-only
    // (start/update/end), so there is no real race — same escape hatch as
    // ClapDetector's AVAudioEngine.
    nonisolated(unsafe) private var activity: Activity<TouchAlertActivityAttributes>?
#endif

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "TouchAlertCoordinator"
    )

    // MARK: Init

    public init(
        responder: AlarmResponder,
        detector: MotionDetector = MotionDetector(),
        keepAlive: ClapDetector = ClapDetector(),
        analytics: AnalyticsClient = OSLogAnalyticsClient(),
        soundBundle: Bundle = .main
    ) {
        self.responder = responder
        self.detector = detector
        self.keepAlive = keepAlive
        self.analytics = analytics
        self.soundBundle = soundBundle
    }

    // MARK: Public API

    /// Arms touch detection: starts the audio-session keep-alive, motion
    /// sampling, and the 5 s grace period.
    ///
    /// - Throws: `ClapDetectorError` if the keep-alive audio session
    ///   cannot start (mic permission denied, session conflict).
    public func arm(animal: Animal, sensitivity: Sensitivity) throws {
        guard logic.state == .disarmed else { return }

        armedAnimal = animal
        try keepAlive.start(sensitivity: sensitivity)

        detector.onSample = { [weak self] magnitude, now in
            self?.handleSample(magnitude: magnitude, at: now)
        }
        detector.start()

        logic.arm(sensitivity: sensitivity, at: Date())
        startGraceCountdown()
        requestNotificationPermissionIfNeeded()

        // Live Activity disarm button → this coordinator (LIVE_ACTIVITY_DESIGN §2).
        TouchAlertControl.register { [weak self] in self?.disarm() }
        startLiveActivity(animal: animal)

        analytics.log(TouchAlertAnalytics.armed(sensitivity: sensitivity.rawValue))
        Self.logger.info("Armed — \(animal.name), sensitivity \(sensitivity.rawValue)")
    }

    /// Disarms from any armed state. The ONLY way to stop the alarm (§3).
    public func disarm() {
        guard logic.state != .disarmed else { return }

        let sensitivity = logic.sensitivity
        let armedDuration = logic.secondsSinceArmed(at: Date())
        let wasAlarming = logic.disarm()

        responder.stopAlarm()
        detector.stop()
        detector.onSample = nil
        keepAlive.stop()
        graceTask?.cancel()
        graceTask = nil
        graceRemaining = 0
        armedAnimal = nil

        endLiveActivity()
        TouchAlertControl.clear()

        analytics.log(TouchAlertAnalytics.disarmed(
            sensitivity: sensitivity.rawValue,
            wasAlarming: wasAlarming,
            armedDurationS: armedDuration
        ))
        Self.logger.info("Disarmed (wasAlarming \(wasAlarming))")
    }

    // MARK: Private — detection

    private func handleSample(magnitude: Double, at now: Date) {
        // §4.2 watchdog: the keep-alive session died while armed —
        // monitoring is no longer trustworthy. Notify and stand down.
        if !keepAlive.isListening, logic.state != .disarmed {
            Self.logger.warning("Keep-alive session lost while armed — standing down")
            notifyMonitoringStopped()
            disarm()
            return
        }

        if logic.processSample(magnitude: magnitude, at: now) {
            triggerAlarm(at: now)
        }
    }

    private func triggerAlarm(at now: Date) {
        guard let animal = armedAnimal else { return }
        analytics.log(TouchAlertAnalytics.triggered(
            sensitivity: logic.sensitivity.rawValue,
            graceElapsedS: logic.secondsSinceArmed(at: now)
        ))
        Self.logger.info("Motion alarm triggered — \(animal.name)")
        responder.startAlarm(animal: animal, in: soundBundle)
        updateLiveActivity(phase: .alarming)
    }

    private func startGraceCountdown() {
        graceRemaining = Int(logic.gracePeriod.rounded())
        graceTask?.cancel()
        graceTask = Task { @MainActor [weak self] in
            while let self, self.graceRemaining > 0, !Task.isCancelled {
                self.updateLiveActivity(phase: .grace)
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.graceRemaining = max(self.graceRemaining - 1, 0)
            }
            // Grace finished — reflect the armed/monitoring state.
            if let self, self.logic.state != .alarming {
                self.updateLiveActivity(phase: .armed)
            }
        }
    }

    // MARK: Private — Live Activity (LIVE_ACTIVITY_DESIGN.md §3)

#if os(iOS)
    private func startLiveActivity(animal: Animal) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = TouchAlertActivityAttributes(animalName: animal.name)
        let state = TouchAlertActivityAttributes.ContentState(
            phase: .grace,
            animalEmoji: animal.emoji,
            graceRemaining: Int(logic.gracePeriod.rounded())
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            Self.logger.error("Live Activity start failed: \(error.localizedDescription)")
        }
    }

    /// Box so a non-Sendable `Activity` handle can cross into a detached Task.
    /// Safe: each box is used by exactly one task that owns the async call.
    private struct ActivityBox: @unchecked Sendable {
        let activity: Activity<TouchAlertActivityAttributes>
    }

    private func updateLiveActivity(phase: TouchAlertActivityPhase) {
        guard let live = activity, let animal = armedAnimal else { return }
        let box = ActivityBox(activity: live)
        let content = ActivityContent(
            state: TouchAlertActivityAttributes.ContentState(
                phase: phase,
                animalEmoji: animal.emoji,
                graceRemaining: graceRemaining
            ),
            staleDate: nil
        )
        Task { await box.activity.update(content) }
    }

    private func endLiveActivity() {
        guard let live = activity else { return }
        activity = nil
        let box = ActivityBox(activity: live)
        Task { await box.activity.end(nil, dismissalPolicy: .immediate) }
    }
#else
    private func startLiveActivity(animal: Animal) {}
    private func updateLiveActivity(phase: TouchAlertActivityPhase) {}
    private func endLiveActivity() {}
#endif

    // MARK: Private — notifications (§4.2)

    private func requestNotificationPermissionIfNeeded() {
#if canImport(UserNotifications) && os(iOS)
        let key = "touchAlert.hasRequestedNotifications"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
#endif
    }

    private func notifyMonitoringStopped() {
#if canImport(UserNotifications) && os(iOS)
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("touchAlert.notification.title", comment: "")
        content.body = NSLocalizedString("touchAlert.notification.body", comment: "")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "touchAlert.monitoringStopped",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
#endif
    }

    // MARK: Testing support

    /// Arms without starting the real audio engine or CoreMotion.
    /// **Only call this from test code.**
    func armForTesting(animal: Animal, sensitivity: Sensitivity, at now: Date) {
        guard logic.state == .disarmed else { return }
        armedAnimal = animal
        keepAlive.setListeningForTesting(true, sensitivity: sensitivity)
        detector.onSample = { [weak self] magnitude, sampleNow in
            self?.handleSample(magnitude: magnitude, at: sampleNow)
        }
        detector.start()
        logic.arm(sensitivity: sensitivity, at: now)
    }
}

// MARK: - TouchAlertAnalytics (EVENTS.md — Touch / Motion Alert)

/// Typed constructors for the PR-11 event schema.
public enum TouchAlertAnalytics {

    public static func armed(sensitivity: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "touch_alert_armed", params: [
            "sensitivity": .string(sensitivity)
        ])
    }

    public static func triggered(sensitivity: String, graceElapsedS: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "touch_alert_triggered", params: [
            "sensitivity": .string(sensitivity),
            "grace_elapsed_s": .int(graceElapsedS)
        ])
    }

    public static func disarmed(
        sensitivity: String,
        wasAlarming: Bool,
        armedDurationS: Int
    ) -> AnalyticsEvent {
        AnalyticsEvent(name: "touch_alert_disarmed", params: [
            "sensitivity": .string(sensitivity),
            "was_alarming": .bool(wasAlarming),
            "armed_duration_s": .int(armedDurationS)
        ])
    }
}
