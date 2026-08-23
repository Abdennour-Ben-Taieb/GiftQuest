package com.example.giftquest.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// Use default system sans or swap to Inter if you add the font files.
val AppTypography = Typography(
    displayLarge = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.SemiBold),
    titleLarge   = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.SemiBold),
    titleMedium  = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge    = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Normal),
    bodyMedium   = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Normal),
    labelLarge   = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium) // buttons
)
