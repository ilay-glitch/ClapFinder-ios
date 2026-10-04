package com.appcentral.guarddog.data

import android.util.Log
import com.appcentral.guarddog.core.AnalyticsClient
import com.appcentral.guarddog.core.AnalyticsEvent

/** Default transport until a real analytics SDK lands: `adb logcat -s GuardDogAnalytics`. */
class LogcatAnalytics : AnalyticsClient {
    override fun log(event: AnalyticsEvent) {
        Log.i("GuardDogAnalytics", "${event.name} ${event.params}")
    }
}
