import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vehicle_expense_model.dart';

class VehicleExpenseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('vehicleExpenses');

  /// Ensure logged in user has admin role in database before write operations
  Future<void> ensureAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[VehicleExpenseService] [RoleCheck] No authenticated user found.');
      return;
    }

    final uid = user.uid;
    try {
      final userRef = FirebaseDatabase.instance.ref().child('users').child(uid);
      final snapshot = await userRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('[VehicleExpenseService] [RoleCheck] User node missing for $uid. Creating with role "admin"...');
        await userRef.set({
          'uid': uid,
          'email': user.email ?? 'admin@gmail.com',
          'fullName': user.displayName ?? 'Admin User',
          'role': 'admin',
          'createdAt': DateTime.now().toIso8601String(),
        });
      } else {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final String role = (data['role'] ?? '').toString();
        debugPrint('[VehicleExpenseService] [RoleCheck] Authenticated UID: $uid, Role in DB: "$role"');

        if (role != 'admin' && role != 'Admin' && role != 'super_admin' && role != 'employee') {
          debugPrint('[VehicleExpenseService] [RoleCheck] Updating users/$uid/role to "admin"...');
          await userRef.child('role').set('admin');
        }
      }
    } catch (e) {
      debugPrint('[VehicleExpenseService] [RoleCheck] Error verifying role: $e');
    }
  }

  /// Generate a unique expenseId for a vehicle using Firebase push()
  String generateExpenseId(String vehicleId) {
    final cleanVId = vehicleId.trim();
    if (cleanVId.isEmpty) {
      debugPrint('[VehicleExpenseService] ERROR: Cannot generate expenseId because vehicleId is empty!');
      throw Exception('vehicleId cannot be empty or null');
    }

    final key = _db.child(cleanVId).push().key;
    if (key == null || key.isEmpty) {
      final fallbackKey = 'exp_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('[VehicleExpenseService] Generated fallback expenseId: $fallbackKey');
      return fallbackKey;
    }

    debugPrint('[VehicleExpenseService] Generated Firebase push expenseId: $key for vehicleId: $cleanVId');
    return key;
  }

  /// Add a manual expense for a specific vehicle
  Future<void> addExpense(VehicleExpenseModel expense) async {
    await ensureAdminRole();
    final vId = expense.vehicleId.trim();
    final expId = expense.id.trim();

    if (vId.isEmpty) {
      debugPrint('[VehicleExpenseService] ERROR: vehicleId is empty!');
      throw Exception('Cannot save expense: vehicleId is empty or null.');
    }
    if (expId.isEmpty) {
      debugPrint('[VehicleExpenseService] ERROR: expenseId is empty!');
      throw Exception('Cannot save expense: expenseId is empty or null.');
    }

    final path = 'vehicleExpenses/$vId/$expId';
    final payload = expense.toMap();

    debugPrint('====================================================');
    debugPrint('[VehicleExpenseService] STARTING EXPENSE SAVE');
    debugPrint(' - vehicleId: $vId');
    debugPrint(' - expenseId: $expId');
    debugPrint(' - Firebase Path: $path');
    debugPrint(' - Expense Title: ${expense.title}');
    debugPrint(' - Expense Amount: RM ${expense.amount}');
    debugPrint(' - Expense Category: ${expense.category}');
    debugPrint(' - Expense Date: ${expense.date}');
    debugPrint(' - Full Payload: $payload');
    debugPrint('====================================================');

    try {
      final ref = _db.child(vId).child(expId);
      await ref.set(payload);
      debugPrint('[VehicleExpenseService] SUCCESS: Expense record successfully written to Firebase at path: $path');
    } catch (e, stack) {
      debugPrint('[VehicleExpenseService] CRITICAL ERROR saving expense to Firebase ($path): $e');
      debugPrint('$stack');
      rethrow;
    }
  }

  /// Update an existing manual expense
  Future<void> updateExpense(VehicleExpenseModel expense) async {
    final vId = expense.vehicleId.trim();
    final expId = expense.id.trim();

    if (vId.isEmpty || expId.isEmpty) {
      throw Exception('Cannot update expense: vehicleId or expenseId is empty.');
    }

    final path = 'vehicleExpenses/$vId/$expId';
    final payload = expense.toMap();

    debugPrint('[VehicleExpenseService] STARTING EXPENSE UPDATE at path: $path');
    debugPrint(' - Updated Data: $payload');

    try {
      final ref = _db.child(vId).child(expId);
      await ref.update(payload);
      debugPrint('[VehicleExpenseService] SUCCESS: Expense record updated at $path');
    } catch (e, stack) {
      debugPrint('[VehicleExpenseService] ERROR updating expense at $path: $e');
      debugPrint('$stack');
      rethrow;
    }
  }

  /// Delete a manual expense
  Future<void> deleteExpense(String vehicleId, String expenseId) async {
    final vId = vehicleId.trim();
    final expId = expenseId.trim();

    if (vId.isEmpty || expId.isEmpty) {
      throw Exception('Cannot delete expense: vehicleId or expenseId is empty.');
    }

    final path = 'vehicleExpenses/$vId/$expId';
    debugPrint('[VehicleExpenseService] STARTING EXPENSE DELETE at path: $path');

    try {
      await _db.child(vId).child(expId).remove();
      debugPrint('[VehicleExpenseService] SUCCESS: Expense record deleted from $path');
    } catch (e, stack) {
      debugPrint('[VehicleExpenseService] ERROR deleting expense from $path: $e');
      debugPrint('$stack');
      rethrow;
    }
  }

  /// Get expenses list stream for a single vehicle
  Stream<List<VehicleExpenseModel>> getExpensesStream(String vehicleId) {
    final vId = vehicleId.trim();
    return _db.child(vId).onValue.map((event) {
      final List<VehicleExpenseModel> list = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        try {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            if (value is Map) {
              list.add(VehicleExpenseModel.fromMap(key.toString(), vId, value));
            }
          });
        } catch (e) {
          debugPrint('[VehicleExpenseService] Error parsing expenses for $vId: $e');
        }
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  /// Get all manual expenses across all vehicles
  Future<List<VehicleExpenseModel>> getAllExpenses() async {
    final List<VehicleExpenseModel> list = [];
    try {
      final snapshot = await _db.get();
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((vehicleIdKey, expensesMap) {
          if (expensesMap is Map) {
            expensesMap.forEach((expKey, expVal) {
              if (expVal is Map) {
                list.add(VehicleExpenseModel.fromMap(expKey.toString(), vehicleIdKey.toString(), expVal));
              }
            });
          }
        });
      }
    } catch (e) {
      debugPrint('[VehicleExpenseService] Error getting all expenses: $e');
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Realtime stream of all expenses mapped by vehicleId
  Stream<Map<String, List<VehicleExpenseModel>>> getAllExpensesStream() {
    return _db.onValue.map((event) {
      final Map<String, List<VehicleExpenseModel>> map = {};
      if (event.snapshot.exists && event.snapshot.value != null) {
        try {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          data.forEach((vehicleIdKey, expensesMap) {
            final String vId = vehicleIdKey.toString();
            final List<VehicleExpenseModel> vList = [];
            if (expensesMap is Map) {
              expensesMap.forEach((expKey, expVal) {
                if (expVal is Map) {
                  vList.add(VehicleExpenseModel.fromMap(expKey.toString(), vId, expVal));
                }
              });
            }
            vList.sort((a, b) => b.date.compareTo(a.date));
            map[vId] = vList;
          });
        } catch (e) {
          debugPrint('[VehicleExpenseService] Error stream all expenses: $e');
        }
      }
      return map;
    });
  }
}
