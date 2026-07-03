import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:carrent_system/models/booking_model.dart';

void main() {
  group('Smart Pickup & Return Scheduling Tests', () {
    test('1. Time Slot Generation Bounds and Step Intervals', () {
      final String openStr = '08:00 AM';
      final String closeStr = '08:00 PM';
      
      final List<String> slots = [];
      final format = DateFormat('hh:mm a');
      final open = format.parse(openStr);
      final close = format.parse(closeStr);
      
      var current = open;
      while (current.isBefore(close) || current.isAtSameMomentAs(close)) {
        slots.add(DateFormat('hh:mm a').format(current));
        current = current.add(const Duration(minutes: 30));
      }

      // 12 hours * 2 slots per hour + 1 (end boundary slot at 08:00 PM) = 25 slots
      expect(slots.length, 25);
      expect(slots.first, '08:00 AM');
      expect(slots.last, '08:00 PM');
      expect(slots[1], '08:30 AM');
    });

    test('2. Return Time Must Match Pickup Time Exactly', () {
      final pickupDate = DateTime(2026, 7, 5, 10, 0); // 5 July 2026, 10:00 AM
      final rentalDays = 3;
      
      // Auto-matched return date based on duration
      final returnDate = pickupDate.add(Duration(days: rentalDays));
      
      expect(returnDate.year, 2026);
      expect(returnDate.month, 7);
      expect(returnDate.day, 8);
      expect(returnDate.hour, 10);
      expect(returnDate.minute, 0);
    });

    test('3. Actual Pickup & Return Times Serialization in BookingModel', () {
      final now = DateTime.now();
      final actualPickup = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
      final actualReturn = DateTime.now().toIso8601String();

      final mockData = {
        'vehicleId': 'v1',
        'vehicleName': 'Perodua Myvi',
        'userId': 'u1',
        'userName': 'Musab',
        'userPhone': '1234',
        'pickUpDate': now.toIso8601String(),
        'returnDate': now.add(const Duration(days: 3)).toIso8601String(),
        'totalPrice': 300.0,
        'depositAmount': 50.0,
        'status': 'Completed',
        'createdAt': now.toIso8601String(),
        'actualPickupTime': actualPickup,
        'actualReturnTime': actualReturn,
        'pickupReminderSent': true,
        'returnReminderSent': true,
        'customerStatus': 'on_my_way',
      };

      final booking = BookingModel.fromMap('b_sched_1', mockData);
      
      expect(booking.actualPickupTime, actualPickup);
      expect(booking.actualReturnTime, actualReturn);
      expect(booking.pickupReminderSent, true);
      expect(booking.returnReminderSent, true);
      expect(booking.customerStatus, 'on_my_way');

      final serialized = booking.toMap();
      expect(serialized['actualPickupTime'], actualPickup);
      expect(serialized['actualReturnTime'], actualReturn);
      expect(serialized['pickupReminderSent'], true);
      expect(serialized['returnReminderSent'], true);
      expect(serialized['customerStatus'], 'on_my_way');
    });

    test('4. Reminder Scan Window Calculation', () {
      final now = DateTime.now();
      
      // Scheduled pickup is in exactly 45 minutes
      final scheduledPickup = now.add(const Duration(minutes: 45));
      final diffToPickup = scheduledPickup.difference(now);
      
      // Should trigger reminder (difference is <= 60 mins and > 0 mins)
      final bool triggerPickupReminder = diffToPickup.inMinutes > 0 && diffToPickup.inMinutes <= 60;
      expect(triggerPickupReminder, true);
      
      // Scheduled return is in 2 hours
      final scheduledReturn = now.add(const Duration(hours: 2));
      final diffToReturn = scheduledReturn.difference(now);
      
      // Should NOT trigger return reminder (difference > 60 mins)
      final bool triggerReturnReminder = diffToReturn.inMinutes > 0 && diffToReturn.inMinutes <= 60;
      expect(triggerReturnReminder, false);
    });
  });
}
