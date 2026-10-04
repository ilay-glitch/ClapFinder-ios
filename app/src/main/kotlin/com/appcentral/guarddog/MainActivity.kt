package com.appcentral.guarddog

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import android.graphics.Color
import com.appcentral.guarddog.ui.MainScreen
import com.appcentral.guarddog.ui.OnboardingScreen
import com.appcentral.guarddog.ui.SplashScreen
import com.appcentral.guarddog.ui.theme.GuardDogTheme

/** Cold launch: splash → onboarding (first launch only) → home. Warm resumes skip the splash. */
class MainActivity : ComponentActivity() {

    private enum class Screen { SPLASH, ONBOARDING, MAIN }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
        )
        val app = application as GuardDogApp

        setContent {
            GuardDogTheme {
                fun afterSplash() = if (app.prefs.onboardingCompleted) Screen.MAIN else Screen.ONBOARDING
                var screen by rememberSaveable {
                    mutableStateOf(if (app.splashDoneThisProcess) afterSplash() else Screen.SPLASH)
                }
                when (screen) {
                    Screen.SPLASH -> SplashScreen(onFinished = { screen = afterSplash() })
                    Screen.ONBOARDING -> OnboardingScreen(app.prefs) {
                        app.prefs.onboardingCompleted = true
                        screen = Screen.MAIN
                    }
                    Screen.MAIN -> MainScreen(app)
                }
            }
        }
    }
}
