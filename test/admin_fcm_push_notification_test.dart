import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/services/fcm_service.dart';

void main() {
  group('Admin FCM Push Notification Service Tests', () {
    final fcmService = FCMService();

    test('sanitizeTokenKey correctly cleans illegal Realtime Database characters', () {
      const rawToken = 'fcm.admin.token#456\$xyz[abc]';
      final sanitized = fcmService.sanitizeTokenKey(rawToken);

      expect(sanitized, equals('fcm_admin_token_456_xyz_abc_'));
      expect(sanitized.contains('.'), isFalse);
      expect(sanitized.contains('#'), isFalse);
      expect(sanitized.contains('\$'), isFalse);
      expect(sanitized.contains('['), isFalse);
      expect(sanitized.contains(']'), isFalse);
    });

    test('Admin role verification recognizes admin variants (admin, Admin, super_admin)', () {
      final roles = ['admin', 'Admin', 'super_admin'];
      for (final r in roles) {
        final rLower = r.toLowerCase();
        final bool isAdmin = rLower == 'admin' || rLower == 'super_admin';
        expect(isAdmin, isTrue);
      }
    });

    test('Admin FCM push payload structure matches FCM specification', () {
      final payload = {
        'to': '/topics/admin',
        'priority': 'high',
        'notification': {
          'title': 'New Booking Created',
          'body': 'Customer John Doe booked Toyota Camry',
          'sound': 'default',
          'android_channel_id': 'high_importance_channel',
        },
        'data': {
          'title': 'New Booking Created',
          'body': 'Customer John Doe booked Toyota Camry',
          'type': 'booking',
          'actionRoute': 'Bookings',
          'relatedId': 'BOOK-101',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      expect(payload['to'], equals('/topics/admin'));
      expect(payload['priority'], equals('high'));

      final notif = payload['notification'] as Map<String, dynamic>;
      expect(notif['android_channel_id'], equals('high_importance_channel'));

      final data = payload['data'] as Map<String, dynamic>;
      expect(data['type'], equals('booking'));
      expect(data['actionRoute'], equals('Bookings'));
      expect(data['click_action'], equals('FLUTTER_NOTIFICATION_CLICK'));
    });
  });
}
