import AppTrackingTransparency
import ClapFinderKitAds
import GoogleMobileAds
import Observation
import OSLog

// MARK: - InterstitialController

/// Owns the interstitial lifecycle: preload, policy-gated present,
/// counter bookkeeping (ADS_DESIGN.md §2–§4).
///
/// "Use" = one clap-mode listening session start (D1). The attempt
/// happens at stop-listening only — never on arm/disarm, never during
/// detection or alarm (enforced by `InterstitialPolicy`, unit-tested).
@Observable
@MainActor
final class InterstitialController: NSObject {

    // MARK: Ad unit

    /// PLACEHOLDER: Google's TEST interstitial unit. Replace with the
    /// production unit ID (PM-provided secret) before App Store submission.
    static let adUnitID = "ca-app-pub-3940256099942544/4411468910"

    // MARK: Dependencies

    private let policy: InterstitialPolicy
    private let store: InterstitialStore
    private let analytics: AnalyticsClient
    private var interstitial: InterstitialAd?

    private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "InterstitialController"
    )

    // MARK: Init

    init(
        policy: InterstitialPolicy = InterstitialPolicy(),
        store: InterstitialStore = UserDefaultsInterstitialStore(),
        analytics: AnalyticsClient = OSLogAnalyticsClient()
    ) {
        self.policy = policy
        self.store = store
        self.analytics = analytics
        super.init()
        if store.threshold == nil {
            store.threshold = policy.newThreshold()
        }
        preload()
    }

    // MARK: Public API

    /// Call when a clap listening session starts (D1: this is a "use").
    func recordUse() {
        store.usesSinceLast += 1
        Self.logger.debug("Use recorded (\(self.store.usesSinceLast)/\(self.store.threshold ?? -1))")
    }

    /// Call at stop-listening. Presents when the policy allows.
    func attemptPresentation(isDetectionActive: Bool, isAlarmActive: Bool) {
        let threshold = store.threshold ?? policy.newThreshold()
        let decision = policy.decide(
            usesSinceLast: store.usesSinceLast,
            threshold: threshold,
            isDetectionActive: isDetectionActive,
            isAlarmActive: isAlarmActive,
            isAdLoaded: interstitial != nil
        )

        switch decision {
        case .show:
            let uses = store.usesSinceLast
            analytics.log(AdPlacementAnalytics.interstitialShown(usesSinceLast: uses))
            store.usesSinceLast = 0
            store.threshold = policy.newThreshold()
            interstitial?.present(from: nil)

        case .suppress(let reason):
            // Frequency-cap suppressions are the normal case between
            // thresholds — log only the interesting ones at info.
            if reason != .frequencyCap {
                analytics.log(AdPlacementAnalytics.interstitialSuppressed(reason: reason))
            }
            Self.logger.debug("Interstitial suppressed: \(reason.rawValue)")
        }
    }

    // MARK: Private

    private func preload() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let request = Request()
            if ATTrackingManager.trackingAuthorizationStatus != .authorized {
                let extras = Extras()
                extras.additionalParameters = ["npa": "1"]
                request.register(extras)
            }
            do {
                let loaded = try await InterstitialAd.load(with: Self.adUnitID, request: request)
                loaded.fullScreenContentDelegate = self
                self.interstitial = loaded
                Self.logger.info("Interstitial preloaded")
            } catch {
                Self.logger.error("Interstitial load failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - FullScreenContentDelegate

extension InterstitialController: FullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ presentedAd: FullScreenPresentingAd) {
        Task { @MainActor in
            // A shown interstitial cannot be re-shown — drop and preload the next.
            self.interstitial = nil
            self.preload()
        }
    }

    nonisolated func ad(
        _ presentedAd: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        Task { @MainActor in
            Self.logger.error("Interstitial present failed: \(error.localizedDescription)")
            self.interstitial = nil
            self.preload()
        }
    }
}
