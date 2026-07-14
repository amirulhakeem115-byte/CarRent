import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/review_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/review_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../constants/colors.dart';
import '../../../services/receipt_service.dart';
import 'booking_screen.dart';
import 'customer_responsive_shell.dart';
import 'contact_support_screen.dart';
import '../../../services/notification_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor =>
      _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor =>
      _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;
  Color get _borderColor =>
      _isDark ? const Color(0xFF334155) : AppColors.borderGray;

  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  final AuthService _authService = AuthService();
  final ReviewService _reviewService = ReviewService();
  final VehicleService _vehicleService = VehicleService();

  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  List<VehicleModel> _vehicles = [];
  bool _loading = false;

  // Track which tabs have been viewed
  final Set<int> _viewedTabs = {};

  // Store previous/current counts to detect new bookings for tab badges
  Map<int, int> _previousCounts = {};
  Map<int, int> _currentCounts = {};

  late TabController _tabController;

  StreamSubscription<List<BookingModel>>? _bookingsSubscription;
  StreamSubscription<List<PaymentModel>>? _paymentsSubscription;
  StreamSubscription<List<VehicleModel>>? _vehiclesSubscription;
  StreamSubscription<DatabaseEvent>? _reviewsSubscription;
  Set<String> _reviewedBookingIds = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // 5-tab controller: Pay Now, Upcoming, Ongoing, Completed, Cancelled
    _tabController = TabController(length: 5, vsync: this);

    // Mark the initial tab as viewed
    _viewedTabs.add(0);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Mark the tab as viewed when user switches to it
        _viewedTabs.add(_tabController.index);
        setState(() {});
      }
    });

    _loadBookings();
    _subscribeToLiveData();
    _subscribeToReviews();

    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _subscribeToLiveData() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _bookingsSubscription?.cancel();
    _bookingsSubscription = _bookingService.getBookingsStream().listen((
      allBookings,
    ) {
      if (mounted) {
        setState(() {
          _bookings = allBookings
              .where((b) => b.userId == currentUser.uid)
              .toList();
          _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _updateCounts();
        });
      }
    });

    _paymentsSubscription?.cancel();
    _paymentsSubscription = _paymentService.getPaymentsStream().listen((
      allPayments,
    ) {
      if (mounted) {
        setState(() {
          _payments = allPayments
              .where((p) => p.userId == currentUser.uid)
              .toList();
        });
      }
    });

    _vehiclesSubscription?.cancel();
    _vehiclesSubscription = _vehicleService.getVehiclesStream().listen((
      allVehicles,
    ) {
      if (mounted) {
        setState(() {
          _vehicles = allVehicles;
        });
      }
    });
  }

  void _subscribeToReviews() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _reviewsSubscription?.cancel();
    _reviewsSubscription = FirebaseDatabase.instance
        .ref()
        .child('reviews')
        .orderByChild('userId')
        .equalTo(currentUser.uid)
        .onValue
        .listen((event) {
          if (mounted) {
            final Set<String> ids = {};
            if (event.snapshot.exists && event.snapshot.value != null) {
              final Map<dynamic, dynamic> data =
                  event.snapshot.value as Map<dynamic, dynamic>;
              data.forEach((key, value) {
                if (value is Map && value['bookingId'] != null) {
                  ids.add(value['bookingId'].toString());
                }
              });
            }
            setState(() {
              _reviewedBookingIds = ids;
            });
          }
        });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _bookingsSubscription?.cancel();
    _paymentsSubscription?.cancel();
    _vehiclesSubscription?.cancel();
    _reviewsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });

    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final results = await Future.wait([
          _bookingService.getUserBookings(currentUser.uid),
          _paymentService.getUserPayments(currentUser.uid),
        ]).timeout(const Duration(seconds: 8));

        if (mounted) {
          setState(() {
            _bookings = results[0] as List<BookingModel>;
            _payments = results[1] as List<PaymentModel>;
            _updateCounts();
            _previousCounts = Map.from(_currentCounts);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading bookings: $e. Using empty/streamed state.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _updateCounts() {
    final now = DateTime.now();

    final pendingPaymentCount = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return s == 'pending payment' || s == 'waiting for payment';
    }).length;

    final upcomingCount = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return (s == 'pending' || s == 'approved' || s == 'confirmed') &&
          b.pickUpDate.isAfter(now) &&
          s != 'pending payment' &&
          s != 'waiting for payment';
    }).length;

    final ongoingCount = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return (s == 'active' || s == 'ongoing') ||
          s == 'awaiting return inspection' ||
          s == 'awaiting final payment' ||
          s == 'return requested' ||
          ((s == 'approved' || s == 'confirmed') &&
              b.pickUpDate.isBefore(now) &&
              (b.returnDate == null || b.returnDate!.isAfter(now)) &&
              s != 'waiting for payment' &&
              s != 'pending payment') ||
          s == 'overdue';
    }).length;

    final completedCount = _bookings
        .where((b) => b.status.toLowerCase() == 'completed')
        .length;

    final cancelledCount = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return s == 'cancelled' || s == 'rejected';
    }).length;

    _currentCounts = {
      0: pendingPaymentCount,
      1: upcomingCount,
      2: ongoingCount,
      3: completedCount,
      4: cancelledCount,
    };
  }

  bool _shouldShowBadge(int tabIndex) {
    if (_viewedTabs.contains(tabIndex)) return false;
    final currentCount = _currentCounts[tabIndex] ?? 0;
    final previousCount = _previousCounts[tabIndex] ?? 0;
    return currentCount > previousCount;
  }

  int _getBadgeCount(int tabIndex) {
    final currentCount = _currentCounts[tabIndex] ?? 0;
    final previousCount = _previousCounts[tabIndex] ?? 0;
    return currentCount - previousCount;
  }

  Widget _buildBookingCard(BookingModel booking, bool isDesktop) {
    final dateFormat = DateFormat('dd MMM yyyy');
    double pricePerDay = 100.0;
    try {
      pricePerDay = _vehicles.firstWhere((v) => v.id == booking.vehicleId).pricePerDay;
    } catch (_) {}
    final overdue = BookingService.getOverdueDetails(booking, pricePerDay);

    Color statusColor = Colors.orange;
    final bStatus = booking.status.toLowerCase();
    final isWaitingPayment =
        bStatus == 'waiting for payment' || bStatus == 'pending payment';

    if (bStatus == 'approved' ||
        bStatus == 'active' ||
        bStatus == 'ongoing' ||
        bStatus == 'confirmed') {
      statusColor = const Color(0xFF10B981);
    } else if (bStatus == 'completed') {
      statusColor = const Color(0xFF3B82F6);
    } else if (bStatus == 'cancelled' ||
        bStatus == 'rejected' ||
        bStatus == 'overdue') {
      statusColor = const Color(0xFFEF4444);
    }

    final paymentList = _payments
        .where((p) => p.bookingId == booking.id)
        .toList();
    final payment = paymentList.isNotEmpty ? paymentList.first : null;
    final bool canCancel =
        [
          'pending',
          'approved',
          'confirmed',
          'pending payment',
          'waiting for payment',
        ].contains(bStatus) &&
        booking.pickUpDate.isAfter(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWaitingPayment
              ? Colors.orange.withValues(alpha: 0.8)
              : _borderColor,
          width: isWaitingPayment ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _isDark
                        ? const Color(0xFF0F172A)
                        : AppColors.lightGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    color: _textColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.vehicleName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ref ID: #${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length).toUpperCase()}',
                        style: TextStyle(
                          color: _subColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 10,
                            color: _subColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              booking.isOpenRental
                                  ? '${dateFormat.format(booking.pickUpDate)} to ♾ Open Rental'
                                  : '${dateFormat.format(booking.pickUpDate)} to ${booking.returnDate != null ? dateFormat.format(booking.returnDate!) : ""}',
                              style: TextStyle(color: _subColor, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        booking.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (payment != null) ...[
                      const SizedBox(height: 6),
                      _buildPaymentBadge(payment),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: _borderColor),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overdue['isOverdue'] == true ? 'CURRENT TOTAL AMOUNT' : 'TOTAL COST',
                      style: TextStyle(
                        fontSize: 8,
                        color: _subColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          booking.status == 'Awaiting Final Payment'
                              ? 'RM ${booking.finalAmount.toStringAsFixed(2)}'
                              : (booking.isOpenRental && _isOngoing(booking)
                                  ? 'RM ${(_getDynamicPrice(booking) + (overdue['charges'] as num)).toStringAsFixed(2)}'
                                  : 'RM ${(booking.totalPrice + (overdue['charges'] as num)).toStringAsFixed(2)}'),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: overdue['isOverdue'] == true ? Colors.redAccent : AppColors.primaryOrange,
                          ),
                        ),
                        if (booking.isOpenRental && _isOngoing(booking)) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(Est. for ${_getElapsedDays(booking)} days)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _subColor,
                            ),
                          ),
                        ],
                        if (booking.discountAmount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  color: Colors.green,
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '-RM ${booking.discountAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (booking.isOpenRental && _isOngoing(booking)) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Active Duration: ${_getElapsedHours(booking)} hours elapsed',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _subColor,
                        ),
                      ),
                    ],
                    if (overdue['isOverdue'] == true) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            'Overdue: ${overdue['days']}d ${overdue['hours']}h (+RM ${overdue['charges'].toStringAsFixed(2)})',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    if (booking.status == 'Awaiting Final Payment') ...[
                      ElevatedButton.icon(
                        onPressed: () => _payNowExistingBooking(booking),
                        icon: const Icon(
                          Icons.payment_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Pay Final Invoice',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (isWaitingPayment) ...[
                      ElevatedButton.icon(
                        onPressed: () => _payNowExistingBooking(booking),
                        icon: const Icon(
                          Icons.payment_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Pay Now',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (canCancel)
                      OutlinedButton.icon(
                        onPressed: () => _confirmCancelBooking(booking),
                        icon: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Cancel Request',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    // Self-service panel is rendered as a sibling of this actions row to prevent rendering constraint errors.
                    if (bStatus == 'completed' &&
                        !_reviewedBookingIds.contains(booking.id)) ...[
                      ElevatedButton.icon(
                        onPressed: () => _submitReview(booking),
                        icon: const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Submit Review',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                    if (booking.status.toLowerCase() == 'completed' ||
                        (payment != null &&
                            (payment.paymentStatus?.toLowerCase() ==
                                     'approved' ||
                                 payment.status.toLowerCase() == 'approved' ||
                                 payment.paymentStatus?.toLowerCase() ==
                                     'paid' ||
                                 payment.status.toLowerCase() == 'paid'))) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showReceiptOptions(booking),
                        icon: const Icon(
                          Icons.receipt_long_rounded,
                          size: 12,
                          color: AppColors.primaryOrange,
                        ),
                        label: const Text(
                          'Receipt',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.primaryOrange,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if ((bStatus == 'active' ||
                    bStatus == 'ongoing' ||
                    bStatus == 'overdue' ||
                    bStatus == 'return requested' ||
                    bStatus == 'awaiting return inspection' ||
                    bStatus == 'awaiting final payment')) ...[
              _buildSelfServicePanel(booking, _isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(PaymentModel payment) {
    Color badgeColor = Colors.orange;
    String badgeText = 'Unverified';
    final pStatus = payment.paymentStatus?.toLowerCase() ?? 'pending';

    if (pStatus == 'approved') {
      badgeColor = const Color(0xFF10B981);
      badgeText = 'Paid';
    } else if (pStatus == 'rejected') {
      badgeColor = const Color(0xFFEF4444);
      badgeText = 'Payment Rejected';
    } else {
      badgeColor = Colors.orange;
      badgeText = 'Verification Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _confirmCancelBooking(BookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _borderColor),
        ),
        title: Text(
          'Cancel Reservation',
          style: TextStyle(fontWeight: FontWeight.bold, color: _textColor),
        ),
        content: Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: TextStyle(color: _textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: TextStyle(
                color: _isDark ? const Color(0xFF94A3B8) : Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Cancel Booking',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _bookingService.cancelBooking(
          booking.id,
          booking.userId,
          booking.vehicleId,
          booking.vehicleName,
        );
        _loadBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking request has been cancelled successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }



  Future<void> _payNowExistingBooking(BookingModel booking) async {
    if (mounted) {
      await BookingScreen.navigateToPayment(
        context,
        booking,
        booking.paymentMethod,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    final now = DateTime.now();

    final pendingPaymentList = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return s == 'pending payment' || s == 'waiting for payment';
    }).toList();

    final upcomingList = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return (s == 'pending' || s == 'approved' || s == 'confirmed') &&
          b.pickUpDate.isAfter(now) &&
          s != 'pending payment' &&
          s != 'waiting for payment';
    }).toList();

    final ongoingList = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return (s == 'active' || s == 'ongoing') ||
          s == 'awaiting return inspection' ||
          s == 'awaiting final payment' ||
          s == 'return requested' ||
          ((s == 'approved' || s == 'confirmed') &&
              b.pickUpDate.isBefore(now) &&
              (b.returnDate == null || b.returnDate!.isAfter(now)) &&
              s != 'waiting for payment' &&
              s != 'pending payment') ||
          s == 'overdue';
    }).toList();

    final completedList = _bookings
        .where((b) => b.status.toLowerCase() == 'completed')
        .toList();

    final cancelledList = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return s == 'cancelled' || s == 'rejected';
    }).toList();

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    return Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryOrange,
            unselectedLabelColor: _subColor,
            indicatorColor: AppColors.primaryOrange,
            indicatorWeight: 3,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 13,
            ),
            tabs: [
              _buildTabItem('Pay Now', 0, pendingPaymentList.length),
              _buildTabItem('Upcoming', 1, upcomingList.length),
              _buildTabItem('Ongoing', 2, ongoingList.length),
              _buildTabItem('Completed', 3, completedList.length),
              _buildTabItem('Cancelled', 4, cancelledList.length),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabList(
                  pendingPaymentList,
                  'No pending payments.',
                  isDesktop,
                  0,
                ),
                _buildTabList(upcomingList, 'No upcoming bookings.', isDesktop, 1),
                _buildTabList(ongoingList, 'No ongoing rentals.', isDesktop, 2),
                _buildTabList(completedList, 'No completed bookings.', isDesktop, 3),
                _buildTabList(cancelledList, 'No cancelled reservations.', isDesktop, 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Tab _buildTabItem(String label, int tabIndex, int count) {
    final bool showBadge = _shouldShowBadge(tabIndex);
    final int badgeCount = _getBadgeCount(tabIndex);

    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label ($count)'),
          if (showBadge && badgeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabList(
    List<BookingModel> list,
    String emptyMsg,
    bool isDesktop,
    int tabIndex,
  ) {
    // Mark tab as viewed when user actually sees the content
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_viewedTabs.contains(tabIndex) && list.isNotEmpty) {
        setState(() {
          _viewedTabs.add(tabIndex);
          // Update previous counts for this tab
          _previousCounts[tabIndex] = _currentCounts[tabIndex] ?? 0;
        });
      }
    });

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: _isDark ? const Color(0xFF334155) : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                emptyMsg,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Ready for your next trip? Discover our available premium vehicles.',
                style: TextStyle(fontSize: 11, color: _subColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  CustomerResponsiveShell.of(context)?.setIndex(1);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Browse Cars',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildBookingCard(list[index], isDesktop);
      },
    );
  }

  Future<void> _submitReview(BookingModel booking) async {
    double rating = 5;
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Rate Your Experience',
          style: TextStyle(fontWeight: FontWeight.bold, color: _textColor),
        ),
        content: StatefulBuilder(
          builder: (ctx2, setInner) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                booking.vehicleName,
                style: TextStyle(color: _subColor, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setInner(() => rating = (i + 1).toDouble()),
                    child: Icon(
                      i < rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.primaryOrange,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)',
                  hintStyle: TextStyle(color: _subColor, fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: _subColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = _authService.currentUser;
        if (currentUser == null) return;
        
        final review = ReviewModel(
          id: '',
          bookingId: booking.id,
          vehicleId: booking.vehicleId,
          userId: currentUser.uid,
          userName: booking.userName,
          rating: rating,
          comment: commentController.text.trim(),
          createdAt: DateTime.now(),
        );

        await _reviewService.submitReview(review);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit review: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
    commentController.dispose();
  }

  void _showReceiptOptions(BookingModel booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receipt Options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Booking ID: #${booking.id.toUpperCase()}',
              style: TextStyle(fontSize: 11, color: _subColor),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.visibility_outlined, color: _textColor),
              title: Text('View Receipt', style: TextStyle(color: _textColor)),
              onTap: () {
                Navigator.pop(ctx);
                ReceiptService().viewReceipt(context, booking.id);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.primaryOrange,
              ),
              title: Text('Download PDF', style: TextStyle(color: _textColor)),
              onTap: () {
                Navigator.pop(ctx);
                ReceiptService().downloadReceipt(context, booking.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfServicePanel(BookingModel booking, bool isDark) {
    final hasPendingExt = booking.extensionRequest != null &&
        booking.extensionRequest!['status'] == 'pending';
    final isReturnRequested = booking.status == 'Return Requested' || booking.status == 'Awaiting Return Inspection' || booking.status == 'Awaiting Final Payment';
    final isOnMyWay = booking.customerStatus == 'on_my_way';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Divider(color: Colors.white10),
        const SizedBox(height: 8),
        const Text(
          'RENTAL SELF-SERVICE OPTIONS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryOrange,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        if (hasPendingExt) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_empty, color: Colors.orange, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Extension request pending approval until ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.parse(booking.extensionRequest!['newReturnDate']))}',
                    style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (isReturnRequested) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.done_all, color: Colors.blue, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking.status == 'Awaiting Return Inspection'
                        ? 'Return request submitted. Please wait for the Admin to inspect the vehicle.'
                        : (booking.status == 'Awaiting Final Payment'
                            ? 'Inspection completed. Awaiting final payment.'
                            : 'Return request submitted. Awaiting Admin inspection & completion.'),
                    style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!booking.isOpenRental)
              ElevatedButton.icon(
                onPressed: hasPendingExt || isReturnRequested ? null : () => _showExtensionSheet(booking),
                icon: const Icon(Icons.add_alarm, size: 12),
                label: const Text('Extend Booking', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ElevatedButton.icon(
              onPressed: isReturnRequested ? null : () => _confirmReturnVehicle(booking),
              icon: const Icon(Icons.keyboard_return, size: 12),
              label: Text(booking.isOpenRental ? 'Return Car' : 'Return Vehicle', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: isOnMyWay || isReturnRequested ? null : () => _markOnMyWay(booking),
              icon: const Icon(Icons.directions_run, size: 12),
              label: Text(isOnMyWay ? 'On My Way!' : "I'm On My Way", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOnMyWay ? Colors.green : Colors.indigo,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 12),
              label: const Text('Support', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryOrange),
                foregroundColor: AppColors.primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        )
      ],
    );
  }

  Future<void> _showExtensionSheet(BookingModel booking) async {
    final isDark = _isDark;
    final fallbackReturn = booking.returnDate ?? booking.pickUpDate;
    DateTime newDate = fallbackReturn.add(const Duration(days: 1));
    TimeOfDay newTime = TimeOfDay.fromDateTime(fallbackReturn);
    bool isChecking = false;
    bool isAvailable = true;
    double pricePerDay = 120.0;

    try {
      final snap = await FirebaseDatabase.instance.ref().child('vehicles').child(booking.vehicleId).get();
      if (snap.exists) {
        pricePerDay = ((snap.value as Map)['pricePerDay'] ?? 120.0).toDouble();
      }
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightText;
        final textPrim = isDark ? Colors.white : AppColors.darkText;

        return StatefulBuilder(
          builder: (ctx2, setStateSheet) {
            final returnDateTime = DateTime(
              newDate.year,
              newDate.month,
              newDate.day,
              newTime.hour,
              newTime.minute,
            );

            final diff = returnDateTime.difference(fallbackReturn);
            final hours = diff.inHours;
            final addDays = (hours / 24.0).ceil();
            final addCost = addDays > 0 ? addDays * pricePerDay : 0.0;

            Future<void> verifyAvailability() async {
              setStateSheet(() {
                isChecking = true;
              });
              final ok = await _bookingService.isVehicleAvailableForExtension(
                booking.vehicleId,
                fallbackReturn,
                returnDateTime,
                booking.id,
              );
              setStateSheet(() {
                isChecking = false;
                isAvailable = ok;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 24, left: 24, right: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Request Extension', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrim)),
                  const SizedBox(height: 4),
                  Text('Current Return: ${booking.returnDate != null ? DateFormat('dd MMM yyyy hh:mm a').format(booking.returnDate!) : "Open Rental"}', style: TextStyle(fontSize: 11, color: textSec)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: newDate.isBefore(fallbackReturn) ? fallbackReturn.add(const Duration(days: 1)) : newDate,
                              firstDate: fallbackReturn,
                              lastDate: fallbackReturn.add(const Duration(days: 30)),
                            );
                            if (picked != null) {
                              setStateSheet(() => newDate = picked);
                              verifyAvailability();
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text(DateFormat('dd MMM yyyy').format(newDate), style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: newTime,
                            );
                            if (picked != null) {
                              setStateSheet(() => newTime = picked);
                              verifyAvailability();
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 14),
                          label: Text(newTime.format(context), style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (isChecking) ...[
                    const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
                    const SizedBox(height: 16),
                  ] else ...[
                    if (!isAvailable) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Vehicle is not available for this period. Please try another date/time.',
                                style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Additional Duration', style: TextStyle(fontSize: 12, color: textSec)),
                                Text('$addDays Days ($hours Hours)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrim)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Daily Rate', style: TextStyle(fontSize: 12, color: textSec)),
                                Text('RM ${pricePerDay.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrim)),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Additional Cost', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('RM ${addCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryOrange)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: addCost <= 0 ? null : () async {
                          Navigator.pop(ctx);
                          await BookingScreen.navigateToPayment(
                            context,
                            booking,
                            addCost,
                            returnDateTime,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          addCost > 0 ? 'Proceed to Payment (RM ${addCost.toStringAsFixed(2)})' : 'Select a valid extension date',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmReturnVehicle(BookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _borderColor),
        ),
        title: Text(
          'Return Vehicle',
          style: TextStyle(fontWeight: FontWeight.bold, color: _textColor),
        ),
        content: Text(
          'Are you sure you want to request a return for this vehicle? This will notify the Admin to schedule an inspection.',
          style: TextStyle(color: _textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: _isDark ? const Color(0xFF94A3B8) : Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Request Return',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _bookingService.requestReturn(booking.id);
        _loadBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Return request submitted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to request return: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _markOnMyWay(BookingModel booking) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('bookings')
          .child(booking.id)
          .update({'customerStatus': 'on_my_way'});

      final notificationService = NotificationService();

      final bool isPickup = booking.status.toLowerCase() != 'active' &&
                            booking.status.toLowerCase() != 'ongoing' &&
                            booking.status.toLowerCase() != 'overdue';

      final String actionMsg = isPickup ? "pick up" : "return";

      // 1. Notify Admin
      await notificationService.notifyAllAdmins(
        title: isPickup ? "Customer On the Way 🚗" : "Return Request",
        message: isPickup
            ? 'Customer "${booking.userName}" is on the way to pick up Vehicle "${booking.vehicleName}".'
            : 'Customer ${booking.userName} is on the way to return ${booking.vehicleName}. Please prepare for vehicle inspection.',
        type: isPickup ? 'on_my_way' : 'return_request',
        icon: '🚗',
        color: '0xFF10B981',
        relatedId: booking.id,
        actionRoute: 'Bookings',
      );

      // 2. Notify Customer
      await notificationService.createNotification(
        userId: booking.userId,
        title: "Status Updated: On My Way",
        message: "You have notified the Admin that you are on your way to $actionMsg ${booking.vehicleName}.",
        type: 'booking',
        icon: '🚗',
        color: '0xFF10B981',
        relatedId: booking.id,
        actionRoute: 'Dashboard',
      );

      _loadBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Admin notified that you're on your way!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to notify admin: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  int _getElapsedDays(BookingModel booking) {
    final pickup = booking.actualPickupTimestamp ?? booking.pickUpDate;
    final diff = DateTime.now().difference(pickup);
    final days = (diff.inHours / 24.0).ceil();
    return days <= 0 ? 1 : days;
  }

  int _getElapsedHours(BookingModel booking) {
    final pickup = booking.actualPickupTimestamp ?? booking.pickUpDate;
    return DateTime.now().difference(pickup).inHours;
  }

  bool _isOngoing(BookingModel booking) {
    final s = booking.status.toLowerCase();
    return s == 'active' || s == 'ongoing' || s == 'overdue' || s == 'return requested' || s == 'awaiting return inspection' || s == 'awaiting final payment';
  }

  double _getDynamicPrice(BookingModel booking) {
    if (!booking.isOpenRental || !_isOngoing(booking)) {
      return booking.totalPrice;
    }
    final days = _getElapsedDays(booking);
    return days * booking.totalPrice;
  }
}
