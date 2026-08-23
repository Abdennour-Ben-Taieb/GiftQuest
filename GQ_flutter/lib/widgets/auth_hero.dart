import 'package:flutter/material.dart';

/// Purple hero panel with the Fredoka "GiftQuest" wordmark, shared by the
/// login and sign-up screens.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key, this.onBack});

  /// When provided, shows a back button over the hero instead of just the
  /// wordmark (used by the sign-up screen, which is pushed on top of login).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'GiftQuest',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.displayMedium?.copyWith(color: scheme.onPrimary),
              ),
            ),
            if (onBack != null)
              Positioned(
                left: 4,
                child: IconButton(
                  onPressed: onBack,
                  icon: Icon(Icons.arrow_back, color: scheme.onPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
