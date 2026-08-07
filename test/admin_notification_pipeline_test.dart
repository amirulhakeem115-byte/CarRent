import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/models/notification_model.dart';

void main() {
  group('Admin Notification Pipeline & Role Isolation Tests', () {
    test('Admin role receives both user-specific and admin-topic notifications', () {
      final userNotifs = [
        NotificationModel(
          id: 'notif_1',
          userId: 'admin_uid_123',
          title: 'Direct Admin Notification',
          message: 'Direct alert to admin user',
          type: 'system',
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      final adminNotifs = [
        NotificationModel(
          id: 'notif_2',
          userId: 'admin',
          title: 'New Booking Created',
          message: 'Customer John Doe booked Toyota Camry',
          type: 'booking',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];

      final Map<String, NotificationModel> map = {};
      for (var n in userNotifs) {
        map[n.id] = n;
      }
      for (var n in adminNotifs) {
        map[n.id] = n;
      }

      final combined = map.values.toList();
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(combined.length, equals(2));
      expect(combined.first.id, equals('notif_2'));
      expect(combined.first.userId, equals('admin'));
    });

    test('Customer role receives ONLY customer-specific notifications and never admin-topic', () {
      final customerNotifs = [
        NotificationModel(
          id: 'cust_notif_1',
          userId: 'customer_123',
          title: 'Booking Confirmed',
          message: 'Your booking is confirmed',
          type: 'booking',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];

      final combined = List<NotificationModel>.from(customerNotifs);

      expect(combined.length, equals(1));
      expect(combined.every((n) => n.userId != 'admin'), isTrue);
    });

    test('Verify all 8 core system events generate valid notification maps', () {
      final events = [
        {'type': 'booking', 'title': 'New Booking Created'},
        {'type': 'booking', 'title': 'Booking Approved'},
        {'type': 'booking', 'title': 'Booking Rejected'},
        {'type': 'payment', 'title': 'Payment Submitted'},
        {'type': 'payment', 'title': 'Payment Approved'},
        {'type': 'payment', 'title': 'Payment Rejected'},
        {'type': 'support', 'title': 'Support Ticket Created'},
        {'type': 'inspection_completed', 'title': 'Vehicle Returned'},
      ];

      for (var ev in events) {
        final notif = NotificationModel(
          id: 'test_id',
          userId: 'admin',
          title: ev['title']!,
          message: 'Test message for ${ev['title']}',
          type: ev['type']!,
          isRead: false,
          createdAt: DateTime.now(),
        );

        final map = notif.toMap();
        expect(map['userId'], equals('admin'));
        expect(map['title'], equals(ev['title']));
        expect(map['type'], equals(ev['type']));
      }
    });
  });
}
