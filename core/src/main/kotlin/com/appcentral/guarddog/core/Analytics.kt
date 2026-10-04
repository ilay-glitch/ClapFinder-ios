package com.appcentral.guarddog.core

/**
 * An analytics event. Names and params are the contract (EVENTS.md,
 * ANDROID_HANDOFF §1.7) — snake_case, Firebase-compatible.
 */
data class AnalyticsEvent(val name: String, val params: Map<String, Any> = emptyMap())

fun interface AnalyticsClient {
    fun log(event: AnalyticsEvent)
}

object Events {
    // Splash / App Open Ad
    fun splashShown(firstLaunch: Boolean) =
        AnalyticsEvent("splash_shown", mapOf("cold_launch" to true, "first_launch" to firstLaunch))
    fun appOpenAdRequested(consentObtained: Boolean) =
        AnalyticsEvent("app_open_ad_requested", mapOf("consent_obtained" to consentObtained))
    fun appOpenAdShown() = AnalyticsEvent("app_open_ad_shown")
    fun appOpenAdFailed(reason: String) = AnalyticsEvent("app_open_ad_failed", mapOf("error_reason" to reason))
    fun appOpenAdTimeout(elapsedMs: Long) = AnalyticsEvent("app_open_ad_timeout", mapOf("elapsed_ms" to elapsedMs))
    fun splashCompleted(durationMs: Long, adShown: Boolean, skipReason: AdSkipReason) = AnalyticsEvent(
        "splash_completed",
        mapOf("duration_ms" to durationMs, "ad_shown" to adShown, "ad_skip_reason" to skipReason.key),
    )

    // Don't Touch
    fun touchArmed(sensitivity: Sensitivity) =
        AnalyticsEvent("touch_alert_armed", mapOf("sensitivity" to sensitivity.key))
    fun touchTriggered(sensitivity: Sensitivity, graceElapsedS: Int) = AnalyticsEvent(
        "touch_alert_triggered",
        mapOf("sensitivity" to sensitivity.key, "grace_elapsed_s" to graceElapsedS),
    )
    fun touchDisarmed(sensitivity: Sensitivity, wasAlarming: Boolean, armedDurationS: Int) = AnalyticsEvent(
        "touch_alert_disarmed",
        mapOf("sensitivity" to sensitivity.key, "was_alarming" to wasAlarming, "armed_duration_s" to armedDurationS),
    )

    // Pocket Mode
    fun pocketArmed() = AnalyticsEvent("pocket_armed")
    fun pocketEngaged() = AnalyticsEvent("pocket_engaged")
    fun pocketAlarm() = AnalyticsEvent("pocket_alarm")
    fun pocketDisarmed(wasAlarming: Boolean, armedDurationS: Int) = AnalyticsEvent(
        "pocket_disarmed",
        mapOf("was_alarming" to wasAlarming, "armed_duration_s" to armedDurationS),
    )
    fun pocketStandDown(reason: String) = AnalyticsEvent("pocket_standdown", mapOf("reason" to reason))

    // Interstitial
    fun interstitialShown(usesSinceLast: Int) =
        AnalyticsEvent("interstitial_shown", mapOf("uses_since_last" to usesSinceLast))
    fun interstitialSuppressed(reason: InterstitialPolicy.SuppressReason) =
        AnalyticsEvent("interstitial_suppressed", mapOf("reason" to reason.key))
}
