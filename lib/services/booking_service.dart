import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';
import 'vehicle_service.dart';
import 'reward_service.dart';
import 'receipt_service.dart';

class BookingService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('bookings');
  final VehicleService _vehicleService = VehicleService();
  final NotificationService _notificationService = NotificationService();

  Future<void> createBooking(BookingModel booking) async {
    try {
      await _db.child(booking.id).set(booking.toMap()).timeout(const Duration(seconds: 10));
      
      final bool isConfirmed = booking.status == 'Confirmed' || booking.status == 'Confirmed';

      if (isConfirmed) {
        try {
          await _vehicleService.updateVehicleStatus(booking.vehicleId, 'Booked');
        } catch (vErr) {
          debugPrint('Error auto-marking vehicle as booked: $vErr');
        }
      }

      // Create booking notification for user
      await _notificationService.createNotification(
        userId: booking.userId,
        title: isConfirmed ? 'Booking Confirmed' : 'Booking Created',
        message: isConfirmed
            ? 'Your booking for ${booking.vehicleName} is confirmed! Get ready for your rental.'
            : 'Your booking for ${booking.vehicleName} has been submitted and is pending approval.',
        type: 'booking',
        icon: '📅',
        color: isConfirmed ? '0xFF10B981' : '0xFFF59E0B',
        relatedId: booking.id,
        actionRoute: 'Dashboard',
      );

      // Create new booking notification for admins
      await _notificationService.notifyAllAdmins(
        title: isConfirmed ? 'New Confirmed Booking' : 'New Booking Received',
        message: isConfirmed
            ? '${booking.userName} booked and confirmed ${booking.vehicleName}.'
            : '${booking.userName} booked ${booking.vehicleName}.',
        type: 'booking',
        icon: '📅',
        color: isConfirmed ? '0xFF10B981' : '0xFFF59E0B',
        relatedId: booking.id,
        actionRoute: 'Bookings',
      );
    } catch (e) {
      debugPrint('Error creating booking in Realtime Database: $e');
      rethrow;
    }
  }

  Future<List<BookingModel>> getBookings() async {
    List<BookingModel> bookings = [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return bookings;

    String currentRole = 'customer';
    try {
      final roleSnap = await FirebaseDatabase.instance.ref().child('users').child(currentUid).child('role').get().timeout(const Duration(seconds: 3));
      if (roleSnap.exists) {
        currentRole = roleSnap.value.toString();
      }
    } catch (_) {}
    debugPrint('[BookingService] [getBookings] Accessing path: bookings');
    debugPrint('[BookingService] [getBookings] Current UID: $currentUid, Current Role: $currentRole');

    try {
      final DataSnapshot snapshot;
      if (currentRole == 'admin') {
        snapshot = await _db.get().timeout(const Duration(seconds: 10));
      } else {
        snapshot = await _db.orderByChild('userId').equalTo(currentUid).get().timeout(const Duration(seconds: 10));
      }

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          bookings.add(BookingModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }

      // Auto-complete ongoing/active bookings that have passed their return date
      final now = DateTime.now();
      for (int i = 0; i < bookings.length; i++) {
        final b = bookings[i];
        if ((b.status == 'ongoing' || b.status == 'active') && b.returnDate.isBefore(now)) {
          await updateBookingStatus(b.id, 'completed', b.userId, b.vehicleId, b.vehicleName);
          bookings[i] = BookingModel(
            id: b.id,
            vehicleId: b.vehicleId,
            vehicleName: b.vehicleName,
            userId: b.userId,
            userName: b.userName,
            userPhone: b.userPhone,
            pickUpDate: b.pickUpDate,
            returnDate: b.returnDate,
            totalPrice: b.totalPrice,
            depositAmount: b.depositAmount,
            status: 'completed',
            notes: b.notes,
            createdAt: b.createdAt,
          );
        }
      }

      debugPrint('[BookingService] [getBookings] Bookings count loaded: ${bookings.length}');
    } catch (e) {
      debugPrint('[BookingService] [getBookings] Error getting bookings: $e');
      rethrow;
    }
    return bookings;
  }

  Stream<List<BookingModel>> getBookingsStream() async* {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      yield [];
      return;
    }

    String currentRole = 'customer';
    try {
      final roleSnap = await FirebaseDatabase.instance.ref().child('users').child(currentUid).child('role').get().timeout(const Duration(seconds: 3));
      if (roleSnap.exists) {
        currentRole = roleSnap.value.toString();
      }
    } catch (_) {}

    final Query query = currentRole == 'admin' 
        ? _db 
        : _db.orderByChild('userId').equalTo(currentUid);

    yield* query.onValue.map((event) {
      List<BookingModel> bookings = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          bookings.add(BookingModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
      return bookings;
    });
  }

  Future<List<BookingModel>> getUserBookings(String userId) async {
    List<BookingModel> bookings = [];
    try {
      final snapshot = await _db.orderByChild('userId').equalTo(userId).get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          bookings.add(BookingModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting user bookings: $e');
      rethrow;
    }

    // Sort bookings by date descending
    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings;
  }

  Future<void> updateBookingStatus(String bookingId, String status, String userId, String vehicleId, String vehicleName) async {
    try {
      await _db.child(bookingId).update({
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));

      final String statusLower = status.toLowerCase();

      // Update vehicle status — wrapped independently so a permission error
      // on the vehicle node never rolls back the booking cancellation.
      try {
        if (statusLower == 'ongoing' || statusLower == 'active' || statusLower == 'approved' || statusLower == 'confirmed') {
          await _vehicleService.updateVehicleStatus(vehicleId, 'Booked');
        } else if (statusLower == 'completed' || statusLower == 'cancelled' || statusLower == 'rejected' || statusLower == 'pending payment') {
          await _vehicleService.updateVehicleStatus(vehicleId, 'Available');
        }
      } catch (vehicleErr) {
        debugPrint('[BookingService] Warning: vehicle status update failed (booking cancellation still succeeded): $vehicleErr');
      }

      // Create notification
      String title = 'Booking Status Updated';
      String message = 'Your booking for $vehicleName is now $status.';
      String icon = '📅';
      String color = '0xFFF59E0B'; // default orange

      if (statusLower == 'pending') {
        title = 'Booking Pending';
        message = 'Your booking for $vehicleName is pending approval.';
        color = '0xFFF59E0B'; // orange
      } else if (statusLower == 'approved' || statusLower == 'confirmed') {
        title = 'Booking Confirmed!';
        message = 'Your booking for $vehicleName is confirmed. Get ready for your rental!';
        color = '0xFF10B981'; // green
      } else if (statusLower == 'rejected') {
        title = 'Booking Rejected';
        message = 'Your booking for $vehicleName has been rejected.';
        color = '0xFFEF4444'; // red
        try {
          await RewardPointsService().refundOrCancelPointsForBooking(bookingId, userId);
        } catch (rewardErr) {
          debugPrint('[BookingService] Warning: reward points reversion failed: $rewardErr');
        }
      } else if (statusLower == 'pending payment') {
        title = 'Booking Pending Payment';
        message = 'Your booking for $vehicleName requires payment upload.';
        color = '0xFFF59E0B'; // orange
      } else if (statusLower == 'ongoing' || statusLower == 'active') {
        title = 'Rental Started';
        message = 'Your rental for $vehicleName is now active. Drive safely!';
        color = '0xFF3B82F6'; // blue
      } else if (statusLower == 'completed') {
        title = 'Rental Completed';
        message = 'Your rental for $vehicleName is complete. Thank you for renting with us!';
        color = '0xFF10B981'; // green
        
        // Also notify admins!
        await _notificationService.notifyAllAdmins(
          title: 'Booking Completed',
          message: 'Rental completed for $vehicleName (Booking: $bookingId).',
          type: 'booking',
          icon: '📅',
          color: '0xFF10B981',
          relatedId: bookingId,
          actionRoute: 'Bookings',
        );

        // Award reward points automatically
        try {
          await RewardPointsService().awardPointsForBooking(bookingId);
        } catch (rewardErr) {
          debugPrint('[BookingService] Warning: reward points award failed: $rewardErr');
        }

        // Trigger automatic receipt check & storage creation
        try {
          await ReceiptService().triggerAutomaticReceiptCheck(bookingId);
        } catch (receiptErr) {
          debugPrint('[BookingService] Warning: receipt check failed: $receiptErr');
        }
      } else if (statusLower == 'cancelled') {
        title = 'Booking Cancelled';
        message = 'Your booking for $vehicleName has been cancelled.';
        color = '0xFFEF4444'; // red
        
        try {
          await RewardPointsService().refundOrCancelPointsForBooking(bookingId, userId);
        } catch (rewardErr) {
          debugPrint('[BookingService] Warning: reward points reversion failed: $rewardErr');
        }
        
        // Also notify admins!
        String customerName = 'Customer';
        try {
          final uSnap = await FirebaseDatabase.instance.ref().child('users').child(userId).child('fullName').get();
          if (uSnap.exists) {
            customerName = uSnap.value.toString();
          }
        } catch (_) {}
        
        await _notificationService.notifyAllAdmins(
          title: 'Booking Cancelled',
          message: '$customerName cancelled booking $bookingId for $vehicleName.',
          type: 'booking',
          icon: '📅',
          color: '0xFFEF4444',
          relatedId: bookingId,
          actionRoute: 'Bookings',
        );
      }

      await _notificationService.createNotification(
        userId: userId,
        title: title,
        message: message,
        type: 'booking',
        icon: icon,
        color: color,
        relatedId: bookingId,
        actionRoute: 'Dashboard',
      );
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      rethrow;
    }
  }

  Future<void> cancelBooking(String bookingId, String userId, String vehicleId, String vehicleName) async {
    await updateBookingStatus(bookingId, 'cancelled', userId, vehicleId, vehicleName);
  }
}

