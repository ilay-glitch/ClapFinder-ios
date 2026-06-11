import AppTrackingTransparency
import ClapFinderKitAds
import GoogleMobileAds
import OSLog

// MARK: - AppOpenAdLoader

/// Thin wrapper around GoogleMobileAds for the splash App Open Ad.
///
/// Lives in the app target — the GMA binary is iOS-only and must not
/// enter ClapFinderKit (SPLASH_DESIGN.md §9). All decision logic stays
/// in `SplashStateMachine` / `AppOpenAdPolicy`; this type only loads,
/// presents, and reports outcomes.
@MainActor
final class AppOpenAdLoader: NSObject {

    // MARK: Ad unit

    /// PLACEHOLDER: Google's TEST app-open ad unit. Replace with the
    /// production unit ID (PM-provided secret) before App Store submission.
    static let adUnitID = "ca-app-pub-3940256099942544/5575463023"

    // MARK: State

    private var appOpenAd: AppOpenAd?
    private var onDismiss: (@MainActor () -> Void)?

    private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "AppOpenAdLoader"
    )

    // MARK: Load

    /// Loads an app open ad. Non-personalized when ATT is not authorized
    /// (SPLASH_DESIGN.md §6 — ATT status is read at request time).
    ///
    /// - Returns: `nil` error string on success; the error description on failure.
    func load() async -> String? {
        let request = Request()
        if ATTrackingManager.trackingAuthorizationStatus != .authorized {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }

        do {
            let loadedAd = try await AppOpenAd.load(with: Self.adUnitID, request: request)
            loadedAd.fullScreenContentDelegate = self
            appOpenAd = loadedAd
            Self.logger.info("App open ad loaded")
            return nil
        } catch {
            Self.logger.error("App open ad failed to load: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    /// Whether ATT authorization was granted (for the `att_authorized`
    /// analytics param).
    var isATTAuthorized: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    // MARK: Present

    /// Presents the loaded ad. `onDismiss` fires exactly once, when the
    /// user closes the ad or presentation fails.
    func present(onDismiss: @escaping @MainActor () -> Void) {
        guard let appOpenAd else {
            onDismiss()
            return
        }
        self.onDismiss = onDismiss
        appOpenAd.present(from: nil)
    }

    /// Drops a loaded-but-unused ad (late load after timeout — §6 rule 5).
    func discard() {
        appOpenAd = nil
        onDismiss = nil
    }

    private func finishPresentation() {
        let callback = onDismiss
        appOpenAd = nil
        onDismiss = nil
        callback?()
    }
}

// MARK: - FullScreenContentDelegate

extension AppOpenAdLoader: FullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ presentedAd: FullScreenPresentingAd) {
        Task { @MainActor in
            Self.logger.info("App open ad dismissed")
            self.finishPresentation()
        }
    }

    nonisolated func ad(
        _ presentedAd: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        Task { @MainActor in
            Self.logger.error("App open ad failed to present: \(error.localizedDescription)")
            self.finishPresentation()
        }
    }
}
