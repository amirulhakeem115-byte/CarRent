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
      final snapshot = await _db.get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          vehicles.add(VehicleModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      } else {
        // Seed default vehicles if none exist, but don't let offline/unauthorized state hang
        try {
          await seedDefaultVehicles().timeout(const Duration(seconds: 3));
          final secondSnapshot = await _db.get().timeout(const Duration(seconds: 3));
          if (secondSnapshot.exists) {
            final Map<dynamic, dynamic> secondData = secondSnapshot.value as Map<dynamic, dynamic>;
            secondData.forEach((key, value) {
              vehicles.add(VehicleModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
            });
            return vehicles;
          }
        } catch (seedError) {
          debugPrint('Failed to seed default vehicles or read after seeding: $seedError. Using local defaults.');
        }
        return getDefaultVehicles();
      }
    } catch (e) {
      debugPrint('Error getting vehicles: $e. Returning fallback vehicles.');
      return getDefaultVehicles();
    }
    return vehicles.isEmpty ? getDefaultVehicles() : vehicles;
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
      return 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600';
    }
  }

  Future<void> seedDefaultVehicles() async {
    final defaults = [
      VehicleModel(
        id: '',
        brand: 'Mercedes',
        model: 'Sedan',
        year: 2024,
        plateNumber: 'WQX 2026-A',
        color: 'Silver',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 200.0,
        isAvailable: true,
        mainImage: 'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&q=80&w=600',
        description: 'Mercedes-Benz executive luxury sedan featuring class-leading cabin quietness, advanced dual-zone climate systems, premium leather upholstery, active safety features, and a powerful M280 engine.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kuala Lumpur',
        engine: 'M280',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 92.0,
        gallery: [
          'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&q=80&w=600',
        ],
      ),
      VehicleModel(
        id: '',
        brand: 'Mercedes',
        model: 'Coupe',
        year: 2024,
        plateNumber: 'WQX 2026-B',
        color: 'Graphite Grey',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 4,
        pricePerDay: 220.0,
        isAvailable: true,
        mainImage: 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&q=80&w=600',
        description: 'Sporty Mercedes-Benz executive Coupe with a low-slung aerodynamic profile, dynamic select modes, sports exhaust, and a performance-tuned M177 turbocharged engine.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kuala Lumpur',
        engine: 'M177',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 78.0,
        gallery: [
          'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&q=80&w=600',
        ],
      ),
      VehicleModel(
        id: '',
        brand: 'Proton',
        model: 'X50',
        year: 2023,
        plateNumber: 'VBY 4321',
        color: 'Electric Blue',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 130.0,
        isAvailable: true,
        mainImage: 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
        description: 'Premium compact SUV with active safety systems and powerful turbocharged performance.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Shah Alam',
        engine: '1.5T',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 85.0,
      ),
      VehicleModel(
        id: '',
        brand: 'Perodua',
        model: 'Myvi',
        year: 2023,
        plateNumber: 'WQX 9876',
        color: 'Snow White',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 100.0,
        isAvailable: true,
        mainImage: 'https://images.unsplash.com/photo-1605559424843-9e4c228bf1c2?auto=format&fit=crop&q=80&w=600',
        description: 'The king of Malaysian highways. Extremely fuel efficient, spacious, and easy to park.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Putrajaya',
        engine: '1.3L',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 95.0,
      ),
    ];

    for (var vehicle in defaults) {
      await addVehicle(vehicle);
    }
  }

  List<VehicleModel> getDefaultVehicles() {
    return [
      VehicleModel(
        id: 'mercedes_sedan',
        brand: 'Mercedes',
        model: 'Sedan',
        year: 2024,
        plateNumber: 'WQX 2026-A',
        color: 'Silver',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 200.0,
        isAvailable: true,
        mainImage: 'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&q=80&w=600',
        description: 'Mercedes-Benz executive luxury sedan featuring class-leading cabin quietness, advanced dual-zone climate systems, premium leather upholstery, active safety features, and a powerful M280 engine.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kuala Lumpur',
        engine: 'M280',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 92.0,
        gallery: [
          'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&q=80&w=600',
        ],
      ),
      VehicleModel(
        id: 'mercedes_coupe',
        brand: 'Mercedes',
        model: 'Coupe',
        year: 2024,
        plateNumber: 'WQX 2026-B',
        color: 'Graphite Grey',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 4,
        pricePerDay: 220.0,
        isAvailable: true,
        mainImage: 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&q=80&w=600',
        description: 'Sporty Mercedes-Benz executive Coupe with a low-slung aerodynamic profile, dynamic select modes, sports exhaust, and a performance-tuned M177 turbocharged engine.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kuala Lumpur',
        engine: 'M177',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 78.0,
        gallery: [
          'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&q=80&w=600',
        ],
      ),
      VehicleModel(
        id: 'proton_x50',
        brand: 'Proton',
        model: 'X50',
        year: 2023,
        plateNumber: 'VBY 4321',
        color: 'Electric Blue',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 130.0,
        isAvailable: true,
        mainImage: 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
        description: 'Premium compact SUV with active safety systems and powerful turbocharged performance.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Shah Alam',
        engine: '1.5T',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 85.0,
      ),
      VehicleModel(
        id: 'perodua_myvi',
        brand: 'Perodua',
        model: 'Myvi',
        year: 2023,
        plateNumber: 'WQX 9876',
        color: 'Snow White',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 100.0,
        isAvailable: true,
        mainImage: 'https://images.unsplash.com/photo-1605559424843-9e4c228bf1c2?auto=format&fit=crop&q=80&w=600',
        description: 'The king of Malaysian highways. Extremely fuel efficient, spacious, and easy to park.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Putrajaya',
        engine: '1.3L',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 95.0,
      ),
    ];
  }
}
