import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/payment_model.dart';
import 'notification_service.dart';

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
    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          payments.add(PaymentModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting payments: $e');
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

  Future<void> updatePaymentStatus(String paymentId, String status, String userId) async {
    try {
      await _db.child(paymentId).update({
        'status': status,
      }).timeout(const Duration(seconds: 10));

      await _notificationService.createNotification(
        userId: userId,
        title: 'Payment Update',
        message: 'Your transaction status has been updated to $status.',
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
