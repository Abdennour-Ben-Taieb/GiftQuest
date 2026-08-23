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

  /// Links two users together using a share code. Returns the partner's uid.
  Future<String> linkWithPartnerCode({
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
    batch.update(_fs.collection('users').doc(myUid), {'linkedWith': partnerUid});
    batch.update(_fs.collection('users').doc(partnerUid), {'linkedWith': myUid});
    await batch.commit();

    return partnerUid;
  }

  /// Unlinks the current user from their partner and deletes only the
  /// current user's own game results (partner's results are their own data).
  Future<void> unlinkMe(String myUid) async {
    final myDoc = await _fs.collection('users').doc(myUid).get();
    final partnerUid = myDoc.data()?['linkedWith'] as String?;

    if (partnerUid != null) {
      await _gameResultsRepo.deleteResultsForPartner(
        guesserUid: myUid,
        partnerUid: partnerUid,
      );
    }

    final batch = _fs.batch();
    batch.update(_fs.collection('users').doc(myUid), {'linkedWith': null});
    if (partnerUid != null) {
      batch.update(_fs.collection('users').doc(partnerUid), {'linkedWith': null});
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
