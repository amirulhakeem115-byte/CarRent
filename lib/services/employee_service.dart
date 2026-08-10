import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'notification_service.dart';

class EmployeeService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  /// Fetches all users with role 'employee' (or case-insensitively employee)
  Future<List<UserModel>> getEmployees({bool forceRefresh = false}) async {
    try {
      final allUsers = await _databaseService.getUsers(forceRefresh: forceRefresh);
      return allUsers.where((u) => u.isEmployee).toList();
    } catch (e) {
      debugPrint('[EmployeeService] Error getting employees: $e');
      rethrow;
    }
  }

  /// Realtime stream of employee users
  Stream<List<UserModel>> getEmployeesStream() {
    return _db.child('users').onValue.map((event) {
      final List<UserModel> employees = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final user = UserModel.fromMap(key.toString(), value);
            if (user.isEmployee) {
              employees.add(user);
            }
          }
        });
      }
      employees.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return employees;
    });
  }

  /// Creates a new employee account in Firebase Auth using a secondary Firebase App instance
  /// so that the current Admin login session is NOT logged out.
  Future<UserModel> createEmployee({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String? employeeId,
    String role = 'employee',
  }) async {
    debugPrint('[EmployeeService] Creating new employee: $email');

    try {
      // Initialize or get secondary Firebase App to preserve primary Auth session
      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('SecondaryEmployeeAuthApp');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryEmployeeAuthApp',
          options: Firebase.app().options,
        );
      }

      final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final UserCredential userCreds = await secondaryAuth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          )
          .timeout(const Duration(seconds: 15));

      final uid = userCreds.user!.uid;
      await secondaryAuth.signOut();

      final String finalEmpId = (employeeId != null && employeeId.trim().isNotEmpty)
          ? employeeId.trim().toUpperCase()
          : 'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final String nowStr = DateTime.now().toIso8601String();
      final String normalizedRole = role.trim().toLowerCase();

      final Map<String, dynamic> employeeMap = {
        'uid': uid,
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': normalizedRole,
        'employeeId': finalEmpId,
        'isVerified': true,
        'isActive': true,
        'accountStatus': 'Active',
        'createdAt': nowStr,
        'profileImage': '',
        'licenseStatus': 'approved',
      };

      // Save to Firebase Realtime Database node: users/{uid}
      await _db.child('users').child(uid).set(employeeMap).timeout(const Duration(seconds: 10));

      _databaseService.invalidateUsersCache();

      // Send admin notification
      try {
        await _notificationService.notifyAllAdmins(
          title: 'New Employee Account Created',
          message: 'Employee ${fullName.trim()} ($finalEmpId) account created.',
          type: 'security',
          icon: '👔',
          color: '0xFF3B82F6',
          relatedId: uid,
          actionRoute: 'Employees',
        );
      } catch (nErr) {
        debugPrint('[EmployeeService] Notification error: $nErr');
      }

      return UserModel.fromMap(uid, employeeMap);
    } on FirebaseAuthException catch (e) {
      debugPrint('[EmployeeService] FirebaseAuthException: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Failed to create employee auth account.');
    } catch (e) {
      debugPrint('[EmployeeService] Error creating employee: $e');
      rethrow;
    }
  }

  /// Updates an existing employee's details
  Future<void> updateEmployee(String uid, Map<String, dynamic> updates) async {
    try {
      _databaseService.invalidateUsersCache();
      await _db.child('users').child(uid).update(updates).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[EmployeeService] Error updating employee $uid: $e');
      rethrow;
    }
  }

  /// Activates or deactivates an employee account
  Future<void> toggleEmployeeStatus(String uid, bool isActive, String accountStatus) async {
    try {
      _databaseService.invalidateUsersCache();
      await _db.child('users').child(uid).update({
        'isActive': isActive,
        'accountStatus': accountStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[EmployeeService] Error toggling employee status $uid: $e');
      rethrow;
    }
  }

  /// Safely deletes an employee's DB record without destroying Auth session context unexpectedly
  Future<void> deleteEmployee(String uid) async {
    try {
      _databaseService.invalidateUsersCache();
      await _db.child('users').child(uid).remove().timeout(const Duration(seconds: 10));

      try {
        await _notificationService.notifyAllAdmins(
          title: 'Employee Account Removed',
          message: 'Employee record (ID: $uid) was removed from system database.',
          type: 'security',
          icon: '🗑️',
          color: '0xFFEF4444',
          relatedId: uid,
          actionRoute: 'Employees',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('[EmployeeService] Error deleting employee $uid: $e');
      rethrow;
    }
  }
}
