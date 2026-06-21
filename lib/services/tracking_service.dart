import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/tracking_model.dart';

class TrackingService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('tracking');

  // Stream location updates for a specific vehicle
  Stream<TrackingModel?> getVehicleLocationStream(String vehicleId) {
    return _db.child(vehicleId).onValue.map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return TrackingModel.fromMap(vehicleId, data);
      }
      return null;
    });
  }

  // Retrieve current static coordinates
  Future<TrackingModel?> getVehicleLocation(String vehicleId) async {
    try {
      final snapshot = await _db.child(vehicleId).get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return TrackingModel.fromMap(vehicleId, data);
      }
    } catch (e) {
      debugPrint('Error loading coordinates: $e');
    }
    // Return a default Malaysian location (KL Sentral) as fallback
    return TrackingModel(
      vehicleId: vehicleId,
      latitude: 3.1344,
      longitude: 101.6861,
      speed: 0.0,
      timestamp: DateTime.now().toIso8601String(),
    );
  }

  // Update telemetry details (used by GPS hardware trackers or simulator)
  Future<void> updateLocation(String vehicleId, double latitude, double longitude, double speed) async {
    try {
      await _db.child(vehicleId).set({
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error writing telematics updates: $e');
      rethrow;
    }
  }

  // Simulates a car route driving from Kuala Lumpur Sentral to Shah Alam Seksyen 7
  Timer startRouteSimulation(String vehicleId) {
    final List<List<double>> klToShahAlamRoute = [
      [3.1344, 101.6861], // KL Sentral
      [3.1284, 101.6701], // Mid Valley
      [3.1168, 101.6498], // PJ Asia
      [3.1044, 101.6128], // Kelana Jaya
      [3.0901, 101.5644], // Subang Jaya
      [3.0768, 101.5204], // Glenmarie
      [3.0697, 101.5037], // Batu Tiga
      [3.0733, 101.4897], // Shah Alam Town
      [3.0805, 101.4920], // Seksyen 7 Shah Alam
    ];

    int currentIndex = 0;
    return Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (currentIndex >= klToShahAlamRoute.length) {
        currentIndex = 0; // Restart path loop
      }
      final coords = klToShahAlamRoute[currentIndex];
      final speed = currentIndex == 0 || currentIndex == klToShahAlamRoute.length - 1 ? 0.0 : 80.0;
      await updateLocation(vehicleId, coords[0], coords[1], speed);
      currentIndex++;
    });
  }
}
