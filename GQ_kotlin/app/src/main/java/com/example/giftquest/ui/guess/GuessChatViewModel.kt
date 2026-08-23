package com.example.giftquest.ui.guess

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.giftquest.data.GameResultsRepository
import com.example.giftquest.data.ItemsRepository
import com.example.giftquest.data.NotificationService
import com.example.giftquest.data.model.GameMessage
import com.example.giftquest.data.model.Item
import com.example.giftquest.data.remote.AppConfig
import com.example.giftquest.data.remote.RemoteConfigRepository
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

private const val TAG = "GiftQuest"

enum class Sender { USER, AI }
data class ChatMessage(val sender: Sender, val text: String)
enum class GameState { PLAYING, WON, GIVEN_UP, ALREADY_PLAYED }

class GuessChatViewModel(app: Application) : AndroidViewModel(app) {

    private val itemsRepo = ItemsRepository()
    private val gameResultsRepo = GameResultsRepository()
    private val remoteConfigRepo = RemoteConfigRepository()
    private val uid = FirebaseAuth.getInstance().currentUser?.uid ?: "anon"

    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _gameState = MutableStateFlow(GameState.PLAYING)
    val gameState: StateFlow<GameState> = _gameState.asStateFlow()

    private val _guessCount = MutableStateFlow(0)
    val guessCount: StateFlow<Int> = _guessCount.asStateFlow()

    private val _revealedTitle = MutableStateFlow<String?>(null)
    val revealedTitle: StateFlow<String?> = _revealedTitle.asStateFlow()

    // ── Remote AI config — live from Firestore, no reinstall needed ────────────
    private val aiConfig: StateFlow<AppConfig> = remoteConfigRepo.appConfigFlow()
        .catch { emit(AppConfig()) }
        .stateIn(viewModelScope, SharingStarted.Eagerly, AppConfig())

    private var currentItem: Item? = null
    private var itemOwnerId: String? = null
    private var itemLoaded = false
    private var enrichedContext: String = ""

    // ── Setup ──────────────────────────────────────────────────────────────────

    fun loadItem(itemId: String, itemOwnerId: String) {
        if (itemLoaded) return
        itemLoaded = true
        this.itemOwnerId = itemOwnerId
        Log.d(TAG, "loadItem() — itemId=$itemId, itemOwnerId=$itemOwnerId")

        viewModelScope.launch {
            _isLoading.value = true

            // Check if already guessed — load saved conversation
            val existingResult = gameResultsRepo.getResultForItem(uid, itemId)
            if (existingResult != null) {
                Log.d(TAG, "Item already guessed — loading saved conversation")
                _messages.value = existingResult.messages.map { msg ->
                    ChatMessage(
                        sender = if (msg.role == "user") Sender.USER else Sender.AI,
                        text   = msg.text
                    )
                }
                _guessCount.value      = existingResult.guessCount
                _revealedTitle.value   = existingResult.itemSnapshot.title
                _gameState.value       = GameState.ALREADY_PLAYED
                _isLoading.value       = false
                return@launch
            }

            // New game — load the item
            try {
                val items = itemsRepo.itemsFlow(itemOwnerId).first()
                val item  = items.find { it.remoteId == itemId } ?: run {
                    Log.e(TAG, "Item $itemId not found")
                    _isLoading.value = false
                    return@launch
                }
                currentItem = item
                Log.d(TAG, "Found item: ${item.title}")

                // Notify item owner that their partner started guessing
                launch {
                    NotificationService.sendNotificationToUser(
                        targetUid = itemOwnerId,
                        title     = "Someone's guessing 🕵️",
                        message   = "Your partner is trying to guess one of your gifts!"
                    )
                }

                // Launch greeting and URL context fetch simultaneously
                val greetingJob = launch { sendGreeting(item) }
                launch {
                    enrichedContext = GiftContextFetcher.fetch(item.link)
                    Log.d(TAG, "Context fetch done — hasContent=${enrichedContext.isNotBlank()}")
                }
                greetingJob.join()

            } catch (e: Exception) {
                Log.e(TAG, "Error loading item: ${e.message}", e)
            }

            _isLoading.value = false
        }
    }

    // ── Game logic ─────────────────────────────────────────────────────────────

    private suspend fun sendGreeting(item: Item) {
        _isLoading.value = true
        val greeting = GroqApiClient.call(
            systemPrompt = buildGreetingPrompt(),
            history      = emptyList(),
            userMessage  = "__START__",
            model        = GameConfig.MODEL_GREETING
        )
        appendAiMessage(greeting)
        _isLoading.value = false
    }

