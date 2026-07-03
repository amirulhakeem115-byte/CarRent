import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/ai/services/intent_engine.dart';
import 'package:carrent_system/ai/models/ai_intent.dart';

void main() {
  group('IntentEngine Matcher Tests (70 Variations)', () {
    final engine = IntentEngine();

    test('1. SUV Search Variations', () {
      final variations = [
        'Find SUV',
        'Show SUVs',
        'I need an suv',
        'search for suvs',
        'find sports utility',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<VehicleSearchIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['category'], 'SUV', reason: 'Failed category on: $text');
      }
    });

    test('2. Sedan Search Variations', () {
      final variations = [
        'Find Sedan',
        'Show Sedan',
        'I want a sedan',
        'search sedans',
        'find a sedan',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<VehicleSearchIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['category'], 'Sedan', reason: 'Failed category on: $text');
      }
    });

    test('3. Price Searches Variations', () {
      final variations = [
        'Cars under RM200',
        'RM150 max',
        'under 200',
        'below RM250',
        'rm 300 limit',
      ];
      final prices = [200.0, 150.0, 200.0, 250.0, 300.0];
      for (int i = 0; i < variations.length; i++) {
        final text = variations[i];
        final intent = engine.detectIntent(text);
        expect(intent, isA<VehicleSearchIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['max_price'], prices[i], reason: 'Failed price on: $text');
      }
    });

    test('4. Automatic Transmission Variations', () {
      final variations = [
        'Automatic cars',
        'show automatic',
        'auto transmission car',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<VehicleSearchIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['transmission'], 'Automatic', reason: 'Failed trans on: $text');
      }
    });

    test('5. Manual Transmission Variations', () {
      final variations = [
        'Manual cars',
        'show manual',
        'manual transmission car',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<VehicleSearchIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['transmission'], 'Manual', reason: 'Failed trans on: $text');
      }
    });

    test('6. Cheapest / Budget Sort Variations', () {
      final variations = [
        'Cheapest car',
        'affordable vehicles',
        'budget cars',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<VehicleSearchIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['sort'], 'price_asc', reason: 'Failed sort on: $text');
      }
    });

    test('7. View Bookings Variations', () {
      final variations = [
        'Open bookings',
        'Show my bookings',
        'booking list',
        'my rentals list',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<BookingIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['action'], 'view_bookings', reason: 'Failed action on: $text');
      }
    });

    test('8. Book a Vehicle Variations', () {
      final variations = [
        'Book a vehicle',
        'make a booking',
        'create a rental reservation',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<BookingIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['action'], 'book_vehicle', reason: 'Failed action on: $text');
      }
    });

    test('9. Cancel Booking Variations', () {
      final variations = [
        'Cancel booking',
        'Cancel my car',
        'terminate reservation',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<BookingIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['action'], 'cancel_booking', reason: 'Failed action on: $text');
      }
    });

    test('10. Rewards Variations', () {
      final variations = [
        'Rewards',
        'Reward points',
        'my loyalty points',
        'membership benefits',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<RewardIntent>(), reason: 'Failed on: $text');
      }
    });

    test('11. Open Receipt Variations', () {
      final variations = [
        'Open receipt',
        'show invoice statements',
        'receipt page',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<ReceiptIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['action'], 'open_receipt', reason: 'Failed action on: $text');
      }
    });

    test('12. Download Receipt Variations', () {
      final variations = [
        'Download receipt',
        'get invoice pdf',
        'export receipt',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<ReceiptIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['action'], 'download_receipt', reason: 'Failed action on: $text');
      }
    });

    test('13. Profile Variations', () {
      final variations = [
        'Profile',
        'Open profile',
        'my details settings',
        'account details',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<ProfileIntent>(), reason: 'Failed on: $text');
      }
    });

    test('14. Customer Support Variations', () {
      final variations = [
        'Support',
        'Contact support',
        'talk to customer care',
        'submit help complaint',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<SupportIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['action'], 'contact_support', reason: 'Failed action on: $text');
      }
    });

    test('15. Branches Locations Variations', () {
      final variations = [
        'Branches',
        'Locations',
        'where are your hubs',
        'rental map office',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<BranchIntent>(), reason: 'Failed on: $text');
      }
    });

    test('16. Notifications Variations', () {
      final variations = [
        'Notifications',
        'Alerts',
        'unread notifications log',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<NotificationIntent>(), reason: 'Failed on: $text');
      }
    });

    test('17. Rental History Variations', () {
      final variations = [
        'History',
        'Booking history',
        'past rentals log',
        'completed bookings record',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<HistoryIntent>(), reason: 'Failed on: $text');
      }
    });

    test('18. Dashboard Variations', () {
      final variations = [
        'Dashboard',
        'Home screen panel',
        'main view overview',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<DashboardIntent>(), reason: 'Failed on: $text');
      }
    });

    test('19. Customer Payments Ledger Variations', () {
      final variations = [
        'Payment list',
        'ledger statements',
        'transaction history payment',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<PaymentIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['action'], 'view_payments', reason: 'Failed action on: $text');
      }
    });

    test('20. Today Bookings (Admin) Variations', () {
      final variations = [
        'Today\'s bookings',
        'bookings for today',
        'current bookings list admin',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<BookingIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['action'], 'admin_today_bookings', reason: 'Failed action on: $text');
      }
    });

    test('21. Revenue Today (Admin) Variations', () {
      final variations = [
        'Revenue today',
        'today sales analytics',
        'earnings statement',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<PaymentIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['action'], 'admin_revenue_today', reason: 'Failed action on: $text');
      }
    });

    test('22. Customer Database (Admin) Variations', () {
      final variations = [
        'Customers',
        'view customer profiles list',
        'all active user clients',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<CustomerIntent>(), reason: 'Failed on: $text');
      }
    });

    test('23. Maintenance (Admin) Variations', () {
      final variations = [
        'Maintenance service',
        'vehicle repair log',
        'car inspection reports',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<MaintenanceIntent>(), reason: 'Failed on: $text');
      }
    });

    test('24. Reports (Admin) Variations', () {
      final variations = [
        'Reports stats',
        'Generate report analytic',
        'export charts dashboard data',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<ReportIntent>(), reason: 'Failed on: $text');
      }
    });

    test('25. Live Tracking (Admin) Variations', () {
      final variations = [
        'Vehicle tracking live',
        'where is the car gps',
        'track live vehicle locations',
      ];
      for (final text in variations) {
        final intent = engine.detectIntent(text);
        expect(intent, isA<NavigationIntent>(), reason: 'Failed on: $text');
        expect(intent.parameters['action'], 'admin_vehicle_tracking', reason: 'Failed action on: $text');
      }
    });
  });
}
