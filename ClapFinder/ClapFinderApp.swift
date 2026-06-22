import ClapFinderKitAds
import ClapFinderKitAudio
import ClapFinderKitData
import ClapFinderKitMotion
import OSLog
import SwiftUI

// ClapFinder app target entry point.
// Xcode project (.xcodeproj) is created manually via Xcode → File → New → Project
// Bundle ID: com.appcentral.clapfinder | iOS 17.0+ | Universal

@main
struct ClapFinderApp: App {

    @State private var catalogStore = CatalogStore()
    @State private var coordinator: ResponseCoordinator
    @State private var touchAlert: TouchAlertCoordinator
    @State private var attManager = ATTManager()
    @State private var interstitials = InterstitialController()

    init() {
        // Both coordinators share ONE AlarmResponder (sound + flashlight) —
        // the AlertTrigger extraction from TOUCH_ALERT_DESIGN.md §6.
        let responseCoordinator = ResponseCoordinator()
        _coordinator = State(initialValue: responseCoordinator)
        _touchAlert = State(initialValue: TouchAlertCoordinator(responder: responseCoordinator.responder))
    }
    @State private var hasRequestedATT = false

    /// Launch phases. `WindowGroup` content is created once per process, so the
    /// splash runs exactly once per cold launch (SPLASH_DESIGN.md §6 rule 1).
    /// First launch: splash → onboarding → home. Returning: splash → home.
    private enum LaunchPhase { case splash, onboarding, home }
    @State private var phase: LaunchPhase = .splash

    /// Onboarding gate — **separate** from the App Open Ad's first-launch flag,
    /// so the ad fence is untouched (ONBOARDING_DESIGN.md §1).
    @AppStorage("onboarding.hasCompleted") private var onboardingDone = false

    @Environment(\.scenePhase) private var scenePhase

    private static let logger = Logger(subsystem: "com.appcentral.clapfinder", category: "App")

    var body: some Scene {
        WindowGroup {
            switch phase {
            case .splash:
                SplashView { onSplashFinished() }
                    .transition(.opacity)
            case .onboarding:
                OnboardingView { onOnboardingFinished() }
                    .transition(.opacity)
            case .home:
                HomeView()
                    .environment(catalogStore)
                    .environment(coordinator)
                    .environment(touchAlert)
                    .environment(interstitials)
                    .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    // MARK: Launch routing

    private func onSplashFinished() {
        if onboardingDone {
            enterHome()
        } else {
            withAnimation(.easeOut(duration: 0.35)) { phase = .onboarding }
        }
    }

    private func onOnboardingFinished() {
        onboardingDone = true
        enterHome()
    }

    /// The single path into Home — ATT fires here, so on first launch it lands
    /// after onboarding (never over the step-2 mic prompt) and on returning
    /// launches after the splash hand-off. Same rule, relocated.
    private func enterHome() {
        withAnimation(.easeOut(duration: 0.35)) { phase = .home }
        requestATTIfNeeded()
    }

    // MARK: Scene phase

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Self.logger.info("App active")

        case .background:
            // UIBackgroundModes = ["audio"] keeps the engine running.
            Self.logger.info("App backgrounded — detection continues via background audio mode")

        case .inactive:
            break

        @unknown default:
            break
        }
    }

    // MARK: ATT

    /// Fires the ATT prompt 0.5 s after entering Home (via `enterHome()`).
    ///
    /// Timing rationale:
    /// - Lands after the final hand-off into Home: after onboarding on first
    ///   launch (so it never overlaps the step-2 mic prompt), after the splash
    ///   on returning launches. The short delay lets the cross-fade settle.
    /// - Never appears over the splash, onboarding, or an App Open Ad (first
    ///   launch shows no ad; later launches have ATT determined).
    /// - Apple recommends not requesting ATT on cold launch.
    private func requestATTIfNeeded() {
        guard !hasRequestedATT else { return }
        hasRequestedATT = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            await attManager.requestAuthorizationIfNeeded()
        }
    }
}
