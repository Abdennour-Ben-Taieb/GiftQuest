package com.example.giftquest.data

import android.util.Log
import com.example.giftquest.data.model.GameMessage
import com.example.giftquest.data.model.GameResult
import com.example.giftquest.data.model.Item
import com.example.giftquest.data.model.ItemSnapshot
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await

private const val TAG = "GiftQuest"

class GameResultsRepository(
    private val fs: FirebaseFirestore = FirebaseFirestore.getInstance()
) {

    /**
     * Save a completed game result under the guesser's collection.
     * Includes full conversation and a snapshot of the gift at time of play.
     */
    suspend fun saveGameResult(
        guesserUid: String,
        partnerUid: String,
        itemId: String,
        item: Item,
        won: Boolean,
        guessCount: Int,
        difficulty: String,
        messages: List<GameMessage>
    ) {
        val messagesData = messages.map { mapOf("role" to it.role, "text" to it.text) }

        val data = mapOf(
            "itemId" to itemId,
            "itemOwnerId" to partnerUid,
            "partnerUid" to partnerUid,
            "won" to won,
            "guessCount" to guessCount,
            "difficulty" to difficulty,
            "playedAtMillis" to System.currentTimeMillis(),
            "itemSnapshot" to mapOf(
                "title" to item.title,
                "category" to item.category,
                "price" to item.price,
                "link" to item.link
            ),
            "messages" to messagesData
        )

        fs.collection("users")
            .document(guesserUid)
            .collection("gameResults")
            .add(data)
            .await()

        Log.d(TAG, "Game result saved for itemId=$itemId under guesser=$guesserUid")
    }

    // Add this method to your existing GameResultsRepository.kt
// inside the GameResultsRepository class

    /**
     * Delete a specific game result by itemId for a guesser.
     * Called when the item owner edits a guessed item.
     */
    suspend fun deleteResultForItem(guesserUid: String, itemId: String) {
        try {
            val snapshot = fs.collection("users")
                .document(guesserUid)
                .collection("gameResults")
                .whereEqualTo("itemId", itemId)
                .get()
                .await()

            val batch = fs.batch()
            snapshot.documents.forEach { doc -> batch.delete(doc.reference) }
            batch.commit().await()

            Log.d(TAG, "Deleted game result for guesser=$guesserUid, item=$itemId")
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting result for item $itemId: ${e.message}")
        }
    }

    /**
     * Real-time flow of all game results for a user, filtered by partnerUid.
     * Used to know which items have been guessed.
     */
    fun gameResultsFlow(guesserUid: String, partnerUid: String): Flow<List<GameResult>> =
        callbackFlow {
            val listener = fs.collection("users")
                .document(guesserUid)
                .collection("gameResults")
                .whereEqualTo("partnerUid", partnerUid)
                .addSnapshotListener { snapshots, error ->
                    if (error != null) {
                        close(error)
                        return@addSnapshotListener
                    }

                    val results = snapshots?.documents?.mapNotNull { doc ->
                        try {
                            val snapshotMap = doc.get("itemSnapshot") as? Map<*, *>
                            val messagesData = doc.get("messages") as? List<*>

                            val itemSnapshot = ItemSnapshot(
                                title = snapshotMap?.get("title") as? String ?: "",
                                category = snapshotMap?.get("category") as? String ?: "",
                                price = (snapshotMap?.get("price") as? Double) ?: 0.0,
                                link = snapshotMap?.get("link") as? String ?: ""
                            )

                            val messages = messagesData?.mapNotNull { msgMap ->
                                val map = msgMap as? Map<*, *> ?: return@mapNotNull null
                                GameMessage(
                                    role = map["role"] as? String ?: "",
                                    text = map["text"] as? String ?: ""
                                )
                            } ?: emptyList()

                            GameResult(
                                remoteId = doc.id,
                                itemId = doc.getString("itemId") ?: "",
                                itemOwnerId = doc.getString("itemOwnerId") ?: "",
                                partnerUid = doc.getString("partnerUid") ?: "",
                                won = doc.getBoolean("won") ?: false,
                                guessCount = (doc.getLong("guessCount") ?: 0L).toInt(),
                                difficulty = doc.getString("difficulty") ?: "",
                                playedAtMillis = doc.getLong("playedAtMillis") ?: 0L,
                                itemSnapshot = itemSnapshot,
                                messages = messages
                            )
                        } catch (e: Exception) {
                            Log.e(TAG, "Error parsing game result: ${e.message}")
                            null
                        }
                    } ?: emptyList()

                    trySend(results)
                }

            awaitClose { listener.remove() }
        }

    /**
     * Get a single game result by itemId.
     * Returns null if item hasn't been guessed yet.
     */
    suspend fun getResultForItem(guesserUid: String, itemId: String): GameResult? {
        return try {
            val snapshot = fs.collection("users")
                .document(guesserUid)
                .collection("gameResults")
                .whereEqualTo("itemId", itemId)
                .limit(1)
                .get()
                .await()

            val doc = snapshot.documents.firstOrNull() ?: return null

            val snapshotMap = doc.get("itemSnapshot") as? Map<*, *>
            val messagesData = doc.get("messages") as? List<*>

            val itemSnapshot = ItemSnapshot(
                title = snapshotMap?.get("title") as? String ?: "",
                category = snapshotMap?.get("category") as? String ?: "",
                price = (snapshotMap?.get("price") as? Double) ?: 0.0,
                link = snapshotMap?.get("link") as? String ?: ""
            )

            val messages = messagesData?.mapNotNull { msgMap ->
                val map = msgMap as? Map<*, *> ?: return@mapNotNull null
                GameMessage(
                    role = map["role"] as? String ?: "",
                    text = map["text"] as? String ?: ""
                )
            } ?: emptyList()

            GameResult(
                remoteId = doc.id,
                itemId = doc.getString("itemId") ?: "",
                itemOwnerId = doc.getString("itemOwnerId") ?: "",
                partnerUid = doc.getString("partnerUid") ?: "",
                won = doc.getBoolean("won") ?: false,
                guessCount = (doc.getLong("guessCount") ?: 0L).toInt(),
                difficulty = doc.getString("difficulty") ?: "",
                playedAtMillis = doc.getLong("playedAtMillis") ?: 0L,
                itemSnapshot = itemSnapshot,
                messages = messages
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching result for item $itemId: ${e.message}")
            null
        }
    }

    /**
     * Delete ALL game results for a guesser with a specific partner.
     * Called when the user unlinks from their partner.
     */
    suspend fun deleteResultsForPartner(guesserUid: String, partnerUid: String) {
        try {
            val snapshot = fs.collection("users")
                .document(guesserUid)
                .collection("gameResults")
                .whereEqualTo("partnerUid", partnerUid)
                .get()
                .await()

            if (snapshot.documents.isEmpty()) return

            val batch = fs.batch()
            snapshot.documents.forEach { doc ->
                batch.delete(doc.reference)
            }
            batch.commit().await()

            Log.d(TAG, "Deleted ${snapshot.documents.size} game results for partner=$partnerUid")
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting game results: ${e.message}")
        }
    }
}