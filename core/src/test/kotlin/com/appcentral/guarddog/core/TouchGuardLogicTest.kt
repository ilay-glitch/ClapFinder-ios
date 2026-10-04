package com.appcentral.guarddog.core

import com.appcentral.guarddog.core.TouchGuardLogic.Event
import com.appcentral.guarddog.core.TouchGuardLogic.State
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TouchGuardLogicTest {

    private fun armed(sensitivity: Sensitivity = Sensitivity.MEDIUM) =
        TouchGuardLogic().apply { arm(sensitivity, nowMs = 0) }

    @Test fun `arm enters grace and ignores motion during it`() {
        val logic = armed()
        assertEquals(State.GRACE, logic.state)
        assertNull(logic.onSample(5.0, 1_000))
        assertNull(logic.onSample(5.0, 4_999))
        assertEquals(State.GRACE, logic.state)
    }

    @Test fun `tick ends grace exactly at five seconds`() {
        val logic = armed()
        assertNull(logic.tick(4_999))
        assertEquals(Event.MONITORING_STARTED, logic.tick(5_000))
        assertEquals(State.MONITORING, logic.state)
        assertNull(logic.tick(6_000))
    }

    @Test fun `two consecutive samples above threshold trigger`() {
        val logic = armed().apply { tick(5_000) }
        assertNull(logic.onSample(0.09, 5_100))
        assertEquals(Event.ALARM, logic.onSample(0.09, 5_200))
        assertEquals(State.ALARMING, logic.state)
    }

    @Test fun `a below-threshold sample resets the count`() {
        val logic = armed().apply { tick(5_000) }
        logic.onSample(0.5, 5_100)
        logic.onSample(0.01, 5_200)
        assertNull(logic.onSample(0.5, 5_300))
        assertEquals(State.MONITORING, logic.state)
    }

    @Test fun `samples during grace do not count toward the trigger`() {
        val logic = armed()
        logic.onSample(0.5, 4_900)
        // First post-grace sample flips to monitoring and counts as one.
        assertEquals(Event.MONITORING_STARTED, logic.onSample(0.5, 5_000))
        assertEquals(Event.ALARM, logic.onSample(0.5, 5_100))
    }

    @Test fun `threshold follows sensitivity`() {
        val low = armed(Sensitivity.LOW).apply { tick(5_000) }
        low.onSample(0.1, 5_100)
        assertNull(low.onSample(0.1, 5_200))
        val high = armed(Sensitivity.HIGH).apply { tick(5_000) }
        high.onSample(0.05, 5_100)
        assertEquals(Event.ALARM, high.onSample(0.05, 5_200))
    }

    @Test fun `disarm reports the state it left from`() {
        assertEquals(State.GRACE, armed().disarm())
        assertEquals(State.MONITORING, armed().apply { tick(5_000) }.disarm())
        val alarming = armed().apply { tick(5_000); onSample(1.0, 5_100); onSample(1.0, 5_200) }
        assertEquals(State.ALARMING, alarming.disarm())
        assertEquals(State.DISARMED, alarming.state)
    }

    @Test fun `arm is a no-op while armed and alarming stays latched`() {
        val logic = armed().apply { tick(5_000); onSample(1.0, 5_100); onSample(1.0, 5_200) }
        logic.arm(Sensitivity.LOW, 9_000)
        assertEquals(State.ALARMING, logic.state)
        assertNull(logic.onSample(0.0, 9_100))
        assertEquals(State.ALARMING, logic.state)
    }

    @Test fun `grace countdown rounds up`() {
        val logic = armed()
        assertEquals(5, logic.graceRemainingSeconds(0))
        assertEquals(5, logic.graceRemainingSeconds(1))
        assertEquals(4, logic.graceRemainingSeconds(1_000))
        assertEquals(1, logic.graceRemainingSeconds(4_999))
    }
}
