import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';
import 'user_role_cache.dart';

class RewardPointsService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();

  // Reusable points earning formula: RM 10 = 1 Point
  int calculateEarnedPoints(double totalPrice) {
    return (totalPrice / 10).floor();
  }

  // Reusable points discount formula: 10 points = RM 1.00 (or 1 point = RM 0.10)
  double calculateDiscount(int points) {
    return points * 0.10;
  }

  // Fetch current user reward points balance
  Future<int> getUserPoints(String userId) async {
    try {
      final snap = await _db.child('users').child(userId).child('rewardPoints').get();
      if (snap.exists && snap.value != null) {
        return int.tryParse(snap.value.toString()) ?? 0;
      }
    } catch (e) {
      debugPrint('Error getting user reward points: $e');
    }
    return 0;
  }

  // Stream of reward transactions for a user (defensive parsing)
  Stream<List<Map<String, dynamic>>> getUserTransactionsStream(String userId) {
    return _db
        .child('reward_transactions')
        .child(userId)
        .onValue
        .map((event) {
      final List<Map<String, dynamic>> txs = [];
      try {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final rawVal = event.snapshot.value;
          if (rawVal is Map) {
            rawVal.forEach((key, value) {
              if (value is Map) {
                try {
                  final tx = Map<String, dynamic>.from(value);
                  tx['id'] = key.toString();
                  tx['userId'] = userId;
                  txs.add(tx);
                } catch (e) {
                  debugPrint('Error parsing transaction node: $e');
                }
              }
            });
          } else if (rawVal is List) {
            for (int i = 0; i < rawVal.length; i++) {
              final value = rawVal[i];
              if (value is Map) {
                try {
                  final tx = Map<String, dynamic>.from(value);
                  tx['id'] = i.toString();
                  tx['userId'] = userId;
                  txs.add(tx);
                } catch (e) {
                  debugPrint('Error parsing transaction list item: $e');
                }
              }
            }
          }
        }
        // Sort newest first safely
        txs.sort((a, b) {
          final aTime = (a['createdAt'] ?? '').toString();
          final bTime = (b['createdAt'] ?? '').toString();
          return bTime.compareTo(aTime);
        });
      } catch (e) {
        debugPrint('Error processing getUserTransactionsStream: $e');
      }
      return txs;
    });
  }

  // Stream of all reward transactions (for admin ledger view) (defensive parsing)
  Stream<List<Map<String, dynamic>>> getAllTransactionsStream() async* {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    final String currentRole = await UserRoleCache.getRole(currentUser.uid);

    if (currentRole == 'admin') {
      yield* _db.child('reward_transactions').onValue.map((event) {
        final List<Map<String, dynamic>> txs = [];
        try {
          if (event.snapshot.exists && event.snapshot.value != null) {
            final rawVal = event.snapshot.value;
            if (rawVal is Map) {
              rawVal.forEach((userKey, userTxsValue) {
                if (userTxsValue is Map) {
                  userTxsValue.forEach((txKey, txValue) {
                    if (txValue is Map) {
                      try {
                        final tx = Map<String, dynamic>.from(txValue);
                        tx['id'] = txKey.toString();
                        tx['userId'] = userKey.toString();
                        txs.add(tx);
                      } catch (e) {
                        debugPrint('Error parsing transaction node in getAllTransactionsStream: $e');
                      }
                    }
                  });
                } else if (userTxsValue is List) {
                  for (int i = 0; i < userTxsValue.length; i++) {
                    final txValue = userTxsValue[i];
                    if (txValue is Map) {
                      try {
                        final tx = Map<String, dynamic>.from(txValue);
                        tx['id'] = i.toString();
                        tx['userId'] = userKey.toString();
                        txs.add(tx);
                      } catch (e) {
                        debugPrint('Error parsing transaction list item in getAllTransactionsStream: $e');
                      }
                    }
                  }
                }
              });
            }
          }
          txs.sort((a, b) {
            final aTime = (a['createdAt'] ?? '').toString();
            final bTime = (b['createdAt'] ?? '').toString();
            return bTime.compareTo(aTime);
          });
        } catch (e) {
          debugPrint('Error in getAllTransactionsStream: $e');
        }
        return txs;
      });
    } else {
      yield* _db.child('reward_transactions').child(currentUser.uid).onValue.map((event) {
        final List<Map<String, dynamic>> txs = [];
        try {
          if (event.snapshot.exists && event.snapshot.value != null) {
            final rawVal = event.snapshot.value;
            if (rawVal is Map) {
              rawVal.forEach((key, value) {
                if (value is Map) {
                  try {
                    final tx = Map<String, dynamic>.from(value);
                    tx['id'] = key.toString();
                    tx['userId'] = currentUser.uid;
                    txs.add(tx);
                  } catch (e) {
                    debugPrint('Error parsing transaction node: $e');
                  }
                }
              });
            } else if (rawVal is List) {
              for (int i = 0; i < rawVal.length; i++) {
                final value = rawVal[i];
                if (value is Map) {
                  try {
                    final tx = Map<String, dynamic>.from(value);
                    tx['id'] = i.toString();
                    tx['userId'] = currentUser.uid;
                    txs.add(tx);
                  } catch (e) {
                    debugPrint('Error parsing transaction list item: $e');
                  }
                }
              }
            }
          }
          txs.sort((a, b) {
            final aTime = (a['createdAt'] ?? '').toString();
            final bTime = (b['createdAt'] ?? '').toString();
            return bTime.compareTo(aTime);
          });
        } catch (e) {
          debugPrint('Error processing getAllTransactionsStream (customer fallback): $e');
        }
        return txs;
      });
    }
  }

  // Automatically award points to customer after successfully completing a payment
  Future<void> awardPointsForPayment({
    required String userId,
    required String bookingId,
    required double paymentAmount,
    required String paymentId,
  }) async {
    try {
      // Calculate earned points (1 point for every RM10 spent)
      final int earned = calculateEarnedPoints(paymentAmount);
      if (earned <= 0) return;

      // Update user points balance in users/$userId/rewardPoints
      final int balanceAfter = await _updateUserBalance(userId, earned);

      // Create transaction log under reward_transactions/$userId/$transactionId
      final txRef = _db.child('reward_transactions').child(userId).push();
      final txData = {
        'userId': userId,
        'bookingId': bookingId,
        'paymentId': paymentId,
        'type': 'Earned',
        'points': earned,
        'paymentAmount': paymentAmount,
        'balanceAfter': balanceAfter,
        'status': 'Completed',
        'createdAt': DateTime.now().toIso8601String(),
      };
      await txRef.set(txData);

      // Update bookings node to mark rewardPointsAwarded = true to prevent double earning on completion
      if (bookingId.isNotEmpty) {
        await _db.child('bookings').child(bookingId).update({
          'rewardPointsAwarded': true,
        });
      }

      // Notify customer
      await _notificationService.createNotification(
        userId: userId,
        title: 'Points Earned! ⭐',
        message: 'You have earned $earned reward points for payment of RM ${paymentAmount.toStringAsFixed(2)}!',
        type: 'reward',
        icon: '⭐',
        color: '0xFFF97316',
        relatedId: bookingId,
        actionRoute: 'Dashboard',
      );
    } catch (e) {
      debugPrint('[RewardPointsService] Error awarding points for payment: $e');
      rethrow;
    }
  }

  // Update user rewardPoints balance atomically using Realtime Database transaction
  Future<int> _updateUserBalance(String userId, int pointsChange) async {
    final balanceRef = _db.child('users').child(userId).child('rewardPoints');
    final result = await balanceRef.runTransaction((Object? currentPoints) {
      int points = 0;
      if (currentPoints != null) {
        points = int.tryParse(currentPoints.toString()) ?? 0;
      }
      points += pointsChange;
      if (points < 0) points = 0; // Prevent negative balances
      return Transaction.success(points);
    });

    if (result.committed) {
      return (result.snapshot.value as int? ?? 0);
    } else {
      throw Exception('Failed to update reward points balance transaction');
    }
  }

  // Award points to customer for completed, paid booking
  Future<void> awardPointsForBooking(String bookingId) async {
    try {
      // Load booking
      final bookingSnap = await _db.child('bookings').child(bookingId).get();
      if (!bookingSnap.exists) {
        debugPrint('[RewardPointsService] Booking not found: $bookingId');
        return;
      }

      final bookingMap = bookingSnap.value as Map<dynamic, dynamic>;
      final booking = BookingModel.fromMap(bookingId, bookingMap);

      if (booking.rewardPointsAwarded) {
        debugPrint('[RewardPointsService] Booking $bookingId already awarded points.');
        return;
      }

      // Calculate earned points
      final int earned = calculateEarnedPoints(booking.totalPrice);
      if (earned <= 0) return;

      // Update user points balance
      final int balanceAfter = await _updateUserBalance(booking.userId, earned);

      // Create transaction log
      final txRef = _db.child('reward_transactions').child(booking.userId).push();
      final txData = {
        'userId': booking.userId,
        'bookingId': bookingId,
        'type': 'Earn',
        'points': earned,
        'balanceAfter': balanceAfter,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await txRef.set(txData);

      // Set rewardPointsAwarded = true on booking
      await _db.child('bookings').child(bookingId).update({
        'rewardPointsAwarded': true,
      });

      // Notify customer
      await _notificationService.createNotification(
        userId: booking.userId,
        title: 'Points Earned! ⭐',
        message: 'You have earned $earned reward points for completing rental ${booking.vehicleName}!',
        type: 'reward',
        icon: '⭐',
        color: '0xFFF97316',
        relatedId: bookingId,
        actionRoute: 'Dashboard',
      );
    } catch (e) {
      debugPrint('[RewardPointsService] Error awarding points for booking: $e');
      rethrow;
    }
  }

  // Deduct redeemed points from customer's balance after payment approval
  Future<void> deductPointsForBooking(String bookingId) async {
    try {
      // Load booking
      final bookingSnap = await _db.child('bookings').child(bookingId).get();
      if (!bookingSnap.exists) {
        debugPrint('[RewardPointsService] Booking not found: $bookingId');
        return;
      }

      final bookingMap = bookingSnap.value as Map<dynamic, dynamic>;
      final booking = BookingModel.fromMap(bookingId, bookingMap);

      if (booking.pointsRedeemed <= 0) return;

      if (booking.pointsRedeemedProcessed) {
        debugPrint('[RewardPointsService] Redeemed points already processed for booking $bookingId.');
        return;
      }

      // Update user points balance
      final int balanceAfter = await _updateUserBalance(booking.userId, -booking.pointsRedeemed);

      // Create transaction log
      final txRef = _db.child('reward_transactions').child(booking.userId).push();
      final txData = {
        'userId': booking.userId,
        'bookingId': bookingId,
        'type': 'Redeem',
        'points': -booking.pointsRedeemed,
        'balanceAfter': balanceAfter,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await txRef.set(txData);

      // Set pointsRedeemedProcessed = true on booking
      await _db.child('bookings').child(bookingId).update({
        'pointsRedeemedProcessed': true,
      });

      // Notify customer
      await _notificationService.createNotification(
        userId: booking.userId,
        title: 'Points Redeemed! 🛍️',
        message: 'Successfully redeemed ${booking.pointsRedeemed} points (RM ${booking.discountAmount.toStringAsFixed(2)} discount) on your rental booking!',
        type: 'reward',
        icon: '🛍️',
        color: '0xFF10B981',
        relatedId: bookingId,
        actionRoute: 'Dashboard',
      );
    } catch (e) {
      debugPrint('[RewardPointsService] Error deducting points for booking: $e');
      rethrow;
    }
  }

  // Manual admin points adjustment (Add or Deduct)
  Future<void> adjustPoints(String userId, int pointsChange, String reason, {String? adminId}) async {
    try {
      // Update balance
      final int balanceAfter = await _updateUserBalance(userId, pointsChange);

      // Create transaction log
      final txRef = _db.child('reward_transactions').child(userId).push();
      final txData = {
        'userId': userId,
        'bookingId': '',
        'type': 'Adjustment',
        'points': pointsChange,
        'balanceAfter': balanceAfter,
        'reason': reason,
        'adminId': adminId ?? 'admin',
        'createdAt': DateTime.now().toIso8601String(),
      };
      await txRef.set(txData);

      // Notify customer
      final isAddition = pointsChange >= 0;
      await _notificationService.createNotification(
        userId: userId,
        title: isAddition ? 'Points Adjusted (Credited) 🎁' : 'Points Adjusted (Debited) ⚠️',
        message: isAddition
            ? 'Administrator has credited your account with ${pointsChange.abs()} reward points. Reason: $reason'
            : 'Administrator has debited your account by ${pointsChange.abs()} reward points. Reason: $reason',
        type: 'reward',
        icon: isAddition ? '🎁' : '⚠️',
        color: isAddition ? '0xFF3B82F6' : '0xFFEF4444',
        relatedId: '',
        actionRoute: 'Dashboard',
      );
    } catch (e) {
      debugPrint('[RewardPointsService] Error adjusting user points: $e');
      rethrow;
    }
  }

  // Revert or refund reward points when a booking is cancelled or rejected
  Future<void> refundOrCancelPointsForBooking(String bookingId, String userId) async {
    try {
      debugPrint('[RewardPointsService] [refundOrCancelPointsForBooking] Reverting transactions for bookingId: $bookingId, userId: $userId');
      final snap = await _db.child('reward_transactions').child(userId).get();
      if (!snap.exists || snap.value == null) return;

      final rawVal = snap.value;
      if (rawVal is Map) {
        final Map<dynamic, dynamic> data = rawVal;
        for (var entry in data.entries) {
          final txId = entry.key.toString();
          final txData = entry.value as Map<dynamic, dynamic>;
          final bId = txData['bookingId']?.toString() ?? '';
          if (bId == bookingId) {
            final type = txData['type']?.toString() ?? '';
            final points = int.tryParse(txData['points']?.toString() ?? '0') ?? 0;

            debugPrint('[RewardPointsService] Reverting transaction: ID $txId, Type $type, Points $points');

            if (type == 'Earn' || type == 'Earned') {
              if (points > 0) {
                await _updateUserBalance(userId, -points);
              }
            } else if (type == 'Redeem') {
              if (points != 0) {
                await _updateUserBalance(userId, points.abs());
              }
            }

            await _db.child('reward_transactions').child(userId).child(txId).remove();
            debugPrint('[RewardPointsService] Successfully removed transaction ID: $txId');
          }
        }
      }
    } catch (e) {
      debugPrint('Error reverting reward points: $e');
      rethrow;
    }
  }
}
