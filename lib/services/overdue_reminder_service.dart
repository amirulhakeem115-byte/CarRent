import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';
import 'booking_service.dart';

class OverdueReminderService {
  static final OverdueReminderService _instance =
      OverdueReminderService._internal();
  factory OverdueReminderService() => _instance;
  OverdueReminderService._internal();

  Timer? _timer;
  bool _isChecking = false;

  /// Start background periodic monitoring (checks every 60 seconds)
  void startMonitoring() {
    if (_timer != null && _timer!.isActive) return;
    debugPrint('[OverdueReminderService] Starting background late return monitoring timer (60s)...');
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      checkOverdueRentals();
    });
    // Run an initial check immediately
    checkOverdueRentals();
  }

  /// Stop background monitoring
  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    debugPrint('[OverdueReminderService] Background late return monitoring stopped.');
  }

  /// Evaluates all active, ongoing, and overdue rentals against server return timestamps
  Future<void> checkOverdueRentals() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final now = DateTime.now();
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('bookings')
          .get()
          .timeout(const Duration(seconds: 10));

      if (!snapshot.exists || snapshot.value == null) {
        _isChecking = false;
        return;
      }

      final Map<dynamic, dynamic> data =
          snapshot.value as Map<dynamic, dynamic>;

      for (var entry in data.entries) {
        final bookingId = entry.key.toString();
        final rawMap = Map<dynamic, dynamic>.from(entry.value as Map);
        final booking = BookingModel.fromMap(bookingId, rawMap);

        final status = booking.status.toLowerCase();
        final isCompletedOrCancelled =
            status == 'completed' || status == 'cancelled' || status == 'rejected';

        // Immediately stop sending reminders if booking is completed or cancelled
        if (isCompletedOrCancelled) continue;

        // Skip if return date is not set (e.g. open rental without return request)
        if (booking.returnDate == null) continue;

        final returnDate = booking.returnDate!;

        // Check if return time has passed
        if (now.isAfter(returnDate)) {
          final minutesOverdue = now.difference(returnDate).inMinutes;
          if (minutesOverdue < 0) continue;

          // 2-hour interval slot calculation:
          // Slot 0: 0 - 119 minutes (exact return time arrived)
          // Slot 1: 120 - 239 minutes (2 hours overdue)
          // Slot 2: 240 - 359 minutes (4 hours overdue)
          // Slot 3: 360 - 479 minutes (6 hours overdue)...
          final int slotIndex = (minutesOverdue / 120).floor();

          final Map<dynamic, dynamic> sentSlots =
              rawMap['overdueReminderSlots'] is Map
                  ? Map<dynamic, dynamic>.from(rawMap['overdueReminderSlots'] as Map)
                  : {};

          final bool alreadySent = sentSlots.containsKey(slotIndex.toString());

          if (!alreadySent) {
            await _dispatchOverdueReminder(
              booking: booking,
              slotIndex: slotIndex,
              minutesOverdue: minutesOverdue,
              returnDate: returnDate,
              now: now,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[OverdueReminderService] Error checking overdue rentals: $e');
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _dispatchOverdueReminder({
    required BookingModel booking,
    required int slotIndex,
    required int minutesOverdue,
    required DateTime returnDate,
    required DateTime now,
  }) async {
    final hoursOverdue = (minutesOverdue / 60.0).floor();
    final returnTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(returnDate);

    // Fetch vehicle price per day to calculate accurate overdue charges estimate
    double pricePerDay = 120.0;
    try {
      final vSnap = await FirebaseDatabase.instance
          .ref()
          .child('vehicles')
          .child(booking.vehicleId)
          .get();
      if (vSnap.exists && vSnap.value != null) {
        pricePerDay =
            ((vSnap.value as Map)['pricePerDay'] ?? 120.0).toDouble();
      }
    } catch (_) {}

    final lateFees = BookingService.calculateOverdueCharges(
      booking,
      pricePerDay,
      now: now,
    );

    String title;
    String message;

    if (slotIndex == 0) {
      title = '⚠️ Return Time Arrived';
      message =
          'Your vehicle return time for ${booking.vehicleName} has arrived ($returnTimeStr). '
          'Please return the vehicle immediately to avoid overdue charges.';
    } else if (slotIndex == 1) {
      title = '⚠️ Rental 2 Hours Overdue';
      message =
          'Your vehicle ${booking.vehicleName} is 2 hours overdue (Return was $returnTimeStr). '
          'Estimated late fee: RM ${lateFees.toStringAsFixed(2)}. Please return it immediately.';
    } else {
      title = '⚠️ Rental Overdue (${hoursOverdue}h Overdue)';
      message =
          'Reminder: Your rental for ${booking.vehicleName} is $hoursOverdue hours overdue '
          '(Return time: $returnTimeStr). Estimated late fee: RM ${lateFees.toStringAsFixed(2)}. '
          'Please click "Return Vehicle" or contact support immediately.';
    }

    debugPrint(
      '[OverdueReminderService] [DISPATCH] Sending Slot $slotIndex reminder to user ${booking.userId} '
      'for Booking #${booking.id} (${hoursOverdue}h overdue)',
    );

    final notificationService = NotificationService();

    // 1. Dispatch Customer Reminder Notification
    await notificationService.createNotification(
      userId: booking.userId,
      title: title,
      message: message,
      type: 'overdue_reminder',
      category: 'Open Rental',
      customerName: booking.userName,
      vehicleName: booking.vehicleName,
      bookingId: booking.id,
      priority: 'high',
      icon: '⚠️',
      color: '0xFFEF4444',
      relatedId: booking.id,
      actionRoute: 'MyBookings',
    );

    // 2. Dispatch Admin Notification Alert
    await notificationService.notifyOpenRentalEvent(
      eventName: slotIndex == 0
          ? 'Return Time Reached'
          : 'Rental Overdue (${hoursOverdue}h Overdue)',
      customerName: booking.userName,
      vehicleName: booking.vehicleName,
      bookingId: booking.id,
      details: slotIndex == 0
          ? 'return time ($returnTimeStr) reached. Vehicle not yet returned.'
          : 'rental is ${hoursOverdue}h overdue (Return was $returnTimeStr). Est. late fee: RM ${lateFees.toStringAsFixed(2)}.',
      priority: 'high',
      icon: '⚠️',
      color: '0xFFEF4444',
    );

    // 3. Record sent slot in Firebase to prevent duplicate reminders across app restarts
    try {
      final updates = {
        'overdueReminderSlots/$slotIndex': now.toIso8601String(),
        'lastOverdueReminderSlot': slotIndex,
        'lastOverdueReminderSentAt': now.toIso8601String(),
        'status': 'Overdue',
      };
      await FirebaseDatabase.instance
          .ref()
          .child('bookings')
          .child(booking.id)
          .update(updates)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[OverdueReminderService] Error recording reminder slot in DB: $e');
    }
  }
}
