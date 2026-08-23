/// AI guessing-game tuning — mirrors the Kotlin app's GameConfig object.
class GameConfig {
  GameConfig._();

  /// Lightweight model — used only for the greeting (fast).
  static const modelGreeting = 'llama-3.1-8b-instant';

  /// Smart model — used for the actual guessing game.
  static const modelGame = 'llama-3.3-70b-versatile';
}
