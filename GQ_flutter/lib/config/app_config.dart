/// Build-time configuration, overridable via --dart-define.
///
/// Defaults match the values used by the Kotlin app (see local.properties
/// in the GiftQuest Android project) so the app works out of the box.
class AppConfig {
  static const String cloudinaryCloud = String.fromEnvironment(
    'CLOUDINARY_CLOUD',
    defaultValue: 'dyhybiueu',
  );

  static const String cloudinaryPreset = String.fromEnvironment(
    'CLOUDINARY_PRESET',
    defaultValue: 'giftquest_pfp',
  );

  static const String webClientId = String.fromEnvironment(
    'WEB_CLIENT_ID',
    defaultValue:
        '47304546314-v7c7jjv0teh1rpueihn8v9mghb47r47g.apps.googleusercontent.com',
  );

  /// Groq API key for the AI guessing game (see GroqApiClient). Unlike the
  /// values above, this is a real secret — it has no baked-in default and
  /// must be supplied via `--dart-define=GROQ_API_KEY=...` at build time.
  /// The chat screen degrades gracefully (shows an error message instead of
  /// crashing) when this is empty.
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  static bool get hasGroqApiKey => groqApiKey.isNotEmpty;
}
