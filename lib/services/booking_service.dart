import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';
import 'vehicle_service.dart';

class BookingService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('bookings');
  final VehicleService _vehicleService = VehicleService();
  final NotificationService _notificationService = NotificationService();

  Future<void> createBooking(BookingModel booking) async {
    try {
      await _db.child(booking.id).set(booking.toMap()).timeout(const Duration(seconds: 10));
      
      // Create booking notification for user
      await _notificationService.createNotification(
        userId: booking.userId,
        title: 'Booking Pending',
        message: 'Your booking for ${booking.vehicleName} has been submitted and is pending approval.',
        type: 'booking',
      );
    } catch (e) {
      debugPrint('Error creating booking in Realtime Database: $e');
      rethrow;
    }
  }

  Future<List<BookingModel>> getBookings() async {
    List<BookingModel> bookings = [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    String currentRole = 'unknown';
    if (currentUid != null) {
      try {
        final roleSnap = await FirebaseDatabase.instance.ref().child('users').child(currentUid).child('role').get().timeout(const Duration(seconds: 3));
        if (roleSnap.exists) {
          currentRole = roleSnap.value.toString();
        }
      } catch (_) {}
    }
    debugPrint('[BookingService] [getBookings] Accessing path: bookings');
    debugPrint('[BookingService] [getBookings] Current UID: $currentUid, Current Role: $currentRole');

    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 10));
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

  Stream<List<BookingModel>> getBookingsStream() {
    return _db.onValue.map((event) {
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

      // Update vehicle status in database based on booking transition
      if (status == 'ongoing' || status == 'active' || status == 'approved') {
        await _vehicleService.updateVehicleStatus(vehicleId, 'booked');
      } else if (status == 'completed' || status == 'cancelled' || status == 'rejected') {
        await _vehicleService.updateVehicleStatus(vehicleId, 'available');
      }

      // Create notification
      String title = 'Booking Status Updated';
      String message = 'Your booking for $vehicleName is now $status.';
      if (status == 'approved') {
        title = 'Booking Approved!';
        message = 'Your booking for $vehicleName has been approved. Please pay the deposit to lock your dates.';
      } else if (status == 'rejected') {
        title = 'Booking Rejected';
        message = 'Your booking request for $vehicleName was not accepted.';
      } else if (status == 'ongoing' || status == 'active') {
        title = 'Rental Started';
        message = 'Your rental for $vehicleName is now active. Drive safely!';
      } else if (status == 'completed') {
        title = 'Rental Completed';
        message = 'Your rental for $vehicleName is complete. Thank you for renting with us!';
      }

      await _notificationService.createNotification(
        userId: userId,
        title: title,
        message: message,
        type: 'booking',
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
