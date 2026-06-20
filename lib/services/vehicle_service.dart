import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/vehicle_model.dart';

class VehicleService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('vehicles');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<VehicleModel>> getVehicles() async {
    List<VehicleModel> vehicles = [];
    try {
      final snapshot = await _db.get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          vehicles.add(VehicleModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting vehicles: $e');
    }

    if (vehicles.isEmpty) {
      vehicles = [
        VehicleModel(
          id: 'mock_v1',
          brand: 'Perodua',
          model: 'Myvi',
          year: 2023,
          plateNumber: 'VBY 4321',
          color: 'Electric Blue',
          transmission: 'Automatic',
          fuelType: 'Petrol',
          seats: 5,
          pricePerDay: 130.0,
          isAvailable: true,
          mainImage: 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
          description: 'The king of Malaysian highways. Extremely fuel efficient, spacious, and easy to park.',
          createdAt: DateTime.now().toIso8601String(),
          branchId: 'mock_b1',
          branchName: 'Kuala Lumpur',
        ),
        VehicleModel(
          id: 'mock_v2',
          brand: 'Proton',
          model: 'X50',
          year: 2022,
          plateNumber: 'WQX 9876',
          color: 'Snow White',
          transmission: 'Automatic',
          fuelType: 'Petrol',
          seats: 5,
          pricePerDay: 220.0,
          isAvailable: true,
          mainImage: 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&q=80&w=600',
          description: 'Premium compact SUV with active safety systems and powerful turbocharged performance.',
          createdAt: DateTime.now().toIso8601String(),
          branchId: 'mock_b2',
          branchName: 'Shah Alam',
        ),
        VehicleModel(
          id: 'mock_v3',
          brand: 'Toyota',
          model: 'Camry',
          year: 2021,
          plateNumber: 'BND 8888',
          color: 'Graphite Grey',
          transmission: 'Automatic',
          fuelType: 'Petrol',
          seats: 5,
          pricePerDay: 350.0,
          isAvailable: true,
          mainImage: 'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?auto=format&fit=crop&q=80&w=600',
          description: 'Executive sedan offering class-leading comfort, quietness, and luxury ride quality.',
          createdAt: DateTime.now().toIso8601String(),
          branchId: 'mock_b1',
          branchName: 'Kuala Lumpur',
        ),
        VehicleModel(
          id: 'mock_v4',
          brand: 'Honda',
          model: 'Civic',
          year: 2022,
          plateNumber: 'PPY 1212',
          color: 'Carnelian Red',
          transmission: 'Automatic',
          fuelType: 'Petrol',
          seats: 5,
          pricePerDay: 250.0,
          isAvailable: false,
          mainImage: 'https://images.unsplash.com/photo-1605559424843-9e4c228bf1c2?auto=format&fit=crop&q=80&w=600',
          description: 'Sporty sedan with VTEC Turbo, modern digital dashboard, and comfortable interior styling.',
          createdAt: DateTime.now().toIso8601String(),
          branchId: 'mock_b3',
          branchName: 'Putrajaya',
        ),
      ];
    }
    return vehicles;
  }

  Stream<List<VehicleModel>> getVehiclesStream() {
    return _db.onValue.map((event) {
      List<VehicleModel> vehicles = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          vehicles.add(VehicleModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
      return vehicles;
    });
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    try {
      final newRef = _db.push();
      await newRef.set(vehicle.toMap());
    } catch (e) {
      debugPrint('Error adding vehicle: $e');
      rethrow;
    }
  }

  Future<void> updateVehicle(String id, Map<String, dynamic> data) async {
    try {
      await _db.child(id).update(data);
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      rethrow;
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      await _db.child(id).remove();
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      rethrow;
    }
  }

  Future<void> toggleAvailability(String id, bool isAvailable) async {
    try {
      await _db.child(id).update({'isAvailable': isAvailable});
    } catch (e) {
      debugPrint('Error toggling availability: $e');
      rethrow;
    }
  }

  Future<String> uploadVehicleImage(File imageFile) async {
    try {
      final ref = _storage.ref().child('vehicles/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await ref.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading vehicle image, returning fallback: $e');
      // Return a professional stock vehicle image as a fallback
      return 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600';
    }
  }
}
