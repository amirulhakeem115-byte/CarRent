import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/maintenance_job_model.dart';
import 'vehicle_service.dart';
import 'notification_service.dart';

class MaintenanceService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('maintenance_jobs');

  Future<List<MaintenanceJobModel>> getMaintenanceJobs() async {
    List<MaintenanceJobModel> jobs = [];
    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 10));
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
      final key = newRef.key!;
      final newJob = MaintenanceJobModel(
        id: key,
        vehicleId: job.vehicleId,
        vehicleName: job.vehicleName,
        title: job.title,
        description: job.description,
        cost: job.cost,
        startDate: job.startDate,
        endDate: job.endDate,
        status: job.status,
        showToCustomer: job.showToCustomer,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await newRef.set(newJob.toMap()).timeout(const Duration(seconds: 10));
      await _handleStateTransition(newJob.vehicleId, newJob.vehicleName, newJob.status);
    } catch (e) {
      debugPrint('Error adding maintenance job: $e');
      rethrow;
    }
  }

  Future<void> updateMaintenanceJob(String id, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = DateTime.now().toIso8601String();
      await _db.child(id).update(data).timeout(const Duration(seconds: 10));
      
      final status = data['status'] as String?;
      final vehicleId = data['vehicleId'] as String?;
      final vehicleName = data['vehicleName'] as String?;
      if (status != null && vehicleId != null && vehicleName != null) {
        await _handleStateTransition(vehicleId, vehicleName, status);
      } else {
        final snap = await _db.child(id).get().timeout(const Duration(seconds: 5));
        if (snap.exists) {
          final val = snap.value as Map<dynamic, dynamic>;
          final vId = val['vehicleId'] as String? ?? '';
          final vName = val['vehicleName'] as String? ?? '';
          final st = val['status'] as String? ?? '';
          if (vId.isNotEmpty && st.isNotEmpty) {
            await _handleStateTransition(vId, vName, st);
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating maintenance job: $e');
      rethrow;
    }
  }

  Future<void> deleteMaintenanceJob(String id) async {
    try {
      // If we delete it, make sure the vehicle goes back to available if it was locked
      final snap = await _db.child(id).get().timeout(const Duration(seconds: 5));
      if (snap.exists) {
        final val = snap.value as Map<dynamic, dynamic>;
        final vId = val['vehicleId'] as String? ?? '';
        final st = val['status'] as String? ?? '';
        if (vId.isNotEmpty && (st == 'Scheduled' || st == 'In Progress')) {
          await VehicleService().updateVehicleStatus(vId, 'Available');
        }
      }
      await _db.child(id).remove().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error deleting maintenance job: $e');
      rethrow;
    }
  }

  Future<void> _handleStateTransition(String vehicleId, String vehicleName, String status) async {
    final vehicleService = VehicleService();
    final notificationService = NotificationService();
    
    if (status == 'Scheduled' || status == 'In Progress') {
      await vehicleService.updateVehicleStatus(vehicleId, 'Maintenance');
      await notificationService.notifyAllCustomers(
        title: 'Vehicle Unavailable',
        message: 'The vehicle $vehicleName is temporarily unavailable due to maintenance.',
        type: 'maintenance',
      );

      // Check for active/pending bookings that are affected by this maintenance
      try {
        final bookingsSnap = await FirebaseDatabase.instance.ref().child('bookings').get().timeout(const Duration(seconds: 5));
        if (bookingsSnap.exists) {
          final bookingsData = bookingsSnap.value as Map<dynamic, dynamic>;
          for (var entry in bookingsData.entries) {
            final b = entry.value as Map<dynamic, dynamic>;
            final bVehicleId = b['vehicleId'] as String?;
            final bStatus = b['status'] as String? ?? '';
            final bUserId = b['userId'] as String?;
            
            if (bVehicleId == vehicleId && bUserId != null && bUserId.isNotEmpty) {
              final isAffectedStatus = bStatus == 'pending' || bStatus == 'approved' || bStatus == 'Confirmed' || bStatus == 'ongoing' || bStatus == 'active' || bStatus == 'Pending Payment';
              if (isAffectedStatus) {
                await notificationService.createNotification(
                  userId: bUserId,
                  title: 'Vehicle Maintenance Affects Booking',
                  message: 'A scheduled maintenance on $vehicleName affects your booking (ID: ${entry.key}). Please contact support.',
                  type: 'maintenance',
                );
              }
            }
          }
        }
      } catch (err) {
        debugPrint('Error notifying affected customers: $err');
      }
    } else if (status == 'Completed' || status == 'Cancelled') {
      await vehicleService.updateVehicleStatus(vehicleId, 'Available');
      if (status == 'Completed') {
        await notificationService.notifyAllAdmins(
          title: 'Maintenance Completed',
          message: 'Maintenance for $vehicleName has been completed successfully.',
          type: 'maintenance',
          icon: '🔧',
          color: '0xFF10B981',
          relatedId: vehicleId,
          actionRoute: 'Vehicle Maintenance',
        );
      }
    }
  }
}

