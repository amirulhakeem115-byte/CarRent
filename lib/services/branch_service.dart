import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/branch_model.dart';

class BranchService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('branches');

  Future<List<BranchModel>> getBranches() async {
    List<BranchModel> branches = [];
    try {
       final snapshot = await _db.get();
       if (snapshot.exists) {
         final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
         data.forEach((key, value) {
           branches.add(BranchModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
         });
       } else {
         // Seed branches if none exist
         await seedDefaultBranches();
         return getBranches();
       }
    } catch (e) {
      debugPrint('Error getting branches: $e');
    }

    if (branches.isEmpty) {
      branches = [
        BranchModel(id: 'mock_b1', name: 'Kuala Lumpur', address: 'KL Sentral, 50470 Kuala Lumpur', phone: '+603-22741234'),
        BranchModel(id: 'mock_b2', name: 'Shah Alam', address: 'Seksyen 7, 40000 Shah Alam, Selangor', phone: '+603-55101234'),
        BranchModel(id: 'mock_b3', name: 'Putrajaya', address: 'Presint 1, 62000 Putrajaya', phone: '+603-88881234'),
        BranchModel(id: 'mock_b4', name: 'Kajang', address: 'Jalan Kajang Impian, 43000 Kajang, Selangor', phone: '+603-87391234'),
      ];
    }
    return branches;
  }

  Stream<List<BranchModel>> getBranchesStream() {
    return _db.onValue.map((event) {
      List<BranchModel> branches = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          branches.add(BranchModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
      return branches;
    });
  }

  Future<void> addBranch(BranchModel branch) async {
    try {
      final newRef = _db.push();
      await newRef.set(branch.toMap());
    } catch (e) {
      debugPrint('Error adding branch: $e');
      rethrow;
    }
  }

  Future<void> updateBranch(String id, Map<String, dynamic> data) async {
    try {
      await _db.child(id).update(data);
    } catch (e) {
      debugPrint('Error updating branch: $e');
      rethrow;
    }
  }

  Future<void> deleteBranch(String id) async {
    try {
      await _db.child(id).remove();
    } catch (e) {
      debugPrint('Error deleting branch: $e');
      rethrow;
    }
  }

  Future<void> seedDefaultBranches() async {
    final defaults = [
      BranchModel(id: '', name: 'Kajang', address: 'Jalan Kajang Impian, 43000 Kajang, Selangor', phone: '+603-87391234'),
      BranchModel(id: '', name: 'Kuala Lumpur', address: 'KL Sentral, 50470 Kuala Lumpur', phone: '+603-22741234'),
      BranchModel(id: '', name: 'Putrajaya', address: 'Presint 1, 62000 Putrajaya', phone: '+603-88881234'),
      BranchModel(id: '', name: 'Shah Alam', address: 'Seksyen 7, 40000 Shah Alam, Selangor', phone: '+603-55101234'),
    ];

    for (var branch in defaults) {
      await addBranch(branch);
    }
  }
}
