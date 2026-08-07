import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/services/fcm_service.dart';

void main() {
  group('FCM Push Notification Service Tests', () {
    final fcmService = FCMService();

    test('sanitizeTokenKey correctly cleans invalid Firebase Realtime DB key characters', () {
      const rawToken = 'fcm.token#123\$abc[xyz]';
      final sanitized = fcmService.sanitizeTokenKey(rawToken);

      expect(sanitized, equals('fcm_token_123_abc_xyz_'));
      expect(sanitized.contains('.'), isFalse);
      expect(sanitized.contains('#'), isFalse);
      expect(sanitized.contains('\$'), isFalse);
      expect(sanitized.contains('['), isFalse);
      expect(sanitized.contains(']'), isFalse);
    });

    test('FCMService singleton maintains a single instance', () {
      final instance1 = FCMService();
      final instance2 = FCMService();

      expect(identical(instance1, instance2), isTrue);
    });
  });
}
