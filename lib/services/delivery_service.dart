import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';

class DeliveryService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('bookings');
  final NotificationService _notificationService = NotificationService();

  /// Fetch all delivery bookings
  Future<List<BookingModel>> getDeliveryBookings() async {
    List<BookingModel> deliveryBookings = [];
    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 10));
      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final booking = BookingModel.fromMap(key.toString(), value);
            if (booking.isDelivery) {
              deliveryBookings.add(booking);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error getting delivery bookings: $e');
    }
    deliveryBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deliveryBookings;
  }

  /// Stream of delivery bookings
  Stream<List<BookingModel>> getDeliveryStream() {
    return _db.onValue.map((event) {
      List<BookingModel> list = [];
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final booking = BookingModel.fromMap(key.toString(), value);
            if (booking.isDelivery) {
              list.add(booking);
            }
          }
        });
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Update delivery status on a booking
  Future<void> updateDeliveryStatus({
    required String bookingId,
    required String newStatus,
    required String userId,
    required String vehicleName,
  }) async {
    return updateDeliveryDetails(
      bookingId: bookingId,
      newStatus: newStatus,
      deliveryFee: 0.0,
      userId: userId,
      vehicleName: vehicleName,
      updateFee: false,
    );
  }

  /// Update delivery status and fee on a booking
  Future<void> updateDeliveryDetails({
    required String bookingId,
    required String newStatus,
    required double deliveryFee,
    required String userId,
    required String vehicleName,
    bool updateFee = true,
  }) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      final Map<String, dynamic> updateData = {
        'deliveryStatus': newStatus,
        'updatedAt': nowIso,
      };
      if (updateFee) {
        updateData['deliveryFee'] = deliveryFee;
      }
      await _db.child(bookingId).update(updateData).timeout(const Duration(seconds: 10));

      // Notify customer
      String statusMsg = 'Your vehicle delivery status has been updated to: $newStatus.';
      if (newStatus == 'Out for Delivery') {
        statusMsg = 'Good news! Your vehicle $vehicleName is now out for delivery to your location.';
      } else if (newStatus == 'Delivered') {
        statusMsg = 'Your vehicle $vehicleName has been delivered successfully. Enjoy your ride!';
      } else if (newStatus == 'Assigned') {
        statusMsg = 'A driver has been assigned to deliver your vehicle $vehicleName.';
      }

      if (updateFee && deliveryFee > 0) {
        statusMsg += ' Delivery Fee: RM ${deliveryFee.toStringAsFixed(2)}.';
      }

      await _notificationService.createNotification(
        userId: userId,
        title: 'Delivery Status: $newStatus',
        message: statusMsg,
        type: 'delivery',
        category: 'Deliveries',
        vehicleName: vehicleName,
        bookingId: bookingId,
        icon: '🚚',
        color: '0xFF3B82F6',
        actionRoute: 'Bookings',
      );
    } catch (e) {
      debugPrint('Error updating delivery details: $e');
      rethrow;
    }
  }
}
