package com.appcentral.guarddog.core

import com.appcentral.guarddog.core.SplashStateMachine.Event
import com.appcentral.guarddog.core.SplashStateMachine.State
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SplashStateMachineTest {

    private val eligible = Event.AdDecided(AppOpenAdPolicy.Decision.Eligible)

    @Test fun `first launch skips the ad and finishes after the minimum timer`() {
        val m = SplashStateMachine()
        m.apply(Event.CatalogLoaded)
        m.apply(Event.AdDecided(AppOpenAdPolicy.Decision.Skip(AdSkipReason.FIRST_LAUNCH)))
        assertFalse(m.showsAdDisclaimer)
        assertEquals(State.Loading, m.state)
        m.apply(Event.MinTimerFired)
        assertEquals(State.Finished(false, AdSkipReason.FIRST_LAUNCH), m.state)
    }

    @Test fun `loaded ad presents then finishes on dismiss`() {
        val m = SplashStateMachine()
        m.apply(Event.CatalogLoaded)
        m.apply(eligible)
        assertTrue(m.wantsAdRequest)
        assertTrue(m.showsAdDisclaimer)
        m.apply(Event.AdLoaded)
        m.apply(Event.MinTimerFired)
        assertEquals(State.PresentingAd, m.state)
        m.apply(Event.AdDismissed)
        assertEquals(State.Finished(true, AdSkipReason.NONE), m.state)
    }

    @Test fun `late load after timeout is discarded`() {
        val m = SplashStateMachine()
        m.apply(Event.CatalogLoaded)
        m.apply(eligible)
        m.apply(Event.MinTimerFired)
        m.apply(Event.AdTimedOut)
        assertEquals(State.Finished(false, AdSkipReason.TIMEOUT), m.state)
        m.apply(Event.AdLoaded)
        assertEquals(State.Finished(false, AdSkipReason.TIMEOUT), m.state)
    }

    @Test fun `decision is taken once`() {
        val m = SplashStateMachine()
        m.apply(Event.AdDecided(AppOpenAdPolicy.Decision.Skip(AdSkipReason.SESSION_CAP)))
        m.apply(eligible)
        assertFalse(m.wantsAdRequest)
    }

    @Test fun `progress is monotonic and gated by readiness and time`() {
        assertEquals(0.3, SplashStateMachine.progress(1_500, true, false, 0.0), 1e-9)
        assertEquals(0.5, SplashStateMachine.progress(750, true, true, 0.0), 1e-9)
        assertEquals(1.0, SplashStateMachine.progress(1_500, true, true, 0.0), 1e-9)
        assertEquals(0.6, SplashStateMachine.progress(0, false, false, 0.6), 1e-9)
    }
}
