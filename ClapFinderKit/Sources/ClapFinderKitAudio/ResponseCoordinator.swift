import ClapFinderKitData
import Foundation
import OSLog
import Observation

// MARK: - ResponseCoordinator

/// Wires `ClapDetector` → `SoundPlayer` + `FlashlightController`.
///
/// Typical usage:
/// ```swift
/// let coordinator = ResponseCoordinator()
/// try coordinator.start(animal: catalogStore.selectedAnimal!, sensitivity: catalogStore.sensitivity)
/// // …
/// coordinator.stop()
/// ```
///
/// The coordinator owns the `ClapDetector`. It registers `onClapDetected`,
/// starts detection, and on each double-clap triggers sound and flashlight
/// concurrently on the main actor.
@Observable
@MainActor
public final class ResponseCoordinator {

    // MARK: Public state

    /// `true` while clap detection is running.
    public private(set) var isActive = false

    /// The last animal that triggered a response (for UI feedback).
    public private(set) var lastTriggeredAnimal: Animal?

    // MARK: Dependencies

    public let detector: ClapDetector
    public let soundPlayer: SoundPlayer
    public let flashlight: FlashlightController

    /// Bundle used to resolve sound files. Defaults to `Bundle.main`;
    /// inject a custom bundle in tests.
    public var soundBundle: Bundle

    // MARK: Logging

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "ResponseCoordinator"
    )

    // MARK: Init

    /// Creates a coordinator with default-constructed components.
    ///
    /// - Parameter soundBundle: Bundle containing the `.caf` audio files
    ///   (default: `Bundle.main`).
    public init(soundBundle: Bundle = .main) {
        self.detector = ClapDetector()
        self.soundPlayer = SoundPlayer()
        self.flashlight = FlashlightController()
        self.soundBundle = soundBundle
    }

    /// Dependency-injection init for tests.
    public init(
        detector: ClapDetector,
        soundPlayer: SoundPlayer,
        flashlight: FlashlightController,
        soundBundle: Bundle = .main
    ) {
        self.detector = detector
        self.soundPlayer = soundPlayer
        self.flashlight = flashlight
        self.soundBundle = soundBundle
    }

    // MARK: Public API

    /// Starts clap detection for the given animal and sensitivity.
    ///
    /// - Throws: `ClapDetectorError` if the audio session or engine cannot start.
    public func start(animal: Animal, sensitivity: Sensitivity = .medium) throws {
        guard !isActive else { return }
        wireDetector(for: animal)
        try detector.start(sensitivity: sensitivity)
        isActive = true
        Self.logger.info("Started — animal: \(animal.name), sensitivity: \(sensitivity.rawValue)")
    }

    /// Stops detection and cancels any in-progress sound.
    public func stop() {
        guard isActive else { return }
        detector.stop()
        soundPlayer.stop()
        isActive = false
        Self.logger.info("Stopped")
    }

    // MARK: Private

    private func wireDetector(for animal: Animal) {
        let capturedAnimal = animal
        let capturedBundle = soundBundle
        detector.onClapDetected = { [weak self] in
            self?.respond(to: capturedAnimal, bundle: capturedBundle)
        }
    }

    private func respond(to animal: Animal, bundle: Bundle) {
        lastTriggeredAnimal = animal
        Self.logger.info("Clap response triggered — \(animal.name)")
        soundPlayer.play(animal: animal, in: bundle)
        flashlight.pulse()
    }

    // MARK: Testing support

    /// Starts the coordinator without launching the real AVAudioEngine.
    /// **Only call this from test code.**
    func startForTesting(animal: Animal, sensitivity: Sensitivity = .medium) {
        guard !isActive else { return }
        wireDetector(for: animal)
        detector.setListeningForTesting(true, sensitivity: sensitivity)
        isActive = true
    }
}
