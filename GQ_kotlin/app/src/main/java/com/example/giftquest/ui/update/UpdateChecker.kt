package com.example.giftquest.ui.update

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import com.example.giftquest.data.remote.AppConfig
import com.example.giftquest.data.remote.RemoteConfigRepository
import kotlinx.coroutines.flow.catch

private const val TAG = "GiftQuest"

/** Drop this anywhere in your NavHost / GiftQuestApp to get automatic update prompts */
@Composable
fun UpdateChecker(currentVersion: Int) {
    val context = LocalContext.current
    var config by remember { mutableStateOf<AppConfig?>(null) }

    // Persist dismissal — user only sees dialog once per version
    val prefs = remember { context.getSharedPreferences("gq_prefs", Context.MODE_PRIVATE) }
    val dismissedVersion = remember { prefs.getInt("update_dismissed_version", -1) }
    var dismissed by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        RemoteConfigRepository().appConfigFlow()
            .catch { Log.w("GiftQuest", "UpdateChecker flow error: $it") }
            .collect { config = it }
    }

    val cfg = config ?: return
    if (cfg.latestVersion <= currentVersion) return
    if (dismissed) return
    if (dismissedVersion >= cfg.latestVersion) return // already dismissed this version
    if (cfg.downloadUrl.isBlank()) return

    AlertDialog(
        onDismissRequest = {
            dismissed = true
            prefs.edit().putInt("update_dismissed_version", cfg.latestVersion).apply()
        },
        title = { Text("Update Available 🎁") },
        text = {
            Text(
                "Version ${cfg.latestVersionName} is ready.\n\n" +
                        if (cfg.releaseNotes.isNotBlank()) cfg.releaseNotes else "Tap below to download."
            )
        },
        confirmButton = {
            TextButton(onClick = {
                context.startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(cfg.downloadUrl))
                )
                dismissed = true
                prefs.edit().putInt("update_dismissed_version", cfg.latestVersion).apply()
            }) { Text("Update Now") }
        },
        dismissButton = {
            TextButton(onClick = {
                dismissed = true
                prefs.edit().putInt("update_dismissed_version", cfg.latestVersion).apply()
            }) { Text("Later") }
        }
    )
}

private fun openUrl(context: Context, url: String) {
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    } catch (e: Exception) {
        Log.e(TAG, "Failed to open URL: ${e.message}")
    }
}