import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/promotion_service.dart';
import '../../../models/user_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/promotion_model.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/hero_promotion_carousel.dart';
import '../../../services/company_settings_provider.dart';
import '../../../services/user_session.dart';

import 'vehicle_list_screen.dart';
import 'vehicle_details_screen.dart';
import 'customer_responsive_shell.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor =>
      _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor =>
      _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;

  final AuthService _authService = AuthService();
  final VehicleService _vehicleService = VehicleService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  final PromotionService _promotionService = PromotionService();

  UserModel? _user;
  List<VehicleModel> _vehicles = [];
  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  List<PromotionModel> _promotions = [];
  bool _loading = true;
  String? _error;

  StreamSubscription<DatabaseEvent>? _userSubscription;
  StreamSubscription<List<BookingModel>>? _bookingsSubscription;
  StreamSubscription<List<PaymentModel>>? _paymentsSubscription;
  StreamSubscription<List<VehicleModel>>? _vehiclesSubscription;
  StreamSubscription<List<PromotionModel>>? _promotionsSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToLiveData();
  }

  void _subscribeToLiveData() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _userSubscription?.cancel();
    _userSubscription = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(currentUser.uid)
        .onValue
        .listen((event) {
          if (event.snapshot.exists && event.snapshot.value is Map) {
            if (mounted) {
              setState(() {
                _user = UserModel.fromMap(
                  currentUser.uid,
                  event.snapshot.value as Map<dynamic, dynamic>,
                );
              });
            }
          }
        });

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

    _promotionsSubscription?.cancel();
    _promotionsSubscription = _promotionService.getPromotionsStream().listen((
      allPromotions,
    ) {
      if (mounted) {
        setState(() {
          _promotions = allPromotions;
        });
      }
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _bookingsSubscription?.cancel();
    _paymentsSubscription?.cancel();
    _vehiclesSubscription?.cancel();
    _promotionsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        _user = await UserSession().fetchAndCacheUserModel(currentUser.uid);
        if (_user == null) {
          throw Exception("User data not found in database");
        }
      }
      // Seed preset promotions if empty
      await _promotionService.seedDefaultPromotions();
      _promotions = await _promotionService.getPromotions(forceRefresh: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data. Please pull down to refresh.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryOrange,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off,
                color: AppColors.primaryOrange,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.secondaryBlue,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final activeBookings = _bookings
        .where(
          (b) => [
            'pending',
            'approved',
            'confirmed',
            'active',
            'ongoing',
            'Pending',
            'Approved',
            'Confirmed',
            'Active',
            'Ongoing',
            'Pending Payment',
          ].contains(b.status),
        )
        .toList();
    final currentBooking = activeBookings.isNotEmpty
        ? activeBookings.first
        : null;
    final availableVehicles = _vehicles
        .where((v) => v.status.toLowerCase() == 'available')
        .take(8)
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryOrange,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroBanner(),
            const SizedBox(height: 14),

            // Hero Promotional Carousel
            if (_promotions.isNotEmpty)
              HeroPromotionCarousel(promotions: _promotions),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(),
                  const SizedBox(height: 20),

                  const SizedBox(height: 4),

                  _buildMembershipProgressCard(context),
                  const SizedBox(height: 20),
                  _buildLastPaymentCard(),
                  const SizedBox(height: 24),
                  _buildQuickActions(context),
                  const SizedBox(height: 28),
                  _buildActiveBookingCard(currentBooking),
                  const SizedBox(height: 28),
                  _buildAvailableCarsSection(availableVehicles),
                  const SizedBox(height: 28),
                  _buildRecentPayments(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondaryBlue, Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting! 👋',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _user?.fullName ?? 'Valued Customer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Loyalty Points - moved to app bar beside notification
              GestureDetector(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: AppColors.primaryOrange,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_user?.rewardPoints ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalBookings = _bookings.length;
    final totalSpent = _payments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final activeCount = _bookings
        .where(
          (b) => [
            'pending',
            'approved',
            'confirmed',
            'active',
            'Pending',
            'Approved',
            'Confirmed',
          ].contains(b.status),
        )
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.directions_car_filled_rounded,
            value: '$totalBookings',
            label: 'Bookings',
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.receipt_long_rounded,
            value: 'RM ${totalSpent.toStringAsFixed(0)}',
            label: 'Total Spent',
            color: AppColors.primaryOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.event_available_rounded,
            value: '$activeCount',
            label: 'Active',
            color: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildLastPaymentCard() {
    if (_payments.isEmpty) return const SizedBox();

    final sorted = List<PaymentModel>.from(_payments);
    sorted.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    final lastPayment = sorted.first;

    final booking = _bookings.firstWhere(
      (b) => b.id == lastPayment.bookingId,
      orElse: () => BookingModel(
        id: '',
        vehicleId: '',
        vehicleName: 'Vehicle',
        userId: '',
        userName: '',
        userPhone: '',
        pickUpDate: DateTime.now(),
        returnDate: DateTime.now(),
        totalPrice: 0.0,
        depositAmount: 0.0,
        status: '',
        createdAt: DateTime.now(),
      ),
    );
    final vehicleName = booking.vehicleName;
    final statusStr = lastPayment.paymentStatus ?? lastPayment.status;

    Color statusColor;
    switch (statusStr.toLowerCase()) {
      case 'approved':
      case 'paid':
        statusColor = const Color(0xFF10B981);
        break;
      case 'rejected':
      case 'failed':
        statusColor = const Color(0xFFEF4444);
        break;
      case 'refunded':
        statusColor = const Color(0xFF3B82F6);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    final bool isCompactMobile = MediaQuery.of(context).size.width <= 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompactMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : AppColors.borderGray,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.payment_rounded,
                        color: AppColors.primaryOrange,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LAST PAYMENT SUMMARY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: isCompactMobile ? 10 : 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  statusStr.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: _isDark ? const Color(0xFF334155) : AppColors.borderGray,
          ),
          const SizedBox(height: 14),
          if (isCompactMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicleName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${DateFormat('dd MMM yyyy').format(lastPayment.paymentDate)} at ${lastPayment.paymentTime ?? DateFormat('HH:mm:ss').format(lastPayment.paymentDate)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: _subColor),
                ),
                const SizedBox(height: 4),
                Text(
                  lastPayment.paymentMethod,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: _subColor),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'RM ${lastPayment.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${DateFormat('dd MMM yyyy').format(lastPayment.paymentDate)} at ${lastPayment.paymentTime ?? DateFormat('HH:mm:ss').format(lastPayment.paymentDate)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: _subColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              lastPayment.paymentMethod,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: _subColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'RM ${lastPayment.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: _textColor,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: _subColor)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.directions_car_filled_rounded,
        label: 'Browse Cars',
        color: const Color(0xFF3B82F6),
        onTap: () => CustomerResponsiveShell.of(context)?.setIndex(1),
      ),
      _QuickAction(
        icon: Icons.map_outlined,
        label: 'Branches',
        color: const Color(0xFFEC4899),
        onTap: () => CustomerResponsiveShell.of(context)?.setIndex(3),
      ),
      _QuickAction(
        icon: Icons.support_agent_rounded,
        label: 'Support',
        color: const Color(0xFF6366F1),
        onTap: () => CustomerResponsiveShell.of(context)?.setIndex(7),
      ),
      _QuickAction(
        icon: Icons.history_rounded,
        label: 'History',
        color: const Color(0xFF10B981),
        onTap: () => CustomerResponsiveShell.of(context)?.setIndex(5),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: actions
              .map(
                (a) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: a == actions.last ? 0 : 10),
                    child: _buildQuickActionCard(a),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : AppColors.borderGray,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBookingCard(BookingModel? booking) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Journey',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 14),
        if (booking == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : AppColors.borderGray,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isDark
                        ? const Color(0xFF0F172A)
                        : AppColors.lightGray,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_car_outlined,
                    color: _isDark
                        ? const Color(0xFF334155)
                        : AppColors.borderGray,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No Active Booking',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Browse our premium fleet and book your next ride.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _subColor),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VehicleListScreen(),
                    ),
                  ).then((_) => _loadData()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Book a Ride',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          _buildActiveBookingDetails(booking),
      ],
    );
  }

  Widget _buildActiveBookingDetails(BookingModel booking) {
    final dateFormat = DateFormat('dd MMM yyyy');
    Color statusColor = AppColors.primaryOrange;
    if ([
      'approved',
      'confirmed',
      'active',
      'ongoing',
      'Approved',
      'Confirmed',
      'Active',
      'Ongoing',
    ].contains(booking.status)) {
      statusColor = const Color(0xFF10B981);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryBlue,
            AppColors.secondaryBlue.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Journey',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    booking.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              booking.vehicleName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '#${booking.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PICK UP',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(booking.pickUpDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RETURN',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          booking.isOpenRental
                              ? 'Open Rental'
                              : (booking.returnDate != null
                                    ? dateFormat.format(booking.returnDate!)
                                    : ""),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL COST',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'RM ${booking.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: () =>
                      CustomerResponsiveShell.of(context)?.setIndex(2),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableCarsSection(List<VehicleModel> vehicles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Cars',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: _textColor,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VehicleListScreen()),
              ).then((_) => _loadData()),
              child: const Text(
                'See All',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (vehicles.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No available vehicles at the moment.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: vehicles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) =>
                  _buildVehicleCard(vehicles[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerResponsiveShell(
            initialIndex: 0,
            customBody: VehicleDetailsScreen(
              vehicle: vehicle,
              hideAppBar: true,
            ),
          ),
        ),
      ).then((_) => _loadData()),
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : AppColors.borderGray,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: vehicle.mainImage.isNotEmpty
                    ? Image(
                        image:
                            getAppImageProvider(vehicle.mainImage) ??
                            const AssetImage(
                              'assets/images/car_placeholder.png',
                            ),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.lightGray,
                          child: const Icon(
                            Icons.directions_car_filled_rounded,
                            color: AppColors.borderGray,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.lightGray,
                        child: const Icon(
                          Icons.directions_car_filled_rounded,
                          color: AppColors.borderGray,
                          size: 40,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.brand} ${vehicle.model}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    vehicle.category,
                    style: TextStyle(fontSize: 10, color: _subColor),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RM ${vehicle.pricePerDay.toStringAsFixed(0)}/day',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Available',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPayments() {
    final recent = _payments.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Payments',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: _textColor,
              ),
            ),
            TextButton(
              onPressed: () => CustomerResponsiveShell.of(context)?.setIndex(5),
              child: const Text(
                'See All',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (recent.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No payments yet.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          ...recent.map((p) => _buildPaymentRow(p)),
      ],
    );
  }

  Widget _buildPaymentRow(PaymentModel payment) {
    final statusStr = payment.paymentStatus ?? payment.status;
    Color statusColor;
    switch (statusStr.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        break;
      case 'refunded':
        statusColor = const Color(0xFF3B82F6);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : AppColors.borderGray,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primaryOrange,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.paymentMethod.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _textColor,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(payment.paymentDate),
                  style: TextStyle(fontSize: 10, color: _subColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RM ${payment.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: _textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusStr,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipProgressCard(BuildContext context) {
    final points = _user?.rewardPoints ?? 0;
    final status = CompanySettingsProvider().getMembershipStatus(points);

    Color levelColor;
    List<Color> gradientColors;
    IconData levelIcon;
    List<String> benefits = [];

    switch (status.currentLevel) {
      case 'Premium':
        levelColor = const Color(0xFFA78BFA);
        gradientColors = [const Color(0xFF6D28D9), const Color(0xFF4C1D95)];
        levelIcon = Icons.military_tech_rounded;
        benefits = [
          'Open Rental access (no upfront payment!)',
          '1.5x Reward Points earning multiplier',
          'Priority booking approval & support',
        ];
        break;
      case 'Gold':
        levelColor = const Color(0xFFFBBF24);
        gradientColors = [const Color(0xFFD97706), const Color(0xFFB45309)];
        levelIcon = Icons.stars_rounded;
        benefits = [
          'Priority booking approval',
          'Exclusive promotions',
          'Dynamic discount points redemptions',
        ];
        break;
      case 'Silver':
        levelColor = const Color(0xFFCBD5E1);
        gradientColors = [const Color(0xFF475569), const Color(0xFF334155)];
        levelIcon = Icons.verified_user_rounded;
        benefits = [
          'Dynamic discount points redemptions',
          'Priority customer support channels',
        ];
        break;
      default: // Standard
        levelColor = const Color(0xFF94A3B8);
        gradientColors = [const Color(0xFF374151), const Color(0xFF1F2937)];
        levelIcon = Icons.emoji_events_outlined;
        benefits = ['Standard points earning', 'Standard booking approval'];
    }

    final int pct = (status.progress * 100).toInt();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(levelIcon, color: levelColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '${status.currentLevel} Member',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Loyalty Status',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'REWARD POINTS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$points pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      status.currentLevel == 'Premium'
                          ? 'Maximum Membership Level Reached.'
                          : '${status.pointsNeededForNext} more points to unlock ${status.nextLevel}.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (status.currentLevel != 'Premium')
                      Text(
                        '$pct%',
                        style: TextStyle(
                          color: levelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: status.currentLevel == 'Premium'
                        ? 1.0
                        : status.progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'CURRENT MEMBERSHIP BENEFITS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                ...benefits.map(
                  (b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: levelColor,
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
