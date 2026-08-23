import 'package:cloud_firestore/cloud_firestore.dart';

/// Matches `users/{itemOwnerId}/gameResults/{id}` in Firestore.
class GameResult {
  final String id;
  final String itemId; // Firestore field name kept as "itemId" for compatibility, refers to a Gift.id
  final String guesserUid;
  final int guessCount;
  final bool won;
  final String difficulty;
  final DateTime playedAt;

  /// Set by the guesser once they've actually received the physical gift.
  /// Deliberately guesser-driven, not owner-driven: the guesser is the one
  /// who knows whether it was handed over.
  final bool gifted;
  final DateTime? giftedAt;

  const GameResult({
    required this.id,
    required this.itemId,
    required this.guesserUid,
    required this.guessCount,
    required this.won,
    required this.difficulty,
    required this.playedAt,
    this.gifted = false,
    this.giftedAt,
  });

  factory GameResult.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return GameResult(
      id: doc.id,
      itemId: data['itemId'] as String? ?? '',
      guesserUid: data['guesserUid'] as String? ?? '',
      guessCount: (data['guessCount'] as num?)?.toInt() ?? 0,
      won: data['won'] as bool? ?? false,
      difficulty: data['difficulty'] as String? ?? '',
      playedAt: _parseTimestamp(data['playedAtMillis'] ?? data['playedAt']),
      gifted: data['gifted'] as bool? ?? false,
      giftedAt: data['giftedAt'] == null ? null : _parseTimestamp(data['giftedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'guesserUid': guesserUid,
      'guessCount': guessCount,
      'won': won,
      'difficulty': difficulty,
      'playedAt': Timestamp.fromDate(playedAt),
      'gifted': gifted,
      'giftedAt': giftedAt == null ? null : Timestamp.fromDate(giftedAt!),
    };
  }
}

DateTime _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}
