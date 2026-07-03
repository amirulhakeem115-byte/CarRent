import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/booking_model.dart';
import 'booking_service.dart';
import 'notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_session.dart';

class BookingLifecycleManager {
  static final BookingLifecycleManager _instance = BookingLifecycleManager._internal();
  factory BookingLifecycleManager() => _instance;
  BookingLifecycleManager._internal();

  DatabaseReference get _db => FirebaseDatabase.instance.ref();
  BookingService get _bookingService => BookingService();
  NotificationService get _notificationService => NotificationService();
  bool _isProcessing = false;
  Timer? _periodicTimer;

  void startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      checkAndProcessLifecycle();
    });
    debugPrint('[BookingLifecycleManager] Started periodic lifecycle checks.');
    // Run immediately on start
    checkAndProcessLifecycle();
  }

  void stopPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    debugPrint('[BookingLifecycleManager] Stopped periodic lifecycle checks.');
  }

  Future<void> checkAndProcessLifecycle() async {
    if (Firebase.apps.isEmpty) {
      return;
    }
    if (FirebaseAuth.instance.currentUser == null || !UserSession().isInitialized) {
      debugPrint('[BookingLifecycleManager] Skipping check — user is not authenticated or role is not loaded.');
      return;
    }
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final now = DateTime.now();
      final DataSnapshot snapshot = await _db.child('bookings').get().timeout(const Duration(seconds: 10));
      if (!snapshot.exists || snapshot.value == null) {
        _isProcessing = false;
        return;
      }

      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      final List<BookingModel> bookings = [];
      data.forEach((key, value) {
        try {
          bookings.add(BookingModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        } catch (e) {
          debugPrint('[BookingLifecycleManager] Error parsing booking $key: $e');
        }
      });

      for (final booking in bookings) {
        final String statusLower = booking.status.toLowerCase();
        
        // 1. Pickup Reminder (1 hour before pickup date/time)
        if (statusLower == 'confirmed' || statusLower == 'approved') {
          final difference = booking.pickUpDate.difference(now);
          final bool pickupReminderSent = booking.pickupReminderSent;
          
          if (!pickupReminderSent && difference.inMinutes > 0 && difference.inMinutes <= 60) {
            debugPrint('[BookingLifecycleManager] Sending 1 hour pickup reminder for booking ${booking.id}');
            // Mark as sent in DB first to prevent duplicate sends
            await _db.child('bookings').child(booking.id).update({'pickupReminderSent': true});
            
            // Notify customer
            await _notificationService.createNotification(
              userId: booking.userId,
              title: "Pick-up Reminder 🚗",
              message: "Your vehicle pickup is in one hour.",
              type: 'pickup_reminder_customer',
              icon: '🚗',
              color: '0xFFF59E0B',
              relatedId: booking.id,
              actionRoute: 'Dashboard',
            );

            // Notify admin
            await _notificationService.notifyAllAdmins(
              title: "Customer Pick-up Scheduled 🚗",
              message: "Customer pickup is scheduled in one hour.",
              type: 'pickup_reminder_admin',
              icon: '🚗',
              color: '0xFF3B82F6',
              relatedId: booking.id,
              actionRoute: 'Bookings',
            );
          }
        }
        
        // 2. Return Reminder (1 hour before return date/time)
        if (statusLower == 'active' || statusLower == 'ongoing') {
          final difference = booking.returnDate.difference(now);
          final bool returnReminderSent = booking.returnReminderSent;
          
          if (!returnReminderSent && difference.inMinutes > 0 && difference.inMinutes <= 60) {
            debugPrint('[BookingLifecycleManager] Sending 1 hour return reminder for booking ${booking.id}');
            // Mark as sent in DB
            await _db.child('bookings').child(booking.id).update({'returnReminderSent': true});
            
            // Notify customer
            await _notificationService.createNotification(
              userId: booking.userId,
              title: "Rental Ending Soon ⚠️",
              message: "Your rental ends in one hour.",
              type: 'return_reminder_customer',
              icon: '⚠️',
              color: '0xFFEF4444',
              relatedId: booking.id,
              actionRoute: 'Dashboard',
            );

            // Notify admin
            await _notificationService.notifyAllAdmins(
              title: "Vehicle Return Due ⚠️",
              message: "Vehicle return is due in one hour.",
              type: 'return_reminder_admin',
              icon: '⚠️',
              color: '0xFFF59E0B',
              relatedId: booking.id,
              actionRoute: 'Bookings',
            );
          }
        }

        // 3. Status Transitions (active/ongoing/overdue)
        if (statusLower == 'active' || statusLower == 'ongoing' || statusLower == 'overdue') {
          // Case 1: Vehicle is marked as returned (returned early or returned on time)
          if (booking.isReturned) {
            if (statusLower != 'completed') {
              debugPrint('[BookingLifecycleManager] Automatically completing booking ${booking.id} (isReturned is true)');
              await _bookingService.updateBookingStatus(
                booking.id,
                'completed',
                booking.userId,
                booking.vehicleId,
                booking.vehicleName,
                isAutomatic: true,
              );
            }
          }
          // Case 2: Return datetime has passed and isReturned is false
          else if (now.isAfter(booking.returnDate) || now.isAtSameMomentAs(booking.returnDate)) {
            if (statusLower != 'overdue') {
              debugPrint('[BookingLifecycleManager] Transitioning booking ${booking.id} to OVERDUE');
              await _bookingService.updateBookingStatus(
                booking.id,
                'overdue',
                booking.userId,
                booking.vehicleId,
                booking.vehicleName,
                isAutomatic: true,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[BookingLifecycleManager] Error during lifecycle verification: $e');
    } finally {
      _isProcessing = false;
    }
  }
}
