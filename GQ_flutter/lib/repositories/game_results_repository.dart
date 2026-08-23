import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_result.dart';

class GameResultsRepository {
  final FirebaseFirestore _fs;

  GameResultsRepository({FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  /// Returns the new result's document id.
  Future<String> saveGameResult({
    required String itemId,
    required String itemOwnerId,
    required String guesserUid,
    required int guessCount,
    required bool won,
    required String difficulty,
  }) async {
    final doc = await _fs
        .collection('users')
        .doc(itemOwnerId)
        .collection('gameResults')
        .add({
      'itemId': itemId,
      'guesserUid': guesserUid,
      'guessCount': guessCount,
      'won': won,
      'difficulty': difficulty,
      'playedAt': Timestamp.fromDate(DateTime.now()),
      'gifted': false,
      'giftedAt': null,
    });
    return doc.id;
  }

  /// The guesser's saved result for a single item, or null if not played yet.
  Future<GameResult?> getResultForItem({
    required String itemOwnerId,
    required String itemId,
    required String guesserUid,
  }) async {
    final snap = await _fs
        .collection('users')
        .doc(itemOwnerId)
        .collection('gameResults')
        .where('itemId', isEqualTo: itemId)
        .where('guesserUid', isEqualTo: guesserUid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return GameResult.fromFirestore(snap.docs.first);
  }

  /// Live list of everything [guesserUid] has played against [itemOwnerId]'s
  /// gifts — used to badge the mystery-gift grid with guessed/not-started.
  Stream<List<GameResult>> streamResults({
    required String itemOwnerId,
    required String guesserUid,
  }) {
    return _fs
        .collection('users')
        .doc(itemOwnerId)
        .collection('gameResults')
        .where('guesserUid', isEqualTo: guesserUid)
        .snapshots()
        .map((snap) => snap.docs.map(GameResult.fromFirestore).toList());
  }

  /// Live list of every result recorded against [ownerUid]'s own gifts,
  /// regardless of who guessed — used to badge the owner's own Home list
  /// with "guessed by [partner]" / "gifted".
  Stream<List<GameResult>> streamAllResultsForOwner(String ownerUid) {
    return _fs
        .collection('users')
        .doc(ownerUid)
        .collection('gameResults')
        .snapshots()
        .map((snap) => snap.docs.map(GameResult.fromFirestore).toList());
  }

  /// Marks a result as gifted — guesser-driven, since they're the one who
  /// knows whether the physical gift actually changed hands.
  Future<void> markGifted({
    required String itemOwnerId,
    required String resultId,
  }) async {
    await _fs
        .collection('users')
        .doc(itemOwnerId)
        .collection('gameResults')
        .doc(resultId)
        .update({'gifted': true, 'giftedAt': Timestamp.fromDate(DateTime.now())});
  }

  /// Deletes all game results where [guesserUid] guessed [partnerUid]'s gifts.
  /// Used on unlink — mirrors PairingRepository.unlinkMe's cleanup behavior.
  Future<void> deleteResultsForPartner({
    required String guesserUid,
    required String partnerUid,
  }) async {
    final results = await _fs
        .collection('users')
        .doc(partnerUid)
        .collection('gameResults')
        .where('guesserUid', isEqualTo: guesserUid)
        .get();

    if (results.docs.isEmpty) return;

    final batch = _fs.batch();
    for (final doc in results.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
