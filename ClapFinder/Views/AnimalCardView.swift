import ClapFinderKitData
import ClapFinderKitDesign
import SwiftUI

// MARK: - AnimalCardView

/// An 80×90pt tappable card showing an animal emoji and name.
///
/// Selected state: brand-gradient border (2pt) + inner glow.
/// Design spec: DESIGN.md § Animal card
struct AnimalCardView: View {

    let animal: Animal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: CFSpacing.xs) {
                Text(animal.emoji)
                    .font(.system(size: 36))

                Text(animal.name) // allow-hardcoded-string until: pr-8
                    .font(CFFont.caption())
                    .foregroundStyle(CFColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 80, height: 90)
            .background(
                RoundedRectangle(cornerRadius: CFRadius.animalCard)
                    .fill(CFColor.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: CFRadius.animalCard)
                            .fill(
                                isSelected
                                    ? CFColor.skyTint.opacity(0.5)
                                    : .clear
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CFRadius.animalCard)
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(CFGradient.brand)
                            : AnyShapeStyle(CFColor.borderSubtle),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)  // allow-hardcoded-string until: pr-8
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: Private helpers

    private var accessibilityLabel: String {
        let key = isSelected ? "a11y.animal.selected" : "a11y.animal.unselected"
        return String(format: NSLocalizedString(key, comment: ""), animal.name, animal.emoji)
    }
}
