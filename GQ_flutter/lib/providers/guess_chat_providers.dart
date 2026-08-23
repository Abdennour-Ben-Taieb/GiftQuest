import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/game_config.dart';
import '../models/chat_message.dart';
import '../models/gift.dart';
import '../services/gift_context_fetcher.dart';
import '../services/groq_api_client.dart';
import 'auth_providers.dart';
import 'gifts_providers.dart';
import 'pairing_providers.dart';

typedef GuessChatArgs = ({String itemId, String itemOwnerId});

class GuessChatState {
  const GuessChatState({
    this.messages = const [],
    this.isLoading = true,
    this.gameState = GameState.playing,
    this.guessCount = 0,
    this.revealedTitle,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final GameState gameState;
  final int guessCount;
  final String? revealedTitle;

  GuessChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    GameState? gameState,
    int? guessCount,
    String? revealedTitle,
  }) {
    return GuessChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      gameState: gameState ?? this.gameState,
      guessCount: guessCount ?? this.guessCount,
      revealedTitle: revealedTitle ?? this.revealedTitle,
    );
  }
}

/// Drives a single guessing session against one of the partner's gifts.
/// Mirrors the Kotlin app's GuessChatViewModel — greeting, guess/hint loop
/// via Groq, and saving the final result. One instance per (itemId,
/// itemOwnerId) chat screen; state resets when the screen is popped
/// (autoDispose).
class GuessChatController extends Notifier<GuessChatState> {
  GuessChatController(this.args);

  final GuessChatArgs args;

  Gift? _item;
  String _enrichedContext = '';

  String get _guesserUid =>
      ref.read(firebaseAuthProvider).currentUser?.uid ?? 'anon';

  @override
  GuessChatState build() {
    Future.microtask(_load);
    return const GuessChatState(isLoading: true);
  }

  Future<void> _load() async {
    final existing = await ref
        .read(gameResultsRepositoryProvider)
        .getResultForItem(
          itemOwnerId: args.itemOwnerId,
          itemId: args.itemId,
          guesserUid: _guesserUid,
        );

    if (existing != null) {
      state = GuessChatState(
        isLoading: false,
        gameState: GameState.alreadyPlayed,
        guessCount: existing.guessCount,
      );
      return;
    }

    try {
      final gifts = await ref
          .read(giftsRepositoryProvider)
          .streamGifts(args.itemOwnerId)
          .first;
      Gift? item;
      for (final g in gifts) {
        if (g.id == args.itemId) {
          item = g;
          break;
        }
      }
      if (item == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      _item = item;

      unawaited(
        GiftContextFetcher.fetch(
          item.link,
        ).then((ctx) => _enrichedContext = ctx),
      );

      await _sendGreeting();
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _sendGreeting() async {
    state = state.copyWith(isLoading: true);
    final greeting = await GroqApiClient.call(
      systemPrompt: _greetingPrompt,
      history: const [],
      userMessage: '__START__',
      model: GameConfig.modelGreeting,
    );
    state = state.copyWith(
      isLoading: false,
      messages: [...state.messages, ChatMessage(sender: Sender.ai, text: greeting)],
    );
  }

  Future<void> sendGuess(String text) async {
    if (state.gameState != GameState.playing) return;
    final item = _item;
    if (item == null) return;

    final historyBeforeThis = state.messages;
    state = state.copyWith(
      guessCount: state.guessCount + 1,
      messages: [...state.messages, ChatMessage(sender: Sender.user, text: text)],
      isLoading: true,
    );

    final response = await GroqApiClient.call(
      systemPrompt: _gamePrompt(item),
      history: historyBeforeThis,
      userMessage: text,
      model: GameConfig.modelGame,
    );

    state = state.copyWith(
      isLoading: false,
      messages: [...state.messages, ChatMessage(sender: Sender.ai, text: response)],
    );

    if (response.toLowerCase().contains('correct_guess')) {
      state = state.copyWith(gameState: GameState.won, revealedTitle: item.title);
      await _saveResult(won: true);
    }
  }

  Future<void> giveUp() async {
    final item = _item;
    if (item == null || state.gameState != GameState.playing) return;

    final reveal = StringBuffer('The gift was: ${item.title}');
    if (item.category.isNotEmpty) reveal.write(' (${item.category})');
    if (item.price > 0) {
      reveal.write(', about €${item.price.toStringAsFixed(0)}');
    }
    if (item.link.isNotEmpty) reveal.write('\n${item.link}');

    state = state.copyWith(
      gameState: GameState.givenUp,
      revealedTitle: item.title,
      messages: [...state.messages, ChatMessage(sender: Sender.ai, text: reveal.toString())],
    );
    await _saveResult(won: false);
  }

  Future<void> _saveResult({required bool won}) async {
    try {
      await ref.read(gameResultsRepositoryProvider).saveGameResult(
            itemId: args.itemId,
            itemOwnerId: args.itemOwnerId,
            guesserUid: _guesserUid,
            guessCount: state.guessCount,
            won: won,
            difficulty: Difficulty.medium.name,
          );
    } catch (_) {
      // Matches the Kotlin app: a failed save shouldn't break the game UI.
    }
  }

  static const _greetingPrompt = '''
You are a fun, witty gift-guessing game host.
Send a short playful greeting to kick off the game in 1-2 sentences.
Do NOT mention anything about the gift. Just welcome the player warmly.
''';

  String _gamePrompt(Gift item) {
    final String priceRange;
    if (item.price <= 0) {
      priceRange = 'unknown price';
    } else if (item.price < 20) {
      priceRange = 'under €20 (inexpensive)';
    } else if (item.price < 50) {
      priceRange = '€20–50 (affordable)';
    } else if (item.price < 100) {
      priceRange = '€50–100 (moderate)';
    } else if (item.price < 200) {
      priceRange = '€100–200 (pricey)';
    } else {
      priceRange = 'over €200 (expensive)';
    }

    final revealText = StringBuffer('Your partner wished for: ${item.title}');
    if (item.price > 0) {
      revealText.write(', about €${item.price.toStringAsFixed(0)}');
    }
    if (item.link.isNotEmpty) revealText.write(' — find it here: ${item.link}');

    return '''
You are a fun, witty gift-guessing game host. Someone's partner is trying to guess a gift they wished for.

THE GIFT (SECRET — never reveal directly):
- Name: ${item.title}
- Category: ${item.category}
- Price: $priceRange
- Note: ${item.note.isEmpty ? 'none' : item.note}
$_enrichedContext
DIFFICULTY: ${Difficulty.medium.promptText}

RULES:
1. Never say the gift name or reveal it directly.
2. Answer yes/no questions truthfully but cleverly.
3. Give vague category hints when helpful.
4. Accept synonyms and close matches as correct.
5. When the partner guesses correctly, respond with:
   "CORRECT_GUESS 🎉 [fun celebration. Then: $revealText]"
6. Keep ALL responses SHORT — 1 to 2 sentences maximum.
7. Be playful and warm. This is a fun game between partners.
''';
  }
}

final guessChatControllerProvider = NotifierProvider.autoDispose
    .family<GuessChatController, GuessChatState, GuessChatArgs>(
      GuessChatController.new,
    );
