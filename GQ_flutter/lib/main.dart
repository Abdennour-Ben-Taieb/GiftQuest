import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GiftQuest',
      theme: buildAppTheme(),
      home: const SplashScreen(child: AuthGate()),
    );
  }
}

/// Picks the start screen once, the same way the Kotlin app's NavHost
/// chooses its startDestination from `FirebaseAuth.getInstance().currentUser`.
/// Navigation between screens afterwards is explicit (Navigator push /
/// pushAndRemoveUntil), not driven by rebuilding this gate.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.read(firebaseAuthProvider).currentUser != null;
    return isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}