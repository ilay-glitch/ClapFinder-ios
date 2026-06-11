#if canImport(Testing)
import Foundation
import Testing
@testable import ClapFinderKitData
@testable import ClapFinderKitMotion

// MARK: - MotionAlertLogic tests
//
// All time arrives as injected Date values — no sleeping
// (TOUCH_ALERT_DESIGN.md §5, §9).

struct MotionAlertLogicTests {

    private let base = Date(timeIntervalSince1970: 1_750_000_000)

    /// Logic armed at `base` with the given sensitivity.
    private func armed(_ sensitivity: Sensitivity = .medium) -> MotionAlertLogic {
        var logic = MotionAlertLogic()
        logic.arm(sensitivity: sensitivity, at: base)
        return logic
    }

    /// A timestamp safely past the grace period.
    private var afterGrace: Date { base.addingTimeInterval(6.0) }

    // MARK: Grace period — the canonical t+4.9 / t+5.1 pair

    @Test("Sample at t+4.9s is inside grace — ignored even above threshold")
    func graceIgnoresSamples() {
        var logic = armed()
        let fired = logic.processSample(magnitude: 1.0, at: base.addingTimeInterval(4.9))
        #expect(!fired)
        #expect(logic.state == .grace)
    }

    @Test("Sample at t+5.1s is past grace — counts toward trigger")
    func gracePassedSampleCounts() {
        var logic = armed()
        let fired = logic.processSample(magnitude: 1.0, at: base.addingTimeInterval(5.1))
        #expect(!fired)   // first of 2 required samples
        #expect(logic.state == .monitoring)
    }

    @Test("Exactly t+5.0s is past grace (boundary is inclusive)")
    func graceBoundaryInclusive() {
        var logic = armed()
        logic.processSample(magnitude: 1.0, at: base.addingTimeInterval(5.0))
        #expect(logic.state == .monitoring)
    }

    // MARK: 2-consecutive-samples rule

    @Test("Two consecutive above-threshold samples trigger the alarm")
    func twoConsecutiveTrigger() {
        var logic = armed()
        let first = logic.processSample(magnitude: 0.2, at: afterGrace)
        let second = logic.processSample(magnitude: 0.2, at: afterGrace)
        #expect(!first)
        #expect(second)
        #expect(logic.state == .alarming)
    }

    @Test("spike-quiet-spike does NOT trigger — quiet resets the count")
    func quietResetsCount() {
        var logic = armed()
        let spike1 = logic.processSample(magnitude: 0.2, at: afterGrace)
        let quiet = logic.processSample(magnitude: 0.01, at: afterGrace)
        let spike2 = logic.processSample(magnitude: 0.2, at: afterGrace)
        #expect(!spike1)
        #expect(!quiet)
        #expect(!spike2)
        #expect(logic.state == .monitoring)
    }

    @Test("Samples while alarming are ignored — no retrigger")
    func alarmingIgnoresSamples() {
        var logic = armed()
        logic.processSample(magnitude: 0.2, at: afterGrace)
        logic.processSample(magnitude: 0.2, at: afterGrace)
        let fired = logic.processSample(magnitude: 1.0, at: afterGrace)
        #expect(!fired)
        #expect(logic.state == .alarming)
    }

    // MARK: Threshold × sensitivity matrix

    @Test("Low (0.15g): 0.14 below / 0.16 above", arguments: [
        (0.14, false), (0.16, true)
    ])
    func lowThreshold(magnitude: Double, shouldTrigger: Bool) {
        var logic = armed(.low)
        logic.processSample(magnitude: magnitude, at: afterGrace)
        let fired = logic.processSample(magnitude: magnitude, at: afterGrace)
        #expect(fired == shouldTrigger)
    }

    @Test("Medium (0.08g): 0.07 below / 0.09 above", arguments: [
        (0.07, false), (0.09, true)
    ])
    func mediumThreshold(magnitude: Double, shouldTrigger: Bool) {
        var logic = armed(.medium)
        logic.processSample(magnitude: magnitude, at: afterGrace)
        let fired = logic.processSample(magnitude: magnitude, at: afterGrace)
        #expect(fired == shouldTrigger)
    }

    @Test("High (0.04g): 0.03 below / 0.05 above", arguments: [
        (0.03, false), (0.05, true)
    ])
    func highThreshold(magnitude: Double, shouldTrigger: Bool) {
        var logic = armed(.high)
        logic.processSample(magnitude: magnitude, at: afterGrace)
        let fired = logic.processSample(magnitude: magnitude, at: afterGrace)
        #expect(fired == shouldTrigger)
    }

    @Test("Exactly at threshold does not count (strictly greater)")
    func exactThresholdBelow() {
        var logic = armed(.medium)
        logic.processSample(magnitude: 0.08, at: afterGrace)
        let fired = logic.processSample(magnitude: 0.08, at: afterGrace)
        #expect(!fired)
        #expect(logic.state == .monitoring)
    }

    // MARK: Arm / disarm transitions

    @Test("Disarm during grace returns to disarmed, reports not alarming")
    func disarmDuringGrace() {
        var logic = armed()
        let wasAlarming = logic.disarm()
        #expect(!wasAlarming)
        #expect(logic.state == .disarmed)
    }

    @Test("Disarm while alarming reports wasAlarming")
    func disarmWhileAlarming() {
        var logic = armed()
        logic.processSample(magnitude: 0.5, at: afterGrace)
        logic.processSample(magnitude: 0.5, at: afterGrace)
        let wasAlarming = logic.disarm()
        #expect(wasAlarming)
        #expect(logic.state == .disarmed)
    }

    @Test("Re-arm after an alarm starts a fresh grace period")
    func rearmAfterAlarm() {
        var logic = armed()
        logic.processSample(magnitude: 0.5, at: afterGrace)
        logic.processSample(magnitude: 0.5, at: afterGrace)
        logic.disarm()

        let rearmTime = base.addingTimeInterval(100)
        logic.arm(sensitivity: .high, at: rearmTime)
        #expect(logic.state == .grace)
        // Inside the NEW grace window — ignored
        let fired = logic.processSample(magnitude: 1.0, at: rearmTime.addingTimeInterval(2))
        #expect(!fired)
    }

    @Test("Arm while already armed is a no-op (keeps original grace clock)")
    func armIsIdempotent() {
        var logic = armed(.medium)
        logic.arm(sensitivity: .high, at: base.addingTimeInterval(100))
        #expect(logic.sensitivity == .medium)
        // Original grace clock: t+5.1 from the FIRST arm is monitoring
        logic.processSample(magnitude: 1.0, at: base.addingTimeInterval(5.1))
        #expect(logic.state == .monitoring)
    }

    @Test("Samples while disarmed are ignored")
    func disarmedIgnoresSamples() {
        var logic = MotionAlertLogic()
        let fired = logic.processSample(magnitude: 1.0, at: base)
        #expect(!fired)
        #expect(logic.state == .disarmed)
    }

    // MARK: Analytics helper

    @Test("secondsSinceArmed reports whole seconds since arm")
    func secondsSinceArmed() {
        let logic = armed()
        #expect(logic.secondsSinceArmed(at: base.addingTimeInterval(42.7)) == 42)
    }
}

#endif
