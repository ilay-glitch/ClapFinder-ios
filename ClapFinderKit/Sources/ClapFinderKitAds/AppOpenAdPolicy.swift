import Foundation

// MARK: - AppOpenAdPolicy

/// Pure eligibility policy for App Open Ads (SPLASH_DESIGN.md §6).
///
/// The policy holds no state and performs no I/O. Callers pass the
/// relevant facts in and get a `Decision` back. The clock is injected
/// so interval tests never sleep — pass a fixed `now` and move it.
///
/// ```swift
/// let policy = AppOpenAdPolicy(now: { fixedDate })
/// policy.decide(isFirstLaunch: false, shownThisSession: false, lastShownAt: t)
/// ```
///
/// Rule order (first match wins): first launch → session cap →
/// frequency cap → eligible. Cold-launch gating (rule 1) is upstream:
/// the splash — and therefore this policy — only runs on cold launch.
public struct AppOpenAdPolicy: Sendable {

    // MARK: Decision

    public enum Decision: Equatable, Sendable {
        case eligible
        case skip(AdSkipReason)
    }

    // MARK: Configuration

    /// Minimum interval between app open ads (rule 4). Default 4 hours.
    public let minimumInterval: TimeInterval

    private let now: @Sendable () -> Date

    // MARK: Init

    /// - Parameters:
    ///   - minimumInterval: Seconds required between app open ads (default 4 h).
    ///   - now: Clock seam — injected so tests control time. Defaults to `Date.init`.
    public init(
        minimumInterval: TimeInterval = 4 * 60 * 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.minimumInterval = minimumInterval
        self.now = now
    }

    // MARK: Public API

    /// Decides whether an App Open Ad request may be made.
    ///
    /// - Parameters:
    ///   - isFirstLaunch: `true` on the first-ever launch (rule 2).
    ///   - shownThisSession: `true` if an app open ad already showed this session (rule 3).
    ///   - lastShownAt: Timestamp of the last app open ad across sessions (rule 4).
    public func decide(
        isFirstLaunch: Bool,
        shownThisSession: Bool,
        lastShownAt: Date?
    ) -> Decision {
        if isFirstLaunch {
            return .skip(.firstLaunch)
        }
        if shownThisSession {
            return .skip(.sessionCap)
        }
        if let lastShownAt, now().timeIntervalSince(lastShownAt) < minimumInterval {
            return .skip(.frequencyCap)
        }
        return .eligible
    }
}

// MARK: - AppOpenAdStore

/// Persistence seam for the policy's cross-session facts.
public protocol AppOpenAdStore: AnyObject, Sendable {
    /// `false` until the first launch completes (drives rule 2).
    var hasCompletedFirstLaunch: Bool { get set }
    /// When the last app open ad was shown (drives rule 4).
    var lastAdShownAt: Date? { get set }
}

/// `UserDefaults`-backed store used in production.
///
/// `@unchecked Sendable`: `UserDefaults` is documented thread-safe.
public final class UserDefaultsAppOpenAdStore: AppOpenAdStore, @unchecked Sendable {

    private enum Key {
        static let firstLaunch = "appOpenAd.hasCompletedFirstLaunch"
        static let lastShown = "appOpenAd.lastShownAt"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasCompletedFirstLaunch: Bool {
        get { defaults.bool(forKey: Key.firstLaunch) }
        set { defaults.set(newValue, forKey: Key.firstLaunch) }
    }

    public var lastAdShownAt: Date? {
        get { defaults.object(forKey: Key.lastShown) as? Date }
        set { defaults.set(newValue, forKey: Key.lastShown) }
    }
}
