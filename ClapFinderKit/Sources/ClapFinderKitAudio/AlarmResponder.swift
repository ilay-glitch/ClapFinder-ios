import ClapFinderKitData
import Foundation
import Observation
import OSLog

// MARK: - AlarmResponder

/// Shared response pipeline for every alert trigger
/// (TOUCH_ALERT_DESIGN.md §6 — the `AlertTrigger` extraction).
///
/// Owns `SoundPlayer` + `FlashlightController` and offers two shapes:
/// - `respondOnce(animal:in:)` — one sound + one 3× flash pulse
///   (clap detection's behavior, extracted from `ResponseCoordinator`).
/// - `startAlarm(animal:in:)` / `stopAlarm()` — looped sound + continuous
///   flashlight until explicitly stopped (touch alert's alarm).
@Observable
@MainActor
public final class AlarmResponder {

    // MARK: Public state

    /// `true` while a continuous alarm is sounding.
    public private(set) var isAlarming = false

    // MARK: Dependencies

    public let soundPlayer: SoundPlayer
    public let flashlight: FlashlightController

    // MARK: Logging

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "AlarmResponder"
    )

    // MARK: Init

    public init(soundPlayer: SoundPlayer, flashlight: FlashlightController) {
        self.soundPlayer = soundPlayer
        self.flashlight = flashlight
    }

    // MARK: One-shot response (clap detection)

    /// Plays the animal sound once and pulses the flashlight 3×.
    public func respondOnce(animal: Animal, in bundle: Bundle) {
        soundPlayer.play(animal: animal, in: bundle)
        flashlight.pulse()
    }

    // MARK: Continuous alarm (touch alert)

    /// Starts the looping alarm: sound repeats and the flashlight pulses
    /// until `stopAlarm()` is called. Idempotent while alarming.
    public func startAlarm(animal: Animal, in bundle: Bundle) {
        guard !isAlarming else { return }
        isAlarming = true
        Self.logger.info("Alarm started — \(animal.name)")
        soundPlayer.play(animal: animal, in: bundle, loop: true)
        flashlight.startContinuousPulse()
    }

    /// Stops the alarm immediately. Always wins, safe to call repeatedly.
    public func stopAlarm() {
        guard isAlarming else { return }
        isAlarming = false
        Self.logger.info("Alarm stopped")
        soundPlayer.stop()
        flashlight.stopContinuousPulse()
    }
}
