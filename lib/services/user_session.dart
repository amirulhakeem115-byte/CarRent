import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'booking_lifecycle_manager.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  DatabaseReference get _db => FirebaseDatabase.instance.ref();
  
  String? _userId;
  String? _role;
  Future<String>? _roleFuture;
  
  StreamSubscription<User?>? _authSubscription;
  final StreamController<String?> _roleController = StreamController<String?>.broadcast();
  
  Stream<String?> get roleChanges => _roleController.stream;

  String? get currentRole => _role;
  String? get currentUserId => _userId;
  bool get isInitialized => _role != null;

  void initialize() {
    _authSubscription?.cancel();
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        // Clear session on logout
        _userId = null;
        _role = null;
        _roleFuture = null;
        _roleController.add(null);
        BookingLifecycleManager().stopPeriodicCheck();
        debugPrint('[UserSession] Logged out, session cleared.');
      } else {
        _userId = user.uid;
        // Fetch and cache role
        await fetchAndCacheRole(user.uid);
      }
    });
  }

  Future<String> fetchAndCacheRole(String uid) async {
    if (_role != null && _userId == uid) {
      return _role!;
    }
    
    if (_roleFuture != null && _userId == uid) {
      return _roleFuture!;
    }
    
    _userId = uid;
    _roleFuture = _fetchRoleDirectly(uid);
    return _roleFuture!;
  }

  Future<String> _fetchRoleDirectly(String uid) async {
    try {
      debugPrint('[UserSession] Fetching role once for uid: $uid');
      final snap = await _db.child('users').child(uid).child('role').get().timeout(const Duration(seconds: 15));
      if (snap.exists) {
        _role = snap.value.toString();
        debugPrint('[UserSession] Cached role: $_role');
        _roleController.add(_role);
        
        // Start BookingLifecycleManager checks
        BookingLifecycleManager().startPeriodicCheck();
        
        return _role!;
      } else {
        debugPrint('[UserSession] Role node not found in DB. Defaulting to customer.');
        _role = 'customer';
        _roleController.add(_role);
        BookingLifecycleManager().startPeriodicCheck();
        return 'customer';
      }
    } catch (e) {
      debugPrint('[UserSession] Error fetching user role: $e');
      return _role ?? 'customer';
    } finally {
      _roleFuture = null;
    }
  }

  void forceSetRole(String role, {String? uid}) {
    if (uid != null) {
      _userId = uid;
    }
    _role = role;
    _roleFuture = null;
    _roleController.add(role);
    BookingLifecycleManager().startPeriodicCheck();
    debugPrint('[UserSession] Force set role to: $role for uid: $_userId');
  }

  void clear() {
    _userId = null;
    _role = null;
    _roleFuture = null;
    debugPrint('[UserSession] Session explicitly cleared.');
  }

  void dispose() {
    _authSubscription?.cancel();
    _roleController.close();
  }
}
