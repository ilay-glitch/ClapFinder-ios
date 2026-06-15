#if canImport(Testing)
import Testing
@testable import ClapFinderKitActivity

// MARK: - TouchAlertControl + phase tests (LIVE_ACTIVITY_DESIGN.md §2–§3)

@MainActor
struct TouchAlertControlTests {

    @Test("requestDisarm invokes the registered handler")
    func disarmInvokesHandler() {
        var called = 0
        TouchAlertControl.register { called += 1 }
        TouchAlertControl.requestDisarm()
        #expect(called == 1)
        TouchAlertControl.clear()
    }

    @Test("requestDisarm after clear is a no-op (nothing armed)")
    func disarmAfterClearNoop() {
        var called = 0
        TouchAlertControl.register { called += 1 }
        TouchAlertControl.clear()
        TouchAlertControl.requestDisarm()
        #expect(called == 0)
    }

    @Test("Phase status keys are stable (must match Localizable.strings)")
    func phaseStatusKeys() {
        #expect(TouchAlertActivityPhase.grace.statusKey == "liveactivity.status.grace")
        #expect(TouchAlertActivityPhase.armed.statusKey == "liveactivity.status.armed")
        #expect(TouchAlertActivityPhase.alarming.statusKey == "liveactivity.status.alarming")
    }
}

#endif
