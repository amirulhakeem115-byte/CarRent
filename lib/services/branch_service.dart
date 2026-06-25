import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/branch_model.dart';

class BranchService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('branches');

  Future<List<BranchModel>> getBranches() async {
    List<BranchModel> branches = [];
    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          branches.add(BranchModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      } else {
        // Seed branches if none exist, but don't let offline/unauthorized state hang
        try {
          await seedDefaultBranches().timeout(const Duration(seconds: 3));
          final secondSnapshot = await _db.get().timeout(const Duration(seconds: 3));
          if (secondSnapshot.exists) {
            final Map<dynamic, dynamic> secondData = secondSnapshot.value as Map<dynamic, dynamic>;
            secondData.forEach((key, value) {
              branches.add(BranchModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
            });
            return branches;
          }
        } catch (seedError) {
          debugPrint('Failed to seed default branches or read after seeding: $seedError. Using local defaults.');
        }
        return getDefaultBranches();
      }
    } catch (e) {
      debugPrint('Error getting branches from Realtime Database: $e. Returning fallback branches.');
      return getDefaultBranches();
    }
    return branches.isEmpty ? getDefaultBranches() : branches;
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
      BranchModel(id: '', branchName: 'Kuala Lumpur', address: 'KL Sentral Hub, Level 2, 50470 Kuala Lumpur', phone: '+603-22741234', latitude: 3.1390, longitude: 101.6869, operatingHours: '09:00 AM - 09:00 PM'),
      BranchModel(id: '', branchName: 'Kajang', address: 'Jalan Kajang Impian Hub, 43000 Kajang, Selangor', phone: '+603-87391234', latitude: 3.0166, longitude: 101.7916, operatingHours: '09:00 AM - 09:00 PM'),
      BranchModel(id: '', branchName: 'Putrajaya', address: 'Presint 1 Terminal Hub, 62000 Putrajaya', phone: '+603-88881234', latitude: 2.9264, longitude: 101.6964, operatingHours: '09:00 AM - 09:00 PM'),
      BranchModel(id: '', branchName: 'Shah Alam', address: 'Seksyen 7 Commercial Hub, 40000 Shah Alam, Selangor', phone: '+603-55101234', latitude: 3.0738, longitude: 101.5183, operatingHours: '09:00 AM - 09:00 PM'),
      BranchModel(id: '', branchName: 'Johor Bahru', address: 'Jalan Tun Abdul Razak Hub, 80000 Johor Bahru, Johor', phone: '+607-2211234', latitude: 1.4927, longitude: 103.7414, operatingHours: '09:00 AM - 09:00 PM'),
      BranchModel(id: '', branchName: 'Penang', address: 'Jalan Sultan Azlan Shah Hub, 11900 Bayan Lepas, Pulau Pinang', phone: '+604-6411234', latitude: 5.3528, longitude: 100.3013, operatingHours: '09:00 AM - 09:00 PM'),
    ];

    for (var branch in defaults) {
      await addBranch(branch);
    }
  }

  List<BranchModel> getDefaultBranches() {
    return [
      BranchModel(id: 'kl_hub', branchName: 'Kuala Lumpur', address: 'KL Sentral Hub, Level 2, 50470 Kuala Lumpur', phone: '+603-22741234', latitude: 3.1390, longitude: 101.6869, operatingHours: '09:00 AM - 09:00 PM'),
      BranchModel(id: 'kajang_hub', branchName: 'Kajang', address: 'Jalan Kajang Impian Hub, 43000 Kajang, Selangor', phone: '+603-87391234', latitude: 3.0166, longitude: 101.7916, operatingHours: '09:00 AM - 09:00 PM'),
      BranchModel(id: 'putrajaya_hub', branchName: 'Putrajaya', address: 'Presint 1 Terminal Hub, 62000 Putrajaya', phone: '+603-88881234', latitude: 2.9264, longitude: 101.6964, operatingHours: '09:00 AM - 09:00 PM'),
      BranchModel(id: 'shah_alam_hub', branchName: 'Shah Alam', address: 'Seksyen 7 Commercial Hub, 40000 Shah Alam, Selangor', phone: '+603-55101234', latitude: 3.0738, longitude: 101.5183, operatingHours: '09:00 AM - 09:00 PM'),
      BranchModel(id: 'jb_hub', branchName: 'Johor Bahru', address: 'Jalan Tun Abdul Razak Hub, 80000 Johor Bahru, Johor', phone: '+607-2211234', latitude: 1.4927, longitude: 103.7414, operatingHours: '09:00 AM - 09:00 PM'),
      BranchModel(id: 'penang_hub', branchName: 'Penang', address: 'Jalan Sultan Azlan Shah Hub, 11900 Bayan Lepas, Pulau Pinang', phone: '+604-6411234', latitude: 5.3528, longitude: 100.3013, operatingHours: '09:00 AM - 09:00 PM'),
    ];
  }

}
