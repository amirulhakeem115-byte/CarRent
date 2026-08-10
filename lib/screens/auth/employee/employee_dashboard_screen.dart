import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../models/booking_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/database_service.dart';
import '../../../services/user_session.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/return_video_evidence_widget.dart';
import '../../../widgets/upload_video_modal_sheet.dart';
import '../login_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final AuthService _authService = AuthService();
  final BookingService _bookingService = BookingService();
  final VehicleService _vehicleService = VehicleService();
  final DatabaseService _databaseService = DatabaseService();

  UserModel? _employeeUser;
  List<BookingModel> _bookings = [];
  Map<String, VehicleModel> _vehicleMap = {};
  bool _loading = true;
  String? _error;

  // Active Navigation Tab: 'Overview', 'All Queue Tasks', 'Fleet Vehicles', 'My Profile'
  String _activeTab = 'Overview';

  // All Queue Tasks Filters
  final TextEditingController _taskSearchController = TextEditingController();
  String _taskTypeFilter = 'All'; // 'All', 'Pickup', 'Return', 'Delivery'
  String _taskStatusFilter = 'All'; // 'All', 'Pending', 'Ongoing', 'Completed', 'Cancelled'
  String _taskDateFilter = 'All Time'; // 'All Time', 'Today', 'Next 7 Days', 'Overdue'
  String _taskSortOrder = 'Newest First'; // 'Newest First', 'Oldest First', 'Scheduled Date'

  // Fleet Vehicles Filters
  final TextEditingController _fleetSearchController = TextEditingController();
  String _fleetStatusFilter = 'All'; // 'All', 'Available', 'Booked', 'Maintenance', 'Inactive'

  StreamSubscription? _bookingsSubscription;
  StreamSubscription? _vehiclesSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeStreams();
    _taskSearchController.addListener(_onSearchChanged);
    _fleetSearchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _vehiclesSubscription?.cancel();
    _taskSearchController.dispose();
    _fleetSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
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
        _employeeUser = await UserSession().fetchAndCacheUserModel(currentUser.uid);
      }

      final bookings = await _bookingService.getBookings(forceRefresh: true);
      final vehicles = await _vehicleService.getVehicles();

      final vMap = <String, VehicleModel>{};
      for (final v in vehicles) {
        vMap[v.id] = v;
      }

      if (mounted) {
        setState(() {
          _bookings = bookings;
          _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _vehicleMap = vMap;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[EmployeeDashboard] Error loading data: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load employee dashboard data. Error: $e';
          _loading = false;
        });
      }
    }
  }

  void _subscribeStreams() {
    _bookingsSubscription = _bookingService.getBookingsStream().listen((bList) {
      if (mounted) {
        setState(() {
          _bookings = bList;
          _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      }
    }, onError: (err) {
      debugPrint('[EmployeeDashboard] Bookings stream error: $err');
    });

    _vehiclesSubscription = _vehicleService.getVehiclesStream().listen((vList) {
      if (mounted) {
        final vMap = <String, VehicleModel>{};
        for (final v in vList) {
          vMap[v.id] = v;
        }
        setState(() {
          _vehicleMap = vMap;
        });
      }
    }, onError: (err) {
      debugPrint('[EmployeeDashboard] Vehicles stream error: $err');
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the Employee Portal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      UserSession().clear();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen(onLoggedIn: () {})),
          (route) => false,
        );
      }
    }
  }

  // ── STRICT EMPLOYEE TASK ASSIGNMENT FILTER ──
  bool _isTaskAssignedToCurrentEmployee(BookingModel b) {
    if (_employeeUser == null && _authService.currentUser == null) return false;

    final currentUid = (_authService.currentUser?.uid ?? '').trim().toLowerCase();
    final empId = (_employeeUser?.employeeId ?? '').trim().toLowerCase();
    final empUid = (_employeeUser?.id ?? currentUid).trim().toLowerCase();

    final bAssigned = (b.assignedEmployeeId ?? '').trim().toLowerCase();
    final bHandedOver = (b.handedOverByEmployeeId ?? '').trim().toLowerCase();
    final bReceived = (b.receivedByEmployeeId ?? '').trim().toLowerCase();

    final matchesAssigned = bAssigned.isNotEmpty && (bAssigned == empId || bAssigned == empUid);
    final matchesHandedOver = bHandedOver.isNotEmpty && (bHandedOver == empId || bHandedOver == empUid);
    final matchesReceived = bReceived.isNotEmpty && (bReceived == empId || bReceived == empUid);

    return matchesAssigned || matchesHandedOver || matchesReceived;
  }

  // ── TASK CLASSIFICATION HELPERS (Scoped to Current Employee & Active States) ──
  List<BookingModel> get _pickupTasks {
    return _bookings.where((b) {
      final s = b.status.toLowerCase();
      final isUpcoming = BookingService.isUpcomingStatus(b.status) || s == 'pending pickup';
      final isNotClosed = !BookingService.isClosedStatus(b.status) && s != 'cancelled' && s != 'canceled' && s != 'rejected';
      return isUpcoming && isNotClosed && _isTaskAssignedToCurrentEmployee(b);
    }).toList();
  }

  List<BookingModel> get _returnTasks {
    return _bookings.where((b) {
      final s = b.status.toLowerCase();
      final isOngoing = BookingService.isOngoingStatus(b.status);
      final isNotClosed = !BookingService.isClosedStatus(b.status) && s != 'cancelled' && s != 'canceled' && s != 'rejected';
      return isOngoing && isNotClosed && _isTaskAssignedToCurrentEmployee(b);
    }).toList();
  }

  List<BookingModel> get _deliveryTasks {
    return _bookings.where((b) {
      final noteLower = (b.notes ?? '').toLowerCase();
      final statusLower = b.status.toLowerCase();
      final custStatusLower = (b.customerStatus ?? '').toLowerCase();
      final isDelivery = noteLower.contains('deliver') ||
          statusLower.contains('deliver') ||
          custStatusLower.contains('deliver') ||
          (b.notes != null && b.notes!.trim().isNotEmpty && (statusLower == 'approved' || statusLower == 'confirmed'));
      final isNotClosed = !BookingService.isClosedStatus(b.status) && statusLower != 'cancelled' && statusLower != 'canceled' && statusLower != 'rejected';
      return isDelivery && isNotClosed && _isTaskAssignedToCurrentEmployee(b);
    }).toList();
  }

  String _getTaskType(BookingModel b) {
    final noteLower = (b.notes ?? '').toLowerCase();
    final statusLower = b.status.toLowerCase();
    if (noteLower.contains('deliver') || statusLower.contains('deliver')) return 'Delivery';
    if (BookingService.isOngoingStatus(b.status)) return 'Return';
    return 'Pickup';
  }

  String _getLocationForBooking(BookingModel b, {bool isDelivery = false}) {
    if (isDelivery && b.notes != null && b.notes!.trim().isNotEmpty) {
      return b.notes!;
    }
    final vehicle = _vehicleMap[b.vehicleId];
    if (vehicle != null && vehicle.branchName.isNotEmpty) {
      return '${vehicle.branchName} Branch';
    }
    return 'Main Branch Headquarters';
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBookingStatus(
    BookingModel booking,
    String newStatus, {
    Map<String, dynamic>? returnInspection,
  }) async {
    // Security check: verify task assignment before status modification
    if (!_isTaskAssignedToCurrentEmployee(booking)) {
      _showErrorDialog('Access Denied', 'You are not authorized to manage tasks assigned to another employee.');
      return;
    }

    final sLower = booking.status.toLowerCase();
    final targetLower = newStatus.toLowerCase();

    // Pre-action Eligibility Validation
    if (targetLower == 'active' && (sLower == 'completed' || sLower == 'cancelled' || sLower == 'canceled' || sLower == 'rejected')) {
      _showErrorDialog('Invalid Handover Action', 'Cannot hand over a booking that is already completed, cancelled, or rejected.');
      return;
    }

    if (targetLower == 'completed' && (sLower == 'pending' || sLower == 'pending payment')) {
      _showErrorDialog('Invalid Return Action', 'Cannot process vehicle return for a booking that has not been handed over yet.');
      return;
    }

    try {
      final empId = _employeeUser?.employeeId.isNotEmpty == true ? _employeeUser!.employeeId : (_employeeUser?.id ?? 'EMP-STAFF');
      final empName = _employeeUser?.fullName.isNotEmpty == true ? _employeeUser!.fullName : 'Staff Employee';

      await _bookingService.updateBookingStatus(
        booking.id,
        newStatus,
        booking.userId,
        booking.vehicleId,
        booking.vehicleName,
        employeeId: empId,
        employeeName: empName,
        returnInspection: returnInspection,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking #${booking.id.substring(0, 6).toUpperCase()} status updated to ${newStatus.toUpperCase()} successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[EmployeeDashboard] Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _openTaskDetailsModal({
    required String taskType, // 'Pickup', 'Return', 'Delivery'
    required BookingModel booking,
  }) async {
    // Security authorization check before opening details
    if (!_isTaskAssignedToCurrentEmployee(booking)) {
      _showErrorDialog('Access Denied', 'You are not authorized to view or manage tasks assigned to another employee.');
      return;
    }

    UserModel? customer;
    try {
      customer = await _databaseService.getUser(booking.userId);
    } catch (_) {}

    if (!mounted) return;

    final vehicle = _vehicleMap[booking.vehicleId];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskWorkflowModalSheet(
        taskType: taskType,
        booking: booking,
        customer: customer,
        vehicle: vehicle,
        location: _getLocationForBooking(booking, isDelivery: taskType == 'Delivery'),
        onUpdateStatus: (newStatus, [returnInspectionMap]) {
          Navigator.pop(ctx);
          _updateBookingStatus(booking, newStatus, returnInspection: returnInspectionMap);
        },
      ),
    );
  }

  void _openCategoryTasksListModal(String taskType, List<BookingModel> tasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryTasksListSheet(
        taskType: taskType,
        tasks: tasks,
        vehicleMap: _vehicleMap,
        onSelectTask: (b) {
          Navigator.pop(ctx);
          _openTaskDetailsModal(taskType: taskType, booking: b);
        },
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _employeeUser?.fullName ?? '');
    final phoneController = TextEditingController(text: _employeeUser?.phone ?? '');
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_outline, color: AppColors.primaryOrange),
              SizedBox(width: 10),
              Text('Edit Profile Information', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Employees can only update their personal profile details.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  Text('Email: ${_employeeUser?.email ?? "N/A"}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  Text('Employee ID: ${_employeeUser?.employeeId ?? "EMP-STAFF"}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  Text('Assigned Role: ${_employeeUser?.normalizedRole.toUpperCase() ?? "EMPLOYEE"} (Locked)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
              onPressed: saving
                  ? null
                  : () async {
                      setModalState(() => saving = true);
                      try {
                        await _databaseService.updateUser(_employeeUser!.id, {
                          'fullName': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                        });
                        await UserSession().fetchAndCacheUserModel(_employeeUser!.id);
                        await _loadData();
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        setModalState(() => saving = false);
                      }
                    },
              child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVehicleDetailsModal(VehicleModel vehicle) {
    final activeBooking = _bookings.firstWhere(
      (b) => b.vehicleId == vehicle.id && (BookingService.isOngoingStatus(b.status) || BookingService.isUpcomingStatus(b.status)),
      orElse: () => BookingModel(
        id: '',
        vehicleId: '',
        vehicleName: '',
        userId: '',
        userName: '',
        userPhone: '',
        pickUpDate: DateTime.now(),
        totalPrice: 0,
        depositAmount: 0,
        status: '',
        createdAt: DateTime.now(),
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VehicleDetailsSheet(vehicle: vehicle, activeBooking: activeBooking.id.isNotEmpty ? activeBooking : null),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  const AppLogo(size: 32, fallbackColor: AppColors.primaryOrange),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'CarRent Employee Portal',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
                      ),
                      Text('Staff Operations, Queue & Fleet Operations', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const Spacer(),
                  CircleAvatar(
                    backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.15),
                    child: Text(
                      _employeeUser?.fullName.isNotEmpty == true ? _employeeUser!.fullName[0].toUpperCase() : 'E',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (isDesktop)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_employeeUser?.fullName ?? 'Employee', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.secondaryBlue)),
                        Text('Employee ID: ${_employeeUser?.employeeId.isNotEmpty == true ? _employeeUser!.employeeId : "EMP-STAFF"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    tooltip: 'Logout',
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          if (isDesktop)
            Container(
              width: 230,
              color: isDark ? const Color(0xFF172033) : AppColors.secondaryBlue,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildSidebarItem(Icons.dashboard_outlined, 'Overview', _activeTab == 'Overview'),
                  _buildSidebarItem(Icons.assignment_outlined, 'All Queue Tasks', _activeTab == 'All Queue Tasks'),
                  _buildSidebarItem(Icons.directions_car_outlined, 'Fleet Vehicles', _activeTab == 'Fleet Vehicles'),
                  _buildSidebarItem(Icons.person_outline, 'My Profile', _activeTab == 'My Profile'),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildActiveTabContent(isDesktop: isDesktop),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? BottomNavigationBar(
              currentIndex: _mobileTabIndex(),
              selectedItemColor: AppColors.primaryOrange,
              unselectedItemColor: Colors.grey,
              onTap: (index) {
                setState(() {
                  if (index == 0) _activeTab = 'Overview';
                  if (index == 1) _activeTab = 'All Queue Tasks';
                  if (index == 2) _activeTab = 'Fleet Vehicles';
                  if (index == 3) _activeTab = 'My Profile';
                });
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
                BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Queue'),
                BottomNavigationBarItem(icon: Icon(Icons.directions_car_outlined), label: 'Fleet'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
              ],
            )
          : null,
    );
  }

  int _mobileTabIndex() {
    if (_activeTab == 'All Queue Tasks') return 1;
    if (_activeTab == 'Fleet Vehicles') return 2;
    if (_activeTab == 'My Profile') return 3;
    return 0;
  }

  Widget _buildSidebarItem(IconData icon, String title, bool isSelected) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primaryOrange : Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primaryOrange : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () => setState(() => _activeTab = title),
    );
  }

  Widget _buildActiveTabContent({required bool isDesktop}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: LoadingWidget(message: 'Syncing Realtime Employee Portal...')),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.redAccent)),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry Connection')),
          ],
        ),
      );
    }

    if (_activeTab == 'Overview') {
      return _buildOverviewTab(isDesktop: isDesktop, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor);
    } else if (_activeTab == 'All Queue Tasks') {
      return _buildAllQueueTasksTab(isDesktop: isDesktop, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor);
    } else if (_activeTab == 'Fleet Vehicles') {
      return _buildFleetVehiclesTab(isDesktop: isDesktop, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor);
    } else if (_activeTab == 'My Profile') {
      return _buildMyProfileTab(isDesktop: isDesktop, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor);
    } else {
      return _buildOverviewTab(isDesktop: isDesktop, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor);
    }
  }

  // =========================================================================
  // 1. OVERVIEW TAB
  // =========================================================================
  Widget _buildOverviewTab({
    required bool isDesktop,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    final pickups = _pickupTasks;
    final returns = _returnTasks;
    final deliveries = _deliveryTasks;

    final now = DateTime.now();

    // Scoped assigned tasks list (Active & Pending tasks assigned to logged-in employee)
    final assignedBookings = _bookings.where((b) {
      final sLower = b.status.toLowerCase();
      final isClosedOrCancelled = BookingService.isClosedStatus(b.status) || sLower == 'cancelled' || sLower == 'canceled' || sLower == 'rejected';
      return _isTaskAssignedToCurrentEmployee(b) && !isClosedOrCancelled;
    }).toList();

    final totalAssigned = assignedBookings.length;
    final pendingCount = assignedBookings.where((b) => BookingService.isUpcomingStatus(b.status) || b.status.toLowerCase() == 'pending pickup').length;
    final ongoingCount = assignedBookings.where((b) => BookingService.isOngoingStatus(b.status)).length;
    final completedCount = _bookings.where((b) => _isTaskAssignedToCurrentEmployee(b) && (BookingService.isClosedStatus(b.status) || b.status.toLowerCase() == 'completed')).length;

    final todayCount = assignedBookings.where((b) {
      final pDate = b.pickUpDate;
      final rDate = b.returnDate;
      final isPickupToday = pDate.year == now.year && pDate.month == now.month && pDate.day == now.day;
      final isReturnToday = rDate != null && rDate.year == now.year && rDate.month == now.month && rDate.day == now.day;
      return isPickupToday || isReturnToday;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operational Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary)),
                const SizedBox(height: 4),
                const Text('Live Firebase Metrics, Handover Cards & Employee Statistics', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh Realtime Data', onPressed: _loadData),
          ],
        ),
        const SizedBox(height: 20),

        // STATS BAR
        GridView.count(
          crossAxisCount: isDesktop ? 5 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          childAspectRatio: isDesktop ? 1.6 : 1.3,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStatCard('Assigned Tasks', totalAssigned.toString(), Icons.assignment_outlined, Colors.indigo, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor),
            _buildStatCard('Pending Tasks', pendingCount.toString(), Icons.hourglass_top_rounded, Colors.orange, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor),
            _buildStatCard('Ongoing Rentals', ongoingCount.toString(), Icons.directions_car_rounded, Colors.blue, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor),
            _buildStatCard('Today\'s Tasks', todayCount.toString(), Icons.today_rounded, Colors.teal, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor),
            _buildStatCard('Completed', completedCount.toString(), Icons.task_alt_rounded, Colors.green, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor),
          ],
        ),
        const SizedBox(height: 24),

        // THREE SEPARATE TASK CARDS: [ PICKUP ] [ RETURN ] [ DELIVERY ]
        LayoutBuilder(
          builder: (context, constraints) {
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPickupCard(pickups, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildReturnCard(returns, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDeliveryCard(deliveries, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor)),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildPickupCard(pickups, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor),
                  const SizedBox(height: 16),
                  _buildReturnCard(returns, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor),
                  const SizedBox(height: 16),
                  _buildDeliveryCard(deliveries, cardColor: cardColor, textPrimary: textPrimary, borderColor: borderColor),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  // =========================================================================
  // 2. ALL QUEUE TASKS TAB (Filtered strictly to current assigned employee)
  // =========================================================================
  Widget _buildAllQueueTasksTab({
    required bool isDesktop,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    final query = _taskSearchController.text.trim().toLowerCase();
    final now = DateTime.now();

    List<BookingModel> filtered = _bookings.where((b) {
      final statusLower = b.status.toLowerCase();

      // Exclude historical completed or cancelled bookings from active queue
      if (BookingService.isClosedStatus(b.status) || statusLower == 'cancelled' || statusLower == 'canceled' || statusLower == 'rejected') {
        return false;
      }

      // Strictly filter by assigned employee ID
      if (!_isTaskAssignedToCurrentEmployee(b)) {
        return false;
      }

      final taskType = _getTaskType(b);

      // Type Filter
      if (_taskTypeFilter != 'All' && taskType.toLowerCase() != _taskTypeFilter.toLowerCase()) return false;

      // Status Filter
      if (_taskStatusFilter == 'Pending' && !BookingService.isUpcomingStatus(b.status)) return false;
      if (_taskStatusFilter == 'Ongoing' && !BookingService.isOngoingStatus(b.status)) return false;

      // Date Filter
      if (_taskDateFilter == 'Today') {
        if (b.pickUpDate.year != now.year || b.pickUpDate.month != now.month || b.pickUpDate.day != now.day) return false;
      } else if (_taskDateFilter == 'Next 7 Days') {
        final diff = b.pickUpDate.difference(now).inDays;
        if (diff < 0 || diff > 7) return false;
      } else if (_taskDateFilter == 'Overdue') {
        if (!BookingService.isOngoingStatus(b.status) || b.returnDate == null || !now.isAfter(b.returnDate!)) return false;
      }

      // Search Query
      if (query.isNotEmpty) {
        final bId = b.id.toLowerCase();
        final cust = b.userName.toLowerCase();
        final veh = b.vehicleName.toLowerCase();
        final loc = _getLocationForBooking(b).toLowerCase();
        if (!bId.contains(query) && !cust.contains(query) && !veh.contains(query) && !loc.contains(query)) return false;
      }

      return true;
    }).toList();

    // Sort
    if (_taskSortOrder == 'Oldest First') {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else if (_taskSortOrder == 'Scheduled Date') {
      filtered.sort((a, b) => a.pickUpDate.compareTo(b.pickUpDate));
    } else {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Assigned Tasks Queue', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary)),
        const SizedBox(height: 4),
        Text('Active Operational Tasks Assigned to Staff ID: ${_employeeUser?.employeeId.isNotEmpty == true ? _employeeUser!.employeeId : "EMP-STAFF"}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 20),

        // SEARCH & FILTERS BAR
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(
            children: [
              TextField(
                controller: _taskSearchController,
                decoration: InputDecoration(
                  hintText: 'Search my tasks by Booking ID, Customer Name, Vehicle Model, or Location...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _taskSearchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _taskSearchController.clear()) : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterDropdown<String>(
                      label: 'Type',
                      value: _taskTypeFilter,
                      items: const ['All', 'Pickup', 'Return', 'Delivery'],
                      onChanged: (val) => setState(() => _taskTypeFilter = val!),
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                    ),
                    const SizedBox(width: 10),
                    _buildFilterDropdown<String>(
                      label: 'Status',
                      value: _taskStatusFilter,
                      items: const ['All', 'Pending', 'Ongoing'],
                      onChanged: (val) => setState(() => _taskStatusFilter = val!),
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                    ),
                    const SizedBox(width: 10),
                    _buildFilterDropdown<String>(
                      label: 'Date',
                      value: _taskDateFilter,
                      items: const ['All Time', 'Today', 'Next 7 Days', 'Overdue'],
                      onChanged: (val) => setState(() => _taskDateFilter = val!),
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                    ),
                    const SizedBox(width: 10),
                    _buildFilterDropdown<String>(
                      label: 'Sort',
                      value: _taskSortOrder,
                      items: const ['Newest First', 'Oldest First', 'Scheduled Date'],
                      onChanged: (val) => setState(() => _taskSortOrder = val!),
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // TASK LIST
        filtered.isEmpty
            ? Container(
                height: 200,
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_ind_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('No active tasks currently assigned to you.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final b = filtered[idx];
                  final taskType = _getTaskType(b);
                  final isPending = BookingService.isUpcomingStatus(b.status);
                  final isOngoing = BookingService.isOngoingStatus(b.status);

                  Color badgeColor = Colors.teal;
                  if (taskType == 'Return') badgeColor = AppColors.primaryOrange;
                  if (taskType == 'Delivery') badgeColor = Colors.blue;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(
                            taskType == 'Pickup' ? Icons.key_rounded : (taskType == 'Return' ? Icons.assignment_return_rounded : Icons.local_shipping_rounded),
                            color: badgeColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
                                    child: Text(taskType.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Booking #${b.id.substring(0, 6).toUpperCase()}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPending ? Colors.orange.withValues(alpha: 0.15) : (isOngoing ? Colors.blue.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(b.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPending ? Colors.orange : (isOngoing ? Colors.blue : Colors.green))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Customer: ${b.userName} (${b.userPhone.isNotEmpty ? b.userPhone : "N/A"})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('Vehicle: ${b.vehicleName} • Location: ${_getLocationForBooking(b, isDelivery: taskType == 'Delivery')}', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('Assigned Staff: ${_employeeUser?.employeeId.isNotEmpty == true ? _employeeUser!.employeeId : "EMP-STAFF"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: badgeColor, foregroundColor: Colors.white),
                          onPressed: () => _openTaskDetailsModal(taskType: taskType, booking: b),
                          child: const Text('View Task Details'),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  // =========================================================================
  // 3. FLEET VEHICLES TAB
  // =========================================================================
  Widget _buildFleetVehiclesTab({
    required bool isDesktop,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    final query = _fleetSearchController.text.trim().toLowerCase();

    final vehiclesList = _vehicleMap.values.where((v) {
      if (_fleetStatusFilter != 'All' && v.status.toLowerCase() != _fleetStatusFilter.toLowerCase()) return false;
      if (query.isNotEmpty) {
        final name = v.name.toLowerCase();
        final plate = v.plateNumber.toLowerCase();
        final id = v.id.toLowerCase();
        final branch = v.branchName.toLowerCase();
        if (!name.contains(query) && !plate.contains(query) && !id.contains(query) && !branch.contains(query)) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fleet Vehicle Directory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary)),
        const SizedBox(height: 4),
        const Text('Realtime Fleet Inventory & Active Booking Status', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 20),

        // SEARCH & FILTER BAR
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fleetSearchController,
                  decoration: const InputDecoration(
                    hintText: 'Search fleet by Vehicle Name, Plate Number, ID or Branch...',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildFilterDropdown<String>(
                label: 'Status',
                value: _fleetStatusFilter,
                items: const ['All', 'Available', 'Booked', 'Maintenance', 'Inactive'],
                onChanged: (val) => setState(() => _fleetStatusFilter = val!),
                cardColor: cardColor,
                textPrimary: textPrimary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // VEHICLES GRID
        vehiclesList.isEmpty
            ? Container(
                height: 200,
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('No vehicles match the selected criteria.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 3 : 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isDesktop ? 1.25 : 1.6,
                ),
                itemCount: vehiclesList.length,
                itemBuilder: (context, idx) {
                  final v = vehiclesList[idx];
                  final isAvailable = v.status.toLowerCase() == 'available';

                  // Active booking lookup if vehicle is booked
                  final activeBooking = _bookings.firstWhere(
                    (b) => b.vehicleId == v.id && (BookingService.isOngoingStatus(b.status) || BookingService.isUpcomingStatus(b.status)),
                    orElse: () => BookingModel(id: '', vehicleId: '', vehicleName: '', userId: '', userName: '', userPhone: '', pickUpDate: DateTime.now(), totalPrice: 0, depositAmount: 0, status: '', createdAt: DateTime.now()),
                  );

                  return Container(
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vehicle Image Banner
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                          child: SizedBox(
                            height: 110,
                            width: double.infinity,
                            child: AppImage(
                              imageSrc: v.mainImage,
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: Colors.grey.shade200,
                                child: const Center(child: Icon(Icons.directions_car, size: 48, color: Colors.grey)),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(v.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isAvailable ? Colors.teal.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(v.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAvailable ? Colors.teal : Colors.orange)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Plate: ${v.plateNumber} • ID: ${v.id.substring(0, 6)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              Text('Location: ${v.branchName.isNotEmpty ? v.branchName : "Main Depot"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              if (activeBooking.id.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text('Current Renter: ${activeBooking.userName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ),
                              ],
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => _showVehicleDetailsModal(v),
                                  child: const Text('View Specs & Details'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  // =========================================================================
  // 4. MY PROFILE TAB
  // =========================================================================
  Widget _buildMyProfileTab({
    required bool isDesktop,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                child: Text(
                  _employeeUser?.fullName.isNotEmpty == true ? _employeeUser!.fullName[0].toUpperCase() : 'E',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_employeeUser?.fullName ?? 'Employee Staff', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
                  Text('Employee ID: ${_employeeUser?.employeeId.isNotEmpty == true ? _employeeUser!.employeeId : "EMP-STAFF"}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Text('ACCOUNT STATUS: ${_employeeUser?.accountStatus.toUpperCase() ?? "ACTIVE"}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
                onPressed: _showEditProfileDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
              ),
            ],
          ),
          const Divider(height: 32),

          Text('Employee Credentials & Role Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.person_outline), title: Text(_employeeUser?.fullName ?? 'Employee'), subtitle: const Text('Full Name (Editable)')),
          ListTile(leading: const Icon(Icons.email_outlined), title: Text(_employeeUser?.email ?? 'N/A'), subtitle: const Text('Primary Email Address (Locked)')),
          ListTile(leading: const Icon(Icons.phone_outlined), title: Text(_employeeUser?.phone.isNotEmpty == true ? _employeeUser!.phone : 'N/A'), subtitle: const Text('Phone Number (Editable)')),
          ListTile(leading: const Icon(Icons.badge_outlined), title: Text(_employeeUser?.employeeId.isNotEmpty == true ? _employeeUser!.employeeId : 'EMP-STAFF'), subtitle: const Text('Employee Staff ID (Locked)')),
          ListTile(
            leading: const Icon(Icons.security_outlined, color: Colors.redAccent),
            title: Text(_employeeUser?.normalizedRole.toUpperCase() ?? 'EMPLOYEE', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
            subtitle: const Text('Assigned System Role (Role elevation disabled for staff accounts)'),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log Out of Staff Portal'),
          ),
        ],
      ),
    );
  }

  // ── HELPER WIDGETS ──
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textPrimary)),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required Color cardColor,
    required Color textPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: cardColor,
          style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
          items: items.map((i) => DropdownMenuItem<T>(value: i, child: Text('$label: $i'))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // 1. PICKUP CARD
  Widget _buildPickupCard(
    List<BookingModel> pickups, {
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    final topBooking = pickups.isNotEmpty ? pickups.first : null;
    final topVehicle = topBooking != null ? _vehicleMap[topBooking.vehicleId] : null;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.teal.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.12), borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.key_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PICKUP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: 0.8)), const Text('Vehicle Handover Tasks', style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(20)), child: Text('${pickups.length} PENDING', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white))),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: pickups.isEmpty
                ? const SizedBox(
                    height: 160,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.teal, size: 44),
                          SizedBox(height: 8),
                          Text('No current pickup', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('No pickup task assigned to you.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Next Pickup Priority:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Row(children: [const Icon(Icons.person_outline, size: 16, color: Colors.teal), const SizedBox(width: 6), Expanded(child: Text('Customer: ${topBooking!.userName}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)))]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.directions_car_outlined, size: 16, color: Colors.teal), const SizedBox(width: 6), Expanded(child: Text('Vehicle: ${topBooking.vehicleName} ${topVehicle != null ? "(${topVehicle.plateNumber})" : ""}', style: const TextStyle(fontSize: 12, color: Colors.grey)))]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.teal), const SizedBox(width: 6), Expanded(child: Text('Time: ${_formatDate(topBooking.pickUpDate)}', style: const TextStyle(fontSize: 12, color: Colors.grey)))]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.location_on_outlined, size: 16, color: Colors.teal), const SizedBox(width: 6), Expanded(child: Text('Location: ${_getLocationForBooking(topBooking)}', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                      const SizedBox(height: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text('STATUS: ${topBooking.status.toUpperCase()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.teal))),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () => _openTaskDetailsModal(taskType: 'Pickup', booking: topBooking), icon: const Icon(Icons.key, size: 18), label: const Text('Open Pickup Task', style: TextStyle(fontWeight: FontWeight.bold)))),
                      if (pickups.length > 1) ...[const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.teal), onPressed: () => _openCategoryTasksListModal('Pickup', pickups), child: Text('View All ${pickups.length} Pickups')))],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // 2. RETURN CARD
  Widget _buildReturnCard(
    List<BookingModel> returns, {
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    final topBooking = returns.isNotEmpty ? returns.first : null;
    final topVehicle = topBooking != null ? _vehicleMap[topBooking.vehicleId] : null;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.primaryOrange.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.primaryOrange.withValues(alpha: 0.12), borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.assignment_return_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RETURN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: 0.8)), const Text('Inspection & Check-in Tasks', style: TextStyle(fontSize: 11, color: AppColors.primaryOrange, fontWeight: FontWeight.bold))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(20)), child: Text('${returns.length} PENDING', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white))),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: returns.isEmpty
                ? const SizedBox(
                    height: 160,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.task_alt, color: AppColors.primaryOrange, size: 44),
                          SizedBox(height: 8),
                          Text('No current return', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('No return task assigned to you.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Next Return Priority:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Row(children: [const Icon(Icons.person_outline, size: 16, color: AppColors.primaryOrange), const SizedBox(width: 6), Expanded(child: Text('Customer: ${topBooking!.userName}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)))]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.directions_car_outlined, size: 16, color: AppColors.primaryOrange), const SizedBox(width: 6), Expanded(child: Text('Vehicle: ${topBooking.vehicleName} ${topVehicle != null ? "(${topVehicle.plateNumber})" : ""}', style: const TextStyle(fontSize: 12, color: Colors.grey)))]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.event_outlined, size: 16, color: AppColors.primaryOrange), const SizedBox(width: 6), Expanded(child: Text('Return: ${_formatDate(topBooking.returnDate)}', style: const TextStyle(fontSize: 12, color: Colors.grey)))]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primaryOrange), const SizedBox(width: 6), Expanded(child: Text('Location: ${_getLocationForBooking(topBooking)}', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                      const SizedBox(height: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.primaryOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text('STATUS: ${topBooking.status.toUpperCase()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryOrange))),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () => _openTaskDetailsModal(taskType: 'Return', booking: topBooking), icon: const Icon(Icons.assignment_turned_in, size: 18), label: const Text('Open Return Task', style: TextStyle(fontWeight: FontWeight.bold)))),
                      if (returns.length > 1) ...[const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryOrange), onPressed: () => _openCategoryTasksListModal('Return', returns), child: Text('View All ${returns.length} Returns')))],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // 3. DELIVERY CARD
  Widget _buildDeliveryCard(
    List<BookingModel> deliveries, {
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    final topBooking = deliveries.isNotEmpty ? deliveries.first : null;
    final topVehicle = topBooking != null ? _vehicleMap[topBooking.vehicleId] : null;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.12), borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('DELIVERY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: 0.8)), const Text('Drop-off & Dispatch Tasks', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)), child: Text('${deliveries.length} PENDING', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white))),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: deliveries.isEmpty
                ? const SizedBox(
                    height: 160,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_outlined, color: Colors.blue, size: 44),
                          SizedBox(height: 8),
                          Text('No current delivery', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('No delivery task assigned to you.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Next Delivery Priority:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Row(children: [const Icon(Icons.person_outline, size: 16, color: Colors.blue), const SizedBox(width: 6), Expanded(child: Text('Customer: ${topBooking!.userName}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)))]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.directions_car_outlined, size: 16, color: Colors.blue), const SizedBox(width: 6), Expanded(child: Text('Vehicle: ${topBooking.vehicleName} ${topVehicle != null ? "(${topVehicle.plateNumber})" : ""}', style: const TextStyle(fontSize: 12, color: Colors.grey)))]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.schedule_outlined, size: 16, color: Colors.blue), const SizedBox(width: 6), Expanded(child: Text('Dispatch: ${_formatDate(topBooking.pickUpDate)}', style: const TextStyle(fontSize: 12, color: Colors.grey)))]),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.map_outlined, size: 16, color: Colors.blue), const SizedBox(width: 6), Expanded(child: Text('Address: ${_getLocationForBooking(topBooking, isDelivery: true)}', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                      const SizedBox(height: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text('STATUS: ${topBooking.status.toUpperCase()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue))),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () => _openTaskDetailsModal(taskType: 'Delivery', booking: topBooking), icon: const Icon(Icons.local_shipping, size: 18), label: const Text('Open Delivery Task', style: TextStyle(fontWeight: FontWeight.bold)))),
                      if (deliveries.length > 1) ...[const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.blue), onPressed: () => _openCategoryTasksListModal('Delivery', deliveries), child: Text('View All ${deliveries.length} Deliveries')))],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TASK WORKFLOW MODAL SHEET (PICKUP / RETURN / DELIVERY)
// ─────────────────────────────────────────────────────────────
class _TaskWorkflowModalSheet extends StatelessWidget {
  final String taskType; // 'Pickup', 'Return', 'Delivery'
  final BookingModel booking;
  final UserModel? customer;
  final VehicleModel? vehicle;
  final String location;
  final Function(String newStatus, [Map<String, dynamic>? returnInspectionMap]) onUpdateStatus;

  const _TaskWorkflowModalSheet({
    required this.taskType,
    required this.booking,
    required this.customer,
    required this.vehicle,
    required this.location,
    required this.onUpdateStatus,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  void _showHandoverConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Colors.teal),
            SizedBox(width: 10),
            Text('Confirm Vehicle Handover', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please verify all details before handing over keys to customer:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Text('Customer Name: ${booking.userName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Phone Number: ${customer?.phone.isNotEmpty == true ? customer!.phone : (booking.userPhone.isNotEmpty ? booking.userPhone : "N/A")}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Vehicle: ${booking.vehicleName} (${vehicle?.plateNumber ?? "N/A"})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Pickup Location: $location', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Deposit Lodged: RM ${booking.depositAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onUpdateStatus('active');
            },
            child: const Text('Hand Over Vehicle & Activate Rental'),
          ),
        ],
      ),
    );
  }

  void _showReturnInspectionDialog(BuildContext context) {
    String vehicleCondition = 'Good / Normal Wear';
    String fuelLevel = 'Full (100%)';
    final mileageController = TextEditingController(text: '45200');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in_rounded, color: AppColors.primaryOrange),
              SizedBox(width: 10),
              Text('Receive Vehicle Return & Inspection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Complete vehicle inspection items before check-in:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: vehicleCondition,
                    decoration: const InputDecoration(labelText: 'Vehicle Condition', prefixIcon: Icon(Icons.car_repair)),
                    items: const [
                      DropdownMenuItem(value: 'Good / Normal Wear', child: Text('Good / Normal Wear')),
                      DropdownMenuItem(value: 'Minor Scratches', child: Text('Minor Scratches')),
                      DropdownMenuItem(value: 'Major Damage / Cleaning Needed', child: Text('Major Damage / Cleaning Needed')),
                    ],
                    onChanged: (val) => setModalState(() => vehicleCondition = val!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: fuelLevel,
                    decoration: const InputDecoration(labelText: 'Fuel Gauge Level', prefixIcon: Icon(Icons.local_gas_station)),
                    items: const [
                      DropdownMenuItem(value: 'Full (100%)', child: Text('Full (100%)')),
                      DropdownMenuItem(value: '3/4 Full', child: Text('3/4 Full')),
                      DropdownMenuItem(value: '1/2 Full', child: Text('1/2 Full')),
                      DropdownMenuItem(value: '1/4 Full', child: Text('1/4 Full')),
                      DropdownMenuItem(value: 'Empty', child: Text('Empty')),
                    ],
                    onChanged: (val) => setModalState(() => fuelLevel = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mileageController,
                    decoration: const InputDecoration(labelText: 'Current Odometer Mileage (km)', prefixIcon: Icon(Icons.speed)),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Inspection Notes / Damage Remarks', prefixIcon: Icon(Icons.note_alt_outlined)),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                final inspectionMap = {
                  'condition': vehicleCondition,
                  'fuelLevel': fuelLevel,
                  'mileage': mileageController.text.trim(),
                  'notes': notesController.text.trim(),
                  'inspectedAt': DateTime.now().toIso8601String(),
                };
                onUpdateStatus('completed', inspectionMap);
              },
              child: const Text('Receive Vehicle & Complete Return'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;

    Color themeColor = Colors.teal;
    IconData themeIcon = Icons.key_rounded;

    if (taskType == 'Return') {
      themeColor = AppColors.primaryOrange;
      themeIcon = Icons.assignment_return_rounded;
    } else if (taskType == 'Delivery') {
      themeColor = Colors.blue;
      themeIcon = Icons.local_shipping_rounded;
    }

    final sLower = booking.status.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: themeColor.withValues(alpha: 0.15), child: Icon(themeIcon, color: themeColor)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$taskType Task Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                      Text('Booking ID: #${booking.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),

            // Vehicle Information Section
            Text('Vehicle Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeColor)),
            const SizedBox(height: 6),
            Text('Model: ${booking.vehicleName}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
            Text('Plate Number: ${vehicle?.plateNumber ?? "N/A"} • Color: ${vehicle?.color ?? "Standard"}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text('Transmission: ${vehicle?.transmission ?? "Auto"} • Fuel: ${vehicle?.fuelType ?? "Petrol"}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),

            // Customer Information Section
            Text('Customer Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeColor)),
            const SizedBox(height: 6),
            Text('Full Name: ${booking.userName}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary)),
            Text('Phone Number: ${customer?.phone.isNotEmpty == true ? customer!.phone : (booking.userPhone.isNotEmpty ? booking.userPhone : "N/A")}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text('Email Address: ${customer?.email ?? booking.userId}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),

            // Schedule & Location Section
            Text('$taskType Schedule & Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeColor)),
            const SizedBox(height: 6),
            Text('Scheduled Time: ${_formatDate(taskType == 'Return' ? booking.returnDate : booking.pickUpDate)}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text('Target Location: $location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
            Text('Current Booking Status: ${booking.status.toUpperCase()}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor)),
            // Return Video Evidence Section (For Return Task)
            if (taskType == 'Return') ...[
              const SizedBox(height: 16),
              ReturnVideoEvidenceWidget(
                booking: booking,
                isEmployeeView: true,
                onUploadClick: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => UploadVideoModalSheet(
                      booking: booking,
                      uploaderId: booking.assignedEmployeeId ?? 'EMP-STAFF',
                      uploaderName: 'Staff Employee',
                      uploaderRole: 'employee',
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),

            // Allowed Employee Actions Workflow
            Text('Execute Staff Workflow Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // PICKUP WORKFLOW ACTIONS
                if (taskType == 'Pickup' && (sLower == 'pending' || sLower == 'pending payment'))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    onPressed: () => onUpdateStatus('approved'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Approve & Prep Pickup'),
                  ),
                if (taskType == 'Pickup' && (sLower == 'approved' || sLower == 'confirmed' || sLower == 'pending pickup'))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    onPressed: () => _showHandoverConfirmationDialog(context),
                    icon: const Icon(Icons.key),
                    label: const Text('Hand Over Vehicle to Customer'),
                  ),

                // RETURN WORKFLOW ACTIONS
                if (taskType == 'Return' && (BookingService.isOngoingStatus(booking.status) || sLower == 'return requested' || sLower == 'awaiting return'))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    onPressed: () => _showReturnInspectionDialog(context),
                    icon: const Icon(Icons.assignment_turned_in),
                    label: const Text('Receive Vehicle & Complete Inspection'),
                  ),

                // DELIVERY WORKFLOW ACTIONS
                if (taskType == 'Delivery' && (sLower == 'pending' || sLower == 'approved' || sLower == 'confirmed'))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    onPressed: () => onUpdateStatus('active'),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Confirm & Complete Delivery Dispatch'),
                  ),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Close Details'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CATEGORY TASKS LIST SHEET
// ─────────────────────────────────────────────────────────────
class _CategoryTasksListSheet extends StatelessWidget {
  final String taskType;
  final List<BookingModel> tasks;
  final Map<String, VehicleModel> vehicleMap;
  final ValueChanged<BookingModel> onSelectTask;

  const _CategoryTasksListSheet({
    required this.taskType,
    required this.tasks,
    required this.vehicleMap,
    required this.onSelectTask,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Pending $taskType Tasks (${tasks.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final b = tasks[idx];
                final v = vehicleMap[b.vehicleId];

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  title: Text('${b.userName} • ${b.vehicleName}', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                  subtitle: Text('Plate: ${v?.plateNumber ?? "N/A"} • Date: ${_formatDate(taskType == 'Return' ? b.returnDate : b.pickUpDate)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: ElevatedButton(onPressed: () => onSelectTask(b), child: const Text('Open')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// VEHICLE DETAILS MODAL SHEET
// ─────────────────────────────────────────────────────────────
class _VehicleDetailsSheet extends StatelessWidget {
  final VehicleModel vehicle;
  final BookingModel? activeBooking;

  const _VehicleDetailsSheet({required this.vehicle, required this.activeBooking});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;

    final isAvailable = vehicle.status.toLowerCase() == 'available';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(vehicle.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Banner Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: AppImage(
                  imageSrc: vehicle.mainImage,
                  fit: BoxFit.cover,
                  placeholder: Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.directions_car, size: 64, color: Colors.grey))),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: isAvailable ? Colors.teal.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(vehicle.status.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isAvailable ? Colors.teal : Colors.orange)),
                ),
                const SizedBox(width: 12),
                Text('RM ${vehicle.pricePerDay.toStringAsFixed(2)} / day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryOrange)),
              ],
            ),
            const SizedBox(height: 16),

            Text('Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
            const SizedBox(height: 6),
            Text('Plate Number: ${vehicle.plateNumber}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text('Vehicle ID: ${vehicle.id}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text('Category: ${vehicle.category} • Year: ${vehicle.year}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text('Transmission: ${vehicle.transmission} • Fuel: ${vehicle.fuelType}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text('Branch Location: ${vehicle.branchName.isNotEmpty ? vehicle.branchName : "Main Headquarters"}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),

            if (activeBooking != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withValues(alpha: 0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Active Booking Assignment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Customer: ${activeBooking!.userName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('Booking Status: ${activeBooking!.status.toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close Details')),
            ),
          ],
        ),
      ),
    );
  }
}
