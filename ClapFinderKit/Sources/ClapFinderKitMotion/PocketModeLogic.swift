import Foundation

// MARK: - PocketModeLogic

/// Pure state machine for the pocket-mode arm → pocket-in → monitor → alarm
/// cycle (POCKET_MODE_DESIGN.md §3).
///
/// No `Date()` calls inside — every transition receives the current time from
/// the caller (clock-seam pattern, same as `MotionAlertLogic`), so the
/// debounce tests never sleep.
///
/// Debounce rules (§3): covering must be sustained ≥ `coverDebounce` before
/// the guard engages (rejects hand-shadow flicker while pocketing); uncovering
/// must be sustained ≥ `uncoverDebounce` before the alarm fires (rejects
/// loose-fabric flicker). A flicker back to the previous sensor state clears
/// the pending transition.
public struct PocketModeLogic: Equatable, Sendable {

    // MARK: Types

    public enum State: Equatable, Sendable {
        case disarmed
        /// Armed, waiting for the phone to be pocketed (sensor uncovered).
        case awaitingPocket
        /// Pocketed and on duty — a sustained uncover triggers the alarm.
        case monitoring
        /// Pulled out — alarm is sounding until disarm.
        case alarming
    }

    /// Transition produced by `evaluate(at:)` once a debounce elapses.
    public enum Event: Equatable, Sendable {
        /// Cover sustained — the guard engaged (chirp moment).
        case engaged
        /// Uncover sustained — the phone was pulled out.
        case alarm
    }

    // MARK: Constants

    /// Sustained-cover time required to engage (§3: 1.5 s).
    public let coverDebounce: TimeInterval

    /// Sustained-uncover time required to alarm (§3: 0.5 s).
    public let uncoverDebounce: TimeInterval

    // MARK: State

    public private(set) var state: State = .disarmed
    private var armedAt: Date?
    /// Pending-cover edge while awaiting pocket (nil = uncovered/no edge).
    private var coveredSince: Date?
    /// Pending-uncover edge while monitoring (nil = covered/no edge).
    private var uncoveredSince: Date?

    // MARK: Init

    public init(coverDebounce: TimeInterval = 1.5, uncoverDebounce: TimeInterval = 0.5) {
        self.coverDebounce = coverDebounce
        self.uncoverDebounce = uncoverDebounce
    }

    // MARK: Transitions

    /// Arms pocket mode. No-op unless disarmed.
    public mutating func arm(at now: Date) {
        guard state == .disarmed else { return }
        armedAt = now
        coveredSince = nil
        uncoveredSince = nil
        state = .awaitingPocket
    }

    /// Disarms from any armed state.
    /// - Returns: `true` if the alarm was sounding when disarmed.
    @discardableResult
    public mutating func disarm() -> Bool {
        let wasAlarming = state == .alarming
        state = .disarmed
        armedAt = nil
        coveredSince = nil
        uncoveredSince = nil
        return wasAlarming
    }

    /// Feeds a proximity-sensor edge. Repeated reports of the same value do
    /// NOT reset a pending debounce (the sensor only posts on change, but the
    /// logic is defensive about duplicates).
    public mutating func setCovered(_ covered: Bool, at now: Date) {
        switch state {
        case .disarmed, .alarming:
            break

        case .awaitingPocket:
            if covered {
                if coveredSince == nil { coveredSince = now }
            } else {
                coveredSince = nil  // flicker — restart the cover debounce
            }

        case .monitoring:
            if covered {
                uncoveredSince = nil  // flicker recovered — still pocketed
            } else {
                if uncoveredSince == nil { uncoveredSince = now }
            }
        }
    }

    /// Checks whether a pending debounce has elapsed and performs the
    /// transition. Call after `coverDebounce`/`uncoverDebounce` has passed
    /// since the edge (the coordinator schedules this).
    /// - Returns: the transition that fired, if any.
    @discardableResult
    public mutating func evaluate(at now: Date) -> Event? {
        switch state {
        case .disarmed, .alarming:
            return nil

        case .awaitingPocket:
            guard let coveredSince, now.timeIntervalSince(coveredSince) >= coverDebounce else {
                return nil
            }
            self.coveredSince = nil
            state = .monitoring
            return .engaged

        case .monitoring:
            guard let uncoveredSince, now.timeIntervalSince(uncoveredSince) >= uncoverDebounce else {
                return nil
            }
            self.uncoveredSince = nil
            state = .alarming
            return .alarm
        }
    }

    /// Seconds since arming, for the `armed_duration_s` analytics param.
    public func secondsSinceArmed(at now: Date) -> Int {
        guard let armedAt else { return 0 }
        return Int(now.timeIntervalSince(armedAt))
    }
}
