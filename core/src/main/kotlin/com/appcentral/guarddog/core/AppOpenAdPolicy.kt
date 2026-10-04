package com.appcentral.guarddog.core

/**
 * App Open Ad eligibility (ANDROID_HANDOFF §3). Stateless; the clock is injected.
 *
 * Rule order (first match wins): first launch → session cap → frequency cap →
 * eligible. Cold-launch-only is enforced upstream: the splash (and so this policy)
 * only runs on a cold launch. The 5 s load timeout lives in [SplashStateMachine].
 */
class AppOpenAdPolicy(
    val minimumIntervalMs: Long = 4 * 60 * 60 * 1000L,
    private val now: () -> Long = System::currentTimeMillis,
) {
    sealed interface Decision {
        data object Eligible : Decision
        data class Skip(val reason: AdSkipReason) : Decision
    }

    fun decide(isFirstLaunch: Boolean, shownThisSession: Boolean, lastShownAtMs: Long?): Decision = when {
        isFirstLaunch -> Decision.Skip(AdSkipReason.FIRST_LAUNCH)
        shownThisSession -> Decision.Skip(AdSkipReason.SESSION_CAP)
        lastShownAtMs != null && now() - lastShownAtMs < minimumIntervalMs ->
            Decision.Skip(AdSkipReason.FREQUENCY_CAP)
        else -> Decision.Eligible
    }
}
