import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/review_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/review_service.dart';
import '../../../services/auth_service.dart';
import '../../../constants/colors.dart';
import 'customer_responsive_shell.dart';
import '../../../services/receipt_service.dart';
import '../../../services/booking_lifecycle_manager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'booking_screen.dart';

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
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();

  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  bool _loading = true;
  String? _error;

  // Track which tabs have been viewed
  Set<int> _viewedTabs = {};

  // Store previous counts to detect new bookings
  Map<int, int> _previousCounts = {};
  Map<int, int> _currentCounts = {};

  late TabController _tabController;

  StreamSubscription<List<BookingModel>>? _bookingsSubscription;
  StreamSubscription<List<PaymentModel>>? _paymentsSubscription;
  StreamSubscription<DatabaseEvent>? _reviewsSubscription;
  Set<String> _reviewedBookingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

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
          _payments = allPayments.where((p) => p.userId == currentUser.uid).toList();
        });
      }
    });
  }

  void _updateCounts() {
    final now = DateTime.now();

    final upcoming = _bookings.where((b) {
      final status = b.status.toLowerCase();
      return (status == 'pending' ||
              status == 'approved' ||
              status == 'confirmed' ||
              status == 'pending payment') &&
          b.pickUpDate.isAfter(now);
    }).length;

    final ongoing = _bookings.where((b) {
      final status = b.status.toLowerCase();
      return (status == 'active' || status == 'ongoing') ||
          ((status == 'approved' || status == 'confirmed') &&
              b.pickUpDate.isBefore(now) &&
              b.returnDate.isAfter(now));
    }).length;

    final completed = _bookings
        .where((b) => b.status.toLowerCase() == 'completed')
        .length;
    final cancelled = _bookings
        .where(
          (b) =>
              b.status.toLowerCase() == 'cancelled' ||
              b.status.toLowerCase() == 'rejected',
        )
        .length;

    _currentCounts = {0: upcoming, 1: ongoing, 2: completed, 3: cancelled};
  }

  // Check if tab should show badge (has unread items)
  bool _shouldShowBadge(int tabIndex) {
    // If tab has been viewed, don't show badge
    if (_viewedTabs.contains(tabIndex)) return false;

    // Get current count for this tab
    final currentCount = _currentCounts[tabIndex] ?? 0;

    // Get previous count for this tab (before user viewed it)
    final previousCount = _previousCounts[tabIndex] ?? 0;

    // Show badge if there are new items (current count > previous count)
    return currentCount > previousCount;
  }

  // Get the count to display in badge
  int _getBadgeCount(int tabIndex) {
    final currentCount = _currentCounts[tabIndex] ?? 0;
    final previousCount = _previousCounts[tabIndex] ?? 0;

    // Only show the new items count
    return currentCount - previousCount;
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
          final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
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
    _tabController.dispose();
    _bookingsSubscription?.cancel();
    _paymentsSubscription?.cancel();
    _reviewsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
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
            // Store initial counts as viewed
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

  void _submitReview(BookingModel booking) {
    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: _borderColor),
              ),
              title: Text(
                'Rate ${booking.vehicleName}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How was your rental experience?',
                    style: TextStyle(color: _textColor, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1.0;
                      return IconButton(
                        icon: Icon(
                          starVal <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = starVal;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    style: TextStyle(color: _textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Share your feedback...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: _isDark ? Colors.white30 : Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: _isDark ? const Color(0xFF94A3B8) : Colors.grey,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final comment = commentController.text.trim();

                    final review = ReviewModel(
                      id: '',
                      bookingId: booking.id,
                      vehicleId: booking.vehicleId,
                      userId: booking.userId,
                      userName: booking.userName,
                      rating: selectedRating,
                      comment: comment,
                      createdAt: DateTime.now(),
                    );

                    await _reviewService.submitReview(review);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Review submitted! Thank you.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text(
                    'Submit',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReceiptOptions(BookingModel booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
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
                leading: Icon(Icons.visibility, color: _textColor),
                title: Text(
                  'View Receipt',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ReceiptService().viewReceipt(context, booking.id);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.download,
                  color: AppColors.primaryOrange,
                ),
                title: Text(
                  'Download PDF',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ReceiptService().downloadReceipt(context, booking.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 950;

    final now = DateTime.now();

    final waitingPayment = _bookings.where((b) {
      final status = b.status.toLowerCase();
      return status == 'waiting for payment' || status == 'pending payment';
    }).toList();

    final upcoming = _bookings.where((b) {
      final status = b.status.toLowerCase();
      return (status == 'pending' || status == 'approved' || status == 'confirmed') &&
             b.pickUpDate.isAfter(now) &&
             status != 'waiting for payment' &&
             status != 'pending payment';
    }).toList();

    final ongoing = _bookings.where((b) {
      final status = b.status.toLowerCase();
      return (status == 'active' || status == 'ongoing') ||
          ((status == 'approved' || status == 'confirmed') &&
      return (status == 'active' || status == 'ongoing' || status == 'overdue') ||
             ((status == 'approved' || status == 'confirmed') &&
              b.pickUpDate.isBefore(now) &&
              b.returnDate.isAfter(now) &&
              status != 'waiting for payment' &&
              status != 'pending payment');
    }).toList();

    final completed = _bookings.where((b) => b.status.toLowerCase() == 'completed').toList();

    final cancelled = _bookings.where((b) => b.status.toLowerCase() == 'cancelled' || b.status.toLowerCase() == 'rejected').toList();

    return DefaultTabController(
      length: 5,
      child: Column(
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
                _buildTabItem('Pending Payment', waitingPayment.length),
                _buildTabItem('Upcoming', upcoming.length),
                _buildTabItem('Active', ongoing.length),
                _buildTabItem('Completed', completed.length),
                _buildTabItem('Cancelled', cancelled.length),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryOrange,
                      strokeWidth: 2.5,
                    ),
                  )
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          color: AppColors.primaryOrange,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadBookings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabList(waitingPayment, 'No pending payment bookings', isDesktop),
                      _buildTabList(upcoming, 'No upcoming bookings', isDesktop),
                      _buildTabList(ongoing, 'No active bookings', isDesktop),
                      _buildTabList(completed, 'No completed trips', isDesktop),
                      _buildTabList(cancelled, 'No cancelled reservations', isDesktop),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Tab _buildTabItem(String label, int tabIndex, int count) {
    final bool showBadge = _shouldShowBadge(tabIndex);
    final int badgeCount = _getBadgeCount(tabIndex);

    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
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

  Widget _buildBookingCard(BookingModel booking, bool isDesktop) {
    final dateFormat = DateFormat('dd MMM yyyy');

    Color statusColor = Colors.orange;
    final bStatus = booking.status.toLowerCase();
    if (bStatus == 'approved' ||
        bStatus == 'active' ||
        bStatus == 'ongoing' ||
        bStatus == 'confirmed') {
    final isWaitingPayment = bStatus == 'waiting for payment' || bStatus == 'pending payment';
    if (bStatus == 'approved' || bStatus == 'active' || bStatus == 'ongoing' || bStatus == 'confirmed') {
      statusColor = const Color(0xFF10B981);
    } else if (bStatus == 'completed') {
      statusColor = const Color(0xFF3B82F6);
    } else if (bStatus == 'cancelled' || bStatus == 'rejected' || bStatus == 'overdue') {
      statusColor = const Color(0xFFEF4444);
    } else if (isWaitingPayment) {
      statusColor = Colors.orange;
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
        ].contains(bStatus) &&
        booking.pickUpDate.isAfter(DateTime.now());
    final bool canCancel = ['pending', 'approved', 'confirmed', 'pending payment', 'waiting for payment'].contains(bStatus) && booking.pickUpDate.isAfter(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        border: Border.all(
          color: isWaitingPayment ? Colors.orange.withValues(alpha: 0.8) : _borderColor,
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
                // Icon or placeholder for car image
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
                // Details
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
                              '${dateFormat.format(booking.pickUpDate)} to ${dateFormat.format(booking.returnDate)}',
                              style: TextStyle(color: _subColor, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Pill
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
                      'TOTAL COST',
                      style: TextStyle(
                        fontSize: 8,
                        color: _subColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'RM ${booking.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppColors.primaryOrange,
                          ),
                        ),
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
                  ],
                ),
                Row(
                  children: [
                    if (isWaitingPayment) ...[
                      ElevatedButton.icon(
                        onPressed: () => _payNowExistingBooking(booking),
                        icon: const Icon(Icons.payment_rounded, size: 12, color: Colors.white),
                        label: const Text('Pay Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    if ((bStatus == 'active' || bStatus == 'ongoing' || bStatus == 'overdue') && !booking.isReturned) ...[
                      ElevatedButton.icon(
                        onPressed: () => _markVehicleAsReturned(booking),
                        icon: const Icon(Icons.keyboard_return, size: 12, color: Colors.white),
                        label: const Text('Return Vehicle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                    if (bStatus == 'completed' && !_reviewedBookingIds.contains(booking.id))
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

  Future<void> _markVehicleAsReturned(BookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _borderColor)),
        title: Text('Return Vehicle', style: TextStyle(fontWeight: FontWeight.bold, color: _textColor)),
        content: Text('Are you sure you want to mark this vehicle as returned? This will finalize your rental completion.', style: TextStyle(color: _textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _isDark ? const Color(0xFF94A3B8) : Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Return', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('bookings')
            .child(booking.id)
            .update({'isReturned': true});

        // Trigger lifecycle check immediately to transition to completed and update vehicle availability
        await BookingLifecycleManager().checkAndProcessLifecycle();

        _loadBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vehicle marked as returned successfully.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to return vehicle: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _payNowExistingBooking(BookingModel booking) async {
    if (mounted) {
      await BookingScreen.navigateToPayment(context, booking, booking.paymentMethod);
    }
  }
}
