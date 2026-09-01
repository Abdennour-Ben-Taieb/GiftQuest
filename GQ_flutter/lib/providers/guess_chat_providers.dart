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
    this.item,
    this.resultId,
    this.gifted = false,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final GameState gameState;
  final int guessCount;

  /// The wish being guessed — loaded once at start, kept around so the
  /// reveal screen has the title/hint/photo without a second fetch.
  final Gift? item;

  /// The saved GameResult's doc id, once the game has ended — needed to
  /// call markGifted from the reveal screen.
  final String? resultId;
  final bool gifted;

  GuessChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    GameState? gameState,
    int? guessCount,
    Gift? item,
    String? resultId,
    bool? gifted,
  }) {
    return GuessChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      gameState: gameState ?? this.gameState,
      guessCount: guessCount ?? this.guessCount,
      item: item ?? this.item,
      resultId: resultId ?? this.resultId,
      gifted: gifted ?? this.gifted,
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

  String _enrichedContext = '';

  String get _guesserUid =>
      ref.read(firebaseAuthProvider).currentUser?.uid ?? 'anon';

  @override
  GuessChatState build() {
    Future.microtask(_load);
    return const GuessChatState(isLoading: true);
  }

  Future<void> _load() async {
    Gift? item;
    try {
      final gifts = await ref
          .read(giftsRepositoryProvider)
          .streamGifts(args.itemOwnerId)
          .first;
      for (final g in gifts) {
        if (g.id == args.itemId) {
          item = g;
          break;
        }
      }
    } catch (_) {
      // fall through — item stays null, handled below
    }

    if (item == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    state = state.copyWith(item: item);

    final existing = await ref
        .read(gameResultsRepositoryProvider)
        .getResultForItem(
          itemOwnerId: args.itemOwnerId,
          itemId: args.itemId,
          guesserUid: _guesserUid,
        );

    if (existing != null) {
      state = state.copyWith(
        isLoading: false,
        gameState: existing.won ? GameState.won : GameState.lost,
        guessCount: existing.guessCount,
        resultId: existing.id,
        gifted: existing.gifted,
      );
      return;
    }

    unawaited(
      GiftContextFetcher.fetch(
        item.link,
      ).then((ctx) => _enrichedContext = ctx),
    );

    await _sendGreeting();
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
    final item = state.item;
    if (item == null) return;

    final historyBeforeThis = state.messages;
    final newGuessCount = state.guessCount + 1;
    state = state.copyWith(
      guessCount: newGuessCount,
      messages: [...state.messages, ChatMessage(sender: Sender.user, text: text)],
      isLoading: true,
    );

    final response = await GroqApiClient.call(
      systemPrompt: _gamePrompt(item),
      history: historyBeforeThis,
      userMessage: text,
      model: GameConfig.modelGame,
    );

    final won = response.toLowerCase().contains('correct_guess');

    state = state.copyWith(
      isLoading: false,
      messages: [...state.messages, ChatMessage(sender: Sender.ai, text: response)],
    );

    if (won) {
      state = state.copyWith(gameState: GameState.won);
      final resultId = await _saveResult(won: true);
      state = state.copyWith(resultId: resultId);
    } else if (newGuessCount >= GameConfig.maxGuesses) {
      state = state.copyWith(gameState: GameState.lost);
      final resultId = await _saveResult(won: false);
      state = state.copyWith(resultId: resultId);
    }
  }

  Future<String?> _saveResult({required bool won}) async {
    try {
      return await ref.read(gameResultsRepositoryProvider).saveGameResult(
            itemId: args.itemId,
            itemOwnerId: args.itemOwnerId,
            guesserUid: _guesserUid,
            guessCount: state.guessCount,
            won: won,
            difficulty: Difficulty.medium.name,
          );
    } catch (_) {
      // Matches the Kotlin app: a failed save shouldn't break the game UI.
      return null;
    }
  }

  /// Called from the reveal screen once the guesser confirms they've
  /// actually received the physical gift.
  Future<void> markGifted() async {
    final resultId = state.resultId;
    if (resultId == null || state.gifted) return;
    try {
      await ref.read(gameResultsRepositoryProvider).markGifted(
            itemOwnerId: args.itemOwnerId,
            resultId: resultId,
          );
      state = state.copyWith(gifted: true);
    } catch (_) {
      // Leave gifted unset; the button remains tappable to retry.
    }
  }

  static const _greetingPrompt = '''
You are a fun, witty gift-guessing game host.
Send a short playful greeting to kick off the game in 1-2 sentences.
Do NOT mention anything about the gift. Just welcome the player warmly.
''';

  String _gamePrompt(Gift item) {
    // Bucket boundaries aren't currency-converted — this is fuzzy hint
    // shaping for the AI, not a financial calculation, so the same numeric
    // cutoffs apply regardless of which currency the price is denominated
    // in; only the displayed symbol changes.
    final symbol = currencyLabel(item.currency);
    final String priceRange;
    if (item.price <= 0) {
      priceRange = 'unknown price';
    } else if (item.price < 20) {
      priceRange = 'under ${symbol}20 (inexpensive)';
    } else if (item.price < 50) {
      priceRange = '${symbol}20–50 (affordable)';
    } else if (item.price < 100) {
      priceRange = '${symbol}50–100 (moderate)';
    } else if (item.price < 200) {
      priceRange = '${symbol}100–200 (pricey)';
    } else {
      priceRange = 'over ${symbol}200 (expensive)';
    }

    final revealText = StringBuffer('Your partner wished for: ${item.title}');
    if (item.price > 0) {
      revealText.write(', about $symbol${item.price.toStringAsFixed(0)}');
    }
    if (item.link.isNotEmpty) revealText.write(' — find it here: ${item.link}');

    return '''
You are a fun, witty gift-guessing game host. Someone's partner is trying to guess a gift they wished for.

THE GIFT (SECRET — never reveal directly):
- Name: ${item.title}
- Category: ${item.category}
- Price: $priceRange
- Hint (the only extra evidence you may draw on): ${item.hint.isEmpty ? 'none' : item.hint}
$_enrichedContext
DIFFICULTY: ${Difficulty.medium.promptText}

RULES:
1. Never say the gift name or reveal it directly.
2. Answer yes/no questions truthfully but cleverly, using only the hint above and the structured fields — never invent details beyond them.
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
