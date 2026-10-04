package com.appcentral.guarddog.ui

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.appcentral.guarddog.R
import com.appcentral.guarddog.data.Prefs
import com.appcentral.guarddog.ui.theme.GDColor
import com.appcentral.guarddog.ui.theme.GDRadius
import com.appcentral.guarddog.ui.theme.GDSpacing
import com.appcentral.guarddog.ui.theme.GDType

/**
 * First-launch 3-step onboarding. Step 2 is the notification pre-permission
 * explainer: it shows *why*, then asks; grant or deny, it proceeds.
 */
@Composable
fun OnboardingScreen(prefs: Prefs, onFinished: () -> Unit) {
    var step by rememberSaveable { mutableIntStateOf(0) }
    val advance = { if (step >= 2) onFinished() else step += 1 }

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { advance() }

    Column(
        Modifier
            .fillMaxSize()
            .background(GDColor.skyPrimary)
            .systemBarsPadding()
            .padding(horizontal = GDSpacing.lg, vertical = GDSpacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            stringResource(R.string.onboarding_progress, step + 1),
            style = GDType.caption,
            fontWeight = FontWeight.Bold,
            color = GDColor.textSecondary,
        )
        Spacer(Modifier.weight(1f))
        AnimatedContent(step, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "step") { s ->
            when (s) {
                0 -> ArtStep(R.drawable.guard_dog_wave, R.string.onboarding_step1_title, R.string.onboarding_step1_body)
                1 -> NotificationStep()
                else -> ArtStep(R.drawable.guard_dog_shield, R.string.onboarding_step3_title, R.string.onboarding_step3_body)
            }
        }
        Spacer(Modifier.weight(1f))
        Button(
            onClick = {
                if (step == 1) {
                    prefs.hasSeenNotifExplainer = true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else {
                        advance()
                    }
                } else {
                    advance()
                }
            },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            shape = RoundedCornerShape(GDRadius.button),
            colors = ButtonDefaults.buttonColors(containerColor = GDColor.ctaBlue),
        ) {
            Text(
                stringResource(
                    when (step) {
                        0 -> R.string.onboarding_continue
                        1 -> R.string.onboarding_step2_cta
                        else -> R.string.onboarding_step3_cta
                    },
                ),
                style = GDType.headline,
                color = GDColor.surface,
            )
        }
    }
}

@Composable
private fun ArtStep(image: Int, title: Int, body: Int) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(GDSpacing.lg)) {
        Image(painterResource(image), contentDescription = null, modifier = Modifier.fillMaxWidth().height(220.dp))
        SpeechBubble(title, body)
    }
}

@Composable
private fun NotificationStep() {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(GDSpacing.lg)) {
        Box(Modifier.height(190.dp).fillMaxWidth(), contentAlignment = Alignment.Center) {
            repeat(2) { ring ->
                Box(
                    Modifier
                        .size((110 + ring * 44).dp)
                        .border(3.dp, GDColor.ctaBlue.copy(alpha = 0.30f), CircleShape),
                )
            }
            Text("🔔", fontSize = 52.sp)
            Image(
                painterResource(R.drawable.guard_dog_watching),
                contentDescription = null,
                modifier = Modifier.width(90.dp).offset(x = 78.dp, y = 56.dp),
            )
        }
        SpeechBubble(R.string.onboarding_step2_title, R.string.onboarding_step2_body)
    }
}

@Composable
private fun SpeechBubble(title: Int, body: Int) {
    val shape = RoundedCornerShape(GDRadius.card)
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(10.dp, shape, ambientColor = GDColor.textPrimary.copy(alpha = 0.08f))
            .background(GDColor.surface, shape)
            .padding(GDSpacing.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(GDSpacing.sm),
    ) {
        Text(stringResource(title), style = GDType.title2, color = GDColor.textPrimary, textAlign = TextAlign.Center)
        Text(stringResource(body), style = GDType.body, color = GDColor.textSecondary, textAlign = TextAlign.Center)
    }
}
