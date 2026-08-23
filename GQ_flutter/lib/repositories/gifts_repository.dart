import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gift.dart';

class GiftsRepository {
  final FirebaseFirestore _fs;

  GiftsRepository({FirebaseFirestore? firestore})
      : _fs = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _itemsCol(String userId) =>
      _fs.collection('users').doc(userId).collection('items');

  /// Live stream of a user's gifts, ordered by position (matches Kotlin's
  /// itemsFlow behavior).
  Stream<List<Gift>> streamGifts(String userId) {
    return _itemsCol(userId)
        .orderBy('position')
        .snapshots()
        .map((snap) => snap.docs.map(Gift.fromFirestore).toList());
  }

  Future<void> addGift({
    required String userId,
    required String title,
    required String category,
    required double price,
    required String link,
    required String note,
    String? photoUrl,
  }) async {
    final col = _itemsCol(userId);

    // Mirror Kotlin's "append to end" position logic
    final last = await col.orderBy('position', descending: true).limit(1).get();
    final nextPos = last.docs.isEmpty
        ? 0.0
        : ((last.docs.first.data()['position'] as num?)?.toDouble() ?? -1.0) + 1.0;

    final now = DateTime.now();
    await col.add({
      'title': title,
      'category': category,
      'price': price,
      'link': link,
      'note': note,
      'position': nextPos,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'photoUrl': photoUrl,
    });
  }

  Future<void> updateGift({
    required String userId,
    required String giftId,
    required String title,
    required String category,
    required double price,
    required String link,
    required String note,
    String? photoUrl,
  }) async {
    await _itemsCol(userId).doc(giftId).update({
      'title': title,
      'category': category,
      'price': price,
      'link': link,
      'note': note,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'photoUrl': photoUrl,
    });
  }

  Future<void> deleteGift({required String userId, required String giftId}) async {
    await _itemsCol(userId).doc(giftId).delete();
  }

  Future<void> reorder({required String userId, required List<String> giftIdsInOrder}) async {
    final col = _itemsCol(userId);
    final batch = _fs.batch();

    for (var i = 0; i < giftIdsInOrder.length; i++) {
      batch.update(col.doc(giftIdsInOrder[i]), {
        'position': i.toDouble(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    await batch.commit();
  }
}
