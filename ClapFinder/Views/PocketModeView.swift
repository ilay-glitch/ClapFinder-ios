import ClapFinderKitData
import ClapFinderKitDesign
import ClapFinderKitMotion
import SwiftUI

// MARK: - PocketModeView

/// The Pocket Mode tab (POCKET_MODE_DESIGN.md §4): same dog, new post.
/// Arm → slide the phone in screen-on → sustained cover engages (chirp) →
/// sustained uncover alarms. The alarm overlay lives in MainTabView.
struct PocketModeView: View {

    @Environment(CatalogStore.self) private var catalogStore
    @Environment(PocketModeCoordinator.self) private var pocket

    var body: some View {
        ZStack {
            CFColor.skyPrimary.ignoresSafeArea()

            if let background = GuardAssets.homeBackground {
                Image(background)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(CFColor.skyPrimary.opacity(0.30).ignoresSafeArea())
                    .accessibilityHidden(true)
            }

            VStack(spacing: CFSpacing.md) {
                Text(NSLocalizedString("pocket.title", comment: ""))
                    .font(CFFont.display())
                    .foregroundStyle(CFColor.textPrimary)
                    .padding(.top, CFSpacing.lg)

                if let mascot = GuardAssets.heroArmed {
                    Image(mascot)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                        .accessibilityHidden(true)
                }

                PocketHeroView(state: pocket.state, onTap: toggle)
                    .padding(.top, CFSpacing.md)

                statusLabel
                    .padding(.top, CFSpacing.sm)

                if pocket.state == .disarmed {
                    Text(NSLocalizedString("pocket.howItWorks", comment: ""))
                        .font(CFFont.caption())
                        .foregroundStyle(CFColor.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, CFSpacing.xs)
                }

                Spacer()
            }
            .padding(.horizontal, CFSpacing.md)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        Group {
            switch pocket.state {
            case .disarmed:
                Text(NSLocalizedString("pocket.status.disarmed", comment: ""))
                    .foregroundStyle(CFColor.textTertiary)
            case .awaitingPocket:
                Text(NSLocalizedString("pocket.status.awaitingPocket", comment: ""))
                    .foregroundStyle(CFColor.textSecondary)
            case .monitoring:
                HStack(spacing: CFSpacing.xs) {
                    Circle()
                        .fill(CFColor.listeningActive)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("pocket.status.monitoring", comment: ""))
                        .foregroundStyle(CFColor.listeningActive)
                }
            case .alarming:
                Text(NSLocalizedString("pocket.status.alarming", comment: ""))
                    .foregroundStyle(.red)
            }
        }
        .font(CFFont.callout())
        .multilineTextAlignment(.center)
    }

    private func toggle() {
        if pocket.state == .disarmed {
            guard let animal = catalogStore.selectedAnimal else { return }
            pocket.arm(animal: animal)
        } else {
            pocket.disarm()
        }
    }
}

// MARK: - PocketHeroView

/// Big arm/disarm circle, mirroring TouchAlertHeroView's proportions.
/// Pulse rings while on duty; no grace ring (pocket mode has no grace —
/// the cover debounce is the "grace").
struct PocketHeroView: View {

    let state: PocketModeLogic.State
    let onTap: () -> Void

    var body: some View {
        ZStack {
            PulseRingsView(isActive: state == .monitoring, diameter: 72)

            Button(action: onTap) {
                ZStack {
                    Circle()
                        .fill(state == .disarmed
                              ? AnyShapeStyle(Color.white)
                              : AnyShapeStyle(CFGradient.brand))
                        .frame(width: 160, height: 160)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)

                    Text(verbatim: state == .disarmed ? "👖" : "👀")
                        .font(.system(size: 56))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(NSLocalizedString(
                state == .disarmed ? "pocket.arm" : "pocket.disarm", comment: ""
            )))
        }
        .frame(height: 200)
    }
}
