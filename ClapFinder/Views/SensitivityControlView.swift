import ClapFinderKitData
import ClapFinderKitDesign
import SwiftUI

// MARK: - SensitivityControlView

/// Segmented Low / Medium / High sensitivity picker.
///
/// Active segment: brand gradient fill.
/// Design spec: DESIGN.md § Sensitivity control
struct SensitivityControlView: View {

    @Binding var sensitivity: Sensitivity

    var body: some View {
        VStack(alignment: .leading, spacing: CFSpacing.sm) {
            Text(NSLocalizedString("sensitivity.label", comment: "")) // allow-hardcoded-string until: pr-8
                .font(CFFont.callout())
                .foregroundStyle(CFColor.textSecondary)

            HStack(spacing: 0) {
                ForEach(Sensitivity.allCases, id: \.self) { level in
                    sensitivitySegment(level)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CFRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: CFRadius.button)
                    .strokeBorder(CFColor.borderSubtle, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func sensitivitySegment(_ level: Sensitivity) -> some View {
        let isSelected = sensitivity == level

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                sensitivity = level
            }
        } label: {
            Text(level.displayName) // allow-hardcoded-string until: pr-8
                .font(CFFont.callout())
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? CFColor.textPrimary : CFColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CFSpacing.sm)
                .background(
                    isSelected
                        ? AnyShapeStyle(CFGradient.brand)
                        : AnyShapeStyle(CFColor.surfaceCard)
                )
        }
        .buttonStyle(.plain)
    }
}
