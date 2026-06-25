import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/branch_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/notification_service.dart';
import '../../../models/user_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/branch_model.dart';
import '../../../models/notification_model.dart';
import 'vehicle_list_screen.dart';
import 'profile_screen.dart';
import 'contact_support_screen.dart';
import '../../home_screen.dart';
import 'package:intl/intl.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';
import '../../../widgets/app_image.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final BranchService _branchService = BranchService();
  final VehicleService _vehicleService = VehicleService();
  final NotificationService _notificationService = NotificationService();

  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  UserModel? _user;
  List<BranchModel> _branches = [];
  BranchModel? _selectedBranch;
  List<VehicleModel> _vehicles = [];
  List<NotificationModel> _notifications = [];
  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
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
        // Load user info
        try {
          _user = await _databaseService.getUser(currentUser.uid).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('Error loading user details: $e');
        }

        // Load bookings & payments
        try {
          _bookings = await _bookingService.getUserBookings(currentUser.uid).timeout(const Duration(seconds: 4));
          _payments = await _paymentService.getUserPayments(currentUser.uid).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('Error loading bookings or payments: $e');
        }

        // Load notifications
        try {
          _notifications = await _notificationService.getNotifications(currentUser.uid).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('Error loading notifications: $e');
          _notifications = [];
        }
      }

      // Load branches
      try {
        _branches = await _branchService.getBranches().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Error loading branches: $e. Using defaults.');
        _branches = _branchService.getDefaultBranches();
      }

      // Load vehicles
      try {
        _vehicles = await _vehicleService.getVehicles().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Error loading vehicles: $e. Using defaults.');
        _vehicles = _vehicleService.getDefaultVehicles();
      }

      if (_branches.isNotEmpty) {
        _selectedBranch = _branches.first;
      }
    } catch (e) {
      debugPrint('Unexpected error loading customer home data: $e');
      if (_branches.isEmpty) _branches = _branchService.getDefaultBranches();
      if (_vehicles.isEmpty) _vehicles = _vehicleService.getDefaultVehicles();
      if (_branches.isNotEmpty) _selectedBranch = _branches.first;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
                      ),
                      if (_notifications.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            if (_user != null) {
                              await _notificationService.clearAllNotifications(_user!.id);
                              final updated = await _notificationService.getNotifications(_user!.id);
                              setModalState(() {
                                _notifications = updated;
                              });
                              setState(() {
                                _notifications = updated;
                              });
                            }
                          },
                          child: const Text('Clear All'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text('No notifications yet', style: TextStyle(color: Colors.grey[500])),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _notifications.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              IconData icon = Icons.info_outline;
                              Color color = Colors.blue;
                              if (notif.type == 'booking') {
                                icon = Icons.book_online_outlined;
                                color = Colors.orange;
                              } else if (notif.type == 'payment') {
                                icon = Icons.payment_outlined;
                                color = Colors.green;
                              }

                              return ListTile(
                                leading: CircleAvatar(
                                   backgroundColor: color.withValues(alpha: 0.1),
                                  child: Icon(icon, color: color),
                                ),
                                title: Text(notif.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(notif.message),
                                trailing: notif.isRead
                                    ? null
                                    : Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                onTap: () async {
                                  await _notificationService.markAsRead(notif.id);
                                  final updated = await _notificationService.getNotifications(_user!.id);
                                  setModalState(() {
                                    _notifications = updated;
                                  });
                                  setState(() {
                                    _notifications = updated;
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<VehicleModel> filteredVehicles = _vehicles;
    if (_selectedBranch != null) {
      filteredVehicles = _vehicles.where((v) => v.branchName == _selectedBranch!.name).toList();
    }

    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: _loading
          ? const Center(child: LoadingWidget(message: 'Loading customer dashboard...'))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.secondaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry Loading'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Premium full-bleed header with gradient
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.secondaryBlue, Color(0xFF07172C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(32),
                              bottomRight: Radius.circular(32),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              padding: const EdgeInsets.only(left: 24, right: 24, top: 60, bottom: 32),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Welcome back,',
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, letterSpacing: 0.5),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _user?.fullName ?? 'Valued Customer',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.08),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Stack(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                                                  onPressed: _showNotifications,
                                                ),
                                                if (unreadCount > 0)
                                                  Positioned(
                                                    right: 8,
                                                    top: 8,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(
                                                        color: AppColors.primaryOrange,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      constraints: const BoxConstraints(
                                                        minWidth: 16,
                                                        minHeight: 16,
                                                      ),
                                                      child: Text(
                                                        '$unreadCount',
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                              ).then((_) => _loadData());
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(color: AppColors.primaryOrange, width: 2),
                                              ),
                                              child: CircleAvatar(
                                                radius: 20,
                                                backgroundColor: Colors.white24,
                                                backgroundImage: getAppImageProvider(_user?.profileImage),
                                                child: _user?.profileImage == null || _user!.profileImage.isEmpty || getAppImageProvider(_user?.profileImage) == null
                                                    ? const Icon(Icons.person, color: Colors.white)
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),
                                  // Floating glassmorphic branch selector card
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.25), width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<BranchModel>(
                                        hint: const Text('Filter by Branch Location', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.lightText)),
                                        value: _selectedBranch,
                                        isExpanded: true,
                                        icon: const Icon(Icons.location_on_outlined, color: AppColors.primaryOrange, size: 22),
                                        items: [
                                          const DropdownMenuItem<BranchModel>(
                                            value: null,
                                            child: Text('All Branches', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                                          ),
                                          ..._branches.map((BranchModel b) {
                                            return DropdownMenuItem<BranchModel>(
                                              value: b,
                                              child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                                            );
                                          }),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedBranch = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Main responsive body content bounded to 1200px
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quick Actions',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.secondaryBlue,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildQuickActionButton(
                                      icon: Icons.search,
                                      label: 'Search Cars',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const VehicleListScreen()),
                                        );
                                      },
                                    ),
                                    _buildQuickActionButton(
                                      icon: Icons.history,
                                      label: 'History',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                        );
                                      },
                                    ),
                                    _buildQuickActionButton(
                                      icon: Icons.person_outline,
                                      label: 'Profile',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                        ).then((_) => _loadData());
                                      },
                                    ),
                                    _buildQuickActionButton(
                                      icon: Icons.support_agent,
                                      label: 'Support Desk',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const ContactSupportScreen()),
                                        ).then((_) => _loadData());
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 40),
                                _buildBookingAndPaymentsSection(),
                                const SizedBox(height: 40),
                                // Available fleet list header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedBranch == null
                                          ? 'Available Fleet'
                                          : 'Available at ${_selectedBranch!.name}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.secondaryBlue,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const VehicleListScreen()),
                                        );
                                      },
                                      child: const Row(
                                        children: [
                                          Text('View All', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                                          SizedBox(width: 4),
                                          Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primaryOrange),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Fleet horizontal carousel or empty state
                                filteredVehicles.isEmpty
                                    ? Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 60),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.grey[200]!),
                                        ),
                                        child: Center(
                                          child: Column(
                                            children: [
                                              Icon(Icons.directions_car_filled_outlined, size: 48, color: Colors.grey[300]),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No vehicles available at this location right now.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : SizedBox(
                                        height: 410,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: filteredVehicles.length,
                                          itemBuilder: (context, index) {
                                            final vehicle = filteredVehicles[index];
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 20, bottom: 20),
                                              child: VehicleHoverCard(vehicle: vehicle),
                                            );
                                          },
                                        ),
                                      ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primaryOrange, size: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingAndPaymentsSection() {
    final activeBookingsList = _bookings.where(
      (b) => ['pending', 'approved', 'active', 'ongoing'].contains(b.status.toLowerCase()),
    ).toList();
    final currentBooking = activeBookingsList.isNotEmpty ? activeBookingsList.first : null;

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    return Flex(
      direction: isDesktop ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: isDesktop ? 5 : 0,
          child: _buildCurrentBookingCard(currentBooking),
        ),
        if (isDesktop) const SizedBox(width: 24),
        if (!isDesktop) const SizedBox(height: 24),
        Expanded(
          flex: isDesktop ? 5 : 0,
          child: _buildRecentPaymentsCard(),
        ),
      ],
    );
  }

  Widget _buildCurrentBookingCard(BookingModel? booking) {
    if (booking == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Booking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(Icons.no_sim_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'No active bookings found.',
                    style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Need a car? Explore our fleet and make a booking.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VehicleListScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Book Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy');
    Color statusColor = Colors.orange;
    if (booking.status == 'approved' || booking.status == 'active' || booking.status == 'ongoing') {
      statusColor = Colors.blue;
    } else if (booking.status == 'completed') {
      statusColor = Colors.green;
    } else if (booking.status == 'cancelled' || booking.status == 'rejected') {
      statusColor = Colors.red;
    }

    final bool canCancel = ['pending', 'approved'].contains(booking.status.toLowerCase());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Booking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car_filled, color: AppColors.secondaryBlue, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.vehicleName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Booking ID: #${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length).toUpperCase()}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PICKUP DATE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(dateFormat.format(booking.pickUpDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('RETURN DATE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(dateFormat.format(booking.returnDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL PRICE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('RM ${booking.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryOrange)),
                ],
              ),
              if (canCancel)
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cancel Booking'),
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
                        _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Booking cancelled successfully'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Cancellation failed: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.redAccent),
                  label: const Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPaymentsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Payments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: const Text('View Ledger', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _payments.isEmpty
              ? Container(
                  height: 160,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No payment transactions found.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _payments.length > 3 ? 3 : _payments.length,
                  separatorBuilder: (context, index) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final payment = _payments[index];
                    Color statusColor = Colors.orange;
                    if (payment.paymentStatus == 'Approved') {
                      statusColor = Colors.green;
                    } else if (payment.paymentStatus == 'Rejected') {
                      statusColor = Colors.red;
                    } else {
                      statusColor = Colors.amber;
                    }

                    final String bRef = payment.bookingId.length > 8
                        ? payment.bookingId.substring(0, 8).toUpperCase()
                        : payment.bookingId.toUpperCase();

                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                          child: Icon(Icons.payments_outlined, color: statusColor, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RM ${payment.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryBlue),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ref Booking: #$bRef',
                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            payment.paymentStatus ?? 'Pending Verification',
                            style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }
}
