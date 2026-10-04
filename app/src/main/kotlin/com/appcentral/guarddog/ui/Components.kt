package com.appcentral.guarddog.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.StartOffset
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.appcentral.guarddog.R
import com.appcentral.guarddog.core.Guard
import com.appcentral.guarddog.core.Sensitivity
import com.appcentral.guarddog.ui.theme.GDColor
import com.appcentral.guarddog.ui.theme.GDRadius
import com.appcentral.guarddog.ui.theme.GDSpacing
import com.appcentral.guarddog.ui.theme.GDType

private val pulseBrush = Brush.linearGradient(listOf(GDColor.skyTint, GDColor.ctaBlue))

/** Full-bleed illustrated backdrop under a 30% sky scrim. */
@Composable
fun GuardBackground() {
    Box(Modifier.fillMaxSize().background(GDColor.skyPrimary)) {
        Image(
            painter = painterResource(R.drawable.guard_dog_home_background),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
        )
        Box(Modifier.fillMaxSize().background(GDColor.skyPrimary.copy(alpha = 0.30f)))
    }
}

/** Three staggered rings expanding 1.0→2.4× and fading out over 2 s while active. */
@Composable
fun PulseRings(active: Boolean, diameter: Dp) {
    if (!active) return
    val transition = rememberInfiniteTransition(label = "pulse")
    val rings = List(3) { index ->
        transition.animateFloat(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 2_000, easing = LinearOutSlowInEasing),
                repeatMode = RepeatMode.Restart,
                initialStartOffset = StartOffset(index * 500),
            ),
            label = "ring$index",
        )
    }
    Canvas(Modifier.size(diameter * 2.4f)) {
        val base = diameter.toPx() / 2
        rings.forEach { ring ->
            val t = ring.value
            drawCircle(
                brush = pulseBrush,
                radius = base * (1f + 1.4f * t),
                alpha = 0.7f * (1f - t),
                style = Stroke(width = 2.dp.toPx()),
            )
        }
    }
}

/** Status line: tertiary when idle, secondary while arming, green dot when on duty, red when alarming. */
@Composable
fun StatusLine(text: String, kind: StatusKind) {
    val color = when (kind) {
        StatusKind.IDLE -> GDColor.textTertiary
        StatusKind.ARMING -> GDColor.textSecondary
        StatusKind.ON_DUTY -> GDColor.listeningActive
        StatusKind.ALARM -> GDColor.alarmRed
    }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
        if (kind == StatusKind.ON_DUTY) {
            Box(Modifier.size(8.dp).background(GDColor.listeningActive, CircleShape))
            Spacer(Modifier.width(GDSpacing.xs))
        }
        Text(text, style = GDType.callout, color = color, textAlign = TextAlign.Center)
    }
}

enum class StatusKind { IDLE, ARMING, ON_DUTY, ALARM }

/** 80×90 guard card: emoji + name; selected = 2dp cta border over a sky tint. */
@Composable
fun GuardCard(guard: Guard, selected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(GDRadius.animalCard)
    val label = stringResource(
        if (selected) R.string.a11y_animal_selected else R.string.a11y_animal_unselected,
        guard.name,
        guard.emoji,
    )
    Column(
        modifier = Modifier
            .size(width = 80.dp, height = 90.dp)
            .clip(shape)
            .background(GDColor.surface)
            .background(if (selected) GDColor.skyTint.copy(alpha = 0.5f) else Color.Transparent)
            .border(if (selected) 2.dp else 1.dp, if (selected) GDColor.ctaBlue else GDColor.borderSubtle, shape)
            .clickable(role = Role.RadioButton, onClick = onClick)
            .semantics {
                contentDescription = label
                this.selected = selected
            },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(guard.emoji, fontSize = 36.sp)
        Spacer(Modifier.height(GDSpacing.xs))
        Text(
            guard.name,
            style = GDType.caption,
            color = GDColor.textSecondary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** Segmented Low / Medium / High. */
@Composable
fun SensitivityControl(value: Sensitivity, onChange: (Sensitivity) -> Unit) {
    val shape = RoundedCornerShape(GDRadius.button)
    Column(verticalArrangement = Arrangement.spacedBy(GDSpacing.sm)) {
        Text(stringResource(R.string.sensitivity_label), style = GDType.callout, color = GDColor.textSecondary)
        Row(
            Modifier
                .fillMaxWidth()
                .clip(shape)
                .border(1.dp, GDColor.borderSubtle, shape),
        ) {
            Sensitivity.entries.forEach { level ->
                val selected = level == value
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .background(if (selected) GDColor.ctaBlue else GDColor.surface)
                        .clickable(role = Role.RadioButton) { onChange(level) }
                        .semantics { this.selected = selected }
                        .padding(vertical = GDSpacing.sm),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        stringResource(level.labelRes()),
                        style = GDType.callout,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                        color = if (selected) GDColor.textPrimary else GDColor.textSecondary,
                    )
                }
            }
        }
    }
}

private fun Sensitivity.labelRes() = when (this) {
    Sensitivity.LOW -> R.string.sensitivity_low
    Sensitivity.MEDIUM -> R.string.sensitivity_medium
    Sensitivity.HIGH -> R.string.sensitivity_high
}

/** Round hero button with a press-scale. */
@Composable
fun HeroCircle(
    size: Dp,
    filled: Boolean,
    contentDescription: String,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(size)
            .shadow(if (filled || size > 100.dp) 12.dp else 0.dp, CircleShape)
            .clip(CircleShape)
            .background(if (filled) GDColor.ctaBlue else if (size > 100.dp) GDColor.surface else Color.Transparent)
            .border(if (filled || size > 100.dp) 0.dp else 2.dp, Color.White, CircleShape)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) { content() }
}

/** Depleting countdown ring around the touch hero during grace. */
@Composable
fun GraceRing(fraction: Float, diameter: Dp) {
    val animated by animateFloatAsState(fraction, tween(1_000, easing = LinearEasing), label = "grace")
    Canvas(Modifier.size(diameter)) {
        drawArc(
            brush = pulseBrush,
            startAngle = -90f,
            sweepAngle = 360f * animated,
            useCenter = false,
            style = Stroke(width = 4.dp.toPx(), cap = StrokeCap.Round),
        )
    }
}

/** A gently bobbing modifier value for mascots (±[amplitude] dp). */
@Composable
fun rememberBob(amplitude: Float, periodMs: Int): Float {
    val anim = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        anim.animateTo(
            1f,
            infiniteRepeatable(tween(periodMs), RepeatMode.Reverse),
        )
    }
    return -amplitude * anim.value
}
