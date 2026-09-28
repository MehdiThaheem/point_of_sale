import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // LOGIN
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential =
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return credential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // REGISTER
  Future<User?> register({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential =
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return credential.user;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // CREATE A NEW LOGIN AS ADMIN (does not sign the admin out).
  // Uses a temporary secondary Firebase app so the new account is
  // created without replacing the current admin's session.
  Future<String> createManagedUser({
    required String email,
    required String password,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      await secondaryAuth.signOut();
      return uid;
    } finally {
      await secondaryApp.delete();
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Sends a password reset link to the given email. Used by admins on the
  // Employees screen since a user's actual password can never be read back
  // (Firebase Auth only stores a hash of it, by design) — a reset link is
  // the correct, secure way to let them set a new one.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // CURRENT USER
  User? get currentUser {
    return _auth.currentUser;
  }

  // CHECK LOGIN
  bool get isLoggedIn {
    return _auth.currentUser != null;
  }
}