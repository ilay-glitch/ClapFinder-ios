#if os(iOS)
import ActivityKit
import Foundation

// MARK: - ClapListeningActivityAttributes

/// ActivityKit attributes for the clap-listening Live Activity — a
/// "Listening…" card with a Stop button (parallels the touch-alert one).
public struct ClapListeningActivityAttributes: ActivityAttributes, Sendable {

    public struct ContentState: Codable, Hashable, Sendable {
        /// Emoji of the selected animal (shown on the card).
        public var animalEmoji: String

        public init(animalEmoji: String) {
            self.animalEmoji = animalEmoji
        }
    }

    public var animalName: String

    public init(animalName: String) {
        self.animalName = animalName
    }
}
#endif

#if canImport(AppIntents) && os(iOS)
import AppIntents

// MARK: - StopListeningIntent

/// The clap Live Activity "Stop" button. Runs in the app process (iOS 17+)
/// and stops listening via `ClapListeningControl`.
@available(iOS 17.0, *)
public struct StopListeningIntent: LiveActivityIntent {

    public static let title: LocalizedStringResource = "Stop"
    public static let description = IntentDescription("Stops listening for claps.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        ClapListeningControl.requestStop()
        return .result()
    }
}
#endif
