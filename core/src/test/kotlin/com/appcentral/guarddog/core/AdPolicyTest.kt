package com.appcentral.guarddog.core

import com.appcentral.guarddog.core.AppOpenAdPolicy.Decision.Eligible
import com.appcentral.guarddog.core.AppOpenAdPolicy.Decision.Skip
import com.appcentral.guarddog.core.InterstitialPolicy.SuppressReason
import org.junit.Assert.assertEquals
import org.junit.Test

class AdPolicyTest {

    private val hour = 60 * 60 * 1000L

    @Test fun `app open rules apply in order`() {
        val policy = AppOpenAdPolicy(now = { 10 * hour })
        assertEquals(Skip(AdSkipReason.FIRST_LAUNCH), policy.decide(true, true, 10 * hour))
        assertEquals(Skip(AdSkipReason.SESSION_CAP), policy.decide(false, true, null))
        assertEquals(Skip(AdSkipReason.FREQUENCY_CAP), policy.decide(false, false, 6 * hour + 1))
        assertEquals(Eligible, policy.decide(false, false, 6 * hour))
        assertEquals(Eligible, policy.decide(false, false, null))
    }

    @Test fun `interstitial never shows while a guard is active`() {
        val policy = InterstitialPolicy()
        assertEquals(
            InterstitialPolicy.Decision.Suppress(SuppressReason.ALARM_ACTIVE),
            policy.decide(usesSinceLast = 99, threshold = 3, isGuardActive = true, isAdLoaded = true),
        )
    }

    @Test fun `threshold is clamped to 3-5`() {
        assertEquals(3, InterstitialPolicy { 0 }.newThreshold())
        assertEquals(5, InterstitialPolicy { 9 }.newThreshold())
        assertEquals(4, InterstitialPolicy { 4 }.newThreshold())
    }

    private class MemoryStore : InterstitialStore {
        override var usesSinceLast = 0
        override var threshold: Int? = null
    }

    @Test fun `counter shows at threshold, resets, and preserves when not loaded`() {
        val store = MemoryStore()
        val draws = ArrayDeque(listOf(3, 5))
        val counter = InterstitialCounter(store, InterstitialPolicy { draws.removeFirst() })

        repeat(2) { counter.recordUse() }
        assertEquals(3, store.threshold)
        assertEquals(
            InterstitialPolicy.Decision.Suppress(SuppressReason.FREQUENCY_CAP),
            counter.decide(isGuardActive = false, isAdLoaded = true),
        )

        counter.recordUse()
        assertEquals(
            InterstitialPolicy.Decision.Suppress(SuppressReason.NOT_LOADED),
            counter.decide(isGuardActive = false, isAdLoaded = false),
        )
        assertEquals(3, store.usesSinceLast) // preserved for the next disarm

        assertEquals(InterstitialPolicy.Decision.Show, counter.decide(isGuardActive = false, isAdLoaded = true))
        counter.onShown()
        assertEquals(0, store.usesSinceLast)
        assertEquals(5, store.threshold)
    }
}
