import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';
import 'user_role_cache.dart';

class AdminBookingObserverService {
  static final AdminBookingObserverService _instance = AdminBookingObserverService._internal();
  factory AdminBookingObserverService() => _instance;
  AdminBookingObserverService._internal();

  final DatabaseReference _bookingsRef = FirebaseDatabase.instance.ref().child('bookings');
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<DatabaseEvent>? _addedSubscription;
  StreamSubscription<DatabaseEvent>? _changedSubscription;
  bool _isObserving = false;

  /// Start observing booking changes under Admin authority
  Future<void> startObserving() async {
    if (_isObserving) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final role = await UserRoleCache.getRole(currentUser.uid);
    final roleLower = role.toLowerCase();
    if (roleLower != 'admin' && roleLower != 'super_admin') {
      debugPrint('[AdminBookingObserverService] Current user is not Admin ($role). Observer inactive.');
      return;
    }

    _isObserving = true;
    debugPrint('[AdminBookingObserverService] Initializing real-time booking observer for Admin UID: ${currentUser.uid}');

    _addedSubscription = _bookingsRef.onChildAdded.listen(_processBookingEvent, onError: (e) {
      debugPrint('[AdminBookingObserverService] Error listening onChildAdded: $e');
    });

    _changedSubscription = _bookingsRef.onChildChanged.listen(_processBookingEvent, onError: (e) {
      debugPrint('[AdminBookingObserverService] Error listening onChildChanged: $e');
    });
  }

  void stopObserving() {
    _addedSubscription?.cancel();
    _changedSubscription?.cancel();
    _addedSubscription = null;
    _changedSubscription = null;
    _isObserving = false;
    debugPrint('[AdminBookingObserverService] Booking observer stopped.');
  }

  Future<void> _processBookingEvent(DatabaseEvent event) async {
    if (event.snapshot.value == null) return;

    try {
      final bookingId = event.snapshot.key;
      if (bookingId == null || bookingId.isEmpty) return;

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final booking = BookingModel.fromMap(bookingId, data);
      final notifiedEvents = data['notifiedEvents'] as Map<dynamic, dynamic>? ?? {};

      // 1. Customer On The Way Event
      final customerStatus = (data['customerStatus'] ?? '').toString().toLowerCase();
      if (customerStatus == 'on_my_way' && notifiedEvents['on_my_way'] != true) {
        await _markEventNotified(bookingId, 'on_my_way');
        final bool isPickup = booking.status.toLowerCase() != 'active' &&
                              booking.status.toLowerCase() != 'ongoing' &&
                              booking.status.toLowerCase() != 'overdue';
        await _notificationService.notifyOpenRentalEvent(
          eventName: isPickup ? "Customer On The Way for Pickup 🚗" : "Customer On The Way for Return 🚗",
          customerName: booking.userName,
          vehicleName: booking.vehicleName,
          bookingId: booking.id,
          details: isPickup
              ? 'is on the way to pick up ${booking.vehicleName}.'
              : 'is on the way to return ${booking.vehicleName}. Please prepare for inspection.',
          priority: 'high',
          icon: '🚗',
          color: '0xFF10B981',
        );
      }

      // 2. Customer Return Request Event
      final status = booking.status;
      final statusLower = status.toLowerCase();
      if ((statusLower == 'return requested' || statusLower == 'awaiting return inspection') &&
          notifiedEvents['return_requested'] != true) {
        await _markEventNotified(bookingId, 'return_requested');
        await _notificationService.notifyOpenRentalEvent(
          eventName: 'Customer Submitted Return Request',
          customerName: booking.userName,
          vehicleName: booking.vehicleName,
          bookingId: booking.id,
          details: 'submitted Return Request for ${booking.vehicleName}. Please schedule vehicle inspection.',
          priority: 'high',
          icon: '🚗',
          color: '0xFF3B82F6',
        );
      }

      // 3. New Booking Event
      if ((statusLower == 'pending' || statusLower == 'approved' || statusLower == 'confirmed') &&
          notifiedEvents['new_booking'] != true) {
        await _markEventNotified(bookingId, 'new_booking');
        final bool isUpcoming = booking.pickUpDate.isAfter(DateTime.now().add(const Duration(days: 1)));
        await _notificationService.notifyBookingEvent(
          eventName: statusLower == 'confirmed' ? 'Booking Confirmed' : (isUpcoming ? 'Upcoming Booking Created' : 'New Booking Received'),
          customerName: booking.userName,
          vehicleName: booking.vehicleName,
          bookingId: booking.id,
          details: 'created a booking for ${booking.vehicleName}.',
          isUpcoming: isUpcoming,
          priority: 'high',
          icon: '📅',
          color: '0xFF3B82F6',
        );
      }
    } catch (e) {
      debugPrint('[AdminBookingObserverService] Error processing booking event: $e');
    }
  }

  Future<void> _markEventNotified(String bookingId, String eventKey) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = currentUser?.uid ?? 'unauthenticated';
      final role = currentUser != null ? await UserRoleCache.getRole(currentUser.uid) : 'unauthenticated';
      debugPrint('[FIREBASE WRITE TRACE] Function="_markEventNotified", Path="bookings/$bookingId/notifiedEvents/$eventKey", UID="$uid", Role="$role"');
      await _bookingsRef.child(bookingId).child('notifiedEvents').child(eventKey).set(true);
    } catch (e) {
      debugPrint('[AdminBookingObserverService] Error setting notified event flag: $e');
    }
  }
}
