import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/screens/auth/customer/booking_date_utils.dart';

void main() {
  group('customer booking date defaults', () {
    test('defaults pickup date to today', () {
      final now = DateTime(2026, 8, 29, 15, 30);

      expect(getTomorrowStart(now: now), DateTime(2026, 8, 30));
      expect(getDefaultPickupDate(now: now), DateTime(2026, 8, 29));
    });

    test('allows today and later, but not past dates', () {
      final now = DateTime(2026, 8, 29, 15, 30);

      expect(isPickupDateAllowed(DateTime(2026, 8, 28), now: now), isFalse);
      expect(isPickupDateAllowed(DateTime(2026, 8, 29), now: now), isTrue);
      expect(isPickupDateAllowed(DateTime(2026, 8, 30), now: now), isTrue);
    });
  });
}
