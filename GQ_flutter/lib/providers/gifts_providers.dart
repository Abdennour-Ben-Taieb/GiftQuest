import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gift.dart';
import '../repositories/gifts_repository.dart';
import 'auth_providers.dart';

final giftsRepositoryProvider = Provider<GiftsRepository>((ref) {
  return GiftsRepository(firestore: ref.watch(firestoreProvider));
});

/// Live gifts for the given uid, ordered by position.
final giftsStreamProvider =
    StreamProvider.family<List<Gift>, String>((ref, uid) {
  return ref.watch(giftsRepositoryProvider).streamGifts(uid);
});
