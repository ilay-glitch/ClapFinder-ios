import ClapFinderKitAudio
import ClapFinderKitDesign
import SwiftUI

// MARK: - ClapCalibrationSheet

/// One-time clap calibration flow (SOUND_RECOGNITION_DESIGN.md §5).
///
/// The user taps "Start", double-claps a couple of times during the capture
/// window, and the controller derives a crest threshold tuned to their claps,
/// mic, and room. On success the caller persists the threshold; "Use default"
/// clears any saved calibration.
struct ClapCalibrationSheet: View {

    let calibrator: ClapCalibrationController
    /// Called with the derived crest threshold when calibration succeeds.
    let onCalibrated: (Float) -> Void
    /// Called when the user opts back to the sensitivity-derived default.
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: CFSpacing.lg) {
            Capsule()
                .fill(CFColor.borderSubtle)
                .frame(width: 36, height: 5)
                .padding(.top, CFSpacing.sm)

            Text(NSLocalizedString("calibrate.title", comment: ""))
                .font(CFFont.title2())
                .foregroundStyle(CFColor.textPrimary)

            content
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, CFSpacing.lg)
        .padding(.bottom, CFSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CFColor.backgroundElevated.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var content: some View {
        switch calibrator.state {
        case .idle:
            idleContent
        case .capturing:
            capturingContent
        case .success(let threshold):
            successContent(threshold)
        case .failed:
            failedContent
        }
    }

    private var idleContent: some View {
        VStack(spacing: CFSpacing.lg) {
            Text(NSLocalizedString("calibrate.instructions", comment: ""))
                .font(CFFont.body())
                .foregroundStyle(CFColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            primaryButton(titleKey: "calibrate.start") {
                calibrator.start()
            }

            Button {
                onReset()
            } label: {
                Text(NSLocalizedString("calibrate.useDefault", comment: ""))
                    .font(CFFont.callout())
                    .foregroundStyle(CFColor.textSecondary)
            }
        }
    }

    private var capturingContent: some View {
        VStack(spacing: CFSpacing.lg) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(CFColor.listeningActive)
            Text(NSLocalizedString("calibrate.listening", comment: ""))
                .font(CFFont.headline())
                .foregroundStyle(CFColor.textPrimary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func successContent(_ threshold: Float) -> some View {
        VStack(spacing: CFSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(CFColor.listeningActive)
            Text(NSLocalizedString("calibrate.success", comment: ""))
                .font(CFFont.headline())
                .foregroundStyle(CFColor.textPrimary)
                .multilineTextAlignment(.center)
            Spacer()
            primaryButton(titleKey: "calibrate.done") {
                onCalibrated(threshold)
            }
        }
    }

    private var failedContent: some View {
        VStack(spacing: CFSpacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(CFColor.textSecondary)
            Text(NSLocalizedString("calibrate.failed", comment: ""))
                .font(CFFont.body())
                .foregroundStyle(CFColor.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            primaryButton(titleKey: "calibrate.retry") {
                calibrator.reset()
                calibrator.start()
            }
        }
    }

    private func primaryButton(titleKey: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(NSLocalizedString(titleKey, comment: ""))
                .font(CFFont.headline())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CFSpacing.md)
                .background(
                    LinearGradient(
                        colors: [CFColor.gradientStart, CFColor.gradientMid],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: CFRadius.button, style: .continuous)
                )
        }
    }
}
