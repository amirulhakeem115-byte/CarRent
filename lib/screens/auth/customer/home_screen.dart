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
import 'vehicle_details_screen.dart';
import 'vehicle_list_screen.dart';
import 'profile_screen.dart';
import '../login_screen.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';

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

  UserModel? _user;
  List<BranchModel> _branches = [];
  BranchModel? _selectedBranch;
  List<VehicleModel> _vehicles = [];
  List<NotificationModel> _notifications = [];
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
      backgroundColor: const Color(0xFFF8F9FA),
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
                            color: Color(0xFF1E3C72),
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
                    // Header container with gradient
                    Container(
                      padding: const EdgeInsets.only(left: 24, right: 24, top: 60, bottom: 32),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
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
                                     style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _user?.fullName ?? 'Valued Customer',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Stack(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                                        onPressed: _showNotifications,
                                      ),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.redAccent,
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
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                      ).then((_) => _loadData());
                                    },
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white24,
                                      backgroundImage: _user?.profileImage != null && _user!.profileImage.isNotEmpty
                                          ? NetworkImage(_user!.profileImage)
                                          : null,
                                      child: _user?.profileImage == null || _user!.profileImage.isEmpty
                                          ? const Icon(Icons.person, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Branch Filter Dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<BranchModel>(
                                hint: const Text('Filter by Branch Location'),
                                value: _selectedBranch,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<BranchModel>(
                                    value: null,
                                    child: Text('All Branches'),
                                  ),
                                  ..._branches.map((BranchModel b) {
                                    return DropdownMenuItem<BranchModel>(
                                      value: b,
                                      child: Text(b.name),
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
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
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
                            icon: Icons.logout,
                            label: 'Logout',
                            onTap: () async {
                              final nav = Navigator.of(context);
                              await _authService.logout();
                              nav.pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                                (route) => false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Vehicles list header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedBranch == null
                                ? 'Available Fleet'
                                : 'Available at ${_selectedBranch!.name}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const VehicleListScreen()),
                              );
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Vehicles list
                    filteredVehicles.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.car_rental, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No vehicles available at this location right now.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 280,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(left: 24, right: 8),
                              itemCount: filteredVehicles.length,
                              itemBuilder: (context, index) {
                                final vehicle = filteredVehicles[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 220,
                                    margin: const EdgeInsets.only(right: 16, bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                          child: vehicle.mainImage.isNotEmpty
                                              ? Image.network(
                                                  vehicle.mainImage,
                                                  height: 130,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => Container(
                                                    height: 130,
                                                    color: Colors.grey[200],
                                                    child: const Icon(Icons.car_rental, size: 48, color: Colors.grey),
                                                  ),
                                                )
                                              : Container(
                                                  height: 130,
                                                  color: Colors.grey[200],
                                                  child: const Icon(Icons.car_rental, size: 48, color: Colors.grey),
                                                ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${vehicle.brand} ${vehicle.model}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Color(0xFF2C3E50),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    vehicle.branchName.isNotEmpty ? vehicle.branchName : 'General',
                                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'RM ${vehicle.pricePerDay.toStringAsFixed(0)}/day',
                                                    style: const TextStyle(
                                                      color: Color(0xFF1E3C72),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: vehicle.isAvailable
                                                          ? Colors.green.withValues(alpha: 0.1)
                                                          : Colors.redAccent.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      vehicle.isAvailable ? 'Available' : 'Booked',
                                                      style: TextStyle(
                                                        color: vehicle.isAvailable ? Colors.green : Colors.redAccent,
                                                        fontSize: 10,
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
                              },
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                   color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF1E3C72), size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }
}
