import ActivityKit
import ClapFinderKitActivity
import ClapFinderKitDesign
import SwiftUI
import WidgetKit

// MARK: - TouchAlertLiveActivity

/// Lock Screen card + Dynamic Island for the armed touch alert, with a
/// Disarm button (LIVE_ACTIVITY_DESIGN.md §4). The button runs `DisarmIntent`
/// (a `LiveActivityIntent`) in the app process, which stops the alarm.
struct TouchAlertLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TouchAlertActivityAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(CFColor.backgroundElevated)
                .activitySystemActionForegroundColor(CFColor.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(verbatim: context.state.animalEmoji).font(.title)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(status(context.state))
                        .font(CFFont.callout())
                        .foregroundStyle(CFColor.textPrimary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    disarmButton
                }
            } compactLeading: {
                Image(systemName: "shield.fill").foregroundStyle(CFColor.gradientStart)
            } compactTrailing: {
                if context.state.phase == .grace {
                    Text(verbatim: "\(context.state.graceRemaining)").monospacedDigit()
                }
            } minimal: {
                Image(systemName: "shield.fill").foregroundStyle(CFColor.gradientStart)
            }
        }
    }

    // MARK: Lock Screen

    private func lockScreen(_ state: TouchAlertActivityAttributes.ContentState) -> some View {
        HStack(spacing: CFSpacing.md) {
            Text(verbatim: state.animalEmoji)
                .font(.system(size: 40))

            VStack(alignment: .leading, spacing: CFSpacing.xs) {
                Text(NSLocalizedString("home.title", comment: ""))
                    .font(CFFont.headline())
                    .foregroundStyle(CFColor.textPrimary)
                Text(status(state))
                    .font(CFFont.callout())
                    .foregroundStyle(state.phase == .alarming ? Color.red : CFColor.textSecondary)
            }

            Spacer()
            disarmButton
        }
        .padding(CFSpacing.md)
    }

    // MARK: Disarm button

    @ViewBuilder
    private var disarmButton: some View {
        if #available(iOS 17.0, *) {
            Button(intent: DisarmIntent()) {
                Text(NSLocalizedString("touch.disarm", comment: ""))
                    .font(CFFont.callout())
                    .fontWeight(.bold)
                    .foregroundStyle(CFColor.textPrimary)
                    .padding(.horizontal, CFSpacing.md)
                    .padding(.vertical, CFSpacing.xs)
                    .background(Capsule().fill(CFGradient.brand))
            }
            .buttonStyle(.plain)
        }
    }

    private func status(_ state: TouchAlertActivityAttributes.ContentState) -> String {
        if state.phase == .grace {
            return String(
                format: NSLocalizedString("liveactivity.status.grace", comment: ""),
                state.graceRemaining
            )
        }
        return NSLocalizedString(state.phase.statusKey, comment: "")
    }
}
