package com.example.giftquest.ui.signup

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.giftquest.data.auth.AuthRepository
import com.example.giftquest.data.user.UserProfile
import com.example.giftquest.data.user.UserRepository
import com.facebook.AccessToken
import com.facebook.CallbackManager
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import com.facebook.login.LoginManager
import com.facebook.login.LoginResult
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.auth.FacebookAuthProvider
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import com.example.giftquest.BuildConfig
import java.net.URL

private const val TAG = "GiftQuest"
private val WEB_CLIENT_ID get() = BuildConfig.WEB_CLIENT_ID
private val CLOUDINARY_CLOUD get() = BuildConfig.CLOUDINARY_CLOUD
private val CLOUDINARY_PRESET get() = BuildConfig.CLOUDINARY_PRESET

data class SignUpUiState(
    val loading: Boolean = false,
    val error: String? = null
)

class SignUpViewModel(
    private val auth: AuthRepository = AuthRepository(),
    private val users: UserRepository = UserRepository()
) : ViewModel() {

    private val _state = MutableStateFlow(SignUpUiState())
    val state: StateFlow<SignUpUiState> = _state

    // Must be kept alive in ViewModel so Facebook callbacks survive recomposition
    val facebookCallbackManager: CallbackManager = CallbackManager.Factory.create()

    // ── Email + Password ───────────────────────────────────────────────────────

    fun signUp(
        name: String,
        nickname: String,
        email: String,
        password: String,
        dateOfBirth: String,
        photoUri: Uri?,
        context: Context,
        onSuccess: () -> Unit
    ) {
        _state.value = SignUpUiState(loading = true, error = null)
        viewModelScope.launch {
            try {
                auth.signUp(email, password)
                val uid = auth.uid ?: throw IllegalStateException("Signed up, but no UID")

                // Upload photo and save profile BEFORE navigating
                val photoUrl = photoUri?.let { uploadToCloudinary(context, it) }
                users.saveUser(UserProfile(uid, name, nickname, email, photoUrl, dateOfBirth))

                _state.value = SignUpUiState(loading = false)
                onSuccess() // navigate only after profile is fully saved
            } catch (e: Exception) {
                _state.value = SignUpUiState(loading = false, error = e.message ?: "Sign up failed")
            }
        }
    }

    // ── Google ─────────────────────────────────────────────────────────────────

    fun signInWithGoogle(context: Context, onSuccess: () -> Unit) {
        _state.value = SignUpUiState(loading = true, error = null)
        viewModelScope.launch {
            try {
                val credentialManager = CredentialManager.create(context)
                val request = GetCredentialRequest.Builder()
                    .addCredentialOption(
                        GetGoogleIdOption.Builder()
                            .setFilterByAuthorizedAccounts(false)
                            .setServerClientId(WEB_CLIENT_ID)
                            .build()
                    ).build()

                val result = credentialManager.getCredential(context, request)
                val googleIdToken = GoogleIdTokenCredential.createFrom(result.credential.data).idToken
                val authResult = FirebaseAuth.getInstance()
                    .signInWithCredential(GoogleAuthProvider.getCredential(googleIdToken, null))
                    .await()

                val user = authResult.user ?: throw Exception("No Firebase user")
                _state.value = SignUpUiState(loading = false)
                onSuccess()

                if (authResult.additionalUserInfo?.isNewUser == true) {
                    launch {
                        runCatching {
                            users.saveUser(UserProfile(
                                uid = user.uid,
                                name = user.displayName ?: "",
                                nickname = user.displayName?.split(" ")?.firstOrNull() ?: "",
                                email = user.email ?: "",
                                photoUrl = user.photoUrl?.toString(),
                                dateOfBirth = ""
                            ))
                        }
                    }
                }
            } catch (e: Exception) {
                _state.value = SignUpUiState(
                    loading = false,
                    error = if (e.message?.contains("No credentials") == true)
                        "No Google account found on this device"
                    else "Google sign-in failed: ${e.message}"
                )
            }
        }
    }

    // ── Cloudinary ─────────────────────────────────────────────────────────────

    private suspend fun uploadToCloudinary(context: Context, uri: Uri): String? =
        withContext(Dispatchers.IO) {
            try {
                val bytes = context.contentResolver.openInputStream(uri)?.readBytes() ?: return@withContext null
                val boundary = "boundary_${System.currentTimeMillis()}"
                val url = URL("https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD/image/upload")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                    doOutput = true
                    connectTimeout = 30_000
                    readTimeout = 30_000
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
}