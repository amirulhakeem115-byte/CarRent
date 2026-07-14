import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Open Rental Calculation Tests', () {
    const double pricePerDay = 130.0; // Honda City daily rate

    double calculateCost(Duration duration) {
      final pickup = DateTime(2026, 7, 8, 12, 0);
      final returnTime = pickup.add(duration);
      
      final diff = returnTime.difference(pickup);
      final double totalHoursDecimal = diff.inSeconds / 3600.0;
      final int roundedHours = totalHoursDecimal.ceil();
      final int hours = roundedHours <= 0 ? 1 : roundedHours;

      final int days = hours ~/ 24;
      final int remainingHours = hours % 24;
      return (days * pricePerDay) + (remainingHours * 20.0);
    }

    test('30 minutes rental (less than 1 hour) -> RM20', () {
      expect(calculateCost(const Duration(minutes: 30)), 20.0);
    });

    test('1 hour rental -> RM20', () {
      expect(calculateCost(const Duration(hours: 1)), 20.0);
    });

    test('1 hour 10 minutes rental -> RM40', () {
      expect(calculateCost(const Duration(hours: 1, minutes: 10)), 40.0);
    });

    test('2 hours rental -> RM40', () {
      expect(calculateCost(const Duration(hours: 2)), 40.0);
    });

    test('5 hours rental -> RM100', () {
      expect(calculateCost(const Duration(hours: 5)), 100.0);
    });

    test('12 hours rental -> RM240', () {
      expect(calculateCost(const Duration(hours: 12)), 240.0);
    });

    test('24 hours rental -> RM130', () {
      expect(calculateCost(const Duration(hours: 24)), 130.0);
    });

    test('26 hours rental -> RM170', () {
      expect(calculateCost(const Duration(hours: 26)), 170.0);
    });

    test('48 hours rental -> RM260', () {
      expect(calculateCost(const Duration(hours: 48)), 260.0);
    });

    test('72 hours rental -> RM390', () {
      expect(calculateCost(const Duration(hours: 72)), 390.0);
    });
  });
}
