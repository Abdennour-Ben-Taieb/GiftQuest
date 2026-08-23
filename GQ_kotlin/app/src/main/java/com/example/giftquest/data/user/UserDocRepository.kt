package com.example.giftquest.data.user

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await

class UserDocRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance(),
    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
) {
    fun meFlow(): Flow<UserDoc?> = callbackFlow {
        val uid = auth.currentUser?.uid
        if (uid == null) {
            trySend(null)
            close()
            return@callbackFlow
        }


        val reg = db.collection("users").document(uid)
            .addSnapshotListener { snap, _ ->
                val doc = snap?.toObject(UserDoc::class.java)?.copy(uid = uid)
                trySend(doc)
            }
        awaitClose { reg.remove() }
    }

    suspend fun getMeOnce(): UserDoc? {
        val uid = auth.currentUser?.uid ?: return null
        val snap = db.collection("users").document(uid).get().await()
        return snap.toObject(UserDoc::class.java)?.copy(uid = uid)
    }
}
