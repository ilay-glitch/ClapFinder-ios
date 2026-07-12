import ClapFinderKitDesign
import ClapFinderKitMotion
import SwiftUI

// MARK: - MainTabView

/// The two-mode tab bar (POCKET_MODE_DESIGN.md §4 — creative parity).
/// PR-P1 scaffold: Don't Touch is today's Home moved intact; Pocket Mode is
/// a placeholder until PR-P2 lands the coordinator.
///
/// The alarm overlay is hoisted here (was HomeView) so it covers the tab bar
/// too — the alarm must remain full-screen with DISARM as the only exit
/// (TOUCH_ALERT_DESIGN.md §3); a reachable tab bar would be an escape hatch.
struct MainTabView: View {

    @Environment(TouchAlertCoordinator.self) private var touchAlert

    var body: some View {
        ZStack {
            TabView {
                HomeView()
                    .tabItem {
                        Label(NSLocalizedString("tab.dontTouch", comment: ""), systemImage: "shield.fill")
                    }

                PocketModeView()
                    .tabItem {
                        Label(NSLocalizedString("tab.pocketMode", comment: ""), systemImage: "bag.fill")
                    }
            }

            if touchAlert.state == .alarming {
                AlarmOverlayView(animal: touchAlert.armedAnimal) {
                    touchAlert.disarm()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: touchAlert.state == .alarming)
    }
}
