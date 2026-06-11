import ClapFinderKitDesign
import SwiftUI

// MARK: - SplashView

/// Animated launch screen, implemented against LOADING_SCREEN_MOCKUP.html
/// (SPLASH_DESIGN.md §2). Doubles as the App Open Ad loading window —
/// all timing/ad behavior lives in `SplashViewModel`.
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
                CFGradient.splashNight.ignoresSafeArea()

                starField(in: geo.size)
                moon
                hills(in: geo.size)
                pawPrints(in: geo.size)
                titleBlock(in: geo.size)
                characterStage(in: geo.size)
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

    // MARK: Stars (7, fixed positions per mockup, twinkle 2.4 s)

    private struct Star: Identifiable {
        let id: Int
        let unitX: Double
        let unitY: Double
        let size: Double
        let delay: Double
    }

    private static let stars: [Star] = [
        Star(id: 0, unitX: 0.10, unitY: 0.07, size: 4, delay: 0.0),
        Star(id: 1, unitX: 0.30, unitY: 0.13, size: 3, delay: 0.4),
        Star(id: 2, unitX: 0.56, unitY: 0.08, size: 5, delay: 0.9),
        Star(id: 3, unitX: 0.76, unitY: 0.18, size: 3, delay: 1.3),
        Star(id: 4, unitX: 0.18, unitY: 0.22, size: 4, delay: 0.7),
        Star(id: 5, unitX: 0.81, unitY: 0.05, size: 3, delay: 1.7),
        Star(id: 6, unitX: 0.89, unitY: 0.25, size: 4, delay: 0.2)
    ]

    private func starField(in size: CGSize) -> some View {
        ForEach(Self.stars) { star in
            Circle()
                .fill(.white)
                .frame(width: star.size, height: star.size)
                .opacity(animating ? 1.0 : 0.25)
                .scaleEffect(animating ? 1.15 : 0.8)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true)
                        .delay(star.delay),
                    value: animating
                )
                .position(x: size.width * star.unitX, y: size.height * star.unitY)
        }
    }

    // MARK: Moon (84 pt, radial core → edge, glow)

    private var moon: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [CFColor.splashMoonCore, CFColor.splashMoonEdge],
                    center: UnitPoint(x: 0.35, y: 0.35),
                    startRadius: 4,
                    endRadius: 52
                )
            )
            .frame(width: 84, height: 84)
            .shadow(color: CFColor.splashMoonEdge.opacity(0.35), radius: 25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 86)
            .padding(.trailing, 56)
    }

    // MARK: Hills

    private func hills(in size: CGSize) -> some View {
        ZStack {
            Ellipse()
                .fill(CFColor.splashHillBack.opacity(0.8))
                .frame(width: size.width * 1.2, height: 190)
                .position(x: size.width * 0.28, y: size.height - 195)
            Ellipse()
                .fill(CFColor.splashHillFront)
                .frame(width: size.width * 1.35, height: 210)
                .position(x: size.width * 0.78, y: size.height - 160)
        }
    }

    // MARK: Paw prints

    private func pawPrints(in size: CGSize) -> some View {
        ZStack {
            pawPrint(rotation: -20)
                .position(x: size.width * 0.18, y: size.height - 130)
            pawPrint(rotation: 15)
                .position(x: size.width * 0.33, y: size.height - 100)
            pawPrint(rotation: 40)
                .position(x: size.width * 0.78, y: size.height - 150)
        }
    }

    private func pawPrint(rotation: Double) -> some View {
        Text(verbatim: "🐾")
            .font(.system(size: 22))
            .opacity(0.18)
            .rotationEffect(.degrees(rotation))
            .accessibilityHidden(true)
    }

    // MARK: Title block

    private func titleBlock(in size: CGSize) -> some View {
        VStack(spacing: 10) {
            Text(NSLocalizedString("home.title", comment: ""))
                .font(CFFont.display())
                .fontWeight(.heavy)
                .foregroundStyle(CFGradient.titleGold)
                .shadow(color: .black.opacity(0.4), radius: 10, y: 3)

            Text(NSLocalizedString("splash.tagline", comment: ""))
                .font(CFFont.callout())
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, CFSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, size.height * 0.27)
    }

    // MARK: Character stage (👏 + 🐶📱 with sound waves)

    private func characterStage(in size: CGSize) -> some View {
        HStack(alignment: .bottom) {
            clappingHands
            Spacer()
            dogWithPhone
        }
        .padding(.horizontal, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 250)
        .accessibilityHidden(true)
    }

    private var clappingHands: some View {
        ZStack {
            Text(verbatim: "👏")
                .font(.system(size: 92))
                .rotationEffect(.degrees(animating ? 6 : -6), anchor: .bottom)
                .scaleEffect(animating ? 1.12 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                    value: animating
                )
                .shadow(color: .black.opacity(0.35), radius: 9, y: 8)

            clapSpark(delay: 0)
                .offset(x: -34, y: -52)
            clapSpark(delay: 0.2)
                .offset(x: 38, y: -44)
        }
    }

    private func clapSpark(delay: Double) -> some View {
        Text(verbatim: "✨")
            .font(.system(size: 26))
            .opacity(animating && !reduceMotion ? 1 : 0)
            .offset(y: animating ? -14 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.55)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animating
            )
    }

    private var dogWithPhone: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(verbatim: "🐶")
                .font(.system(size: 96))
                .offset(y: animating ? -16 : 0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                    value: animating
                )

            soundWaves
                .offset(x: 30, y: -8)

            Text(verbatim: "📱")
                .font(.system(size: 44))
                .rotationEffect(.degrees(12))
                .offset(x: 22, y: 10)
        }
        .shadow(color: .black.opacity(0.35), radius: 9, y: 8)
    }

    private var soundWaves: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .trim(from: 0.0, to: 0.25)
                    .stroke(CFColor.splashMoonEdge, lineWidth: 3)
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(-15))
                    .scaleEffect(animating ? 2.1 : 0.6)
                    .opacity(animating ? 0 : 0.9)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 1.1)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.25),
                        value: animating
                    )
            }
        }
    }

    // MARK: Loading block

    private func loadingBlock(in size: CGSize) -> some View {
        VStack(spacing: 14) {
            Text(String(
                format: NSLocalizedString("splash.loading", comment: ""),
                viewModel.percent
            ))
            .font(CFFont.callout())
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
            .monospacedDigit()

            progressBar

            if viewModel.showAdDisclaimer {
                Text(NSLocalizedString("splash.adDisclaimer", comment: ""))
                    .font(CFFont.caption())
                    .foregroundStyle(.white.opacity(0.75))
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
                    .fill(.white.opacity(0.28))
                Capsule()
                    .fill(CFGradient.splashBar)
                    .frame(width: max(barGeo.size.width * viewModel.progress, 14))
                    .shadow(color: CFColor.splashBarGlow.opacity(0.8), radius: 7)
                    .animation(.linear(duration: 0.1), value: viewModel.progress)
            }
        }
        .frame(height: 14)
    }
}
