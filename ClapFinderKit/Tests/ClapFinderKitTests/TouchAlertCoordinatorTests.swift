#if canImport(Testing)
import Foundation
import Testing
@testable import ClapFinderKitAudio
@testable import ClapFinderKitData
@testable import ClapFinderKitMotion

// MARK: - TouchAlertCoordinator tests
//
// Uses armForTesting (no real audio engine) + the macOS MotionDetector
// stub's simulateSample to drive the full pipeline on CLI.

@MainActor
struct TouchAlertCoordinatorTests {

    private let base = Date(timeIntervalSince1970: 1_750_000_000)
    private let animal = Animal(id: "dog", name: "Dog", emoji: "🐕", soundFile: "dog_bark.caf")

    private func makeCoordinator() -> TouchAlertCoordinator {
        let responder = AlarmResponder(soundPlayer: SoundPlayer(), flashlight: FlashlightController())
        return TouchAlertCoordinator(responder: responder)
    }

    private var afterGrace: Date { base.addingTimeInterval(6.0) }

    // MARK: Arm

    @Test("Arm enters grace and starts the detector")
    func armStartsPipeline() {
        let coordinator = makeCoordinator()
        coordinator.armForTesting(animal: animal, sensitivity: .medium, at: base)
        #expect(coordinator.state == .grace)
        #expect(coordinator.detector.isMonitoring)
        #expect(coordinator.armedAnimal?.id == "dog")
    }

    // MARK: Full trigger path

    @Test("Two above-threshold samples after grace start the alarm")
    func motionTriggersAlarm() {
        let coordinator = makeCoordinator()
        coordinator.armForTesting(animal: animal, sensitivity: .medium, at: base)
        coordinator.detector.simulateSample(magnitude: 0.2, at: afterGrace)
        coordinator.detector.simulateSample(magnitude: 0.2, at: afterGrace)
        #expect(coordinator.state == .alarming)
        #expect(coordinator.responder.isAlarming)
        #expect(coordinator.responder.flashlight.isPulsing)
    }

    @Test("Samples inside grace never trigger")
    func graceSuppressesTrigger() {
        let coordinator = makeCoordinator()
        coordinator.armForTesting(animal: animal, sensitivity: .medium, at: base)
        let inGrace = base.addingTimeInterval(2.0)
        coordinator.detector.simulateSample(magnitude: 1.0, at: inGrace)
        coordinator.detector.simulateSample(magnitude: 1.0, at: inGrace)
        #expect(coordinator.state == .grace)
        #expect(!coordinator.responder.isAlarming)
    }

    // MARK: Disarm

    @Test("Disarm while alarming stops alarm, detector, and keep-alive")
    func disarmStopsEverything() {
        let coordinator = makeCoordinator()
        coordinator.armForTesting(animal: animal, sensitivity: .medium, at: base)
        coordinator.detector.simulateSample(magnitude: 0.2, at: afterGrace)
        coordinator.detector.simulateSample(magnitude: 0.2, at: afterGrace)
        #expect(coordinator.responder.isAlarming)

        coordinator.disarm()
        #expect(coordinator.state == .disarmed)
        #expect(!coordinator.responder.isAlarming)
        #expect(!coordinator.responder.flashlight.isPulsing)
        #expect(!coordinator.detector.isMonitoring)
        #expect(!coordinator.keepAlive.isListening)
        #expect(coordinator.armedAnimal == nil)
    }

    @Test("Disarm during grace stands down cleanly")
    func disarmDuringGrace() {
        let coordinator = makeCoordinator()
        coordinator.armForTesting(animal: animal, sensitivity: .medium, at: base)
        coordinator.disarm()
        #expect(coordinator.state == .disarmed)
        #expect(!coordinator.detector.isMonitoring)
    }

    // MARK: Watchdog (§4.2)

    @Test("Keep-alive loss while armed disarms instead of trusting dead monitoring")
    func watchdogStandsDown() {
        let coordinator = makeCoordinator()
        coordinator.armForTesting(animal: animal, sensitivity: .medium, at: base)
        // Simulate the system killing the audio session
        coordinator.keepAlive.setListeningForTesting(false, sensitivity: .medium)
        coordinator.detector.simulateSample(magnitude: 0.2, at: afterGrace)
        #expect(coordinator.state == .disarmed)
        #expect(!coordinator.responder.isAlarming)
    }
}

// MARK: - AlarmResponder tests

@MainActor
struct AlarmResponderTests {

    private let animal = Animal(id: "dog", name: "Dog", emoji: "🐕", soundFile: "missing.caf")

    private func makeResponder() -> AlarmResponder {
        AlarmResponder(soundPlayer: SoundPlayer(), flashlight: FlashlightController())
    }

    @Test("startAlarm sets isAlarming and starts continuous flash")
    func startAlarmState() {
        let responder = makeResponder()
        responder.startAlarm(animal: animal, in: .main)
        #expect(responder.isAlarming)
        #expect(responder.flashlight.isPulsing)
    }

    @Test("startAlarm is idempotent while alarming")
    func startAlarmIdempotent() {
        let responder = makeResponder()
        responder.startAlarm(animal: animal, in: .main)
        responder.startAlarm(animal: animal, in: .main)
        #expect(responder.isAlarming)
    }

    @Test("stopAlarm always wins and is safe to repeat")
    func stopAlarmWins() {
        let responder = makeResponder()
        responder.startAlarm(animal: animal, in: .main)
        responder.stopAlarm()
        #expect(!responder.isAlarming)
        #expect(!responder.flashlight.isPulsing)
        responder.stopAlarm()   // no crash, still stopped
        #expect(!responder.isAlarming)
    }
}

// MARK: - Analytics schema (EVENTS.md — Touch / Motion Alert)

struct TouchAlertAnalyticsTests {

    @Test("Event names and params match EVENTS.md")
    func eventSchema() {
        let armed = TouchAlertAnalytics.armed(sensitivity: "medium")
        #expect(armed.name == "touch_alert_armed")
        #expect(armed.params["sensitivity"] == .string("medium"))

        let triggered = TouchAlertAnalytics.triggered(sensitivity: "high", graceElapsedS: 42)
        #expect(triggered.name == "touch_alert_triggered")
        #expect(triggered.params["grace_elapsed_s"] == .int(42))

        let disarmed = TouchAlertAnalytics.disarmed(
            sensitivity: "low", wasAlarming: true, armedDurationS: 300
        )
        #expect(disarmed.name == "touch_alert_disarmed")
        #expect(disarmed.params["was_alarming"] == .bool(true))
        #expect(disarmed.params["armed_duration_s"] == .int(300))
    }
}

#endif
