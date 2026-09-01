import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/game_config.dart';
import '../models/chat_message.dart';
import '../providers/guess_chat_providers.dart';
import '../utils/date_format.dart';
import 'reveal_screen.dart';

class GuessChatScreen extends ConsumerStatefulWidget {
  const GuessChatScreen({
    super.key,
    required this.itemId,
    required this.itemOwnerId,
    this.wishLabel,
  });

  final String itemId;
  final String itemOwnerId;

  /// Anonymized label for the header before the wish is won (e.g.
  /// "wish #3") — Home knows the list position, so it passes this in.
  final String? wishLabel;

  @override
  ConsumerState<GuessChatScreen> createState() => _GuessChatScreenState();
}

class _GuessChatScreenState extends ConsumerState<GuessChatScreen> {
  final _inputController = TextEditingController();
  bool _navigated = false;

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

  void _goToReveal() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RevealScreen(args: _args)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(guessChatControllerProvider(_args), (previous, next) {
      if (next.gameState == GameState.won || next.gameState == GameState.lost) {
        _goToReveal();
      }
    });

    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(guessChatControllerProvider(_args));
    final label = widget.wishLabel ?? 'this wish';
    final createdAt = state.item?.createdAt;

    return Scaffold(
      appBar: AppBar(
        title: Text(label),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              createdAt != null
                  ? 'hidden since ${formatShortDate(createdAt)}'
                  : ' ',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _GuessCountPill(guessCount: state.guessCount)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.messages.isNotEmpty || !state.isLoading)
            const _SystemHintPill(),
          Expanded(
            child: state.messages.isEmpty && state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          if (state.gameState == GameState.playing)
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
                          hintText: 'type your guess...',
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SendButton(
                      enabled: !state.isLoading,
                      onPressed: _submit,
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

class _GuessCountPill extends StatelessWidget {
  const _GuessCountPill({required this.guessCount});

  final int guessCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '⚡ $guessCount/${GameConfig.maxGuesses}',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SystemHintPill extends StatelessWidget {
  const _SystemHintPill();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          "ask anything — I'll answer, but I won't say it outright",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed, required this.enabled});

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.5,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(Icons.send_rounded, color: scheme.onPrimary, size: 20),
          ),
        ),
      ),
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
