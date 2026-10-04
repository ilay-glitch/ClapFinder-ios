package com.appcentral.guarddog.ui

import android.app.Activity
import android.app.Application
import android.os.SystemClock
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.appcentral.guarddog.GuardDogApp
import com.appcentral.guarddog.core.AppOpenAdPolicy
import com.appcentral.guarddog.core.Events
import com.appcentral.guarddog.core.SplashStateMachine
import com.appcentral.guarddog.core.SplashStateMachine.Event
import com.appcentral.guarddog.core.SplashStateMachine.State
import com.google.android.gms.ads.appopen.AppOpenAd
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Impure shell around [SplashStateMachine]: real clocks (1.5 s minimum, 5 s ad
 * timeout, progress ticker), the ad loader, persistence, analytics. Every decision
 * lives in the pure layer. Survives configuration changes, so timers never restart.
 */
class SplashViewModel(application: Application) : AndroidViewModel(application) {

    data class Ui(
        val progress: Double = 0.0,
        val showAdDisclaimer: Boolean = false,
        val adToPresent: AppOpenAd? = null,
        val finished: Boolean = false,
    )

    private val app = application as GuardDogApp
    private val machine = SplashStateMachine()
    private val policy = AppOpenAdPolicy()
    private val isFirstLaunch = !app.prefs.hasCompletedFirstLaunch
    private var startedAt = SystemClock.elapsedRealtime()
    private var started = false
    private var presenting = false
    private var loadedAd: AppOpenAd? = null
    private val jobs = mutableListOf<Job>()

    private companion object {
        /** `app_open_ad_failed.error_reason` when UMP consent doesn't allow ad requests. */
        const val NO_CONSENT = "no_consent"
    }

    private val _ui = MutableStateFlow(Ui())
    val ui: StateFlow<Ui> = _ui.asStateFlow()

    fun start(activity: Activity) {
        if (started) return
        started = true
        startedAt = SystemClock.elapsedRealtime()
        app.analytics.log(Events.splashShown(firstLaunch = isFirstLaunch))

        // The catalog is compiled in — it is loaded by definition.
        apply(Event.CatalogLoaded)

        val decision = policy.decide(
            isFirstLaunch = isFirstLaunch,
            shownThisSession = app.appOpenAdShownThisProcess,
            lastShownAtMs = app.prefs.appOpenLastShownAtMs,
        )
        apply(Event.AdDecided(decision))
        if (machine.wantsAdRequest) requestAd(activity)

        jobs += viewModelScope.launch {
            delay(SplashStateMachine.MIN_DURATION_MS)
            apply(Event.MinTimerFired)
        }
        jobs += viewModelScope.launch {
            while (isActive && !_ui.value.finished) {
                refresh()
                delay(50)
            }
        }
    }

    /** Called by the screen once the ad it was handed has been dismissed. */
    fun onAdDismissed() = apply(Event.AdDismissed)

    /** Consent refresh + load, both inside the 5 s timeout. */
    private fun requestAd(activity: Activity) {
        app.ads.refreshConsent(activity) { canRequest ->
            if (machine.adPhase != SplashStateMachine.AdPhase.Requesting) return@refreshConsent
            if (canRequest) {
                load()
            } else {
                app.analytics.log(Events.appOpenAdFailed(NO_CONSENT))
                apply(Event.AdFailed(NO_CONSENT))
            }
        }
        jobs += viewModelScope.launch {
            delay(SplashStateMachine.AD_TIMEOUT_MS)
            if (machine.adPhase == SplashStateMachine.AdPhase.Requesting) {
                app.analytics.log(Events.appOpenAdTimeout(SystemClock.elapsedRealtime() - startedAt))
                apply(Event.AdTimedOut)
            }
        }
    }

    private fun load() {
        app.analytics.log(Events.appOpenAdRequested(consentObtained = true))
        app.ads.loadAppOpen(
            onLoaded = { ad ->
                if (machine.adPhase == SplashStateMachine.AdPhase.Requesting) {
                    loadedAd = ad
                    apply(Event.AdLoaded)
                }
                // Late ads (after timeout) are dropped on the floor.
            },
            onFailed = { reason ->
                app.analytics.log(Events.appOpenAdFailed(reason))
                apply(Event.AdFailed(reason))
            },
        )
    }

    private fun apply(event: Event) {
        machine.apply(event)
        when (val state = machine.state) {
            State.PresentingAd -> presentOnce()
            is State.Finished -> finish(state)
            State.Loading -> Unit
        }
        refresh()
    }

    private fun presentOnce() {
        if (presenting) return
        presenting = true
        app.analytics.log(Events.appOpenAdShown())
        app.prefs.appOpenLastShownAtMs = System.currentTimeMillis()
        app.appOpenAdShownThisProcess = true
        _ui.value = _ui.value.copy(adToPresent = loadedAd)
    }

    private fun finish(state: State.Finished) {
        if (_ui.value.finished) return
        jobs.forEach { it.cancel() }
        app.prefs.hasCompletedFirstLaunch = true
        app.splashDoneThisProcess = true
        app.analytics.log(
            Events.splashCompleted(SystemClock.elapsedRealtime() - startedAt, state.adShown, state.skipReason),
        )
        _ui.value = _ui.value.copy(progress = 1.0, adToPresent = null, finished = true)
    }

    private fun refresh() {
        if (_ui.value.finished) return
        val progress = SplashStateMachine.progress(
            elapsedMs = SystemClock.elapsedRealtime() - startedAt,
            catalogLoaded = machine.catalogLoaded,
            adResolved = machine.adResolved,
            previous = _ui.value.progress,
        )
        _ui.value = _ui.value.copy(progress = progress, showAdDisclaimer = machine.showsAdDisclaimer)
    }
}
