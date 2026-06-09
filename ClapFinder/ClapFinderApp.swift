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
        case .background:
            // UIBackgroundModes = ["audio"] keeps the engine running.
            // Nothing extra needed here — just log for diagnostics.
            Self.logger.info("App backgrounded — detection continues via background audio mode")

        case .active:
            Self.logger.info("App active")

        case .inactive:
            break

        @unknown default:
            break
        }
    }
}
