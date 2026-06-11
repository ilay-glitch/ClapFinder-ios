#if canImport(Testing)
import Foundation
import Testing
@testable import ClapFinderKitAds

// MARK: - InterstitialPolicy tests (ADS_DESIGN.md §6)

struct InterstitialPolicyTests {

    private let policy = InterstitialPolicy()

    // MARK: The contract test — never during detection (hard constraint 3)

    @Test("NEVER during active detection — even when every other condition allows the ad")
    func neverDuringDetection() {
        let decision = policy.decide(
            usesSinceLast: 100,
            threshold: 3,
            isDetectionActive: true,
            isAlarmActive: false,
            isAdLoaded: true
        )
        #expect(decision == .suppress(.detectionActive))
    }

    @Test("NEVER while the touch alert is armed or alarming")
    func neverDuringAlarm() {
        let decision = policy.decide(
            usesSinceLast: 100,
            threshold: 3,
            isDetectionActive: false,
            isAlarmActive: true,
            isAdLoaded: true
        )
        #expect(decision == .suppress(.alarmActive))
    }

    @Test("Detection suppression outranks alarm and frequency reasons")
    func suppressReasonPriority() {
        let decision = policy.decide(
            usesSinceLast: 0,
            threshold: 5,
            isDetectionActive: true,
            isAlarmActive: true,
            isAdLoaded: false
        )
        #expect(decision == .suppress(.detectionActive))
    }

    // MARK: Frequency cap

    @Test("threshold−1 uses is suppressed; threshold uses shows")
    func frequencyBoundary() {
        let below = policy.decide(
            usesSinceLast: 2, threshold: 3,
            isDetectionActive: false, isAlarmActive: false, isAdLoaded: true
        )
        #expect(below == .suppress(.frequencyCap))

        let at = policy.decide(
            usesSinceLast: 3, threshold: 3,
            isDetectionActive: false, isAlarmActive: false, isAdLoaded: true
        )
        #expect(at == .show)
    }

    @Test("No loaded ad at an eligible moment suppresses with not_loaded")
    func notLoadedSuppresses() {
        let decision = policy.decide(
            usesSinceLast: 5, threshold: 3,
            isDetectionActive: false, isAlarmActive: false, isAdLoaded: false
        )
        #expect(decision == .suppress(.notLoaded))
    }

    // MARK: Threshold draw

    @Test("Injected draw is used and clamped into 3...5")
    func thresholdInjectedAndClamped() {
        #expect(InterstitialPolicy(drawThreshold: { 4 }).newThreshold() == 4)
        #expect(InterstitialPolicy(drawThreshold: { 1 }).newThreshold() == 3)
        #expect(InterstitialPolicy(drawThreshold: { 99 }).newThreshold() == 5)
    }

    @Test("Default draw stays in 3...5 across many draws")
    func defaultDrawInRange() {
        let policy = InterstitialPolicy()
        for _ in 0..<200 {
            let value = policy.newThreshold()
            #expect(InterstitialPolicy.thresholdRange.contains(value))
        }
    }

    // MARK: Analytics schema

    @Test("Suppress reason raw values match EVENTS.md")
    func suppressReasonRawValues() {
        #expect(InterstitialPolicy.SuppressReason.detectionActive.rawValue == "detection_active")
        #expect(InterstitialPolicy.SuppressReason.alarmActive.rawValue == "alarm_active")
        #expect(InterstitialPolicy.SuppressReason.frequencyCap.rawValue == "frequency_cap")
        #expect(InterstitialPolicy.SuppressReason.notLoaded.rawValue == "not_loaded")

        let shown = AdPlacementAnalytics.interstitialShown(usesSinceLast: 4)
        #expect(shown.name == "interstitial_shown")
        #expect(shown.params["uses_since_last"] == .int(4))

        let suppressed = AdPlacementAnalytics.interstitialSuppressed(reason: .frequencyCap)
        #expect(suppressed.params["reason"] == .string("frequency_cap"))
    }
}

#endif
