import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment_model.dart';
import 'notification_service.dart';
import 'booking_service.dart';
import 'reward_service.dart';
import 'receipt_service.dart';
import 'user_role_cache.dart';
import 'company_settings_provider.dart';

class PaymentService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child(
    'payments',
  );
  final NotificationService _notificationService = NotificationService();

  Future<void> createPayment(PaymentModel payment) async {
    try {
      final newRef = _db.push();
      final paymentData = payment.toMap();
      paymentData['id'] = newRef.key!;

      final isApproved =
          payment.paymentStatus == 'Approved' ||
          payment.status == 'paid' ||
          payment.status == 'Approved' ||
          payment.paymentStatus == 'Paid';

      if (isApproved) {
        paymentData['rewardPointsAwarded'] = true;
      } else {
        paymentData['rewardPointsAwarded'] = false;
      }

      await newRef.set(paymentData).timeout(const Duration(seconds: 10));

      // Award reward points automatically if the payment is approved/completed immediately
      if (isApproved) {
        try {
          await RewardPointsService().awardPointsForPayment(
            userId: payment.userId,
            bookingId: payment.bookingId,
            paymentAmount: payment.amount,
            paymentId: newRef.key!,
          );
        } catch (rewardErr) {
          debugPrint(
            'Error auto-awarding reward points on payment creation: $rewardErr',
          );
        }
      }

      // Fetch booking details to include customer name and vehicle name
      String customerName = 'Customer';
      String vehicleName = 'Vehicle';
      String? currentBookingStatus;
      String? vehicleId;
      try {
        final bSnap = await FirebaseDatabase.instance
            .ref()
            .child('bookings')
            .child(payment.bookingId)
            .get();
        if (bSnap.exists) {
          final bData = bSnap.value as Map;
          customerName = bData['userName'] ?? 'Customer';
          vehicleName = bData['vehicleName'] ?? 'Vehicle';
          currentBookingStatus = bData['status'] as String?;
          vehicleId = bData['vehicleId'] as String?;
        }
      } catch (e) {
        debugPrint('Error getting booking info for payment notification: $e');
      }

      if (isApproved &&
          currentBookingStatus == 'Awaiting Final Payment' &&
          vehicleId != null) {
        try {
          final bookingService = BookingService();
          await bookingService.updateBookingStatus(
            payment.bookingId,
            'completed',
            payment.userId,
            vehicleId,
            vehicleName,
          );

          try {
            await FirebaseDatabase.instance
                .ref()
                .child('vehicles')
                .child(vehicleId)
                .update({'status': 'Available'});
          } catch (vErr) {
            debugPrint(
              'Error updating vehicle to Available on final payment creation: $vErr',
            );
          }

          // Award reward points automatically if enabled
          final rewardsEnabled =
              CompanySettingsProvider().getField(
                    'rewardsEnabled',
                    defaultValue: true,
                  )
                  as bool;
          if (rewardsEnabled) {
            try {
              await RewardPointsService().awardPointsForBooking(
                payment.bookingId,
              );
            } catch (rewardErr) {
              debugPrint(
                'Error awarding reward points on final invoice clearance: $rewardErr',
              );
            }
          }

          // Trigger automatic receipt check
          try {
            await ReceiptService().triggerAutomaticReceiptCheck(
              payment.bookingId,
            );
          } catch (receiptErr) {
            debugPrint(
              'Error generating receipt on final invoice clearance: $receiptErr',
            );
          }
        } catch (e) {
          debugPrint('Error processing final payment booking update: $e');
        }
      }

      if (isApproved) {
        // Notify user of transaction approval
        await _notificationService.createNotification(
          userId: payment.userId,
          title: 'Payment Approved',
          message:
              'Your payment of RM ${payment.amount.toStringAsFixed(2)} has been approved successfully.',
          type: 'payment',
          icon: '💳',
          color: '0xFF10B981',
          relatedId: newRef.key!,
          actionRoute: 'Dashboard',
        );

        // Notify admins of auto-approved payment
        await _notificationService.notifyPaymentEvent(
          eventName: 'Payment Approved Automatically',
          customerName: customerName,
          bookingId: payment.bookingId,
          paymentId: newRef.key!,
          amount: payment.amount,
          details: 'for vehicle $vehicleName.',
          priority: 'normal',
          icon: '💳',
          color: '0xFF10B981',
        );
      } else {
        // Notify user their payment is pending review
        await _notificationService.createNotification(
          userId: payment.userId,
          title: 'Payment Pending Review',
          message:
              'Your payment of RM ${payment.amount.toStringAsFixed(2)} has been submitted and is awaiting admin verification.',
          type: 'payment',
          category: 'Payments',
          customerName: customerName,
          vehicleName: vehicleName,
          bookingId: payment.bookingId,
          paymentId: newRef.key!,
          icon: '🕐',
          color: '0xFFF59E0B',
          relatedId: newRef.key!,
          actionRoute: 'Dashboard',
        );

        // Notify admins of new payment requiring verification
        await _notificationService.notifyPaymentEvent(
          eventName: 'New Payment — Action Required',
          customerName: customerName,
          bookingId: payment.bookingId,
          paymentId: newRef.key!,
          amount: payment.amount,
          details: 'submitted payment for $vehicleName. Verification required.',
          priority: 'high',
          icon: '💳',
          color: '0xFFF59E0B',
        );
      }
    } catch (e) {
      debugPrint('Error creating payment: $e');
      rethrow;
    }
  }

  Future<List<PaymentModel>> getPayments() async {
    List<PaymentModel> payments = [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return payments;

    final currentRole = await UserRoleCache.getRole(currentUid);
    debugPrint('[PaymentService] [getPayments] Accessing path: payments');
    debugPrint(
      '[PaymentService] [getPayments] Current UID: $currentUid, Current Role: $currentRole',
    );

    try {
      final DataSnapshot snapshot;
      if (currentRole == 'admin') {
        snapshot = await _db.get().timeout(const Duration(seconds: 10));
      } else {
        snapshot = await _db
            .orderByChild('userId')
            .equalTo(currentUid)
            .get()
            .timeout(const Duration(seconds: 10));
      }

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          payments.add(
            PaymentModel.fromMap(
              key.toString(),
              value as Map<dynamic, dynamic>,
            ),
          );
        });
      }
      debugPrint(
        '[PaymentService] [getPayments] Payments count loaded: ${payments.length}',
      );
    } catch (e) {
      debugPrint('[PaymentService] [getPayments] Error getting payments: $e');
      rethrow;
    }

    payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return payments;
  }

  Stream<List<PaymentModel>> getPaymentsStream() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return Stream.value([]);
    }

    final controller = StreamController<List<PaymentModel>>.broadcast();
    StreamSubscription? sub;

    UserRoleCache.getRole(currentUid)
        .then((currentRole) {
          if (controller.isClosed) return;
          debugPrint(
            '[PaymentService] getPaymentsStream — uid: $currentUid, role: $currentRole',
          );

          final Query query = currentRole == 'admin'
              ? _db
              : _db.orderByChild('userId').equalTo(currentUid);

          sub = query.onValue.listen(
            (event) {
              if (controller.isClosed) return;
              List<PaymentModel> payments = [];
              if (event.snapshot.exists) {
                final Map<dynamic, dynamic> data =
                    event.snapshot.value as Map<dynamic, dynamic>;
                data.forEach((key, value) {
                  payments.add(
                    PaymentModel.fromMap(
                      key.toString(),
                      value as Map<dynamic, dynamic>,
                    ),
                  );
                });
              }
              payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
              controller.add(payments);
            },
            onError: (e) {
              debugPrint('[PaymentService] getPaymentsStream error: $e');
              if (!controller.isClosed) controller.add([]);
            },
          );
        })
        .catchError((e) {
          debugPrint('[PaymentService] getPaymentsStream role fetch error: $e');
          if (!controller.isClosed) controller.add([]);
        });

    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }

  Future<List<PaymentModel>> getUserPayments(String userId) async {
    List<PaymentModel> payments = [];
    try {
      final snapshot = await _db
          .orderByChild('userId')
          .equalTo(userId)
          .get()
          .timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          payments.add(
            PaymentModel.fromMap(
              key.toString(),
              value as Map<dynamic, dynamic>,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Error getting user payments with filtered query: $e');

      // Fallback: some Realtime Database rule/query combinations reject
      // orderBy/equalTo requests even when simple reads are allowed.
      // Try reading the payments node and filtering client-side.
      try {
        final fallbackSnapshot = await _db.get().timeout(
          const Duration(seconds: 10),
        );
        if (fallbackSnapshot.exists) {
          final Map<dynamic, dynamic> data =
              fallbackSnapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            final row = Map<dynamic, dynamic>.from(value as Map);
            if (row['userId']?.toString() == userId) {
              payments.add(PaymentModel.fromMap(key.toString(), row));
            }
          });
        }
      } catch (fallbackError) {
        debugPrint('Fallback payment load also failed: $fallbackError');
        rethrow;
      }
    }
    payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return payments;
  }

  Future<void> updatePaymentStatus(
    String paymentId,
    String status,
    String userId, {
    String reason = '',
    String? verifiedBy,
  }) async {
    try {
      final isApproved = status == 'paid' || status == 'Approved';
      final dbPaymentStatus = isApproved ? 'Approved' : 'Rejected';

      // Check if reward points have already been awarded for this payment
      final paySnap = await _db
          .child(paymentId)
          .get()
          .timeout(const Duration(seconds: 5));
      bool alreadyAwarded = false;
      double paymentAmount = 0.0;
      String bookingId = '';
      if (paySnap.exists) {
        final payData = paySnap.value as Map<dynamic, dynamic>;
        alreadyAwarded = payData['rewardPointsAwarded'] == true;
        paymentAmount = double.tryParse(payData['amount'].toString()) ?? 0.0;
        bookingId = payData['bookingId'] ?? '';
      }

      await _db
          .child(paymentId)
          .update({
            'status': dbPaymentStatus,
            'paymentStatus': dbPaymentStatus,
            'verifiedAt': DateTime.now().toIso8601String(),
            'verifiedBy': verifiedBy ?? 'admin',
            'rejectionReason': isApproved ? '' : reason,
            'rewardPointsAwarded': isApproved ? true : alreadyAwarded,
          })
          .timeout(const Duration(seconds: 10));

      // Award points automatically if newly approved and not already awarded
      if (isApproved && !alreadyAwarded) {
        try {
          await RewardPointsService().awardPointsForPayment(
            userId: userId,
            bookingId: bookingId,
            paymentAmount: paymentAmount,
            paymentId: paymentId,
          );
        } catch (rewardErr) {
          debugPrint(
            'Error auto-awarding reward points on payment status update: $rewardErr',
          );
        }
      }

      // Get payment record to extract booking ID and update booking automatically
      final freshPaySnap = await _db
          .child(paymentId)
          .get()
          .timeout(const Duration(seconds: 5));
      if (freshPaySnap.exists) {
        final payData = freshPaySnap.value as Map<dynamic, dynamic>;
        final bookingId = payData['bookingId'] as String?;
        if (bookingId != null && bookingId.isNotEmpty) {
          final bookingSnap = await FirebaseDatabase.instance
              .ref()
              .child('bookings')
              .child(bookingId)
              .get()
              .timeout(const Duration(seconds: 5));
          if (bookingSnap.exists) {
            final bookingData = bookingSnap.value as Map<dynamic, dynamic>;
            final vehicleId = bookingData['vehicleId'] as String?;
            final vehicleName = bookingData['vehicleName'] as String?;
            if (vehicleId != null && vehicleName != null) {
              final bookingService = BookingService();
              final currentBookingStatus = bookingData['status'] as String?;
              final bool isFinalPaymentFlow =
                  currentBookingStatus == 'Awaiting Final Payment';

              if (isApproved) {
                if (isFinalPaymentFlow) {
                  // Final payment approved -> Complete booking, make vehicle available
                  await bookingService.updateBookingStatus(
                    bookingId,
                    'completed',
                    userId,
                    vehicleId,
                    vehicleName,
                  );
                  try {
                    await FirebaseDatabase.instance
                        .ref()
                        .child('vehicles')
                        .child(vehicleId)
                        .update({'status': 'Available'});
                  } catch (vErr) {
                    debugPrint(
                      'Error updating vehicle to Available on final payment clearance: $vErr',
                    );
                  }

                  // Award reward points automatically if enabled
                  final rewardsEnabled =
                      CompanySettingsProvider().getField(
                            'rewardsEnabled',
                            defaultValue: true,
                          )
                          as bool;
                  if (rewardsEnabled) {
                    try {
                      await RewardPointsService().awardPointsForBooking(
                        bookingId,
                      );
                    } catch (rewardErr) {
                      debugPrint(
                        'Error awarding reward points on final invoice clearance: $rewardErr',
                      );
                    }
                  }

                  // Trigger automatic receipt check
                  try {
                    await ReceiptService().triggerAutomaticReceiptCheck(
                      bookingId,
                    );
                  } catch (receiptErr) {
                    debugPrint(
                      'Error generating receipt on final invoice clearance: $receiptErr',
                    );
                  }
                } else {
                  // Upfront payment approved -> Confirm booking
                  await bookingService.updateBookingStatus(
                    bookingId,
                    'Confirmed',
                    userId,
                    vehicleId,
                    vehicleName,
                  );
                  // Deduct redeemed reward points if any
                  try {
                    await RewardPointsService().deductPointsForBooking(
                      bookingId,
                    );
                  } catch (rewardErr) {
                    debugPrint(
                      '[PaymentService] Warning: reward points deduction failed: $rewardErr',
                    );
                  }
                  // Trigger automatic receipt check & storage creation
                  try {
                    await ReceiptService().triggerAutomaticReceiptCheck(
                      bookingId,
                    );
                  } catch (receiptErr) {
                    debugPrint(
                      '[PaymentService] Warning: receipt check failed: $receiptErr',
                    );
                  }
                }
              } else {
                if (isFinalPaymentFlow) {
                  // Keep status as Awaiting Final Payment
                  // Nothing extra to do, status remains 'Awaiting Final Payment'
                } else {
                  await bookingService.updateBookingStatus(
                    bookingId,
                    'Pending Payment',
                    userId,
                    vehicleId,
                    vehicleName,
                  );
                }
              }
            }
          }
        }
      }

      // Retrieve customer name if possible
      String customerName = 'Customer';
      try {
        final uSnap = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(userId)
            .child('fullName')
            .get();
        if (uSnap.exists) {
          customerName = uSnap.value.toString();
        }
      } catch (_) {}

      // Notify user
      await _notificationService.createNotification(
        userId: userId,
        title: isApproved ? 'Payment Approved' : 'Payment Rejected',
        message: isApproved
            ? 'Your payment has been approved.'
            : 'Your payment was rejected. Reason: $reason',
        type: 'payment',
        category: 'Payments',
        customerName: customerName,
        paymentId: paymentId,
        icon: '💳',
        color: isApproved ? '0xFF10B981' : '0xFFEF4444',
        relatedId: paymentId,
        actionRoute: 'Dashboard',
      );

      final payAmount = (paySnap.value as Map)['amount'] != null
          ? ((paySnap.value as Map)['amount'] as num).toDouble()
          : 0.0;
      final bookingIdStr =
          (paySnap.value as Map)['bookingId']?.toString() ?? '';

      // Notify admins
      await _notificationService.notifyPaymentEvent(
        eventName: isApproved ? 'Payment Approved' : 'Payment Rejected',
        customerName: customerName,
        bookingId: bookingIdStr,
        paymentId: paymentId,
        amount: payAmount,
        details: isApproved
            ? 'payment approved.'
            : 'payment rejected. Reason: $reason',
        priority: isApproved ? 'normal' : 'high',
        icon: '💳',
        color: isApproved ? '0xFF10B981' : '0xFFEF4444',
      );
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      rethrow;
    }
  }

  Future<void> refundPayment(
    String paymentId,
    String userId,
    double amount,
  ) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      await _db
          .child(paymentId)
          .update({
            'status': 'refunded',
            'paymentStatus': 'Refunded',
            'refundDate': nowIso,
          })
          .timeout(const Duration(seconds: 10));

      String customerName = 'Customer';
      try {
        final uSnap = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(userId)
            .child('fullName')
            .get();
        if (uSnap.exists) {
          customerName = uSnap.value.toString();
        }
      } catch (_) {}

      await _notificationService.createNotification(
        userId: userId,
        title: 'Refund Processed',
        message:
            'A refund of RM ${amount.toStringAsFixed(2)} has been issued to your account.',
        type: 'payment',
        category: 'Payments',
        customerName: customerName,
        paymentId: paymentId,
        icon: '💳',
        color: '0xFF3B82F6',
        relatedId: paymentId,
        actionRoute: 'Dashboard',
      );

      String bookingIdStr = '';
      try {
        final paySnap = await _db.child(paymentId).get();
        if (paySnap.exists) {
          bookingIdStr = (paySnap.value as Map)['bookingId']?.toString() ?? '';
        }
      } catch (_) {}

      // A full refund means this booking should no longer remain ongoing.
      if (bookingIdStr.isNotEmpty) {
        try {
          final bookingRef = FirebaseDatabase.instance
              .ref()
              .child('bookings')
              .child(bookingIdStr);
          final bookingSnap = await bookingRef.get();

          if (bookingSnap.exists && bookingSnap.value is Map) {
            final bookingData = Map<dynamic, dynamic>.from(
              bookingSnap.value as Map,
            );

            final bookingStatus = (bookingData['status'] ?? '')
                .toString()
                .toLowerCase();
            final bookingUserId = (bookingData['userId'] ?? userId).toString();
            final vehicleId = (bookingData['vehicleId'] ?? '').toString();
            final vehicleName = (bookingData['vehicleName'] ?? 'Vehicle')
                .toString();

            final shouldCancel =
                bookingStatus != 'completed' &&
                bookingStatus != 'cancelled' &&
                bookingStatus != 'rejected';

            if (shouldCancel) {
              if (vehicleId.isNotEmpty) {
                await BookingService().updateBookingStatus(
                  bookingIdStr,
                  'cancelled',
                  bookingUserId,
                  vehicleId,
                  vehicleName,
                  isAutomatic: true,
                );
              } else {
                await bookingRef.update({
                  'status': 'cancelled',
                  'updatedAt': nowIso,
                });
              }

              await bookingRef.update({
                'customerStatus': 'cancelled',
                'refundLinkedPaymentId': paymentId,
                'refundTimestamp': nowIso,
              });
            }
          }
        } catch (bookingErr) {
          debugPrint(
            'Warning: refund processed but booking cancellation sync failed: $bookingErr',
          );
        }
      }

      await _notificationService.notifyPaymentEvent(
        eventName: 'Refund Processed',
        customerName: customerName,
        bookingId: bookingIdStr,
        paymentId: paymentId,
        amount: amount,
        details:
            'refund of RM ${amount.toStringAsFixed(2)} processed for Booking #${bookingIdStr.toUpperCase()}.',
        priority: 'high',
        icon: '💳',
        color: '0xFF3B82F6',
      );
    } catch (e) {
      debugPrint('Error refunding payment: $e');
      rethrow;
    }
  }
}
