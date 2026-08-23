package com.example.giftquest.data

import android.util.Log
import com.example.giftquest.data.model.Item
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await

class ItemsRepository(
    private val fs: FirebaseFirestore = FirebaseFirestore.getInstance()
) {

    fun itemsFlow(userId: String): Flow<List<Item>> = callbackFlow {
        val listener = fs.collection("users")
            .document(userId)
            .collection("items")
            .orderBy("position", Query.Direction.ASCENDING)
            .addSnapshotListener { snapshots, error ->
                if (error != null) {
                    Log.w("GiftQuest", "Firestore listener error: ${error.message}")
                    return@addSnapshotListener  // ← silently ignore, don't crash
                }

                val items = snapshots?.documents?.map { doc ->
                    Item(
                        remoteId = doc.id,
                        title = doc.getString("title") ?: "",
                        category = doc.getString("category") ?: "",
                        price = doc.getDouble("price") ?: 0.0,
                        link = doc.getString("link") ?: "",
                        note = doc.getString("note") ?: "",
                        createdAtMillis = doc.getLong("createdAtMillis") ?: System.currentTimeMillis(),
                        updatedAtMillis = doc.getLong("updatedAtMillis") ?: System.currentTimeMillis(),
                        position = doc.getDouble("position") ?: 0.0
                    )
                } ?: emptyList()

                trySend(items)
            }

        awaitClose { listener.remove() }
    }

    suspend fun addItem(
        title: String,
        category: String,
        price: Double,
        link: String,
        note: String,
        userId: String
    ) {
        val col = fs.collection("users")
            .document(userId)
            .collection("items")

        val now = System.currentTimeMillis()

        val nextPos = try {
            val last = col.orderBy("position", Query.Direction.DESCENDING)
                .limit(1).get().await()
            (last.documents.firstOrNull()?.getDouble("position") ?: -1.0) + 1.0
        } catch (e: Exception) { 0.0 }

        val data = mapOf(
            "title" to title,
            "category" to category,
            "price" to price,
            "link" to link,
            "note" to note,
            "position" to nextPos,
            "createdAtMillis" to now,
            "updatedAtMillis" to now
        )

        col.add(data).await()
    }

    suspend fun updateItem(
        remoteId: String,
        userId: String,
        title: String,
        category: String,
        price: Double,
        link: String,
        note: String
    ) {
        val data = mapOf(
            "title" to title,
            "category" to category,
            "price" to price,
            "link" to link,
            "note" to note,
            "updatedAtMillis" to System.currentTimeMillis()
        )

        fs.collection("users")
            .document(userId)
            .collection("items")
            .document(remoteId)
            .update(data)
            .await()
    }

    suspend fun deleteItem(remoteId: String, userId: String) {
        fs.collection("users")
            .document(userId)
            .collection("items")
            .document(remoteId)
            .delete()
            .await()
    }

    suspend fun reorder(remoteIdsInOrder: List<String>, userId: String) {
        val col = fs.collection("users")
            .document(userId)
            .collection("items")

        val batch = fs.batch()

        remoteIdsInOrder.forEachIndexed { index, remoteId ->
            batch.update(
                col.document(remoteId),
                mapOf(
                    "position" to index.toDouble(),
                    "updatedAtMillis" to System.currentTimeMillis()
                )
            )
        }

        batch.commit().await()
    }

    /**
     * Save the result of a guessing game for future points system.
     */
    suspend fun saveGameResult(
        itemId: String,
        itemOwnerId: String,
        guesserUid: String,
        guessCount: Int,
        won: Boolean,
        difficulty: String
    ) {
        val data = mapOf(
            "itemId" to itemId,
            "guesserUid" to guesserUid,
            "guessCount" to guessCount,
            "won" to won,
            "difficulty" to difficulty,
            "playedAtMillis" to System.currentTimeMillis()
        )

        fs.collection("users")
            .document(itemOwnerId)
            .collection("gameResults")
            .add(data)
            .await()
    }
}