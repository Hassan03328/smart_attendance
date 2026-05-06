import 'package:firebase_auth/firebase_auth.dart';

// AuthService handles all authentication logic (login, register, logout)
class AuthService {
  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Register a new user (create account)
  Future<UserCredential> register(String email, String password) async {
    try {
      // Create user using email & password
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential; // return created user
    } on FirebaseAuthException catch (e) {
      throw e; // throw error to UI
    }
  }

  /// Sign in (login existing user)
  Future<UserCredential> signIn(String email, String password) async {
    try {
      // Login user using email & password
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential; // return logged-in user
    } on FirebaseAuthException catch (e) {
      throw e; // throw error to UI
    }
  }

  /// Sign out (logout user)
  Future<void> signOut() async {
    await _auth.signOut(); // end session
  }

  /// Get current logged-in user
  User? get currentUser => _auth.currentUser;

  /// Listen to login/logout changes (real-time)
  Stream<User?> authStateChanges() => _auth.authStateChanges();
}