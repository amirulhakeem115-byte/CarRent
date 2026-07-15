import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../models/user_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/review_model.dart';
import '../../../services/notification_service.dart';
import '../../../models/notification_model.dart';
import '../../../services/tracking_service.dart';

import 'vehicles_screen.dart';
import 'bookings_screen.dart';
import 'payments_screen.dart';
import 'customers_screen.dart';
import 'branches_screen.dart';
import 'support_inbox_screen.dart';
import 'vehicle_maintenance_screen.dart';
import 'qr_settings_view.dart';
import 'company_settings_view.dart';
import 'admin_profile_view.dart';
import 'reports_view.dart';
import 'admin_tracking_view.dart';
import 'admin_notifications_view.dart';
import 'reward_points_view.dart';
import '../../../services/maintenance_service.dart';
import '../../../models/maintenance_job_model.dart';
import '../login_screen.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/app_logo.dart';
import '../../../services/company_settings_provider.dart';
import '../../../services/web_audio_player.dart';
import 'package:provider/provider.dart';
import '../../../ai/services/ai_service.dart';
import '../../../ai/models/ai_intent.dart';
import '../../../ai/admin/admin_ai_assistant_view.dart';
import '../../../ai/widgets/ai_floating_button.dart';
import '../../../ai/widgets/ai_chat_panel.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final VehicleService _vehicleService = VehicleService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  final MaintenanceService _maintenanceService = MaintenanceService();

  int _totalCars = 0;
  final int _overdueCount = 0;
  int _totalCustomers = 0;
  double _monthlyRevenue = 0.0;
  int _pendingPaymentsCount = 0;
  int _availableCars = 0;

  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  List<VehicleModel> _vehicles = [];
  List<UserModel> _users = [];
  List<MaintenanceJobModel> _maintenanceJobs = [];
  List<ReviewModel> _reviews = [];
  List<Map<String, dynamic>> _rewardTransactions = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  String _activeTab = 'Dashboard';
  String? _aiFilteredPeriod;
  String? _aiFilteredType;
  StreamSubscription? _reviewsSubscription;
  StreamSubscription? _rewardsSubscription;

  final NotificationService _notificationService = NotificationService();
  StreamSubscription<List<NotificationModel>>? _adminNotificationsSubscription;
  List<NotificationModel> _adminNotifications = [];
  final int _adminNotificationsLimit = 15;

  final Set<String> _playedNotificationIds = {};
  bool _notificationsInitialized = false;

  void _markAdminNotificationLocallyRead(String notificationId) {
    setState(() {
      _adminNotifications = _adminNotifications.map((n) {
        if (n.id != notificationId || n.isRead) {
          return n;
        }
        return NotificationModel(
          id: n.id,
          userId: n.userId,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true,
          createdAt: n.createdAt,
          icon: n.icon,
          color: n.color,
          relatedId: n.relatedId,
          actionRoute: n.actionRoute,
        );
      }).toList();
    });
  }

  void _markAllAdminNotificationsLocallyRead() {
    setState(() {
      _adminNotifications = _adminNotifications.map((n) {
        if (n.isRead) {
          return n;
        }
        return NotificationModel(
          id: n.id,
          userId: n.userId,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true,
          createdAt: n.createdAt,
          icon: n.icon,
          color: n.color,
          relatedId: n.relatedId,
          actionRoute: n.actionRoute,
        );
      }).toList();
    });
  }

  // Real-time admin state and tracking properties
  UserModel? _adminUser;
  int _activeBookingsCount = 0;
  Map<String, Map<String, dynamic>> _liveLocations = {};
  StreamSubscription? _trackingSubscription;
  final MapController _dashboardMapController = MapController();
  Map<String, dynamic>? _selectedTrackedVehicle;
  final Map<String, Timer?> _simulators = {};
  final TrackingService _trackingService = TrackingService();

  void _playNotificationSound() {
    if (kIsWeb) {
      try {
        playNotificationChime();
      } catch (e) {
        debugPrint('Web Audio API error: $e');
      }
    } else {
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (e) {
        debugPrint('Failed to play system sound: $e');
      }
    }
  }

  void _subscribeNotifications() {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      _adminNotificationsSubscription?.cancel();
      _adminNotificationsSubscription = _notificationService
          .getNotificationsStream(
            currentUser.uid,
            limit: _adminNotificationsLimit,
          )
          .listen((notifs) {
            if (mounted) {
              if (!_notificationsInitialized) {
                // First load: populate already played IDs so we do not alarm for old notifications
                for (var notif in notifs) {
                  _playedNotificationIds.add(notif.id);
                }
                _notificationsInitialized = true;
              } else {
                // Subsequent loads: play sound for newly arrived unread notifications
                for (var notif in notifs) {
                  if (!notif.isRead &&
                      !_playedNotificationIds.contains(notif.id)) {
                    _playedNotificationIds.add(notif.id);
                    _playNotificationSound();
                  }
                }
              }
              setState(() {
                _adminNotifications = notifs;
              });
            }
          });
    }
  }

  void _subscribeTracking() {
    _trackingSubscription?.cancel();
    _trackingSubscription = FirebaseDatabase.instance
        .ref()
        .child('tracking')
        .onValue
        .listen((event) {
          if (mounted &&
              event.snapshot.exists &&
              event.snapshot.value != null) {
            try {
              final Map<dynamic, dynamic> data =
                  event.snapshot.value as Map<dynamic, dynamic>;
              final Map<String, Map<String, dynamic>> parsed = {};
              data.forEach((key, value) {
                if (value is Map) {
                  parsed[key.toString()] = Map<String, dynamic>.from(value);
                }
              });
              setState(() {
                _liveLocations = parsed;
              });
            } catch (e) {
              debugPrint('Error parsing real-time tracking node: $e');
            }
          }
        });
  }

  StreamSubscription<List<BookingModel>>? _bookingsSubscription;
  StreamSubscription<List<VehicleModel>>? _vehiclesSubscription;
  StreamSubscription<List<PaymentModel>>? _paymentsSubscription;
  StreamSubscription<List<UserModel>>? _usersSubscription;

  int _mobileNavIndexForActiveTab() {
    switch (_activeTab) {
      case 'Bookings':
        return 1;
      case 'Notifications':
        return 2;
      case 'Admin Profile':
        return 3;
      case 'Dashboard':
      default:
        return 0;
    }
  }

  void _setActiveTabFromMobileIndex(int index) {
    switch (index) {
      case 0:
        _activeTab = 'Dashboard';
        break;
      case 1:
        _activeTab = 'Bookings';
        break;
      case 2:
        _activeTab = 'Notifications';
        break;
      case 3:
        _activeTab = 'Admin Profile';
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _subscribeNotifications();
    _subscribeTracking();
    _subscribeToLiveData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AIService>().addListener(_handleAIAction);
      }
    });
  }

  void _subscribeToLiveData() {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = _bookingService.getBookingsStream().listen((
      bookingsList,
    ) {
      if (mounted) {
        setState(() {
          _bookings = bookingsList;
          _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _activeBookingsCount = _bookings
              .where(
                (b) =>
                    b.status == 'pending' ||
                    b.status == 'approved' ||
                    b.status == 'ongoing' ||
                    b.status == 'Confirmed' ||
                    b.status == 'active',
              )
              .length;

          for (var booking in _bookings) {
            final bStat = booking.status.toLowerCase();
            if (bStat == 'ongoing' ||
                bStat == 'approved' ||
                bStat == 'confirmed' ||
                bStat == 'active') {
              if (!_simulators.containsKey(booking.vehicleId)) {
                _simulators[booking.vehicleId] = _trackingService
                    .startRouteSimulation(booking.vehicleId);
              }
            }
          }
        });
      }
    });

    _vehiclesSubscription?.cancel();
    _vehiclesSubscription = _vehicleService.getVehiclesStream().listen((
      vehiclesList,
    ) {
      if (mounted) {
        setState(() {
          _vehicles = vehiclesList;
          _totalCars = _vehicles.length;
          _availableCars = _vehicles
              .where((v) => v.status.toLowerCase() == 'available')
              .length;
        });
      }
    });

    _paymentsSubscription?.cancel();
    _paymentsSubscription = _paymentService.getPaymentsStream().listen((
      paymentsList,
    ) {
      if (mounted) {
        setState(() {
          _payments = paymentsList;
          _pendingPaymentsCount = _payments
              .where(
                (p) =>
                    p.status == 'pending' || p.status == 'Pending Verification',
              )
              .length;

          double monthlyRev = 0.0;
          final now = DateTime.now();
          for (var payment in _payments) {
            final status = payment.status.toLowerCase();
            final pStatus = (payment.paymentStatus ?? '').toLowerCase();
            if (status == 'approved' ||
                status == 'paid' ||
                pStatus == 'approved') {
              final pDate = payment.paymentDate;
              if (pDate.year == now.year && pDate.month == now.month) {
                monthlyRev += payment.amount;
              }
            }
          }
          _monthlyRevenue = monthlyRev;
        });
      }
    });

    _usersSubscription?.cancel();
    _usersSubscription = _databaseService.getUsersStream().listen((usersList) {
      if (mounted) {
        setState(() {
          _users = usersList;
          _totalCustomers = _users.where((u) => u.role == 'customer').length;
        });
      }
    });

    _reviewsSubscription?.cancel();
    _reviewsSubscription = FirebaseDatabase.instance
        .ref()
        .child('reviews')
        .onValue
        .listen((event) {
          if (mounted) {
            final List<ReviewModel> reviews = [];
            if (event.snapshot.exists && event.snapshot.value != null) {
              try {
                final data = event.snapshot.value;
                if (data is Map) {
                  data.forEach((key, value) {
                    if (value is Map) {
                      reviews.add(ReviewModel.fromMap(key.toString(), value));
                    }
                  });
                }
              } catch (e) {
                debugPrint('Error parsing reviews: $e');
              }
            }
            setState(() {
              _reviews = reviews;
            });
          }
        });

    _rewardsSubscription?.cancel();
    _rewardsSubscription = FirebaseDatabase.instance
        .ref()
        .child('reward_transactions')
        .onValue
        .listen((event) {
          if (mounted) {
            final List<Map<String, dynamic>> txs = [];
            if (event.snapshot.exists && event.snapshot.value != null) {
              try {
                final rawVal = event.snapshot.value;
                if (rawVal is Map) {
                  rawVal.forEach((userKey, userTxsValue) {
                    if (userTxsValue is Map) {
                      userTxsValue.forEach((txKey, txValue) {
                        if (txValue is Map) {
                          final tx = Map<String, dynamic>.from(txValue);
                          tx['id'] = txKey.toString();
                          tx['userId'] = userKey.toString();
                          txs.add(tx);
                        }
                      });
                    } else if (userTxsValue is List) {
                      for (int i = 0; i < userTxsValue.length; i++) {
                        final txValue = userTxsValue[i];
                        if (txValue is Map) {
                          final tx = Map<String, dynamic>.from(txValue);
                          tx['id'] = i.toString();
                          tx['userId'] = userKey.toString();
                          txs.add(tx);
                        }
                      }
                    }
                  });
                }
              } catch (e) {
                debugPrint('Error parsing reward transactions: $e');
              }
            }
            setState(() {
              _rewardTransactions = txs;
            });
          }
        });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _adminNotificationsSubscription?.cancel();
    _trackingSubscription?.cancel();
    _bookingsSubscription?.cancel();
    _vehiclesSubscription?.cancel();
    _paymentsSubscription?.cancel();
    _usersSubscription?.cancel();
    _reviewsSubscription?.cancel();
    _rewardsSubscription?.cancel();
    _simulators.forEach((_, sim) => sim?.cancel());
    try {
      context.read<AIService>().removeListener(_handleAIAction);
    } catch (_) {}
    super.dispose();
  }

  void _handleAIAction() {
    if (!mounted) return;
    final aiService = context.read<AIService>();
    final intent = aiService.lastIntent;
    if (intent == null) return;

    setState(() {
      if (intent is DashboardIntent) {
        _activeTab = 'Dashboard';
        aiService.clearLastIntent();
      } else if (intent is BookingIntent) {
        _activeTab = 'Bookings';
        aiService.clearLastIntent();
      } else if (intent is PaymentIntent) {
        _activeTab = 'Payments';
        aiService.clearLastIntent();
      } else if (intent is CustomerIntent) {
        _activeTab = 'Customers';
        aiService.clearLastIntent();
      } else if (intent is MaintenanceIntent) {
        _activeTab = 'Vehicle Maintenance';
        aiService.clearLastIntent();
      } else if (intent is BranchIntent) {
        _activeTab = 'Locations';
        aiService.clearLastIntent();
      } else if (intent is ReportIntent) {
        _activeTab = 'Reports';
        _aiFilteredPeriod =
            intent.parameters['timeframe'] ?? intent.parameters['period'];
        _aiFilteredType = intent.parameters['type'];
        aiService.clearLastIntent();
      } else if (intent is SupportIntent) {
        _activeTab = 'Support Inbox';
        aiService.clearLastIntent();
      } else if (intent is ProfileIntent) {
        _activeTab = 'Admin Profile';
        aiService.clearLastIntent();
      } else if (intent is NotificationIntent) {
        _activeTab = 'Notifications';
        aiService.clearLastIntent();
      } else if (intent is RewardIntent) {
        _activeTab = 'Reward Points';
        aiService.clearLastIntent();
      } else if (intent is VehicleSearchIntent) {
        _activeTab = 'Cars';
        aiService.clearLastIntent();
      }
    });
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _databaseService.getUsers(),
        _vehicleService.getVehicles(),
        _bookingService.getBookings(),
        _paymentService.getPayments(),
        _maintenanceService.getMaintenanceJobs(),
      ]).timeout(const Duration(seconds: 15));

      _users = results[0] as List<UserModel>;
      _vehicles = results[1] as List<VehicleModel>;
      _bookings = results[2] as List<BookingModel>;
      _payments = results[3] as List<PaymentModel>;
      _maintenanceJobs = results[4] as List<MaintenanceJobModel>;

      // Load admin profile user data
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        _adminUser = await _databaseService.getUser(currentUser.uid);
      }

      _totalCustomers = _users.where((u) => u.role == 'customer').length;
      _totalCars = _vehicles.length;
      _availableCars = _vehicles
          .where((v) => v.status.toLowerCase() == 'available')
          .length;

      _activeBookingsCount = _bookings
          .where(
            (b) =>
                b.status == 'pending' ||
                b.status == 'approved' ||
                b.status == 'ongoing',
          )
          .length;

      // Automatically trigger mock hardware simulator for active bookings
      for (var booking in _bookings) {
        if (booking.status == 'ongoing' || booking.status == 'approved') {
          if (!_simulators.containsKey(booking.vehicleId)) {
            _simulators[booking.vehicleId] = _trackingService
                .startRouteSimulation(booking.vehicleId);
          }
        }
      }

      double monthlyRev = 0.0;
      final now = DateTime.now();

      for (var payment in _payments) {
        final status = payment.status.toLowerCase();
        final pStatus = (payment.paymentStatus ?? '').toLowerCase();
        if (status == 'approved' || status == 'paid' || pStatus == 'approved') {
          final pDate = payment.paymentDate;
          if (pDate.year == now.year && pDate.month == now.month) {
            monthlyRev += payment.amount;
          }
        }
      }
      _monthlyRevenue = monthlyRev;

      _pendingPaymentsCount = _payments
          .where(
            (p) => p.status == 'pending' || p.status == 'Pending Verification',
          )
          .length;
    } catch (e) {
      debugPrint('Dashboard loading error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load dashboard statistics. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
      _checkMaintenanceDue();
    }
  }

  Future<void> _checkMaintenanceDue() async {
    final today = DateTime.now();
    final parsedToday = DateTime(today.year, today.month, today.day);

    for (var job in _maintenanceJobs) {
      if (job.status == 'Scheduled') {
        try {
          final startDate = DateTime.parse(job.startDate);
          final parsedStart = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );

          if (parsedStart.isBefore(parsedToday) ||
              parsedStart.isAtSameMomentAs(parsedToday)) {
            // Check if alert already exists in database (to prevent duplication)
            final ref = FirebaseDatabase.instance.ref().child('notifications');
            final snapshot = await ref
                .orderByChild('relatedId')
                .equalTo(job.id)
                .get()
                .timeout(const Duration(seconds: 5));
            bool alreadyAlerted = false;
            if (snapshot.exists && snapshot.value != null) {
              final data = snapshot.value as Map;
              alreadyAlerted = data.values.any(
                (n) => (n as Map)['type'] == 'maintenance',
              );
            }

            if (!alreadyAlerted) {
              await _notificationService.notifyAllAdmins(
                title: 'Vehicle Maintenance Due',
                message:
                    'Maintenance is due today for ${job.vehicleName}.\nJob: ${job.title}',
                type: 'maintenance',
                icon: '🔧',
                color: '0xFFEF4444',
                relatedId: job.id,
                actionRoute: 'Vehicle Maintenance',
              );
            }
          }
        } catch (e) {
          debugPrint('Error checking maintenance due: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1100;
    final bool showMobileBottomNav = !isDesktop;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Row(
          children: [
            if (isDesktop) _buildSidebar(context),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = isDesktop
                      ? 1650
                      : constraints.maxWidth;
                  final Widget content = _loading
                      ? const Center(
                          child: LoadingWidget(
                            message: 'Syncing dashboard with Firebase...',
                          ),
                        )
                      : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadDashboardData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _buildActiveBody(isDesktop);

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: content,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _activeTab == 'AI Assistant'
          ? null
          : AIFloatingButton(
              onTap: () async {
                final result = await showAIChatModal(context);
                if (result != null && result is String && mounted) {
                  setState(() {
                    if (result == 'search_vehicles') {
                      _activeTab = 'Cars';
                    } else if (result == 'view_bookings') {
                      _activeTab = 'Bookings';
                    } else if (result == 'view_payments') {
                      _activeTab = 'Payments';
                    } else if (result == 'view_support') {
                      _activeTab = 'Support Inbox';
                    } else if (result == 'view_branches') {
                      _activeTab = 'Locations';
                    } else if (result == 'view_notifications') {
                      _activeTab = 'Notifications';
                    } else if (result == 'view_maintenance') {
                      _activeTab = 'Vehicle Maintenance';
                    } else if (result == 'view_reports') {
                      _activeTab = 'Reports';
                    } else if (result == 'view_customers') {
                      _activeTab = 'Customers';
                    } else if (result == 'view_dashboard') {
                      _activeTab = 'Dashboard';
                    }
                  });
                }
              },
              isOpen: false,
            ),
      bottomNavigationBar: showMobileBottomNav
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _mobileNavIndexForActiveTab(),
              selectedItemColor: AppColors.primaryOrange,
              unselectedItemColor: Colors.grey,
              onTap: (index) {
                setState(() {
                  _setActiveTabFromMobileIndex(index);
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_rounded),
                  label: 'Bookings',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_rounded),
                  label: 'Alerts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildActiveBody(bool isDesktop) {
    Widget tabContent;
    switch (_activeTab) {
      case 'Dashboard':
        tabContent = Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopStatsGrid(isDesktop),
                const SizedBox(height: 24),
                _buildMiddleSection(isDesktop),
                const SizedBox(height: 24),
                _buildBottomSection(isDesktop),
              ],
            ),
          ),
        );
        break;
      case 'Cars':
        tabContent = const Expanded(child: VehiclesView());
        break;
      case 'Bookings':
        tabContent = const Expanded(child: BookingsView());
        break;
      case 'Customers':
        tabContent = const Expanded(child: CustomersView());
        break;
      case 'Payments':
        tabContent = const Expanded(child: PaymentsView());
        break;
      case 'Reward Points':
        tabContent = const Expanded(child: RewardPointsView());
        break;
      case 'Vehicle Tracking':
        tabContent = Expanded(
          child: AdminTrackingView(
            vehicles: _vehicles,
            liveLocations: _liveLocations,
          ),
        );
        break;
      case 'Vehicle Maintenance':
        tabContent = const Expanded(child: VehicleMaintenanceView());
        break;
      case 'Locations':
        tabContent = const Expanded(child: BranchesView());
        break;
      case 'Reports':
        tabContent = Expanded(
          child: ReportsView(
            bookings: _bookings,
            payments: _payments,
            vehicles: _vehicles,
            users: _users,
            maintenanceJobs: _maintenanceJobs,
            reviews: _reviews,
            rewardTransactions: _rewardTransactions,
            initialPeriod: _aiFilteredPeriod,
            initialType: _aiFilteredType,
            onClearAIFilters: () {
              setState(() {
                _aiFilteredPeriod = null;
                _aiFilteredType = null;
              });
            },
          ),
        );
        break;
      case 'Support Inbox':
        tabContent = const Expanded(child: SupportInboxView());
        break;
      case 'QR Payment Settings':
        tabContent = const Expanded(child: QrSettingsView());
        break;
      case 'Company Settings':
        tabContent = const Expanded(child: CompanySettingsView());
        break;
      case 'Admin Profile':
        tabContent = Expanded(child: AdminProfileView(onLogout: _logout));
        break;
      case 'AI Assistant':
        tabContent = const Expanded(child: AdminAIAssistantView());
        break;
      case 'Notifications':
        tabContent = Expanded(
          child: AdminNotificationsView(
            onNavigateTab: (route, relatedId) {
              setState(() {
                _activeTab = route;
              });
              if (relatedId != null && relatedId.isNotEmpty) {
                if (route == 'Bookings') {
                  try {
                    final booking = _bookings.firstWhere(
                      (b) => b.id == relatedId,
                    );
                    _showBookingDetailsDialog(booking);
                  } catch (_) {}
                } else if (route == 'Payments') {
                  try {
                    final payment = _payments.firstWhere(
                      (p) => p.id == relatedId,
                    );
                    _showPaymentDetailsDialog(payment);
                  } catch (_) {}
                }
              }
            },
          ),
        );
        break;
      default:
        tabContent = const Expanded(child: Center(child: Text('Unknown Tab')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_buildHeader(isDesktop), tabContent],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF172033)
          : AppColors.secondaryBlue,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const AppLogo(size: 28, fallbackColor: AppColors.primaryOrange),
                const SizedBox(width: 8),
                Text(
                  context.watch<CompanySettingsProvider>().companyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildSidebarTile(
                  Icons.dashboard_outlined,
                  'Dashboard',
                  () => setState(() => _activeTab = 'Dashboard'),
                ),
                _buildSidebarTile(
                  Icons.directions_car_filled_outlined,
                  'Cars',
                  () => setState(() => _activeTab = 'Cars'),
                ),
                _buildSidebarTile(
                  Icons.calendar_today_outlined,
                  'Bookings',
                  () => setState(() => _activeTab = 'Bookings'),
                ),
                _buildSidebarTile(
                  Icons.people_outline_rounded,
                  'Customers',
                  () => setState(() => _activeTab = 'Customers'),
                ),
                _buildSidebarTile(
                  Icons.payment_outlined,
                  'Payments',
                  () => setState(() => _activeTab = 'Payments'),
                ),
                _buildSidebarTile(
                  Icons.stars_rounded,
                  'Reward Points',
                  () => setState(() => _activeTab = 'Reward Points'),
                ),
                _buildSidebarTile(
                  Icons.map_outlined,
                  'Vehicle Tracking',
                  () => setState(() => _activeTab = 'Vehicle Tracking'),
                ),
                _buildSidebarTile(
                  Icons.build_outlined,
                  'Vehicle Maintenance',
                  () => setState(() => _activeTab = 'Vehicle Maintenance'),
                ),
                _buildSidebarTile(
                  Icons.storefront_outlined,
                  'Locations',
                  () => setState(() => _activeTab = 'Locations'),
                ),
                _buildSidebarTile(
                  Icons.assessment_outlined,
                  'Reports',
                  () => setState(() => _activeTab = 'Reports'),
                ),
                _buildSidebarTile(
                  Icons.psychology_outlined,
                  'AI Assistant',
                  () => setState(() => _activeTab = 'AI Assistant'),
                ),
                _buildSidebarTile(
                  Icons.mail_outline_rounded,
                  'Support Inbox',
                  () => setState(() => _activeTab = 'Support Inbox'),
                ),
                _buildSidebarTile(
                  Icons.qr_code_2,
                  'QR Payment Settings',
                  () => setState(() => _activeTab = 'QR Payment Settings'),
                ),
                _buildSidebarTile(
                  Icons.settings_outlined,
                  'Company Settings',
                  () => setState(() => _activeTab = 'Company Settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarTile(IconData icon, String title, VoidCallback onTap) {
    final bool isActive = _activeTab == title;
    return InkWell(
      onTap: () {
        onTap();
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.pop(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRelativeTimeString(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? "minute" : "minutes"} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? "day" : "days"} ago';
    } else {
      return DateFormat('dd MMM, hh:mm a').format(dateTime);
    }
  }

  Widget _buildHeader(bool isDesktop) {
    final unreadCount = _adminNotifications.where((n) => !n.isRead).length;
    final String formattedDate = DateFormat(
      'dd MMM yyyy',
    ).format(DateTime.now());
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF1B2436) : Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (!isDesktop) ...[
                  IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: isDark
                          ? const Color(0xFFF8FAFC)
                          : AppColors.secondaryBlue,
                    ),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDesktop)
                        Text(
                          _activeTab == 'Dashboard'
                              ? 'Dashboard Overview'
                              : _activeTab,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? const Color(0xFFF8FAFC)
                                : AppColors.secondaryBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _activeTab == 'Dashboard'
                                  ? 'Dashboard Overview'
                                  : _activeTab,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? const Color(0xFFF8FAFC)
                                    : AppColors.secondaryBlue,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      if (isDesktop)
                        Text(
                          _activeTab == 'Dashboard'
                              ? 'Welcome back, ${_adminUser?.fullName ?? "Administrator"} 👋'
                              : '${context.watch<CompanySettingsProvider>().companyName} Platform Management',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _activeTab == 'Dashboard'
                                  ? 'Welcome back, ${_adminUser?.fullName ?? "Administrator"} 👋'
                                  : '${context.watch<CompanySettingsProvider>().companyName} Platform Management',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : Colors.grey,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date Indicator
              if (isDesktop) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : Colors.grey[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isDark
                            ? const Color(0xFFF8FAFC)
                            : AppColors.secondaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFFF8FAFC)
                              : AppColors.secondaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // Refresh Button
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: isDark
                      ? const Color(0xFFF8FAFC)
                      : AppColors.secondaryBlue,
                ),
                onPressed: _loadDashboardData,
                tooltip: 'Refresh Data',
              ),
              const SizedBox(width: 16),

              // Notifications Bell
              PopupMenuButton<void>(
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tooltip: 'Notifications Dropdown',
                padding: EdgeInsets.zero,
                itemBuilder: (context) {
                  final currentUser = _authService.currentUser;
                  final recentNotifs = _adminNotifications.take(10).toList();
                  final dropdownUnread = _adminNotifications
                      .where((n) => !n.isRead)
                      .length;

                  return [
                    PopupMenuItem<void>(
                      enabled: false,
                      padding: EdgeInsets.zero,
                      child: Container(
                        width: 380,
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Dropdown Header
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dropdownUnread > 0
                                        ? 'Notifications ($dropdownUnread)'
                                        : 'Notifications',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: isDark
                                          ? const Color(0xFFF8FAFC)
                                          : AppColors.secondaryBlue,
                                    ),
                                  ),
                                  if (currentUser != null &&
                                      _adminNotifications.any((n) => !n.isRead))
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        _markAllAdminNotificationsLocallyRead();
                                        await _notificationService
                                            .markAllAsRead(
                                              currentUser.uid,
                                              includeAdminShared: true,
                                            );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Mark All Read',
                                        style: TextStyle(
                                          color: AppColors.primaryOrange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : Colors.grey[200]!,
                            ),
                            // List of 10 items
                            if (recentNotifs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      size: 40,
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : Colors.grey[300],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No notifications yet',
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFCBD5E1)
                                            : Colors.grey[500],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 350,
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: recentNotifs.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : Colors.grey[200]!,
                                  ),
                                  itemBuilder: (context, index) {
                                    final notif = recentNotifs[index];
                                    final parsedColor = Color(
                                      int.parse(notif.color),
                                    );

                                    return InkWell(
                                      onTap: () async {
                                        Navigator.pop(
                                          context,
                                        ); // Close dropdown
                                        if (!notif.isRead) {
                                          _markAdminNotificationLocallyRead(
                                            notif.id,
                                          );
                                          await _notificationService.markAsRead(
                                            notif.userId,
                                            notif.id,
                                          );
                                        }
                                        if (notif.actionRoute.isNotEmpty) {
                                          setState(() {
                                            _activeTab = notif.actionRoute;
                                          });
                                          // Open direct details if applicable
                                          if (notif.relatedId.isNotEmpty) {
                                            if (notif.actionRoute ==
                                                'Bookings') {
                                              try {
                                                final booking = _bookings
                                                    .firstWhere(
                                                      (b) =>
                                                          b.id ==
                                                          notif.relatedId,
                                                    );
                                                _showBookingDetailsDialog(
                                                  booking,
                                                );
                                              } catch (_) {}
                                            } else if (notif.actionRoute ==
                                                'Payments') {
                                              try {
                                                final payment = _payments
                                                    .firstWhere(
                                                      (p) =>
                                                          p.id ==
                                                          notif.relatedId,
                                                    );
                                                _showPaymentDetailsDialog(
                                                  payment,
                                                );
                                              } catch (_) {}
                                            }
                                          }
                                        }
                                      },
                                      child: Container(
                                        color: notif.isRead
                                            ? Colors.transparent
                                            : (isDark
                                                  ? const Color(0xFF2D251E)
                                                  : const Color(0xFFFFF7ED)),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: parsedColor
                                                  .withValues(
                                                    alpha: isDark ? 0.2 : 0.1,
                                                  ),
                                              child: Text(
                                                notif.icon,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    notif.title,
                                                    style: TextStyle(
                                                      fontWeight: notif.isRead
                                                          ? FontWeight.bold
                                                          : FontWeight.w900,
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFFF8FAFC,
                                                            )
                                                          : AppColors
                                                                .secondaryBlue,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    notif.message,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      height: 1.3,
                                                      color: notif.isRead
                                                          ? (isDark
                                                                ? const Color(
                                                                    0xFFCBD5E1,
                                                                  )
                                                                : Colors
                                                                      .grey[600])
                                                          : (isDark
                                                                ? const Color(
                                                                    0xFFF8FAFC,
                                                                  )
                                                                : Colors
                                                                      .grey[800]),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _getRelativeTimeString(
                                                      notif.createdAt,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFFCBD5E1,
                                                            )
                                                          : Colors.grey,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (!notif.isRead)
                                              Container(
                                                width: 6,
                                                height: 6,
                                                margin: const EdgeInsets.only(
                                                  top: 4,
                                                  left: 4,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color:
                                                      AppColors.primaryOrange,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : Colors.grey[200]!,
                            ),
                            // Footer Button
                            InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _activeTab = 'Notifications';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                alignment: Alignment.center,
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.grey[50],
                                child: Text(
                                  'View All Notifications',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFF8FAFC)
                                        : AppColors.secondaryBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: isDark
                            ? const Color(0xFFF8FAFC)
                            : AppColors.secondaryBlue,
                        size: 24,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryOrange,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                            child: Text(
                              '$unreadCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Admin profile trigger (direct navigation)
              Builder(
                builder: (context) {
                  final isOnAdminProfile = _activeTab == 'Admin Profile';
                  return MouseRegion(
                    cursor: isOnAdminProfile
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.click,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: isOnAdminProfile
                          ? null
                          : () => setState(() => _activeTab = 'Admin Profile'),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.secondaryBlue.withValues(
                              alpha: 0.1,
                            ),
                            backgroundImage: getAppImageProvider(
                              _adminUser?.profileImage,
                            ),
                            child: _adminUser?.profileImage.isNotEmpty != true
                                ? Icon(
                                    Icons.person,
                                    size: 18,
                                    color: _isDark
                                        ? const Color(0xFFF8FAFC)
                                        : AppColors.secondaryBlue,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          if (isDesktop)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _adminUser?.fullName ?? 'Admin',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _isDark
                                        ? const Color(0xFFF8FAFC)
                                        : AppColors.secondaryBlue,
                                  ),
                                ),
                                Text(
                                  'Super Administrator',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _isDark
                                        ? const Color(0xFFE2E8F0)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Do you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) return;

    final nav = Navigator.of(context);
    await _authService.logout();
    if (!mounted) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen(onLoggedIn: () {})),
      (route) => false,
    );
  }

  Widget _buildTopStatsGrid(bool isDesktop) {
    final now = DateTime.now();

    // 1. Total Vehicles added this month
    int vehiclesAddedThisMonth = _vehicles.where((v) {
      try {
        final date = DateTime.parse(v.createdAt);
        return date.year == now.year && date.month == now.month;
      } catch (_) {
        return false;
      }
    }).length;
    String vehiclesTrend = vehiclesAddedThisMonth > 0
        ? '+$vehiclesAddedThisMonth this month'
        : 'Stable fleet';

    // 2. Available vehicles percentage
    double availablePct = _totalCars > 0
        ? (_availableCars / _totalCars) * 100
        : 0.0;
    String availableTrend = '${availablePct.toStringAsFixed(0)}% ready to rent';

    // 3. Active Bookings
    String bookingsTrend = 'Ongoing rentals';

    // 4. Monthly Revenue dynamic comparison
    double lastMonthRev = 0.0;
    for (var payment in _payments) {
      final status = payment.status.toLowerCase();
      final pStatus = (payment.paymentStatus ?? '').toLowerCase();
      if (status == 'approved' || status == 'paid' || pStatus == 'approved') {
        final pDate = payment.paymentDate;
        final lastMonth = now.month == 1 ? 12 : now.month - 1;
        final lastYear = now.month == 1 ? now.year - 1 : now.year;
        if (pDate.year == lastYear && pDate.month == lastMonth) {
          lastMonthRev += payment.amount;
        }
      }
    }
    double revChange = 0.0;
    if (lastMonthRev > 0) {
      revChange = ((_monthlyRevenue - lastMonthRev) / lastMonthRev) * 100;
    }
    String revenueTrend = revChange >= 0
        ? '+${revChange.toStringAsFixed(1)}% vs last month'
        : '${revChange.toStringAsFixed(1)}% vs last month';

    // 5. Total Customers registered this month
    int customersThisMonth = _users.where((u) {
      if (u.role != 'customer') return false;
      try {
        final date = DateTime.parse(u.createdAt);
        return date.year == now.year && date.month == now.month;
      } catch (_) {
        return false;
      }
    }).length;
    String customersTrend = customersThisMonth > 0
        ? '+$customersThisMonth this month'
        : 'Stable userbase';

    // 6. Pending Payments action required
    String paymentsTrend = _pendingPaymentsCount > 0
        ? 'Requires approval'
        : 'All cleared';

    return GridView.count(
      crossAxisCount: isDesktop
          ? 6
          : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isDesktop ? 1.05 : 0.94,
      children: [
        _buildStatsCard(
          'Total Vehicles',
          '$_totalCars',
          Icons.directions_car,
          Colors.indigo,
          vehiclesTrend,
          false,
        ),
        _buildStatsCard(
          'Available Vehicles',
          '$_availableCars',
          Icons.check_circle_outline,
          Colors.green,
          availableTrend,
          false,
        ),
        _buildStatsCard(
          'Active Bookings',
          '$_activeBookingsCount',
          Icons.calendar_month,
          Colors.amber,
          bookingsTrend,
          false,
        ),
        _buildStatsCard(
          'Monthly Revenue',
          'RM ${NumberFormat('#,##0.00').format(_monthlyRevenue)}',
          Icons.monetization_on,
          Colors.purple,
          revenueTrend,
          revChange >= 0,
        ),
        _buildStatsCard(
          'Total Customers',
          '$_totalCustomers',
          Icons.people_outline,
          Colors.teal,
          customersTrend,
          false,
        ),
        _buildStatsCard(
          'Pending Payments',
          '$_pendingPaymentsCount',
          Icons.hourglass_top,
          Colors.orange,
          paymentsTrend,
          _pendingPaymentsCount > 0,
        ),
      ],
    );
  }

  Widget _buildStatsCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String trendText,
    bool isPositiveAction,
  ) {
    final bool isCompactMobile = MediaQuery.of(context).size.width <= 600;

    return Container(
      padding: EdgeInsets.all(isCompactMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (label.contains('Pending') && _pendingPaymentsCount > 0)
                Container(
                  width: isCompactMobile ? 7 : 8,
                  height: isCompactMobile ? 7 : 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          SizedBox(height: isCompactMobile ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: isCompactMobile ? 10 : 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: isCompactMobile ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isCompactMobile ? 2 : 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isCompactMobile ? 16 : 18,
                      fontWeight: FontWeight.w900,
                      color: _isDark
                          ? const Color(0xFFF8FAFC)
                          : AppColors.secondaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompactMobile ? 2 : 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                label.contains('Revenue')
                    ? (isPositiveAction
                          ? Icons.arrow_upward
                          : Icons.arrow_downward)
                    : (label.contains('Pending') && _pendingPaymentsCount > 0
                          ? Icons.error_outline
                          : Icons.trending_up),
                color: label.contains('Revenue')
                    ? (isPositiveAction ? Colors.green : Colors.red)
                    : (label.contains('Pending') && _pendingPaymentsCount > 0
                          ? Colors.orange
                          : Colors.grey),
                size: isCompactMobile ? 11 : 12,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  trendText,
                  style: TextStyle(
                    fontSize: isCompactMobile ? 9 : 10,
                    fontWeight: FontWeight.bold,
                    color: label.contains('Revenue')
                        ? (isPositiveAction ? Colors.green : Colors.red)
                        : (label.contains('Pending') &&
                                  _pendingPaymentsCount > 0
                              ? Colors.orange
                              : Colors.grey),
                  ),
                  maxLines: isCompactMobile ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleSection(bool isDesktop) {
    final currentYear = DateTime.now().year;
    List<double> monthlyRevenue = List.filled(12, 0.0);
    for (var payment in _payments) {
      final status = payment.status.toLowerCase();
      final pStatus = (payment.paymentStatus ?? '').toLowerCase();
      if (status == 'paid' || status == 'approved' || pStatus == 'approved') {
        final pDate = payment.paymentDate;
        if (pDate.year == currentYear) {
          monthlyRevenue[pDate.month - 1] += payment.amount;
        }
      }
    }

    int pendingCount = _bookings
        .where((b) => b.status.toLowerCase() == 'pending')
        .length;
    int approvedCount = _bookings
        .where((b) => b.status.toLowerCase() == 'approved')
        .length;
    int ongoingCount = _bookings
        .where((b) => b.status.toLowerCase() == 'ongoing')
        .length;
    int completedCount = _bookings
        .where((b) => b.status.toLowerCase() == 'completed')
        .length;
    int cancelledCount = _bookings
        .where(
          (b) =>
              b.status.toLowerCase() == 'cancelled' ||
              b.status.toLowerCase() == 'rejected',
        )
        .length;

    Map<String, int> statusCounts = {
      'Pending': pendingCount,
      'Approved': approvedCount,
      'Ongoing': ongoingCount,
      'Completed': completedCount,
      'Cancelled': cancelledCount,
      'Overdue': _overdueCount,
    };

    final totalBookingsCount = statusCounts.values.fold(
      0,
      (sum, val) => sum + val,
    );

    final chartCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Overview',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: _isDark
                      ? const Color(0xFFF8FAFC)
                      : AppColors.secondaryBlue,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Text(
                  'Monthly',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: RevenueOverviewLineChartPainter(
                values: monthlyRevenue,
                labels: const [
                  'Jan',
                  'Feb',
                  'Mar',
                  'Apr',
                  'May',
                  'Jun',
                  'Jul',
                  'Aug',
                  'Sep',
                  'Oct',
                  'Nov',
                  'Dec',
                ],
                isDark: _isDark,
              ),
              child: Container(),
            ),
          ),
        ],
      ),
    );

    final statusCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bookings Status',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: _isDark
                      ? const Color(0xFFF8FAFC)
                      : AppColors.secondaryBlue,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Text(
                  'This Year',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(140, 140),
                        painter: BookingStatusDoughnutPainter(
                          statusCounts: statusCounts,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$totalBookingsCount',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _isDark
                                  ? const Color(0xFFF8FAFC)
                                  : AppColors.secondaryBlue,
                            ),
                          ),
                          const Text(
                            'Bookings',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendRow(
                      'Pending',
                      pendingCount,
                      totalBookingsCount,
                      Colors.orange,
                    ),
                    _buildLegendRow(
                      'Approved',
                      approvedCount,
                      totalBookingsCount,
                      Colors.blue,
                    ),
                    _buildLegendRow(
                      'Ongoing',
                      ongoingCount,
                      totalBookingsCount,
                      Colors.teal,
                    ),
                    _buildLegendRow(
                      'Completed',
                      completedCount,
                      totalBookingsCount,
                      Colors.green,
                    ),
                    _buildLegendRow(
                      'Cancelled',
                      cancelledCount,
                      totalBookingsCount,
                      Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: chartCard),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: statusCard),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [chartCard, const SizedBox(height: 24), statusCard],
          );
  }

  Widget _buildLegendRow(String label, int count, int total, Color color) {
    final double pct = total > 0 ? (count / total) * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isDark
                        ? const Color(0xFFF8FAFC)
                        : AppColors.secondaryBlue,
                  ),
                ),
                Text(
                  '$count (${pct.toStringAsFixed(0)}%)',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(bool isDesktop) {
    return Column(
      children: [
        _buildTrackingAndBookingsSection(isDesktop),
        const SizedBox(height: 24),
        _buildActionsAlertsPaymentsSection(isDesktop),
      ],
    );
  }

  List<Map<String, dynamic>> _getActiveTrackedVehicles() {
    final Map<String, Map<String, dynamic>> tracked = {};
    final activeBookings = _bookings
        .where((b) => b.status == 'ongoing' || b.status == 'approved')
        .toList();

    for (var booking in activeBookings) {
      if (tracked.containsKey(booking.vehicleId)) continue;

      final vehicleList = _vehicles.where((v) => v.id == booking.vehicleId);
      if (vehicleList.isEmpty) continue;
      final vehicle = vehicleList.first;

      final loc = _liveLocations[vehicle.id];
      final double lat = loc != null
          ? (loc['latitude'] as num).toDouble()
          : 3.1344;
      final double lng = loc != null
          ? (loc['longitude'] as num).toDouble()
          : 101.6861;
      final double speed = loc != null ? (loc['speed'] as num).toDouble() : 0.0;

      tracked[booking.vehicleId] = {
        'booking': booking,
        'vehicle': vehicle,
        'latitude': lat,
        'longitude': lng,
        'speed': speed,
      };
    }
    return tracked.values.toList();
  }

  List<BookingModel> _getRecentBookings() {
    final list = List<BookingModel>.from(_bookings);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(5).toList();
  }

  List<MaintenanceJobModel> _getActiveMaintenanceJobs() {
    return _maintenanceJobs
        .where((j) => j.status == 'Scheduled' || j.status == 'In Progress')
        .toList();
  }

  List<PaymentModel> _getRecentPayments() {
    final list = List<PaymentModel>.from(_payments);
    list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return list.take(5).toList();
  }

  String _getCustomerName(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId).fullName;
    } catch (_) {
      return 'Customer';
    }
  }

  String _getVehicleNameForPayment(String bookingId) {
    try {
      return _bookings.firstWhere((b) => b.id == bookingId).vehicleName;
    } catch (_) {
      return 'Vehicle';
    }
  }

  Widget _buildTrackingAndBookingsSection(bool isDesktop) {
    final trackedVehicles = _getActiveTrackedVehicles();
    final recentBookings = _getRecentBookings();
    final mapCard = Container(
      height: 380,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.gps_fixed,
                      color: AppColors.primaryOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live Vehicle Tracking',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: _isDark
                            ? const Color(0xFFF8FAFC)
                            : AppColors.secondaryBlue,
                      ),
                    ),
                  ],
                ),
                if (trackedVehicles.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trackedVehicles.length} Active',
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
            ),
          ),
          Expanded(
            child: trackedVehicles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No active tracked vehicles',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const Text(
                          'Active bookings will drive automated simulated routes.',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _dashboardMapController,
                        options: MapOptions(
                          initialCenter: LatLng(
                            trackedVehicles.first['latitude'],
                            trackedVehicles.first['longitude'],
                          ),
                          initialZoom: 11,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                            userAgentPackageName: 'com.carrent.app',
                          ),
                          MarkerLayer(
                            markers: trackedVehicles.map((tv) {
                              return Marker(
                                point: LatLng(tv['latitude'], tv['longitude']),
                                width: 44,
                                height: 44,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTrackedVehicle = tv;
                                    });
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryOrange
                                              .withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: AppColors.primaryOrange,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.directions_car,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      if (_selectedTrackedVehicle != null)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            width: 260,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: _isDark
                                    ? const Color(0xFF334155)
                                    : Colors.grey[100]!,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Live Vehicle Telematics',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: _isDark
                                            ? const Color(0xFFF8FAFC)
                                            : AppColors.secondaryBlue,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 14),
                                      onPressed: () => setState(
                                        () => _selectedTrackedVehicle = null,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        width: 50,
                                        height: 38,
                                        color: _isDark
                                            ? const Color(0xFF111827)
                                            : Colors.grey[100],
                                        child: AppImage(
                                          imageSrc:
                                              (_selectedTrackedVehicle!['vehicle']
                                                      as VehicleModel)
                                                  .mainImage,
                                          placeholder: const Icon(
                                            Icons.directions_car,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${(_selectedTrackedVehicle!['vehicle'] as VehicleModel).brand} ${(_selectedTrackedVehicle!['vehicle'] as VehicleModel).model}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: _isDark
                                                  ? const Color(0xFFF8FAFC)
                                                  : AppColors.secondaryBlue,
                                            ),
                                          ),
                                          Text(
                                            (_selectedTrackedVehicle!['vehicle']
                                                    as VehicleModel)
                                                .plateNumber,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                _buildOverlayRow(
                                  'Customer',
                                  (_selectedTrackedVehicle!['booking']
                                          as BookingModel)
                                      .userName,
                                ),
                                _buildOverlayRow(
                                  'Booking Status',
                                  (_selectedTrackedVehicle!['booking']
                                          as BookingModel)
                                      .status
                                      .toUpperCase(),
                                ),
                                _buildOverlayRow(
                                  'Speed',
                                  '${_selectedTrackedVehicle!['speed'].toStringAsFixed(0)} km/h',
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isDark
                                          ? AppColors.primaryOrange
                                          : AppColors.secondaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    onPressed: () => _showVehicleDetailsDialog(
                                      _selectedTrackedVehicle!['vehicle'],
                                    ),
                                    child: const Text(
                                      'View Specifications',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
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

    final bookingsCard = Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Bookings',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: _isDark
                      ? const Color(0xFFF8FAFC)
                      : AppColors.secondaryBlue,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _activeTab = 'Bookings'),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: recentBookings.isEmpty
                ? const Center(child: Text('No bookings available'))
                : ListView.separated(
                    itemCount: recentBookings.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final booking = recentBookings[index];

                      // Find vehicle image
                      String vehicleImg = '';
                      try {
                        vehicleImg = _vehicles
                            .firstWhere((v) => v.id == booking.vehicleId)
                            .mainImage;
                      } catch (_) {}

                      Color statusColor = Colors.orange;
                      if (booking.status == 'approved' ||
                          booking.status == 'ongoing') {
                        statusColor = Colors.blue;
                      } else if (booking.status == 'completed') {
                        statusColor = Colors.green;
                      } else if (booking.status == 'cancelled' ||
                          booking.status == 'rejected') {
                        statusColor = Colors.red;
                      }

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 48,
                            height: 36,
                            color: _isDark
                                ? const Color(0xFF111827)
                                : Colors.grey[100],
                            child: AppImage(
                              imageSrc: vehicleImg,
                              placeholder: const Icon(
                                Icons.directions_car,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          booking.vehicleName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _isDark
                                ? const Color(0xFFF8FAFC)
                                : AppColors.secondaryBlue,
                          ),
                        ),
                        subtitle: Text(
                          '${booking.userName} • ${DateFormat('dd MMM').format(booking.pickUpDate)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'RM ${booking.totalPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: _isDark
                                    ? const Color(0xFFF8FAFC)
                                    : AppColors.secondaryBlue,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                booking.status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _showBookingDetailsDialog(booking),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: mapCard),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: bookingsCard),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [mapCard, const SizedBox(height: 24), bookingsCard],
          );
  }

  Widget _buildOverlayRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _isDark
                  ? const Color(0xFFF8FAFC)
                  : AppColors.secondaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsAlertsPaymentsSection(bool isDesktop) {
    final activeMaintenance = _getActiveMaintenanceJobs();
    final recentPayments = _getRecentPayments();

    final actionsCard = Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: _isDark
                  ? const Color(0xFFF8FAFC)
                  : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _buildQuickActionButton(
                  'Add Vehicle',
                  Icons.add_road,
                  Colors.blue,
                  () {
                    setState(() => _activeTab = 'Cars');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Click "Add Vehicle" at the top right of the fleet screen.',
                        ),
                        backgroundColor: Colors.indigo,
                      ),
                    );
                  },
                ),
                _buildQuickActionButton(
                  'New Booking',
                  Icons.add_box,
                  Colors.green,
                  () {
                    setState(() => _activeTab = 'Bookings');
                  },
                ),
                _buildQuickActionButton(
                  'Add Customer',
                  Icons.person_add,
                  Colors.teal,
                  () {
                    setState(() => _activeTab = 'Customers');
                  },
                ),
                _buildQuickActionButton(
                  'Generate Report',
                  Icons.assessment,
                  Colors.purple,
                  () {
                    setState(() => _activeTab = 'Reports');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: _showSendNotificationDialog,
              icon: const Icon(Icons.campaign, size: 18),
              label: const Text(
                'Send Broadcast Notification',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    final maintenanceCard = activeMaintenance.isNotEmpty
        ? Container(
            height: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDark ? const Color(0xFF334155) : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Maintenance Alerts',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.secondaryBlue,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _activeTab = 'Vehicle Maintenance'),
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: activeMaintenance.length > 4
                        ? 4
                        : activeMaintenance.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final job = activeMaintenance[index];
                      final Color statusColor = job.status == 'In Progress'
                          ? Colors.orange
                          : Colors.blue;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          job.vehicleName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.secondaryBlue,
                          ),
                        ),
                        subtitle: Text(
                          '${job.title} • Due: ${job.endDate}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            job.status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        : null;

    final paymentsCard = Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Payments',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: _isDark
                      ? const Color(0xFFF8FAFC)
                      : AppColors.secondaryBlue,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _activeTab = 'Payments'),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: recentPayments.isEmpty
                ? const Center(child: Text('No payments found'))
                : ListView.separated(
                    itemCount: recentPayments.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final payment = recentPayments[index];
                      final custName = _getCustomerName(payment.userId);
                      final vName = _getVehicleNameForPayment(
                        payment.bookingId,
                      );
                      final bool isPending =
                          payment.status.toLowerCase() == 'pending' ||
                          payment.status == 'Pending Verification';
                      final Color statusColor = isPending
                          ? Colors.orange
                          : Colors.green;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          vName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.secondaryBlue,
                          ),
                        ),
                        subtitle: Text(
                          '$custName • ${DateFormat('dd MMM').format(payment.paymentDate)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'RM ${payment.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.secondaryBlue,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPending ? 'PENDING' : 'PAID',
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _showPaymentDetailsDialog(payment),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: actionsCard),
              const SizedBox(width: 24),
              if (maintenanceCard != null) ...[
                Expanded(child: maintenanceCard),
                const SizedBox(width: 24),
              ],
              Expanded(child: paymentsCard),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              actionsCard,
              const SizedBox(height: 24),
              if (maintenanceCard != null) ...[
                maintenanceCard,
                const SizedBox(height: 24),
              ],
              paymentsCard,
            ],
          );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              radius: 14,
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVehicleDetailsDialog(VehicleModel vehicle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor = isDark
        ? const Color(0xFF111827)
        : const Color(0xFFF1F5F9);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '${vehicle.brand} ${vehicle.model}',
            style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (vehicle.mainImage.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 150,
                          width: 250,
                          color: surfaceColor,
                          child: AppImage(imageSrc: vehicle.mainImage),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildDetailDialogRow('Plate Number', vehicle.plateNumber),
                  _buildDetailDialogRow('Category', vehicle.category),
                  _buildDetailDialogRow(
                    'Daily Rental Rate',
                    'RM ${vehicle.pricePerDay.toStringAsFixed(0)}',
                  ),
                  _buildDetailDialogRow('Seats', '${vehicle.seats} Seats'),
                  _buildDetailDialogRow('Transmission', vehicle.transmission),
                  _buildDetailDialogRow('Fuel Type', vehicle.fuelType),
                  _buildDetailDialogRow('Engine Spec', vehicle.engine),
                  _buildDetailDialogRow('Condition', vehicle.condition),
                  _buildDetailDialogRow('Current Status', vehicle.status),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showBookingDetailsDialog(BookingModel booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    double pricePerDay = 100.0;
    try {
      pricePerDay = _vehicles
          .firstWhere((v) => v.id == booking.vehicleId)
          .pricePerDay;
    } catch (_) {}
    final overdue = BookingService.getOverdueDetails(booking, pricePerDay);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Booking Details',
            style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailDialogRow('Booking Reference', booking.id),
                  _buildDetailDialogRow('Vehicle Model', booking.vehicleName),
                  _buildDetailDialogRow('Customer Name', booking.userName),
                  _buildDetailDialogRow('Customer Phone', booking.userPhone),
                  _buildDetailDialogRow(
                    'Pickup Date',
                    DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(booking.pickUpDate),
                  ),
                  _buildDetailDialogRow(
                    'Return Date',
                    booking.isOpenRental
                        ? 'Open Rental'
                        : (booking.returnDate != null
                              ? DateFormat(
                                  'dd MMM yyyy, hh:mm a',
                                ).format(booking.returnDate!)
                              : ""),
                  ),
                  _buildDetailDialogRow(
                    'Total Paid Price',
                    'RM ${booking.totalPrice.toStringAsFixed(2)}',
                  ),
                  if (overdue['isOverdue'] == true) ...[
                    _buildDetailDialogRow(
                      '⚠️ Overdue Duration',
                      '${overdue['days']} days, ${overdue['hours']} hours',
                      valueColor: Colors.redAccent,
                    ),
                    _buildDetailDialogRow(
                      '⚠️ Late Fees Accrued',
                      'RM ${overdue['charges'].toStringAsFixed(2)}',
                      valueColor: Colors.redAccent,
                    ),
                    _buildDetailDialogRow(
                      '⚠️ Current Total',
                      'RM ${(booking.totalPrice + overdue['charges']).toStringAsFixed(2)}',
                      valueColor: Colors.redAccent,
                    ),
                  ],
                  _buildDetailDialogRow(
                    'Deposit Amount',
                    'RM ${booking.depositAmount.toStringAsFixed(2)}',
                  ),
                  _buildDetailDialogRow(
                    'Booking Status',
                    booking.status.toUpperCase(),
                  ),
                  if (booking.notes?.isNotEmpty == true)
                    _buildDetailDialogRow('Reservation Notes', booking.notes!),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showPaymentDetailsDialog(PaymentModel payment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Transaction Details',
            style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailDialogRow('Payment Receipt ID', payment.id),
                  _buildDetailDialogRow('Booking Reference', payment.bookingId),
                  _buildDetailDialogRow(
                    'Transaction Amount',
                    'RM ${payment.amount.toStringAsFixed(2)}',
                  ),
                  _buildDetailDialogRow(
                    'Payment Method',
                    payment.paymentMethod,
                  ),
                  _buildDetailDialogRow(
                    'Transaction Ref',
                    payment.transactionId ?? 'N/A',
                  ),
                  _buildDetailDialogRow(
                    'Payment Date',
                    DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(payment.paymentDate),
                  ),
                  _buildDetailDialogRow(
                    'Verification Status',
                    payment.status.toUpperCase(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailDialogRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        valueColor ??
        (isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue);
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSendNotificationDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String target = 'all_customers';
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Send Broadcast Notification',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        style: TextStyle(color: textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Notification Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: messageController,
                        style: TextStyle(color: textPrimary),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notification Message',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: target,
                        dropdownColor: cardColor,
                        style: TextStyle(color: textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Recipient Target',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all_customers',
                            child: Text('All Customers'),
                          ),
                          DropdownMenuItem(
                            value: 'all_admins',
                            child: Text('All Admin Staff'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              target = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        messageController.text.trim().isEmpty) {
                      return;
                    }
                    final title = titleController.text.trim();
                    final msg = messageController.text.trim();
                    Navigator.pop(context);

                    try {
                      if (target == 'all_customers') {
                        await _notificationService.notifyAllCustomers(
                          title: title,
                          message: msg,
                          type: 'system',
                        );
                      } else if (target == 'all_admins') {
                        await _notificationService.notifyAllAdmins(
                          title: title,
                          message: msg,
                          type: 'system',
                        );
                      }
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Broadcast notification sent successfully!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to broadcast: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Send Broadcast',
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
}

class BookingSelectionDialogContent extends StatelessWidget {
  final List<BookingModel> bookings;
  final ValueChanged<BookingModel> onSelected;

  const BookingSelectionDialogContent({
    super.key,
    required this.bookings,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return ListTile(
          title: Text(
            booking.vehicleName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            'Customer: ${booking.userName} | RM ${booking.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: booking.status == 'pending'
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              booking.status.toUpperCase(),
              style: TextStyle(
                color: booking.status == 'pending'
                    ? Colors.orange
                    : Colors.green,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () => onSelected(booking),
        );
      },
    );
  }
}

class RevenueOverviewLineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final bool isDark;

  RevenueOverviewLineChartPainter({
    required this.values,
    required this.labels,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paintLine = Paint()
      ..color = AppColors.primaryOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final paintFill = Paint()..style = PaintingStyle.fill;

    double maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1000.0;
    final double stepX = size.width / (values.length - 1);

    // Draw horizontal grid lines
    final paintGrid = Paint()
      ..color = isDark ? const Color(0xFF334155) : Colors.grey[200]!
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final double y = 20.0 + (size.height - 50.0) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);

      final double gridVal = maxVal - (maxVal * i / 4);
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'RM ${(gridVal / 1000).toStringAsFixed(1)}K',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(5, y - 10));
    }

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final double x = i * stepX;
      final double y =
          20.0 + (size.height - 50.0) * (1.0 - (values[i] / maxVal));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height - 30);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (i == values.length - 1) {
        fillPath.lineTo(x, size.height - 30);
        fillPath.close();
      }

      // Draw X-axis monthly label
      if (i % 2 == 0 || i == values.length - 1) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(x - (textPainter.width / 2), size.height - 15),
        );
      }
    }

    final gradient = LinearGradient(
      colors: [
        AppColors.primaryOrange.withValues(alpha: 0.3),
        AppColors.primaryOrange.withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    paintFill.shader = gradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);

    // Draw point dots
    final paintDot = Paint()..color = AppColors.primaryOrange;
    final paintDotOuter = Paint()..color = Colors.white;
    for (int i = 0; i < values.length; i++) {
      final double x = i * stepX;
      final double y =
          20.0 + (size.height - 50.0) * (1.0 - (values[i] / maxVal));
      canvas.drawCircle(Offset(x, y), 5.0, paintDotOuter);
      canvas.drawCircle(Offset(x, y), 3.0, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BookingStatusDoughnutPainter extends CustomPainter {
  final Map<String, int> statusCounts;

  BookingStatusDoughnutPainter({required this.statusCounts});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = statusCounts.values
        .fold(0, (sum, val) => sum + val)
        .toDouble();
    if (total == 0) return;

    final double centerPadding = size.width / 2;
    final double radius = size.width / 2.4;
    final center = Offset(centerPadding, centerPadding);

    final List<MapEntry<String, int>> entries = statusCounts.entries.toList();
    final Map<String, Color> colorMap = {
      'Pending': Colors.orange,
      'Approved': Colors.blue,
      'Ongoing': Colors.teal,
      'Completed': Colors.green,
      'Cancelled': Colors.redAccent,
      'Overdue': Colors.red,
    };
    final List<Color> colors = [
      Colors.orange,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.redAccent,
      Colors.red,
    ];

    double startAngle = -3.14159 / 2;

    final paintStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < entries.length; i++) {
      final count = entries[i].value;
      if (count == 0) continue;

      final double sweepAngle = (count / total) * 2 * 3.14159;
      paintStroke.color = colorMap[entries[i].key] ?? colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.08,
        false,
        paintStroke,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
