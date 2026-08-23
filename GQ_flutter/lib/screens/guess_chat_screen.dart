import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../providers/guess_chat_providers.dart';
import '../providers/user_providers.dart';
import '../widgets/sticker.dart';

class GuessChatScreen extends ConsumerStatefulWidget {
  const GuessChatScreen({
    super.key,
    required this.itemId,
    required this.itemOwnerId,
  });

  final String itemId;
  final String itemOwnerId;

  @override
  ConsumerState<GuessChatScreen> createState() => _GuessChatScreenState();
}

class _GuessChatScreenState extends ConsumerState<GuessChatScreen> {
  final _inputController = TextEditingController();

  GuessChatArgs get _args =>
      (itemId: widget.itemId, itemOwnerId: widget.itemOwnerId);

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    ref.read(guessChatControllerProvider(_args).notifier).sendGuess(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(guessChatControllerProvider(_args));
    final partner =
        ref.watch(userProfileStreamProvider(widget.itemOwnerId)).value;
    final partnerName = partner?.nickname.isNotEmpty == true
        ? partner!.nickname
        : (partner?.name.isNotEmpty == true ? partner!.name : 'their');

    return Scaffold(
      appBar: AppBar(
        title: Text("Guessing $partnerName's gift"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GuessProgress(guessCount: state.guessCount),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty && state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        state.messages.length + (state.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (state.isLoading && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _ThinkingIndicator(),
                        );
                      }
                      final msgIndex =
                          state.messages.length -
                          1 -
                          (index - (state.isLoading ? 1 : 0));
                      final msg = state.messages[msgIndex];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChatBubble(message: msg),
                      );
                    },
                  ),
          ),
          if (state.gameState == GameState.won ||
              state.gameState == GameState.givenUp)
            _GameOverBanner(won: state.gameState == GameState.won, guessCount: state.guessCount)
          else if (state.gameState == GameState.alreadyPlayed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'You already played this one — ${state.guessCount} guesses.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !state.isLoading,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Ask a question...',
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StickerButton(
                      label: 'I think I know!',
                      onPressed: state.isLoading ? null : _submit,
                      expand: false,
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

class _GuessProgress extends StatelessWidget {
  const _GuessProgress({required this.guessCount});

  final int guessCount;

  static const _cap = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = guessCount.clamp(0, _cap);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _cap; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 18,
            height: 6,
            decoration: BoxDecoration(
              color: i < filled ? scheme.secondary : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        if (guessCount > _cap) ...[
          const SizedBox(width: 6),
          Text(
            '+${guessCount - _cap}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.sender == Sender.user;
    final displayText = message.text.replaceAll('CORRECT_GUESS', '').trim();

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? scheme.secondary : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
            ),
            child: Text(
              displayText,
              style: TextStyle(
                color: isUser ? scheme.onSecondary : scheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: scheme.secondary),
        ),
        const SizedBox(width: 8),
        Text(
          'thinking…',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _GameOverBanner extends StatelessWidget {
  const _GameOverBanner({required this.won, required this.guessCount});

  final bool won;
  final int guessCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: won ? scheme.secondary : scheme.errorContainer,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Text(
              won ? '🎉 You got it!' : '😅 Better luck next time!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: won ? scheme.onSecondary : scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (won) ...[
              const SizedBox(height: 4),
              Text(
                '$guessCount guesses',
                style: TextStyle(
                  color: won ? scheme.onSecondary : scheme.onErrorContainer,
                ),
              ),
            ],
            const SizedBox(height: 12),
            StickerButton(
              label: 'Back to gifts',
              onPressed: () => Navigator.of(context).pop(),
              expand: false,
              variant: StickerButtonVariant.outline,
            ),
          ],
        ),
      ),
    );
  }
}
