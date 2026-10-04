package com.appcentral.guarddog.core

import kotlin.random.Random

/**
 * Interstitial eligibility (ANDROID_HANDOFF §3, ADS_DESIGN D1-v2 + D2).
 *
 * A "use" is a completed guard session — armed, then disarmed by the user from
 * MONITORING (either mode). Presentation is only ever attempted at disarm-to-idle,
 * and never while any guard is armed or alarming.
 *
 * Suppress priority: guard active > frequency > not loaded.
 */
class InterstitialPolicy(
    private val drawThreshold: () -> Int = { Random.nextInt(THRESHOLD_MIN, THRESHOLD_MAX + 1) },
) {
    sealed interface Decision {
        data object Show : Decision
        data class Suppress(val reason: SuppressReason) : Decision
    }

    enum class SuppressReason(val key: String) {
        ALARM_ACTIVE("alarm_active"),
        FREQUENCY_CAP("frequency_cap"),
        NOT_LOADED("not_loaded"),
    }

    /** Next cycle's threshold, clamped into 3–5. */
    fun newThreshold(): Int = drawThreshold().coerceIn(THRESHOLD_MIN, THRESHOLD_MAX)

    fun decide(usesSinceLast: Int, threshold: Int, isGuardActive: Boolean, isAdLoaded: Boolean): Decision = when {
        isGuardActive -> Decision.Suppress(SuppressReason.ALARM_ACTIVE)
        usesSinceLast < threshold -> Decision.Suppress(SuppressReason.FREQUENCY_CAP)
        !isAdLoaded -> Decision.Suppress(SuppressReason.NOT_LOADED)
        else -> Decision.Show
    }

    companion object {
        const val THRESHOLD_MIN = 3
        const val THRESHOLD_MAX = 5
    }
}

/** Persisted frequency-cap state — the counter survives force-quit. */
interface InterstitialStore {
    var usesSinceLast: Int
    /** Current cycle's threshold; null until first drawn. */
    var threshold: Int?
}

/**
 * Counter bookkeeping around [InterstitialPolicy]: draws and persists the threshold
 * with the counter, resets + redraws after a show, and preserves the counter when
 * the ad isn't loaded (retry at the next disarm).
 */
class InterstitialCounter(
    private val store: InterstitialStore,
    private val policy: InterstitialPolicy = InterstitialPolicy(),
) {
    val usesSinceLast: Int get() = store.usesSinceLast

    fun recordUse() {
        ensureThreshold()
        store.usesSinceLast += 1
    }

    fun decide(isGuardActive: Boolean, isAdLoaded: Boolean): InterstitialPolicy.Decision =
        policy.decide(store.usesSinceLast, ensureThreshold(), isGuardActive, isAdLoaded)

    /** Call when an interstitial actually presented. */
    fun onShown() {
        store.usesSinceLast = 0
        store.threshold = policy.newThreshold()
    }

    private fun ensureThreshold(): Int =
        store.threshold ?: policy.newThreshold().also { store.threshold = it }
}
