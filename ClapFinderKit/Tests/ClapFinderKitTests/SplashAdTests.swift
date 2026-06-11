#if canImport(Testing)
import Foundation
import Testing
@testable import ClapFinderKitAds

// MARK: - AppOpenAdPolicy tests
//
// The clock is injected — interval tests move a fixed date instead of
// sleeping (SPLASH_DESIGN.md §9, §10).

struct AppOpenAdPolicyTests {

    /// Fixed reference instant for all interval math.
    private let base = Date(timeIntervalSince1970: 1_750_000_000)

    private func policy(now: Date) -> AppOpenAdPolicy {
        AppOpenAdPolicy(now: { now })
    }

    // MARK: First launch (rule 2)

    @Test("First launch is suppressed even with no other caps active")
    func firstLaunchSuppressed() {
        let decision = policy(now: base).decide(
            isFirstLaunch: true,
            shownThisSession: false,
            lastShownAt: nil
        )
        #expect(decision == .skip(.firstLaunch))
    }

    @Test("First launch wins over other skip reasons")
    func firstLaunchTakesPriority() {
        let decision = policy(now: base).decide(
            isFirstLaunch: true,
            shownThisSession: true,
            lastShownAt: base
        )
        #expect(decision == .skip(.firstLaunch))
    }

    // MARK: Session cap (rule 3)

    @Test("Second ad in the same session is suppressed")
    func sessionCapSuppressed() {
        let decision = policy(now: base).decide(
            isFirstLaunch: false,
            shownThisSession: true,
            lastShownAt: nil
        )
        #expect(decision == .skip(.sessionCap))
    }

    // MARK: Frequency cap (rule 4) — the canonical t+3:59 / t+4:01 pair

    @Test("3h59m after the last ad is still frequency-capped")
    func threeFiftyNineDenied() {
        let lastShown = base
        let now = base.addingTimeInterval(3 * 3600 + 59 * 60)
        let decision = policy(now: now).decide(
            isFirstLaunch: false,
            shownThisSession: false,
            lastShownAt: lastShown
        )
        #expect(decision == .skip(.frequencyCap))
    }

    @Test("4h01m after the last ad is eligible")
    func fourOhOneAllowed() {
        let lastShown = base
        let now = base.addingTimeInterval(4 * 3600 + 60)
        let decision = policy(now: now).decide(
            isFirstLaunch: false,
            shownThisSession: false,
            lastShownAt: lastShown
        )
        #expect(decision == .eligible)
    }

    @Test("Exactly 4h00m is eligible (interval is a strict minimum)")
    func exactlyFourHoursAllowed() {
        let now = base.addingTimeInterval(4 * 3600)
        let decision = policy(now: now).decide(
            isFirstLaunch: false,
            shownThisSession: false,
            lastShownAt: base
        )
        #expect(decision == .eligible)
    }

    @Test("No prior ad ever means eligible")
    func noHistoryEligible() {
        let decision = policy(now: base).decide(
            isFirstLaunch: false,
            shownThisSession: false,
            lastShownAt: nil
        )
        #expect(decision == .eligible)
    }
}

// MARK: - SplashStateMachine tests

struct SplashStateMachineTests {

    private func readyMachine() -> SplashStateMachine {
        var machine = SplashStateMachine()
        machine.apply(.catalogLoaded)
        machine.apply(.minTimerFired)
        return machine
    }

    // MARK: Happy ad path

    @Test("Eligible → loaded → present → dismissed → finished(adShown)")
    func happyAdPath() {
        var machine = readyMachine()
        machine.apply(.adDecided(.eligible))
        #expect(machine.wantsAdRequest)
        machine.apply(.adLoaded)
        #expect(machine.state == .presentingAd)
        machine.apply(.adDismissed)
        #expect(machine.state == .finished(adShown: true, skipReason: .none))
    }

    // MARK: Skip paths

    @Test("Ineligible (frequency cap) goes straight to finished")
    func ineligibleFinishes() {
        var machine = readyMachine()
        machine.apply(.adDecided(.skip(.frequencyCap)))
        #expect(machine.state == .finished(adShown: false, skipReason: .frequencyCap))
    }

    @Test("Load failure finishes without an ad, reason load_failed")
    func failureFinishes() {
        var machine = readyMachine()
        machine.apply(.adDecided(.eligible))
        machine.apply(.adFailed("no fill"))
        #expect(machine.state == .finished(adShown: false, skipReason: .loadFailed))
    }

    @Test("Timeout finishes without an ad, reason timeout")
    func timeoutFinishes() {
        var machine = readyMachine()
        machine.apply(.adDecided(.eligible))
        machine.apply(.adTimedOut)
        #expect(machine.state == .finished(adShown: false, skipReason: .timeout))
    }

    // MARK: Late-ad discard (§6 rule 5)

