import Foundation

// MARK: - TouchAlertActivityPhase

/// The state the touch-alert Live Activity reflects (LIVE_ACTIVITY_DESIGN.md §3).
///
/// Plain value type — no ActivityKit — so the transition logic is unit-testable
/// on the macOS CLI where ActivityKit is unavailable.
public enum TouchAlertActivityPhase: String, Codable, Hashable, Sendable {
    /// Armed, inside the grace period (countdown shown).
    case grace
    /// Armed and actively monitoring.
    case armed
    /// Motion detected — alarm sounding.
    case alarming

    /// Localization key for the status line shown on the card.
    public var statusKey: String {
        switch self {
        case .grace:
            return "liveactivity.status.grace"
        case .armed:
            return "liveactivity.status.armed"
        case .alarming:
            return "liveactivity.status.alarming"
        }
    }
}

// MARK: - TouchAlertControl

/// Process-wide bridge so the Live Activity's Disarm button can stop the
/// running alarm (LIVE_ACTIVITY_DESIGN.md §2).
///
/// When armed/alarming the **app process is alive** (the audio-session
/// keep-alive), so `DisarmIntent` — a `LiveActivityIntent` that runs in the
/// app process on iOS 17+ — calls `requestDisarm()`, which invokes the
/// handler the live `TouchAlertCoordinator` registered. No App Group needed.
@MainActor
public enum TouchAlertControl {

    /// Set by the coordinator while armed; cleared on disarm.
    public private(set) static var disarmHandler: (() -> Void)?

    public static func register(disarm: @escaping () -> Void) {
        disarmHandler = disarm
    }

    public static func clear() {
        disarmHandler = nil
    }

    /// Invoked by the Live Activity Disarm button. No-op if nothing is armed.
    public static func requestDisarm() {
        disarmHandler?()
    }
}
