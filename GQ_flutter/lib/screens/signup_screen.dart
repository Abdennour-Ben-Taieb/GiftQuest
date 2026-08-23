import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_hero.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/sticker.dart';
import 'home_screen.dart';

final _emailRegExp = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
);

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  DateTime? _dateOfBirth;
  XFile? _photo;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _nicknameController.text.trim().isNotEmpty &&
      _emailRegExp.hasMatch(_emailController.text.trim()) &&
      _passwordController.text.length >= 6 &&
      _dateOfBirth != null;

  String get _dobText {
    final dob = _dateOfBirth;
    if (dob == null) return '';
    final mm = dob.month.toString().padLeft(2, '0');
    final dd = dob.day.toString().padLeft(2, '0');
    return '${dob.year}-$mm-$dd';
  }

  void _onSignedUp() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setState(() => _photo = file);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final ok = await ref.read(signUpControllerProvider.notifier).signUp(
          name: _nameController.text.trim(),
          nickname: _nicknameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          dateOfBirth: _dobText,
          photo: _photo,
        );
    if (ok) _onSignedUp();
  }

  Future<void> _signUpWithGoogle() async {
    final ok =
        await ref.read(signUpControllerProvider.notifier).signInWithGoogle();
    if (ok) _onSignedUp();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signUpControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          AuthHero(onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'A few details and you\'re in.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: StickerAvatar(
                      image: _photo != null ? FileImage(File(_photo!.path)) : null,
                      onTap: _pickPhoto,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: StickerButton(
                      label: 'Choose Photo',
                      onPressed: _pickPhoto,
                      variant: StickerButtonVariant.outline,
                      expand: false,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(labelText: 'Nickname'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (min 6)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                          ),
                          child: Text(_dobText.isEmpty ? 'Not set' : _dobText),
                        ),
                      ),
                      const SizedBox(width: 12),
                      StickerButton(
                        label: 'Pick',
                        onPressed: _pickDateOfBirth,
                        variant: StickerButtonVariant.secondary,
                        expand: false,
                      ),
                    ],
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    StickerCard(
                      color: scheme.errorContainer,
                      borderColor: scheme.error,
                      child: Text(
                        state.error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  StickerButton(
                    label: 'Create Account',
                    onPressed: !state.loading && _canSubmit ? _submit : null,
                    isLoading: state.loading,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'or sign up with email',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GoogleSignInButton(
                    onPressed: _signUpWithGoogle,
                    text: 'Sign up with Google',
                    enabled: !state.loading,
                    isLoading: state.loading,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Log in'),
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