    @Test("Ad loading after timeout is discarded — splash stays finished")
    func lateAdDiscarded() {
        var machine = readyMachine()
        machine.apply(.adDecided(.eligible))
        machine.apply(.adTimedOut)
        let finished = machine.state
        machine.apply(.adLoaded)
        #expect(machine.state == finished)
        #expect(machine.adPhase == .timedOut)
    }

    // MARK: Resume idempotence

    @Test("Replayed adDecided after resume never re-requests")
    func decisionIsIdempotent() {
        var machine = readyMachine()
        machine.apply(.adDecided(.eligible))
        machine.apply(.adLoaded)
        // App backgrounds mid-splash; on resume the caller replays the decision.
        machine.apply(.adDecided(.eligible))
        #expect(!machine.wantsAdRequest)
        #expect(machine.state == .presentingAd)
    }

    @Test("Skip decision replayed over an in-flight request is ignored")
    func skipReplayIgnoredWhileRequesting() {
        var machine = readyMachine()
        machine.apply(.adDecided(.eligible))
        machine.apply(.adDecided(.skip(.sessionCap)))
        #expect(machine.wantsAdRequest)
    }

    // MARK: Barrier — splash never ends early

    @Test("Loaded ad does not present before the minimum timer fires")
    func adWaitsForMinTimer() {
        var machine = SplashStateMachine()
        machine.apply(.catalogLoaded)
        machine.apply(.adDecided(.eligible))
        machine.apply(.adLoaded)
        #expect(machine.state == .loading)
        machine.apply(.minTimerFired)
        #expect(machine.state == .presentingAd)
    }

    @Test("Finished is terminal — further events are ignored")
    func finishedIsTerminal() {
        var machine = readyMachine()
        machine.apply(.adDecided(.skip(.firstLaunch)))
        let finished = machine.state
        machine.apply(.adLoaded)
        machine.apply(.adDismissed)
        machine.apply(.catalogLoaded)
        #expect(machine.state == finished)
    }
}

// MARK: - Progress function tests (SPLASH_DESIGN.md §5)

struct SplashProgressTests {

    @Test("Progress is monotonic even when readiness inputs regress")
    func monotonic() {
        let first = SplashStateMachine.progress(
            elapsed: 1.5, catalogLoaded: true, adResolved: true, previous: 0
        )
        let second = SplashStateMachine.progress(
            elapsed: 1.6, catalogLoaded: false, adResolved: false, previous: first
        )
        #expect(second >= first)
    }

    @Test("Never reaches 100% before the minimum duration")
    func neverDoneBeforeMinTimer() {
        let value = SplashStateMachine.progress(
            elapsed: 0.75, catalogLoaded: true, adResolved: true, previous: 0
        )
        #expect(value < 1.0)
        #expect(value == 0.5)
    }

    @Test("Reaches exactly 100% when everything is ready past min duration")
    func completesWhenReady() {
        let value = SplashStateMachine.progress(
            elapsed: 2.0, catalogLoaded: true, adResolved: true, previous: 0.8
        )
        #expect(value == 1.0)
    }

    @Test("Caps at catalog weight while the ad is unresolved")
    func capsAtReadiness() {
        let value = SplashStateMachine.progress(
            elapsed: 3.0, catalogLoaded: true, adResolved: false, previous: 0
        )
        #expect(value == 0.3)
    }
}

// MARK: - Analytics schema tests (EVENTS.md)

struct SplashAnalyticsTests {

    @Test("splash_completed carries duration, ad_shown, and skip reason")
    func splashCompletedParams() {
        let event = SplashAnalytics.splashCompleted(
            durationMs: 1812,
            adShown: false,
            skipReason: .frequencyCap
        )
        #expect(event.name == "splash_completed")
        #expect(event.params["duration_ms"] == .int(1812))
        #expect(event.params["ad_shown"] == .bool(false))
        #expect(event.params["ad_skip_reason"] == .string("frequency_cap"))
    }

    @Test("Skip reason raw values match the EVENTS.md enum")
    func skipReasonRawValues() {
        #expect(AdSkipReason.none.rawValue == "none")
        #expect(AdSkipReason.firstLaunch.rawValue == "first_launch")
        #expect(AdSkipReason.frequencyCap.rawValue == "frequency_cap")
        #expect(AdSkipReason.sessionCap.rawValue == "session_cap")
        #expect(AdSkipReason.loadFailed.rawValue == "load_failed")
        #expect(AdSkipReason.timeout.rawValue == "timeout")
    }

    @Test("Event names match EVENTS.md schema")
    func eventNames() {
        #expect(SplashAnalytics.splashShown(coldLaunch: true, firstLaunch: false).name == "splash_shown")
        #expect(SplashAnalytics.adRequested(attAuthorized: false).name == "app_open_ad_requested")
        #expect(SplashAnalytics.adShown().name == "app_open_ad_shown")
        #expect(SplashAnalytics.adFailed(errorReason: "x").name == "app_open_ad_failed")
        #expect(SplashAnalytics.adTimeout(elapsedMs: 5000).name == "app_open_ad_timeout")
    }
}

#endif
