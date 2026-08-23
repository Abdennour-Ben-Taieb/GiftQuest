package com.example.giftquest.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.giftquest.ui.components.FacebookSignInButton
import com.example.giftquest.ui.components.GoogleSignInButton
import com.example.giftquest.ui.login.LoginViewModel
import com.example.giftquest.ui.signup.SignUpViewModel
import com.example.giftquest.utils.DevMode
@Composable
fun LoginScreen(
    onLoggedIn: () -> Unit,
    onCreateAccount: () -> Unit,
    onForgotPassword: () -> Unit,
    viewModel: LoginViewModel = viewModel()
) {
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()

    val googleVm: SignUpViewModel = viewModel()
    val googleState by googleVm.state.collectAsState()

    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    // Dev mode auto-login
    LaunchedEffect(Unit) {
        if (DevMode.DEV_MODE_ENABLED) {
            DevMode.getDeviceConfig()?.let { config ->
                viewModel.signIn(config.email, config.password, onSuccess = onLoggedIn)
            }
        }
    }

    val isLoading = state.loading || googleState.loading
    val error = state.error ?: googleState.error

    Scaffold { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(1.dp)
        ) {
            if (isLoading) {
                Spacer(Modifier.height(200.dp))
                CircularProgressIndicator()
                Spacer(Modifier.height(16.dp))
                Text("Signing in...", style = MaterialTheme.typography.bodyMedium)
            } else {
                Text("GiftQuest", style = MaterialTheme.typography.displayMedium)
                Text(
                    "Gift Discovery Made Easy",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(Modifier.height(48.dp))

                // Error banner
                error?.let {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
                    ) {
                        Text(it, modifier = Modifier.padding(16.dp), color = MaterialTheme.colorScheme.onErrorContainer)
                    }
                    Spacer(Modifier.height(16.dp))
                }

                // ── Social buttons ───────────────────────────────────────────
                GoogleSignInButton(
                    onClick = { googleVm.signInWithGoogle(context, onLoggedIn) },
                    modifier = Modifier.fillMaxWidth(),
                    text = "Continue with Google",
                    enabled = !isLoading
                )

                Spacer(Modifier.height(20.dp))

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    HorizontalDivider(modifier = Modifier.weight(1f))
                    Text("  or  ", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    HorizontalDivider(modifier = Modifier.weight(1f))
                }

                Spacer(Modifier.height(20.dp))

                // ── Email / Password ─────────────────────────────────────────
                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("Email") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next)
                )

                Spacer(Modifier.height(8.dp))

                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Password") },
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(
                        onDone = {
                            if (email.isNotBlank() && password.isNotBlank())
                                viewModel.signIn(email.trim(), password, onSuccess = onLoggedIn)
                        }
                    )
                )

                TextButton(onClick = onForgotPassword, modifier = Modifier.align(Alignment.End)) {
                    Text("Forgot Password?")
                }

                Spacer(Modifier.height(8.dp))

                Button(
                    onClick = { viewModel.signIn(email.trim(), password, onSuccess = onLoggedIn) },
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    enabled = email.isNotBlank() && password.isNotBlank()
                ) {
                    Text("Log In", style = MaterialTheme.typography.titleMedium)
                }

                Spacer(Modifier.height(8.dp))

                Row(horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    Text("Don't have an account?")
                    TextButton(onClick = onCreateAccount) { Text("Sign Up") }
                }
            }
        }
    }
}