import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';
import 'vehicle_service.dart';

class BookingService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('bookings');
  final VehicleService _vehicleService = VehicleService();
  final NotificationService _notificationService = NotificationService();

  static final List<BookingModel> _mockBookings = [
    BookingModel(
      id: 'mock_bk1',
      userId: 'demo_customer',
      userName: 'Demo Customer',
      userPhone: '+60123456789',
      vehicleId: 'mock_v2',
      vehicleName: 'Proton X50',
      pickUpDate: DateTime.now().add(const Duration(days: 1)),
      returnDate: DateTime.now().add(const Duration(days: 4)),
      totalPrice: 660.0,
      depositAmount: 150.0,
      status: 'approved',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    BookingModel(
      id: 'mock_bk2',
      userId: 'demo_customer',
      userName: 'Demo Customer',
      userPhone: '+60123456789',
      vehicleId: 'mock_v1',
      vehicleName: 'Perodua Myvi',
      pickUpDate: DateTime.now().subtract(const Duration(days: 5)),
      returnDate: DateTime.now().subtract(const Duration(days: 2)),
      totalPrice: 390.0,
      depositAmount: 150.0,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
  ];

  Future<void> createBooking(BookingModel booking) async {
    try {
      await _db.child(booking.id).set(booking.toMap());
    } catch (e) {
      debugPrint('Error creating booking, using fallback: $e');
    }

    _mockBookings.removeWhere((b) => b.id == booking.id);
    _mockBookings.add(booking);

    // Create booking notification for user
    await _notificationService.createNotification(
      userId: booking.userId,
      title: 'Booking Pending',
      message: 'Your booking for ${booking.vehicleName} has been submitted and is pending approval.',
      type: 'booking',
    );
  }

  Future<List<BookingModel>> getBookings() async {
    List<BookingModel> bookings = [];
    try {
      final snapshot = await _db.get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          bookings.add(BookingModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting bookings: $e');
    }

    if (bookings.isEmpty) {
      bookings = List.from(_mockBookings);
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
      if (bookings.isEmpty) {
        bookings = List.from(_mockBookings);
      }
      return bookings;
    });
  }

  Future<List<BookingModel>> getUserBookings(String userId) async {
    List<BookingModel> bookings = [];
    try {
      final snapshot = await _db.orderByChild('userId').equalTo(userId).get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          bookings.add(BookingModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting user bookings: $e');
    }

    if (bookings.isEmpty) {
      bookings = _mockBookings.where((b) => b.userId == userId).toList();
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
      });
    } catch (e) {
      debugPrint('Error updating booking status, using fallback: $e');
    }

    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final existing = _mockBookings[index];
      _mockBookings[index] = BookingModel(
        id: existing.id,
        userId: existing.userId,
        userName: existing.userName,
        userPhone: existing.userPhone,
        vehicleId: existing.vehicleId,
        vehicleName: existing.vehicleName,
        pickUpDate: existing.pickUpDate,
        returnDate: existing.returnDate,
        totalPrice: existing.totalPrice,
        depositAmount: existing.depositAmount,
        status: status,
        createdAt: existing.createdAt,
        notes: existing.notes,
      );
    }

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
  }

  Future<void> cancelBooking(String bookingId, String userId, String vehicleId, String vehicleName) async {
    await updateBookingStatus(bookingId, 'cancelled', userId, vehicleId, vehicleName);
  }
}
