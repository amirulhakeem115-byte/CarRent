import 'package:firebase_auth/firebase_auth.dart';
import 'user_session.dart';

class UserRoleCache {
  static String? getLocal(String uid) {
    if (UserSession().currentUserId == uid) {
      return UserSession().currentRole;
    }
    return null;
  }

  static void set(String uid, String role) {
    UserSession().forceSetRole(role, uid: uid);
  }

  static void clear() {
    UserSession().clear();
  }

  static Future<String> getRole(String uid) async {
    return UserSession().fetchAndCacheRole(uid);
  }

  static Future<String> getCurrentUserRole() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return 'unauthenticated';
    return getRole(currentUid);
  }
}
