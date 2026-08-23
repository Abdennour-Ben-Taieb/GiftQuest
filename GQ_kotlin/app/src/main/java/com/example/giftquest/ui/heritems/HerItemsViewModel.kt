package com.example.giftquest.ui.heritems

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.giftquest.data.ItemsRepository
import com.example.giftquest.data.model.Item
import com.example.giftquest.data.remote.PairingRepository
import com.example.giftquest.data.user.UserDocRepository
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class HerItemsUiState(
    val loading: Boolean = false,
    val error: String? = null,
    val myShareCode: String = "",
    val partnerUid: String? = null,
    val partnerItems: List<Item> = emptyList(),
    val isLinked: Boolean = false
)

class HerItemsViewModel(
    private val auth: FirebaseAuth = FirebaseAuth.getInstance(),
    private val pairingRepo: PairingRepository = PairingRepository(),
    private val itemsRepo: ItemsRepository = ItemsRepository(),
    private val userRepo: UserDocRepository = UserDocRepository()
) : ViewModel() {

    private val uid: String = auth.currentUser?.uid ?: "anon"

    private val _state = MutableStateFlow(HerItemsUiState(loading = true))
    val state: StateFlow<HerItemsUiState> = _state.asStateFlow()

    init {
        if (uid != "anon") {
            loadShareCode()

            viewModelScope.launch {
                userRepo.meFlow().collect { userDoc ->
                    val partnerUid = userDoc?.linkedWith

                    _state.update { it.copy(
                        partnerUid = partnerUid,
                        isLinked = partnerUid != null,
                        loading = false
                    )}

                    if (partnerUid != null) {
                        observePartnerItems(partnerUid)
                    } else {
                        _state.update { it.copy(partnerItems = emptyList()) }
                    }
                }
            }
        }
    }

    private fun loadShareCode() {
        viewModelScope.launch {
            try {
                val code = pairingRepo.ensureMyShareCode(uid)
                _state.update { it.copy(myShareCode = code) }
            } catch (e: Exception) {
                _state.update { it.copy(error = "Failed to load share code") }
            }
        }
    }

    private fun observePartnerItems(partnerUid: String) {
        viewModelScope.launch {
            itemsRepo.itemsFlow(partnerUid).collect { items ->
                _state.update { it.copy(partnerItems = items) }
            }
        }
    }

    fun linkWith(partnerCode: String) {
        if (uid == "anon") {
            _state.update { it.copy(error = "Please sign in first") }
            return
        }

        viewModelScope.launch {
            try {
                _state.update { it.copy(loading = true, error = null) }
                val partnerUid = pairingRepo.linkWithPartnerCode(uid, partnerCode.trim())
                _state.update { it.copy(
                    loading = false,
                    partnerUid = partnerUid,
                    isLinked = true
                )}
            } catch (e: Exception) {
                _state.update { it.copy(
                    loading = false,
                    error = e.message ?: "Link failed"
                )}
            }
        }
    }

    fun unlink() {
        if (uid == "anon") {
            _state.update { it.copy(error = "Please sign in first") }
            return
        }

        viewModelScope.launch {
            try {
                _state.update { it.copy(loading = true, error = null) }
                pairingRepo.unlinkMe(uid)
                _state.update { it.copy(
                    loading = false,
                    partnerUid = null,
                    isLinked = false,
                    partnerItems = emptyList()
                )}
            } catch (e: Exception) {
                _state.update { it.copy(
                    loading = false,
                    error = "Unlink failed: ${e.message}"
                )}
            }
        }
    }

    fun clearError() {
        _state.update { it.copy(error = null) }
    }
}