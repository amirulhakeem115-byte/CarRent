import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/notification_model.dart';

class NotificationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('notifications');

  static final List<NotificationModel> _mockNotifications = [
    NotificationModel(
      id: 'mock_n1',
      userId: 'demo_customer',
      title: 'Welcome to Antigravity Rent!',
      message: 'Explore our premium fleet of vehicles and pick a location to get started.',
      type: 'general',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: title,
      message: message,
      type: type,
      isRead: false,
      createdAt: DateTime.now(),
    );

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
      await newRef.set(finalNotification.toMap());
    } catch (e) {
      debugPrint('Error creating notification, using fallback: $e');
    }

    _mockNotifications.add(notification);
  }

  Future<List<NotificationModel>> getNotifications(String userId) async {
    List<NotificationModel> notifications = [];
    try {
      final snapshot = await _db.orderByChild('userId').equalTo(userId).get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          notifications.add(NotificationModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting notifications: $e');
    }

    if (notifications.isEmpty) {
      notifications = _mockNotifications.where((n) => n.userId == userId).toList();
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
      if (notifications.isEmpty) {
        notifications = _mockNotifications.where((n) => n.userId == userId).toList();
      }
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  Future<void> markAsRead(String id) async {
    try {
      await _db.child(id).update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read, using fallback: $e');
    }

    final index = _mockNotifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final existing = _mockNotifications[index];
      _mockNotifications[index] = NotificationModel(
        id: existing.id,
        userId: existing.userId,
        title: existing.title,
        message: existing.message,
        type: existing.type,
        isRead: true,
        createdAt: existing.createdAt,
      );
    }
  }

  Future<void> clearAllNotifications(String userId) async {
    try {
      final snapshot = await _db.orderByChild('userId').equalTo(userId).get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        for (var key in data.keys) {
          await _db.child(key.toString()).remove();
        }
      }
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }

    _mockNotifications.removeWhere((n) => n.userId == userId);
  }
}
