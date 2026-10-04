package com.appcentral.guarddog.ads

import android.app.Activity
import android.content.Context
import android.util.Log
import com.appcentral.guarddog.BuildConfig
import com.appcentral.guarddog.core.AnalyticsClient
import com.appcentral.guarddog.core.Events
import com.appcentral.guarddog.core.InterstitialCounter
import com.appcentral.guarddog.core.InterstitialPolicy
import com.appcentral.guarddog.data.Prefs
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.appopen.AppOpenAd
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Consent (UMP — replaces iOS's ATT), SDK init, and the two ad formats
 * (ANDROID_HANDOFF §3). No banner, by PM ruling.
 *
 * Consent is gathered on reaching Home. The first launch never requests an app
 * open ad, so consent always resolves before the first possible ad request.
 */
class AdsManager(
    private val context: Context,
    prefs: Prefs,
    private val analytics: AnalyticsClient,
) {
    private val consent: ConsentInformation = UserMessagingPlatform.getConsentInformation(context)
    private val initialized = AtomicBoolean(false)
    private val counter = InterstitialCounter(prefs)
    private var interstitial: InterstitialAd? = null
    private var interstitialLoading = false

    val canRequestAds: Boolean get() = consent.canRequestAds()

    /** Runs the UMP flow (shows a form only where required), then initialises the SDK. */
    fun gatherConsent(activity: Activity) {
        val params = ConsentRequestParameters.Builder().build()
        consent.requestConsentInfoUpdate(
            activity,
            params,
            {
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { error ->
                    error?.let { Log.w(TAG, "Consent form: ${it.message}") }
                    if (consent.canRequestAds()) initializeSdk()
                }
            },
            { error -> Log.w(TAG, "Consent update failed: ${error.message}") },
        )
        // A previous session's consent is enough to start right away.
        if (consent.canRequestAds()) initializeSdk()
    }

    /**
     * Refreshes consent without showing any form (the form belongs to Home), then
     * reports whether ads may be requested. UMP forgets the status between processes
     * until this runs, so the splash calls it before every app open request.
     */
    fun refreshConsent(activity: Activity, onResult: (canRequestAds: Boolean) -> Unit) {
        if (consent.canRequestAds()) return onResult(true)
        consent.requestConsentInfoUpdate(
            activity,
            ConsentRequestParameters.Builder().build(),
            { onResult(consent.canRequestAds()) },
            { error ->
                Log.w(TAG, "Consent update failed: ${error.message}")
                onResult(false)
            },
        )
    }

    private fun initializeSdk() {
        if (!initialized.compareAndSet(false, true)) return
        MobileAds.initialize(context) { preloadInterstitial() }
    }

    // region App Open

    /**
     * Loads one app open ad. Exactly one of the callbacks fires. The splash owns the
     * 5 s timeout and simply ignores a late result.
     */
    fun loadAppOpen(onLoaded: (AppOpenAd) -> Unit, onFailed: (String) -> Unit) {
        initializeSdk()
        AppOpenAd.load(
            context,
            BuildConfig.ADMOB_APP_OPEN_UNIT,
            AdRequest.Builder().build(),
            object : AppOpenAd.AppOpenAdLoadCallback() {
                override fun onAdLoaded(ad: AppOpenAd) = onLoaded(ad)
                override fun onAdFailedToLoad(error: LoadAdError) = onFailed(error.message)
            },
        )
    }

    fun showAppOpen(activity: Activity, ad: AppOpenAd, onDismissed: () -> Unit) {
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() = onDismissed()
            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                analytics.log(Events.appOpenAdFailed(error.message))
                onDismissed()
            }
        }
        ad.show(activity)
    }

    // endregion

    // region Interstitial

    /** A completed guard session. */
    fun recordUse() = counter.recordUse()

    /**
     * Only ever called at disarm-to-idle. Re-checks every rule; never shows while a
     * guard is armed or alarming.
     */
    fun attemptInterstitial(activity: Activity, isGuardActive: Boolean) {
        val ad = interstitial
        when (val decision = counter.decide(isGuardActive, isAdLoaded = ad != null)) {
            InterstitialPolicy.Decision.Show -> {
                val uses = counter.usesSinceLast
                interstitial = null
                ad!!.fullScreenContentCallback = object : FullScreenContentCallback() {
                    override fun onAdDismissedFullScreenContent() = preloadInterstitial()
                    override fun onAdFailedToShowFullScreenContent(error: AdError) = preloadInterstitial()
                }
                ad.show(activity)
                counter.onShown()
                analytics.log(Events.interstitialShown(uses))
            }
            is InterstitialPolicy.Decision.Suppress -> {
                analytics.log(Events.interstitialSuppressed(decision.reason))
                if (decision.reason == InterstitialPolicy.SuppressReason.NOT_LOADED) preloadInterstitial()
            }
        }
    }

    private fun preloadInterstitial() {
        if (!initialized.get() || interstitial != null || interstitialLoading) return
        interstitialLoading = true
        InterstitialAd.load(
            context,
            BuildConfig.ADMOB_INTERSTITIAL_UNIT,
            AdRequest.Builder().build(),
            object : InterstitialAdLoadCallback() {
                override fun onAdLoaded(ad: InterstitialAd) {
                    interstitialLoading = false
                    interstitial = ad
                }

                override fun onAdFailedToLoad(error: LoadAdError) {
                    interstitialLoading = false
                    Log.w(TAG, "Interstitial load failed: ${error.message}")
                }
            },
        )
    }

    // endregion

    private companion object {
        const val TAG = "AdsManager"
    }
}
