import ClapFinderKitAudio
import ClapFinderKitData
import SwiftUI

// ClapFinder app target entry point.
// Xcode project (.xcodeproj) is created manually via Xcode → File → New → Project
// Bundle ID: com.appcentral.clapfinder | iOS 17.0+ | Universal

@main
struct ClapFinderApp: App {

    @State private var catalogStore = CatalogStore()
    @State private var coordinator = ResponseCoordinator()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(catalogStore)
                .environment(coordinator)
        }
    }
}
