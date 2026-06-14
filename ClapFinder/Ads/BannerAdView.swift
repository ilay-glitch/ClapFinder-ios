import AppTrackingTransparency
import ClapFinderKitAds
import ClapFinderKitDesign
import GoogleMobileAds
import OSLog
import SwiftUI

// MARK: - BannerAdView

/// Bottom-of-Home banner (ADS_DESIGN.md D3 — idle-only; the caller
/// controls visibility). 50 pt container per DESIGN.md, anchored
/// adaptive size, `CFColor.adContainer` background.
struct BannerAdView: View {

    var body: some View {
        BannerViewRepresentable()
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(CFColor.adContainer)
    }
}

// MARK: - UIKit bridge

private struct BannerViewRepresentable: UIViewRepresentable {

    /// PLACEHOLDER: Google's TEST banner unit. Replace with the
    /// production unit ID (PM-provided secret) before App Store submission.
    static let adUnitID = "ca-app-pub-3940256099942544/2435281174"

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = Self.adUnitID
        banner.adSize = AdSizeBanner
        banner.delegate = context.coordinator

        let request = Request()
        if ATTrackingManager.trackingAuthorizationStatus != .authorized {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        banner.load(request)
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, BannerViewDelegate {

        private let analytics: AnalyticsClient = OSLogAnalyticsClient()
        private static let logger = Logger(
            subsystem: "com.appcentral.clapfinder",
            category: "BannerAdView"
        )

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            analytics.log(AdPlacementAnalytics.bannerLoaded())
            Self.logger.info("Banner loaded")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            analytics.log(AdPlacementAnalytics.bannerFailed(errorReason: error.localizedDescription))
            Self.logger.error("Banner failed: \(error.localizedDescription)")
        }
    }
}
