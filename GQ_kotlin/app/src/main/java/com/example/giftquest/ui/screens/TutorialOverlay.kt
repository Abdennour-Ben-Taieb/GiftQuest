package com.example.giftquest.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

// ─── Data ────────────────────────────────────────────────────────────────────

data class TutorialStep(
    val emoji: String,
    val title: String,
    val body: String,
    val gradientStart: Color,
    val gradientEnd: Color
)

val giftQuestTutorialSteps = listOf(
    TutorialStep(
        emoji = "🎁",
        title = "Welcome to GiftQuest!",
        body = "The gift guessing game for couples.\nNo more awkward Christmas surprises.",
        gradientStart = Color(0xFF6A11CB),
        gradientEnd = Color(0xFF2575FC)
    ),
    TutorialStep(
        emoji = "🔗",
        title = "Step 1\nLink Up",
        body = "Go to your Profile and share your GQ code with your partner. Once they enter it, you're connected.",
        gradientStart = Color(0xFFf953c6),
        gradientEnd = Color(0xFFb91d73)
    ),
    TutorialStep(
        emoji = "📝",
        title = "Step 2\nFill Your Wish List",
        body = "Add gifts you actually want. Your partner won't see the name — just that a mystery gift is waiting.",
        gradientStart = Color(0xFF11998e),
        gradientEnd = Color(0xFF38ef7d)
    ),
    TutorialStep(
        emoji = "🕵️",
        title = "Step 3\nGuess Away!",
        body = "Tap your partner's mystery gift and chat with the AI to figure out what it is. Good luck!",
        gradientStart = Color(0xFFFC4A1A),
        gradientEnd = Color(0xFFF7B733)
    )
)

// ─── Composable ──────────────────────────────────────────────────────────────

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TutorialOverlay(
    steps: List<TutorialStep> = giftQuestTutorialSteps,
    onFinish: () -> Unit
) {
    val pagerState = rememberPagerState(pageCount = { steps.size })
    val scope = rememberCoroutineScope()
    val isLastPage = pagerState.currentPage == steps.lastIndex

    // Animate the emoji bouncing in on each page
    val emojiScale by animateFloatAsState(
        targetValue = 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        )
    )

    Box(modifier = Modifier.fillMaxSize()) {

        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            val step = steps[page]

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(step.gradientStart, step.gradientEnd)
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 40.dp)
                        .padding(top = 100.dp, bottom = 180.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    // Emoji
                    Text(
                        text = step.emoji,
                        fontSize = 96.sp,
                        modifier = Modifier.scale(emojiScale)
                    )

                    Spacer(Modifier.height(40.dp))

                    // Title
                    Text(
                        text = step.title,
                        fontSize = 36.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = Color.White,
                        textAlign = TextAlign.Center,
                        lineHeight = 42.sp
                    )

                    Spacer(Modifier.height(24.dp))

                    // Body
                    Text(
                        text = step.body,
                        fontSize = 18.sp,
                        color = Color.White.copy(alpha = 0.88f),
                        textAlign = TextAlign.Center,
                        lineHeight = 26.sp
                    )
                }
            }
        }

        // ── Bottom controls ───────────────────────────────────────────────────
        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(horizontal = 32.dp)
                .padding(bottom = 56.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Page indicator dots
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                steps.forEachIndexed { i, _ ->
                    val isSelected = i == pagerState.currentPage
                    val dotWidth by animateDpAsState(
                        targetValue = if (isSelected) 28.dp else 8.dp,
                        animationSpec = spring(stiffness = Spring.StiffnessMedium)
                    )
                    Box(
                        modifier = Modifier
                            .height(8.dp)
                            .width(dotWidth)
                            .clip(CircleShape)
                            .background(
                                if (isSelected) Color.White
                                else Color.White.copy(alpha = 0.40f)
                            )
                    )
                }
            }

            Spacer(Modifier.height(32.dp))

            // Next / Get Started button
            Button(
                onClick = {
                    if (isLastPage) {
                        onFinish()
                    } else {
                        scope.launch {
                            pagerState.animateScrollToPage(pagerState.currentPage + 1)
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White,
                    contentColor = steps[pagerState.currentPage].gradientStart
                )
            ) {
                Text(
                    text = if (isLastPage) "Let's go! 🎉" else "Next",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(Modifier.height(16.dp))

            // Skip (hidden on last page)
            if (!isLastPage) {
                TextButton(onClick = onFinish) {
                    Text(
                        "Skip",
                        color = Color.White.copy(alpha = 0.70f),
                        fontSize = 15.sp
                    )
                }
            }
        }
    }
}