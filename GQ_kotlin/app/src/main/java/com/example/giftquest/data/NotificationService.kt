package com.example.giftquest.data

import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

private const val TAG = "GiftQuest"

// ← Replace with your actual Worker URL
private const val WORKER_URL = "https://giftquest-notifications.abdelnourbentaieb.workers.dev"

object NotificationService {

    /**
     * Save the FCM token for the current user to Firestore.
     * Called on app start and whenever the token refreshes.
     */
    suspend fun saveFcmToken(token: String) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        try {
            FirebaseFirestore.getInstance()
                .collection("users")
                .document(uid)
                .update("fcmToken", token)
                .await()
            Log.d(TAG, "FCM token saved for uid=$uid")
        } catch (e: Exception) {
            // User doc might not exist yet — set instead of update
            try {
                FirebaseFirestore.getInstance()
                    .collection("users")
                    .document(uid)
                    .set(mapOf("fcmToken" to token), com.google.firebase.firestore.SetOptions.merge())
                    .await()
            } catch (e2: Exception) {
                Log.w(TAG, "Could not save FCM token: ${e2.message}")
            }
        }
    }

    /**
     * Send a notification to a specific user via the Cloudflare Worker.
     * Fetches their FCM token from Firestore then calls the Worker.
     */
    suspend fun sendNotificationToUser(
        targetUid: String,
        title: String,
        message: String
    ) = withContext(Dispatchers.IO) {
        try {
            // Get the target user's FCM token
            val userDoc = FirebaseFirestore.getInstance()
                .collection("users")
                .document(targetUid)
                .get()
                .await()

            val fcmToken = userDoc.getString("fcmToken")
            if (fcmToken.isNullOrBlank()) {
                Log.w(TAG, "No FCM token found for uid=$targetUid")
                return@withContext
            }

            // Call Cloudflare Worker
            val url = URL(WORKER_URL)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true
            connection.connectTimeout = 10000
            connection.readTimeout = 10000

            val body = JSONObject().apply {
                put("fcmToken", fcmToken)
                put("title", title)
                put("message", message)
            }

            connection.outputStream.use { it.write(body.toString().toByteArray()) }

            val responseCode = connection.responseCode
            if (responseCode == 200) {
                Log.d(TAG, "Notification sent to uid=$targetUid")
            } else {
                val error = connection.errorStream?.bufferedReader()?.readText()
                Log.e(TAG, "Worker error $responseCode: $error")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to send notification: ${e.message}", e)
        }
    }
}