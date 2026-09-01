import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/gift.dart';
import '../providers/guess_chat_providers.dart';
import '../providers/user_providers.dart';
import '../theme.dart';
import '../widgets/sticker.dart';
import 'home_screen.dart';

/// Shows the outcome of a finished guessing game. Deliberately re-derives
/// everything from `guessChatControllerProvider(args)` rather than taking a
/// snapshot of fields as constructor params: when pushed via
/// `pushReplacement` straight off the chat screen it picks up that same
/// (still-alive) controller instance instantly; when opened directly from
/// Home for an already-resolved wish, a fresh instance spins up and its
/// `_load()` re-derives the same state from the saved GameResult — either
/// way the screen ends up with the same data, with no duplicated state.
class RevealScreen extends ConsumerStatefulWidget {
  const RevealScreen({super.key, required this.args});

  final GuessChatArgs args;

  @override
  ConsumerState<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends ConsumerState<RevealScreen> {
  bool _markingGifted = false;

  Future<void> _markGifted() async {
    setState(() => _markingGifted = true);
    await ref
        .read(guessChatControllerProvider(widget.args).notifier)
        .markGifted();
    if (mounted) setState(() => _markingGifted = false);
  }

  void _backToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guessChatControllerProvider(widget.args));
    final item = state.item;

    if (item == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final won = state.gameState == GameState.won;
    final scheme = Theme.of(context).colorScheme;
    final partner =
        ref.watch(userProfileStreamProvider(widget.args.itemOwnerId)).value;
    final partnerName = partner?.nickname.isNotEmpty == true
        ? partner!.nickname
        : (partner?.name.isNotEmpty == true ? partner!.name : 'your partner');

    final tint = won ? AppColors.success : scheme.error;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [tint.withValues(alpha: 0.16), scheme.surface],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                StickerOutcomeIcon(
                  icon: won ? Icons.card_giftcard_rounded : Icons.sentiment_dissatisfied_rounded,
                  tint: tint,
                  dashed: !won,
                ),
                const SizedBox(height: 24),
                Text(
                  won ? 'you got it!' : 'so close',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  won
                      ? _winFlavorText(state.guessCount, partnerName)
                      : _loseFlavorText(state.guessCount),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                _ResultCard(item: item, won: won),
                const SizedBox(height: 28),
                if (won) ...[
                  if (state.gifted)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          'marked as gifted',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    StickerButton(
                      label: 'mark as gifted',
                      isLoading: _markingGifted,
                      onPressed: _markingGifted ? null : _markGifted,
                    ),
                  const SizedBox(height: 12),
                ],
                StickerButton(
                  label: 'back to home',
                  variant: StickerButtonVariant.outline,
                  onPressed: _backToHome,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _winFlavorText(int guessCount, String partnerName) {
  final guesses = guessCount == 1 ? '1 guess' : '$guessCount guesses';
  return '$guesses. $partnerName is going to be a little annoyed.';
}

String _loseFlavorText(int guessCount) {
  return "Out of guesses after $guessCount tries — it stays a mystery. For now.";
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item, required this.won});

  final Gift item;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = item.hint.isNotEmpty
        ? item.hint.split('\n').first
        : null;

    return StickerCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              image: (item.photoUrl?.isNotEmpty ?? false)
                  ? DecorationImage(
                      image: NetworkImage(item.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: (item.photoUrl?.isNotEmpty ?? false)
                ? null
                : Icon(Icons.card_giftcard_rounded, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  won ? 'THE WISH' : 'IT WAS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
