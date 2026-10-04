package com.appcentral.guarddog.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.appcentral.guarddog.R
import com.appcentral.guarddog.core.Guard
import com.appcentral.guarddog.ui.theme.GDColor
import com.appcentral.guarddog.ui.theme.GDRadius
import com.appcentral.guarddog.ui.theme.GDSpacing
import com.appcentral.guarddog.ui.theme.GDType

/**
 * Full-screen alarm: the SELECTED guard's emoji bouncing + a giant DISARM. Covers
 * everything including the tab bar, swallows Back and every stray tap — DISARM is
 * the only way out.
 */
@Composable
fun AlarmOverlay(guard: Guard?, title: String, onDisarm: () -> Unit) {
    BackHandler { /* no escape hatch */ }
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.55f))
            .background(Color.Red.copy(alpha = 0.32f))
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { },
    ) {
        Column(
            Modifier.fillMaxSize().systemBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(GDSpacing.xl),
        ) {
            Spacer(Modifier.weight(1f))
            Text(guard?.emoji ?: "🛡️", fontSize = 120.sp, modifier = Modifier.offset(y = rememberBob(24f, 400).dp))
            Text(title, style = GDType.title1, color = GDColor.textPrimary)
            Spacer(Modifier.weight(1f))
            Box(
                Modifier
                    .padding(horizontal = GDSpacing.lg)
                    .padding(bottom = GDSpacing.xxl)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(GDRadius.card))
                    .background(GDColor.ctaBlue)
                    .clickable(role = Role.Button, onClick = onDisarm)
                    .padding(vertical = GDSpacing.lg),
                contentAlignment = Alignment.Center,
            ) {
                Text(stringResource(R.string.touch_disarm), style = GDType.title1, fontWeight = FontWeight.Black, color = GDColor.textPrimary)
            }
        }
    }
}
