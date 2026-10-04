package com.appcentral.guarddog.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.appcentral.guarddog.R
import com.appcentral.guarddog.core.Guard
import com.appcentral.guarddog.core.GuardCatalog
import com.appcentral.guarddog.core.Sensitivity
import com.appcentral.guarddog.core.TouchGuardLogic
import com.appcentral.guarddog.core.TouchGuardLogic.State
import com.appcentral.guarddog.guard.GuardEngine
import com.appcentral.guarddog.ui.theme.GDColor
import com.appcentral.guarddog.ui.theme.GDRadius
import com.appcentral.guarddog.ui.theme.GDSpacing
import com.appcentral.guarddog.ui.theme.GDType

/**
 * The Don't Touch tab, top → bottom: header, mascot, shield hero, status,
 * one-line explainer, volume tip, guard grid, sensitivity.
 */
@Composable
fun DontTouchScreen(
    touch: GuardEngine.TouchUi,
    selectedGuard: Guard,
    sensitivity: Sensitivity,
    showVolumeTip: Boolean,
    error: String?,
    onHeroTap: () -> Unit,
    onSelectGuard: (Guard) -> Unit,
    onSensitivity: (Sensitivity) -> Unit,
    onDismissVolumeTip: () -> Unit,
) {
    Box(Modifier.fillMaxSize()) {
        GuardBackground()
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = GDSpacing.md),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(GDSpacing.lg))
            Text(stringResource(R.string.home_title), style = GDType.display, color = GDColor.textPrimary)
            Text(stringResource(R.string.home_subtitle), style = GDType.callout, color = GDColor.textSecondary)

            Image(
                painterResource(if (touch.state == State.DISARMED) R.drawable.guard_dog_shield else R.drawable.guard_dog_watching),
                contentDescription = null,
                modifier = Modifier.padding(top = GDSpacing.md).height(130.dp),
            )

            TouchHero(touch, onHeroTap)

            Spacer(Modifier.height(GDSpacing.md))
            when (touch.state) {
                State.DISARMED -> StatusLine(stringResource(R.string.touch_status_disarmed), StatusKind.IDLE)
                State.GRACE -> StatusLine(stringResource(R.string.touch_status_grace), StatusKind.ARMING)
                State.MONITORING -> StatusLine(stringResource(R.string.touch_status_monitoring), StatusKind.ON_DUTY)
                State.ALARMING -> StatusLine(stringResource(R.string.touch_status_alarming), StatusKind.ALARM)
            }
            if (touch.state == State.DISARMED) {
                Text(
                    stringResource(R.string.touch_how_it_works),
                    style = GDType.caption,
                    color = GDColor.textTertiary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = GDSpacing.xs),
                )
            }

            if (showVolumeTip) VolumeTip(onDismissVolumeTip)

            error?.let {
                Text(it, style = GDType.caption, color = GDColor.alarmRed, textAlign = TextAlign.Center, modifier = Modifier.padding(top = GDSpacing.xs))
            }

            Spacer(Modifier.height(GDSpacing.xl))
            Text(
                stringResource(R.string.animals_header),
                style = GDType.headline,
                color = GDColor.textPrimary,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(GDSpacing.md))
            Column(verticalArrangement = Arrangement.spacedBy(GDSpacing.sm)) {
                GuardCatalog.all.chunked(4).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(GDSpacing.sm)) {
                        row.forEach { guard ->
                            // While armed, the session keeps the voice it was armed with;
                            // a new choice applies from the next arm.
                            GuardCard(guard, selected = guard.id == selectedGuard.id) { onSelectGuard(guard) }
                        }
                    }
                }
            }

            Spacer(Modifier.height(GDSpacing.lg))
            SensitivityControl(sensitivity, onSensitivity)
            Spacer(Modifier.height(GDSpacing.xxl))
        }
    }
}

@Composable
private fun TouchHero(touch: GuardEngine.TouchUi, onTap: () -> Unit) {
    val armed = touch.state != State.DISARMED
    Box(Modifier.padding(top = GDSpacing.lg).height(180.dp).fillMaxWidth(), contentAlignment = Alignment.Center) {
        PulseRings(active = touch.state == State.MONITORING || touch.state == State.ALARMING, diameter = 72.dp)
        if (touch.state == State.GRACE) {
            GraceRing(
                fraction = touch.graceRemaining / (TouchGuardLogic.GRACE_PERIOD_MS / 1000f),
                diameter = 92.dp,
            )
        }
        HeroCircle(
            size = 72.dp,
            filled = armed,
            contentDescription = stringResource(if (armed) R.string.a11y_touch_armed else R.string.a11y_touch_disarmed),
            onClick = onTap,
        ) {
            if (touch.state == State.GRACE) {
                Text("${touch.graceRemaining}", style = GDType.title1, color = GDColor.textPrimary)
            } else {
                Text("🛡️", fontSize = 28.sp, color = if (armed) GDColor.textPrimary else GDColor.textTertiary)
            }
        }
    }
}

@Composable
private fun VolumeTip(onDismiss: () -> Unit) {
    Row(
        Modifier
            .padding(top = GDSpacing.md)
            .fillMaxWidth()
            .background(GDColor.cream, RoundedCornerShape(GDRadius.card))
            .padding(GDSpacing.md),
        verticalAlignment = Alignment.Top,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(GDSpacing.xs)) {
            Text(stringResource(R.string.volume_tip_title), style = GDType.headline, color = GDColor.textPrimary)
            Text(stringResource(R.string.volume_tip_body), style = GDType.caption, color = GDColor.textSecondary)
        }
        TextButton(onClick = onDismiss) {
            Text(stringResource(R.string.volume_tip_dismiss), style = GDType.caption, color = GDColor.ctaBlue)
        }
    }
}
