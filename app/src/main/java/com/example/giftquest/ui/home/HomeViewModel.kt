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
import com.example.giftquest.data.model.GameResult
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

private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

class HomeViewModel(app: Application) : AndroidViewModel(app) {

    private val itemsRepo      = ItemsRepository()
    private val pairingRepo    = PairingRepository()
    private val userRepo       = UserDocRepository()
    private val gameResultsRepo = GameResultsRepository()
    private val fs             = FirebaseFirestore.getInstance()
    private val auth           = FirebaseAuth.getInstance()
    private val uid: String get() = auth.currentUser?.uid ?: "anon"

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message

    // ── Tutorial ───────────────────────────────────────────────────────────────

    val showTutorial = MutableStateFlow(
        !getApplication<Application>()
            .getSharedPreferences("gq_prefs", Context.MODE_PRIVATE)
            .getBoolean("tutorial_shown", false)
    )

    fun markTutorialDone() {
        getApplication<Application>()
            .getSharedPreferences("gq_prefs", Context.MODE_PRIVATE)
            .edit().putBoolean("tutorial_shown", true).apply()
        showTutorial.value = false
    }

    // ── User & partner ─────────────────────────────────────────────────────────

    val userProfile: StateFlow<UserDoc?> = userRepo.meFlow()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val partnerUid: StateFlow<String?> = userProfile
        .map { it?.linkedWith }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val isLinked: StateFlow<Boolean> = userProfile
        .map { it?.linkedWith != null }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    // ── My items — loads immediately (user is always on this tab first) ────────

    val myItems: StateFlow<List<Item>> = itemsRepo.itemsFlow(uid)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    // ── Partner items — only loads when partner tab is opened ──────────────────

    private val _partnerTabVisible = MutableStateFlow(false)

    fun onPartnerTabOpened() { _partnerTabVisible.value = true }
    fun onPartnerTabClosed() { _partnerTabVisible.value = false }

    // Warm cache: fetch silently as soon as linked
    private val _partnerItemsCache = MutableStateFlow<List<Item>>(emptyList())

    val partnerItems: StateFlow<List<Item>> = _partnerTabVisible
        .flatMapLatest { visible ->
            if (visible) _partnerItemsCache
            else flowOf(emptyList())
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    init {
        // Warm the partner items cache silently in background
        viewModelScope.launch {
            partnerUid.collectLatest { pUid ->
                if (pUid != null) {
                    itemsRepo.itemsFlow(pUid).collect { items ->
                        _partnerItemsCache.value = items
                    }
                } else {
                    _partnerItemsCache.value = emptyList()
                }
            }
        }

        viewModelScope.launch {
            try {
                val token = FirebaseMessaging.getInstance().token.await()
                NotificationService.saveFcmToken(token)
            } catch (e: Exception) {
                Log.w(TAG, "Could not get FCM token: ${e.message}")
            }
        }
    }

    // ── Game results — loaded on demand per item, not upfront ─────────────────

    // Cache so we don't re-fetch the same item twice
    private val _gameResults = MutableStateFlow<Map<String, GameResult?>>(emptyMap())
    val gameResults: StateFlow<Map<String, GameResult?>> = _gameResults

    fun loadGameResultForItem(itemId: String) {
        val currentUid = uid
        val pUid = partnerUid.value ?: return
        if (_gameResults.value.containsKey(itemId)) return // already loaded

        viewModelScope.launch {
            try {
                gameResultsRepo.gameResultsFlow(currentUid, pUid)
                    .map { list -> list.find { it.itemId == itemId } }
                    .collect { result ->
                        _gameResults.value = _gameResults.value + (itemId to result)
                    }
            } catch (e: Exception) {
                Log.w(TAG, "loadGameResultForItem failed: ${e.message}")
            }
        }
    }

    // ── Init ───────────────────────────────────────────────────────────────────

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
        title: String, category: String = "", price: Double = 0.0,
        link: String = "", note: String = ""
    ) {
        if (title.isBlank()) { _message.value = "Title cannot be empty"; return }
        val currentUid = uid
        applicationScope.launch {
            try {
                itemsRepo.addItem(
                    title = title, category = category, price = price,
                    link = link, note = note, userId = currentUid
                )
                val myDoc = fs.collection("users").document(currentUid).get().await()
                val partner = myDoc.getString("linkedWith")
                if (!partner.isNullOrBlank()) {
                    NotificationService.sendNotificationToUser(
                        targetUid = partner,
                        title = "New gift on the wishlist 🎁",
                        message = "Your partner just added a new gift — go take a guess!"
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "addItem failed: ${e.message}", e)
            }
        }
    }

    fun updateItem(
        remoteId: String, title: String, category: String = "",
        price: Double = 0.0, link: String = "", note: String = ""
    ) {
        val currentUid = uid
        applicationScope.launch {
            try {
                itemsRepo.updateItem(
                    remoteId = remoteId, userId = currentUid,
                    title = title, category = category,
                    price = price, link = link, note = note
                )
                val myDoc = fs.collection("users").document(currentUid).get().await()
                val partner = myDoc.getString("linkedWith")
                if (partner.isNullOrBlank()) return@launch

                val existingResult = gameResultsRepo.getResultForItem(
                    guesserUid = partner, itemId = remoteId
                )
                if (existingResult != null) {
                    gameResultsRepo.deleteResultForItem(
                        guesserUid = partner, itemId = remoteId
                    )
                    NotificationService.sendNotificationToUser(
                        targetUid = partner,
                        title = "Gift updated 🎁",
                        message = "Your partner edited a gift you already guessed. Try again!"
                    )
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