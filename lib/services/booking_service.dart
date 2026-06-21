import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
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
    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          bookings.add(BookingModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting bookings: $e');
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

      // Update vehicle availability if booking is ongoing (false) or completed/cancelled (true)
      if (status == 'ongoing') {
        await _vehicleService.toggleAvailability(vehicleId, false);
      } else if (status == 'completed' || status == 'cancelled' || status == 'rejected') {
        await _vehicleService.toggleAvailability(vehicleId, true);
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
      } else if (status == 'ongoing') {
        title = 'Rental Started';
        message = 'Your rental for $vehicleName is now ongoing. Drive safely!';
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
