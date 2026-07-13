import ClapFinderKitAds
import ClapFinderKitAudio
import ClapFinderKitData
import Foundation
import Observation
import OSLog

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFAudio)
import AVFAudio
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - PocketModeCoordinator

/// Owns a pocket-mode session (POCKET_MODE_DESIGN.md §2, §5): foreground
/// proximity-blank. The app must stay unlocked and foreground — when the
/// sensor covers, the system blanks the screen while we keep running.
///
/// ## Session requirements (§2, D0-verified)
/// `isProximityMonitoringEnabled` + `isIdleTimerDisabled` while armed, and a
/// `.playback` audio session activated at arm so the alarm is instant. No
/// keep-alive: a healthy session never backgrounds.
///
/// ## Fail-loud watchdog (§2)
/// Anything that resigns active mid-session (side-button lock, incoming
/// call, app switch) stands the session down and fires a local notification
/// — the user is never falsely confident.
@Observable
@MainActor
public final class PocketModeCoordinator {

    // MARK: Public state

    public var state: PocketModeLogic.State { logic.state }

    /// The animal that will sound (and is sounding) on trigger.
    public private(set) var armedAnimal: Animal?

    /// Mutual-exclusivity hook (§5): the app wires this to disarm the other
    /// coordinator. Called on every successful arm.
    public var onWillArm: (() -> Void)?

    // MARK: Dependencies

    public let responder: AlarmResponder
    public var soundBundle: Bundle

    private let analytics: AnalyticsClient
    private var logic = PocketModeLogic()
    private var evaluateTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "PocketModeCoordinator"
    )

    // MARK: Init

    public init(
        responder: AlarmResponder,
        analytics: AnalyticsClient = OSLogAnalyticsClient(),
        soundBundle: Bundle = .main
    ) {
        self.responder = responder
        self.analytics = analytics
        self.soundBundle = soundBundle
    }

    // MARK: Public API

    /// Arms pocket mode: proximity monitoring on, idle timer off, audio
    /// session hot. The guard engages after a sustained cover (§3).
    public func arm(animal: Animal) {
        guard logic.state == .disarmed else { return }
        onWillArm?()

        armedAnimal = animal
        logic.arm(at: Date())
        startSession()

        analytics.log(PocketModeAnalytics.armed())
        Self.logger.info("Pocket mode armed — \(animal.name)")
    }

    /// Disarms from any armed state. The ONLY way out of the alarm (§3).
    public func disarm() {
        guard logic.state != .disarmed else { return }

        let armedDuration = logic.secondsSinceArmed(at: Date())
        let wasAlarming = logic.disarm()

        responder.stopAlarm()
        responder.playChirp(in: soundBundle)
        endSession()
        armedAnimal = nil

        analytics.log(PocketModeAnalytics.disarmed(
            wasAlarming: wasAlarming,
            armedDurationS: armedDuration
        ))
        Self.logger.info("Pocket mode disarmed (wasAlarming \(wasAlarming))")
    }

    // MARK: Proximity handling

    /// Sensor edge → logic, then schedule the debounce evaluation.
    func handleProximityChange(covered: Bool, at now: Date) {
        logic.setCovered(covered, at: now)

        let delay = logic.state == .awaitingPocket
            ? logic.coverDebounce : logic.uncoverDebounce
        evaluateTask?.cancel()
        evaluateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay + 0.05))
            guard !Task.isCancelled else { return }
            self?.evaluatePending()
        }
    }

    private func evaluatePending() {
        guard let event = logic.evaluate(at: Date()) else { return }
        switch event {
        case .engaged:
            // Chirp through the blanked screen — audible "locked" (§3, D0 row 5).
            responder.playChirp(in: soundBundle)
            analytics.log(PocketModeAnalytics.engaged())
            Self.logger.info("Pocket mode engaged — on duty")

        case .alarm:
            guard let animal = armedAnimal else { return }
            responder.startAlarm(animal: animal, in: soundBundle)
            analytics.log(PocketModeAnalytics.alarm())
            Self.logger.info("Pocket mode ALARM — phone pulled out")
        }
    }

    // MARK: Session plumbing

    private func startSession() {
#if canImport(UIKit) && os(iOS)
        // Alarm must be instant — activate the playback session now (§5).
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        UIDevice.current.isProximityMonitoringEnabled = true
        UIApplication.shared.isIdleTimerDisabled = true

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleProximityChange(covered: UIDevice.current.proximityState, at: Date())
            }
        })
        // Fail-loud watchdog: resigning active kills the session audibly (§2).
        observers.append(center.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.standDown(reason: "resigned_active") }
        })
#endif
    }

    private func endSession() {
        evaluateTask?.cancel()
        evaluateTask = nil
#if canImport(UIKit) && os(iOS)
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
#endif
    }

    /// §2 watchdog: the app resigned active while armed — monitoring is no
    /// longer trustworthy. Notify and stand down.
    private func standDown(reason: String) {
        guard logic.state != .disarmed else { return }
        // While ALARMING, resigning active is expected chaos (thief pressing
        // buttons) — the alarm keeps sounding; only quiet states stand down.
        guard logic.state != .alarming else { return }

        logic.disarm()
        responder.stopAlarm()
        endSession()
        armedAnimal = nil
        notifyMonitoringStopped()

        analytics.log(PocketModeAnalytics.standDown(reason: reason))
        Self.logger.warning("Pocket mode stand-down: \(reason, privacy: .public)")
    }

    private func notifyMonitoringStopped() {
#if canImport(UserNotifications) && os(iOS)
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("touchAlert.notification.title", comment: "")
        content.body = NSLocalizedString("touchAlert.notification.body", comment: "")
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "pocketMode.monitoringStopped",
            content: content,
            trigger: nil
        ))
#endif
    }

    // MARK: Testing support

    /// Arms without touching UIKit (no proximity subscription, no idle-timer
    /// or audio-session calls). **Only call this from test code.**
    func armForTesting(animal: Animal, at now: Date) {
        guard logic.state == .disarmed else { return }
        onWillArm?()
        armedAnimal = animal
        logic.arm(at: now)
    }

    /// Drives the logic directly in tests (no scheduled evaluation).
    func setCoveredForTesting(_ covered: Bool, at now: Date) {
        logic.setCovered(covered, at: now)
    }

    @discardableResult
    func evaluateForTesting(at now: Date) -> PocketModeLogic.Event? {
        logic.evaluate(at: now)
    }
}

// MARK: - PocketModeAnalytics (POCKET_MODE_DESIGN.md §5)

/// Typed constructors for the pocket-mode event schema.
public enum PocketModeAnalytics {

    public static func armed() -> AnalyticsEvent {
        AnalyticsEvent(name: "pocket_armed")
    }

    public static func engaged() -> AnalyticsEvent {
        AnalyticsEvent(name: "pocket_engaged")
    }

    public static func alarm() -> AnalyticsEvent {
        AnalyticsEvent(name: "pocket_alarm")
    }

    public static func disarmed(wasAlarming: Bool, armedDurationS: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "pocket_disarmed", params: [
            "was_alarming": .bool(wasAlarming),
            "armed_duration_s": .int(armedDurationS)
        ])
    }

    public static func standDown(reason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "pocket_standdown", params: [
            "reason": .string(reason)
        ])
    }
}
