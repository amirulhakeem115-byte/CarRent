import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/services/user_role_cache.dart';

void main() {
  group('UserRoleCache Tests', () {
    setUp(() {
      UserRoleCache.clear();
    });

    test('getLocal should return null initially and the cached value after setting', () {
      expect(UserRoleCache.getLocal('user123'), isNull);
      UserRoleCache.set('user123', 'admin');
      expect(UserRoleCache.getLocal('user123'), 'admin');
    });

    test('clear should empty the cache', () {
      UserRoleCache.set('user123', 'admin');
      expect(UserRoleCache.getLocal('user123'), 'admin');
      UserRoleCache.clear();
      expect(UserRoleCache.getLocal('user123'), isNull);
    });
  });
}
