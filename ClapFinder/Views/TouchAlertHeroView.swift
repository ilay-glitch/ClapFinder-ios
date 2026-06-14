import ClapFinderKitDesign
import ClapFinderKitMotion
import SwiftUI

// MARK: - TouchAlertHeroView

/// Touch-mode hero: 72 pt shield arm/disarm button with a grace-period
/// countdown ring and an armed "watching" pulse
/// (TOUCH_ALERT_DESIGN.md §7).
struct TouchAlertHeroView: View {

    let state: MotionAlertLogic.State
    let graceRemaining: Int
    let gracePeriod: Double
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    private var isArmed: Bool { state != .disarmed }

    var body: some View {
        ZStack {
            PulseRingsView(isActive: state == .monitoring || state == .alarming, diameter: 72)

            countdownRing

            Button {
                pressed = true
                onTap()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    pressed = false
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isArmed ? AnyShapeStyle(CFGradient.brand) : AnyShapeStyle(.clear))
                    Circle()
                        .strokeBorder(isArmed ? AnyShapeStyle(.clear) : AnyShapeStyle(.white), lineWidth: 2)

                    if state == .grace, !reduceMotion {
                        Text(verbatim: "\(graceRemaining)")
                            .font(CFFont.title1())
                            .foregroundStyle(CFColor.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.snappy, value: graceRemaining)
                    } else {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(isArmed ? CFColor.textPrimary : CFColor.textTertiary)
                    }
                }
                .frame(width: 72, height: 72)
            }
            .buttonStyle(.plain)
            .scaleEffect(pressed ? 0.95 : 1.0)
            .animation(.spring(duration: 0.25), value: pressed)
            .accessibilityLabel(Text(NSLocalizedString(
                isArmed ? "a11y.touch.armed" : "a11y.touch.disarmed",
                comment: ""
            )))
        }
        .frame(height: 180)
    }

    /// Depleting ring around the button during the grace countdown.
    private var countdownRing: some View {
        Circle()
            .trim(from: 0, to: state == .grace ? CGFloat(graceRemaining) / gracePeriod : 0)
            .stroke(CFGradient.pulse, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 92, height: 92)
            .opacity(state == .grace ? 1 : 0)
            .animation(.linear(duration: 1.0), value: graceRemaining)
    }
}
