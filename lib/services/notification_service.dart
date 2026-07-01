import 'dart:async';
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

    final controller = StreamController<List<NotificationModel>>.broadcast();
    StreamSubscription<DatabaseEvent>? personalSub;
    StreamSubscription<DatabaseEvent>? adminSub;
    List<NotificationModel> personalList = [];
    List<NotificationModel> adminList = [];

    void emitMerged() {
      if (controller.isClosed) return;
      final Map<String, NotificationModel> merged = {};
      for (var n in personalList) {
        merged[n.id] = n;
      }
      for (var n in adminList) {
        merged[n.id] = n;
      }
      final list = merged.values.toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (limit != null && list.length > limit) {
        controller.add(list.take(limit).toList());
      } else {
        controller.add(list);
      }
    }

    // 1. Immediately subscribe to personal notifications
    Query personalQuery = _baseDb.orderByChild('userId').equalTo(currentUser.uid);
    if (limit != null) {
      personalQuery = personalQuery.limitToLast(limit);
    }
    personalSub = personalQuery.onValue.listen((event) {
      personalList = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        try {
          final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            personalList.add(NotificationModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
          });
        } catch (e) {
          debugPrint('Error parsing personal notifications: $e');
        }
      }
      emitMerged();
    });

    // 2. Fetch role asynchronously and optionally subscribe to 'admin' topic
    FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(currentUser.uid)
        .child('role')
        .get()
        .then((roleSnap) {
      if (controller.isClosed) return;
      final role = roleSnap.exists ? roleSnap.value.toString() : 'customer';

      if (role == 'admin') {
        Query adminQuery = _baseDb.orderByChild('userId').equalTo('admin');
        if (limit != null) {
          adminQuery = adminQuery.limitToLast(limit);
        }
        adminSub = adminQuery.onValue.listen((event) {
          adminList = [];
          if (event.snapshot.exists && event.snapshot.value != null) {
            try {
              final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
              data.forEach((key, value) {
                adminList.add(NotificationModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
              });
            } catch (e) {
              debugPrint('Error parsing admin notifications: $e');
            }
          }
          emitMerged();
        });
      }
    }).catchError((e) {
      debugPrint('Error checking user role for notification stream: $e');
    });

    controller.onCancel = () {
      personalSub?.cancel();
      adminSub?.cancel();
    };

    return controller.stream;
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
        // Fallback for customer actions: write directly to 'admin' topic
        await createNotification(
          userId: 'admin',
          title: title,
          message: message,
          type: type,
          icon: icon,
          color: color,
          relatedId: relatedId,
          actionRoute: actionRoute,
        );
        return;
      }

      // If caller is admin, try to create individual notifications for each admin
      try {
        final snapshot = await FirebaseDatabase.instance.ref().child('users').get().timeout(const Duration(seconds: 5));
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
        // Fallback if users list reading is permission-denied
        await createNotification(
          userId: 'admin',
          title: title,
          message: message,
          type: type,
          icon: icon,
          color: color,
          relatedId: relatedId,
          actionRoute: actionRoute,
        );
      }
    } catch (e) {
      debugPrint('Error notifying all admins: $e');
    }
  }
}
