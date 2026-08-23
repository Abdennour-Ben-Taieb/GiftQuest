package com.example.giftquest.ui.login

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.giftquest.data.auth.AuthRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

data class LoginUiState(
    val loading: Boolean = false,
    val error: String? = null
)

class LoginViewModel(
    private val repo: AuthRepository = AuthRepository()
) : ViewModel() {

    private val _state = MutableStateFlow(LoginUiState())
    val state: StateFlow<LoginUiState> = _state

    fun signIn(email: String, password: String, onSuccess: () -> Unit) {
        _state.value = LoginUiState(loading = true)
        viewModelScope.launch {
            try {
                repo.signIn(email, password)
                _state.value = LoginUiState()
                onSuccess()
            } catch (e: Exception) {
                _state.value = LoginUiState(loading = false, error = e.message)
            }
        }
    }

    fun signUp(email: String, password: String, onSuccess: () -> Unit) {
        _state.value = LoginUiState(loading = true)
        viewModelScope.launch {
            try {
                repo.signUp(email, password)
                _state.value = LoginUiState()
                onSuccess()
            } catch (e: Exception) {
                _state.value = LoginUiState(loading = false, error = e.message)
            }
        }
    }

    fun reset(email: String) {
        viewModelScope.launch {
            try { repo.sendPasswordReset(email) } catch (_: Exception) {}
        }
    }
}
