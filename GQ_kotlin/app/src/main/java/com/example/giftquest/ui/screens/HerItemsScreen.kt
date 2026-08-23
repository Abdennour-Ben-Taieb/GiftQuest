package com.example.giftquest.ui.screens

import android.Manifest
import android.graphics.Bitmap
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.giftquest.data.GameResultsRepository
import com.example.giftquest.data.model.GameResult
import com.example.giftquest.ui.heritems.HerItemsViewModel
import com.google.firebase.auth.FirebaseAuth
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HerItemsScreen(
    onBack: () -> Unit,
    onGuess: (String) -> Unit,
    viewModel: HerItemsViewModel = viewModel()
) {
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()
    var partnerCodeInput by remember { mutableStateOf("") }
    var showQRCode by remember { mutableStateOf(false) }
    var qrCodeBitmap by remember { mutableStateOf<Bitmap?>(null) }

    LaunchedEffect(state.myShareCode) {
        if (state.myShareCode.isNotBlank()) {
            qrCodeBitmap = generateQRCode(state.myShareCode)
        }
    }

    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        if (result.contents != null) {
            partnerCodeInput = result.contents.uppercase()
            viewModel.linkWith(result.contents.uppercase()) // auto-link immediately
        } else {
            Toast.makeText(context, "Scan cancelled", Toast.LENGTH_SHORT).show()
        }
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            val options = ScanOptions().apply {
                setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                setPrompt("Scan your partner's QR code")
                setBeepEnabled(true)
                setOrientationLocked(false)
            }
            scanLauncher.launch(options)
        } else {
            Toast.makeText(context, "Camera permission required", Toast.LENGTH_LONG).show()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Partner's Wishlist") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Text("←", style = MaterialTheme.typography.headlineMedium)
                    }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            if (state.loading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                return@Column
            }

            state.error?.let { error ->
                Card(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(error, modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.onErrorContainer)
                        IconButton(onClick = { viewModel.clearError() }) { Text("✕") }
                    }
                }
            }

            if (!state.isLinked) {
                NotLinkedContent(
                    myShareCode = state.myShareCode,
                    partnerCodeInput = partnerCodeInput,
                    onPartnerCodeChange = { partnerCodeInput = it },
                    onLinkClick = { viewModel.linkWith(partnerCodeInput) },
                    qrCodeBitmap = qrCodeBitmap,
                    showQRCode = showQRCode,
                    onToggleQRCode = { showQRCode = !showQRCode },
                    onScanQRCode = { cameraPermissionLauncher.launch(Manifest.permission.CAMERA) }
                )
            } else {
                LinkedContent(
                    partnerItems = state.partnerItems,
                    partnerUid = state.partnerUid ?: "",  // ← fixed: now passed
                    onUnlinkClick = { viewModel.unlink() },
                    onGuess = onGuess
                )
            }
        }
    }
}

@Composable
private fun NotLinkedContent(
    myShareCode: String,
    partnerCodeInput: String,
    onPartnerCodeChange: (String) -> Unit,
    onLinkClick: () -> Unit,
    qrCodeBitmap: Bitmap?,
    showQRCode: Boolean,
    onToggleQRCode: () -> Unit,
    onScanQRCode: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Spacer(Modifier.height(16.dp))
        Text("Not Linked with Partner", style = MaterialTheme.typography.headlineMedium, textAlign = TextAlign.Center)
        Text("Share your code with your partner:", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)

        ElevatedCard(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = myShareCode.ifBlank { "Loading..." },
                    style = MaterialTheme.typography.displaySmall,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(Modifier.height(16.dp))
                OutlinedButton(onClick = onToggleQRCode, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Default.QrCode, contentDescription = null, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(if (showQRCode) "Hide QR Code" else "Show QR Code")
                }
                if (showQRCode && qrCodeBitmap != null) {
                    Spacer(Modifier.height(16.dp))
                    Card(
                        modifier = Modifier.size(250.dp).padding(8.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                    ) {
                        Image(
                            bitmap = qrCodeBitmap.asImageBitmap(),
                            contentDescription = "QR Code",
                            modifier = Modifier.fillMaxSize().padding(16.dp)
                        )
                    }
                    Text("Let your partner scan this code", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }

        HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
        Text("Enter partner's code:", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)

        OutlinedTextField(
            value = partnerCodeInput,
            onValueChange = { onPartnerCodeChange(it.uppercase()) },
            label = { Text("Partner's Code") },
            placeholder = { Text("e.g., A3F7B2C1") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        OutlinedButton(onClick = onScanQRCode, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Default.QrCodeScanner, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text("Scan Partner's QR Code")
        }

        Button(onClick = onLinkClick, modifier = Modifier.fillMaxWidth().height(56.dp), enabled = partnerCodeInput.isNotBlank()) {
            Text("Link with Partner", style = MaterialTheme.typography.titleMedium)
        }

        Spacer(Modifier.weight(1f))

        Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("💡 How it works:", style = MaterialTheme.typography.titleSmall)
                Text("1. Share your code above with your partner", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("2. Ask them to enter it in their app", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("3. You'll instantly see each other's wishlists!", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun LinkedContent(
    partnerItems: List<com.example.giftquest.data.model.Item>,
    partnerUid: String,
    onUnlinkClick: () -> Unit,
    onGuess: (String) -> Unit
) {
    val currentUid = FirebaseAuth.getInstance().currentUser?.uid ?: ""

    val gameResults by produceState(
        initialValue = emptyMap<String, GameResult>(),
        key1 = partnerUid
    ) {
        if (partnerUid.isNotBlank()) {
            GameResultsRepository()
                .gameResultsFlow(currentUid, partnerUid)
                .collect { results ->
                    value = results.associateBy { it.itemId }
                }
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Card(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Linked with Partner", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "${partnerItems.size} gifts · ${gameResults.size} guessed",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                OutlinedButton(
                    onClick = onUnlinkClick,
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                ) { Text("Unlink") }
            }
        }

        if (partnerItems.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
                Text(
                    "Your partner hasn't added any gifts yet.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                itemsIndexed(partnerItems) { _, item ->
                    val result = gameResults[item.remoteId]
                    AnonymizedGiftCard(
                        itemId = item.remoteId,
                        category = item.category,
                        isGuessed = result != null,
                        revealedTitle = result?.itemSnapshot?.title,
                        guessCount = result?.guessCount ?: 0,
                        onClick = { onGuess(item.remoteId) }
                    )
                }
                item { Spacer(Modifier.height(16.dp)) }
            }
        }
    }
}

private fun generateQRCode(text: String, size: Int = 512): Bitmap? {
    return try {
        val writer = QRCodeWriter()
        val bitMatrix = writer.encode(text, BarcodeFormat.QR_CODE, size, size)
        val bitmap = Bitmap.createBitmap(bitMatrix.width, bitMatrix.height, Bitmap.Config.RGB_565)
        for (x in 0 until bitMatrix.width) {
            for (y in 0 until bitMatrix.height) {
                bitmap.setPixel(x, y, if (bitMatrix[x, y]) android.graphics.Color.BLACK else android.graphics.Color.WHITE)
            }
        }
        bitmap
    } catch (e: Exception) {
        android.util.Log.e("GiftQuest", "Failed to generate QR code", e)
        null
    }
}