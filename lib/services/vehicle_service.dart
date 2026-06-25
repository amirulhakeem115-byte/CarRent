import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vehicle_model.dart';

class VehicleService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('vehicles');

  Future<List<VehicleModel>> getVehicles() async {
    List<VehicleModel> vehicles = [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    String currentRole = 'unknown';
    if (currentUid != null) {
      try {
        final roleSnap = await FirebaseDatabase.instance.ref().child('users').child(currentUid).child('role').get().timeout(const Duration(seconds: 3));
        if (roleSnap.exists) {
          currentRole = roleSnap.value.toString();
        }
      } catch (_) {}
    }
    debugPrint('[VehicleService] [getVehicles] Accessing path: vehicles');
    debugPrint('[VehicleService] [getVehicles] Current UID: $currentUid, Current Role: $currentRole');

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
            debugPrint('[VehicleService] [getVehicles] Vehicles count loaded (after seeding): ${vehicles.length}');
            return vehicles;
          }
        } catch (seedError) {
          debugPrint('Failed to seed default vehicles or read after seeding: $seedError. Using local defaults.');
        }
        return getDefaultVehicles();
      }
      debugPrint('[VehicleService] [getVehicles] Vehicles count loaded: ${vehicles.length}');
    } catch (e) {
      debugPrint('[VehicleService] [getVehicles] Error getting vehicles: $e. Returning fallback vehicles.');
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
      await _db.child(id).update({
        'isAvailable': isAvailable,
        'status': isAvailable ? 'available' : 'booked',
      });
    } catch (e) {
      debugPrint('Error toggling availability: $e');
      rethrow;
    }
  }

  Future<void> updateVehicleStatus(String id, String status) async {
    try {
      await _db.child(id).update({
        'status': status,
        'isAvailable': status == 'available',
      });
    } catch (e) {
      debugPrint('Error updating vehicle status: $e');
      rethrow;
    }
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
        mainImage: 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
        description: 'Super compact city hatchback, extremely fuel-efficient, easy to park, and perfect for dense traffic.',
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
        equipment: ['ABS', 'Airbags', 'USB Port', 'Bluetooth', 'Reverse Sensors'],
        maintenance: [
          {'section': 'Engine Oil', 'description': 'Routine oil change and fluid top-up.', 'startDate': '2026-05-10', 'endDate': '2026-05-10'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&q=80&w=600',
        description: 'Reliable and spacious compact sedan. A true Malaysian icon, providing absolute value and comfort.',
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
        equipment: ['ABS', 'Airbags', 'Bluetooth', 'Reverse Sensors', 'Spare Tyre'],
        maintenance: [
          {'section': 'Brakes', 'description': 'Replaced front brake pads.', 'startDate': '2026-04-18', 'endDate': '2026-04-18'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1616422285623-13ff0162193c?auto=format&fit=crop&q=80&w=600',
        description: 'Affordable sedan with huge luggage boot space (508L) and exceptional fuel economy for family road trips.',
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
        maintenance: [
          {'section': 'Tyres', 'description': 'Replaced front tyre set.', 'startDate': '2026-03-22', 'endDate': '2026-03-22'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&q=80&w=600',
        description: 'Sleek and spacious subcompact sedan with premium interior, excellent driving dynamics, and cold dual-zone AC.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Shah Alam',
        engine: '1.5L i-VTEC',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 94.0,
        gallery: [
          'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Apple CarPlay', 'Android Auto', 'Reverse Camera', 'LED Headlights'],
        maintenance: [
          {'section': 'Engine Oil', 'description': 'First service completed.', 'startDate': '2026-05-02', 'endDate': '2026-05-02'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1553440569-bcc63803a83d?auto=format&fit=crop&q=80&w=600',
        description: 'The staple of reliable sedans. Offers smooth performance, high safety standards, and supreme cabin isolation.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Johor Bahru',
        engine: '1.5L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 90.0,
        gallery: [
          'https://images.unsplash.com/photo-1553440569-bcc63803a83d?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Keyless Start', '360 Camera', 'Blind Spot Monitor'],
        maintenance: [
          {'section': 'Air Filter', 'description': 'Replaced cabin air filters.', 'startDate': '2026-04-12', 'endDate': '2026-04-12'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&q=80&w=600',
        description: 'Sporty, powerful, and premium. Features a turbocharged engine, Honda SENSING active safety, and leather seats.',
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
        equipment: ['ABS', 'Airbags', 'Honda SENSING', 'Leather Seats', 'Turbo Engine', 'Digital Dashboard'],
        maintenance: [
          {'section': 'Engine Tune', 'description': 'Spark plugs and ECU check.', 'startDate': '2026-05-15', 'endDate': '2026-05-15'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=600',
        description: 'Premium compact SUV with active safety systems, intelligent voice command connectivity, and powerful turbocharged engine.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Shah Alam',
        engine: '1.5T Turbo',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 93.0,
        gallery: [
          'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Voice Command', 'Panoramic Sunroof', 'Auto Park Assist'],
        maintenance: [
          {'section': 'Oil Service', 'description': 'Engine oil filter change.', 'startDate': '2026-03-10', 'endDate': '2026-03-10'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&q=80&w=600',
        description: 'Spacious and intelligent mid-size SUV. Features panoramic sunroof, ventilated leather seats, and premium comfort.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kuala Lumpur',
        engine: '1.5L TGDi',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 89.0,
        gallery: [
          'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Ventilated Seats', 'GPS Tracker', 'Nappa Leather'],
        maintenance: [
          {'section': 'Air Cond', 'description': 'AC system cleaning and recharge.', 'startDate': '2026-02-28', 'endDate': '2026-02-28'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=600',
        description: 'Modern compact crossover SUV with exceptionally versatile seating space configurations and sleek design.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Putrajaya',
        engine: '1.5L VTEC',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 92.0,
        gallery: [
          'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'ULTRA Seats', 'Honda SENSING', 'Keyless Go'],
        maintenance: [
          {'section': 'Battery', 'description': 'Replaced car battery (AGM).', 'startDate': '2026-04-05', 'endDate': '2026-04-05'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1625217527288-93919c996509?auto=format&fit=crop&q=80&w=600',
        description: 'Hybrid technology SUV offering high fuel efficiency, Toyota Safety Sense, smooth electric motor cruising, and space.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Penang',
        engine: '1.8L Hybrid',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 96.0,
        gallery: [
          'https://images.unsplash.com/photo-1625217527288-93919c996509?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Hybrid Engine', 'Toyota Safety Sense', 'TSS 2.0'],
        maintenance: [
          {'section': 'Hybrid Check', 'description': 'Inverter and battery diagnostic check.', 'startDate': '2026-05-11', 'endDate': '2026-05-11'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=600',
        description: 'Spacious 7-seater family MPV with versatile seat configurations, rear AC vents, and advanced safety features.',
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
        maintenance: [
          {'section': 'Alignment', 'description': 'Wheel alignment and tyre rotation.', 'startDate': '2026-05-01', 'endDate': '2026-05-01'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&q=80&w=600',
        description: 'The premier full-sized MPV. Offers spacious 8-seat cabin, exceptional cargo capacity, dual blowers, and high road view.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Johor Bahru',
        engine: '2.0L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 91.0,
        gallery: [
          'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', '8 Seats', 'Dual Blower AC', 'Touch Screen Nav'],
        maintenance: [
          {'section': 'Transmission', 'description': 'Gearbox fluid check.', 'startDate': '2026-03-15', 'endDate': '2026-03-15'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
        description: 'Super compact city hatchback, extremely fuel-efficient, easy to park, and perfect for dense traffic.',
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
        equipment: ['ABS', 'Airbags', 'USB Port', 'Bluetooth', 'Reverse Sensors'],
        maintenance: [
          {'section': 'Engine Oil', 'description': 'Routine oil change and fluid top-up.', 'startDate': '2026-05-10', 'endDate': '2026-05-10'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&q=80&w=600',
        description: 'Reliable and spacious compact sedan. A true Malaysian icon, providing absolute value and comfort.',
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
        equipment: ['ABS', 'Airbags', 'Bluetooth', 'Reverse Sensors', 'Spare Tyre'],
        maintenance: [
          {'section': 'Brakes', 'description': 'Replaced front brake pads.', 'startDate': '2026-04-18', 'endDate': '2026-04-18'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1616422285623-13ff0162193c?auto=format&fit=crop&q=80&w=600',
        description: 'Affordable sedan with huge luggage boot space (508L) and exceptional fuel economy for family road trips.',
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
        maintenance: [
          {'section': 'Tyres', 'description': 'Replaced front tyre set.', 'startDate': '2026-03-22', 'endDate': '2026-03-22'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&q=80&w=600',
        description: 'Sleek and spacious subcompact sedan with premium interior, excellent driving dynamics, and cold dual-zone AC.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Shah Alam',
        engine: '1.5L i-VTEC',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 94.0,
        gallery: [
          'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Apple CarPlay', 'Android Auto', 'Reverse Camera', 'LED Headlights'],
        maintenance: [
          {'section': 'Engine Oil', 'description': 'First service completed.', 'startDate': '2026-05-02', 'endDate': '2026-05-02'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1553440569-bcc63803a83d?auto=format&fit=crop&q=80&w=600',
        description: 'The staple of reliable sedans. Offers smooth performance, high safety standards, and supreme cabin isolation.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Johor Bahru',
        engine: '1.5L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 90.0,
        gallery: [
          'https://images.unsplash.com/photo-1553440569-bcc63803a83d?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Keyless Start', '360 Camera', 'Blind Spot Monitor'],
        maintenance: [
          {'section': 'Air Filter', 'description': 'Replaced cabin air filters.', 'startDate': '2026-04-12', 'endDate': '2026-04-12'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&q=80&w=600',
        description: 'Sporty, powerful, and premium. Features a turbocharged engine, Honda SENSING active safety, and leather seats.',
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
        equipment: ['ABS', 'Airbags', 'Honda SENSING', 'Leather Seats', 'Turbo Engine', 'Digital Dashboard'],
        maintenance: [
          {'section': 'Engine Tune', 'description': 'Spark plugs and ECU check.', 'startDate': '2026-05-15', 'endDate': '2026-05-15'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=600',
        description: 'Premium compact SUV with active safety systems, intelligent voice command connectivity, and powerful turbocharged engine.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Shah Alam',
        engine: '1.5T Turbo',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 93.0,
        gallery: [
          'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Voice Command', 'Panoramic Sunroof', 'Auto Park Assist'],
        maintenance: [
          {'section': 'Oil Service', 'description': 'Engine oil filter change.', 'startDate': '2026-03-10', 'endDate': '2026-03-10'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&q=80&w=600',
        description: 'Spacious and intelligent mid-size SUV. Features panoramic sunroof, ventilated leather seats, and premium comfort.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Kuala Lumpur',
        engine: '1.5L TGDi',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 89.0,
        gallery: [
          'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Ventilated Seats', 'GPS Tracker', 'Nappa Leather'],
        maintenance: [
          {'section': 'Air Cond', 'description': 'AC system cleaning and recharge.', 'startDate': '2026-02-28', 'endDate': '2026-02-28'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=600',
        description: 'Modern compact crossover SUV with exceptionally versatile seating space configurations and sleek design.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Putrajaya',
        engine: '1.5L VTEC',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 92.0,
        gallery: [
          'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'ULTRA Seats', 'Honda SENSING', 'Keyless Go'],
        maintenance: [
          {'section': 'Battery', 'description': 'Replaced car battery (AGM).', 'startDate': '2026-04-05', 'endDate': '2026-04-05'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1625217527288-93919c996509?auto=format&fit=crop&q=80&w=600',
        description: 'Hybrid technology SUV offering high fuel efficiency, Toyota Safety Sense, smooth electric motor cruising, and space.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Penang',
        engine: '1.8L Hybrid',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 96.0,
        gallery: [
          'https://images.unsplash.com/photo-1625217527288-93919c996509?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', 'Hybrid Engine', 'Toyota Safety Sense', 'TSS 2.0'],
        maintenance: [
          {'section': 'Hybrid Check', 'description': 'Inverter and battery diagnostic check.', 'startDate': '2026-05-11', 'endDate': '2026-05-11'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=600',
        description: 'Spacious 7-seater family MPV with versatile seat configurations, rear AC vents, and advanced safety features.',
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
        maintenance: [
          {'section': 'Alignment', 'description': 'Wheel alignment and tyre rotation.', 'startDate': '2026-05-01', 'endDate': '2026-05-01'},
        ],
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
        mainImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&q=80&w=600',
        description: 'The premier full-sized MPV. Offers spacious 8-seat cabin, exceptional cargo capacity, dual blowers, and high road view.',
        createdAt: DateTime.now().toIso8601String(),
        branchName: 'Johor Bahru',
        engine: '2.0L Dual VVT-i',
        condition: 'Excellent',
        ac: true,
        rentalDemand: 91.0,
        gallery: [
          'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&q=80&w=600',
        ],
        equipment: ['ABS', 'Airbags', '8 Seats', 'Dual Blower AC', 'Touch Screen Nav'],
        maintenance: [
          {'section': 'Transmission', 'description': 'Gearbox fluid check.', 'startDate': '2026-03-15', 'endDate': '2026-03-15'},
        ],
      ),
    ];
  }
}
