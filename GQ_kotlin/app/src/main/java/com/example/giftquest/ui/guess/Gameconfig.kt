package com.example.giftquest.ui.guess

// ══════════════════════════════════════════════════════════
//  GAME CONFIGURATION — change everything here
// ══════════════════════════════════════════════════════════
object GameConfig {

    // Lightweight model — used only for the greeting (fast)
    const val MODEL_GREETING = "llama-3.1-8b-instant"

    // Smart model — used for the actual guessing game
    const val MODEL_GAME = "llama-3.3-70b-versatile"

    // Difficulty: "EASY", "MEDIUM", or "HARD"
    const val DIFFICULTY = "MEDIUM"

    val DIFFICULTY_PROMPT get() = when (DIFFICULTY) {
        "EASY" -> "Be generous with hints. After every 2 wrong guesses give a clear clue. Accept near-correct answers and synonyms as correct."
        "HARD" -> "Be stingy with hints. Only confirm or deny. Give a clue only after 5 wrong guesses. Require a very specific answer to win."
        else   -> "Give a helpful clue every 3 wrong guesses. Accept synonyms and close matches (e.g. 'gaming mouse' for 'mouse') as correct."
    }
}