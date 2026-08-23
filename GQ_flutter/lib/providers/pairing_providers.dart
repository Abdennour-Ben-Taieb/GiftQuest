import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_result.dart';
import '../repositories/game_results_repository.dart';
import '../repositories/pairing_repository.dart';
import 'auth_providers.dart';

final gameResultsRepositoryProvider = Provider<GameResultsRepository>((ref) {
  return GameResultsRepository(firestore: ref.watch(firestoreProvider));
});

final pairingRepositoryProvider = Provider<PairingRepository>((ref) {
  return PairingRepository(
    firestore: ref.watch(firestoreProvider),
    gameResultsRepo: ref.watch(gameResultsRepositoryProvider),
  );
});

/// The signed-in user's own share code, generating one on first read.
final myShareCodeProvider = FutureProvider<String>((ref) async {
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (uid == null) return '';
  return ref.watch(pairingRepositoryProvider).ensureMyShareCode(uid);
});

/// Everything the signed-in user has played against [itemOwnerId]'s gifts —
/// keyed by itemId on the Home grid to badge guessed/not-started.
final gameResultsForOwnerProvider =
    StreamProvider.family<List<GameResult>, String>((ref, itemOwnerId) {
  final guesserUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (guesserUid == null) return Stream.value(const []);
  return ref.watch(gameResultsRepositoryProvider).streamResults(
        itemOwnerId: itemOwnerId,
        guesserUid: guesserUid,
      );
});

class PairingActionState {
  const PairingActionState({this.loading = false, this.error});

  final bool loading;
  final String? error;
}

class PairingController extends Notifier<PairingActionState> {
  @override
  PairingActionState build() => const PairingActionState();

  Future<bool> linkWithPartnerCode(String code) async {
    final myUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (myUid == null) return false;
    if (code.trim().isEmpty) {
      state = const PairingActionState(error: 'Enter a code first.');
      return false;
    }

    state = const PairingActionState(loading: true);
    try {
      await ref
          .read(pairingRepositoryProvider)
          .linkWithPartnerCode(myUid: myUid, partnerCode: code.trim());
      state = const PairingActionState();
      return true;
    } catch (e) {
      state = PairingActionState(error: e.toString());
      return false;
    }
  }

  Future<void> unlink() async {
    final myUid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (myUid == null) return;
    state = const PairingActionState(loading: true);
    try {
      await ref.read(pairingRepositoryProvider).unlinkMe(myUid);
      state = const PairingActionState();
    } catch (e) {
      state = PairingActionState(error: e.toString());
    }
  }
}

final pairingControllerProvider =
    NotifierProvider<PairingController, PairingActionState>(
  PairingController.new,
);
