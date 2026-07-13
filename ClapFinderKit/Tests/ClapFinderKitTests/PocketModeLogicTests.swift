#if canImport(Testing)
import Foundation
import Testing
@testable import ClapFinderKitAudio
@testable import ClapFinderKitData
@testable import ClapFinderKitMotion

// MARK: - PocketModeLogic tests
//
// All time arrives as injected Date values — no sleeping
// (POCKET_MODE_DESIGN.md §3 debounces, clock-seam pattern).

struct PocketModeLogicTests {

    private let base = Date(timeIntervalSince1970: 1_750_000_000)

    private func at(_ seconds: TimeInterval) -> Date { base.addingTimeInterval(seconds) }

    private func armed() -> PocketModeLogic {
        var logic = PocketModeLogic()
        logic.arm(at: base)
        return logic
    }

    /// Armed → covered at t0 → engaged (monitoring).
    private func monitoring() -> PocketModeLogic {
        var logic = armed()
        logic.setCovered(true, at: at(1))
        logic.evaluate(at: at(2.6))
        return logic
    }

    // MARK: Arm / disarm

    @Test("Arm only from disarmed; state becomes awaitingPocket")
    func armTransitions() {
        var logic = PocketModeLogic()
        #expect(logic.state == .disarmed)
        logic.arm(at: base)
        #expect(logic.state == .awaitingPocket)
    }

    @Test("Disarm returns wasAlarming only from the alarming state")
    func disarmReportsAlarming() {
        var quiet = monitoring()
        #expect(quiet.disarm() == false)

        var loud = monitoring()
        loud.setCovered(false, at: at(10))
        #expect(loud.evaluate(at: at(10.6)) == .alarm)
        #expect(loud.disarm() == true)
        #expect(loud.state == .disarmed)
    }

    // MARK: Cover debounce (engage) — the canonical 1.4 / 1.5 pair

    @Test("Cover sustained 1.4s — not engaged yet")
    func coverTooShort() {
        var logic = armed()
        logic.setCovered(true, at: at(1))
        #expect(logic.evaluate(at: at(2.4)) == nil)
        #expect(logic.state == .awaitingPocket)
    }

    @Test("Cover sustained 1.5s — engaged")
    func coverEngages() {
        var logic = armed()
        logic.setCovered(true, at: at(1))
        #expect(logic.evaluate(at: at(2.5)) == .engaged)
        #expect(logic.state == .monitoring)
    }

    @Test("Cover flicker restarts the debounce")
    func coverFlickerRestarts() {
        var logic = armed()
        logic.setCovered(true, at: at(1))
        logic.setCovered(false, at: at(2))     // hand shadow passed
        logic.setCovered(true, at: at(3))
        #expect(logic.evaluate(at: at(4.4)) == nil)   // 1.4s since re-cover
        #expect(logic.evaluate(at: at(4.5)) == .engaged)
    }

    @Test("Duplicate covered reports do not reset the debounce")
    func duplicateCoverKeepsClock() {
        var logic = armed()
        logic.setCovered(true, at: at(1))
        logic.setCovered(true, at: at(2))      // defensive duplicate
        #expect(logic.evaluate(at: at(2.5)) == .engaged)
    }

    // MARK: Uncover debounce (alarm) — the canonical 0.4 / 0.5 pair

    @Test("Uncover sustained 0.4s — no alarm (loose-fabric flicker)")
    func uncoverTooShort() {
        var logic = monitoring()
        logic.setCovered(false, at: at(10))
        #expect(logic.evaluate(at: at(10.4)) == nil)
        #expect(logic.state == .monitoring)
    }

    @Test("Uncover sustained 0.5s — alarm")
    func uncoverAlarms() {
        var logic = monitoring()
        logic.setCovered(false, at: at(10))
        #expect(logic.evaluate(at: at(10.5)) == .alarm)
        #expect(logic.state == .alarming)
    }

    @Test("Re-cover clears the pending alarm — flicker recovered")
    func recoverCancelsPendingAlarm() {
        var logic = monitoring()
        logic.setCovered(false, at: at(10))
        logic.setCovered(true, at: at(10.3))   // fabric settled back
        #expect(logic.evaluate(at: at(11)) == nil)
        #expect(logic.state == .monitoring)
    }

    // MARK: State guards

    @Test("Edges and evaluation are inert while disarmed or alarming")
    func inertStates() {
        var idle = PocketModeLogic()
        idle.setCovered(true, at: base)
        #expect(idle.evaluate(at: at(5)) == nil)

        var loud = monitoring()
        loud.setCovered(false, at: at(10))
        loud.evaluate(at: at(10.6))
        #expect(loud.state == .alarming)
        loud.setCovered(true, at: at(11))      // thief covers the sensor
        #expect(loud.evaluate(at: at(20)) == nil)
        #expect(loud.state == .alarming)       // only disarm exits (§3)
    }
}

// MARK: - Mutual exclusivity (POCKET_MODE_DESIGN.md §5, QA Q11)

@MainActor
struct PocketExclusivityTests {

    private let base = Date(timeIntervalSince1970: 1_750_000_000)

    private func makeAnimal() -> Animal {
        Animal(id: "dog", name: "Dog", emoji: "🐶", soundFile: "dog_bark.caf")
    }

    @Test("Arming pocket mode disarms touch alert (and vice versa)")
    func armingOneDisarmsTheOther() {
        let responder = AlarmResponder(soundPlayer: SoundPlayer(), flashlight: FlashlightController())
        let touch = TouchAlertCoordinator(responder: responder)
        let pocket = PocketModeCoordinator(responder: responder)
        touch.onWillArm = { [weak pocket] in pocket?.disarm() }
        pocket.onWillArm = { [weak touch] in touch?.disarm() }

        touch.armForTesting(animal: makeAnimal(), sensitivity: .medium, at: base)
        #expect(touch.state != .disarmed)

        pocket.armForTesting(animal: makeAnimal(), at: base.addingTimeInterval(1))
        #expect(pocket.state == .awaitingPocket)
        #expect(touch.state == .disarmed)

        touch.armForTesting(animal: makeAnimal(), sensitivity: .medium, at: base.addingTimeInterval(2))
        #expect(touch.state != .disarmed)
        #expect(pocket.state == .disarmed)
    }
}
#endif
