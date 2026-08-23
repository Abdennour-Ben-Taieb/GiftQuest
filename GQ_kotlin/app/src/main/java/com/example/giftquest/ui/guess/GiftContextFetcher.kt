package com.example.giftquest.ui.guess

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

private const val TAG = "GiftQuest"

/**
 * Fetches a gift's product page URL and extracts useful context
 * (title, description) to enrich the AI's understanding of the gift.
 * Silently fails if the URL is unreachable — game works fine without it.
 */
object GiftContextFetcher {

    suspend fun fetch(link: String): String {
        if (link.isBlank()) return ""

        return withContext(Dispatchers.IO) {
            try {
                val url = URL(link)
                val connection = url.openConnection() as HttpURLConnection
                connection.connectTimeout = 8000
                connection.readTimeout = 8000
                connection.setRequestProperty("User-Agent", "Mozilla/5.0")
                connection.instanceFollowRedirects = true

                if (connection.responseCode != 200) {
                    Log.w(TAG, "Gift URL returned ${connection.responseCode}")
                    return@withContext ""
                }

                // Only read first 50KB — enough for meta tags, avoids huge pages
                val html = connection.inputStream.bufferedReader()
                    .readText()
                    .take(50_000)

                val pageTitle = extractMeta(html, "og:title")
                    .ifBlank { extractTag(html, "title") }

                val pageDesc = extractMeta(html, "og:description")
                    .ifBlank { extractMetaName(html, "description") }

                if (pageTitle.isBlank() && pageDesc.isBlank()) {
                    Log.d(TAG, "No useful content extracted from gift URL")
                    return@withContext ""
                }

                Log.d(TAG, "Gift context fetched — title: $pageTitle")

                buildString {
                    append("\nADDITIONAL GIFT CONTEXT FROM PRODUCT PAGE:\n")
                    if (pageTitle.isNotBlank()) append("- Product: $pageTitle\n")
                    if (pageDesc.isNotBlank()) append("- Description: ${pageDesc.take(200)}\n")
                }

            } catch (e: Exception) {
                Log.w(TAG, "Could not fetch gift URL: ${e.message}")
                "" // silent fail
            }
        }
    }

    private fun extractMeta(html: String, property: String): String =
        Regex("""meta[^>]+property="og:$property"[^>]+content="([^"]+)"""", RegexOption.IGNORE_CASE)
            .find(html)?.groupValues?.get(1)?.trim()
            ?: Regex("""meta[^>]+content="([^"]+)"[^>]+property="og:$property"""", RegexOption.IGNORE_CASE)
                .find(html)?.groupValues?.get(1)?.trim() ?: ""

    private fun extractMetaName(html: String, name: String): String =
        Regex("""meta[^>]+name="$name"[^>]+content="([^"]+)"""", RegexOption.IGNORE_CASE)
            .find(html)?.groupValues?.get(1)?.trim()
            ?: Regex("""meta[^>]+content="([^"]+)"[^>]+name="$name"""", RegexOption.IGNORE_CASE)
                .find(html)?.groupValues?.get(1)?.trim() ?: ""

    private fun extractTag(html: String, tag: String): String =
        Regex("<$tag[^>]*>(.*?)</$tag>", RegexOption.IGNORE_CASE)
            .find(html)?.groupValues?.get(1)?.trim() ?: ""
}