package com.appcentral.guarddog.ui

import android.Manifest
import android.os.Build
import androidx.activity.compose.LocalActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.appcentral.guarddog.GuardDogApp
import com.appcentral.guarddog.R
import com.appcentral.guarddog.core.PocketGuardLogic
import com.appcentral.guarddog.core.TouchGuardLogic
import com.appcentral.guarddog.guard.GuardEngine
import com.appcentral.guarddog.ui.theme.GDColor
import com.appcentral.guarddog.ui.theme.GDType

/**
 * Two tabs + the alarm overlay hoisted ABOVE the tab bar (a reachable tab bar during
 * an alarm would be an escape hatch).
 */
@Composable
fun MainScreen(app: GuardDogApp) {
    val activity = LocalActivity.current ?: return
    val engine = app.engine
    val prefs = app.prefs

    val touch by engine.touchUi.collectAsStateWithLifecycle()
    val pocket by engine.pocketUi.collectAsStateWithLifecycle()
    val selectedGuard by prefs.selectedGuard.collectAsStateWithLifecycle()
    val sensitivity by prefs.sensitivity.collectAsStateWithLifecycle()
    val showVolumeTip by prefs.showVolumeTip.collectAsStateWithLifecycle()

    var tab by rememberSaveable { mutableIntStateOf(0) }
    var touchError by remember { mutableStateOf<String?>(null) }
    var pocketError by remember { mutableStateOf<String?>(null) }
    var showExplainer by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { app.ads.gatherConsent(activity) }

    val noMotionSensor = stringResource(R.string.touch_error_no_motion_sensor)
    val noProximity = stringResource(R.string.pocket_error_no_sensor)

    fun armTouch() {
        if (engine.armTouch(selectedGuard, sensitivity) == GuardEngine.ArmResult.NoSensor) touchError = noMotionSensor
    }

    // Ask first, arm after: arming before the system dialog is answered would let the
    // user's own tap on "Allow" set off the alarm once grace ends.
    val notifPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { armTouch() }

    fun onTouchHero() {
        touchError = null
        if (touch.state == TouchGuardLogic.State.DISARMED) {
            if (prefs.hasSeenNotifExplainer) armTouch() else showExplainer = true
        } else {
            // A use = user disarm from MONITORING. Grace-cancels don't count; the
            // alarm-dismiss path never reaches here.
            if (engine.disarmTouch() == TouchGuardLogic.State.MONITORING) {
                app.ads.attemptInterstitial(activity, engine.isAnyActive)
            }
        }
    }

    fun onPocketHero() {
        pocketError = null
        if (pocket.state == PocketGuardLogic.State.DISARMED) {
            if (engine.armPocket(selectedGuard) == GuardEngine.ArmResult.NoSensor) pocketError = noProximity
        } else if (engine.disarmPocket() == PocketGuardLogic.State.MONITORING) {
            app.ads.attemptInterstitial(activity, engine.isAnyActive)
        }
    }

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            containerColor = GDColor.skyPrimary,
            bottomBar = {
                NavigationBar(containerColor = GDColor.surface) {
                    TabItem(selected = tab == 0, emoji = "🛡️", label = stringResource(R.string.tab_dont_touch)) { tab = 0 }
                    TabItem(selected = tab == 1, emoji = "👖", label = stringResource(R.string.tab_pocket_mode)) { tab = 1 }
                }
            },
        ) { padding ->
            Box(Modifier.padding(padding)) {
                if (tab == 0) {
                    DontTouchScreen(
                        touch = touch,
                        selectedGuard = selectedGuard,
                        sensitivity = sensitivity,
                        showVolumeTip = showVolumeTip,
                        error = touchError,
                        onHeroTap = ::onTouchHero,
                        onSelectGuard = prefs::selectGuard,
                        onSensitivity = prefs::setSensitivity,
                        onDismissVolumeTip = prefs::dismissVolumeTip,
                    )
                } else {
                    PocketScreen(pocket = pocket, error = pocketError, onHeroTap = ::onPocketHero)
                }
            }
        }

        val touchAlarming = touch.state == TouchGuardLogic.State.ALARMING
        val pocketAlarming = pocket.state == PocketGuardLogic.State.ALARMING
        AnimatedVisibility(visible = touchAlarming || pocketAlarming, enter = fadeIn(), exit = fadeOut()) {
            if (pocketAlarming) {
                AlarmOverlay(pocket.armedGuard, stringResource(R.string.pocket_status_alarming)) { engine.disarmPocket() }
            } else {
                AlarmOverlay(touch.armedGuard, stringResource(R.string.touch_status_alarming)) { engine.disarmTouch() }
            }
        }
    }

    if (showExplainer) {
        AlertDialog(
            onDismissRequest = {},
            title = { Text(stringResource(R.string.touch_notif_explainer_title)) },
            text = { Text(stringResource(R.string.touch_notif_explainer_body)) },
            confirmButton = {
                TextButton(onClick = {
                    showExplainer = false
                    prefs.hasSeenNotifExplainer = true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        notifPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else {
                        armTouch()
                    }
                }) { Text(stringResource(R.string.touch_notif_explainer_ok)) }
            },
        )
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.TabItem(
    selected: Boolean,
    emoji: String,
    label: String,
    onClick: () -> Unit,
) {
    NavigationBarItem(
        selected = selected,
        onClick = onClick,
        icon = { Text(emoji, fontSize = 22.sp) },
        label = { Text(label, style = GDType.caption) },
        colors = NavigationBarItemDefaults.colors(
            selectedTextColor = GDColor.ctaBlue,
            unselectedTextColor = GDColor.textSecondary,
            indicatorColor = GDColor.skyTint.copy(alpha = 0.5f),
        ),
    )
}
