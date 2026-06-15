import ActivityKit
import ClapFinderKitActivity
import ClapFinderKitDesign
import SwiftUI
import WidgetKit

// MARK: - ClapListeningLiveActivity

/// Lock Screen + Dynamic Island for clap-listening mode: a "Listening…" card
/// with a Stop button (parallels the touch-alert Live Activity).
struct ClapListeningLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClapListeningActivityAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(CFColor.backgroundElevated)
                .activitySystemActionForegroundColor(CFColor.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(verbatim: context.state.animalEmoji).font(.title)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(NSLocalizedString("liveactivity.clap.listening", comment: ""))
                        .font(CFFont.callout())
                        .foregroundStyle(CFColor.textPrimary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    stopButton
                }
            } compactLeading: {
                Image(systemName: "mic.fill").foregroundStyle(CFColor.gradientStart)
            } compactTrailing: {
                Text(verbatim: context.state.animalEmoji)
            } minimal: {
                Image(systemName: "mic.fill").foregroundStyle(CFColor.gradientStart)
            }
        }
    }

    private func lockScreen(_ state: ClapListeningActivityAttributes.ContentState) -> some View {
        HStack(spacing: CFSpacing.md) {
            Text(verbatim: state.animalEmoji)
                .font(.system(size: 40))

            VStack(alignment: .leading, spacing: CFSpacing.xs) {
                Text(NSLocalizedString("home.title", comment: ""))
                    .font(CFFont.headline())
                    .foregroundStyle(CFColor.textPrimary)
                Text(NSLocalizedString("liveactivity.clap.listening", comment: ""))
                    .font(CFFont.callout())
                    .foregroundStyle(CFColor.listeningActive)
            }

            Spacer()
            stopButton
        }
        .padding(CFSpacing.md)
    }

    @ViewBuilder
    private var stopButton: some View {
        if #available(iOS 17.0, *) {
            Button(intent: StopListeningIntent()) {
                Text(NSLocalizedString("liveactivity.clap.stop", comment: ""))
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
}
