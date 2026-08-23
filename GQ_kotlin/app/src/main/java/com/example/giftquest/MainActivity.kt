package com.example.giftquest

import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.runtime.*
import androidx.core.splashscreen.SplashScreen
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import com.example.giftquest.ui.splash.BrandedSplash

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val splash: SplashScreen = installSplashScreen()
        splash.setOnExitAnimationListener { provider ->
            provider.view
                .animate()
                .alpha(0f)
                .setDuration(200)
                .withEndAction { provider.remove() }
                .start()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1)
        }

        // ← This one line fixes keyboard pushing content up, app-wide
        WindowCompat.setDecorFitsSystemWindows(window, false)

        super.onCreate(savedInstanceState)
        setContent {
            var showBranded by remember { mutableStateOf(true) }

            Crossfade(
                targetState = showBranded,
                animationSpec = tween(500)
            ) { isSplash ->
                if (isSplash) {
                    BrandedSplash(
                        durationMs = 1800,
                        onFinish = { showBranded = false }
                    )
                } else {
                    GiftQuestApp()
                }
            }
        }
    }
}