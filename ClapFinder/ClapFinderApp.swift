import ClapFinderKitAds
import ClapFinderKitAudio
import ClapFinderKitData
import OSLog
import SwiftUI

// ClapFinder app target entry point.
// Xcode project (.xcodeproj) is created manually via Xcode → File → New → Project
// Bundle ID: com.appcentral.clapfinder | iOS 17.0+ | Universal

@main
struct ClapFinderApp: App {

    @State private var catalogStore = CatalogStore()
    @State private var coordinator = ResponseCoordinator()
    @State private var attManager = ATTManager()
    @State private var hasRequestedATT = false
    @Environment(\.scenePhase) private var scenePhase

    private static let logger = Logger(subsystem: "com.appcentral.clapfinder", category: "App")

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(catalogStore)
                .environment(coordinator)
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
            requestATTIfNeeded()

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

    /// Fires the ATT prompt 1.5 s after the first `.active` scene phase.
    ///
    /// Delay rationale:
    /// - Lets the home screen fully render before the system alert appears.
    /// - Avoids stacking ATT on top of the mic permission prompt.
    /// - Apple recommends not requesting ATT on cold launch.
    private func requestATTIfNeeded() {
        guard !hasRequestedATT else { return }
        hasRequestedATT = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            await attManager.requestAuthorizationIfNeeded()
        }
    }
}
