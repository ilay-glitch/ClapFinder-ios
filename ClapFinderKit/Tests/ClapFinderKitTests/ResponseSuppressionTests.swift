#if canImport(Testing)
import Testing
import Foundation
@_spi(Testing) @testable import ClapFinderKitAudio
@testable import ClapFinderKitData

// MARK: - Feedback-loop suppression tests
//
// Pins the fix for the device-confirmed feedback loop: the alert re-triggering
// detection through the mic, with echo ACCEPTs chaining at 1.3–2.5 s spacing.
// The grace is anchored to AUTHORITATIVE playback end (not trigger
// observations) because the detector's cooldown means no triggers arrive
// during playback — the exact hole that broke the first fix on-device.

@Suite("ResponseSuppression")
struct ResponseSuppressionTests {

    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)
    private func at(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

    @Test("Trigger while the sound is playing is suppressed")
    func suppressedWhilePlaying() {
        let sup = ResponseSuppression()
        #expect(sup.shouldSuppress(isPlaying: true, playbackEndedAt: nil, now: at(0)))
    }

    @Test("THE device failure sequence: echo after playback end + cooldown is suppressed")
    func deviceFailureSequenceSuppressed() {
        // Bark fires at t=0 (respond + seed). NO triggers arrive during
        // playback (detector cooldown eats them). Playback ends at t=1.8.
        // The echo re-pairs the FSM at t=2.5 — after the old 1.0s seeded tail,
        // which is exactly how the loop escaped on-device.
        var sup = ResponseSuppression()
        sup.responseStarted(now: at(0))
        let echo = sup.shouldSuppress(isPlaying: false, playbackEndedAt: at(1.8), now: at(2.5))
        #expect(echo, "echo inside playbackEnd+grace must be suppressed even with no triggers during playback")
        // Well after the tail → a genuine clap passes.
        let genuine = sup.shouldSuppress(isPlaying: false, playbackEndedAt: at(1.8), now: at(3.5))
        #expect(!genuine)
    }

    @Test("Grace is anchored to playback END, not response start")
    func anchoredToPlaybackEnd() {
        var sup = ResponseSuppression()
        sup.responseStarted(now: at(0))
        // Long sound: ends at t=3.0. A trigger at t=2.0 (sound still playing).
        #expect(sup.shouldSuppress(isPlaying: true, playbackEndedAt: nil, now: at(2.0)))
        // After end at 3.0: covered until 4.5 regardless of the old seed.
        #expect(sup.shouldSuppress(isPlaying: false, playbackEndedAt: at(3.0), now: at(4.4)))
        #expect(!sup.shouldSuppress(isPlaying: false, playbackEndedAt: at(3.0), now: at(4.51)))
    }

    @Test("responseStarted seeds a grace for failed/instant playback")
    func seedCoversFailedPlayback() {
        var sup = ResponseSuppression()
        sup.responseStarted(now: at(0))     // sound missing → isPlaying never true
        let inSeed = sup.shouldSuppress(isPlaying: false, playbackEndedAt: nil, now: at(1.0))
        let after = sup.shouldSuppress(isPlaying: false, playbackEndedAt: nil, now: at(1.6))
        #expect(inSeed && !after)
    }

    @Test("No response ever → nothing suppressed")
    func idleNeverSuppresses() {
        let sup = ResponseSuppression()
        #expect(!sup.shouldSuppress(isPlaying: false, playbackEndedAt: nil, now: at(100)))
    }

    // MARK: Through the coordinator (the wiring)

    @Test("Coordinator ignores detector triggers during + shortly after a response")
    @MainActor
    func coordinatorSuppressesFeedback() {
        let coordinator = ResponseCoordinator()
        let dog = Animal(id: "dog", name: "Dog", emoji: "🐕", soundFile: "dog_bark.caf")
        let bundle = Bundle.module

        // First trigger → responds and seeds the grace.
        coordinator.handleTrigger(animal: dog, bundle: bundle, now: at(0))
        #expect(coordinator.lastTriggeredAnimal == dog)

        // Re-trigger inside the seeded grace → ignored (no second response).
        let ghost = Animal(id: "ghost", name: "Ghost", emoji: "👻", soundFile: "ghost.caf")
        coordinator.handleTrigger(animal: ghost, bundle: bundle, now: at(1.0))
        #expect(coordinator.lastTriggeredAnimal == dog, "trigger in the grace must be ignored")

        // Genuine trigger after the grace AND the 10 s rate limit → responds.
        coordinator.handleTrigger(animal: ghost, bundle: bundle, now: at(11.0))
        #expect(coordinator.lastTriggeredAnimal == ghost)
    }
}
#endif

