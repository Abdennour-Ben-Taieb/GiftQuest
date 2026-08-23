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

  const GameResult({
    required this.id,
    required this.itemId,
    required this.guesserUid,
    required this.guessCount,
    required this.won,
    required this.difficulty,
    required this.playedAt,
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
    };
  }
}

DateTime _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}
