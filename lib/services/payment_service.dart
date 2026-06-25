import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment_model.dart';
import 'notification_service.dart';
import 'booking_service.dart';

class PaymentService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('payments');
  final NotificationService _notificationService = NotificationService();

  Future<void> createPayment(PaymentModel payment) async {
    try {
      final newRef = _db.push();
      final paymentData = payment.toMap();
      paymentData['id'] = newRef.key!;
      await newRef.set(paymentData).timeout(const Duration(seconds: 10));

      // Notify user of transaction submission
      await _notificationService.createNotification(
        userId: payment.userId,
        title: 'Payment Processed',
        message: 'Your payment of RM ${payment.amount.toStringAsFixed(2)} is complete.',
        type: 'payment',
      );
    } catch (e) {
      debugPrint('Error creating payment: $e');
      rethrow;
    }
  }

  Future<List<PaymentModel>> getPayments() async {
    List<PaymentModel> payments = [];
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
    debugPrint('[PaymentService] [getPayments] Accessing path: payments');
    debugPrint('[PaymentService] [getPayments] Current UID: $currentUid, Current Role: $currentRole');

    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          payments.add(PaymentModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
      debugPrint('[PaymentService] [getPayments] Payments count loaded: ${payments.length}');
    } catch (e) {
      debugPrint('[PaymentService] [getPayments] Error getting payments: $e');
      rethrow;
    }

    payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return payments;
  }

  Stream<List<PaymentModel>> getPaymentsStream() {
    return _db.onValue.map((event) {
      List<PaymentModel> payments = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          payments.add(PaymentModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
      payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      return payments;
    });
  }

  Future<List<PaymentModel>> getUserPayments(String userId) async {
    List<PaymentModel> payments = [];
    try {
      final snapshot = await _db.orderByChild('userId').equalTo(userId).get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          payments.add(PaymentModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting user payments: $e');
      rethrow;
    }
    payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return payments;
  }

  Future<void> updatePaymentStatus(String paymentId, String status, String userId, {String reason = '', String? verifiedBy}) async {
    try {
      final isApproved = status == 'paid' || status == 'Approved';
      final dbStatus = isApproved ? 'paid' : 'failed';
      final dbPaymentStatus = isApproved ? 'Approved' : 'Rejected';

      await _db.child(paymentId).update({
        'status': dbStatus,
        'paymentStatus': dbPaymentStatus,
        'verifiedAt': DateTime.now().toIso8601String(),
        'verifiedBy': verifiedBy ?? 'admin',
        'rejectionReason': isApproved ? '' : reason,
      }).timeout(const Duration(seconds: 10));

      // Get payment record to extract booking ID and update booking automatically
      final paySnap = await _db.child(paymentId).get().timeout(const Duration(seconds: 5));
      if (paySnap.exists) {
        final payData = paySnap.value as Map<dynamic, dynamic>;
        final bookingId = payData['bookingId'] as String?;
        if (bookingId != null && bookingId.isNotEmpty) {
          final bookingSnap = await FirebaseDatabase.instance.ref().child('bookings').child(bookingId).get().timeout(const Duration(seconds: 5));
          if (bookingSnap.exists) {
            final bookingData = bookingSnap.value as Map<dynamic, dynamic>;
            final vehicleId = bookingData['vehicleId'] as String?;
            final vehicleName = bookingData['vehicleName'] as String?;
            if (vehicleId != null && vehicleName != null) {
              final bookingService = BookingService();
              if (isApproved) {
                await bookingService.updateBookingStatus(bookingId, 'approved', userId, vehicleId, vehicleName);
              } else {
                await bookingService.updateBookingStatus(bookingId, 'rejected', userId, vehicleId, vehicleName);
              }
            }
          }
        }
      }

      await _notificationService.createNotification(
        userId: userId,
        title: isApproved ? 'Payment Verified Successfully' : 'Payment Rejected',
        message: isApproved 
            ? 'Your payment has been verified successfully.' 
            : 'Your payment was rejected. Please upload a valid receipt.',
        type: 'payment',
      );
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      rethrow;
    }
  }

  Future<void> refundPayment(String paymentId, String userId, double amount) async {
    try {
      await _db.child(paymentId).update({
        'status': 'refunded',
        'refundDate': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));

      await _notificationService.createNotification(
        userId: userId,
        title: 'Refund Processed',
        message: 'A refund of RM ${amount.toStringAsFixed(2)} has been issued to your account.',
        type: 'payment',
      );
    } catch (e) {
      debugPrint('Error refunding payment: $e');
      rethrow;
    }
  }
}
