import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../services/cloudinary_service.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final googleSignInProvider =
    Provider<GoogleSignIn>((ref) => GoogleSignIn.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(firestore: ref.watch(firestoreProvider));
});

final cloudinaryServiceProvider =
    Provider<CloudinaryService>((ref) => CloudinaryService());

/// Live stream of the signed-in Firebase user (null when signed out).
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Mirrors the Kotlin app's LoginUiState / SignUpUiState.
class AuthFormState {
  const AuthFormState({this.loading = false, this.error});

  final bool loading;
  final String? error;
}

/// Saves a UserProfile for a brand-new Google sign-in, fire-and-forget —
/// matches the Kotlin app, which calls onSuccess() (navigates) before the
/// profile write resolves.
Future<void> _saveGoogleProfileIfNewUser(
  Ref ref,
  UserCredential credential,
) async {
  if (credential.additionalUserInfo?.isNewUser != true) return;
  final user = credential.user;
  if (user == null) return;

  final displayName = user.displayName ?? '';
  final nameParts = displayName.split(' ').where((p) => p.isNotEmpty);
  final nickname = nameParts.isNotEmpty ? nameParts.first : '';

  unawaited(
    ref
        .read(userRepositoryProvider)
        .saveUser(
          UserProfile(
            uid: user.uid,
            name: displayName,
            nickname: nickname,
            email: user.email ?? '',
            photoUrl: user.photoURL,
            dateOfBirth: '',
          ),
        )
        .catchError((_) {}),
  );
}

String _authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return error.message ?? 'Authentication failed';
  }
  if (error is GoogleSignInException) {
    return 'Google sign-in failed: ${error.description ?? error.code.name}';
  }
  return error.toString();
}

class LoginController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  Future<bool> signIn(String email, String password) async {
    state = const AuthFormState(loading: true);
    try {
      await ref.read(authRepositoryProvider).signIn(email, password);
      state = const AuthFormState();
      return true;
    } catch (e) {
      state = AuthFormState(error: _authErrorMessage(e));
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AuthFormState(loading: true);
    try {
      final credential =
          await ref.read(authRepositoryProvider).signInWithGoogle();
      state = const AuthFormState();
      await _saveGoogleProfileIfNewUser(ref, credential);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = const AuthFormState();
        return false;
      }
      state = AuthFormState(error: _authErrorMessage(e));
      return false;
    } catch (e) {
      state = AuthFormState(error: _authErrorMessage(e));
      return false;
    }
  }

  /// Matches Kotlin's LoginViewModel.reset(): failures are swallowed.
  Future<void> sendPasswordReset(String email) async {
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
    } catch (_) {
      // intentionally ignored
    }
  }
}

final loginControllerProvider =
    NotifierProvider<LoginController, AuthFormState>(LoginController.new);

class SignUpController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  Future<bool> signUp({
    required String name,
    required String nickname,
    required String email,
    required String password,
    required String dateOfBirth,
    XFile? photo,
  }) async {
    state = const AuthFormState(loading: true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signUp(email, password);
      final uid = authRepo.uid;
      if (uid == null) throw Exception('Signed up, but no UID');

      // Upload photo and save profile BEFORE reporting success, matching
      // the Kotlin app's SignUpViewModel.signUp().
      String? photoUrl;
      if (photo != null) {
        photoUrl = await ref.read(cloudinaryServiceProvider).uploadImage(photo);
      }

      await ref
          .read(userRepositoryProvider)
          .saveUser(
            UserProfile(
              uid: uid,
              name: name,
              nickname: nickname,
              email: email,
              photoUrl: photoUrl,
              dateOfBirth: dateOfBirth,
            ),
          );

      state = const AuthFormState();
      return true;
    } catch (e) {
      state = AuthFormState(error: _authErrorMessage(e));
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AuthFormState(loading: true);
    try {
      final credential =
          await ref.read(authRepositoryProvider).signInWithGoogle();
      state = const AuthFormState();
      await _saveGoogleProfileIfNewUser(ref, credential);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = const AuthFormState();
        return false;
      }
      state = AuthFormState(error: _authErrorMessage(e));
      return false;
    } catch (e) {
      state = AuthFormState(error: _authErrorMessage(e));
      return false;
    }
  }
}

final signUpControllerProvider =
    NotifierProvider<SignUpController, AuthFormState>(SignUpController.new);
