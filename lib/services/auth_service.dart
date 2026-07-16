import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'browser_device_info.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();

  User? get currentUser => _auth.currentUser;

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
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          )
          .timeout(const Duration(seconds: 15));

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

      try {
        final notificationService = NotificationService();
        await notificationService.notifyAllAdmins(
          title: 'New Customer Registered',
          message: '$fullName has registered.\nEmail: $email',
          type: 'customer',
          icon: '👤',
          color: '0xFF14B8A6',
          relatedId: uid,
          actionRoute: 'Customers',
        );
      } catch (err) {
        debugPrint('Failed to notify admins of registration: $err');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AUTH] REGISTER FAILED — code: ${e.code}, message: ${e.message}',
      );
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('[AUTH] REGISTER FAILED — unknown error: $e');
      throw Exception(
        'Registration failed. Please check your connection and try again.',
      );
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
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[AUTH] AUTH SUCCESS — uid: ${userCredential.user?.uid}');

      try {
        final uid = userCredential.user!.uid;
        final userModel = await _databaseService.getUser(uid);
        if (userModel != null && userModel.role == 'admin') {
          final sanitizedEmail = email
              .replaceAll('.', '_')
              .replaceAll('@', '_');
          await FirebaseDatabase.instance
              .ref()
              .child('failed_logins')
              .child(sanitizedEmail)
              .remove();

          final device = getDeviceInfo();
          final nowStr = DateFormat('dd MMM, hh:mm a').format(DateTime.now());
          final notificationService = NotificationService();
          await notificationService.notifyAllAdmins(
            title: 'System Login',
            message:
                'Administrator ${userModel.fullName} logged in.\nDevice: $device\nTime: $nowStr',
            type: 'security',
            icon: '🔒',
            color: '0xFF8B5CF6',
            relatedId: uid,
            actionRoute: 'Dashboard',
          );
        }
      } catch (err) {
        debugPrint('Failed to process admin login notification: $err');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] AUTH FAILED — code: ${e.code}, message: ${e.message}');
      recordFailedLogin(email).catchError((err) {
        debugPrint('Error recording failed login: $err');
      });
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('[AUTH] AUTH FAILED — unknown error: $e');
      throw Exception(
        'Login failed. Please check your internet connection and try again.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  GOOGLE SIGN-IN
  // ─────────────────────────────────────────────────────────────
  Future<UserCredential> signInWithGoogle() async {
    debugPrint('[AUTH] GOOGLE SIGN-IN STARTED');
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        // For Web, use Firebase Authentication popup directly
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await _auth
            .signInWithPopup(googleProvider)
            .timeout(const Duration(seconds: 60));
      } else {
        // For Android, use google_sign_in package
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google Sign-In was cancelled by the user.');
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth
            .signInWithCredential(credential)
            .timeout(const Duration(seconds: 30));
      }

      final uid = userCredential.user!.uid;
      final email = userCredential.user!.email ?? '';
      final name = userCredential.user!.displayName ?? 'Google User';
      final profilePhoto = userCredential.user!.photoURL ?? '';

      debugPrint('[AUTH] GOOGLE SIGN-IN SUCCESS — uid: $uid, email: $email');

      // Check if user already exists in database
      final existingUser = await _databaseService.getUser(uid);
      if (existingUser == null) {
        debugPrint('[AUTH] FIRST TIME GOOGLE USER, SAVING PROFILE — uid: $uid');
        // Save to Firebase Realtime Database
        // Save: uid, name, email, profilePhoto, role = customer, createdAt
        await _databaseService.saveGoogleUser(
          uid: uid,
          name: name,
          email: email,
          profilePhoto: profilePhoto,
        );

        try {
          final notificationService = NotificationService();
          await notificationService.notifyAllAdmins(
            title: 'New Customer Registered',
            message: '$name registered via Google.\nEmail: $email',
            type: 'customer',
            icon: '�',
            color: '0xFF14B8A6',
            relatedId: uid,
            actionRoute: 'Customers',
          );
        } catch (err) {
          debugPrint('Failed to notify admins of registration: $err');
        }
      } else {
        debugPrint(
          '[AUTH] EXISTING GOOGLE USER — uid: $uid, role: ${existingUser.role}',
        );
        // Loaded existing data, do not overwrite role.
      }

      // Fetch user profile again to get correct/latest role
      final finalUser = await _databaseService.getUser(uid);
      final role = finalUser?.role ?? 'customer';

      // ADD DEBUG LOGS: uid, email, role
      debugPrint('[AUTH] GOOGLE SIGN-IN DEBUG LOGS:');
      debugPrint('[AUTH]   - uid: $uid');
      debugPrint('[AUTH]   - email: $email');
      debugPrint('[AUTH]   - role: $role');

      if (role == 'admin') {
        try {
          final device = getDeviceInfo();
          final nowStr = DateFormat('dd MMM, hh:mm a').format(DateTime.now());
          final notificationService = NotificationService();
          await notificationService.notifyAllAdmins(
            title: 'System Login',
            message:
                'Administrator ${finalUser?.fullName ?? name} logged in via Google.\nDevice: $device\nTime: $nowStr',
            type: 'security',
            icon: '🔒',
            color: '0xFF8B5CF6',
            relatedId: uid,
            actionRoute: 'Dashboard',
          );
        } catch (err) {
          debugPrint('Failed to notify admin google login: $err');
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AUTH] GOOGLE SIGN-IN FAILED — code: ${e.code}, message: ${e.message}',
      );
      throw _handleAuthException(e);
    }
  }

  String getDeviceInfo() {
    if (kIsWeb) {
      return getBrowserDeviceInfo();
    } else {
      return defaultTargetPlatform.name;
    }
  }

  Future<void> recordFailedLogin(String email) async {
    try {
      final sanitizedEmail = email.replaceAll('.', '_').replaceAll('@', '_');
      final ref = FirebaseDatabase.instance
          .ref()
          .child('failed_logins')
          .child(sanitizedEmail);
      final snap = await ref.get();
      int count = 1;
      if (snap.exists) {
        final data = snap.value as Map;
        count = (data['count'] ?? 0) as int;
        count += 1;
      }
      await ref.set({
        'count': count,
        'lastAttempt': DateTime.now().toIso8601String(),
        'email': email,
      });

      if (count >= 3) {
        final notificationService = NotificationService();
        await notificationService.notifyAllAdmins(
          title: 'Failed Login Security Alert',
          message:
              'Multiple failed login attempts detected for account $email.',
          type: 'security',
          icon: '🔒',
          color: '0xFFEF4444',
          relatedId: email,
          actionRoute: 'Dashboard',
        );
        await ref.update({'count': 0});
      }
    } catch (e) {
      debugPrint('Error recording failed login: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  FORGOT PASSWORD
  // ─────────────────────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    debugPrint('[AUTH] RESET PASSWORD STARTED — email: $email');

    try {
      await _auth
          .sendPasswordResetEmail(email: email.trim())
          .timeout(const Duration(seconds: 15));
      debugPrint('[AUTH] RESET PASSWORD SUCCESS — email: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AUTH] RESET PASSWORD FAILED — code: ${e.code}, message: ${e.message}',
      );
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('[AUTH] RESET PASSWORD FAILED — unknown error: $e');
      throw Exception(
        'Failed to send reset email. Please check your connection and try again.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  LOGOUT
  // ─────────────────────────────────────────────────────────────
  Future<void> logout() async {
    debugPrint('[AUTH] LOGOUT');
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

      // ── API key / config errors ──────────────────────────────
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
