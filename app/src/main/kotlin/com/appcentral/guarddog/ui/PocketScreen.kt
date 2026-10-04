package com.appcentral.guarddog.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.appcentral.guarddog.R
import com.appcentral.guarddog.core.PocketGuardLogic.State
import com.appcentral.guarddog.guard.GuardEngine
import com.appcentral.guarddog.ui.theme.GDColor
import com.appcentral.guarddog.ui.theme.GDSpacing
import com.appcentral.guarddog.ui.theme.GDType

/**
 * Pocket Mode tab: same dog, new post. Arm → slide in → sustained cover engages
 * (chirp) → sustained uncover alarms. No sensitivity concept in v1.
 */
@Composable
fun PocketScreen(pocket: GuardEngine.PocketUi, error: String?, onHeroTap: () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        GuardBackground()
        Column(
            Modifier.fillMaxSize().padding(horizontal = GDSpacing.md),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(GDSpacing.lg))
            Text(stringResource(R.string.pocket_title), style = GDType.display, color = GDColor.textPrimary)
            Image(
                painterResource(R.drawable.guard_dog_watching),
                contentDescription = null,
                modifier = Modifier.padding(top = GDSpacing.md).height(140.dp),
            )

            Box(Modifier.padding(top = GDSpacing.md).height(200.dp).fillMaxWidth(), contentAlignment = Alignment.Center) {
                PulseRings(active = pocket.state == State.MONITORING, diameter = 72.dp)
                HeroCircle(
                    size = 160.dp,
                    filled = pocket.state != State.DISARMED,
                    contentDescription = stringResource(
                        if (pocket.state == State.DISARMED) R.string.pocket_arm else R.string.pocket_disarm,
                    ),
                    onClick = onHeroTap,
                ) {
                    Text(if (pocket.state == State.DISARMED) "👖" else "👀", fontSize = 56.sp)
                }
            }

            Spacer(Modifier.height(GDSpacing.sm))
            when (pocket.state) {
                State.DISARMED -> StatusLine(stringResource(R.string.pocket_status_disarmed), StatusKind.IDLE)
                State.AWAITING_POCKET -> StatusLine(stringResource(R.string.pocket_status_awaiting), StatusKind.ARMING)
                State.MONITORING -> StatusLine(stringResource(R.string.pocket_status_monitoring), StatusKind.ON_DUTY)
                State.ALARMING -> StatusLine(stringResource(R.string.pocket_status_alarming), StatusKind.ALARM)
            }
            if (pocket.state == State.DISARMED) {
                Text(
                    stringResource(R.string.pocket_how_it_works),
                    style = GDType.caption,
                    color = GDColor.textTertiary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = GDSpacing.xs),
                )
            }
            error?.let {
                Text(it, style = GDType.caption, color = GDColor.alarmRed, textAlign = TextAlign.Center, modifier = Modifier.padding(top = GDSpacing.xs))
            }
        }
    }
}
