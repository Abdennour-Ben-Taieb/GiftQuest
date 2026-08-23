package com.example.giftquest.ui.partner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.giftquest.data.remote.PairingRepository
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class PartnerLinkUiState(
    val loading: Boolean = false,
    val error: String? = null,
    val myShareCode: String = "",
    val partnerUid: String? = null,
    val linked: Boolean = false
)

class PartnerLinkViewModel(
    private val repo: PairingRepository = PairingRepository(),
    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
) : ViewModel() {

    private val _state = MutableStateFlow(PartnerLinkUiState())
    val state: StateFlow<PartnerLinkUiState> = _state.asStateFlow()

    init {
        loadShareCode()
    }

    fun loadShareCode() {
        val uid = auth.currentUser?.uid
        if (uid.isNullOrBlank()) {
            _state.value = _state.value.copy(error = "Please sign in first")
            return
        }

        _state.value = _state.value.copy(loading = true, error = null)

        viewModelScope.launch {
            try {
                val code = repo.ensureMyShareCode(uid)
                _state.value = _state.value.copy(loading = false, myShareCode = code)
            } catch (e: Exception) {
                _state.value = _state.value.copy(
                    loading = false,
                    error = "Failed to load share code: ${e.message}"
                )
            }
        }
    }

    fun linkWith(partnerCode: String) {
        val uid = auth.currentUser?.uid
        if (uid.isNullOrBlank()) {
            _state.value = _state.value.copy(error = "Please sign in first")
            return
        }

        if (partnerCode.isBlank()) {
            _state.value = _state.value.copy(error = "Please enter a code")
            return
        }

        _state.value = _state.value.copy(loading = true, error = null)

        viewModelScope.launch {
            try {
                val partnerUid = repo.linkWithPartnerCode(uid, partnerCode.trim())
                _state.value = _state.value.copy(
                    loading = false,
                    partnerUid = partnerUid,
                    linked = true,
                    error = null
                )
            } catch (e: Exception) {
                _state.value = _state.value.copy(
                    loading = false,
                    error = e.message ?: "Link failed"
                )
            }
        }
    }

    fun unlink() {
        val uid = auth.currentUser?.uid
        if (uid.isNullOrBlank()) {
            _state.value = _state.value.copy(error = "Please sign in first")
            return
        }

        _state.value = _state.value.copy(loading = true, error = null)

        viewModelScope.launch {
            try {
                repo.unlinkMe(uid)
                _state.value = _state.value.copy(
                    loading = false,
                    partnerUid = null,
                    linked = false,
                    error = null
                )
            } catch (e: Exception) {
                _state.value = _state.value.copy(
                    loading = false,
                    error = "Unlink failed: ${e.message}"
                )
            }
        }
    }

    fun clearError() {
        _state.value = _state.value.copy(error = null)
    }
}