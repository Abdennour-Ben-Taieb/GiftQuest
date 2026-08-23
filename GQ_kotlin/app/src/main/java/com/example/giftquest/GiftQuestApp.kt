package com.example.giftquest

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.giftquest.ui.screens.*
import com.example.giftquest.ui.theme.GiftQuestTheme
import com.example.giftquest.ui.update.UpdateChecker
import com.google.firebase.auth.FirebaseAuth

object Routes {
    const val LOGIN = "login"
    const val SIGN_UP = "sign_up"
    const val HOME = "home"
    const val ADD_ITEM = "add_item"
    const val EDIT_ITEM_ROUTE = "edit_item/{itemId}"
    const val PROFILE = "profile"
    const val GUESS_CHAT_ROUTE = "guess_chat/{ownerUid}/{itemId}"
    const val HER_ITEMS = "herItems"
}

@Composable
fun GiftQuestApp() {
    GiftQuestTheme {
        val nav = rememberNavController()
        val isLoggedIn = FirebaseAuth.getInstance().currentUser != null
        val start = if (isLoggedIn) Routes.HOME else Routes.LOGIN

        Surface(color = MaterialTheme.colorScheme.background) {
            UpdateChecker(currentVersion = BuildConfig.VERSION_CODE)
            NavHost(navController = nav, startDestination = start) {

                composable(Routes.LOGIN) {
                    LoginScreen(
                        onLoggedIn = {
                            nav.navigate(Routes.HOME) {
                                popUpTo(Routes.LOGIN) { inclusive = true }
                            }
                        },
                        onCreateAccount = { nav.navigate(Routes.SIGN_UP) },
                        onForgotPassword = { }
                    )
                }

                composable(Routes.SIGN_UP) {
                    SignUpScreen(
                        onBack = { nav.popBackStack() },
                        onSignedUp = {
                            nav.navigate(Routes.HOME) {
                                popUpTo(Routes.LOGIN) { inclusive = true }
                            }
                        }
                    )
                }

                composable(Routes.HOME) {
                    HomeScreen(
                        navController = nav,
                        onAddItem = { nav.navigate(Routes.ADD_ITEM) },
                        onEditItem = { itemId: String -> nav.navigate("edit_item/$itemId") },
                        onOpenGuessChat = { ownerUid: String, itemId: String ->
                            nav.navigate("guess_chat/$ownerUid/$itemId")
                        },
                        onOpenProfile = { nav.navigate(Routes.PROFILE) }
                    )
                }

                composable(Routes.ADD_ITEM) {
                    AddItemScreen(
                        itemId = null,
                        onSave = { nav.popBackStack() },
                        onBack = { nav.popBackStack() }
                    )
                }

                composable(Routes.EDIT_ITEM_ROUTE) { backStackEntry ->
                    val itemId = backStackEntry.arguments?.getString("itemId")
                    AddItemScreen(
                        itemId = itemId,
                        onSave = { nav.popBackStack() },
                        onBack = { nav.popBackStack() }
                    )
                }

                composable(Routes.HER_ITEMS) {
                    HerItemsScreen(
                        onBack = { nav.popBackStack() },
                        onGuess = { itemId: String ->
                            val currentUid = FirebaseAuth.getInstance().currentUser?.uid ?: ""
                            // partnerUid needed here — get it from homeVm if you kept it, or pass through route
                            nav.navigate("guess_chat/$currentUid/$itemId")
                        }
                    )
                }

                composable(Routes.PROFILE) {
                    ProfileScreen(
                        onBack = { nav.popBackStack() },
                        onLoggedOut = {
                            nav.navigate(Routes.LOGIN) { popUpTo(0) { inclusive = true } }
                            FirebaseAuth.getInstance().signOut()
                        },
                        onAccountDeleted = {
                            nav.navigate(Routes.LOGIN) { popUpTo(0) { inclusive = true } }
                        }
                    )
                }

                composable(Routes.GUESS_CHAT_ROUTE) { backStackEntry ->
                    val itemId = backStackEntry.arguments?.getString("itemId")
                    val ownerUid = backStackEntry.arguments?.getString("ownerUid") ?: ""
                    android.util.Log.d("GiftQuest", "Opening chat — itemId=$itemId, ownerUid=$ownerUid")
                    GuessChatScreen(
                        itemId = itemId,
                        itemOwnerId = ownerUid,
                        onBack = { nav.popBackStack() }
                    )
                }
            }
        }
    }
}