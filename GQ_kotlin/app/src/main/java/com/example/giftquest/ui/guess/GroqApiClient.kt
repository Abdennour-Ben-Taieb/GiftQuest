package com.example.giftquest.ui.guess

import android.util.Log
import com.example.giftquest.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

private const val TAG = "GiftQuest"

/**
 * Handles all Groq API calls.
 * Uses OpenAI-compatible chat completions format.
 */
object GroqApiClient {

    suspend fun call(
        systemPrompt: String,
        history: List<ChatMessage>,
        userMessage: String,
        model: String,
        retryCount: Int = 0
    ): String = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Calling Groq — model=$model, history=${history.size}, retry=$retryCount")

            val url = URL("https://api.groq.com/openai/v1/chat/completions")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Authorization", "Bearer ${BuildConfig.GROQ_API_KEY}")
            connection.doOutput = true
            connection.connectTimeout = 15000
            connection.readTimeout = 30000

            val messagesArray = JSONArray()

            // System prompt
            messagesArray.put(JSONObject().apply {
                put("role", "system")
                put("content", systemPrompt)
            })

            // Conversation history
            history.forEach { msg ->
                messagesArray.put(JSONObject().apply {
                    put("role", if (msg.sender == Sender.USER) "user" else "assistant")
                    put("content", msg.text)
                })
            }

            // Current user message
            messagesArray.put(JSONObject().apply {
                put("role", "user")
                put("content", userMessage)
            })

            val body = JSONObject().apply {
                put("model", model)
                put("messages", messagesArray)
                put("max_tokens", 300)
                put("temperature", 0.8)
            }
            Log.d(TAG, "System prompt being sent:\n$systemPrompt")
            connection.outputStream.use { it.write(body.toString().toByteArray()) }

            val responseCode = connection.responseCode
            Log.d(TAG, "Groq response code: $responseCode")

            // Rate limited — wait and retry
            if (responseCode == 429 && retryCount < 2) {
                Log.d(TAG, "Rate limited, waiting 30s before retry ${retryCount + 1}...")
                delay(30_000)
                return@withContext call(systemPrompt, history, userMessage, model, retryCount + 1)
            }

            val responseText = if (responseCode == 200) {
                connection.inputStream.bufferedReader().readText()
            } else {
                val error = connection.errorStream?.bufferedReader()?.readText() ?: "Unknown error"
                Log.e(TAG, "Groq error $responseCode: $error")
                return@withContext "Something went wrong (error $responseCode). Try again!"
            }

            val content = JSONObject(responseText)
                .getJSONArray("choices")
                .getJSONObject(0)
                .getJSONObject("message")
                .optString("content", "")
                .trim()

            if (content.isBlank()) {
                Log.e(TAG, "Empty response from Groq: $responseText")
                return@withContext "Hmm, I didn't catch that. Try asking again!"
            }

            Log.d(TAG, "Groq response: $content")
            content

        } catch (e: Exception) {
            Log.e(TAG, "Groq exception: ${e.message}", e)
            "Couldn't connect. Check your internet and try again!"
        }
    }
}