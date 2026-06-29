import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class NotificationService {
  final DatabaseReference _baseDb = FirebaseDatabase.instance.ref().child('notifications');

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String icon = '⚙️',
    String color = '0xFF64748B',
    String relatedId = '',
    String actionRoute = 'Dashboard',
  }) async {
    try {
      // ignore: avoid_print
      print("Saving notification for customer: $userId");
      final newRef = _baseDb.push();
      final finalNotification = NotificationModel(
        id: newRef.key!,
        userId: userId,
        title: title,
        message: message,
        type: type,
        isRead: false,
        createdAt: DateTime.now(),
        icon: icon,
        color: color,
        relatedId: relatedId,
        actionRoute: actionRoute,
      );
      await newRef.set(finalNotification.toMap()).timeout(const Duration(seconds: 10));
      // ignore: avoid_print
      print("Notification saved successfully");

      // Non-blocking cleanup of old notifications to keep latest 50 per user
      _cleanupOldNotifications(userId).catchError((e) {
        debugPrint('Error cleaning up notifications: $e');
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
      rethrow;
    }
  }

  Future<void> _cleanupOldNotifications(String userId) async {
    try {
      final snapshot = await _baseDb.orderByChild('userId').equalTo(userId).get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        if (data.length > 50) {
          List<NotificationModel> notifications = [];
          data.forEach((key, value) {
            notifications.add(NotificationModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
          });
          notifications.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // oldest first
          
          final toDeleteCount = notifications.length - 50;
          for (int i = 0; i < toDeleteCount; i++) {
            await _baseDb.child(notifications[i].id).remove().timeout(const Duration(seconds: 2));
          }
        }
      }
    } catch (e) {
      debugPrint('Asynchronous notification cleanup failed: $e');
    }
  }

  Future<List<NotificationModel>> getNotifications(String userId, {int? limit}) async {
    List<NotificationModel> notifications = [];
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return notifications;

    String targetUserId = userId;
    if (userId != currentUser.uid) {
      String currentRole = 'customer';
      try {
        final roleSnap = await FirebaseDatabase.instance.ref().child('users').child(currentUser.uid).child('role').get().timeout(const Duration(seconds: 3));
        if (roleSnap.exists) {
          currentRole = roleSnap.value.toString();
        }
      } catch (_) {}

      if (currentRole != 'admin') {
        targetUserId = currentUser.uid;
      }
    }

    try {
      Query query = _baseDb.orderByChild('userId').equalTo(targetUserId);
      if (limit != null) {
        query = query.limitToLast(limit);
      }
      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          notifications.add(NotificationModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      rethrow;
    }

    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  Stream<List<NotificationModel>> getNotificationsStream(String userId, {int? limit}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    if (userId == currentUser.uid) {
      // ignore: avoid_print
      print("Customer UID: ${currentUser.uid}");
      // ignore: avoid_print
      print("Listening to: notifications filtered by userId: ${currentUser.uid}");

      Query query = _baseDb.orderByChild('userId').equalTo(currentUser.uid);
      if (limit != null) {
        query = query.limitToLast(limit);
      }
      return query.onValue.map((event) {
        List<NotificationModel> notifications = [];
        if (event.snapshot.exists && event.snapshot.value != null) {
          final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            notifications.add(NotificationModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
          });
        }
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        // ignore: avoid_print
        print("Notification received: ${notifications.length} item(s)");
        return notifications;
      });
    }

    return _getNotificationsStreamWithRoleCheck(userId, currentUser, limit);
  }

  Stream<List<NotificationModel>> _getNotificationsStreamWithRoleCheck(String userId, User currentUser, int? limit) async* {
    String currentRole = 'customer';
    try {
      final roleSnap = await FirebaseDatabase.instance.ref().child('users').child(currentUser.uid).child('role').get().timeout(const Duration(seconds: 3));
      if (roleSnap.exists) {
        currentRole = roleSnap.value.toString();
      }
    } catch (_) {}

    String targetUserId = userId;
    if (currentRole != 'admin') {
      targetUserId = currentUser.uid;
    }

    // ignore: avoid_print
    print("Customer UID: $targetUserId");
    // ignore: avoid_print
    print("Listening to: notifications filtered by userId: $targetUserId");

    Query query = _baseDb.orderByChild('userId').equalTo(targetUserId);
    if (limit != null) {
      query = query.limitToLast(limit);
    }
    yield* query.onValue.map((event) {
      List<NotificationModel> notifications = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          notifications.add(NotificationModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // ignore: avoid_print
      print("Notification received: ${notifications.length} item(s)");
      return notifications;
    });
  }

  Future<void> markAsRead(String userId, String id) async {
    try {
      await _baseDb.child(id).update({'isRead': true}).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> toggleReadStatus(String userId, String id, bool isRead) async {
    try {
      await _baseDb.child(id).update({'isRead': isRead}).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error toggling read status: $e');
      rethrow;
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _baseDb.orderByChild('userId').equalTo(userId).get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> updates = {};
        data.forEach((key, value) {
          final isReadVal = (value as Map)['isRead'] ?? false;
          if (!isReadVal) {
            updates['$key/isRead'] = true;
          }
        });
        if (updates.isNotEmpty) {
          await _baseDb.update(updates).timeout(const Duration(seconds: 10));
        }
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  Future<void> clearReadNotifications(String userId) async {
    try {
      final snapshot = await _baseDb.orderByChild('userId').equalTo(userId).get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> updates = {};
        data.forEach((key, value) {
          final isReadVal = (value as Map)['isRead'] ?? false;
          if (isReadVal) {
            updates[key.toString()] = null; // delete
          }
        });
        if (updates.isNotEmpty) {
          await _baseDb.update(updates).timeout(const Duration(seconds: 10));
        }
      }
    } catch (e) {
      debugPrint('Error clearing read notifications: $e');
      rethrow;
    }
  }

  Future<void> deleteNotification(String userId, String id) async {
    try {
      await _baseDb.child(id).remove().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      rethrow;
    }
  }

  Future<void> clearAllNotifications(String userId) async {
    try {
      final snapshot = await _baseDb.orderByChild('userId').equalTo(userId).get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> updates = {};
        data.forEach((key, value) {
          updates[key.toString()] = null; // delete
        });
        if (updates.isNotEmpty) {
          await _baseDb.update(updates).timeout(const Duration(seconds: 10));
        }
      }
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
      rethrow;
    }
  }

  Future<void> notifyAllCustomers({
    required String title,
    required String message,
    required String type,
    String icon = '⚙️',
    String color = '0xFF64748B',
    String relatedId = '',
    String actionRoute = 'Dashboard',
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String currentRole = 'customer';
      try {
        final roleSnap = await FirebaseDatabase.instance.ref().child('users').child(currentUser.uid).child('role').get().timeout(const Duration(seconds: 3));
        if (roleSnap.exists) {
          currentRole = roleSnap.value.toString();
        }
      } catch (_) {}

      if (currentRole != 'admin') {
        debugPrint('[NotificationService] [notifyAllCustomers] Customer user cannot read user list to notify customers. Skipping.');
        return;
      }

      final snapshot = await FirebaseDatabase.instance.ref().child('users').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> users = snapshot.value as Map<dynamic, dynamic>;
        for (var entry in users.entries) {
          final userData = entry.value as Map<dynamic, dynamic>;
          final role = userData['role'] ?? 'customer';
          if (role == 'customer') {
            await createNotification(
              userId: entry.key.toString(),
              title: title,
              message: message,
              type: type,
              icon: icon,
              color: color,
              relatedId: relatedId,
              actionRoute: actionRoute,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error notifying all customers: $e');
    }
  }

  Future<void> notifyAllAdmins({
    required String title,
    required String message,
    required String type,
    String icon = '⚙️',
    String color = '0xFF64748B',
    String relatedId = '',
    String actionRoute = 'Dashboard',
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String currentRole = 'customer';
      try {
        final roleSnap = await FirebaseDatabase.instance.ref().child('users').child(currentUser.uid).child('role').get().timeout(const Duration(seconds: 3));
        if (roleSnap.exists) {
          currentRole = roleSnap.value.toString();
        }
      } catch (_) {}

      if (currentRole != 'admin') {
        debugPrint('[NotificationService] [notifyAllAdmins] Customer user cannot read user list to notify admins. Skipping.');
        return;
      }

      final snapshot = await FirebaseDatabase.instance.ref().child('users').get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> users = snapshot.value as Map<dynamic, dynamic>;
        for (var entry in users.entries) {
          final userData = entry.value as Map<dynamic, dynamic>;
          final role = userData['role'] ?? 'customer';
          if (role == 'admin') {
            await createNotification(
              userId: entry.key.toString(),
              title: title,
              message: message,
              type: type,
              icon: icon,
              color: color,
              relatedId: relatedId,
              actionRoute: actionRoute,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error notifying all admins: $e');
    }
  }
}
