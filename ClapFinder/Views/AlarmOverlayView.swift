import ClapFinderKitData
import ClapFinderKitDesign
import SwiftUI

// MARK: - AlarmOverlayView

/// Full-screen alarm state — bouncing animal + giant DISARM button
/// (TOUCH_ALERT_DESIGN.md §7). Disarm is the ONLY way out (§3).
struct AlarmOverlayView: View {

    let animal: Animal?
    /// Localized title key — touch and pocket alarms narrate differently.
    var titleKey = "touch.status.alarming"
    let onDisarm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        ZStack {
            // Dim scrim + red-tinted urgency wash for the alarm state
            Color.black.opacity(0.55).ignoresSafeArea()
            Color.red.opacity(0.32).ignoresSafeArea()

            VStack(spacing: CFSpacing.xl) {
                Spacer()

                // PM ruling 2026-07-09: the SELECTED guard's emoji, not the
                // barking dog — the visual must match the user-chosen sound.
                Text(verbatim: animal?.emoji ?? "🛡️")
                    .font(.system(size: 120))
                    .offset(y: animating && !reduceMotion ? -24 : 0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.4).repeatForever(autoreverses: true),
                        value: animating
                    )

                Text(NSLocalizedString(titleKey, comment: ""))
                    .font(CFFont.title1())
                    .foregroundStyle(CFColor.textPrimary)

                Spacer()

                Button(action: onDisarm) {
                    Text(NSLocalizedString("touch.disarm", comment: ""))
                        .font(CFFont.title1())
                        .fontWeight(.heavy)
                        .foregroundStyle(CFColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CFSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CFRadius.card)
                                .fill(CFGradient.brand)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, CFSpacing.lg)
                .padding(.bottom, CFSpacing.xxl)
                .accessibilityLabel(Text(NSLocalizedString("touch.disarm", comment: "")))
            }
        }
        .onAppear { animating = true }
        .accessibilityElement(children: .contain)
    }
}
