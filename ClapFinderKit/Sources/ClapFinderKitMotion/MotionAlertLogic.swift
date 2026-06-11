import ClapFinderKitData
import Foundation

// MARK: - Sensitivity → motion thresholds

public extension Sensitivity {
    /// Motion trigger threshold in g (user-acceleration magnitude,
    /// gravity removed). TOUCH_ALERT_DESIGN.md §5 — ship as defaults,
    /// calibrated during the consolidated device QA pass.
    var motionThresholdG: Double {
        switch self {
        case .low:
            return 0.15     // deliberate pickup
        case .medium:
            return 0.08     // default
        case .high:
            return 0.04     // nudge / table bump
        }
    }
}

// MARK: - MotionAlertLogic

/// Pure state machine for the touch-alert arm → grace → monitor → alarm
/// cycle (TOUCH_ALERT_DESIGN.md §5, §6).
///
/// No `Date()` calls inside — every transition receives the current time
/// from the caller (same clock-seam pattern as `AppOpenAdPolicy`), so the
/// grace-period tests never sleep.
///
/// Trigger rule: **2 consecutive samples** above the sensitivity
/// threshold (rejects single-sample sensor spikes; a below-threshold
/// sample resets the count).
public struct MotionAlertLogic: Equatable, Sendable {

    // MARK: Types

    public enum State: Equatable, Sendable {
        case disarmed
        /// Armed, inside the grace period — samples are ignored.
        case grace
        /// Armed and actively monitoring.
        case monitoring
        /// Motion detected — alarm is sounding until disarm.
        case alarming
    }

    // MARK: Constants

    /// Seconds after arming during which samples are ignored
    /// (lets the user put the phone down).
    public let gracePeriod: TimeInterval

    /// Consecutive above-threshold samples required to trigger.
    public let samplesToTrigger: Int

    // MARK: State

    public private(set) var state: State = .disarmed
    public private(set) var sensitivity: Sensitivity = .medium
    private var armedAt: Date?
    private var consecutiveAbove = 0

    // MARK: Init

    public init(gracePeriod: TimeInterval = 5.0, samplesToTrigger: Int = 2) {
        self.gracePeriod = gracePeriod
        self.samplesToTrigger = samplesToTrigger
    }

    // MARK: Transitions

    /// Arms detection. No-op unless disarmed.
    public mutating func arm(sensitivity: Sensitivity, at now: Date) {
        guard state == .disarmed else { return }
        self.sensitivity = sensitivity
        armedAt = now
        consecutiveAbove = 0
        state = .grace
    }

    /// Disarms from any armed state (grace, monitoring, or alarming).
    /// - Returns: `true` if the alarm was sounding when disarmed.
    @discardableResult
    public mutating func disarm() -> Bool {
        let wasAlarming = state == .alarming
        state = .disarmed
        armedAt = nil
        consecutiveAbove = 0
        return wasAlarming
    }

    /// Feeds one user-acceleration magnitude sample (in g).
    /// - Returns: `true` exactly when this sample triggers the alarm.
    @discardableResult
    public mutating func processSample(magnitude: Double, at now: Date) -> Bool {
        switch state {
        case .disarmed, .alarming:
            return false

        case .grace:
            guard let armedAt, now.timeIntervalSince(armedAt) >= gracePeriod else {
                return false
            }
            // Grace expired — this sample counts as the first monitored one.
            state = .monitoring
            return evaluate(magnitude: magnitude)

        case .monitoring:
            return evaluate(magnitude: magnitude)
        }
    }

    /// Seconds since arming, for the `grace_elapsed_s` analytics param.
    public func secondsSinceArmed(at now: Date) -> Int {
        guard let armedAt else { return 0 }
        return Int(now.timeIntervalSince(armedAt))
    }

    // MARK: Private

    private mutating func evaluate(magnitude: Double) -> Bool {
        if magnitude > sensitivity.motionThresholdG {
            consecutiveAbove += 1
            if consecutiveAbove >= samplesToTrigger {
                state = .alarming
                return true
            }
        } else {
            consecutiveAbove = 0
        }
        return false
    }
}
