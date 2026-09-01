import 'package:cloud_firestore/cloud_firestore.dart';

/// Short, curated list rather than a full ISO-4217 list — this is a
/// two-person household app, not a payments product.
const kCurrencyCodes = <String>['USD', 'EUR', 'TND', 'GBP'];

/// Display symbol/abbreviation for a currency code. Falls back to the code
/// itself for anything outside [kCurrencyCodes] (e.g. old data).
String currencyLabel(String code) {
  switch (code) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'TND':
      return 'DT';
    default:
      return code;
  }
}

/// When a wish becomes guessable by the linked partner.
enum GiftVisibility {
  /// Guessable as soon as the two accounts are paired (default).
  onPairing('onPairing'),

  /// Guessable starting on [Gift.unlockAt].
  onDate('onDate'),

  /// Stays locked until the owner manually reveals it ([Gift.revealedManually]).
  manual('manual');

  final String value;
  const GiftVisibility(this.value);

  static GiftVisibility fromValue(String? value) {
    return GiftVisibility.values.firstWhere(
      (v) => v.value == value,
      orElse: () => GiftVisibility.onPairing,
    );
  }
}

/// Matches `users/{uid}/items/{itemId}` in Firestore.
/// Renamed from Kotlin's `Item` to `Gift` for clarity in the Dart codebase —
/// the Firestore collection path itself (`items`) is unchanged for compatibility.
class Gift {
  final String id;
  final String title;
  final String category;
  final double price;

  /// ISO code, e.g. "TND" — see [kCurrencyCodes].
  final String currency;
  final String link;

  /// The only evidence the AI is allowed to draw on when giving hints —
  /// kept separate from [title] so difficulty is tunable per wish and the
  /// AI's clues never just restate the answer.
  final String hint;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double position;
  final String? photoUrl;
  final GiftVisibility visibility;
  final DateTime? unlockAt;
  final bool revealedManually;

  const Gift({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    this.currency = 'TND',
    required this.link,
    required this.hint,
    required this.createdAt,
    required this.updatedAt,
    required this.position,
    this.photoUrl,
    this.visibility = GiftVisibility.onPairing,
    this.unlockAt,
    this.revealedManually = false,
  });

  /// Whether this wish is still locked (faded, not guessable) for the
  /// partner. [isPaired] is required since `onPairing` wishes are locked
  /// until the two accounts are linked.
  bool isLocked({required bool isPaired}) {
    switch (visibility) {
      case GiftVisibility.onPairing:
        return !isPaired;
      case GiftVisibility.onDate:
        final unlock = unlockAt;
        if (unlock == null) return true;
        return DateTime.now().isBefore(unlock);
      case GiftVisibility.manual:
        return !revealedManually;
    }
  }

  factory Gift.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Gift(
      id: doc.id,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'TND',
      link: data['link'] as String? ?? '',
      hint: data['hint'] as String? ?? data['note'] as String? ?? '',
      createdAt: _parseTimestamp(data['createdAtMillis'] ?? data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAtMillis'] ?? data['updatedAt']),
      position: (data['position'] as num?)?.toDouble() ?? 0.0,
      photoUrl: data['photoUrl'] as String?,
      visibility: GiftVisibility.fromValue(data['visibility'] as String?),
      unlockAt: data['unlockAt'] == null
          ? null
          : _parseTimestamp(data['unlockAt']),
      revealedManually: data['revealedManually'] as bool? ?? false,
    );
  }

  /// Writes new records using Firestore's native Timestamp type going forward.
  /// Old records written by the Kotlin app (with createdAtMillis/updatedAtMillis
  /// as raw ints) are still readable via `_parseTimestamp` above.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'category': category,
      'price': price,
      'currency': currency,
      'link': link,
      'hint': hint,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'position': position,
      'photoUrl': photoUrl,
      'visibility': visibility.value,
      'unlockAt': unlockAt == null ? null : Timestamp.fromDate(unlockAt!),
      'revealedManually': revealedManually,
    };
  }

  Gift copyWith({
    String? title,
    String? category,
    double? price,
    String? currency,
    String? link,
    String? hint,
    double? position,
    String? photoUrl,
    GiftVisibility? visibility,
    DateTime? unlockAt,
    bool? revealedManually,
  }) {
    return Gift(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      link: link ?? this.link,
      hint: hint ?? this.hint,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      position: position ?? this.position,
      photoUrl: photoUrl ?? this.photoUrl,
      visibility: visibility ?? this.visibility,
      unlockAt: unlockAt ?? this.unlockAt,
      revealedManually: revealedManually ?? this.revealedManually,
    );
  }
}

/// Handles both the new Firestore Timestamp type and the old raw millis
/// (int) values written by the Kotlin app, so existing data keeps working.
DateTime _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}