    fun sendGuess(text: String) {
        if (_gameState.value != GameState.PLAYING) return
        val item = currentItem ?: run {
            Log.e(TAG, "sendGuess() called but currentItem is null!")
            return
        }

        Log.d(TAG, "sendGuess: $text — contextReady=${enrichedContext.isNotBlank()}")
        _guessCount.value += 1
        appendUserMessage(text)

        viewModelScope.launch {
            _isLoading.value = true
            val response = GroqApiClient.call(
                systemPrompt = buildGamePrompt(item),
                history      = _messages.value.dropLast(1),
                userMessage  = text,
                model        = GameConfig.MODEL_GAME
            )
            appendAiMessage(response)
            _isLoading.value = false

            if (response.contains("CORRECT_GUESS", ignoreCase = true)) {
                _gameState.value     = GameState.WON
                _revealedTitle.value = item.title
                saveResult(won = true)

                val ownerId = itemOwnerId
                if (ownerId != null) {
                    launch {
                        NotificationService.sendNotificationToUser(
                            targetUid = ownerId,
                            title     = "Gift guessed! 🎉",
                            message   = "Your partner guessed your gift correctly!"
                        )
                    }
                }
            }
        }
    }

    fun giveUp() {
        val item = currentItem ?: return
        _gameState.value     = GameState.GIVEN_UP
        _revealedTitle.value = item.title
        val reveal = buildString {
            append("The gift was: ${item.title}")
            if (item.category.isNotBlank()) append(" (${item.category})")
            if (item.price > 0) append(", about €${"%.0f".format(item.price)}")
            if (item.link.isNotBlank()) append("\n${item.link}")
        }
        appendAiMessage(reveal)
        saveResult(won = false)
    }

    // ── Save result ────────────────────────────────────────────────────────────

    private fun saveResult(won: Boolean) {
        val ownerId = itemOwnerId ?: return
        val item    = currentItem ?: return

        val gameMessages = _messages.value.map { msg ->
            GameMessage(
                role = if (msg.sender == Sender.USER) "user" else "ai",
                text = msg.text
            )
        }

        viewModelScope.launch {
            try {
                gameResultsRepo.saveGameResult(
                    guesserUid = uid,
                    partnerUid = ownerId,
                    itemId     = item.remoteId,
                    item       = item,
                    won        = won,
                    guessCount = _guessCount.value,
                    difficulty = aiConfig.value.aiDifficulty, // ← now from Firestore
                    messages   = gameMessages
                )
                Log.d(TAG, "Game result saved successfully")
            } catch (e: Exception) {
                Log.w(TAG, "Could not save game result: ${e.message}")
            }
        }
    }

    // ── Prompts — now driven by Firestore remote config ───────────────────────

    private fun buildGreetingPrompt(): String = """
You are a fun, witty gift-guessing game host.
Send a short playful greeting to kick off the game in 1-2 sentences.
Do NOT mention anything about the gift. Just welcome the player warmly.
    """.trimIndent()

    private fun buildGamePrompt(item: Item): String {
        val cfg = aiConfig.value  // live from Firestore — no restart needed

        val priceRange = when {
            item.price <= 0  -> "unknown price"
            item.price < 20  -> "under €20 (inexpensive)"
            item.price < 50  -> "€20–50 (affordable)"
            item.price < 100 -> "€50–100 (moderate)"
            item.price < 200 -> "€100–200 (pricey)"
            else             -> "over €200 (expensive)"
        }

        val revealText = buildString {
            append("Your partner wished for: ${item.title}")
            if (item.price > 0) append(", about €${"%.0f".format(item.price)}")
            if (item.link.isNotBlank()) append(" — find it here: ${item.link}")
        }

        // Difficulty instructions from Firestore
        val difficultyPrompt = when (cfg.aiDifficulty.lowercase()) {
            "easy" -> "Be generous with hints. After every 2 wrong guesses give a clear clue. Accept near-correct answers and synonyms as correct."
            "hard" -> "Be stingy with hints. Only confirm or deny. Give a clue only after 5 wrong guesses. Require a very specific answer to win."
            else   -> "Give a helpful clue every 3 wrong guesses. Accept synonyms and close matches as correct." // medium
        }

        // Base system prompt from Firestore, falls back to hardcoded if blank
        val basePrompt = cfg.aiSystemPrompt.ifBlank {
            "You are a fun, witty gift-guessing game host. Someone's partner is trying to guess a gift they wished for."
        }

        return """
$basePrompt

THE GIFT (SECRET — never reveal directly):
- Name: ${item.title}
- Category: ${item.category}
- Price: $priceRange
- Note: ${item.note.ifBlank { "none" }}
$enrichedContext
DIFFICULTY: $difficultyPrompt

RULES:
1. Never say the gift name or reveal it directly.
2. Answer yes/no questions truthfully but cleverly.
3. Give vague category hints when helpful.
4. Accept synonyms and close matches as correct.
5. When the partner guesses correctly, respond with:
   "CORRECT_GUESS 🎉 [fun celebration. Then: $revealText]"
6. Keep ALL responses SHORT — 1 to 2 sentences maximum.
7. Be playful and warm. This is a fun game between partners.
        """.trimIndent()
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private fun appendUserMessage(text: String) {
        _messages.value = _messages.value + ChatMessage(Sender.USER, text)
    }

    private fun appendAiMessage(text: String) {
        _messages.value = _messages.value + ChatMessage(Sender.AI, text)
    }
}