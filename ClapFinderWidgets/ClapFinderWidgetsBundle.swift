import SwiftUI
import WidgetKit

// MARK: - Widget bundle

/// Extension entry point. Hosts the touch-alert Live Activity
/// (LIVE_ACTIVITY_DESIGN.md §2).
@main
struct ClapFinderWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TouchAlertLiveActivity()
        // ClapListeningLiveActivity: unregistered at the pivot (PIVOT.md §4) —
        // the type stays in the target, dormant.
    }
}
