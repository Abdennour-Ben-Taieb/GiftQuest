package com.example.giftquest.ui.home

import android.app.Application
import android.util.Log
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.giftquest.data.GameResultsRepository
import com.example.giftquest.data.ItemsRepository
import com.example.giftquest.data.NotificationService
import com.example.giftquest.data.model.Item
import com.example.giftquest.data.remote.PairingRepository
import com.example.giftquest.data.user.UserDoc
import com.example.giftquest.data.user.UserDocRepository
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.tasks.await

private const val TAG = "GiftQuest"

// Application-level scope — never cancelled by navigation or ViewModel destruction
private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

class HomeViewModel(app: Application) : AndroidViewModel(app) {

    private val itemsRepo = ItemsRepository()
    private val pairingRepo = PairingRepository()
    private val userRepo = UserDocRepository()
    private val gameResultsRepo = GameResultsRepository()
    private val fs = FirebaseFirestore.getInstance()

    private val auth = FirebaseAuth.getInstance()
    private val uid: String get() = auth.currentUser?.uid ?: "anon"

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message

    private fun prefs(app: Application) =
        app.getSharedPreferences("gq_prefs", Context.MODE_PRIVATE)

    val showTutorial = MutableStateFlow(
        !getApplication<Application>()
            .getSharedPreferences("gq_prefs", Context.MODE_PRIVATE)
            .getBoolean("tutorial_shown", false)
    )

    fun markTutorialDone() {
        getApplication<Application>()
            .getSharedPreferences("gq_prefs", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("tutorial_shown", true)
            .apply()
        showTutorial.value = false
    }

    val userProfile: StateFlow<UserDoc?> = userRepo.meFlow()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val myItems: StateFlow<List<Item>> = itemsRepo.itemsFlow(uid)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val partnerUid: StateFlow<String?> = userProfile
        .map { it?.linkedWith }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val partnerItems: StateFlow<List<Item>> = userRepo.meFlow()
        .flatMapLatest { me ->
            val partnerUid = me?.linkedWith
            if (partnerUid == null) flowOf(emptyList())
            else itemsRepo.itemsFlow(partnerUid)
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val isLinked: StateFlow<Boolean> = userProfile
        .map { it?.linkedWith != null }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    init {
        viewModelScope.launch {
            try {
                val token = FirebaseMessaging.getInstance().token.await()
                NotificationService.saveFcmToken(token)
            } catch (e: Exception) {
                Log.w(TAG, "Could not get FCM token: ${e.message}")
            }
        }
    }

    // ── Item operations ────────────────────────────────────────────────────────

    fun addItem(
        title: String,
        category: String = "",
        price: Double = 0.0,
        link: String = "",
        note: String = ""
    ) {
        if (title.isBlank()) { _message.value = "Title cannot be empty"; return }
        val currentUid = uid
        applicationScope.launch {
            try {
                itemsRepo.addItem(
                    title = title, category = category, price = price,
                    link = link, note = note, userId = currentUid
                )

                // Notify partner that a new gift was added to the wishlist
                val myDoc = fs.collection("users").document(currentUid).get().await()
                val partner = myDoc.getString("linkedWith")
                if (!partner.isNullOrBlank()) {
                    NotificationService.sendNotificationToUser(
                        targetUid = partner,
                        title = "New gift on the wishlist 🎁",
                        message = "Your partner just added a new gift — go take a guess!"
                    )
                    Log.d(TAG, "Partner notified of new item")
                }
            } catch (e: Exception) {
                Log.e(TAG, "addItem failed: ${e.message}", e)
            }
        }
    }

    fun updateItem(
        remoteId: String,
        title: String,
        category: String = "",
        price: Double = 0.0,
        link: String = "",
        note: String = ""
    ) {
        val currentUid = uid
        applicationScope.launch {
            try {
                Log.d(TAG, "=== updateItem called === remoteId=$remoteId uid=$currentUid")

                itemsRepo.updateItem(
                    remoteId = remoteId, userId = currentUid,
                    title = title, category = category,
                    price = price, link = link, note = note
                )
                Log.d(TAG, "Item updated: $remoteId")

                val myDoc = fs.collection("users").document(currentUid).get().await()
                val partner = myDoc.getString("linkedWith")
                Log.d(TAG, "Partner UID from Firestore: $partner")

                if (partner.isNullOrBlank()) {
                    Log.d(TAG, "Not linked — skipping notification check")
                    return@launch
                }

                val existingResult = gameResultsRepo.getResultForItem(
                    guesserUid = partner,
                    itemId = remoteId
                )
                Log.d(TAG, "Existing game result for item $remoteId: ${existingResult != null}")

                if (existingResult != null) {
                    gameResultsRepo.deleteResultForItem(
                        guesserUid = partner,
                        itemId = remoteId
                    )
                    Log.d(TAG, "Game result deleted for partner=$partner, item=$remoteId")

                    NotificationService.sendNotificationToUser(
                        targetUid = partner,
                        title = "Gift updated 🎁",
                        message = "Your partner edited a gift you already guessed. Try to guess it again!"
                    )
                    Log.d(TAG, "Notification sent to partner=$partner")
                }

            } catch (e: Exception) {
                Log.e(TAG, "updateItem failed: ${e.message}", e)
            }
        }
    }

    fun deleteItem(itemId: String) {
        viewModelScope.launch {
            try {
                itemsRepo.deleteItem(itemId, uid)
                _message.value = "Item deleted!"
            } catch (e: Exception) { _message.value = "Failed: ${e.message}" }
        }
    }

    fun reorder(itemIdsInOrder: List<String>) {
        viewModelScope.launch {
            try {
                itemsRepo.reorder(itemIdsInOrder, uid)
            } catch (e: Exception) { _message.value = "Reorder failed: ${e.message}" }
        }
    }

    // ── Partner operations ─────────────────────────────────────────────────────

    fun linkWithPartner(partnerCode: String) {
        if (partnerCode.isBlank()) { _message.value = "Please enter a code"; return }
        viewModelScope.launch {
            try {
                pairingRepo.linkWithPartnerCode(uid, partnerCode.trim())
                _message.value = "Linked with partner!"
            } catch (e: Exception) { _message.value = "Failed: ${e.message}" }
        }
    }

    fun unlinkPartner() {
        viewModelScope.launch {
            try {
                pairingRepo.unlinkMe(uid)
                _message.value = "Unlinked from partner"
            } catch (e: Exception) { _message.value = "Failed: ${e.message}" }
        }
    }

    fun consumeMessage() { _message.value = null }

    suspend fun getUserProfile(): Map<String, Any>? {
        return userProfile.value?.let { user ->
            mapOf("nickname" to user.nickname, "photoUrl" to (user.photoUrl ?: ""))
        }
    }

    fun updateProfile(nickname: String?, photoUrl: String?) {}

    companion object {
        fun factory(app: Application) = object : androidx.lifecycle.ViewModelProvider.Factory {
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
                @Suppress("UNCHECKED_CAST")
                return HomeViewModel(app) as T
            }
        }
    }
}