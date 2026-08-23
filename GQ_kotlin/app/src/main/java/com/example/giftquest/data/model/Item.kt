package com.example.giftquest.data.model

data class Item(
    val remoteId: String,
    val title: String,
    val category: String,       // e.g. "Fashion & Clothing"
    val price: Double,          // approximate price
    val link: String,           // optional URL
    val note: String,           // optional free-text hint
    val createdAtMillis: Long,
    val updatedAtMillis: Long,
    val position: Double,
)