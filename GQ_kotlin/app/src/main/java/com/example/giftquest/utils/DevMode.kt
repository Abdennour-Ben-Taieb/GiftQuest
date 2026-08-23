package com.example.giftquest.utils

/**
 * Dev Mode Configuration
 * Set DEV_MODE_ENABLED = false before production release.
 */
object DevMode {

    const val DEV_MODE_ENABLED = false

    private val WHITELISTED_DEVICES = mapOf(

        // Xiaomi phone → t1@gmail.com
        "23117RA68G" to DeviceConfig(
            email = "t1@gmail.com",
            password = "444444"
        ),

        // Pixel 9 XL emulator → t2@gmail.com
        "sdk_gphone64_x86_64" to DeviceConfig(
            email = "t2@gmail.com",
            password = "444444"
        )
    )

    fun isDeviceWhitelisted(): Boolean {
        if (!DEV_MODE_ENABLED) return false
        val deviceModel = android.os.Build.MODEL
        android.util.Log.d("DevMode", "Current device: $deviceModel")
        return WHITELISTED_DEVICES.keys.any { deviceModel.contains(it, ignoreCase = true) }
    }

    fun getDeviceConfig(): DeviceConfig? {
        if (!DEV_MODE_ENABLED) return null
        val deviceModel = android.os.Build.MODEL
        return WHITELISTED_DEVICES.entries
            .firstOrNull { (model, _) -> deviceModel.contains(model, ignoreCase = true) }
            ?.value
    }

    data class DeviceConfig(val email: String, val password: String)
}