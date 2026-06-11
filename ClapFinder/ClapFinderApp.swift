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
    /// Cold-launch splash gate. `WindowGroup` content is created once per
    /// process, so the splash runs exactly once per cold launch — warm
    /// resumes never re-enter it (SPLASH_DESIGN.md §6 rule 1).
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    private static let logger = Logger(subsystem: "com.appcentral.clapfinder", category: "App")

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showSplash = false
                    }
                    // ATT fires only after the splash hands off — the system
                    // alert must never land on top of the splash (SPLASH_DESIGN.md §6).
                    requestATTIfNeeded()
                }
                .transition(.opacity)
            } else {
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

    /// Fires the ATT prompt 0.5 s after the splash hands off to Home.
    ///
    /// Timing rationale:
    /// - The splash already gave the app its branded first moment; the
    ///   short delay just lets the Home cross-fade settle.
    /// - Never appears over the splash (or over an App Open Ad — first
    ///   launch shows no ad, and later launches have ATT determined).
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
