package com.example.giftquest.ui.profile

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.giftquest.BuildConfig.CLOUDINARY_CLOUD
import com.example.giftquest.BuildConfig.CLOUDINARY_PRESET
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

private const val TAG = "GiftQuest"

data class ProfileUiState(
    val loading: Boolean = true,
    val error: String? = null,
    val nickname: String = "",
    val photoUrl: String = "",
    val uid: String = ""
)

class ProfileViewModel(
    private val auth: FirebaseAuth = FirebaseAuth.getInstance(),
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance()
) : ViewModel() {

    private val _state = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = _state.asStateFlow()

    init { loadProfile() }

    private fun loadProfile() {
        val uid = auth.currentUser?.uid ?: run {
            _state.value = ProfileUiState(loading = false, error = "Not signed in")
            return
        }
        _state.value = ProfileUiState(loading = true, uid = uid)
        viewModelScope.launch {
            try {
                val doc = db.collection("users").document(uid).get().await()
                _state.value = ProfileUiState(
                    loading = false,
                    nickname = doc.getString("nickname") ?: "",
                    photoUrl = doc.getString("photoUrl") ?: "",
                    uid = uid
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load profile", e)
                _state.value = ProfileUiState(loading = false, error = "Failed to load profile", uid = uid)
            }
        }
    }

    fun updateNickname(value: String) {
        _state.value = _state.value.copy(nickname = value)
    }

    fun clearError() {
        _state.value = _state.value.copy(error = null)
    }

    // ── Photo Upload (Cloudinary) ──────────────────────────────────────────────

    suspend fun uploadPhotoAndSave(context: Context, uri: Uri): Boolean {
        val uid = auth.currentUser?.uid ?: return false
        _state.value = _state.value.copy(loading = true, error = null)
        return try {
            val url = uploadToCloudinary(context, uri)
            if (url == null) {
                _state.value = _state.value.copy(loading = false, error = "Photo upload failed")
                return false
            }
            db.collection("users").document(uid)
                .set(mapOf("photoUrl" to url), SetOptions.merge()).await()
            _state.value = _state.value.copy(loading = false, photoUrl = url)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Photo upload failed", e)
            _state.value = _state.value.copy(loading = false, error = "Photo upload failed: ${e.message}")
            false
        }
    }

    private suspend fun uploadToCloudinary(context: Context, uri: Uri): String? =
        withContext(Dispatchers.IO) {
            try {
                val bytes = context.contentResolver.openInputStream(uri)?.readBytes() ?: return@withContext null
                val boundary = "boundary_${System.currentTimeMillis()}"
                val conn = (URL("https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD/image/upload")
                    .openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                    doOutput = true; connectTimeout = 30_000; readTimeout = 30_000
                }
                conn.outputStream.use { out ->
                    out.write("--$boundary\r\nContent-Disposition: form-data; name=\"upload_preset\"\r\n\r\n$CLOUDINARY_PRESET\r\n".toByteArray())
                    out.write("--$boundary\r\nContent-Disposition: form-data; name=\"file\"; filename=\"pfp.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".toByteArray())
                    out.write(bytes)
                    out.write("\r\n--$boundary--\r\n".toByteArray())
                }
                if (conn.responseCode != 200) return@withContext null
                JSONObject(conn.inputStream.bufferedReader().readText()).getString("secure_url")
            } catch (e: Exception) {
                Log.e(TAG, "Cloudinary upload failed: ${e.message}")
                null
            }
        }

    // ── Save Nickname ──────────────────────────────────────────────────────────

    fun saveProfile(onDone: () -> Unit) {
        val uid = auth.currentUser?.uid ?: return
        _state.value = _state.value.copy(loading = true, error = null)
        viewModelScope.launch {
            try {
                db.collection("users").document(uid)
                    .set(mapOf("nickname" to _state.value.nickname.trim()), SetOptions.merge())
                    .await()
                _state.value = _state.value.copy(loading = false)
                onDone()
            } catch (e: Exception) {
                _state.value = _state.value.copy(loading = false, error = "Save failed: ${e.message}")
            }
        }
    }

    // ── Delete Account ─────────────────────────────────────────────────────────

    fun deleteAccount(onDeleted: () -> Unit) {
        val user = auth.currentUser ?: return
        val uid = user.uid
        _state.value = _state.value.copy(loading = true, error = null)
        viewModelScope.launch {
            try {
                // Delete Firestore user doc and subcollections (items, gameResults)
                // Firestore doesn't auto-delete subcollections, but cleaning the root doc
                // is enough for now — subcollections can be cleaned by a Cloud Function later
                db.collection("users").document(uid).delete().await()

                // Delete Firebase Auth account
                user.delete().await()

                onDeleted()
            } catch (e: Exception) {
                Log.e(TAG, "Delete account failed", e)
                _state.value = _state.value.copy(
                    loading = false,
                    error = "Delete failed. You may need to re-login first."
                )
            }
        }
    }
}