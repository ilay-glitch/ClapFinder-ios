import ClapFinderKitDesign
import SwiftUI

// MARK: - PocketModeView

/// PR-P1 placeholder for the Pocket Mode tab (POCKET_MODE_DESIGN.md §4).
/// The arm flow, state machine, and PocketModeCoordinator arrive in PR-P2 —
/// this screen only holds the tab's skeleton: hero mascot + status line.
struct PocketModeView: View {

    var body: some View {
        ZStack {
            CFColor.skyPrimary.ignoresSafeArea()

            VStack(spacing: CFSpacing.md) {
                Spacer()

                if let mascot = GuardAssets.heroArmed {
                    Image(mascot)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 160)
                        .accessibilityHidden(true)
                }

                Text(NSLocalizedString("pocket.title", comment: ""))
                    .font(CFFont.display())
                    .foregroundStyle(CFColor.textPrimary)

                Text(NSLocalizedString("pocket.status.disarmed", comment: ""))
                    .font(CFFont.callout())
                    .foregroundStyle(CFColor.textTertiary)

                Spacer()
            }
            .padding(.horizontal, CFSpacing.md)
        }
    }
}
