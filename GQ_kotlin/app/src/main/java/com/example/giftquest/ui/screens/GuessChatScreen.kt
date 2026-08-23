package com.example.giftquest.ui.screens

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.ClickableText
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.giftquest.ui.components.AppTopBar
import com.example.giftquest.ui.guess.GameState
import com.example.giftquest.ui.guess.GuessChatViewModel
import com.example.giftquest.ui.guess.Sender

// Matches http:// or https:// URLs
private val URL_REGEX = Regex("""https?://[^\s]+""")

@Composable
fun GuessChatScreen(
    itemId: String?,
    itemOwnerId: String,
    onBack: () -> Unit
) {
    val app = LocalContext.current.applicationContext as Application
    val vm: GuessChatViewModel = viewModel(
        factory = androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.getInstance(app)
    )

    LaunchedEffect(itemId, itemOwnerId) {
        if (!itemId.isNullOrBlank()) {
            vm.loadItem(itemId, itemOwnerId)
        }
    }

    if (itemId.isNullOrBlank()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Invalid item", style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.height(16.dp))
                Button(onClick = onBack) { Text("Go Back") }
            }
        }
        return
    }

    val messages by vm.messages.collectAsState()
    val isLoading by vm.isLoading.collectAsState()
    val gameState by vm.gameState.collectAsState()
    val guessCount by vm.guessCount.collectAsState()

    var input by remember { mutableStateOf("") }

    val listState = rememberLazyListState()
    val reversedMessages = messages.reversed()

    Scaffold(
        topBar = { AppTopBar(title = "Guess the Gift 🎁", onBack = onBack) },
        bottomBar = {
            if (gameState == GameState.PLAYING) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .imePadding()
                        .navigationBarsPadding()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        OutlinedTextField(
                            value = input,
                            onValueChange = { input = it },
                            modifier = Modifier.weight(1f),
                            placeholder = { Text("Ask or guess…") },
                            enabled = !isLoading,
                            maxLines = 3
                        )
                        Spacer(Modifier.width(8.dp))
                        Button(
                            onClick = {
                                val text = input.trim()
                                if (text.isNotEmpty() && !isLoading) {
                                    vm.sendGuess(text)
                                    input = ""
                                }
                            },
                            enabled = input.isNotBlank() && !isLoading
                        ) {
                            Text("Send")
                        }
                    }
                }
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            if (guessCount > 0 && gameState == GameState.PLAYING) {
                Text(
                    "Guesses: $guessCount",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .align(Alignment.End)
                        .padding(horizontal = 16.dp, vertical = 4.dp)
                )
            }

            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                reverseLayout = true,
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(vertical = 12.dp)
            ) {
                if (isLoading) {
                    item {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(vertical = 4.dp)
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                "thinking…",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }

                items(reversedMessages) { msg ->
                    ChatBubble(
                        text = msg.text.replace("CORRECT_GUESS", "").trim(),
                        isUser = msg.sender == Sender.USER
                    )
                }
            }

            if (gameState == GameState.WON || gameState == GameState.GIVEN_UP) {
                GameOverBanner(
                    won = gameState == GameState.WON,
                    guessCount = guessCount,
                    onBack = onBack
                )
            }
        }
    }
}

@Composable
private fun ChatBubble(text: String, isUser: Boolean) {
    val context = LocalContext.current
    val linkColor = MaterialTheme.colorScheme.primary

    // Build annotated string — plain text with URLs highlighted and tagged
    val annotatedText = buildAnnotatedString {
        var lastIndex = 0
        URL_REGEX.findAll(text).forEach { match ->
            // Append plain text before the URL
            append(text.substring(lastIndex, match.range.first))
            // Append the URL with annotation + style
            pushStringAnnotation(tag = "URL", annotation = match.value)
            withStyle(
                SpanStyle(
                    color = linkColor,
                    textDecoration = TextDecoration.Underline,
                    fontWeight = FontWeight.Medium
                )
            ) {
                append(match.value)
            }
            pop()
            lastIndex = match.range.last + 1
        }
        // Append remaining plain text after last URL
        if (lastIndex < text.length) {
            append(text.substring(lastIndex))
        }
    }

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = if (isUser) Alignment.End else Alignment.Start
    ) {
        Text(
            text = if (isUser) "You" else "🎁",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 4.dp)
        )
        Spacer(Modifier.height(2.dp))
        Box(
            modifier = Modifier
                .widthIn(max = 300.dp)
                .background(
                    color = if (isUser)
                        MaterialTheme.colorScheme.primaryContainer
                    else
                        MaterialTheme.colorScheme.secondaryContainer,
                    shape = RoundedCornerShape(
                        topStart = 16.dp,
                        topEnd = 16.dp,
                        bottomStart = if (isUser) 16.dp else 4.dp,
                        bottomEnd = if (isUser) 4.dp else 16.dp
                    )
                )
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            ClickableText(
                text = annotatedText,
                style = MaterialTheme.typography.bodyMedium.copy(
                    color = MaterialTheme.colorScheme.onSecondaryContainer
                ),
                onClick = { offset ->
                    annotatedText.getStringAnnotations(
                        tag = "URL",
                        start = offset,
                        end = offset
                    ).firstOrNull()?.let { annotation ->
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(annotation.item))
                        context.startActivity(intent)
                    }
                }
            )
        }
    }
}

@Composable
private fun GameOverBanner(
    won: Boolean,
    guessCount: Int,
    onBack: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = if (won) MaterialTheme.colorScheme.primaryContainer
        else MaterialTheme.colorScheme.errorContainer,
        tonalElevation = 4.dp
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = if (won) "🎉 You got it!" else "😅 Better luck next time!",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            if (won) {
                Spacer(Modifier.height(4.dp))
                Text("$guessCount guesses", style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(12.dp))
            Button(onClick = onBack) { Text("Back to gifts") }
        }
    }
}