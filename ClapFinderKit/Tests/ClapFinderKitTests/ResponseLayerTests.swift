#if canImport(Testing)
import Testing
@testable import ClapFinderKitAudio
@testable import ClapFinderKitData

// MARK: - SoundPlayer Tests

@MainActor
struct SoundPlayerTests {

    @Test("Initial isPlaying is false")
    func initialStateNotPlaying() {
        let player = SoundPlayer()
        #expect(!player.isPlaying)
    }

    @Test("play with missing file does not crash and leaves isPlaying false")
    func playMissingFileDoesNotCrash() {
        let player = SoundPlayer()
        let phantom = Animal(id: "ghost", name: "Ghost", emoji: "👻", soundFile: "ghost_wail.caf")
        // Bundle.main won't have this file in tests — should fail gracefully
        player.play(animal: phantom, in: Bundle(for: SoundPlayerTests.BundleToken.self))
        #expect(!player.isPlaying)
    }

    @Test("stop when not playing does not crash")
    func stopWhenIdleDoesNotCrash() {
        let player = SoundPlayer()
        player.stop()   // should be a no-op
        #expect(!player.isPlaying)
    }

    /// Dummy class for Bundle(for:) lookup.
    private final class BundleToken {}
}

// MARK: - FlashlightController Tests

@MainActor
struct FlashlightControllerTests {

    @Test("Initial isPulsing is false")
    func initialStateNotPulsing() {
        let fl = FlashlightController()
        #expect(!fl.isPulsing)
    }

    @Test("pulse constants are correct")
    func pulseConstants() {
        let fl = FlashlightController()
        #expect(fl.pulseCount == 3)
        #expect(fl.onDuration == 0.150)
        #expect(fl.offDuration == 0.100)
    }

    @Test("pulse on simulator/macOS (no torch) does not crash")
    func pulseNoTorchDoesNotCrash() {
        let fl = FlashlightController()
        // On macOS / Simulator there is no camera/torch — should be a no-op
        fl.pulse()
        // isPulsing is only true when torch IS available; macOS stub is always false
        // This test just proves it doesn't throw / crash
        #expect(true)
    }
}

// MARK: - ResponseCoordinator Tests

@MainActor
struct ResponseCoordinatorTests {

    @Test("Initial state is inactive")
    func initialStateInactive() {
        let coord = ResponseCoordinator()
        #expect(!coord.isActive)
        #expect(coord.lastTriggeredAnimal == nil)
    }

    @Test("startForTesting sets isActive to true")
    func startForTestingSetsActive() {
        let coord = ResponseCoordinator()
        let dog = Animal(id: "dog", name: "Dog", emoji: "🐕", soundFile: "dog_bark.caf")
        coord.startForTesting(animal: dog)
        #expect(coord.isActive)
    }

    @Test("stop sets isActive to false")
    func stopSetsInactive() {
        let coord = ResponseCoordinator()
        let dog = Animal(id: "dog", name: "Dog", emoji: "🐕", soundFile: "dog_bark.caf")
        coord.startForTesting(animal: dog)
        coord.stop()
        #expect(!coord.isActive)
    }

    @Test("Double-clap sets lastTriggeredAnimal")
    func doubleClapSetsLastTriggeredAnimal() {
        let coord = ResponseCoordinator()
        let cat = Animal(id: "cat", name: "Cat", emoji: "🐈", soundFile: "cat_meow.caf")
        coord.startForTesting(animal: cat, sensitivity: .medium)

        // Simulate double-clap via the internal hook
        coord.detector.processSample(dBFS: -20)
        coord.detector.processSample(dBFS: -20)

        #expect(coord.lastTriggeredAnimal?.id == "cat")
    }

    @Test("startForTesting is idempotent — second call is a no-op")
    func startForTestingIdempotent() {
        let coord = ResponseCoordinator()
        let dog = Animal(id: "dog", name: "Dog", emoji: "🐕", soundFile: "dog_bark.caf")
        coord.startForTesting(animal: dog)
        coord.startForTesting(animal: dog)   // second call — should not crash
        #expect(coord.isActive)
    }

    @Test("stop is idempotent — second call is a no-op")
    func stopIdempotent() {
        let coord = ResponseCoordinator()
        let dog = Animal(id: "dog", name: "Dog", emoji: "🐕", soundFile: "dog_bark.caf")
        coord.startForTesting(animal: dog)
        coord.stop()
        coord.stop()    // should not crash
        #expect(!coord.isActive)
    }

    @Test("Clap below threshold does not set lastTriggeredAnimal")
    func clapBelowThresholdNoResponse() {
        let coord = ResponseCoordinator()
        let lion = Animal(id: "lion", name: "Lion", emoji: "🦁", soundFile: "lion_roar.caf")
        coord.startForTesting(animal: lion, sensitivity: .low)   // threshold = -30 dBFS

        // Send two samples that are BELOW threshold
        coord.detector.processSample(dBFS: -40)
        coord.detector.processSample(dBFS: -40)

        #expect(coord.lastTriggeredAnimal == nil)
    }
}
#endif
