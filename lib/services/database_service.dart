import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';

class DatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> saveUser({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
    required String role,
    String licenseNumber = '',
  }) async {
    debugPrint('SAVE USER STARTED');

    try {
      await _db.child('users').child(uid).set({
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'isVerified': false,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
        'profileImage': '',
        'licenseImage': '',
        'licenseNumber': licenseNumber,
      }).timeout(const Duration(seconds: 5));

      debugPrint('USER SAVED SUCCESSFULLY');
    } catch (e, stack) {
      debugPrint('DATABASE ERROR');
      debugPrint(e.toString());
      debugPrint(stack.toString());
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final snapshot = await _db.child('users').child(uid).get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return UserModel.fromMap(uid, data);
      }
    } catch (e) {
      debugPrint('Error getting user: $e');
    }
    return null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _db.child('users').child(uid).update(data).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> getUsers() async {
    List<UserModel> users = [];
    try {
      final snapshot = await _db.child('users').get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          users.add(UserModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error listing users: $e');
    }
    return users;
  }

  Future<void> verifyLicense(String uid, bool isVerified) async {
    try {
      await _db.child('users').child(uid).update({
        'isVerified': isVerified,
      }).timeout(const Duration(seconds: 5));
      
      // Seed a record in license_verifications/
      await _db.child('license_verifications').child(uid).set({
        'userId': uid,
        'status': isVerified ? 'approved' : 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error verifying license: $e');
      rethrow;
    }
  }
}
