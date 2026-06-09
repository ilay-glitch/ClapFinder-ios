#if os(iOS)
import AppTrackingTransparency
import Observation
import OSLog

// MARK: - ATTManager

/// Manages App Tracking Transparency authorization.
///
/// Place one instance at app scope (`@State` in `ClapFinderApp`) and call
/// `requestAuthorizationIfNeeded()` after the initial UI has loaded.
///
/// ## Timing guidance
/// Apple recommends NOT requesting ATT on cold launch. Fire it after the user
/// has seen the app — e.g. 1.5 s after the first `.active` scene phase.
/// iOS only presents the system prompt when status is `.notDetermined`;
/// subsequent calls silently return the stored status.
///
/// ## Phase note
/// No ad SDK is linked in Phase 1. This manager requests consent early so
/// users have already decided before Phase 2 activates the ad network.
@Observable
@MainActor
public final class ATTManager {

    // MARK: Public state

    /// Current ATT authorization status, kept in sync after any request.
    public private(set) var authorizationStatus: ATTrackingManager.AuthorizationStatus

    // MARK: Logging

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "ATTManager"
    )

    // MARK: Init

    public init() {
        // Reflect whatever iOS has already stored — no prompt shown here.
        authorizationStatus = ATTrackingManager.trackingAuthorizationStatus
        Self.logger.debug("ATT status on init: \(String(describing: ATTrackingManager.trackingAuthorizationStatus))")
    }

    // MARK: Public API

    /// Requests tracking authorization if the status is `.notDetermined`.
    ///
    /// Safe to call on every launch — iOS will only show the system prompt once.
    /// `authorizationStatus` is updated after the user responds.
    public func requestAuthorizationIfNeeded() async {
        guard authorizationStatus == .notDetermined else {
            let status = String(describing: self.authorizationStatus)
            Self.logger.debug("ATT already determined (\(status)) — skipping prompt")
            return
        }
        Self.logger.info("Requesting ATT authorization")
        let status = await ATTrackingManager.requestTrackingAuthorization()
        authorizationStatus = status
        Self.logger.info("ATT authorization result: \(String(describing: status))")
    }
}

#else

// MARK: - macOS stub (ATT not available on macOS)

import Observation

/// No-op ATT manager for macOS CLI builds.
@Observable
@MainActor
public final class ATTManager {
    public private(set) var authorizationStatus: Int = 0   // placeholder
    public init() {}
    public func requestAuthorizationIfNeeded() async {}
}

#endif
