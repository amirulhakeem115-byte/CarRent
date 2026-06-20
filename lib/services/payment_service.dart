import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/payment_model.dart';
import 'notification_service.dart';

class PaymentService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('payments');
  final NotificationService _notificationService = NotificationService();

  static final List<PaymentModel> _mockPayments = [
    PaymentModel(
      id: 'mock_pay1',
      bookingId: 'mock_bk1',
      userId: 'demo_customer',
      amount: 150.0,
      depositAmount: 150.0,
      balanceAmount: 0.0,
      paymentMethod: 'Credit Card',
      paymentDate: DateTime.now().subtract(const Duration(days: 2)),
      status: 'completed',
    ),
    PaymentModel(
      id: 'mock_pay2',
      bookingId: 'mock_bk2',
      userId: 'demo_customer',
      amount: 390.0,
      depositAmount: 150.0,
      balanceAmount: 240.0,
      paymentMethod: 'Bank Transfer',
      paymentDate: DateTime.now().subtract(const Duration(days: 5)),
      status: 'completed',
    ),
  ];

  Future<void> createPayment(PaymentModel payment) async {
    try {
      final newRef = _db.push();
      final paymentData = payment.toMap();
      await newRef.set(paymentData);
    } catch (e) {
      debugPrint('Error creating payment, using fallback: $e');
    }

    _mockPayments.add(payment);

    // Notify user of transaction submission
    await _notificationService.createNotification(
      userId: payment.userId,
      title: 'Payment Processed',
      message: 'Your payment of RM ${payment.amount.toStringAsFixed(2)} is complete.',
      type: 'payment',
    );
  }

  Future<List<PaymentModel>> getPayments() async {
    List<PaymentModel> payments = [];
    try {
      final snapshot = await _db.get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          payments.add(PaymentModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting payments: $e');
    }

    if (payments.isEmpty) {
      payments = List.from(_mockPayments);
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
      if (payments.isEmpty) {
        payments = List.from(_mockPayments);
      }
      payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      return payments;
    });
  }

  Future<List<PaymentModel>> getUserPayments(String userId) async {
    List<PaymentModel> payments = [];
    try {
      final snapshot = await _db.orderByChild('userId').equalTo(userId).get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          payments.add(PaymentModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting user payments: $e');
    }

    if (payments.isEmpty) {
      payments = _mockPayments.where((p) => p.userId == userId).toList();
    }
    payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return payments;
  }

  Future<void> updatePaymentStatus(String paymentId, String status, String userId) async {
    try {
      await _db.child(paymentId).update({
        'status': status,
      });
    } catch (e) {
      debugPrint('Error updating payment status, using fallback: $e');
    }

    final index = _mockPayments.indexWhere((p) => p.id == paymentId);
    if (index != -1) {
      final existing = _mockPayments[index];
      _mockPayments[index] = PaymentModel(
        id: existing.id,
        bookingId: existing.bookingId,
        userId: existing.userId,
        amount: existing.amount,
        depositAmount: existing.depositAmount,
        balanceAmount: existing.balanceAmount,
        paymentMethod: existing.paymentMethod,
        paymentDate: existing.paymentDate,
        status: status,
      );
    }

    await _notificationService.createNotification(
      userId: userId,
      title: 'Payment Update',
      message: 'Your transaction status has been updated to $status.',
      type: 'payment',
    );
  }

  Future<void> refundPayment(String paymentId, String userId, double amount) async {
    try {
      await _db.child(paymentId).update({
        'status': 'refunded',
        'refundDate': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error refunding payment, using fallback: $e');
    }

    final index = _mockPayments.indexWhere((p) => p.id == paymentId);
    if (index != -1) {
      final existing = _mockPayments[index];
      _mockPayments[index] = PaymentModel(
        id: existing.id,
        bookingId: existing.bookingId,
        userId: existing.userId,
        amount: existing.amount,
        depositAmount: existing.depositAmount,
        balanceAmount: existing.balanceAmount,
        paymentMethod: existing.paymentMethod,
        paymentDate: existing.paymentDate,
        status: 'refunded',
        refundDate: DateTime.now(),
      );
    }

    await _notificationService.createNotification(
      userId: userId,
      title: 'Refund Processed',
      message: 'A refund of RM ${amount.toStringAsFixed(2)} has been issued to your account.',
      type: 'payment',
    );
  }
}
