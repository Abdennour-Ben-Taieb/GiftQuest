import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

/// Wraps firebase_auth (email/password) and google_sign_in (Google),
/// mirroring the Kotlin app's AuthRepository + SignUpViewModel Google flow.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleSignInInit;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Signs in with Google via Credential Manager (Android/iOS) and exchanges
  /// the ID token for a Firebase credential.
  Future<UserCredential> signInWithGoogle() async {
    _googleSignInInit ??= _googleSignIn.initialize(
      serverClientId: AppConfig.webClientId,
    );
    await _googleSignInInit;

    final GoogleSignInAccount account = await _googleSignIn.authenticate();
    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google sign-in did not return an ID token');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }
}
