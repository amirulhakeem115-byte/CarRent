import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'booking_lifecycle_manager.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  DatabaseReference get _db => FirebaseDatabase.instance.ref();
  
  String? _userId;
  String? _role;
  UserModel? _userModel;
  Future<UserModel?>? _userFuture;
  Future<String>? _roleFuture;
  
  StreamSubscription<User?>? _authSubscription;
  final StreamController<String?> _roleController = StreamController<String?>.broadcast();
  
  Stream<String?> get roleChanges => _roleController.stream;

  String? get currentRole => _role;
  String? get currentUserId => _userId;
  UserModel? get currentUserModel => _userModel;
  bool get isInitialized => _role != null;

  void initialize() {
    _authSubscription?.cancel();
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        // Clear session on logout
        _userId = null;
        _role = null;
        _userModel = null;
        _userFuture = null;
        _roleFuture = null;
        _roleController.add(null);
        BookingLifecycleManager().stopPeriodicCheck();
        debugPrint('[UserSession] Logged out, session cleared.');
      } else {
        _userId = user.uid;
        // Fetch and cache role/user model on startup
        await fetchAndCacheUserModel(user.uid);
      }
    });
  }

  Future<UserModel?> fetchAndCacheUserModel(String uid) async {
    if (_userModel != null && _userId == uid) {
      return _userModel;
    }

    if (_userFuture != null && _userId == uid) {
      return _userFuture;
    }

    _userId = uid;
    _userFuture = _fetchUserDirectly(uid);
    return _userFuture;
  }

  Future<UserModel?> _fetchUserDirectly(String uid) async {
    try {
      debugPrint('[UserSession] Fetching full user profile once for uid: $uid');
      final snap = await _db.child('users').child(uid).get().timeout(const Duration(seconds: 15));
      if (snap.exists && snap.value != null) {
        final data = snap.value as Map<dynamic, dynamic>;
        final user = UserModel.fromMap(uid, data);
        _userModel = user;
        _role = user.role;
        _roleController.add(_role);
        
        BookingLifecycleManager().startPeriodicCheck();
        return _userModel;
      } else {
        debugPrint('[UserSession] User profile node not found in DB. Setting default customer.');
        _role = 'customer';
        _roleController.add(_role);
        BookingLifecycleManager().startPeriodicCheck();
        return null;
      }
    } catch (e) {
      debugPrint('[UserSession] Error fetching user profile: $e');
      return _userModel;
    } finally {
      _userFuture = null;
    }
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
      final user = await fetchAndCacheUserModel(uid);
      if (user != null) {
        return user.role;
      }
      return _role ?? 'customer';
    } catch (e) {
      debugPrint('[UserSession] Error fetching user role via user model: $e');
      return _role ?? 'customer';
    } finally {
      _roleFuture = null;
    }
  }

  void forceSetUser(UserModel user) {
    _userId = user.id;
    _userModel = user;
    _role = user.role;
    _roleFuture = null;
    _userFuture = null;
    _roleController.add(user.role);
    BookingLifecycleManager().startPeriodicCheck();
    debugPrint('[UserSession] Force set user and role to: ${user.role} for uid: ${user.id}');
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
    _userModel = null;
    _userFuture = null;
    _roleFuture = null;
    debugPrint('[UserSession] Session explicitly cleared.');
  }

  void dispose() {
    _authSubscription?.cancel();
    _roleController.close();
  }
}
