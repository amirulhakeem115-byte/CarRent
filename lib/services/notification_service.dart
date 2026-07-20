import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import 'user_role_cache.dart';

class NotificationService {
  final DatabaseReference _baseDb = FirebaseDatabase.instance.ref().child(
    'notifications',
  );

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String category = 'General',
    String customerName = '',
    String vehicleName = '',
    String bookingId = '',
    String paymentId = '',
    String priority = 'normal',
    String icon = '⚙️',
    String color = '0xFF64748B',
    String relatedId = '',
    String actionRoute = 'Dashboard',
  }) async {
    final stopwatch = Stopwatch()..start();
    debugPrint(
      '[STEP 3] Calling NotificationService.createAdminNotification() (Event="$title", Target="$userId")',
    );

    try {
      final newRef = _baseDb.push();
      final finalNotification = NotificationModel(
        id: newRef.key!,
        userId: userId,
        title: title,
        message: message,
        type: type,
        category: category,
        customerName: customerName,
        vehicleName: vehicleName,
        bookingId: bookingId,
        paymentId: paymentId,
        priority: priority,
        isRead: false,
        createdAt: DateTime.now(),
        icon: icon,
        color: color,
        relatedId: relatedId,
        actionRoute: actionRoute,
      );

      debugPrint(
        '[STEP 4] Notification object created (ID="${finalNotification.id}", Title="$title", Target="$userId")',
      );
      debugPrint(
        '[STEP 5] Writing notification to Firebase at path: notifications/${newRef.key}',
      );

      await newRef
          .set(finalNotification.toMap())
          .timeout(const Duration(seconds: 10));

      stopwatch.stop();
      debugPrint(
        '[STEP 6] Firebase write successful (Ref: notifications/${newRef.key}) in ${stopwatch.elapsedMilliseconds}ms',
      );

      // Non-blocking cleanup of old notifications to keep latest 50 per user
      _cleanupOldNotifications(userId).catchError((e) {
        debugPrint('[NotificationService] Error cleaning up notifications: $e');
      });
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint(
        '[NotificationService] [FAILURE] Firebase write failed after ${stopwatch.elapsedMilliseconds}ms. '
        'Exception: $e\nStack: $stack',
      );
      rethrow;
    }
  }

  Future<void> _cleanupOldNotifications(String userId) async {
    try {
      final snapshot = await _baseDb
          .orderByChild('userId')
          .equalTo(userId)
          .get()
          .timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        if (data.length > 50) {
          List<NotificationModel> notifications = [];
          data.forEach((key, value) {
            notifications.add(
              NotificationModel.fromMap(
                key.toString(),
                value as Map<dynamic, dynamic>,
              ),
            );
          });
          notifications.sort(
            (a, b) => a.createdAt.compareTo(b.createdAt),
          ); // oldest first

          final toDeleteCount = notifications.length - 50;
          for (int i = 0; i < toDeleteCount; i++) {
            await _baseDb
                .child(notifications[i].id)
                .remove()
                .timeout(const Duration(seconds: 2));
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Async notification cleanup failed: $e');
    }
  }

  Future<List<NotificationModel>> getNotifications(
    String userId, {
    int? limit,
    bool includeAdminNotifications = true,
  }) async {
    List<NotificationModel> notifications = [];
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return notifications;

    String targetUserId = userId;
    if (userId != currentUser.uid) {
      if (!includeAdminNotifications) {
        targetUserId = currentUser.uid;
      } else {
        final currentRole = await UserRoleCache.getRole(currentUser.uid);
        if (currentRole != 'admin') {
          targetUserId = currentUser.uid;
        }
      }
    }

    try {
      Query query = _baseDb.orderByChild('userId').equalTo(targetUserId);
      if (limit != null) {
        query = query.limitToLast(limit);
      }
      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          notifications.add(
            NotificationModel.fromMap(
              key.toString(),
              value as Map<dynamic, dynamic>,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint(
        '[NotificationService] Error getting notifications with query: $e. Using node fallback.',
      );
      try {
        final fallbackSnapshot = await _baseDb.get().timeout(
          const Duration(seconds: 10),
        );
        if (fallbackSnapshot.exists && fallbackSnapshot.value != null) {
          final Map<dynamic, dynamic> data =
              fallbackSnapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            if (value is Map && value['userId']?.toString() == targetUserId) {
              notifications.add(
                NotificationModel.fromMap(key.toString(), value),
              );
            }
          });
        }
      } catch (fallbackError) {
        debugPrint(
          '[NotificationService] Fallback notification load failed: $fallbackError',
        );
        rethrow;
      }
    }

    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  Stream<List<NotificationModel>> getNotificationsStream(
    String userId, {
    int? limit,
    bool includeAdminNotifications = true,
  }) {
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
      debugPrint(
        '[TRACE STEP 8] Admin listener received notification update: Total count=${list.length}, Admin count=${adminList.length}',
      );
      if (limit != null && list.length > limit) {
        controller.add(list.take(limit).toList());
      } else {
        controller.add(list);
      }
    }

    // 1. Subscribe to personal notifications
    Query personalQuery = _baseDb
        .orderByChild('userId')
        .equalTo(currentUser.uid);
    if (limit != null) {
      personalQuery = personalQuery.limitToLast(limit);
    }
    personalSub = personalQuery.onValue.listen(
      (event) {
        personalList = [];
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final Map<dynamic, dynamic> data =
                event.snapshot.value as Map<dynamic, dynamic>;
            data.forEach((key, value) {
              personalList.add(
                NotificationModel.fromMap(
                  key.toString(),
                  value as Map<dynamic, dynamic>,
                ),
              );
            });
          } catch (e) {
            debugPrint('[NotificationService] Error parsing personal notifications: $e');
          }
        }
        emitMerged();
      },
      onError: (e) {
        debugPrint('[NotificationService] Error in personal notifications stream query: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      },
    );

    // 2. Subscribe to admin notifications if requested
    if (includeAdminNotifications) {
      Query adminQuery = _baseDb.orderByChild('userId').equalTo('admin');
      if (limit != null) {
        adminQuery = adminQuery.limitToLast(limit);
      }
      adminSub = adminQuery.onValue.listen(
        (event) {
          debugPrint('[STEP 7] Admin listener received notification from Firebase');
          adminList = [];
          if (event.snapshot.exists && event.snapshot.value != null) {
            try {
              final Map<dynamic, dynamic> data =
                  event.snapshot.value as Map<dynamic, dynamic>;
              data.forEach((key, value) {
                adminList.add(
                  NotificationModel.fromMap(
                    key.toString(),
                    value as Map<dynamic, dynamic>,
                  ),
                );
              });
            } catch (e) {
              debugPrint(
                '[NotificationService] Error parsing admin notifications: $e',
              );
            }
          }
          emitMerged();
        },
        onError: (e) {
          debugPrint(
            '[NotificationService] Error in admin notifications stream query: $e',
          );
        },
      );
    }

    controller.onCancel = () {
      personalSub?.cancel();
      adminSub?.cancel();
    };

    return controller.stream;
  }

  Future<void> markAsRead(String userId, String id) async {
    try {
      await _baseDb
          .child(id)
          .update({'isRead': true})
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[NotificationService] Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> toggleReadStatus(String userId, String id, bool isRead) async {
    try {
      await _baseDb
          .child(id)
          .update({'isRead': isRead})
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[NotificationService] Error toggling read status: $e');
      rethrow;
    }
  }

  Future<void> markAllAsRead(
    String userId, {
    bool includeAdminShared = false,
  }) async {
    try {
      final targetUserIds = <String>{userId};
      if (includeAdminShared) {
        targetUserIds.add('admin');
      }

      final Map<String, dynamic> updates = {};
      for (final targetUserId in targetUserIds) {
        final snapshot = await _baseDb
            .orderByChild('userId')
            .equalTo(targetUserId)
            .get()
            .timeout(const Duration(seconds: 10));
        if (snapshot.exists) {
          final Map<dynamic, dynamic> data =
              snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            final isReadVal = (value as Map)['isRead'] ?? false;
            if (!isReadVal) {
              updates['$key/isRead'] = true;
            }
          });
        }
      }

      if (updates.isNotEmpty) {
        await _baseDb.update(updates).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint('[NotificationService] Error marking all notifications as read: $e');
      rethrow;
    }
  }

  Future<void> clearReadNotifications(
    String userId, {
    bool includeAdminShared = false,
  }) async {
    try {
      final targetUserIds = <String>{userId};
      if (includeAdminShared) {
        targetUserIds.add('admin');
      }

      final Map<String, dynamic> updates = {};
      for (final targetUserId in targetUserIds) {
        final snapshot = await _baseDb
            .orderByChild('userId')
            .equalTo(targetUserId)
            .get()
            .timeout(const Duration(seconds: 10));
        if (snapshot.exists) {
          final Map<dynamic, dynamic> data =
              snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            final isReadVal = (value as Map)['isRead'] ?? false;
            if (isReadVal) {
              updates[key.toString()] = null; // delete
            }
          });
        }
      }
      if (updates.isNotEmpty) {
        await _baseDb.update(updates).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint('[NotificationService] Error clearing read notifications: $e');
      rethrow;
    }
  }

  Future<void> deleteNotification(String userId, String id) async {
    try {
      await _baseDb.child(id).remove().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[NotificationService] Error deleting notification: $e');
      rethrow;
    }
  }

  Future<void> clearAllNotifications(String userId) async {
    try {
      final snapshot = await _baseDb
          .orderByChild('userId')
          .equalTo(userId)
          .get()
          .timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> updates = {};
        data.forEach((key, value) {
          updates[key.toString()] = null; // delete
        });
        if (updates.isNotEmpty) {
          await _baseDb.update(updates).timeout(const Duration(seconds: 10));
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error clearing notifications: $e');
      rethrow;
    }
  }

  Future<void> notifyAllCustomers({
    required String title,
    required String message,
    required String type,
    String category = 'General',
    String icon = '⚙️',
    String color = '0xFF64748B',
    String relatedId = '',
    String actionRoute = 'Dashboard',
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final currentRole = await UserRoleCache.getRole(currentUser.uid);
      if (currentRole != 'admin') {
        debugPrint(
          '[NotificationService] [notifyAllCustomers] Customer user cannot read user list to notify customers. Skipping.',
        );
        return;
      }

      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> users =
            snapshot.value as Map<dynamic, dynamic>;
        for (var entry in users.entries) {
          final userData = entry.value as Map<dynamic, dynamic>;
          final role = userData['role'] ?? 'customer';
          if (role == 'customer') {
            await createNotification(
              userId: entry.key.toString(),
              title: title,
              message: message,
              type: type,
              category: category,
              icon: icon,
              color: color,
              relatedId: relatedId,
              actionRoute: actionRoute,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error notifying all customers: $e');
    }
  }

  Future<void> notifyAllAdmins({
    required String title,
    required String message,
    required String type,
    String category = 'General',
    String customerName = '',
    String vehicleName = '',
    String bookingId = '',
    String paymentId = '',
    String priority = 'normal',
    String icon = '⚙️',
    String color = '0xFF64748B',
    String relatedId = '',
    String actionRoute = 'Dashboard',
  }) async {
    try {
      debugPrint(
        '[TRACE STEP 4] notifyAllAdmins invoked: Title="$title", Category="$category", BookingId="$bookingId"',
      );

      // Write notification to centralized 'admin' topic
      await createNotification(
        userId: 'admin',
        title: title,
        message: message,
        type: type,
        category: category,
        customerName: customerName,
        vehicleName: vehicleName,
        bookingId: bookingId,
        paymentId: paymentId,
        priority: priority,
        icon: icon,
        color: color,
        relatedId: relatedId,
        actionRoute: actionRoute,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error notifying all admins: $e');
    }
  }

  // =========================================================================
  // CENTRALIZED EVENT HELPER METHODS FOR EVERY SYSTEM ACTIVITY
  // =========================================================================

  /// 1. BOOKINGS EVENT HELPER
  Future<void> notifyBookingEvent({
    required String eventName,
    required String customerName,
    required String vehicleName,
    required String bookingId,
    required String details,
    bool isUpcoming = false,
    String priority = 'normal',
    String icon = '📅',
    String color = '0xFF3B82F6',
    String actionRoute = 'Bookings',
  }) async {
    final title = isUpcoming
        ? 'Upcoming Booking Created'
        : 'Booking Event: $eventName';
    final message = isUpcoming
        ? '$customerName booked $vehicleName (Booking #${bookingId.toUpperCase()}). $details'
        : '$customerName - $vehicleName: $details (Booking #${bookingId.toUpperCase()}).';

    await notifyAllAdmins(
      title: title,
      message: message,
      type: 'booking',
      category: 'Bookings',
      customerName: customerName,
      vehicleName: vehicleName,
      bookingId: bookingId,
      priority: priority,
      icon: icon,
      color: color,
      relatedId: bookingId,
      actionRoute: actionRoute,
    );
  }

  /// 2. OPEN RENTAL & LIFECYCLE EVENT HELPER
  Future<void> notifyOpenRentalEvent({
    required String eventName,
    required String customerName,
    required String vehicleName,
    required String bookingId,
    required String details,
    String priority = 'high',
    String icon = '🚗',
    String color = '0xFF10B981',
    String actionRoute = 'Bookings',
  }) async {
    await notifyAllAdmins(
      title: 'Open Rental: $eventName',
      message: '$customerName ($vehicleName): $details (Booking #${bookingId.toUpperCase()}).',
      type: 'open_rental',
      category: 'Open Rental',
      customerName: customerName,
      vehicleName: vehicleName,
      bookingId: bookingId,
      priority: priority,
      icon: icon,
      color: color,
      relatedId: bookingId,
      actionRoute: actionRoute,
    );
  }

  /// 3. PAYMENTS EVENT HELPER
  Future<void> notifyPaymentEvent({
    required String eventName,
    required String customerName,
    required String bookingId,
    required String paymentId,
    required double amount,
    required String details,
    String priority = 'normal',
    String icon = '💳',
    String color = '0xFF10B981',
    String actionRoute = 'Payments',
  }) async {
    await notifyAllAdmins(
      title: 'Payment: $eventName',
      message: '$customerName paid RM ${amount.toStringAsFixed(2)}. $details (Booking #${bookingId.toUpperCase()}).',
      type: 'payment',
      category: 'Payments',
      customerName: customerName,
      bookingId: bookingId,
      paymentId: paymentId,
      priority: priority,
      icon: icon,
      color: color,
      relatedId: paymentId.isNotEmpty ? paymentId : bookingId,
      actionRoute: actionRoute,
    );
  }

  /// 4. CUSTOMERS EVENT HELPER
  Future<void> notifyCustomerEvent({
    required String eventName,
    required String customerName,
    required String customerUid,
    required String details,
    String priority = 'normal',
    String icon = '👤',
    String color = '0xFF8B5CF6',
    String actionRoute = 'Customers',
  }) async {
    await notifyAllAdmins(
      title: 'Customer: $eventName',
      message: '$customerName ($customerUid): $details',
      type: 'customer',
      category: 'Customers',
      customerName: customerName,
      priority: priority,
      icon: icon,
      color: color,
      relatedId: customerUid,
      actionRoute: actionRoute,
    );
  }

  /// 5. VEHICLES & MAINTENANCE EVENT HELPER
  Future<void> notifyVehicleEvent({
    required String eventName,
    required String vehicleId,
    required String vehicleName,
    required String details,
    String priority = 'normal',
    String icon = '🚘',
    String color = '0xFFF59E0B',
    String actionRoute = 'Vehicles',
  }) async {
    await notifyAllAdmins(
      title: 'Vehicle Alert: $eventName',
      message: '$vehicleName: $details',
      type: 'vehicle',
      category: 'Vehicles',
      vehicleName: vehicleName,
      priority: priority,
      icon: icon,
      color: color,
      relatedId: vehicleId,
      actionRoute: actionRoute,
    );
  }

  /// 6. PROMOTIONS EVENT HELPER
  Future<void> notifyPromotionEvent({
    required String eventName,
    required String promoId,
    required String promoCode,
    required String promoName,
    required String details,
    String priority = 'normal',
    String icon = '🏷️',
    String color = '0xFFEC4899',
    String actionRoute = 'Promotions',
  }) async {
    await notifyAllAdmins(
      title: 'Promotion: $eventName',
      message: 'Code "$promoCode" ($promoName): $details',
      type: 'promotion',
      category: 'Promotions',
      priority: priority,
      icon: icon,
      color: color,
      relatedId: promoId,
      actionRoute: actionRoute,
    );
  }
}
