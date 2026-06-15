#if canImport(AppIntents) && os(iOS)
import AppIntents

// MARK: - DisarmIntent

/// The Live Activity "Disarm" button (LIVE_ACTIVITY_DESIGN.md §2).
///
/// `LiveActivityIntent` runs in the **app process** (iOS 17+), so `perform()`
/// can stop the running alarm directly via `TouchAlertControl`. The app is
/// always alive while armed (audio keep-alive), so the handler is present.
@available(iOS 17.0, *)
public struct DisarmIntent: LiveActivityIntent {

    public static let title: LocalizedStringResource = "Disarm"
    public static let description = IntentDescription("Turns off the touch alert.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        TouchAlertControl.requestDisarm()
        return .result()
    }
}
#endif
