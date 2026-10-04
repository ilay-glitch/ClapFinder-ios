package com.appcentral.guarddog.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Brand tokens (ANDROID_HANDOFF §2.3, DESIGN.md). The only place color literals live. */
object GDColor {
    val skyPrimary = Color(0xFF5BB8FF)
    val skyTint = Color(0xFFA8DCFF)
    val surface = Color(0xFFFFFFFF)
    val cream = Color(0xFFF5EEE0)
    val ctaBlue = Color(0xFF2D7FF9)
    val textPrimary = Color(0xFF14233D)
    val textSecondary = textPrimary.copy(alpha = 0.60f)
    val textTertiary = textPrimary.copy(alpha = 0.40f)
    val borderSubtle = textPrimary.copy(alpha = 0.10f)
    val listeningActive = Color(0xFF22C55E)
    val alarmRed = Color(0xFFFF3B30)
}

object GDSpacing {
    val xs = 4.dp
    val sm = 8.dp
    val md = 16.dp
    val lg = 24.dp
    val xl = 32.dp
    val xxl = 48.dp
}

object GDRadius {
    val card = 20.dp
    val button = 16.dp
    val animalCard = 14.dp
}

object GDType {
    val display = TextStyle(fontSize = 34.sp, fontWeight = FontWeight.Bold)
    val title1 = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.Bold)
    val title2 = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
    val headline = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    val body = TextStyle(fontSize = 16.sp)
    val callout = TextStyle(fontSize = 15.sp)
    val caption = TextStyle(fontSize = 12.sp)
}

@Composable
fun GuardDogTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = GDColor.ctaBlue,
            onPrimary = Color.White,
            background = GDColor.skyPrimary,
            surface = GDColor.surface,
            onSurface = GDColor.textPrimary,
            onBackground = GDColor.textPrimary,
        ),
        content = content,
    )
}
