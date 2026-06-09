package com.example.giftquest.ui.screens

import android.app.Application
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DragHandle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import coil.compose.AsyncImage
import com.example.giftquest.Routes
import com.example.giftquest.data.model.GameResult
import com.example.giftquest.data.model.Item
import com.example.giftquest.ui.home.HomeViewModel
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.burnoutcrew.reorderable.*

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    navController: NavController,
    onAddItem: () -> Unit,
    onEditItem: (String) -> Unit,
    onOpenGuessChat: (String, String) -> Unit,
    onOpenProfile: () -> Unit
) {
    val app = LocalContext.current.applicationContext as Application
    val vm: HomeViewModel = viewModel(factory = HomeViewModel.factory(app))

    val myItems: List<Item> by vm.myItems.collectAsState()
    val partnerItems: List<Item> by vm.partnerItems.collectAsState()
    val partnerUid: String? by vm.partnerUid.collectAsState()
    val showTutorial by vm.showTutorial.collectAsState()
    val gameResults by vm.gameResults.collectAsState()

    val snackbarHostState = remember { SnackbarHostState() }
    val uiMessage by vm.message.collectAsState()

    LaunchedEffect(uiMessage) {
        uiMessage?.let {
            snackbarHostState.showSnackbar(it)
            vm.consumeMessage()
        }
    }

    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    val pagerState = rememberPagerState(initialPage = 0, pageCount = { 2 })

    val authUser = FirebaseAuth.getInstance().currentUser
    val uid = authUser?.uid ?: "unknown"
    val isLinked = partnerUid != null

    // ── My profile ────────────────────────────────────────────────────────────
    var userNickname by remember { mutableStateOf(authUser?.displayName ?: "You") }
    var userPhotoUrl by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(uid) {
        if (uid != "unknown") {
            try {
                val doc = FirebaseFirestore.getInstance()
                    .collection("users").document(uid).get().await()
                userNickname = doc.getString("nickname") ?: authUser?.displayName ?: "You"
                userPhotoUrl = doc.getString("photoUrl")
            } catch (e: Exception) {
                android.util.Log.e("GiftQuest", "Failed to load user profile", e)
            }
        }
    }

    // ── Partner profile ───────────────────────────────────────────────────────
    var partnerNickname by remember { mutableStateOf("Partner") }
    var partnerPhotoUrl by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(partnerUid) {
        if (partnerUid != null) {
            try {
                val doc = FirebaseFirestore.getInstance()
                    .collection("users").document(partnerUid!!).get().await()
                partnerNickname = doc.getString("nickname")?.takeIf { it.isNotBlank() } ?: "Partner"
                partnerPhotoUrl = doc.getString("photoUrl")
            } catch (e: Exception) {
                android.util.Log.e("GiftQuest", "Failed to load partner profile", e)
            }
        } else {
            partnerNickname = "Partner"
            partnerPhotoUrl = null
        }
    }

    // ── Notify ViewModel when tab changes (via swipe or click) ───────────────
    LaunchedEffect(pagerState.currentPage) {
        if (pagerState.currentPage == 1) vm.onPartnerTabOpened()
        else vm.onPartnerTabClosed()
    }

    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = {
            ModalDrawerSheet {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                ) {
                    // ── My profile row ────────────────────────────────────────
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable {
                                scope.launch {
                                    drawerState.close()
                                    onOpenProfile()
                                }
                            },
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        if (!userPhotoUrl.isNullOrEmpty()) {
                            AsyncImage(
                                model = userPhotoUrl,
                                contentDescription = "Profile Photo",
                                modifier = Modifier
                                    .size(56.dp)
                                    .clip(CircleShape),
                                contentScale = ContentScale.Crop
                            )
                        } else {
                            Icon(
                                Icons.Default.AccountCircle,
                                contentDescription = "Profile",
                                modifier = Modifier.size(56.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text(
                                userNickname,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                "Tap to edit profile",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    Spacer(Modifier.height(16.dp))
                    HorizontalDivider()
                    Spacer(Modifier.height(16.dp))

                    // ── Partner profile row (only when linked) ────────────────
                    if (isLinked) {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.primaryContainer
                            )
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                if (!partnerPhotoUrl.isNullOrEmpty()) {
                                    AsyncImage(
                                        model = partnerPhotoUrl,
                                        contentDescription = "Partner Photo",
                                        modifier = Modifier
                                            .size(44.dp)
                                            .clip(CircleShape),
                                        contentScale = ContentScale.Crop
                                    )
                                } else {
                                    Icon(
                                        Icons.Default.AccountCircle,
                                        contentDescription = "Partner",
                                        modifier = Modifier.size(44.dp),
                                        tint = MaterialTheme.colorScheme.onPrimaryContainer
                                    )
                                }
                                Spacer(Modifier.width(12.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        partnerNickname,
                                        style = MaterialTheme.typography.titleSmall,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer
                                    )
                                    Text(
                                        "Your partner",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f)
                                    )
                                }
                                Icon(
                                    Icons.Default.Favorite,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }
                        Spacer(Modifier.height(8.dp))
                    }

                    Button(
                        onClick = {
                            scope.launch {
                                drawerState.close()
                                vm.unlinkPartner()
                            }
                        },
                        enabled = isLinked
                    ) {
                        Text("Unlink Partner")
                    }

                    Spacer(Modifier.height(8.dp))

                    OutlinedButton(
                        onClick = {
                            scope.launch {
                                drawerState.close()
                                navController.navigate(Routes.LOGIN) {
                                    popUpTo(0) { inclusive = true }
                                    launchSingleTop = true
                                }
                                FirebaseAuth.getInstance().signOut()
                            }
                        }
                    ) {
                        Text("Log out")
                    }
                }
            }
        }
    ) {
        // ── Outer Box: lets the tutorial overlay sit on top of everything ─────
        Box(modifier = Modifier.fillMaxSize()) {

            Scaffold(
                topBar = {
                    TopAppBar(
                        title = { Text("GiftQuest") },
                        actions = {
                            IconButton(onClick = { scope.launch { drawerState.open() } }) {
                                if (!userPhotoUrl.isNullOrEmpty()) {
                                    AsyncImage(
                                        model = userPhotoUrl,
                                        contentDescription = "Profile",
                                        modifier = Modifier
                                            .size(32.dp)
                                            .clip(CircleShape),
                                        contentScale = ContentScale.Crop
                                    )
                                } else {
                                    Icon(
                                        Icons.Default.AccountCircle,
                                        contentDescription = "Account menu"
                                    )
                                }
                            }
                        }
                    )
                },
                floatingActionButton = {
                    FloatingActionButton(onClick = onAddItem) {
                        Text("🎁", style = MaterialTheme.typography.headlineMedium)
                    }
                },
                snackbarHost = { SnackbarHost(snackbarHostState) }
            ) { padding ->
                Column(
                    Modifier
                        .padding(padding)
                        .fillMaxSize()
                ) {
                    TabRow(selectedTabIndex = pagerState.currentPage) {
                        Tab(
                            selected = pagerState.currentPage == 0,
                            onClick = {
                                scope.launch { pagerState.animateScrollToPage(0) }
                                vm.onPartnerTabClosed()
                            },
                            text = { Text("My Items") }
                        )
                        Tab(
                            selected = pagerState.currentPage == 1,
                            onClick = {
                                scope.launch { pagerState.animateScrollToPage(1) }
                                vm.onPartnerTabOpened()
                            },
                            text = {
                                Text(
                                    if (isLinked) "$partnerNickname's Items"
                                    else "Partner's Items"
                                )
                            }
                        )
                    }

                    HorizontalPager(
                        state = pagerState,
                        modifier = Modifier.fillMaxSize()
                    ) { page ->
                        when (page) {
                            0 -> MyItemsPage(
                                items = myItems,
                                onEdit = { itemId -> onEditItem(itemId) },
                                onDelete = { itemId -> vm.deleteItem(itemId) },
                                onReorder = { newOrder -> vm.reorder(newOrder) },
                                onGuess = { itemId -> onOpenGuessChat(uid, itemId) }
                            )
                            1 -> {
                                if (!isLinked) {
                                    NotLinkedPage(
                                        onNavigateToLinkScreen = {
                                            navController.navigate(Routes.HER_ITEMS)
                                        }
                                    )
                                } else {
                                    PartnerItemsPage(
                                        items = partnerItems,
                                        partnerNickname = partnerNickname,
                                        gameResults = gameResults,
                                        onLoadResult = { itemId ->
                                            vm.loadGameResultForItem(itemId)
                                        },
                                        onGuess = { itemId ->
                                            onOpenGuessChat(partnerUid ?: "", itemId)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // ── Tutorial overlay: on top of Scaffold, covers full screen ──────
            if (showTutorial) {
                TutorialOverlay(
                    onFinish = { vm.markTutorialDone() }
                )
            }

        } // end outer Box
    } // end ModalNavigationDrawer
}

// ─────────────────────────────────────────────────────────────────────────────
// MyItemsPage
// ─────────────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
private fun MyItemsPage(
    items: List<Item>,
    onEdit: (String) -> Unit,
    onDelete: (String) -> Unit,
    onReorder: (List<String>) -> Unit,
    onGuess: (String) -> Unit
) {
    var itemToDelete by remember { mutableStateOf<Item?>(null) }
    var itemsList by remember(items) { mutableStateOf(items) }

    if (itemToDelete != null) {
        AlertDialog(
            onDismissRequest = { itemToDelete = null },
            title = { Text("Delete Item?") },
            text = { Text("Are you sure you want to delete '${itemToDelete?.title}'?") },
            confirmButton = {
                TextButton(onClick = {
                    itemToDelete?.let { onDelete(it.remoteId) }
                    itemToDelete = null
                }) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { itemToDelete = null }) { Text("Cancel") }
            }
        )
    }

    Column(
        Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        if (items.isEmpty()) {
            ElevatedCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(20.dp)) {
                    Text("Start your first wishlist ✨", style = MaterialTheme.typography.titleLarge)
                    Spacer(Modifier.height(8.dp))
                    Text("Tap the + button to add your first gift item.")
                }
            }
        } else {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("My Items", style = MaterialTheme.typography.titleLarge)
                Text(
                    "Long press ⋮⋮ to reorder",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Spacer(Modifier.height(8.dp))

            val reorderState = rememberReorderableLazyListState(
                onMove = { from, to ->
                    itemsList = itemsList.toMutableList().apply {
                        if (from.index in indices && to.index in indices) {
                            val item = removeAt(from.index)
                            add(to.index.coerceIn(0, size), item)
                        }
                    }
                },
                onDragEnd = { _, _ -> onReorder(itemsList.map { it.remoteId }) }
            )

            LazyColumn(
                state = reorderState.listState,
                modifier = Modifier
                    .fillMaxSize()
                    .reorderable(reorderState),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                itemsIndexed(itemsList, key = { _, item -> item.remoteId }) { _, item ->
                    ReorderableItem(reorderState, key = item.remoteId) { isDragging ->
                        val elevation by animateDpAsState(if (isDragging) 8.dp else 0.dp)
                        SwipeToDismissBox(
                            state = rememberSwipeToDismissBoxState(
                                confirmValueChange = { dismissValue ->
                                    if (dismissValue == SwipeToDismissBoxValue.EndToStart) {
                                        itemToDelete = item
                                    }
                                    false
                                }
                            ),
                            backgroundContent = {
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .padding(horizontal = 8.dp),
                                    contentAlignment = Alignment.CenterEnd
                                ) {
                                    Icon(
                                        Icons.Default.Delete,
                                        contentDescription = "Delete",
                                        tint = MaterialTheme.colorScheme.error,
                                        modifier = Modifier.size(32.dp)
                                    )
                                }
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .shadow(elevation)
                        ) {
                            ElevatedCard(
                                onClick = { onEdit(item.remoteId) },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        Icons.Default.DragHandle,
                                        contentDescription = "Drag to reorder",
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier
                                            .size(24.dp)
                                            .detectReorderAfterLongPress(reorderState)
                                    )
                                    Spacer(Modifier.width(12.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            item.title,
                                            style = MaterialTheme.typography.titleMedium,
                                            fontWeight = FontWeight.SemiBold
                                        )
                                        if (item.note.isNotBlank()) {
                                            Spacer(Modifier.height(4.dp))
                                            Text(
                                                item.note,
                                                style = MaterialTheme.typography.bodyMedium,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                maxLines = 2
                                            )
                                        }
                                        Spacer(Modifier.height(4.dp))
                                        Text(
                                            "Tap to edit • Swipe to delete • Hold ⋮⋮ to reorder",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// PartnerItemsPage
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun PartnerItemsPage(
    items: List<Item>,
    partnerNickname: String,
    gameResults: Map<String, GameResult?>,
    onLoadResult: (String) -> Unit,
    onGuess: (String) -> Unit
) {
    Column(
        Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        if (items.isEmpty()) {
            ElevatedCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(20.dp)) {
                    Text("No gifts yet ✨", style = MaterialTheme.typography.titleLarge)
                    Spacer(Modifier.height(8.dp))
                    Text("$partnerNickname hasn't added any gifts to their wishlist yet.")
                }
            }
        } else {
            Text("$partnerNickname's Gifts 🎁", style = MaterialTheme.typography.titleLarge)
            Spacer(Modifier.height(8.dp))
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                itemsIndexed(items, key = { _, item -> item.remoteId }) { _, item ->

                    // Load this item's game result when it enters the visible list
                    LaunchedEffect(item.remoteId) {
                        onLoadResult(item.remoteId)
                    }

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

// ─────────────────────────────────────────────────────────────────────────────
// NotLinkedPage
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun NotLinkedPage(onNavigateToLinkScreen: () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            "Not Linked with Partner",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(16.dp))
        Text(
            "Link with your partner to see their wishlist and share yours!",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = onNavigateToLinkScreen,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp)
        ) {
            Text("Link with Partner", style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(16.dp))
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Column(Modifier.padding(16.dp)) {
                Text("How it works:", style = MaterialTheme.typography.titleSmall)
                Spacer(Modifier.height(8.dp))
                Text("1. Get your unique share code", style = MaterialTheme.typography.bodySmall)
                Text("2. Share it with your partner", style = MaterialTheme.typography.bodySmall)
                Text("3. Enter their code too", style = MaterialTheme.typography.bodySmall)
                Text("4. You're linked! 🎁", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}