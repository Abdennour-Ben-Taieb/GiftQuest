/// In-memory only during a guessing game — never written to Firestore.
/// Only the final GameResult is persisted once a game ends.
enum Sender { user, ai }

class ChatMessage {
  final Sender sender;
  final String text;

  const ChatMessage({required this.sender, required this.text});
}

/// `lost` covers the only way a game now ends unsuccessfully: guesses run
/// out. There's no manual "give up" — every message sent is a guess.
enum GameState { playing, won, lost, alreadyPlayed }

enum Difficulty {
  easy('Easy 🟢', 'Give generous hints readily. Confirm close guesses.'),
  medium('Medium 🟡', 'Give hints only after 3 wrong guesses. Require a reasonably specific answer to win.'),
  hard('Hard 🔴', 'Be stingy with hints. Only confirm or deny. Give a clue only after 5 wrong guesses. Require the exact item name to win.');

  final String label;
  final String promptText;
  const Difficulty(this.label, this.promptText);
}
