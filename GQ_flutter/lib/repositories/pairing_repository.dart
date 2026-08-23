import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_results_repository.dart';

class PairingRepository {
  final FirebaseFirestore _fs;
  final GameResultsRepository _gameResultsRepo;

  PairingRepository({
    FirebaseFirestore? firestore,
    GameResultsRepository? gameResultsRepo,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _gameResultsRepo = gameResultsRepo ?? GameResultsRepository();

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _fs.collection('users').doc(uid);

  /// Sends a pairing request to whoever owns [partnerCode] — marks both
  /// sides as pending rather than linking immediately, since confirmation
  /// is the partner's external action, not something this call can decide.
  /// Returns the partner's uid.
  Future<String> sendPairRequest({
    required String myUid,
    required String partnerCode,
  }) async {
    final codeDoc = await _fs.collection('shareCodes').doc(partnerCode).get();
    final partnerUid = codeDoc.data()?['uid'] as String?;

    if (partnerUid == null) {
      throw Exception('Invalid code: $partnerCode');
    }
    if (partnerUid == myUid) {
      throw Exception("You can't link with yourself!");
    }

    final batch = _fs.batch();
    batch.update(_userDoc(myUid), {'pendingPairRequestTo': partnerUid});
    batch.update(_userDoc(partnerUid), {'pendingPairRequestFrom': myUid});
    await batch.commit();

    return partnerUid;
  }

  /// Accepts an incoming request from [requesterUid] — links both accounts
  /// and clears the pending flags on both sides.
  Future<void> acceptPairRequest({
    required String myUid,
    required String requesterUid,
  }) async {
    final batch = _fs.batch();
    batch.update(_userDoc(myUid), {
      'linkedWith': requesterUid,
      'pendingPairRequestFrom': null,
    });
    batch.update(_userDoc(requesterUid), {
      'linkedWith': myUid,
      'pendingPairRequestTo': null,
    });
    await batch.commit();
  }

  /// Declines an incoming request from [requesterUid] — no link is made.
  Future<void> declinePairRequest({
    required String myUid,
    required String requesterUid,
  }) async {
    final batch = _fs.batch();
    batch.update(_userDoc(myUid), {'pendingPairRequestFrom': null});
    batch.update(_userDoc(requesterUid), {'pendingPairRequestTo': null});
    await batch.commit();
  }

  /// Cancels a request I sent that hasn't been accepted/declined yet.
  Future<void> cancelMyPendingRequest({
    required String myUid,
    required String partnerUid,
  }) async {
    final batch = _fs.batch();
    batch.update(_userDoc(myUid), {'pendingPairRequestTo': null});
    batch.update(_userDoc(partnerUid), {'pendingPairRequestFrom': null});
    await batch.commit();
  }

  /// Unlinks the current user from their partner and deletes only the
  /// current user's own game results (partner's results are their own data).
  Future<void> unlinkMe(String myUid) async {
    final myDoc = await _userDoc(myUid).get();
    final partnerUid = myDoc.data()?['linkedWith'] as String?;

    if (partnerUid != null) {
      await _gameResultsRepo.deleteResultsForPartner(
        guesserUid: myUid,
        partnerUid: partnerUid,
      );
    }

    final batch = _fs.batch();
    batch.update(_userDoc(myUid), {'linkedWith': null});
    if (partnerUid != null) {
      batch.update(_userDoc(partnerUid), {'linkedWith': null});
    }
    await batch.commit();
  }

  /// Returns the user's existing share code, or generates + saves a new one.
  Future<String> ensureMyShareCode(String myUid) async {
    final existing = await _fs
        .collection('shareCodes')
        .where('uid', isEqualTo: myUid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final code = _generateCode();
    await _fs.collection('shareCodes').doc(code).set({'uid': myUid});
    return code;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
