import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/branch_model.dart';
import 'notification_service.dart';

class BranchService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('branches');

  Future<List<BranchModel>> getBranches() async {
    List<BranchModel> branches = [];
    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 8));
      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            branches.add(BranchModel.fromMap(key.toString(), value));
          }
        });
      }
    } catch (e) {
      debugPrint('Error getting branches from Realtime Database: $e');
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
      final data = branch.toMap();
      data['id'] = newRef.key!;
      await newRef.set(data);

      final notificationService = NotificationService();
      await notificationService.notifyAllAdmins(
        title: 'Branch Added',
        message: 'New branch location established: ${branch.branchName}.',
        type: 'location',
        icon: '📍',
        color: '0xFFEC4899',
        relatedId: newRef.key!,
        actionRoute: 'Locations',
      );
    } catch (e) {
      debugPrint('Error adding branch: $e');
      rethrow;
    }
  }

  Future<void> updateBranch(String id, Map<String, dynamic> data) async {
    try {
      await _db.child(id).update(data);
      
      final name = data['branchName'] ?? '';
      final String desc = name.isNotEmpty ? name : 'ID: $id';

      final notificationService = NotificationService();
      await notificationService.notifyAllAdmins(
        title: 'Branch Updated',
        message: 'Branch details modified: $desc.',
        type: 'location',
        icon: '📍',
        color: '0xFFEC4899',
        relatedId: id,
        actionRoute: 'Locations',
      );
    } catch (e) {
      debugPrint('Error updating branch: $e');
      rethrow;
    }
  }

  Future<void> deleteBranch(String id) async {
    try {
      await _db.child(id).remove();

      final notificationService = NotificationService();
      await notificationService.notifyAllAdmins(
        title: 'Branch Deleted',
        message: 'Branch location closed and removed (ID: $id).',
        type: 'location',
        icon: '📍',
        color: '0xFFEF4444',
        relatedId: id,
        actionRoute: 'Locations',
      );
    } catch (e) {
      debugPrint('Error deleting branch: $e');
      rethrow;
    }
  }

  Future<void> seedDefaultBranches() async {
    final defaults = [
      BranchModel(id: '', branchName: 'Kuala Lumpur', address: 'KL Sentral Hub, Level 2, 50470 Kuala Lumpur', phone: '+603-22741234', latitude: 3.1390, longitude: 101.6869, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
      BranchModel(id: '', branchName: 'Kajang', address: 'Jalan Kajang Impian Hub, 43000 Kajang, Selangor', phone: '+603-87391234', latitude: 3.0166, longitude: 101.7916, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
      BranchModel(id: '', branchName: 'Putrajaya', address: 'Presint 1 Terminal Hub, 62000 Putrajaya', phone: '+603-88881234', latitude: 2.9264, longitude: 101.6964, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
      BranchModel(id: '', branchName: 'Shah Alam', address: 'Seksyen 7 Commercial Hub, 40000 Shah Alam, Selangor', phone: '+603-55101234', latitude: 3.0738, longitude: 101.5183, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
      BranchModel(id: '', branchName: 'Johor Bahru', address: 'Jalan Tun Abdul Razak Hub, 80000 Johor Bahru, Johor', phone: '+607-2211234', latitude: 1.4927, longitude: 103.7414, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
      BranchModel(id: '', branchName: 'Penang', address: 'Jalan Sultan Azlan Shah Hub, 11900 Bayan Lepas, Pulau Pinang', phone: '+604-6411234', latitude: 5.3528, longitude: 100.3013, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
    ];

    for (var branch in defaults) {
      await addBranch(branch);
    }
  }

  List<BranchModel> getDefaultBranches() {
    return [
      BranchModel(id: 'kl_hub', branchName: 'Kuala Lumpur', address: 'KL Sentral Hub, Level 2, 50470 Kuala Lumpur', phone: '+603-22741234', latitude: 3.1390, longitude: 101.6869, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
      BranchModel(id: 'kajang_hub', branchName: 'Kajang', address: 'Jalan Kajang Impian Hub, 43000 Kajang, Selangor', phone: '+603-87391234', latitude: 3.0166, longitude: 101.7916, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
      BranchModel(id: 'putrajaya_hub', branchName: 'Putrajaya', address: 'Presint 1 Terminal Hub, 62000 Putrajaya', phone: '+603-88881234', latitude: 2.9264, longitude: 101.6964, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
      BranchModel(id: 'shah_alam_hub', branchName: 'Shah Alam', address: 'Seksyen 7 Commercial Hub, 40000 Shah Alam, Selangor', phone: '+603-55101234', latitude: 3.0738, longitude: 101.5183, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
      BranchModel(id: 'jb_hub', branchName: 'Johor Bahru', address: 'Jalan Tun Abdul Razak Hub, 80000 Johor Bahru, Johor', phone: '+607-2211234', latitude: 1.4927, longitude: 103.7414, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
      BranchModel(id: 'penang_hub', branchName: 'Penang', address: 'Jalan Sultan Azlan Shah Hub, 11900 Bayan Lepas, Pulau Pinang', phone: '+604-6411234', latitude: 5.3528, longitude: 100.3013, operatingHours: '09:00 AM - 09:00 PM', status: 'Active'),
    ];
  }

}
