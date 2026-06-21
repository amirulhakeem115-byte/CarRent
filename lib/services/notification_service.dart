import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/notification_model.dart';

class NotificationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('notifications');

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final newRef = _db.push();
      final finalNotification = NotificationModel(
        id: newRef.key!,
        userId: userId,
        title: title,
        message: message,
        type: type,
        isRead: false,
        createdAt: DateTime.now(),
      );
      await newRef.set(finalNotification.toMap()).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error creating notification: $e');
      rethrow;
    }
  }

  Future<List<NotificationModel>> getNotifications(String userId) async {
    List<NotificationModel> notifications = [];
    try {
      final snapshot = await _db.orderByChild('userId').equalTo(userId).get().timeout(const Duration(seconds: 10));
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

  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _db.orderByChild('userId').equalTo(userId).onValue.map((event) {
      List<NotificationModel> notifications = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          notifications.add(NotificationModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  Future<void> markAsRead(String id) async {
    try {
      await _db.child(id).update({'isRead': true}).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> clearAllNotifications(String userId) async {
    try {
      final snapshot = await _db.orderByChild('userId').equalTo(userId).get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        for (var key in data.keys) {
          await _db.child(key.toString()).remove().timeout(const Duration(seconds: 10));
        }
      }
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
      rethrow;
    }
  }
}