// MARK: - Hard feed gate + rate limit (2026-07-02 reconstruction fixes)

@Suite("HardFeedGate")
struct HardFeedGateTests {

    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)
    private func at(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

    @Test("feedGate=true drops buffers wholesale — a loud pair cannot fire")
    @MainActor
    func gateBlocksPairs() {
        let detector = ClapDetector()
        var fired = false
        detector.onClapDetected = { fired = true }
        detector.setListeningForTesting(true, sensitivity: .medium)
        detector.feedGate = { true }
        detector.processSample(dBFS: -20, crest: 5, at: at(0.00))
        detector.processSample(dBFS: -40, crest: 1, at: at(0.05))
        detector.processSample(dBFS: -20, crest: 5, at: at(0.15))
        #expect(!fired, "gated buffers must never reach the FSM")
    }

    @Test("THE firstClap-seeding leak is closed: gated tail can't pair with a post-gate transient")
    @MainActor
    func gatedTailCannotSeedFirstClap() {
        let detector = ClapDetector()
        var fired = false
        detector.onClapDetected = { fired = true }
        detector.setListeningForTesting(true, sensitivity: .medium)
        var gateOn = true
        detector.feedGate = { gateOn }
        // Bark tail transient while gated — with output-filtering this seeded
        // firstClap; the gate must drop it entirely.
        detector.processSample(dBFS: -25, crest: 6, at: at(0.00))
        gateOn = false
        // TV transient right after the gate lifts: if firstClap had been
        // seeded, this would pair → ACCEPT. It must be a fresh firstClap.
        detector.processSample(dBFS: -40, crest: 1, at: at(0.10))
        detector.processSample(dBFS: -25, crest: 6, at: at(0.20))
        #expect(!fired, "post-gate transient must not pair with a gated buffer")
    }

    @Test("Gated above-floor buffers are visible in diagnostics as .gated")
    @MainActor
    func gatedBuffersLogged() {
        let detector = ClapDetector()
        detector.setListeningForTesting(true, sensitivity: .medium)
        detector.feedGate = { true }
        var gates: [ClapDiagnostics.Gate] = []
        detector.onDiagnostic = { gates.append($0.gate) }
        detector.processSample(dBFS: -20, crest: 5, at: at(0))
        #expect(gates == [.gated])
    }

    @Test("Engine-start transient grace drops the first second of buffers")
    @MainActor
    func startTransientGateDrops() {
        let detector = ClapDetector()
        var fired = false
        detector.onClapDetected = { fired = true }
        detector.setListeningForTesting(true, sensitivity: .medium)
        detector.setEngineStartedForTesting(at: at(0))
        // The fire-on-Start pattern: start transient + TV pair inside 1s.
        detector.processSample(dBFS: -45, crest: 4, at: at(0.30))
        detector.processSample(dBFS: -48, crest: 1, at: at(0.45))
        detector.processSample(dBFS: -44, crest: 4, at: at(0.60))
        #expect(!fired, "pairs inside the start-transient grace must not fire")
        // After the grace a genuine pair fires.
        detector.processSample(dBFS: -20, crest: 5, at: at(1.20))
        detector.processSample(dBFS: -40, crest: 1, at: at(1.30))
        detector.processSample(dBFS: -20, crest: 5, at: at(1.45))
        #expect(fired)
    }
}

@Suite("ResponseRateLimit")
struct ResponseRateLimitTests {

    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)
    private func at(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

    @Test("At most one response per minResponseInterval, regardless of triggers")
    @MainActor
    func rateLimitHolds() {
        let coordinator = ResponseCoordinator()
        let dog = Animal(id: "dog", name: "Dog", emoji: "🐕", soundFile: "dog_bark.caf")
        let cat = Animal(id: "cat", name: "Cat", emoji: "🐱", soundFile: "cat.caf")
        let bundle = Bundle.module

        coordinator.handleTrigger(animal: dog, bundle: bundle, now: at(0))
        #expect(coordinator.lastTriggeredAnimal == dog)

        // Past the suppression grace but inside the 10 s rate limit → ignored.
        coordinator.handleTrigger(animal: cat, bundle: bundle, now: at(5))
        #expect(coordinator.lastTriggeredAnimal == dog, "5 s after a response must be rate-limited")

        // Past the rate limit → responds.
        coordinator.handleTrigger(animal: cat, bundle: bundle, now: at(10.5))
        #expect(coordinator.lastTriggeredAnimal == cat)
    }
}
