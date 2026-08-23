package com.example.giftquest

import android.app.Application
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

class GiftQuestApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        FirebaseFirestore.setLoggingEnabled(BuildConfig.DEBUG)
    }
}