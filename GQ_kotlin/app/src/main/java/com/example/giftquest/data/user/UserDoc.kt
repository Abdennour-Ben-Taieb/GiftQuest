package com.example.giftquest.data.user

data class UserDoc(
    val uid: String = "",
    val name: String = "",
    val nickname: String = "",
    val email: String = "",
    val photoUrl: String? = null,
    val dateOfBirth: String = "",
    val linkedWith: String? = null,
    val myShareCode: String? = null
)