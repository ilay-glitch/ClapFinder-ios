package com.appcentral.guarddog.data

import android.content.Context
import androidx.core.content.edit
import com.appcentral.guarddog.core.Guard
import com.appcentral.guarddog.core.GuardCatalog
import com.appcentral.guarddog.core.InterstitialStore
import com.appcentral.guarddog.core.Sensitivity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Every persisted fact the app keeps. SharedPreferences-backed; observable where UI needs it. */
class Prefs(context: Context) : InterstitialStore {

    private val sp = context.getSharedPreferences("guard_dog", Context.MODE_PRIVATE)

    private val _selectedGuard = MutableStateFlow(GuardCatalog.byId(sp.getString(KEY_GUARD, null)))
    val selectedGuard: StateFlow<Guard> = _selectedGuard.asStateFlow()

    private val _sensitivity = MutableStateFlow(Sensitivity.fromKey(sp.getString(KEY_SENSITIVITY, null)))
    val sensitivity: StateFlow<Sensitivity> = _sensitivity.asStateFlow()

    private val _showVolumeTip = MutableStateFlow(computeShowVolumeTip())
    val showVolumeTip: StateFlow<Boolean> = _showVolumeTip.asStateFlow()

    fun selectGuard(guard: Guard) {
        sp.edit { putString(KEY_GUARD, guard.id) }
        _selectedGuard.value = guard
    }

    fun setSensitivity(sensitivity: Sensitivity) {
        sp.edit { putString(KEY_SENSITIVITY, sensitivity.key) }
        _sensitivity.value = sensitivity
    }

    var onboardingCompleted: Boolean
        get() = sp.getBoolean(KEY_ONBOARDING, false)
        set(value) = sp.edit { putBoolean(KEY_ONBOARDING, value) }

    /** The one-time "we'll ask for notifications" explainer before the first arm. */
    var hasSeenNotifExplainer: Boolean
        get() = sp.getBoolean(KEY_NOTIF_EXPLAINER, false)
        set(value) = sp.edit { putBoolean(KEY_NOTIF_EXPLAINER, value) }

    var hasCompletedFirstSession: Boolean
        get() = sp.getBoolean(KEY_FIRST_SESSION, false)
        set(value) {
            sp.edit { putBoolean(KEY_FIRST_SESSION, value) }
            _showVolumeTip.value = computeShowVolumeTip()
        }

    fun dismissVolumeTip() {
        sp.edit { putBoolean(KEY_VOLUME_TIP_DISMISSED, true) }
        _showVolumeTip.value = false
    }

    private fun computeShowVolumeTip() =
        sp.getBoolean(KEY_FIRST_SESSION, false) && !sp.getBoolean(KEY_VOLUME_TIP_DISMISSED, false)

    // App Open Ad (rules 2 and 4)
    var hasCompletedFirstLaunch: Boolean
        get() = sp.getBoolean(KEY_FIRST_LAUNCH, false)
        set(value) = sp.edit { putBoolean(KEY_FIRST_LAUNCH, value) }

    var appOpenLastShownAtMs: Long?
        get() = sp.getLong(KEY_APP_OPEN_LAST, -1L).takeIf { it >= 0 }
        set(value) = sp.edit { if (value == null) remove(KEY_APP_OPEN_LAST) else putLong(KEY_APP_OPEN_LAST, value) }

    // Interstitial frequency cap
    override var usesSinceLast: Int
        get() = sp.getInt(KEY_USES, 0)
        set(value) = sp.edit { putInt(KEY_USES, value) }

    override var threshold: Int?
        get() = sp.getInt(KEY_THRESHOLD, -1).takeIf { it >= 0 }
        set(value) = sp.edit { if (value == null) remove(KEY_THRESHOLD) else putInt(KEY_THRESHOLD, value) }

    /**
     * The mode that is armed right now, written synchronously. If the process dies
     * while armed, the next launch finds it set and fails loud.
     */
    var activeSession: String?
        get() = sp.getString(KEY_ACTIVE_SESSION, null)
        set(value) = sp.edit(commit = true) {
            if (value == null) remove(KEY_ACTIVE_SESSION) else putString(KEY_ACTIVE_SESSION, value)
        }

    private companion object {
        const val KEY_GUARD = "guard.selectedId"
        const val KEY_SENSITIVITY = "guard.sensitivity"
        const val KEY_ONBOARDING = "onboarding.hasCompleted"
        const val KEY_NOTIF_EXPLAINER = "touchAlert.hasSeenNotifExplainer"
        const val KEY_FIRST_SESSION = "home.hasCompletedFirstSession"
        const val KEY_VOLUME_TIP_DISMISSED = "home.volumeTipDismissed"
        const val KEY_FIRST_LAUNCH = "appOpenAd.hasCompletedFirstLaunch"
        const val KEY_APP_OPEN_LAST = "appOpenAd.lastShownAt"
        const val KEY_USES = "interstitial.usesSinceLast"
        const val KEY_THRESHOLD = "interstitial.threshold"
        const val KEY_ACTIVE_SESSION = "guard.activeSession"
    }
}
