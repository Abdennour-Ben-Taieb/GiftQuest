package com.example.giftquest.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.giftquest.ui.components.AppTopBar
import com.example.giftquest.ui.home.HomeViewModel
import android.app.Application
import androidx.compose.ui.platform.LocalContext

val GIFT_CATEGORIES = listOf(
    "👗 Fashion & Clothing",
    "👜 Bags & Accessories",
    "💄 Beauty & Fragrance",
    "📱 Tech & Gadgets",
    "🏠 Home & Living",
    "🎮 Gaming & Entertainment",
    "📚 Books & Hobbies",
    "🏋️ Sports & Fitness",
    "🎟️ Experience",
    "💳 Gift Card / Money",
    "🎁 Something Else"
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddItemScreen(
    itemId: String? = null,
    onSave: () -> Unit,
    onBack: () -> Unit
) {
    val app = LocalContext.current.applicationContext as Application
    val vm: HomeViewModel = viewModel(factory = HomeViewModel.factory(app))

    var title by remember { mutableStateOf("") }
    var category by remember { mutableStateOf(GIFT_CATEGORIES[0]) }
    var priceText by remember { mutableStateOf("") }
    var link by remember { mutableStateOf("") }
    var note by remember { mutableStateOf("") }
    var isEditing by remember { mutableStateOf(false) }
    var fieldsLoaded by remember { mutableStateOf(false) }
    var categoryExpanded by remember { mutableStateOf(false) }

    val myItems by vm.myItems.collectAsState()

    LaunchedEffect(itemId, myItems) {
        if (!itemId.isNullOrBlank() && !fieldsLoaded) {
            val itemToEdit = myItems.find { it.remoteId == itemId }
            if (itemToEdit != null) {
                title = itemToEdit.title
                category = itemToEdit.category.ifBlank { GIFT_CATEGORIES[0] }
                priceText = if (itemToEdit.price > 0) itemToEdit.price.toString() else ""
                link = itemToEdit.link
                note = itemToEdit.note
                isEditing = true
                fieldsLoaded = true
            }
        }
    }

    Scaffold(
        topBar = {
            AppTopBar(
                title = if (isEditing) "Edit Gift" else "Add Gift",
                onBack = onBack
            )
        }
    ) { padding ->
        if (!itemId.isNullOrBlank() && !fieldsLoaded) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .imePadding()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp)
            ) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Gift name (secret from partner)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true   // ← never expands
                )

                Spacer(Modifier.height(12.dp))

                ExposedDropdownMenuBox(
                    expanded = categoryExpanded,
                    onExpandedChange = { categoryExpanded = it }
                ) {
                    OutlinedTextField(
                        value = category,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Category") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = categoryExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(),
                        singleLine = true   // ← never expands
                    )
                    ExposedDropdownMenu(
                        expanded = categoryExpanded,
                        onDismissRequest = { categoryExpanded = false }
                    ) {
                        GIFT_CATEGORIES.forEach { cat ->
                            DropdownMenuItem(
                                text = { Text(cat) },
                                onClick = {
                                    category = cat
                                    categoryExpanded = false
                                }
                            )
                        }
                    }
                }

                Spacer(Modifier.height(12.dp))

                OutlinedTextField(
                    value = priceText,
                    onValueChange = { priceText = it.filter { c -> c.isDigit() || c == '.' } },
                    label = { Text("Approximate price (€)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true   // ← never expands
                )

                Spacer(Modifier.height(12.dp))

                OutlinedTextField(
                    value = link,
                    onValueChange = { link = it },
                    label = { Text("Link (optional)") },
                    placeholder = { Text("https://...") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true   // ← stays one line, scrolls horizontally if long
                )

                Spacer(Modifier.height(12.dp))

                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("Note (optional)") },
                    placeholder = { Text("Color, size, brand, or anything helpful…") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                    maxLines = 4        // ← note can expand a little but not infinitely
                )

                Spacer(Modifier.height(24.dp))

                Button(
                    onClick = {
                        if (title.isNotBlank()) {
                            val price = priceText.toDoubleOrNull() ?: 0.0
                            if (isEditing && itemId != null) {
                                vm.updateItem(
                                    remoteId = itemId,
                                    title = title,
                                    category = category,
                                    price = price,
                                    link = link,
                                    note = note
                                )
                            } else {
                                vm.addItem(
                                    title = title,
                                    category = category,
                                    price = price,
                                    link = link,
                                    note = note
                                )
                            }
                            onSave()
                        }
                    },
                    modifier = Modifier.fillMaxWidth().height(48.dp)
                ) {
                    Text(if (isEditing) "Update" else "Save Gift")
                }

                if (isEditing && itemId != null) {
                    Spacer(Modifier.height(12.dp))
                    OutlinedButton(
                        onClick = {
                            vm.deleteItem(itemId)
                            onBack()
                        },
                        modifier = Modifier.fillMaxWidth().height(48.dp),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Text("Delete Gift")
                    }
                }
            }
        }
    }
}