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
      });

      debugPrint('USER SAVED SUCCESSFULLY');
    } catch (e, stack) {
      debugPrint('DATABASE ERROR');
      debugPrint(e.toString());
      debugPrint(stack.toString());
    }
  }

  Future<UserModel?> getUser(String uid) async {
    if (uid == 'demo_customer') {
      return UserModel(
        id: 'demo_customer',
        fullName: 'Demo Customer',
        email: 'customer@demo.com',
        phone: '+60123456789',
        role: 'customer',
        createdAt: DateTime.now().toIso8601String(),
        isVerified: true,
        licenseNumber: 'WQX123456',
        licenseImage: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&q=80&w=600',
      );
    }
    if (uid == 'demo_admin') {
      return UserModel(
        id: 'demo_admin',
        fullName: 'Demo Admin',
        email: 'admin@demo.com',
        phone: '+60111122233',
        role: 'admin',
        createdAt: DateTime.now().toIso8601String(),
        isVerified: true,
      );
    }

    try {
      final snapshot = await _db.child('users').child(uid).get();
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
      await _db.child('users').child(uid).update(data);
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> getUsers() async {
    List<UserModel> users = [];
    try {
      final snapshot = await _db.child('users').get();
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
      });
      
      // Seed a record in license_verifications/
      await _db.child('license_verifications').child(uid).set({
        'userId': uid,
        'status': isVerified ? 'approved' : 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error verifying license: $e');
      rethrow;
    }
  }
}
