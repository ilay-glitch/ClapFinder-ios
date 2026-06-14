import Foundation

// MARK: - InterstitialPolicy

/// Pure interstitial eligibility (ADS_DESIGN.md §2–§3).
///
/// Hard constraints encoded here and pinned by unit tests:
/// - NEVER while detection is active (operating contract).
/// - NEVER while the touch alert is armed or alarming.
/// - At most 1 per `threshold` uses, threshold drawn from 3–5.
///
/// Suppress-reason priority: detection > alarm > frequency > not-loaded.
public struct InterstitialPolicy: Sendable {

    // MARK: Types

    public enum Decision: Equatable, Sendable {
        case show
        case suppress(SuppressReason)
    }

    public enum SuppressReason: String, Equatable, Sendable {
        case detectionActive = "detection_active"
        case alarmActive = "alarm_active"
        case frequencyCap = "frequency_cap"
        case notLoaded = "not_loaded"
    }

    // MARK: Threshold

    /// Inclusive range the per-cycle threshold is drawn from.
    public static let thresholdRange: ClosedRange<Int> = 3...5

    private let drawThreshold: @Sendable () -> Int

    /// - Parameter drawThreshold: RNG seam — injected so tests are
    ///   deterministic. Defaults to a uniform draw from `thresholdRange`.
    public init(drawThreshold: @escaping @Sendable () -> Int = { Int.random(in: thresholdRange) }) {
        self.drawThreshold = drawThreshold
    }

    /// Draws the next cycle's threshold, clamped into `thresholdRange`.
    public func newThreshold() -> Int {
        min(max(drawThreshold(), Self.thresholdRange.lowerBound), Self.thresholdRange.upperBound)
    }

    // MARK: Decision

    /// Decides whether an interstitial may present right now.
    ///
    /// - Parameters:
    ///   - usesSinceLast: Listening sessions started since the last shown interstitial.
    ///   - threshold: This cycle's required use count (3–5, persisted).
    ///   - isDetectionActive: Clap listening is running.
    ///   - isAlarmActive: Touch alert is armed (grace/monitoring) or alarming.
    ///   - isAdLoaded: A presentable interstitial is in memory.
    public func decide(
        usesSinceLast: Int,
        threshold: Int,
        isDetectionActive: Bool,
        isAlarmActive: Bool,
        isAdLoaded: Bool
    ) -> Decision {
        if isDetectionActive {
            return .suppress(.detectionActive)
        }
        if isAlarmActive {
            return .suppress(.alarmActive)
        }
        if usesSinceLast < threshold {
            return .suppress(.frequencyCap)
        }
        if !isAdLoaded {
            return .suppress(.notLoaded)
        }
        return .show
    }
}

// MARK: - InterstitialStore

/// Persisted frequency-cap state (counter survives force-quit).
public protocol InterstitialStore: AnyObject, Sendable {
    var usesSinceLast: Int { get set }
    /// Current cycle's threshold; `nil` until first drawn.
    var threshold: Int? { get set }
}

/// `UserDefaults`-backed store. `@unchecked Sendable`: UserDefaults is
/// documented thread-safe.
public final class UserDefaultsInterstitialStore: InterstitialStore, @unchecked Sendable {

    private enum Key {
        static let uses = "interstitial.usesSinceLast"
        static let threshold = "interstitial.threshold"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var usesSinceLast: Int {
        get { defaults.integer(forKey: Key.uses) }
        set { defaults.set(newValue, forKey: Key.uses) }
    }

    public var threshold: Int? {
        get { defaults.object(forKey: Key.threshold) as? Int }
        set { defaults.set(newValue, forKey: Key.threshold) }
    }
}

// MARK: - AdPlacementAnalytics (EVENTS.md — Banner / Interstitial)

public enum AdPlacementAnalytics {

    public static func bannerLoaded() -> AnalyticsEvent {
        AnalyticsEvent(name: "banner_loaded")
    }

    public static func bannerFailed(errorReason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "banner_failed", params: [
            "error_reason": .string(errorReason)
        ])
    }

    public static func interstitialShown(usesSinceLast: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "interstitial_shown", params: [
            "uses_since_last": .int(usesSinceLast)
        ])
    }

    public static func interstitialSuppressed(reason: InterstitialPolicy.SuppressReason) -> AnalyticsEvent {
        AnalyticsEvent(name: "interstitial_suppressed", params: [
            "reason": .string(reason.rawValue)
        ])
    }
}
