import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/models/booking_model.dart';
import 'package:carrent_system/services/booking_service.dart';

void main() {
  group('Overdue Calculation Logic Verification Tests', () {
    final DateTime scheduledReturn = DateTime(2026, 7, 8, 12, 0); // July 8th, 12:00 PM
    final double pricePerDay = 150.0;

    test('Active bookings calculate overdue correctly', () {
      final booking = BookingModel(
        id: 'b_active',
        vehicleId: 'v1',
        vehicleName: 'Axia',
        userId: 'u1',
        userName: 'Musab',
        userPhone: '12345',
        pickUpDate: scheduledReturn.subtract(const Duration(days: 2)),
        returnDate: scheduledReturn,
        totalPrice: 300.0,
        depositAmount: 50.0,
        status: 'Active',
        createdAt: DateTime.now(),
      );

      // Overdue < 1 day: e.g. 5 hours late
      final fiveHoursLate = scheduledReturn.add(const Duration(hours: 5));
      final chargesUnderOneDay = BookingService.calculateOverdueCharges(booking, pricePerDay, now: fiveHoursLate);
      final detailsUnderOneDay = BookingService.getOverdueDetails(booking, pricePerDay, now: fiveHoursLate);

      expect(chargesUnderOneDay, 5 * 20.0); // RM100
      expect(detailsUnderOneDay['isOverdue'], true);
      expect(detailsUnderOneDay['days'], 0);
      expect(detailsUnderOneDay['hours'], 5);

      // Overdue >= 1 day: e.g. 2 days + 3 hours late
      final twoDaysThreeHoursLate = scheduledReturn.add(const Duration(days: 2, hours: 3));
      final chargesOverOneDay = BookingService.calculateOverdueCharges(booking, pricePerDay, now: twoDaysThreeHoursLate);
      final detailsOverOneDay = BookingService.getOverdueDetails(booking, pricePerDay, now: twoDaysThreeHoursLate);

      expect(chargesOverOneDay, (2 * pricePerDay) + (3 * 20.0)); // 2 * 150 + 3 * 20 = RM360
      expect(detailsOverOneDay['isOverdue'], true);
      expect(detailsOverOneDay['days'], 2);
      expect(detailsOverOneDay['hours'], 3);
    });

    test('Completed bookings never receive new overdue charges (frozen late fees)', () {
      final booking = BookingModel(
        id: 'b_completed',
        vehicleId: 'v1',
        vehicleName: 'Axia',
        userId: 'u1',
        userName: 'Musab',
        userPhone: '12345',
        pickUpDate: scheduledReturn.subtract(const Duration(days: 2)),
        returnDate: scheduledReturn,
        totalPrice: 300.0,
        depositAmount: 50.0,
        status: 'Completed',
        createdAt: DateTime.now(),
        isReturned: true,
        lateFees: 80.0, // Statically stored frozen late fee
      );

      final now = scheduledReturn.add(const Duration(days: 10)); // 10 days later
      final charges = BookingService.calculateOverdueCharges(booking, pricePerDay, now: now);
      final details = BookingService.getOverdueDetails(booking, pricePerDay, now: now);

      expect(charges, 80.0); // Retains frozen late fee
      expect(details['isOverdue'], false);
      expect(details['charges'], 80.0);
    });

    test('Cancelled bookings never receive overdue charges', () {
      final booking = BookingModel(
        id: 'b_cancelled',
        vehicleId: 'v1',
        vehicleName: 'Axia',
        userId: 'u1',
        userName: 'Musab',
        userPhone: '12345',
        pickUpDate: scheduledReturn.subtract(const Duration(days: 2)),
        returnDate: scheduledReturn,
        totalPrice: 300.0,
        depositAmount: 50.0,
        status: 'cancelled',
        createdAt: DateTime.now(),
        isReturned: false,
        lateFees: 0.0,
      );

      final now = scheduledReturn.add(const Duration(days: 5));
      final charges = BookingService.calculateOverdueCharges(booking, pricePerDay, now: now);
      final details = BookingService.getOverdueDetails(booking, pricePerDay, now: now);

      expect(charges, 0.0);
      expect(details['isOverdue'], false);
      expect(details['charges'], 0.0);
    });

    test('Upcoming or future bookings do not calculate overdue even if return date passed', () {
      final booking = BookingModel(
        id: 'b_upcoming',
        vehicleId: 'v1',
        vehicleName: 'Axia',
        userId: 'u1',
        userName: 'Musab',
        userPhone: '12345',
        pickUpDate: scheduledReturn.subtract(const Duration(days: 2)),
        returnDate: scheduledReturn,
        totalPrice: 300.0,
        depositAmount: 50.0,
        status: 'Approved', // Customer hasn't picked up/activated yet
        createdAt: DateTime.now(),
      );

      final now = scheduledReturn.add(const Duration(days: 1));
      final charges = BookingService.calculateOverdueCharges(booking, pricePerDay, now: now);
      final details = BookingService.getOverdueDetails(booking, pricePerDay, now: now);

      expect(charges, 0.0);
      expect(details['isOverdue'], false);
    });
  });
}
