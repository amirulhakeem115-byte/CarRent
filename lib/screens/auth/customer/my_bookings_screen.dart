import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/review_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/review_service.dart';
import '../../../services/auth_service.dart';
import '../../../constants/colors.dart';
import 'customer_responsive_shell.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();

  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  bool _loading = true;
  String? _error;

  StreamSubscription<List<BookingModel>>? _bookingsSubscription;
  StreamSubscription<List<PaymentModel>>? _paymentsSubscription;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _subscribeToLiveData();
  }

  void _subscribeToLiveData() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _bookingsSubscription?.cancel();
    _bookingsSubscription = _bookingService.getBookingsStream().listen((allBookings) {
      if (mounted) {
        setState(() {
          _bookings = allBookings.where((b) => b.userId == currentUser.uid).toList();
          _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      }
    });

    _paymentsSubscription?.cancel();
    _paymentsSubscription = _paymentService.getPaymentsStream().listen((allPayments) {
      if (mounted) {
        setState(() {
          _payments = allPayments.where((p) => p.userId == currentUser.uid).toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _paymentsSubscription?.cancel();
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Rate ${booking.vehicleName}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How was your rental experience?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1.0;
                      return IconButton(
                        icon: Icon(
                          starVal <= selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
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
                    decoration: InputDecoration(
                      hintText: 'Share your feedback...',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (commentController.text.trim().isEmpty) return;

                    final review = ReviewModel(
                      id: '',
                      vehicleId: booking.vehicleId,
                      userId: booking.userId,
                      userName: booking.userName,
                      rating: selectedRating,
                      comment: commentController.text.trim(),
                      createdAt: DateTime.now(),
                    );

                    await _reviewService.submitReview(review);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Review submitted! Thank you.'), backgroundColor: Colors.green),
                    );
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 950;

    final now = DateTime.now();

    final upcoming = _bookings.where((b) {
      final status = b.status.toLowerCase();
      return (status == 'pending' || status == 'approved' || status == 'confirmed' || status == 'pending payment') &&
             b.pickUpDate.isAfter(now);
    }).toList();

    final ongoing = _bookings.where((b) {
      final status = b.status.toLowerCase();
      return (status == 'active' || status == 'ongoing') ||
             ((status == 'approved' || status == 'confirmed') &&
              b.pickUpDate.isBefore(now) &&
              b.returnDate.isAfter(now));
    }).toList();

    final completed = _bookings.where((b) => b.status.toLowerCase() == 'completed').toList();

    final cancelled = _bookings.where((b) => b.status.toLowerCase() == 'cancelled' || b.status.toLowerCase() == 'rejected').toList();

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: AppColors.primaryOrange,
              unselectedLabelColor: AppColors.lightText,
              indicatorColor: AppColors.primaryOrange,
              indicatorWeight: 3,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
              tabs: [
                _buildTabItem('Upcoming', upcoming.length),
                _buildTabItem('Active', ongoing.length),
                _buildTabItem('Completed', completed.length),
                _buildTabItem('Cancelled', cancelled.length),
              ],
            ),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 2.5))
              : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, color: AppColors.primaryOrange, size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadBookings,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    children: [
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

  Tab _buildTabItem(String label, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabList(List<BookingModel> list, String emptyMsg, bool isDesktop) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                emptyMsg,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryBlue),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ready for your next trip? Discover our available premium vehicles.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Browse Cars', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
    if (bStatus == 'approved' || bStatus == 'active' || bStatus == 'ongoing' || bStatus == 'confirmed') {
      statusColor = const Color(0xFF10B981);
    } else if (bStatus == 'completed') {
      statusColor = const Color(0xFF3B82F6);
    } else if (bStatus == 'cancelled' || bStatus == 'rejected') {
      statusColor = const Color(0xFFEF4444);
    }

    final paymentList = _payments.where((p) => p.bookingId == booking.id).toList();
    final payment = paymentList.isNotEmpty ? paymentList.first : null;

    final bool canCancel = ['pending', 'approved', 'confirmed', 'pending payment'].contains(bStatus) && booking.pickUpDate.isAfter(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
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
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car_filled_rounded, color: AppColors.secondaryBlue, size: 28),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.vehicleName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.secondaryBlue),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ref ID: #${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length).toUpperCase()}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 10, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${dateFormat.format(booking.pickUpDate)} to ${dateFormat.format(booking.returnDate)}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        booking.status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
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
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL COST',
                      style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Text(
                          'RM ${booking.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primaryOrange),
                        ),
                        if (booking.discountAmount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stars_rounded, color: Colors.green, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                  '-RM ${booking.discountAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
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
                    if (canCancel)
                      OutlinedButton.icon(
                        onPressed: () => _confirmCancelBooking(booking),
                        icon: const Icon(Icons.close, size: 12, color: Colors.redAccent),
                        label: const Text('Cancel Request', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    if (bStatus == 'completed')
                      ElevatedButton.icon(
                        onPressed: () => _submitReview(booking),
                        icon: const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                        label: const Text('Submit Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
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
        style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _confirmCancelBooking(BookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Reservation'),
        content: const Text('Are you sure you want to cancel this booking? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _bookingService.cancelBooking(booking.id, booking.userId, booking.vehicleId, booking.vehicleName);
        _loadBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking request has been cancelled successfully.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }
}
