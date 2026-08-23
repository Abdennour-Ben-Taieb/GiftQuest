package com.example.giftquest.ui.splash

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform

@Composable
fun BrandedSplash(
    onFinish: () -> Unit,
    durationMs: Long = 2400,
    bgColor: Color = Color(0xFF3B82F6)
) {
    LaunchedEffect(Unit) {
        delay(durationMs)
        onFinish()
    }

    // Overall fade in
    val fadeIn by animateFloatAsState(
        targetValue = 1f,
        animationSpec = tween(500),
        label = "fade"
    )

    // Lid bounces up then settles
    val lidOffset by animateFloatAsState(
        targetValue = -1f,
        animationSpec = keyframes {
            durationMillis = 1200
            0f at 0
            0f at 300
            -60f at 600 using FastOutSlowInEasing
            -45f at 900 using FastOutSlowInEasing
            -50f at 1200
        },
        label = "lid"
    )

    // Stars/sparkles pop after lid opens
    val sparkle by animateFloatAsState(
        targetValue = 1f,
        animationSpec = keyframes {
            durationMillis = 1200
            0f at 0
            0f at 550
            1f at 900
        },
        label = "sparkle"
    )

    // Gentle float up/down loop
    val float by rememberInfiniteTransition(label = "float").animateFloat(
        initialValue = 0f,
        targetValue = 8f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "float"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(bgColor)
            .alpha(fadeIn),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Gift box canvas
            Canvas(
                modifier = Modifier
                    .size(160.dp)
                    .graphicsLayer { translationY = -float }
            ) {
                drawGiftBox(
                    lidOffsetPx = lidOffset * (size.height / 160f) * density,
                    sparkleAlpha = sparkle
                )
            }

            Spacer(Modifier.height(24.dp))

            Text(
                text = "GiftQuest",
                color = Color.White,
                fontSize = 32.sp,
                style = MaterialTheme.typography.headlineMedium
            )

            Spacer(Modifier.height(8.dp))

            Text(
                text = "Gift Discovery Made Easy",
                color = Color.White.copy(alpha = 0.75f),
                fontSize = 14.sp,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

private fun DrawScope.drawGiftBox(lidOffsetPx: Float, sparkleAlpha: Float) {
    val w = size.width
    val h = size.height

    val boxColor    = Color(0xFFDC2626)   // red
    val lidColor    = Color(0xFFB91C1C)   // darker red lid
    val ribbonColor = Color(0xFFFBBF24)   // gold ribbon
    val bowColor    = Color(0xFFF59E0B)   // amber bow
    val shadow      = Color(0x33000000)

    val boxLeft   = w * 0.10f
    val boxTop    = h * 0.42f
    val boxRight  = w * 0.90f
    val boxBottom = h * 0.92f
    val boxW      = boxRight - boxLeft
    val boxH      = boxBottom - boxTop

    val lidH      = h * 0.14f
    val lidTop    = boxTop + lidOffsetPx - lidH
    val lidLeft   = boxLeft - w * 0.04f
    val lidRight  = boxRight + w * 0.04f

    // Shadow under box
    drawRoundRect(
        color = shadow,
        topLeft = Offset(boxLeft + 4f, boxBottom - 6f),
        size = Size(boxW, 12f),
        cornerRadius = CornerRadius(6f)
    )

    // ── Box body ──────────────────────────────────────────────────────────────
    drawRoundRect(
        color = boxColor,
        topLeft = Offset(boxLeft, boxTop),
        size = Size(boxW, boxH),
        cornerRadius = CornerRadius(8f)
    )

    // Ribbon vertical on box
    val ribbonX = w / 2f - w * 0.06f
    val ribbonW = w * 0.12f
    drawRect(
        color = ribbonColor,
        topLeft = Offset(ribbonX, boxTop),
        size = Size(ribbonW, boxH)
    )

    // ── Lid ───────────────────────────────────────────────────────────────────
    drawRoundRect(
        color = lidColor,
        topLeft = Offset(lidLeft, lidTop),
        size = Size(lidRight - lidLeft, lidH),
        cornerRadius = CornerRadius(6f)
    )

    // Ribbon horizontal on lid
    val lidMidY = lidTop + lidH / 2f - w * 0.06f
    drawRect(
        color = ribbonColor,
        topLeft = Offset(lidLeft, lidMidY),
        size = Size(lidRight - lidLeft, ribbonW)
    )

    // ── Bow ───────────────────────────────────────────────────────────────────
    val bowCx = w / 2f
    val bowCy = lidTop - lidH * 0.1f

    // Left loop
    val leftLoop = Path().apply {
        moveTo(bowCx, bowCy)
        cubicTo(bowCx - w * 0.22f, bowCy - h * 0.12f,
            bowCx - w * 0.28f, bowCy + h * 0.04f,
            bowCx - w * 0.06f, bowCy + h * 0.02f)
        close()
    }
    drawPath(leftLoop, bowColor)

    // Right loop
    val rightLoop = Path().apply {
        moveTo(bowCx, bowCy)
        cubicTo(bowCx + w * 0.22f, bowCy - h * 0.12f,
            bowCx + w * 0.28f, bowCy + h * 0.04f,
            bowCx + w * 0.06f, bowCy + h * 0.02f)
        close()
    }
    drawPath(rightLoop, bowColor)

    // Bow knot circle
    drawCircle(color = ribbonColor, radius = w * 0.065f, center = Offset(bowCx, bowCy))

    // ── Sparkles (appear after lid lifts) ────────────────────────────────────
    if (sparkleAlpha > 0f) {
        val sparklePts = listOf(
            Offset(w * 0.20f, h * 0.18f),
            Offset(w * 0.80f, h * 0.14f),
            Offset(w * 0.88f, h * 0.32f),
            Offset(w * 0.15f, h * 0.30f),
            Offset(w * 0.50f, h * 0.10f),
        )
        val sizes = listOf(10f, 14f, 8f, 12f, 16f)
        sparklePts.forEachIndexed { i, pt ->
            drawStar(pt, sizes[i], Color.White.copy(alpha = sparkleAlpha * 0.9f))
        }
    }
}

private fun DrawScope.drawStar(center: Offset, size: Float, color: Color) {
    val stroke = Stroke(width = size * 0.25f, cap = StrokeCap.Round)
    // Horizontal line
    drawLine(color, Offset(center.x - size, center.y), Offset(center.x + size, center.y), stroke.width, StrokeCap.Round)
    // Vertical line
    drawLine(color, Offset(center.x, center.y - size), Offset(center.x, center.y + size), stroke.width, StrokeCap.Round)
    // Diagonals
    val d = size * 0.6f
    drawLine(color, Offset(center.x - d, center.y - d), Offset(center.x + d, center.y + d), stroke.width * 0.7f, StrokeCap.Round)
    drawLine(color, Offset(center.x + d, center.y - d), Offset(center.x - d, center.y + d), stroke.width * 0.7f, StrokeCap.Round)
}