/// AI guessing-game tuning — mirrors the Kotlin app's GameConfig object.
class GameConfig {
  GameConfig._();

  /// Lightweight model — used only for the greeting (fast).
  static const modelGreeting = 'llama-3.1-8b-instant';

  /// Smart model — used for the actual guessing game.
  static const modelGame = 'llama-3.3-70b-versatile';

  /// Guesses allowed per wish before the reveal auto-triggers as a loss.
  /// Tweakable per the UI spec's "capped, 5 by default" resolution.
  static const maxGuesses = 5;
}
