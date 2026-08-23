package com.example.giftquest.data.user

import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await

data class UserProfile(
    val uid: String = "",
    val name: String = "",
    val nickname: String = "",
    val email: String = "",
    val photoUrl: String? = null, // we won't upload yet; null is fine
    val dateOfBirth: String = ""  // store as "YYYY-MM-DD" for now
)

class UserRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance()
) {
    suspend fun saveUser(profile: UserProfile) {
        db.collection("users").document(profile.uid).set(profile).await()
    }
}
