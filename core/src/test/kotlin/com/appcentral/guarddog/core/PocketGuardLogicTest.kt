package com.appcentral.guarddog.core

import com.appcentral.guarddog.core.PocketGuardLogic.Event
import com.appcentral.guarddog.core.PocketGuardLogic.State
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PocketGuardLogicTest {

    private fun armed() = PocketGuardLogic().apply { arm(0) }

    private fun pocketed() = armed().apply {
        setCovered(true, 100)
        evaluate(1_600)
    }

    @Test fun `cover must be sustained 1_5 s to engage`() {
        val logic = armed()
        logic.setCovered(true, 100)
        assertNull(logic.evaluate(1_599))
        assertEquals(Event.ENGAGED, logic.evaluate(1_600))
        assertEquals(State.MONITORING, logic.state)
    }

    @Test fun `flicker while pocketing restarts the cover debounce`() {
        val logic = armed()
        logic.setCovered(true, 0)
        logic.setCovered(false, 1_000)
        logic.setCovered(true, 1_200)
        assertNull(logic.evaluate(2_000))
        assertEquals(Event.ENGAGED, logic.evaluate(2_700))
    }

    @Test fun `duplicate covered reports do not reset the debounce`() {
        val logic = armed()
        logic.setCovered(true, 0)
        logic.setCovered(true, 1_000)
        assertEquals(Event.ENGAGED, logic.evaluate(1_500))
    }

    @Test fun `uncover must be sustained 0_5 s to alarm`() {
        val logic = pocketed()
        logic.setCovered(false, 2_000)
        assertNull(logic.evaluate(2_499))
        assertEquals(Event.ALARM, logic.evaluate(2_500))
        assertEquals(State.ALARMING, logic.state)
    }

    @Test fun `fabric flicker while pocketed is ignored`() {
        val logic = pocketed()
        logic.setCovered(false, 2_000)
        logic.setCovered(true, 2_300)
        assertNull(logic.evaluate(3_000))
        assertEquals(State.MONITORING, logic.state)
    }

    @Test fun `alarm is latched until disarm`() {
        val logic = pocketed().apply { setCovered(false, 2_000); evaluate(2_500) }
        logic.setCovered(true, 3_000)
        assertNull(logic.evaluate(9_000))
        assertEquals(State.ALARMING, logic.disarm())
        assertEquals(State.DISARMED, logic.state)
    }

    @Test fun `disarm while awaiting reports awaiting`() {
        assertEquals(State.AWAITING_POCKET, armed().disarm())
    }
}
