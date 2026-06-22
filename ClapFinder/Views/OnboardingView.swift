import AVFAudio
import ClapFinderKitDesign
import SwiftUI

// MARK: - OnboardingView

/// First-launch 3-step onboarding (ONBOARDING_DESIGN.md). Shown once, gated by
/// `onboarding.hasCompleted` in `ClapFinderApp` — a flag **separate** from the
/// App Open Ad's first-launch flag, so the ad fence is untouched.
///
/// Step 2 is the mic pre-permission explainer: it shows *why* first, then fires
/// the system `requestRecordPermission`; grant or deny, it proceeds (the
/// detector requests the mic lazily anyway). No detection logic is touched.
struct OnboardingView: View {

    let onFinished: () -> Void

    @State private var step = 0
    private let totalSteps = 3

    var body: some View {
        ZStack {
            CFColor.skyPrimary.ignoresSafeArea()

            VStack(spacing: CFSpacing.lg) {
                progressLabel
                Spacer()
                content
                Spacer()
                ctaButton
            }
            .padding(.horizontal, CFSpacing.lg)
            .padding(.vertical, CFSpacing.xl)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Progress

    private var progressLabel: some View {
        Text(String(format: NSLocalizedString("onboarding.progress", comment: ""), step + 1))
            .font(CFFont.caption())
            .fontWeight(.bold)
            .foregroundStyle(CFColor.textSecondary)
            .accessibilityLabel(Text(verbatim: "Step \(step + 1) of \(totalSteps)"))
    }

    // MARK: Step content

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            stepBody(image: "detective_dog_wave",
                     titleKey: "onboarding.step1.title", bodyKey: "onboarding.step1.body")
        case 1:
            micStep
        default:
            stepBody(image: "detective_dog_phone",
                     titleKey: "onboarding.step3.title", bodyKey: "onboarding.step3.body")
        }
    }

    private func stepBody(image: String, titleKey: String, bodyKey: String) -> some View {
        VStack(spacing: CFSpacing.lg) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 220)
                .accessibilityHidden(true)
            speechBubble(titleKey: titleKey, bodyKey: bodyKey)
        }
    }

    /// Step 2 — mascot badge + a mic / sound-wave listening motif, then the card.
    private var micStep: some View {
        VStack(spacing: CFSpacing.lg) {
            ZStack {
                ForEach(0..<2, id: \.self) { ring in
                    Circle()
                        .stroke(CFColor.ctaBlue.opacity(0.30), lineWidth: 3)
                        .frame(width: 110 + CGFloat(ring) * 44, height: 110 + CGFloat(ring) * 44)
                }
                Image(systemName: "mic.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(CFColor.ctaBlue)
                Image("detective_dog_avatar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                    .offset(x: 74, y: 60)
            }
            .frame(height: 190)
            .accessibilityHidden(true)
            speechBubble(titleKey: "onboarding.step2.title", bodyKey: "onboarding.step2.body")
        }
    }

    /// White "speech bubble" card holding the step copy.
    private func speechBubble(titleKey: String, bodyKey: String) -> some View {
        VStack(spacing: CFSpacing.sm) {
            Text(NSLocalizedString(titleKey, comment: ""))
                .font(CFFont.title2())
                .foregroundStyle(CFColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(NSLocalizedString(bodyKey, comment: ""))
                .font(CFFont.body())
                .foregroundStyle(CFColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(CFSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(CFColor.surface, in: RoundedRectangle(cornerRadius: CFRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    // MARK: CTA

    private var ctaButton: some View {
        Button(action: advance) {
            Text(NSLocalizedString(ctaKey, comment: ""))
                .font(CFFont.headline())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CFSpacing.md)
                .background(
                    CFColor.ctaBlue,
                    in: RoundedRectangle(cornerRadius: CFRadius.button, style: .continuous)
                )
        }
    }

    private var ctaKey: String {
        switch step {
        case 0: return "onboarding.continue"
        case 1: return "onboarding.step2.cta"
        default: return "onboarding.step3.cta"
        }
    }

    // MARK: Flow

    private func advance() {
        if step == 1 {
            // Pre-explainer shown → now fire the system mic prompt; proceed on
            // either outcome (detector re-requests lazily on first listen).
            AVAudioApplication.requestRecordPermission { _ in
                Task { @MainActor in goNext() }
            }
        } else {
            goNext()
        }
    }

    private func goNext() {
        if step >= totalSteps - 1 {
            onFinished()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
        }
    }
}
