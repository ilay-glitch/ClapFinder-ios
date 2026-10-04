package com.appcentral.guarddog.ui

import androidx.activity.compose.LocalActivity
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.StartOffset
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.appcentral.guarddog.GuardDogApp
import com.appcentral.guarddog.R
import com.appcentral.guarddog.ui.theme.GDColor
import com.appcentral.guarddog.ui.theme.GDSpacing
import com.appcentral.guarddog.ui.theme.GDType

/** Cold-launch splash; doubles as the App Open Ad loading window. */
@Composable
fun SplashScreen(onFinished: () -> Unit, vm: SplashViewModel = viewModel()) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    val activity = LocalActivity.current ?: return
    val app = activity.application as GuardDogApp

    LaunchedEffect(Unit) { vm.start(activity) }
    LaunchedEffect(ui.finished) { if (ui.finished) onFinished() }
    LaunchedEffect(ui.adToPresent) {
        ui.adToPresent?.let { ad -> app.ads.showAppOpen(activity, ad) { vm.onAdDismissed() } }
    }

    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .background(GDColor.skyPrimary)
            .systemBarsPadding(),
    ) {
        val h = maxHeight
        val w = maxWidth
        Column(
            Modifier.fillMaxWidth().padding(top = h * 0.12f).padding(horizontal = GDSpacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(GDSpacing.sm),
        ) {
            Text(stringResource(R.string.home_title), style = GDType.display, fontWeight = FontWeight.Black, color = GDColor.textPrimary)
            Text(
                stringResource(R.string.splash_tagline),
                style = GDType.callout,
                fontWeight = FontWeight.SemiBold,
                color = GDColor.textPrimary.copy(alpha = 0.85f),
                textAlign = TextAlign.Center,
            )
        }

        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            RadarRings()
            Image(
                painter = painterResource(R.drawable.guard_dog_shield),
                contentDescription = null,
                modifier = Modifier
                    .width(minOf(w * 0.8f, 340.dp))
                    .offset(y = rememberBob(10f, 1_400).dp),
            )
        }

        Column(
            Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 44.dp)
                .padding(bottom = 64.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(GDSpacing.md),
        ) {
            val percent = (ui.progress * 100).toInt()
            Text(
                stringResource(R.string.splash_loading, percent),
                style = GDType.callout,
                fontWeight = FontWeight.Bold,
                color = GDColor.textPrimary,
            )
            ProgressBar(ui.progress.toFloat())
            if (ui.showAdDisclaimer) {
                Text(stringResource(R.string.splash_ad_disclaimer), style = GDType.caption, color = GDColor.textSecondary)
            }
        }
    }
}

@Composable
private fun ProgressBar(progress: Float) {
    BoxWithConstraints(
        Modifier
            .fillMaxWidth()
            .height(14.dp)
            .clip(CircleShape)
            .background(GDColor.surface.copy(alpha = 0.5f)),
    ) {
        Box(
            Modifier
                .height(14.dp)
                .width(maxOf(maxWidth * progress, 14.dp))
                .clip(CircleShape)
                .background(GDColor.ctaBlue),
        )
    }
}

@Composable
private fun RadarRings() {
    val transition = rememberInfiniteTransition(label = "radar")
    val rings = List(3) { index ->
        transition.animateFloat(
            0f,
            1f,
            infiniteRepeatable(tween(2_000, easing = LinearEasing), RepeatMode.Restart, StartOffset(index * 600)),
            label = "radar$index",
        )
    }
    Canvas(Modifier.size(150.dp * 2.3f)) {
        val base = 75.dp.toPx()
        rings.forEach { ring ->
            val t = ring.value
            drawCircle(
                color = GDColor.ctaBlue,
                radius = base * (0.7f + 1.6f * t),
                alpha = 0.6f * (1f - t) * 0.6f,
                style = Stroke(width = 3.dp.toPx()),
            )
        }
    }
}
