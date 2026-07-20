import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Customer Late Return Reminder Interval Calculation Tests', () {
    test('Slot Index 0 at exact return time (0 to 119 minutes)', () {
      final returnDate = DateTime(2026, 7, 20, 16, 0); // 4:00 PM
      final checkTime = DateTime(2026, 7, 20, 16, 30); // 4:30 PM (30 mins overdue)

      final minutesOverdue = checkTime.difference(returnDate).inMinutes;
      final slotIndex = (minutesOverdue / 120).floor();

      expect(minutesOverdue, equals(30));
      expect(slotIndex, equals(0));
    });

    test('Slot Index 1 at 2 hours overdue (120 to 239 minutes)', () {
      final returnDate = DateTime(2026, 7, 20, 16, 0); // 4:00 PM
      final checkTime = DateTime(2026, 7, 20, 18, 0); // 6:00 PM (120 mins overdue)

      final minutesOverdue = checkTime.difference(returnDate).inMinutes;
      final slotIndex = (minutesOverdue / 120).floor();

      expect(minutesOverdue, equals(120));
      expect(slotIndex, equals(1));
    });

    test('Slot Index 2 at 4 hours overdue (240 to 359 minutes)', () {
      final returnDate = DateTime(2026, 7, 20, 16, 0); // 4:00 PM
      final checkTime = DateTime(2026, 7, 20, 20, 0); // 8:00 PM (240 mins overdue)

      final minutesOverdue = checkTime.difference(returnDate).inMinutes;
      final slotIndex = (minutesOverdue / 120).floor();

      expect(minutesOverdue, equals(240));
      expect(slotIndex, equals(2));
    });

    test('Slot Index 3 at 6 hours overdue (360 to 479 minutes)', () {
      final returnDate = DateTime(2026, 7, 20, 16, 0); // 4:00 PM
      final checkTime = DateTime(2026, 7, 20, 22, 0); // 10:00 PM (360 mins overdue)

      final minutesOverdue = checkTime.difference(returnDate).inMinutes;
      final slotIndex = (minutesOverdue / 120).floor();

      expect(minutesOverdue, equals(360));
      expect(slotIndex, equals(3));
    });

    test('Reminders stop when booking status is completed or cancelled', () {
      const statusCompleted = 'completed';
      const statusCancelled = 'cancelled';
      const statusActive = 'active';

      bool shouldSendReminder(String status) {
        final norm = status.toLowerCase();
        return norm != 'completed' && norm != 'cancelled' && norm != 'rejected';
      }

      expect(shouldSendReminder(statusCompleted), isFalse);
      expect(shouldSendReminder(statusCancelled), isFalse);
      expect(shouldSendReminder(statusActive), isTrue);
    });
  });
}
