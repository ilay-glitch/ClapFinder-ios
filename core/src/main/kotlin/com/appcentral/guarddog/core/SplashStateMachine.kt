package com.appcentral.guarddog.core

/**
 * Splash → (app open ad | skip) → next screen (ANDROID_HANDOFF §1.5, §3).
 *
 * Time never appears inside: the 1.5 s minimum and the 5 s ad timeout arrive as
 * events. Guarantees: the ad decision is taken once; a late load after a timeout
 * or failure is discarded; [State.Finished] is terminal.
 */
class SplashStateMachine {

    sealed interface AdPhase {
        data object Idle : AdPhase
        data class Skipped(val reason: AdSkipReason) : AdPhase
        data object Requesting : AdPhase
        data object Loaded : AdPhase
        data object Presenting : AdPhase
        data class Failed(val reason: String) : AdPhase
        data object TimedOut : AdPhase
        data object Dismissed : AdPhase
    }

    sealed interface State {
        data object Loading : State
        data object PresentingAd : State
        data class Finished(val adShown: Boolean, val skipReason: AdSkipReason) : State
    }

    sealed interface Event {
        data object CatalogLoaded : Event
        data object MinTimerFired : Event
        data class AdDecided(val decision: AppOpenAdPolicy.Decision) : Event
        data object AdLoaded : Event
        data class AdFailed(val reason: String) : Event
        data object AdTimedOut : Event
        data object AdDismissed : Event
    }

    var state: State = State.Loading
        private set
    var adPhase: AdPhase = AdPhase.Idle
        private set
    var catalogLoaded = false
        private set
    private var minTimerDone = false

    /** True once the ad sub-flow can no longer block the splash. */
    val adResolved: Boolean
        get() = adPhase != AdPhase.Idle && adPhase != AdPhase.Requesting

    /** True exactly when the caller should fire the real SDK request. */
    val wantsAdRequest: Boolean get() = adPhase == AdPhase.Requesting

    /** "This action can contain ads" shows only while a request is actually in play. */
    val showsAdDisclaimer: Boolean
        get() = adPhase == AdPhase.Requesting || adPhase == AdPhase.Loaded || adPhase == AdPhase.Presenting

    fun apply(event: Event) {
        if (state is State.Finished) return
        when (event) {
            Event.CatalogLoaded -> catalogLoaded = true
            Event.MinTimerFired -> minTimerDone = true
            is Event.AdDecided -> if (adPhase == AdPhase.Idle) {
                adPhase = when (val d = event.decision) {
                    AppOpenAdPolicy.Decision.Eligible -> AdPhase.Requesting
                    is AppOpenAdPolicy.Decision.Skip -> AdPhase.Skipped(d.reason)
                }
            }
            Event.AdLoaded -> fromRequesting(AdPhase.Loaded)
            is Event.AdFailed -> fromRequesting(AdPhase.Failed(event.reason))
            Event.AdTimedOut -> fromRequesting(AdPhase.TimedOut)
            Event.AdDismissed -> if (state == State.PresentingAd) adPhase = AdPhase.Dismissed
        }
        advance()
    }

    private fun fromRequesting(phase: AdPhase) {
        if (adPhase == AdPhase.Requesting) adPhase = phase
    }

    private fun advance() {
        when (state) {
            State.Loading -> {
                if (!catalogLoaded || !minTimerDone || !adResolved) return
                if (adPhase == AdPhase.Loaded) {
                    adPhase = AdPhase.Presenting
                    state = State.PresentingAd
                } else {
                    state = State.Finished(adShown = false, skipReason = skipReason())
                }
            }
            State.PresentingAd -> if (adPhase == AdPhase.Dismissed) {
                state = State.Finished(adShown = true, skipReason = AdSkipReason.NONE)
            }
            is State.Finished -> Unit
        }
    }

    private fun skipReason(): AdSkipReason = when (val phase = adPhase) {
        is AdPhase.Skipped -> phase.reason
        is AdPhase.Failed -> AdSkipReason.LOAD_FAILED
        AdPhase.TimedOut -> AdSkipReason.TIMEOUT
        else -> AdSkipReason.NONE
    }

    companion object {
        const val MIN_DURATION_MS = 1_500L
        const val AD_TIMEOUT_MS = 5_000L

        /**
         * Real-readiness progress: `max(previous, min(elapsed/min, readiness))`,
         * readiness = 0.3 × catalog + 0.7 × adResolved. Monotonic, never ahead of
         * readiness, never complete before the minimum duration.
         */
        fun progress(
            elapsedMs: Long,
            catalogLoaded: Boolean,
            adResolved: Boolean,
            previous: Double,
            minDurationMs: Long = MIN_DURATION_MS,
        ): Double {
            val readiness = (if (catalogLoaded) 0.3 else 0.0) + (if (adResolved) 0.7 else 0.0)
            val timeFactor = if (minDurationMs > 0) minOf(elapsedMs.toDouble() / minDurationMs, 1.0) else 1.0
            return minOf(maxOf(previous, minOf(timeFactor, readiness)), 1.0)
        }
    }
}
