import ClapFinderKitDesign
import SwiftUI

// MARK: - DetectionMode

/// The two detection modes surfaced on Home (TOUCH_ALERT_DESIGN.md §7, D1).
enum DetectionMode: String, CaseIterable, Identifiable {
    case clap
    case touch

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .clap:
            return "mode.clap"
        case .touch:
            return "mode.touch"
        }
    }

    var emoji: String {
        switch self {
        case .clap:
            return "👏"
        case .touch:
            return "🛡️"
        }
    }
}

// MARK: - ModeSwitcherView

/// Segmented Clap / Touch switcher — same visual language as
/// `SensitivityControlView` (gradient active fill).
struct ModeSwitcherView: View {

    @Binding var mode: DetectionMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DetectionMode.allCases) { candidate in
                segment(for: candidate)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: CFRadius.button)
                .fill(CFColor.surfaceCard)
        )
    }

    private func segment(for candidate: DetectionMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = candidate
            }
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: candidate.emoji)
                Text(NSLocalizedString(candidate.labelKey, comment: ""))
                    .font(CFFont.callout())
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: CFRadius.button - 4)
                    .fill(mode == candidate ? AnyShapeStyle(CFGradient.brandHorizontal) : AnyShapeStyle(.clear))
            )
            .foregroundStyle(mode == candidate ? CFColor.textPrimary : CFColor.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == candidate ? .isSelected : [])
    }
}
