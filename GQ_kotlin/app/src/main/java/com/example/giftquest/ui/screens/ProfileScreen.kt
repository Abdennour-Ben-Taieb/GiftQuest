package com.example.giftquest.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.example.giftquest.ui.components.AppTopBar
import com.example.giftquest.ui.profile.ProfileViewModel
import kotlinx.coroutines.launch
import java.io.File

@Composable
fun ProfileScreen(
    onBack: () -> Unit,
    onLoggedOut: () -> Unit,
    onAccountDeleted: () -> Unit,
    viewModel: ProfileViewModel = viewModel()
) {
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()
    val scope = rememberCoroutineScope()

    var showPhotoPickerDialog by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showLogoutDialog by remember { mutableStateOf(false) }
    var tempCameraUri by remember { mutableStateOf<Uri?>(null) }

    // Gallery picker
    val galleryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let {
            scope.launch {
                val success = viewModel.uploadPhotoAndSave(context, it)
                Toast.makeText(
                    context,
                    if (success) "Photo updated!" else "Upload failed",
                    Toast.LENGTH_SHORT
                ).show()
            }
        }
    }

    // Camera launcher
    val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if (success && tempCameraUri != null) {
            scope.launch {
                val uploaded = viewModel.uploadPhotoAndSave(context, tempCameraUri!!)
                Toast.makeText(context, if (uploaded) "Photo updated!" else "Upload failed", Toast.LENGTH_SHORT).show()
            }
        }
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            val uri = createCameraFile(context)
            if (uri != null) { tempCameraUri = uri; cameraLauncher.launch(uri) }
        } else {
            Toast.makeText(context, "Camera permission denied", Toast.LENGTH_SHORT).show()
        }
    }

    // ── Delete confirmation dialog ────────────────────────────────────────────
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete Account?") },
            text = { Text("This will permanently delete your account and all your data. This cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        viewModel.deleteAccount(onDeleted = onAccountDeleted)
                    }
                ) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("Cancel") }
            }
        )
    }

    // ── Logout confirmation dialog ────────────────────────────────────────────
    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text("Log Out?") },
            text = { Text("You'll need to log back in to access your account.") },
            confirmButton = {
                TextButton(onClick = {
                    showLogoutDialog = false
                    onLoggedOut()
                }) { Text("Log Out") }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutDialog = false }) { Text("Cancel") }
            }
        )
    }

    // ── Photo picker dialog ───────────────────────────────────────────────────
    if (showPhotoPickerDialog) {
        AlertDialog(
            onDismissRequest = { showPhotoPickerDialog = false },
            title = { Text("Change Photo") },
            confirmButton = {
                Column(Modifier.fillMaxWidth()) {
                    Button(
                        onClick = { showPhotoPickerDialog = false; galleryLauncher.launch("image/*") },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("📷 Choose from Gallery") }
                    Spacer(Modifier.height(8.dp))
                    Button(
                        onClick = {
                            showPhotoPickerDialog = false
                            if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
                                == PackageManager.PERMISSION_GRANTED
                            ) {
                                val uri = createCameraFile(context)
                                if (uri != null) { tempCameraUri = uri; cameraLauncher.launch(uri) }
                            } else {
                                cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("📸 Take Photo") }
                }
            },
            dismissButton = {
                TextButton(onClick = { showPhotoPickerDialog = false }) { Text("Cancel") }
            }
        )
    }

    Scaffold(
        topBar = { AppTopBar(title = "Profile & Settings", onBack = onBack) }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            if (state.loading) {
                Spacer(Modifier.height(200.dp))
                CircularProgressIndicator()
                return@Column
            }

            state.error?.let { error ->
                Card(
                    modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
                ) {
                    Row(Modifier.padding(16.dp), Arrangement.SpaceBetween, Alignment.CenterVertically) {
                        Text(error, Modifier.weight(1f), color = MaterialTheme.colorScheme.onErrorContainer)
                        IconButton(onClick = { viewModel.clearError() }) { Text("✕") }
                    }
                }
            }

            // ── Profile Photo ─────────────────────────────────────────────────
            Box(modifier = Modifier.size(120.dp), contentAlignment = Alignment.BottomEnd) {
                if (state.photoUrl.isNotEmpty()) {
                    AsyncImage(
                        model = state.photoUrl,
                        contentDescription = "Profile Photo",
                        modifier = Modifier.size(120.dp).clip(CircleShape),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Icon(
                        Icons.Default.AccountCircle,
                        contentDescription = null,
                        modifier = Modifier.size(120.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                FloatingActionButton(
                    onClick = { showPhotoPickerDialog = true },
                    modifier = Modifier.size(40.dp),
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                ) {
                    Icon(Icons.Default.CameraAlt, null, tint = MaterialTheme.colorScheme.onPrimaryContainer)
                }
            }

            Spacer(Modifier.height(8.dp))
            Text(
                if (state.photoUrl.isNotEmpty()) "Tap camera to change photo" else "Tap camera to add photo",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(Modifier.height(32.dp))

            // ── Account Info ──────────────────────────────────────────────────
            Text("Account", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold,
                modifier = Modifier.fillMaxWidth(), color = MaterialTheme.colorScheme.primary)

            Spacer(Modifier.height(8.dp))

            OutlinedTextField(
                value = state.nickname,
                onValueChange = { viewModel.updateNickname(it) },
                label = { Text("Nickname") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            Spacer(Modifier.height(12.dp))

            Button(
                onClick = { viewModel.saveProfile(onDone = onBack) },
                modifier = Modifier.fillMaxWidth().height(48.dp),
                enabled = state.nickname.isNotBlank() && !state.loading
            ) {
                Text("Save Changes")
            }

            Spacer(Modifier.height(32.dp))
            HorizontalDivider()
            Spacer(Modifier.height(24.dp))

            // ── Danger Zone ───────────────────────────────────────────────────
            Text("Account Actions", style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold, modifier = Modifier.fillMaxWidth(),
                color = MaterialTheme.colorScheme.primary)

            Spacer(Modifier.height(8.dp))

            OutlinedButton(
                onClick = { showLogoutDialog = true },
                modifier = Modifier.fillMaxWidth().height(48.dp)
            ) {
                Text("Log Out")
            }

            Spacer(Modifier.height(8.dp))

            OutlinedButton(
                onClick = { showDeleteDialog = true },
                modifier = Modifier.fillMaxWidth().height(48.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = MaterialTheme.colorScheme.error
                )
            ) {
                Text("Delete Account")
            }

            Spacer(Modifier.height(32.dp))

            // ── User ID (debug) ───────────────────────────────────────────────
            OutlinedTextField(
                value = state.uid,
                onValueChange = {},
                label = { Text("User ID") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                readOnly = true,
                enabled = false
            )
        }
    }
}

private fun createCameraFile(context: android.content.Context): Uri? {
    return try {
        val file = File.createTempFile("profile_${System.currentTimeMillis()}", ".jpg", context.cacheDir)
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    } catch (e: Exception) {
        null
    }
}