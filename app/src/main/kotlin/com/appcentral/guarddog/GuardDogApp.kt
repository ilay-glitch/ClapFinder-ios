package com.appcentral.guarddog

import android.app.Application
import com.appcentral.guarddog.ads.AdsManager
import com.appcentral.guarddog.core.AnalyticsClient
import com.appcentral.guarddog.data.LogcatAnalytics
import com.appcentral.guarddog.data.Prefs
import com.appcentral.guarddog.guard.GuardEngine
import com.appcentral.guarddog.guard.Notifications
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

class GuardDogApp : Application() {

    lateinit var prefs: Prefs
        private set
    lateinit var analytics: AnalyticsClient
        private set
    lateinit var engine: GuardEngine
        private set
    lateinit var ads: AdsManager
        private set

    val appScope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /** Process-lifetime facts: the splash runs on cold launch only, max one app open ad. */
    var splashDoneThisProcess = false
    var appOpenAdShownThisProcess = false

    override fun onCreate() {
        super.onCreate()
        prefs = Prefs(this)
        analytics = LogcatAnalytics()
        Notifications.createChannels(this)

        // Fail loud: a session marker surviving into a fresh process means the system
        // killed us while armed. The user must not believe they're still guarded.
        if (prefs.activeSession != null) {
            prefs.activeSession = null
            Notifications.postStandDown(this)
        }

        engine = GuardEngine(this, prefs, analytics, appScope)
        engine.onSessionCompleted = { prefs.hasCompletedFirstSession = true; ads.recordUse() }
        ads = AdsManager(this, prefs, analytics)
    }
}

