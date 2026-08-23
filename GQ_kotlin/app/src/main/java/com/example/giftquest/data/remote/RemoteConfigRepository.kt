package com.example.giftquest.data.remote

import android.util.Log
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await

private const val TAG = "GiftQuest"

data class AppConfig(
    val latestVersion: Int = 1,
    val latestVersionName: String = "1.0.1",
    val downloadUrl: String = "",
    val releaseNotes: String = "",        // ← add this too
    val aiDifficulty: String = "medium",
    val aiSystemPrompt: String = DEFAULT_SYSTEM_PROMPT,
    val aiTemperature: Double = 0.7,
    val aiMaxTokens: Int = 500
) {
    companion object {
        const val DEFAULT_SYSTEM_PROMPT = ""
    }
}

class RemoteConfigRepository(
    private val fs: FirebaseFirestore = FirebaseFirestore.getInstance()
) {
    private val configDoc get() = fs.collection("config").document("appConfig")

    /** One-shot fetch */
    suspend fun getAppConfig(): AppConfig {
        return try {
            val doc = configDoc.get().await()
            AppConfig(
                latestVersion     = (doc.getLong("latestVersion") ?: 1).toInt(),
                latestVersionName = doc.getString("latestVersionName") ?: "1.0.1",  // ← add
                downloadUrl       = doc.getString("downloadUrl") ?: "",
                releaseNotes = doc.getString("releaseNotes") ?: "",
                aiDifficulty      = doc.getString("aiDifficulty") ?: "medium",
                aiSystemPrompt    = doc.getString("aiSystemPrompt") ?: AppConfig.DEFAULT_SYSTEM_PROMPT,
                aiTemperature     = doc.getDouble("aiTemperature") ?: 0.7,
                aiMaxTokens       = (doc.getLong("aiMaxTokens") ?: 500).toInt()
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to fetch remote config, using defaults: ${e.message}")
            AppConfig()
        }
    }

    /** Live-updating flow — AI config changes apply instantly without restart */
    fun appConfigFlow(): Flow<AppConfig> = callbackFlow {
        val listener = configDoc.addSnapshotListener { snap, error ->
            if (error != null) {
                Log.w(TAG, "Config listener error: ${error.message}")
                trySend(AppConfig())
                return@addSnapshotListener
            }
            val config = snap?.let {
                AppConfig(
                    latestVersion     = (it.getLong("latestVersion") ?: 1).toInt(),
                    latestVersionName = it.getString("latestVersionName") ?: "1.0.1",  // ← add
                    downloadUrl       = it.getString("downloadUrl") ?: "",
                    releaseNotes = it.getString("releaseNotes") ?: "",
                    aiDifficulty      = it.getString("aiDifficulty") ?: "medium",
                    aiSystemPrompt    = it.getString("aiSystemPrompt") ?: AppConfig.DEFAULT_SYSTEM_PROMPT,
                    aiTemperature     = it.getDouble("aiTemperature") ?: 0.7,
                    aiMaxTokens       = (it.getLong("aiMaxTokens") ?: 500).toInt()
                )
            } ?: AppConfig()
            trySend(config)
        }
        awaitClose { listener.remove() }
    }
}