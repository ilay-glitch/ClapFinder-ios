import ClapFinderKitDesign
import SwiftUI

// MARK: - SplashView

/// Animated launch screen — sky-blue redesign (DESIGN.md v-next / SPLASH_DESIGN.md).
/// Doubles as the App Open Ad loading window; **all timing/ad behavior lives in
/// `SplashViewModel`** and is unchanged — this is a skin of the view only.
struct SplashView: View {

    @State private var viewModel: SplashViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animating = false

    init(onFinished: @escaping @MainActor () -> Void) {
        let model = SplashViewModel()
        model.onFinished = onFinished
        _viewModel = State(initialValue: model)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CFColor.skyPrimary.ignoresSafeArea()

                titleBlock(in: geo.size)
                heroStage(in: geo.size)
                loadingBlock(in: geo.size)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(NSLocalizedString("home.title", comment: "")))
        .onAppear {
            viewModel.start()
            if !reduceMotion {
                animating = true
            }
        }
    }

    // MARK: Title

    private func titleBlock(in size: CGSize) -> some View {
        VStack(spacing: CFSpacing.sm) {
            Text(NSLocalizedString("home.title", comment: ""))
                .font(CFFont.display())
                .fontWeight(.heavy)
                .foregroundStyle(CFColor.textPrimary)

            Text(NSLocalizedString("splash.tagline", comment: ""))
                .font(CFFont.callout())
                .fontWeight(.semibold)
                .foregroundStyle(CFColor.textPrimary.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, CFSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, size.height * 0.16)
    }

    // MARK: Hero — detective dog + radar/sound-wave rings

    private func heroStage(in size: CGSize) -> some View {
        ZStack {
            radarRings
            Image("detective_dog_phone")
                .resizable()
                .scaledToFit()
                .frame(width: min(size.width * 0.62, 260))
                .offset(y: animating ? -10 : 0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: animating
                )
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var radarRings: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(CFColor.ctaBlue.opacity(0.35), lineWidth: 3)
                    .frame(width: 150, height: 150)
                    .scaleEffect(animating ? 2.3 : 0.7)
                    .opacity(animating ? 0 : 0.6)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.6),
                        value: animating
                    )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Loading

    private func loadingBlock(in size: CGSize) -> some View {
        VStack(spacing: CFSpacing.md) {
            Text(String(
                format: NSLocalizedString("splash.loading", comment: ""),
                viewModel.percent
            ))
            .font(CFFont.callout())
            .fontWeight(.bold)
            .foregroundStyle(CFColor.textPrimary)
            .monospacedDigit()

            progressBar

            if viewModel.showAdDisclaimer {
                Text(NSLocalizedString("splash.adDisclaimer", comment: ""))
                    .font(CFFont.caption())
                    .foregroundStyle(CFColor.textSecondary)
            }
        }
        .padding(.horizontal, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 64)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: "\(viewModel.percent)%"))
    }

    private var progressBar: some View {
        GeometryReader { barGeo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CFColor.surface.opacity(0.5))
                Capsule()
                    .fill(CFColor.ctaBlue)
                    .frame(width: max(barGeo.size.width * viewModel.progress, 14))
                    .animation(.linear(duration: 0.1), value: viewModel.progress)
            }
        }
        .frame(height: 14)
    }
}
