plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    id("com.google.gms.google-services")
}

// ── Auto-increment version ─────────────────────────────────────────────────
// Defined at top level so they're accessible everywhere in this file
val versionFile = rootProject.file("version.txt")
val versionLines = if (versionFile.exists()) versionFile.readLines() else listOf("1", "1.0.1")
val currentVersionCode = versionLines[0].trim().toInt()
val currentVersionName = if (versionLines.size > 1) versionLines[1].trim() else "1.0.$currentVersionCode"

// ──────────────────────────────────────────────────────────────────────────

android {
    namespace = "com.example.giftquest"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.giftquest"
        minSdk = 26
        targetSdk = 35
        versionCode = currentVersionCode
        versionName = currentVersionName

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // Load secrets from local.properties (never commit this file)
        val localProperties = org.jetbrains.kotlin.konan.properties.Properties().apply {
            val file = rootProject.file("local.properties")
            if (file.exists()) file.inputStream().use { load(it) }
        }

        buildConfigField("String", "GROQ_API_KEY",      "\"${localProperties["GROQ_API_KEY"] ?: ""}\"")
        buildConfigField("String", "WEB_CLIENT_ID",     "\"${localProperties["WEB_CLIENT_ID"] ?: ""}\"")
        buildConfigField("String", "CLOUDINARY_CLOUD",  "\"${localProperties["CLOUDINARY_CLOUD"] ?: ""}\"")
        buildConfigField("String", "CLOUDINARY_PRESET", "\"${localProperties["CLOUDINARY_PRESET"] ?: ""}\"")
    }

    // Custom APK name: GiftQuest-v5.apk
    applicationVariants.all {
        outputs
            .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { it.outputFileName = "GiftQuest-v$currentVersionName.apk" }
    }


    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    // Core
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)

    // Compose
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)

    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.7")

    // Lifecycle
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.4")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")

    // Firebase
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")

    // Google Sign-In
    implementation("com.google.android.gms:play-services-auth:21.2.0")
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    // Facebook Login
    implementation("com.facebook.android:facebook-login:latest.release")

    // Image loading
    implementation("io.coil-kt:coil-compose:2.6.0")

    // Drag-to-reorder
    implementation("org.burnoutcrew.composereorderable:reorderable:0.9.6")

    // Splash screen
    implementation("androidx.core:core-splashscreen:1.0.1")

    // QR codes (share code feature)
    implementation("com.google.zxing:core:3.5.3")
    implementation("com.journeyapps:zxing-android-embedded:4.3.0")

    // AppCompat (needed by Facebook SDK)
    implementation("androidx.appcompat:appcompat:1.6.1")

    // Tests
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
}

// ── Auto-increment versionCode after every successful APK build ────────────
tasks.whenTaskAdded {
    if (name == "assembleDebug" || name == "assembleRelease") {
        doLast {
            val nextCode = currentVersionCode + 1
            // Patch number follows versionCode automatically
            val parts = currentVersionName.split(".")
            val nextName = "${parts[0]}.${parts[1]}.$nextCode"
            versionFile.writeText("$nextCode\n$nextName")
            println("✓ Version bumped: $currentVersionCode ($currentVersionName) → $nextCode ($nextName)")
        }
    }
}