#if canImport(Testing)
import Testing
import Foundation
@testable import ClapFinderKitAudio
@testable import ClapFinderKitData

// MARK: - Feedback-loop suppression tests
//
// Pins the fix for the device-confirmed feedback loop (the alert re-triggering
// detection through the mic, including its echo tail at −54 dBFS): triggers
// during playback AND within the tail grace after it are ignored.

@Suite("ResponseSuppression")
struct ResponseSuppressionTests {

    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)
    private func at(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

    // MARK: Pure logic

    @Test("Trigger while the sound is playing is suppressed")
    func suppressedWhilePlaying() {
        var sup = ResponseSuppression()
        let r1 = sup.shouldSuppress(isPlaying: true, now: at(0))
        #expect(r1)
    }

    @Test("Echo tail: trigger shortly AFTER playback is still suppressed")
    func suppressedInTailAfterPlayback() {
        var sup = ResponseSuppression()
        // Last audible moment observed at t=0 (extends the tail)...
        let during = sup.shouldSuppress(isPlaying: true, now: at(0))
        // ...the echo re-trigger 0.2 s later (the −54 dBFS accept) is ignored.
        let echo = sup.shouldSuppress(isPlaying: false, now: at(0.2))
        let lateTail = sup.shouldSuppress(isPlaying: false, now: at(0.99))
        #expect(during && echo && lateTail)
    }

    @Test("A genuine trigger after the tail grace passes")
    func passesAfterGrace() {
        var sup = ResponseSuppression()
        let during = sup.shouldSuppress(isPlaying: true, now: at(0))
        let after = sup.shouldSuppress(isPlaying: false, now: at(1.01))
        #expect(during && !after)
    }

    @Test("responseStarted seeds the tail even if isPlaying never goes true")
    func responseStartSeedsTail() {
        var sup = ResponseSuppression()
        sup.responseStarted(now: at(0))          // fired; sound failed/instant
        let inTail = sup.shouldSuppress(isPlaying: false, now: at(0.5))
        let after = sup.shouldSuppress(isPlaying: false, now: at(1.5))
        #expect(inTail && !after)
    }

    @Test("Playback keeps extending the tail (sliding grace)")
    func slidingTail() {
        var sup = ResponseSuppression()
        let p1 = sup.shouldSuppress(isPlaying: true, now: at(0))
        let p2 = sup.shouldSuppress(isPlaying: true, now: at(2.0))   // still playing
        let tail = sup.shouldSuppress(isPlaying: false, now: at(2.9))  // tail from t=2
        let after = sup.shouldSuppress(isPlaying: false, now: at(3.01))
        #expect(p1 && p2 && tail && !after)
    }

    // MARK: Through the coordinator (the wiring)

    @Test("Coordinator ignores detector triggers during + shortly after a response")
    @MainActor
    func coordinatorSuppressesFeedback() {
        let coordinator = ResponseCoordinator()
        let dog = Animal(id: "dog", name: "Dog", emoji: "🐕", soundFile: "dog_bark.caf")
        let bundle = Bundle.module

        // First trigger → responds and seeds the tail.
        coordinator.handleTrigger(animal: dog, bundle: bundle, now: at(0))
        #expect(coordinator.lastTriggeredAnimal == dog)

        // Feedback re-trigger inside the tail → ignored (no second response).
        let ghost = Animal(id: "ghost", name: "Ghost", emoji: "👻", soundFile: "ghost.caf")
        coordinator.handleTrigger(animal: ghost, bundle: bundle, now: at(0.5))
        #expect(coordinator.lastTriggeredAnimal == dog, "trigger in the tail grace must be ignored")

        // Genuine trigger after the grace → responds again.
        coordinator.handleTrigger(animal: ghost, bundle: bundle, now: at(1.5))
        #expect(coordinator.lastTriggeredAnimal == ghost)
    }
}
#endif
