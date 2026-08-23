import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_hero.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/sticker.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoggedIn() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    final ok = await ref.read(loginControllerProvider.notifier).signIn(
          email,
          password,
        );
    if (ok) _onLoggedIn();
  }

  Future<void> _signInWithGoogle() async {
    final ok =
        await ref.read(loginControllerProvider.notifier).signInWithGoogle();
    if (ok) _onLoggedIn();
  }

  void _showForgotPasswordDialog() {
    final controller =
        TextEditingController(text: _emailController.text.trim());
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset password'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final email = controller.text.trim();
                Navigator.of(dialogContext).pop();
                if (email.isEmpty) return;
                await ref
                    .read(loginControllerProvider.notifier)
                    .sendPasswordReset(email);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'If an account exists for that email, a reset link has been sent.',
                    ),
                  ),
                );
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final canSubmit =
        _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          const AuthHero(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: state.loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Signing in...'),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Little surprises, big grins.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                        if (state.error != null) ...[
                          StickerCard(
                            color: scheme.errorContainer,
                            borderColor: scheme.error,
                            child: Text(
                              state.error!,
                              style: TextStyle(color: scheme.onErrorContainer),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Email'),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _submit(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        StickerButton(
                          label: 'Log In',
                          onPressed: canSubmit ? _submit : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Divider(color: scheme.outlineVariant)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'or',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                            Expanded(child: Divider(color: scheme.outlineVariant)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GoogleSignInButton(
                          onPressed: _signInWithGoogle,
                          text: 'Continue with Google',
                          enabled: !state.loading,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                              child: const Text('Sign Up'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
