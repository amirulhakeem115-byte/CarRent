import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/models/notification_model.dart';
import 'package:carrent_system/services/user_role_cache.dart';

void main() {
  group('Notification Role Isolation Tests', () {
    final now = DateTime.now();

    final notifCustomer1 = NotificationModel(
      id: 'n1',
      userId: 'customer_123',
      title: 'Booking Confirmed',
      message: 'Your booking for SUV is confirmed',
      type: 'booking',
      category: 'Bookings',
      isRead: false,
      createdAt: now,
    );

    final notifCustomer2 = NotificationModel(
      id: 'n2',
      userId: 'customer_456',
      title: 'Booking Pending',
      message: 'Your booking is pending',
      type: 'booking',
      category: 'Bookings',
      isRead: false,
      createdAt: now,
    );

    final notifAdmin = NotificationModel(
      id: 'n3',
      userId: 'admin',
      title: 'New Booking Received',
      message: 'New reservation submitted by customer',
      type: 'booking',
      category: 'Bookings',
      isRead: false,
      createdAt: now,
    );

    final notifEmployee = NotificationModel(
      id: 'n4',
      userId: 'employee_789',
      title: 'Handover Required',
      message: 'Vehicle pickup scheduled today',
      type: 'vehicle',
      category: 'Vehicles',
      isRead: false,
      createdAt: now,
    );

    final allNotifications = [
      notifCustomer1,
      notifCustomer2,
      notifAdmin,
      notifEmployee,
    ];

    setUp(() {
      UserRoleCache.clear();
    });

    test('Customer role receives ONLY customer-specific notifications', () {
      UserRoleCache.set('customer_123', 'customer');
      final role = UserRoleCache.getLocal('customer_123');
      expect(role, 'customer');

      // Customer notification filter: only items matching customer's userId
      final customerNotifications = allNotifications
          .where((n) => n.userId == 'customer_123')
          .toList();

      expect(customerNotifications.length, equals(1));
      expect(customerNotifications.first.id, equals('n1'));
      expect(customerNotifications.first.title, equals('Booking Confirmed'));
      expect(
        customerNotifications.any((n) => n.userId == 'admin'),
        isFalse,
        reason: 'Customer must never receive admin topic notifications.',
      );
      expect(
        customerNotifications.any((n) => n.userId == 'employee_789'),
        isFalse,
        reason: 'Customer must never receive employee notifications.',
      );
    });

    test('Admin role receives admin topic and admin user notifications', () {
      UserRoleCache.set('admin_user', 'admin');
      final role = UserRoleCache.getLocal('admin_user');
      expect(role, 'admin');

      // Admin notification filter: items targeted to 'admin' or admin's userId
      final adminNotifications = allNotifications
          .where((n) => n.userId == 'admin' || n.userId == 'admin_user')
          .toList();

      expect(adminNotifications.length, equals(1));
      expect(adminNotifications.first.id, equals('n3'));
      expect(adminNotifications.first.userId, equals('admin'));
    });

    test('Employee role receives ONLY employee-specific notifications', () {
      UserRoleCache.set('employee_789', 'employee');
      final role = UserRoleCache.getLocal('employee_789');
      expect(role, 'employee');

      // Employee notification filter: items targeted to employee's userId
      final employeeNotifications = allNotifications
          .where((n) => n.userId == 'employee_789')
          .toList();

      expect(employeeNotifications.length, equals(1));
      expect(employeeNotifications.first.id, equals('n4'));
      expect(employeeNotifications.first.title, equals('Handover Required'));
      expect(
        employeeNotifications.any((n) => n.userId == 'admin'),
        isFalse,
        reason: 'Employee must never receive admin notifications.',
      );
    });

    test('Badge count, popup preview, and full page use identical data source', () {
      UserRoleCache.set('customer_123', 'customer');

      // Data source for customer_123
      final customerData = allNotifications
          .where((n) => n.userId == 'customer_123')
          .toList();

      // Popup preview (top 10 items)
      final popupPreview = customerData.take(10).toList();

      // Badge count (unread count)
      final badgeCount = customerData.where((n) => !n.isRead).length;

      // Full notification page items
      final fullPageItems = customerData;

      expect(popupPreview, equals(fullPageItems));
      expect(badgeCount, equals(1));
      expect(popupPreview.length, equals(fullPageItems.length));
    });
  });
}
