import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/maintenance_job_model.dart';

class MaintenanceService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('maintenance_jobs');

  Future<List<MaintenanceJobModel>> getMaintenanceJobs() async {
    List<MaintenanceJobModel> jobs = [];
    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          jobs.add(MaintenanceJobModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting maintenance jobs: $e');
    }
    return jobs;
  }

  Stream<List<MaintenanceJobModel>> getMaintenanceJobsStream() {
    return _db.onValue.map((event) {
      List<MaintenanceJobModel> jobs = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          jobs.add(MaintenanceJobModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
      return jobs;
    });
  }

  Future<void> addMaintenanceJob(MaintenanceJobModel job) async {
    try {
      final newRef = _db.push();
      await newRef.set(job.toMap());
    } catch (e) {
      debugPrint('Error adding maintenance job: $e');
      rethrow;
    }
  }

  Future<void> updateMaintenanceJob(String id, Map<String, dynamic> data) async {
    try {
      await _db.child(id).update(data);
    } catch (e) {
      debugPrint('Error updating maintenance job: $e');
      rethrow;
    }
  }

  Future<void> deleteMaintenanceJob(String id) async {
    try {
      await _db.child(id).remove();
    } catch (e) {
      debugPrint('Error deleting maintenance job: $e');
      rethrow;
    }
  }
}
