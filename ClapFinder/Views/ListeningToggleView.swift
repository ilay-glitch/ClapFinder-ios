import ClapFinderKitDesign
import SwiftUI

// MARK: - ListeningToggleView

/// 72pt circle mic toggle button.
///
/// Active:   brand-gradient radial fill, white mic icon.
/// Inactive: white border (2pt), transparent fill, gray mic icon.
/// Tap:      spring scale 0.95→1.0.
/// Design spec: DESIGN.md § Listening toggle
struct ListeningToggleView: View {

    let isListening: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background fill
                Circle()
                    .fill(
                        isListening
                            ? AnyShapeStyle(CFGradient.brand)
                            : AnyShapeStyle(Color.clear)
                    )

                // Border (inactive state only)
                if !isListening {
                    Circle()
                        .strokeBorder(CFColor.textPrimary, lineWidth: 2)
                }

                // Mic icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        isListening ? CFColor.textPrimary : CFColor.textSecondary
                    )
            }
            .frame(width: 72, height: 72)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isListening)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(
            isListening
                ? NSLocalizedString("a11y.toggle.on", comment: "") // allow-hardcoded-string until: pr-8
                : NSLocalizedString("a11y.toggle.off", comment: "") // allow-hardcoded-string until: pr-8
        )
        .accessibilityAddTraits(.isButton)
    }
}
