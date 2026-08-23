package com.example.giftquest.data.model

data class GameMessage(
    val role: String,   // "user" or "ai"
    val text: String
)

data class ItemSnapshot(
    val title: String,
    val category: String,
    val price: Double,
    val link: String
)

data class GameResult(
    val remoteId: String,
    val itemId: String,
    val itemOwnerId: String,
    val partnerUid: String,
    val won: Boolean,
    val guessCount: Int,
    val difficulty: String,
    val playedAtMillis: Long,
    val itemSnapshot: ItemSnapshot,
    val messages: List<GameMessage>
)