import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();

  static MockUser? mockUser;

  User? get currentUser => mockUser ?? _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────────────────────
  //  REGISTER
  // ─────────────────────────────────────────────────────────────
  Future<UserCredential> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String licenseNumber,
  }) async {
    debugPrint('[AUTH] REGISTER STARTED — email: $email');

    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = userCredential.user!.uid;
      debugPrint('[AUTH] REGISTER SUCCESS — uid: $uid');

      // Save user profile to Realtime Database: users/{uid}
      await _databaseService.saveUser(
        uid: uid,
        fullName: fullName,
        email: email.trim(),
        phone: phone.trim(),
        role: 'customer',
        licenseNumber: licenseNumber.trim().toUpperCase(),
      );

      debugPrint('[AUTH] USER PROFILE SAVED TO DATABASE — uid: $uid');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] REGISTER FAILED — code: ${e.code}, message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('[AUTH] REGISTER FAILED — unknown error: $e');
      throw Exception('Registration failed. Please check your connection and try again.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  LOGIN
  // ─────────────────────────────────────────────────────────────
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    debugPrint('[AUTH] AUTH STARTED — email: $email');

    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      debugPrint('[AUTH] AUTH SUCCESS — uid: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] AUTH FAILED — code: ${e.code}, message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('[AUTH] AUTH FAILED — unknown error: $e');
      throw Exception('Login failed. Please check your internet connection and try again.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  FORGOT PASSWORD
  // ─────────────────────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    debugPrint('[AUTH] RESET PASSWORD STARTED — email: $email');

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('[AUTH] RESET PASSWORD SUCCESS — email: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] RESET PASSWORD FAILED — code: ${e.code}, message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('[AUTH] RESET PASSWORD FAILED — unknown error: $e');
      throw Exception('Failed to send reset email. Please check your connection and try again.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  LOGOUT
  // ─────────────────────────────────────────────────────────────
  Future<void> logout() async {
    debugPrint('[AUTH] LOGOUT');
    mockUser = null;
    await _auth.signOut();
  }

  // ─────────────────────────────────────────────────────────────
  //  PRODUCTION-GRADE ERROR HANDLER
  //  Converts FirebaseAuthException codes → user-friendly messages
  // ─────────────────────────────────────────────────────────────
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      // ── Registration errors ──────────────────────────────────
      case 'email-already-in-use':
        return Exception(
          'An account already exists with this email address. Please log in or use a different email.',
        );
      case 'weak-password':
        return Exception(
          'Your password is too weak. Please use at least 6 characters with a mix of letters and numbers.',
        );
      case 'invalid-email':
        return Exception(
          'The email address format is invalid. Please enter a valid email.',
        );
      case 'operation-not-allowed':
        return Exception(
          'Email/Password sign-in is not enabled for this app. Please contact support.',
        );

      // ── Login errors ─────────────────────────────────────────
      case 'user-not-found':
        return Exception(
          'No account found with this email. Please register first or check your email.',
        );
      case 'wrong-password':
        return Exception(
          'Incorrect password. Please try again or use Forgot Password to reset it.',
        );
      case 'user-disabled':
        return Exception(
          'Your account has been disabled. Please contact our support team.',
        );
      case 'invalid-credential':
        // Firebase Auth v10+ merges user-not-found and wrong-password into this
        return Exception(
          'Invalid email or password. Please check your credentials and try again.',
        );

      // ── Network / rate-limit errors ──────────────────────────
      case 'network-request-failed':
        return Exception(
          'Network error. Please check your internet connection and try again.',
        );
      case 'too-many-requests':
        return Exception(
          'Too many failed attempts. Your account has been temporarily locked. Please try again in a few minutes or reset your password.',
        );

      // ── Password reset errors ────────────────────────────────
      // Note: 'user-not-found' is already handled above under login errors

      // ── API key / config errors (the 401 cause) ──────────────
      case 'api-key-not-valid.-please-pass-a-valid-api-key.':
      case 'invalid-api-key':
        return Exception(
          'Firebase configuration error. Please contact the administrator. (API key invalid)',
        );

      // ── Unknown ──────────────────────────────────────────────
      default:
        return Exception(
          e.message ?? 'An unexpected error occurred. Please try again.',
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  MOCK USER (Dev-mode bypass only — does NOT call Firebase)
// ─────────────────────────────────────────────────────────────
class MockUser implements User {
  @override
  final String uid;

  @override
  final String email;

  MockUser({required this.uid, required this.email});

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
