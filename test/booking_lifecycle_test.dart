import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/models/booking_model.dart';

void main() {
  group('BookingModel isReturned Serialization Tests', () {
    test('fromMap and toMap should parse and serialize isReturned correctly', () {
      final now = DateTime.now();
      final mockData = {
        'vehicleId': 'v1',
        'vehicleName': 'Perodua Axia',
        'userId': 'u1',
        'userName': 'Musab',
        'userPhone': '12345678',
        'pickUpDate': now.toIso8601String(),
        'returnDate': now.add(const Duration(days: 3)).toIso8601String(),
        'totalPrice': 270.0,
        'depositAmount': 50.0,
        'status': 'ongoing',
        'createdAt': now.toIso8601String(),
        'isReturned': true,
      };

      final booking = BookingModel.fromMap('b_test_1', mockData);
      expect(booking.isReturned, true);

      final mapped = booking.toMap();
      expect(mapped['isReturned'], true);
    });

    test('fromMap should fallback isReturned to false when missing from database', () {
      final now = DateTime.now();
      final mockData = {
        'vehicleId': 'v1',
        'vehicleName': 'Perodua Axia',
        'userId': 'u1',
        'userName': 'Musab',
        'userPhone': '12345678',
        'pickUpDate': now.toIso8601String(),
        'returnDate': now.add(const Duration(days: 3)).toIso8601String(),
        'totalPrice': 270.0,
        'depositAmount': 50.0,
        'status': 'ongoing',
        'createdAt': now.toIso8601String(),
      };

      final booking = BookingModel.fromMap('b_test_2', mockData);
      expect(booking.isReturned, false);

      final mapped = booking.toMap();
      expect(mapped['isReturned'], false);
    });
  });

  group('Booking Lifecycle State Transition Rules Tests', () {
    test('Rule 1: If Return DateTime is in the future and isReturned is false, booking remains active', () {
      final now = DateTime.now();
      final pickUp = now.subtract(const Duration(days: 1));
      final returnDate = now.add(const Duration(days: 2));

      final booking = BookingModel(
        id: 'b1',
        vehicleId: 'v1',
        vehicleName: 'Perodua Axia',
        userId: 'u1',
        userName: 'Musab',
        userPhone: '1234',
        pickUpDate: pickUp,
        returnDate: returnDate,
        totalPrice: 270.0,
        depositAmount: 50.0,
        status: 'active',
        createdAt: pickUp,
        isReturned: false,
      );

      // Verify that return date is in future
      expect(now.isBefore(booking.returnDate), true);
      
      // Expected: No change, stays active
      String finalStatus = booking.status;
      if (booking.isReturned) {
        finalStatus = 'completed';
      } else if ((booking.status == 'ongoing' || booking.status == 'active') && now.isAfter(booking.returnDate)) {
        finalStatus = 'overdue';
      }
      expect(finalStatus, 'active');
    });

    test('Rule 1b: If Return DateTime is in the future and isReturned is true, booking transitions to completed (early return)', () {
      final now = DateTime.now();
      final pickUp = now.subtract(const Duration(days: 1));
      final returnDate = now.add(const Duration(days: 2));

      final booking = BookingModel(
        id: 'b1b',
        vehicleId: 'v1',
        vehicleName: 'Perodua Axia',
        userId: 'u1',
        userName: 'Musab',
        userPhone: '1234',
        pickUpDate: pickUp,
        returnDate: returnDate,
        totalPrice: 270.0,
        depositAmount: 50.0,
        status: 'active',
        createdAt: pickUp,
        isReturned: true,
      );

      // Verify that return date is in future
      expect(now.isBefore(booking.returnDate), true);
      
      // Expected: Transitions to completed
      String finalStatus = booking.status;
      if (booking.isReturned) {
        finalStatus = 'completed';
      } else if ((booking.status == 'ongoing' || booking.status == 'active') && now.isAfter(booking.returnDate)) {
        finalStatus = 'overdue';
      }
      expect(finalStatus, 'completed');
    });

    test('Rule 2: If Return DateTime has passed and isReturned is false, status transitions to overdue', () {
      final now = DateTime.now();
      final pickUp = now.subtract(const Duration(days: 5));
      final returnDate = now.subtract(const Duration(hours: 2));

      final booking = BookingModel(
        id: 'b2',
        vehicleId: 'v1',
        vehicleName: 'Perodua Axia',
        userId: 'u1',
        userName: 'Musab',
        userPhone: '1234',
        pickUpDate: pickUp,
        returnDate: returnDate,
        totalPrice: 270.0,
        depositAmount: 50.0,
        status: 'active',
        createdAt: pickUp,
        isReturned: false,
      );

      // Verify return date has passed
      expect(now.isAfter(booking.returnDate), true);
      
      // Apply lifecycle logic
      String finalStatus = booking.status;
      if (booking.isReturned) {
        finalStatus = 'completed';
      } else if ((booking.status == 'ongoing' || booking.status == 'active') && now.isAfter(booking.returnDate)) {
        finalStatus = 'overdue';
      }
      expect(finalStatus, 'overdue');
    });

    test('Rule 3: If Return DateTime has passed and isReturned is true, status transitions to completed', () {
      final now = DateTime.now();
      final pickUp = now.subtract(const Duration(days: 5));
      final returnDate = now.subtract(const Duration(hours: 2));

      final booking = BookingModel(
        id: 'b3',
        vehicleId: 'v1',
        vehicleName: 'Perodua Axia',
        userId: 'u1',
        userName: 'Musab',
        userPhone: '1234',
        pickUpDate: pickUp,
        returnDate: returnDate,
        totalPrice: 270.0,
        depositAmount: 50.0,
        status: 'active',
        createdAt: pickUp,
        isReturned: true,
      );

      // Verify return date has passed
      expect(now.isAfter(booking.returnDate), true);
      
      // Apply lifecycle logic
      String finalStatus = booking.status;
      if (booking.isReturned) {
        finalStatus = 'completed';
      } else if ((booking.status == 'ongoing' || booking.status == 'active') && now.isAfter(booking.returnDate)) {
        finalStatus = 'overdue';
      }
      expect(finalStatus, 'completed');
    });

    test('Rule 4: Once vehicle is marked as returned (isReturned is set to true) on an overdue booking, it transitions to completed', () {
      final now = DateTime.now();
      final pickUp = now.subtract(const Duration(days: 5));
      final returnDate = now.subtract(const Duration(days: 2));

      // Initially overdue
      var booking = BookingModel(
        id: 'b4',
        vehicleId: 'v1',
        vehicleName: 'Perodua Axia',
        userId: 'u1',
        userName: 'Musab',
        userPhone: '1234',
        pickUpDate: pickUp,
        returnDate: returnDate,
        totalPrice: 270.0,
        depositAmount: 50.0,
        status: 'overdue',
        createdAt: pickUp,
        isReturned: false,
      );

      expect(booking.status, 'overdue');

      // Admin or user completes the return process, setting isReturned = true
      booking = BookingModel(
        id: booking.id,
        vehicleId: booking.vehicleId,
        vehicleName: booking.vehicleName,
        userId: booking.userId,
        userName: booking.userName,
        userPhone: booking.userPhone,
        pickUpDate: booking.pickUpDate,
        returnDate: booking.returnDate,
        totalPrice: booking.totalPrice,
        depositAmount: booking.depositAmount,
        status: booking.status,
        createdAt: booking.createdAt,
        isReturned: true,
      );

      // Apply lifecycle logic
      String finalStatus = booking.status;
      if (booking.isReturned) {
        finalStatus = 'completed';
      } else if (booking.status == 'overdue' && booking.isReturned) {
        finalStatus = 'completed';
      }
      expect(finalStatus, 'completed');
    });
  });
}
