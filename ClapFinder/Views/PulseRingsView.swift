import ClapFinderKitDesign
import SwiftUI

// MARK: - PulseRingsView

/// Three concentric expanding rings that animate outward while `isActive` is true.
///
/// Each ring: scale 1.0→2.4, opacity 0.7→0, 2s ease-out.
/// Stagger: ring 2 +0.5s, ring 3 +1.0s.
/// Reduce Motion: static opacity 0.3, no scale animation.
/// Design spec: DESIGN.md § Pulse rings
struct PulseRingsView: View {

    let isActive: Bool
    /// Diameter of the innermost ring. Match the toggle diameter (72pt).
    var diameter: CGFloat = 72

    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(CFGradient.pulse, lineWidth: 2)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(ringScale(index: index))
                    .opacity(ringOpacity(index: index))
                    .animation(
                        ringAnimation(index: index),
                        value: animating
                    )
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                startAnimation()
            } else {
                animating = false
            }
        }
        .onAppear {
            if isActive { startAnimation() }
        }
    }

    // MARK: Private helpers

    private func ringScale(index: Int) -> CGFloat {
        guard !reduceMotion else { return 1.0 }
        return animating ? 2.4 : 1.0
    }

    private func ringOpacity(index: Int) -> Double {
        if reduceMotion { return isActive ? 0.3 : 0.0 }
        return animating ? 0.0 : 0.7
    }

    private func ringAnimation(index: Int) -> Animation? {
        guard !reduceMotion, isActive else { return nil }
        let delay = Double(index) * 0.5
        return Animation
            .easeOut(duration: 2.0)
            .delay(delay)
            .repeatForever(autoreverses: false)
    }

    private func startAnimation() {
        guard !reduceMotion else { return }
        // Reset to initial state, then animate on next run-loop tick
        animating = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            animating = true
        }
    }
}
