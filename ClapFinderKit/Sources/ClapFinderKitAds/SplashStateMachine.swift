import Foundation

// MARK: - SplashStateMachine

/// Pure state machine for the splash → (ad | skip) → home cycle
/// (SPLASH_DESIGN.md §7).
///
/// Time never appears inside the machine — the 1.5 s minimum timer and
/// the 5 s ad timeout arrive as `Event`s from the caller. Every path
/// is therefore unit-testable without sleeping.
///
/// Guarantees encoded here:
/// - An ad request is decided at most once (`adDecided` ignored unless
///   the ad phase is `.idle`) — a backgrounded/resumed splash can
///   replay events without re-requesting.
/// - A late `adLoaded` after `adTimedOut` is discarded (never shown).
/// - `finished` is terminal.
public struct SplashStateMachine: Equatable, Sendable {

    // MARK: Types

    /// Where the ad sub-flow currently stands.
    public enum AdPhase: Equatable, Sendable {
        case idle
        case skipped(AdSkipReason)
        case requesting
        case loaded
        case presenting
        case failed(String)
        case timedOut
        case dismissed
    }

    /// Overall splash state.
    public enum State: Equatable, Sendable {
        case loading
        case presentingAd
        case finished(adShown: Bool, skipReason: AdSkipReason)
    }

    /// External happenings, including elapsed-time milestones.
    public enum Event: Equatable, Sendable {
        case catalogLoaded
        case minTimerFired
        case adDecided(AppOpenAdPolicy.Decision)
        case adLoaded
        case adFailed(String)
        case adTimedOut
        case adDismissed
    }

    // MARK: State

    public private(set) var state: State = .loading
    public private(set) var adPhase: AdPhase = .idle
    public private(set) var catalogLoaded = false
    public private(set) var minTimerDone = false

    // MARK: Init

    public init() {}

    // MARK: Derived

    /// `true` once the ad sub-flow can no longer block the splash
    /// (loaded, skipped, failed, or timed out). Drives the 70 % progress
    /// component (SPLASH_DESIGN.md §5).
    public var adResolved: Bool {
        switch adPhase {
        case .idle, .requesting:
            return false
        case .skipped, .loaded, .presenting, .failed, .timedOut, .dismissed:
            return true
        }
    }

    /// `true` exactly when the caller should fire the real SDK request.
    public var wantsAdRequest: Bool {
        adPhase == .requesting
    }

    // MARK: Events

    public mutating func apply(_ event: Event) {
        if case .finished = state { return }

        switch event {
        case .catalogLoaded:
            catalogLoaded = true
        case .minTimerFired:
            minTimerDone = true
        case .adDecided, .adLoaded, .adFailed, .adTimedOut, .adDismissed:
            applyAdEvent(event)
        }

        advance()
    }

    private mutating func applyAdEvent(_ event: Event) {
        switch event {
        case .adDecided(let decision):
            applyDecision(decision)
        case .adLoaded:
            // Late load after timeout/failure is discarded (§6 rule 5).
            transitionFromRequesting(to: .loaded)
        case .adFailed(let reason):
            transitionFromRequesting(to: .failed(reason))
        case .adTimedOut:
            transitionFromRequesting(to: .timedOut)
        case .adDismissed:
            guard state == .presentingAd else { return }
            adPhase = .dismissed
        case .catalogLoaded, .minTimerFired:
            break
        }
    }

    /// Decide once. Replays (e.g. after background/resume) are no-ops.
    private mutating func applyDecision(_ decision: AppOpenAdPolicy.Decision) {
        guard adPhase == .idle else { return }
        switch decision {
        case .eligible:
            adPhase = .requesting
        case .skip(let reason):
            adPhase = .skipped(reason)
        }
    }

    /// Loaded / failed / timed-out only ever apply to an in-flight request.
    private mutating func transitionFromRequesting(to phase: AdPhase) {
        guard adPhase == .requesting else { return }
        adPhase = phase
    }

    // MARK: Private

    private mutating func advance() {
        switch state {
        case .loading:
            guard catalogLoaded, minTimerDone, adResolved else { return }
            if adPhase == .loaded {
                adPhase = .presenting
                state = .presentingAd
            } else {
                state = .finished(adShown: false, skipReason: skipReason)
            }

        case .presentingAd:
            if adPhase == .dismissed {
                state = .finished(adShown: true, skipReason: .none)
            }

        case .finished:
            break
        }
    }

    private var skipReason: AdSkipReason {
        switch adPhase {
        case .skipped(let reason):
            return reason
        case .failed:
            return .loadFailed
        case .timedOut:
            return .timeout
        case .idle, .requesting, .loaded, .presenting, .dismissed:
            return .none
        }
    }

    // MARK: Progress (SPLASH_DESIGN.md §5)

    /// Real-readiness progress for the splash bar.
    ///
    /// `max(previous, min(elapsed/minDuration, readiness))` — monotonic,
    /// never ahead of readiness, never done before the minimum duration.
    /// `readiness = 0.3 × catalog + 0.7 × adResolved`.
    public static func progress(
        elapsed: TimeInterval,
        minDuration: TimeInterval = 1.5,
        catalogLoaded: Bool,
        adResolved: Bool,
        previous: Double
    ) -> Double {
        let catalogPart = catalogLoaded ? 0.3 : 0.0
        let adPart = adResolved ? 0.7 : 0.0
        let readiness = catalogPart + adPart
        let timeFactor = minDuration > 0 ? min(elapsed / minDuration, 1.0) : 1.0
        return min(max(previous, min(timeFactor, readiness)), 1.0)
    }
}
