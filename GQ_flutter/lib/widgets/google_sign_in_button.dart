import 'package:flutter/material.dart';

import 'sticker.dart';

/// Google sign-in action, styled as a secondary sticker-shadow button so it
/// sits under the primary CTA per the Sunset Pop design.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.text = 'Continue with Google',
    this.enabled = true,
    this.isLoading = false,
  });

  final VoidCallback onPressed;
  final String text;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return StickerButton(
      label: text,
      onPressed: enabled ? onPressed : null,
      isLoading: isLoading,
      variant: StickerButtonVariant.outline,
      icon: Text(
        'G',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}
