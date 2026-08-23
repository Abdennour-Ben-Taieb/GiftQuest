package com.example.giftquest.data.remote

import android.util.Log
import com.example.giftquest.data.GameResultsRepository
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await

private const val TAG = "GiftQuest"

class PairingRepository(
    private val fs: FirebaseFirestore = FirebaseFirestore.getInstance(),
    private val gameResultsRepo: GameResultsRepository = GameResultsRepository()
) {

    /**
     * Link two users together using a share code.
     */
    suspend fun linkWithPartnerCode(myUid: String, partnerCode: String): String {
        // Look up partner by share code
        val codeDoc = fs.collection("shareCodes")
            .document(partnerCode)
            .get()
            .await()

        val partnerUid = codeDoc.getString("uid")
            ?: throw Exception("Invalid code: $partnerCode")

        if (partnerUid == myUid) throw Exception("You can't link with yourself!")

        val batch = fs.batch()

        // Set linkedWith on both users
        batch.update(fs.collection("users").document(myUid), "linkedWith", partnerUid)
        batch.update(fs.collection("users").document(partnerUid), "linkedWith", myUid)

        batch.commit().await()

        Log.d(TAG, "Linked $myUid with $partnerUid")
        return partnerUid
    }

    /**
     * Unlink current user from their partner.
     * Also deletes all game results both users have with each other.
     */
    suspend fun unlinkMe(myUid: String) {
        val myDoc = fs.collection("users").document(myUid).get().await()
        val partnerUid = myDoc.getString("linkedWith")

        if (partnerUid != null) {
            // Only delete MY game results — partner's are their own data
            gameResultsRepo.deleteResultsForPartner(
                guesserUid = myUid,
                partnerUid = partnerUid
            )
            Log.d(TAG, "Deleted my game results on unlink")
        }

        val batch = fs.batch()
        batch.update(fs.collection("users").document(myUid), "linkedWith", null)
        if (partnerUid != null) {
            batch.update(fs.collection("users").document(partnerUid), "linkedWith", null)
        }
        batch.commit().await()

        Log.d(TAG, "Unlinked $myUid from $partnerUid")
    }

    suspend fun ensureMyShareCode(myUid: String): String {
        // Check if user already has a share code
        val existing = fs.collection("shareCodes")
            .whereEqualTo("uid", myUid)
            .limit(1)
            .get()
            .await()

        if (!existing.isEmpty) {
            return existing.documents.first().id
        }

        // Generate a new share code
        val code = generateCode()
        fs.collection("shareCodes").document(code).set(mapOf("uid" to myUid)).await()
        return code
    }

    private fun generateCode(): String {
        val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return (1..8).map { chars.random() }.joinToString("")
    }
}