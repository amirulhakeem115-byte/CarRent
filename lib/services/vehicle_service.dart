import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vehicle_model.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';
import 'booking_lifecycle_manager.dart';
import 'user_role_cache.dart';

class VehicleService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child(
    'vehicles',
  );

  // Cache to track manually updated vehicles
  final Set<String> _manuallyUpdatedVehicleIds = {};

  Future<List<VehicleModel>> getVehicles({bool applyStatusSync = false}) async {
    // Run lifecycle manager check asynchronously in the background
    BookingLifecycleManager().checkAndProcessLifecycle().catchError((lifecycleErr) {
      debugPrint(
        '[VehicleService] Warning: background lifecycle check failed: $lifecycleErr',
      );
    });

    List<VehicleModel> vehicles = [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    String currentRole = 'unknown';
    if (currentUid != null) {
      currentRole = await UserRoleCache.getRole(currentUid);
    }
    debugPrint('[VehicleService] [getVehicles] Accessing path: vehicles');
    debugPrint(
      '[VehicleService] [getVehicles] Current UID: $currentUid, Current Role: $currentRole',
    );

    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 8));
      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            vehicles.add(VehicleModel.fromMap(key.toString(), value));
          }
        });
      }

      if (applyStatusSync) {
        // Fetch bookings to determine dynamic availability
        final bookingsSnap = await FirebaseDatabase.instance
            .ref()
            .child('bookings')
            .get()
            .timeout(const Duration(seconds: 8));
        List<BookingModel> allBookings = [];
        if (bookingsSnap.exists && bookingsSnap.value != null) {
          final Map<dynamic, dynamic> data =
              bookingsSnap.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            try {
              allBookings.add(
                BookingModel.fromMap(
                  key.toString(),
                  value as Map<dynamic, dynamic>,
                ),
              );
            } catch (e) {
              debugPrint('Error parsing booking in sync: $e');
            }
          });
        }

        final now = DateTime.now();
        for (int i = 0; i < vehicles.length; i++) {
          final vehicle = vehicles[i];

          // CRITICAL: Skip ALL auto-sync for manually updated vehicles
          if (_manuallyUpdatedVehicleIds.contains(vehicle.id)) {
            debugPrint(
              '[VehicleService] Skipping ALL auto-sync for manually updated vehicle: ${vehicle.id} (Status: ${vehicle.status})',
            );
            continue;
          }

          // Skip sync for special statuses (Maintenance, Inactive, etc.)
          if (vehicle.status != 'Available' && vehicle.status != 'Booked') {
            continue;
          }

          final hasActiveBooking = allBookings.any((booking) {
            if (booking.vehicleId != vehicle.id) return false;
            final s = booking.status.toLowerCase();
            if (s == 'completed' || s == 'cancelled' || s == 'rejected') {
              return false;
            }

            // Explicitly active or overdue rentals
            if (s == 'active' || s == 'ongoing' || s == 'overdue') {
              return true;
            }

            // Reservations within 12h window
            return booking.pickUpDate.isBefore(
                  now.add(const Duration(hours: 12)),
                ) &&
                (booking.returnDate == null ||
                    now.isBefore(booking.returnDate!));
          });

          // Only perform safe cleanup: Booked -> Available if no active booking
          String targetStatus = vehicle.status;
          if (vehicle.status == 'Booked' && !hasActiveBooking) {
            targetStatus = 'Available';
          }
          final bool isAvailable = (targetStatus == 'Available');

          if (vehicle.status != targetStatus ||
              vehicle.isAvailable != isAvailable) {
            vehicles[i] = vehicle.copyWith(
              status: targetStatus,
              isAvailable: isAvailable,
            );
            if (currentRole == 'admin') {
              try {
                await _db.child(vehicle.id).update({
                  'status': targetStatus,
                  'isAvailable': isAvailable,
                });
              } catch (e) {
                debugPrint(
                  'Error updating synced status for vehicle ${vehicle.id}: $e',
                );
              }
            }
          }
            }
          }
        }
      }

      debugPrint(
        '[VehicleService] [getVehicles] Vehicles count loaded: ${vehicles.length}',
      );
    } catch (e) {
      debugPrint('[VehicleService] [getVehicles] Error getting vehicles: $e');
    }
    return vehicles;
  }

  Stream<List<VehicleModel>> getVehiclesStream() {
    final bookingsDb = FirebaseDatabase.instance.ref().child('bookings');
    final controller = StreamController<List<VehicleModel>>.broadcast();

    StreamSubscription? vehiclesSub;
    StreamSubscription? bookingsSub;

    Map<String, VehicleModel> latestVehicles = {};
    Map<String, BookingModel> latestBookings = {};

    void updateAndEmit() {
      if (controller.isClosed) return;

      final now = DateTime.now();
      final List<VehicleModel> syncedVehicles = [];
      latestVehicles.forEach((vehicleId, vehicle) {
        // CRITICAL: Skip ALL auto-sync for manually updated vehicles
        if (_manuallyUpdatedVehicleIds.contains(vehicleId)) {
          debugPrint(
            '[VehicleService] Stream skipping ALL auto-sync for manually updated vehicle: $vehicleId (Status: ${vehicle.status})',
          );
          syncedVehicles.add(vehicle);
          return;
        }

        // Skip sync for special statuses
        if (vehicle.status != 'Available' && vehicle.status != 'Booked') {
          syncedVehicles.add(vehicle);
          return;
        }

        final hasActiveBooking = latestBookings.values.any((booking) {
          if (booking.vehicleId != vehicle.id) {
            return false;
          }
          final s = booking.status.toLowerCase();
          if (s == 'completed' || s == 'cancelled' || s == 'rejected') {
            return false;
          }

          if (s == 'active' || s == 'ongoing' || s == 'overdue') {
            return true;
          }

          return booking.pickUpDate.isBefore(
                now.add(const Duration(hours: 12)),
              ) &&
              (booking.returnDate == null || now.isBefore(booking.returnDate!));
        });
        // Only perform safe cleanup: Booked -> Available if no active booking
        String targetStatus = vehicle.status;
        if (vehicle.status == 'Booked' && !hasActiveBooking) {
          targetStatus = 'Available';
        }
        final bool isAvailable = (targetStatus == 'Available');

        VehicleModel finalVehicle = vehicle;
        if (vehicle.status != targetStatus ||
            vehicle.isAvailable != isAvailable) {
          finalVehicle = vehicle.copyWith(
            status: targetStatus,
            isAvailable: isAvailable,
          );
        }

        syncedVehicles.add(finalVehicle);
      });

      controller.add(syncedVehicles);
    }

    vehiclesSub = _db.onValue.listen((event) {
      latestVehicles.clear();
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            latestVehicles[key.toString()] = VehicleModel.fromMap(
              key.toString(),
              value,
            );
          }
        });
      }
      updateAndEmit();
    });

    bookingsSub = bookingsDb.onValue.listen((event) {
      latestBookings.clear();
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            latestBookings[key.toString()] = BookingModel.fromMap(
              key.toString(),
              value,
            );
          }
        });
      }
      updateAndEmit();
    });

    controller.onCancel = () {
      vehiclesSub?.cancel();
      bookingsSub?.cancel();
    };

    return controller.stream;
  }

  Future<void> addVehicle(VehicleModel vehicle) async {
    try {
      final newRef = _db.push();
      final data = vehicle.toMap();
      data['id'] = newRef.key!;
      await newRef.set(data);

      final notificationService = NotificationService();
      await notificationService.notifyAllAdmins(
        title: 'Vehicle Added',
        message:
            'New vehicle registered: ${vehicle.brand} ${vehicle.model} (${vehicle.plateNumber}).',
        type: 'vehicle',
        icon: '🚗',
        color: '0xFF3B82F6',
        relatedId: newRef.key!,
        actionRoute: 'Cars',
      );
    } catch (e) {
      debugPrint('Error adding vehicle: $e');
      rethrow;
    }
  }

  Future<void> updateVehicle(String id, Map<String, dynamic> data) async {
    try {
      await _db.child(id).update(data);

      final brand = data['brand'] ?? '';
      final model = data['model'] ?? '';
      final plate = data['plateNumber'] ?? '';
      final String desc = (brand.isNotEmpty || model.isNotEmpty)
          ? '$brand $model ($plate)'
          : 'ID: $id';

      final notificationService = NotificationService();
      await notificationService.notifyAllAdmins(
        title: 'Vehicle Updated',
        message: 'Vehicle information modified: $desc.',
        type: 'vehicle',
        icon: '🚗',
        color: '0xFF3B82F6',
        relatedId: id,
        actionRoute: 'Cars',
      );
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      rethrow;
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      await _db.child(id).remove();

      final notificationService = NotificationService();
      await notificationService.notifyAllAdmins(
        title: 'Vehicle Deleted',
        message:
            'Vehicle was permanently removed from the fleet register (ID: $id).',
        type: 'vehicle',
        icon: '🚗',
        color: '0xFFEF4444',
        relatedId: id,
        actionRoute: 'Cars',
      );
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      rethrow;
    }
  }

  Future<void> toggleAvailability(String id, bool isAvailable) async {
    try {
      // Mark as manually updated
      _manuallyUpdatedVehicleIds.add(id);

      // Auto-clear from manual cache after some time (e.g., 1 hour)
      Future.delayed(const Duration(hours: 1), () {
        _manuallyUpdatedVehicleIds.remove(id);
        debugPrint(
          '[VehicleService] Removed $id from manual update cache (auto-clear)',
        );
      });

      await _db.child(id).update({
        'isAvailable': isAvailable,
        'status': isAvailable ? 'Available' : 'Booked',
        'manualOverride': true,
        'manualSyncTime': DateTime.now().toIso8601String(),
      });

      debugPrint(
        '[VehicleService] Toggled availability for vehicle $id to ${isAvailable ? "Available" : "Booked"}',
      );
    } catch (e) {
      debugPrint('[VehicleService] Error toggling availability: $e');
      rethrow;
    }
  }

  Future<void> updateVehicleStatus(String id, String status) async {
    try {
      String normStatus = status;
      final statusLower = status.toLowerCase().replaceAll(RegExp(r'\s+'), '');

      // Normalize status values
      if (statusLower == 'available') {
        normStatus = 'Available';
      } else if (statusLower == 'booked' ||
          statusLower == 'reserved' ||
          statusLower == 'rented' ||
          statusLower == 'activebooked' ||
          statusLower == 'bookedvehicle') {
        normStatus = 'Booked';
      } else if (statusLower == 'maintenance') {
        normStatus = 'Maintenance';
      } else if (statusLower == 'inactive') {
        normStatus = 'Inactive';
      } else {
        // If status doesn't match any known status, keep it as-is but capitalize first letter
        normStatus =
            status[0].toUpperCase() + status.substring(1).toLowerCase();
      }

      // IMPORTANT: Mark this vehicle as manually updated to prevent ALL auto-sync
      _manuallyUpdatedVehicleIds.add(id);

      // Auto-clear from manual cache after some time (e.g., 1 hour)
      // This allows the vehicle to go back to auto-sync after manual override expires
      Future.delayed(const Duration(hours: 1), () {
        _manuallyUpdatedVehicleIds.remove(id);
        debugPrint(
          '[VehicleService] Removed $id from manual update cache (auto-clear)',
        );
      });

      // Update the vehicle in Firebase
      await _db.child(id).update({
        'status': normStatus,
        'isAvailable': normStatus == 'Available',
        'manualSyncTime': DateTime.now().toIso8601String(),
        'manualOverride': true,
      });

      String vName = 'Vehicle';
      try {
        final snap = await _db.child(id).get();
        if (snap.exists) {
          final m = snap.value as Map;
          vName = '${m['brand'] ?? ''} ${m['model'] ?? ''}'.trim();
          if (vName.isEmpty) vName = m['name'] ?? 'Vehicle';
        }
      } catch (_) {}

      final notificationService = NotificationService();
      await notificationService.notifyVehicleEvent(
        eventName: normStatus == 'Available' ? 'Vehicle Became Available' : 'Vehicle Status Changed ($normStatus)',
        vehicleId: id,
        vehicleName: vName,
        details: 'status changed to "$normStatus".',
        priority: normStatus == 'Maintenance' ? 'high' : 'normal',
        icon: normStatus == 'Available' ? '✅' : '🚗',
        color: normStatus == 'Available' ? '0xFF10B981' : (normStatus == 'Maintenance' ? '0xFFEF4444' : '0xFFF59E0B'),
      );

      debugPrint(
        '[VehicleService] Successfully updated vehicle $id status to $normStatus',
      );
    } catch (e) {
      debugPrint('[VehicleService] Error updating vehicle status: $e');
      rethrow;
    }
  }

  // Method to clear manual override for a vehicle (useful for admin to reset auto-sync)
  Future<void> clearManualOverride(String id) async {
    _manuallyUpdatedVehicleIds.remove(id);
    await _db.child(id).update({'manualOverride': false});
    debugPrint('[VehicleService] Cleared manual override for vehicle $id');
  }

  // Method to get all manually updated vehicles (for debugging)
  Set<String> getManuallyUpdatedVehicleIds() {
    return Set<String>.from(_manuallyUpdatedVehicleIds);
  }

  // Method to manually remove a vehicle from the manual update cache
  void removeFromManualCache(String id) {
    _manuallyUpdatedVehicleIds.remove(id);
    debugPrint(
      '[VehicleService] Removed $id from manual update cache manually',
    );
  }

  // Method to clear all manual overrides (for admin use)
  Future<void> clearAllManualOverrides() async {
    _manuallyUpdatedVehicleIds.clear();
    debugPrint('[VehicleService] Cleared all manual overrides');
  }

  Future<String> uploadVehicleImage(Uint8List bytes, String filename) async {
    try {
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('Error converting vehicle image to base64: $e');
      return 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600';
    }
  }

  Future<void> seedDefaultVehicles() async {
    final defaults = [
      VehicleModel(
        id: '',
        brand: 'Perodua',
        model: 'Axia',
        category: 'Economy',
        year: 2023,
        plateNumber: 'WQA 4521',
        color: 'Solid Red',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 90.0,
        mileage: 28000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
        description:
            'Super compact city hatchback, extremely fuel-efficient, easy to park, and perfect for dense traffic.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kuala Lumpur',
        engine: '1.0L EEV',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 95.0,
        gallery: [
          'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'USB Port',
          'Bluetooth',
          'Reverse Sensors',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Proton',
        model: 'Saga',
        category: 'Economy',
        year: 2022,
        plateNumber: 'VCD 8932',
        color: 'Armour Silver',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 100.0,
        mileage: 35000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&q=80&w=600',
        description:
            'Reliable and spacious compact sedan. A true Malaysian icon, providing absolute value and comfort.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kajang',
        engine: '1.3L VVT',
        condition: 'Good',
        ac: true,
        rentalDemand: 88.0,
        gallery: [
          'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1553440569-bcc63803a83d?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Bluetooth',
          'Reverse Sensors',
          'Spare Tyre',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Perodua',
        model: 'Bezza',
        category: 'Economy',
        year: 2023,
        plateNumber: 'JPS 2831',
        color: 'Ocean Blue',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 110.0,
        mileage: 24000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1616422285623-13ff0162193c?auto=format&fit=crop&q=80&w=600',
        description:
            'Affordable sedan with huge luggage boot space (508L) and exceptional fuel economy for family road trips.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Putrajaya',
        engine: '1.3L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 91.0,
        gallery: [
          'https://images.unsplash.com/photo-1616422285623-13ff0162193c?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Keyless Entry', 'Bluetooth', 'Sensors'],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Honda',
        model: 'City',
        category: 'Sedan',
        year: 2024,
        plateNumber: 'WQX 4812',
        color: 'Taffeta White',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 150.0,
        mileage: 18000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&q=80&w=600',
        description:
            'Sleek and spacious subcompact sedan with premium interior, excellent driving dynamics, and cold dual-zone AC.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Shah Alam',
        engine: '1.5L i-VTEC',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 94.0,
        gallery: [
          'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Apple CarPlay',
          'Android Auto',
          'Reverse Camera',
          'LED Headlights',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Toyota',
        model: 'Vios',
        category: 'Sedan',
        year: 2023,
        plateNumber: 'KCD 1032',
        color: 'Metal Stream',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 160.0,
        mileage: 21000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1553440569-bcc63803a83d?auto=format&fit=crop&q=80&w=600',
        description:
            'The staple of reliable sedans. Offers smooth performance, high safety standards, and supreme cabin isolation.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Johor Bahru',
        engine: '1.5L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 90.0,
        gallery: [
          'https://images.unsplash.com/photo-1553440569-bcc63803a83d?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Keyless Start',
          '360 Camera',
          'Blind Spot Monitor',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Honda',
        model: 'Civic',
        category: 'Sedan',
        year: 2024,
        plateNumber: 'PEN 7777',
        color: 'Ignite Red',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 240.0,
        mileage: 12000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&q=80&w=600',
        description:
            'Sporty, powerful, and premium. Features a turbocharged engine, Honda SENSING active safety, and leather seats.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Penang',
        engine: '1.5L Turbo',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 97.0,
        gallery: [
          'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Honda SENSING',
          'Leather Seats',
          'Turbo Engine',
          'Digital Dashboard',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Proton',
        model: 'X50',
        category: 'SUV',
        year: 2023,
        plateNumber: 'VBY 4321',
        color: 'Electric Blue',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 180.0,
        mileage: 25000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=600',
        description:
            'Premium compact SUV with active safety systems, intelligent voice command connectivity, and powerful turbocharged engine.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Shah Alam',
        engine: '1.5T Turbo',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 93.0,
        gallery: [
          'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Voice Command',
          'Panoramic Sunroof',
          'Auto Park Assist',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Proton',
        model: 'X70',
        category: 'SUV',
        year: 2023,
        plateNumber: 'WQX 9876',
        color: 'Space Grey',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 230.0,
        mileage: 30000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&q=80&w=600',
        description:
            'Spacious and intelligent mid-size SUV. Features panoramic sunroof, ventilated leather seats, and premium comfort.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kuala Lumpur',
        engine: '1.5L TGDi',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 89.0,
        gallery: [
          'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Ventilated Seats',
          'GPS Tracker',
          'Nappa Leather',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Honda',
        model: 'HR-V',
        category: 'SUV',
        year: 2023,
        plateNumber: 'BQA 9012',
        color: 'Meteor Grey',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 200.0,
        mileage: 19000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=600',
        description:
            'Modern compact crossover SUV with exceptionally versatile seating space configurations and sleek design.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Putrajaya',
        engine: '1.5L VTEC',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 92.0,
        gallery: [
          'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'ULTRA Seats',
          'Honda SENSING',
          'Keyless Go',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Toyota',
        model: 'Corolla Cross',
        category: 'SUV',
        year: 2024,
        plateNumber: 'WQX 3388',
        color: 'White Pearl',
        transmission: 'Automatic',
        fuelType: 'Hybrid',
        seats: 5,
        pricePerDay: 220.0,
        mileage: 15000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1625217527288-93919c996509?auto=format&fit=crop&q=80&w=600',
        description:
            'Hybrid technology SUV offering high fuel efficiency, Toyota Safety Sense, smooth electric motor cruising, and space.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Penang',
        engine: '1.8L Hybrid',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 96.0,
        gallery: [
          'https://images.unsplash.com/photo-1625217527288-93919c996509?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Hybrid Engine',
          'Toyota Safety Sense',
          'TSS 2.0',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Perodua',
        model: 'Alza',
        category: 'MPV',
        year: 2023,
        plateNumber: 'VCD 7122',
        color: 'Vintage Brown',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 7,
        pricePerDay: 170.0,
        mileage: 27000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=600',
        description:
            'Spacious 7-seater family MPV with versatile seat configurations, rear AC vents, and advanced safety features.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kajang',
        engine: '1.5L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 90.0,
        gallery: [
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', '7 Seats', 'Rear AC Vents', 'HDMI Input'],
        maintenance: const [],
      ),
      VehicleModel(
        id: '',
        brand: 'Toyota',
        model: 'Innova',
        category: 'MPV',
        year: 2023,
        plateNumber: 'PEN 4499',
        color: 'Attitude Black',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 8,
        pricePerDay: 260.0,
        mileage: 42000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&q=80&w=600',
        description:
            'The premier full-sized MPV. Offers spacious 8-seat cabin, exceptional cargo capacity, dual blowers, and high road view.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Johor Bahru',
        engine: '2.0L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 91.0,
        gallery: [
          'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          '8 Seats',
          'Dual Blower AC',
          'Touch Screen Nav',
        ],
        maintenance: const [],
      ),
    ];

    for (var vehicle in defaults) {
      await addVehicle(vehicle);
    }
  }

  List<VehicleModel> getDefaultVehicles() {
    return [
      VehicleModel(
        id: 'perodua_axia',
        brand: 'Perodua',
        model: 'Axia',
        category: 'Economy',
        year: 2023,
        plateNumber: 'WQA 4521',
        color: 'Solid Red',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 90.0,
        mileage: 28000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
        description:
            'Super compact city hatchback, extremely fuel-efficient, easy to park, and perfect for dense traffic.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kuala Lumpur',
        engine: '1.0L EEV',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 95.0,
        gallery: [
          'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'USB Port',
          'Bluetooth',
          'Reverse Sensors',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'proton_saga',
        brand: 'Proton',
        model: 'Saga',
        category: 'Economy',
        year: 2022,
        plateNumber: 'VCD 8932',
        color: 'Armour Silver',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 100.0,
        mileage: 35000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&q=80&w=600',
        description:
            'Reliable and spacious compact sedan. A true Malaysian icon, providing absolute value and comfort.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kajang',
        engine: '1.3L VVT',
        condition: 'Good',
        ac: true,
        rentalDemand: 88.0,
        gallery: [
          'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1553440569-bcc63803a83d?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Bluetooth',
          'Reverse Sensors',
          'Spare Tyre',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'perodua_bezza',
        brand: 'Perodua',
        model: 'Bezza',
        category: 'Economy',
        year: 2023,
        plateNumber: 'JPS 2831',
        color: 'Ocean Blue',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 110.0,
        mileage: 24000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1616422285623-13ff0162193c?auto=format&fit=crop&q=80&w=600',
        description:
            'Affordable sedan with huge luggage boot space (508L) and exceptional fuel economy for family road trips.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Putrajaya',
        engine: '1.3L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 91.0,
        gallery: [
          'https://images.unsplash.com/photo-1616422285623-13ff0162193c?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Keyless Entry', 'Bluetooth', 'Sensors'],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'honda_city',
        brand: 'Honda',
        model: 'City',
        category: 'Sedan',
        year: 2024,
        plateNumber: 'WQX 4812',
        color: 'Taffeta White',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 150.0,
        mileage: 18000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&q=80&w=600',
        description:
            'Sleek and spacious subcompact sedan with premium interior, excellent driving dynamics, and cold dual-zone AC.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Shah Alam',
        engine: '1.5L i-VTEC',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 94.0,
        gallery: [
          'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Apple CarPlay',
          'Android Auto',
          'Reverse Camera',
          'LED Headlights',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'toyota_vios',
        brand: 'Toyota',
        model: 'Vios',
        category: 'Sedan',
        year: 2023,
        plateNumber: 'KCD 1032',
        color: 'Metal Stream',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 160.0,
        mileage: 21000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1553440569-bcc63803a83d?auto=format&fit=crop&q=80&w=600',
        description:
            'The staple of reliable sedans. Offers smooth performance, high safety standards, and supreme cabin isolation.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Johor Bahru',
        engine: '1.5L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 90.0,
        gallery: [
          'https://images.unsplash.com/photo-1553440569-bcc63803a83d?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Keyless Start',
          '360 Camera',
          'Blind Spot Monitor',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'honda_civic',
        brand: 'Honda',
        model: 'Civic',
        category: 'Sedan',
        year: 2024,
        plateNumber: 'PEN 7777',
        color: 'Ignite Red',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 240.0,
        mileage: 12000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&q=80&w=600',
        description:
            'Sporty, powerful, and premium. Features a turbocharged engine, Honda SENSING active safety, and leather seats.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Penang',
        engine: '1.5L Turbo',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 97.0,
        gallery: [
          'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&q=80&w=600',
          'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Honda SENSING',
          'Leather Seats',
          'Turbo Engine',
          'Digital Dashboard',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'proton_x50',
        brand: 'Proton',
        model: 'X50',
        category: 'SUV',
        year: 2023,
        plateNumber: 'VBY 4321',
        color: 'Electric Blue',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 180.0,
        mileage: 25000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=600',
        description:
            'Premium compact SUV with active safety systems, intelligent voice command connectivity, and powerful turbocharged engine.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Shah Alam',
        engine: '1.5T Turbo',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 93.0,
        gallery: [
          'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Voice Command',
          'Panoramic Sunroof',
          'Auto Park Assist',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'proton_x70',
        brand: 'Proton',
        model: 'X70',
        category: 'SUV',
        year: 2023,
        plateNumber: 'WQX 9876',
        color: 'Space Grey',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 230.0,
        mileage: 30000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&q=80&w=600',
        description:
            'Spacious and intelligent mid-size SUV. Features panoramic sunroof, ventilated leather seats, and premium comfort.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kuala Lumpur',
        engine: '1.5L TGDi',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 89.0,
        gallery: [
          'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Ventilated Seats',
          'GPS Tracker',
          'Nappa Leather',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'honda_hrv',
        brand: 'Honda',
        model: 'HR-V',
        category: 'SUV',
        year: 2023,
        plateNumber: 'BQA 9012',
        color: 'Meteor Grey',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 200.0,
        mileage: 19000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=600',
        description:
            'Modern compact crossover SUV with exceptionally versatile seating space configurations and sleek design.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Putrajaya',
        engine: '1.5L VTEC',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 92.0,
        gallery: [
          'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'ULTRA Seats',
          'Honda SENSING',
          'Keyless Go',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'toyota_corolla_cross',
        brand: 'Toyota',
        model: 'Corolla Cross',
        category: 'SUV',
        year: 2024,
        plateNumber: 'WQX 3388',
        color: 'White Pearl',
        transmission: 'Automatic',
        fuelType: 'Hybrid',
        seats: 5,
        pricePerDay: 220.0,
        mileage: 15000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1625217527288-93919c996509?auto=format&fit=crop&q=80&w=600',
        description:
            'Hybrid technology SUV offering high fuel efficiency, Toyota Safety Sense, smooth electric motor cruising, and space.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Penang',
        engine: '1.8L Hybrid',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 96.0,
        gallery: [
          'https://images.unsplash.com/photo-1625217527288-93919c996509?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          'Hybrid Engine',
          'Toyota Safety Sense',
          'TSS 2.0',
        ],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'perodua_alza',
        brand: 'Perodua',
        model: 'Alza',
        category: 'MPV',
        year: 2023,
        plateNumber: 'VCD 7122',
        color: 'Vintage Brown',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 7,
        pricePerDay: 170.0,
        mileage: 27000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=600',
        description:
            'Spacious 7-seater family MPV with versatile seat configurations, rear AC vents, and advanced safety features.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kajang',
        engine: '1.5L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 90.0,
        gallery: [
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', '7 Seats', 'Rear AC Vents', 'HDMI Input'],
        maintenance: const [],
      ),
      VehicleModel(
        id: 'toyota_innova',
        brand: 'Toyota',
        model: 'Innova',
        category: 'MPV',
        year: 2023,
        plateNumber: 'PEN 4499',
        color: 'Attitude Black',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 8,
        pricePerDay: 260.0,
        mileage: 42000,
        isAvailable: true,
        mainImage:
            'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&q=80&w=600',
        description:
            'The premier full-sized MPV. Offers spacious 8-seat cabin, exceptional cargo capacity, dual blowers, and high road view.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Johor Bahru',
        engine: '2.0L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 91.0,
        gallery: [
          'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: [
          'ABS',
          'Airbags',
          '8 Seats',
          'Dual Blower AC',
          'Touch Screen Nav',
        ],
        maintenance: const [],
      ),
    ];
  }
}
