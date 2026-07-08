import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/models/booking_model.dart';
import 'package:carrent_system/models/vehicle_model.dart';

void main() {
  group('Open Rental BookingModel Tests', () {
    test('Should initialize BookingModel with isOpenRental true and null returnDate', () {
      final now = DateTime.now();
      final booking = BookingModel(
        id: 'b_open_1',
        vehicleId: 'v1',
        vehicleName: 'Toyota Vios',
        userId: 'u1',
        userName: 'Customer Test',
        userPhone: '12345678',
        pickUpDate: now,
        returnDate: null,
        totalPrice: 150.0,
        depositAmount: 50.0,
        status: 'Confirmed',
        createdAt: now,
        isOpenRental: true,
      );

      expect(booking.isOpenRental, true);
      expect(booking.returnDate, isNull);
    });

    test('should parse and serialize isOpenRental and actual timestamps correctly', () {
      final now = DateTime.now();
      final pickupTime = now.subtract(const Duration(days: 2));
      final returnTime = now;

      final mockData = {
        'vehicleId': 'v1',
        'vehicleName': 'Toyota Vios',
        'userId': 'u1',
        'userName': 'Customer Test',
        'userPhone': '12345678',
        'pickUpDate': pickupTime.toIso8601String(),
        'returnDate': null,
        'totalPrice': 150.0,
        'depositAmount': 50.0,
        'status': 'Completed',
        'createdAt': pickupTime.toIso8601String(),
        'isOpenRental': true,
        'actualPickupTimestamp': pickupTime.toIso8601String(),
        'actualReturnTimestamp': returnTime.toIso8601String(),
      };

      final booking = BookingModel.fromMap('b_open_serialize', mockData);
      expect(booking.isOpenRental, true);
      expect(booking.returnDate, isNull);
      expect(booking.actualPickupTimestamp, isNotNull);
      expect(booking.actualReturnTimestamp, isNotNull);
      expect(booking.actualPickupTimestamp!.day, pickupTime.day);
      expect(booking.actualReturnTimestamp!.day, returnTime.day);

      final mapped = booking.toMap();
      expect(mapped['isOpenRental'], true);
      expect(mapped['returnDate'], isNull);
      expect(mapped['actualPickupTimestamp'], pickupTime.toIso8601String());
      expect(mapped['actualReturnTimestamp'], returnTime.toIso8601String());
    });

    test('should fall back to defaults when isOpenRental and actual timestamps are missing', () {
      final now = DateTime.now();
      final mockData = {
        'vehicleId': 'v1',
        'vehicleName': 'Toyota Vios',
        'userId': 'u1',
        'userName': 'Customer Test',
        'userPhone': '12345678',
        'pickUpDate': now.toIso8601String(),
        'returnDate': now.add(const Duration(days: 2)).toIso8601String(),
        'totalPrice': 150.0,
        'depositAmount': 50.0,
        'status': 'Confirmed',
        'createdAt': now.toIso8601String(),
      };

      final booking = BookingModel.fromMap('b_open_defaults', mockData);
      expect(booking.isOpenRental, false);
      expect(booking.returnDate, isNotNull);
      expect(booking.actualPickupTimestamp, isNull);
      expect(booking.actualReturnTimestamp, isNull);
    });

    test('should calculate correct dynamic open rental days based on hours elapsed', () {
      final pickup = DateTime.now().subtract(const Duration(hours: 26)); // 1 day and 2 hours
      
      // Elapsed hours: 26 hours -> ceil(26 / 24) = 2 days
      final diff = DateTime.now().difference(pickup);
      final hours = diff.inHours;
      final days = (hours / 24.0).ceil();
      final calculatedDays = days <= 0 ? 1 : days;

      expect(calculatedDays, 2);
    });

    test('should calculate 1 day for minimal elapsed hours', () {
      final pickup = DateTime.now().subtract(const Duration(hours: 4)); // 4 hours
      
      final diff = DateTime.now().difference(pickup);
      final hours = diff.inHours;
      final days = (hours / 24.0).ceil();
      final calculatedDays = days <= 0 ? 1 : days;

      expect(calculatedDays, 1);
    });

    test('BookingModel rentalDays should return 1 when isOpenRental is true', () {
      final now = DateTime.now();
      final booking = BookingModel(
        id: 'b_open_days_test',
        vehicleId: 'v1',
        vehicleName: 'Toyota Vios',
        userId: 'u1',
        userName: 'Customer Test',
        userPhone: '12345678',
        pickUpDate: now,
        returnDate: null,
        totalPrice: 150.0,
        depositAmount: 50.0,
        status: 'Confirmed',
        createdAt: now,
        isOpenRental: true,
      );

      expect(booking.rentalDays, 1);
    });

    test('Vehicle status sync with bookings - active booking makes vehicle unavailable', () {
      final vehicle = VehicleModel(
        id: 'v_sync_test',
        brand: 'Toyota',
        model: 'Camry',
        year: 2022,
        plateNumber: 'BQA 1234',
        color: 'Black',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 150.0,
        isAvailable: true,
        status: 'Available',
        mainImage: '',
        description: '',
        createdAt: '',
      );

      final activeBooking = BookingModel(
        id: 'b_sync_active',
        vehicleId: 'v_sync_test',
        vehicleName: 'Toyota Camry',
        userId: 'u1',
        userName: 'Customer Test',
        userPhone: '12345678',
        pickUpDate: DateTime.now(),
        returnDate: null,
        totalPrice: 150.0,
        depositAmount: 50.0,
        status: 'Confirmed',
        createdAt: DateTime.now(),
        isOpenRental: true,
      );

      final bookingsList = [activeBooking];
      final hasActiveBooking = bookingsList.any((booking) {
        if (booking.vehicleId != vehicle.id) return false;
        final statusLower = booking.status.toLowerCase();
        return statusLower != 'completed' && 
               statusLower != 'cancelled' && 
               statusLower != 'rejected';
      });

      expect(hasActiveBooking, isTrue);
      
      final updatedVehicle = vehicle.copyWith(
        status: hasActiveBooking ? 'Booked' : 'Available',
        isAvailable: !hasActiveBooking,
      );

      expect(updatedVehicle.status, 'Booked');
      expect(updatedVehicle.isAvailable, isFalse);
    });

    test('Vehicle status sync with bookings - completed booking makes vehicle available', () {
      final vehicle = VehicleModel(
        id: 'v_sync_test_completed',
        brand: 'Toyota',
        model: 'Camry',
        year: 2022,
        plateNumber: 'BQA 1234',
        color: 'Black',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        pricePerDay: 150.0,
        isAvailable: false,
        status: 'Booked',
        mainImage: '',
        description: '',
        createdAt: '',
      );

      final completedBooking = BookingModel(
        id: 'b_sync_completed',
        vehicleId: 'v_sync_test_completed',
        vehicleName: 'Toyota Camry',
        userId: 'u1',
        userName: 'Customer Test',
        userPhone: '12345678',
        pickUpDate: DateTime.now().subtract(const Duration(days: 2)),
        returnDate: DateTime.now().subtract(const Duration(days: 1)),
        totalPrice: 150.0,
        depositAmount: 50.0,
        status: 'Completed',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        isOpenRental: false,
      );

      final bookingsList = [completedBooking];
      final hasActiveBooking = bookingsList.any((booking) {
        if (booking.vehicleId != vehicle.id) return false;
        final statusLower = booking.status.toLowerCase();
        return statusLower != 'completed' && 
               statusLower != 'cancelled' && 
               statusLower != 'rejected';
      });

      expect(hasActiveBooking, isFalse);
      
      final updatedVehicle = vehicle.copyWith(
        status: hasActiveBooking ? 'Booked' : 'Available',
        isAvailable: !hasActiveBooking,
      );

      expect(updatedVehicle.status, 'Available');
      expect(updatedVehicle.isAvailable, isTrue);
    });
  });
}
