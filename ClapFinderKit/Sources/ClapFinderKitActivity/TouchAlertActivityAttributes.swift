#if os(iOS)
import ActivityKit
import Foundation

// MARK: - TouchAlertActivityAttributes

/// ActivityKit attributes for the touch-alert Live Activity.
///
/// Shared by the app (which starts/updates/ends the activity) and the
/// widget extension (which renders it), so the type is byte-identical
/// across both targets.
public struct TouchAlertActivityAttributes: ActivityAttributes, Sendable {

    /// The mutable part, updated as the shield changes state.
    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: TouchAlertActivityPhase
        /// Emoji of the selected animal (shown on the card).
        public var animalEmoji: String
        /// Seconds left in the grace countdown (0 once monitoring/alarming).
        public var graceRemaining: Int

        public init(phase: TouchAlertActivityPhase, animalEmoji: String, graceRemaining: Int) {
            self.phase = phase
            self.animalEmoji = animalEmoji
            self.graceRemaining = graceRemaining
        }
    }

    /// Static identity for the session (name shown if the system needs it).
    public var animalName: String

    public init(animalName: String) {
        self.animalName = animalName
    }
}
#endif
