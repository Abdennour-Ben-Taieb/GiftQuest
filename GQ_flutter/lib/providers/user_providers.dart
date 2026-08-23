import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'auth_providers.dart';

/// Live document for any uid — used to watch both "my" profile (for
/// linkedWith/myShareCode) and the partner's profile (for their name).
final userProfileStreamProvider =
    StreamProvider.family<UserProfile?, String>((ref, uid) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
});

/// Convenience stream for the signed-in user's own profile.
final myProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
});
