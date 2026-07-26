import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/booking_model.dart';
import '../models/payment_model.dart';
import 'user_role_cache.dart';
import '../screens/auth/customer/booking_screen.dart';
import '../screens/auth/customer/customer_responsive_shell.dart';

class PaymentRestrictionService extends ChangeNotifier {
  static final PaymentRestrictionService _instance =
      PaymentRestrictionService._internal();

  factory PaymentRestrictionService() => _instance;

  PaymentRestrictionService._internal();

  bool _isRestricted = false;
  bool _isInitialized = false;
  BookingModel? _primaryOutstandingBooking;
  double _totalOutstandingAmount = 0.0;

  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<DatabaseEvent>? _bookingsSubscription;
  StreamSubscription<DatabaseEvent>? _paymentsSubscription;

  List<BookingModel> _userBookings = [];
  List<PaymentModel> _userPayments = [];

  bool get isRestricted => _isRestricted;
  BookingModel? get primaryOutstandingBooking => _primaryOutstandingBooking;
  double get totalOutstandingAmount => _totalOutstandingAmount;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _authStateSubscription?.cancel();
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        if (user == null) {
          _resetState();
        } else {
          _setupUserListeners(user.uid);
        }
      },
    );
  }

  void _resetState() {
    _bookingsSubscription?.cancel();
    _paymentsSubscription?.cancel();
    _userBookings = [];
    _userPayments = [];
    _isRestricted = false;
    _primaryOutstandingBooking = null;
    _totalOutstandingAmount = 0.0;
    notifyListeners();
  }

  Future<void> _setupUserListeners(String uid) async {
    try {
      final role = await UserRoleCache.getRole(uid);
      if (role == 'admin') {
        _resetState();
        return;
      }
    } catch (e) {
      debugPrint('[PaymentRestrictionService] Error fetching user role: $e');
    }

    _bookingsSubscription?.cancel();
    _bookingsSubscription = FirebaseDatabase.instance
        .ref()
        .child('bookings')
        .orderByChild('userId')
        .equalTo(uid)
        .onValue
        .listen((event) {
          _userBookings = [];
          if (event.snapshot.exists && event.snapshot.value != null) {
            final Map<dynamic, dynamic> data =
                event.snapshot.value as Map<dynamic, dynamic>;
            data.forEach((key, value) {
              if (value is Map) {
                _userBookings.add(
                  BookingModel.fromMap(key.toString(), value),
                );
              }
            });
          }
          _reevaluateRestriction();
        });

    _paymentsSubscription?.cancel();
    _paymentsSubscription = FirebaseDatabase.instance
        .ref()
        .child('payments')
        .orderByChild('userId')
        .equalTo(uid)
        .onValue
        .listen((event) {
          _userPayments = [];
          if (event.snapshot.exists && event.snapshot.value != null) {
            final Map<dynamic, dynamic> data =
                event.snapshot.value as Map<dynamic, dynamic>;
            data.forEach((key, value) {
              if (value is Map) {
                _userPayments.add(
                  PaymentModel.fromMap(key.toString(), value),
                );
              }
            });
          }
          _reevaluateRestriction();
        });
  }

  void _reevaluateRestriction() {
    evaluateRestrictionForData(_userBookings, _userPayments);
  }

  /// Evaluates restriction status given custom booking and payment lists (useful for testing and real-time calculation).
  void evaluateRestrictionForData(
    List<BookingModel> bookings,
    List<PaymentModel> payments,
  ) {
    BookingModel? firstUnpaidBooking;
    double totalOwed = 0.0;
    bool foundOutstanding = false;

    for (final booking in bookings) {
      final status = booking.status.toLowerCase();
      if (status == 'completed' ||
          status == 'cancelled' ||
          status == 'rejected') {
        continue;
      }

      bool isUnpaid = false;
      double owedForBooking = 0.0;

      if (status == 'awaiting final payment') {
        isUnpaid = true;
        owedForBooking = booking.finalAmount > 0
            ? booking.finalAmount
            : booking.totalPrice;
      } else if (status == 'pending payment' || status == 'waiting for payment') {
        isUnpaid = true;
        owedForBooking = booking.totalPrice;
      } else if (booking.finalAmount > 0 && !booking.isReturned) {
        isUnpaid = true;
        owedForBooking = booking.finalAmount;
      } else if (booking.lateFees > 0) {
        isUnpaid = true;
        owedForBooking = booking.lateFees;
      } else if (booking.extensionRequest != null) {
        final ext = booking.extensionRequest!;
        final extStatus = (ext['status'] ?? '').toString().toLowerCase();
        final extPaymentStatus =
            (ext['paymentStatus'] ?? '').toString().toLowerCase();
        if ((extStatus == 'pending' || extStatus == 'approved') &&
            extPaymentStatus == 'unpaid') {
          isUnpaid = true;
          owedForBooking = (ext['additionalCost'] ?? 0.0).toDouble();
        }
      }

      if (isUnpaid) {
        foundOutstanding = true;
        totalOwed += owedForBooking;
        firstUnpaidBooking ??= booking;
      }
    }

    if (!foundOutstanding) {
      for (final payment in _userPayments) {
        final pStatus = (payment.paymentStatus ?? payment.status).toLowerCase();
        if (pStatus == 'pending payment' ||
            pStatus == 'waiting for payment' ||
            pStatus == 'unpaid' ||
            pStatus == 'rejected' ||
            pStatus == 'failed') {
          foundOutstanding = true;
          totalOwed += payment.amount;
        }
      }
    }

    final previousRestricted = _isRestricted;
    _isRestricted = foundOutstanding;
    _primaryOutstandingBooking = firstUnpaidBooking;
    _totalOutstandingAmount = totalOwed;

    if (previousRestricted != _isRestricted) {
      debugPrint(
        '[PaymentRestrictionService] Restricted status changed: $_isRestricted (Owed: RM ${totalOwed.toStringAsFixed(2)})',
      );
    }
    notifyListeners();
  }

  /// Checks whether the user is restricted.
  /// If restricted, displays the "Outstanding Payment Required" dialog and returns true.
  /// If clear, invokes optional [onAllowed] callback and returns false.
  bool checkRestriction(BuildContext context, {VoidCallback? onAllowed}) {
    if (!_isRestricted) {
      onAllowed?.call();
      return false;
    }
    showRestrictionDialog(context);
    return true;
  }

  /// Displays the official Outstanding Payment Required dialog.
  Future<void> showRestrictionDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryOrange = Color(0xFFFF5722);
    const alertRed = Color(0xFFEF4444);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: alertRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: alertRed,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Outstanding Payment Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your account has been temporarily restricted because you have an unpaid balance.\n\nPlease complete your outstanding payment before using other system features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _navigateToPaymentPage(context);
                  },
                  child: const Text(
                    'Go to Payment',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToPaymentPage(BuildContext context) {
    if (_primaryOutstandingBooking != null) {
      BookingScreen.navigateToPayment(
        context,
        _primaryOutstandingBooking!,
        _primaryOutstandingBooking!.paymentMethod ?? 'DuitNow QR',
      );
    } else {
      final shellState = CustomerResponsiveShell.of(context);
      if (shellState != null) {
        shellState.setIndex(2); // Navigate to My Bookings screen
      }
    }
  }
}
