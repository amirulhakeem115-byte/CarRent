import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/company_settings_provider.dart';
import '../../../services/web_audio_player.dart';
import '../../../models/user_model.dart';
import '../../../models/notification_model.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/app_logo.dart';
import '../../../ai/services/ai_service.dart';
import '../../../ai/models/ai_intent.dart';
import '../../../ai/widgets/ai_floating_button.dart';
import '../../../ai/widgets/ai_chat_panel.dart';
import '../../../models/booking_model.dart';
import 'booking_screen.dart';

// Import all screens to load them inside the shell
import 'home_screen.dart';
import 'vehicle_list_screen.dart';
import 'my_bookings_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'contact_support_screen.dart';
import 'customer_notifications_screen.dart';
import 'branches_map_screen.dart';
import 'reward_history_screen.dart';

class CustomerResponsiveShell extends StatefulWidget {
  final int initialIndex;
  final Widget? customBody;

  const CustomerResponsiveShell({
    super.key,
    this.initialIndex = 0,
    this.customBody,
  });

  static CustomerResponsiveShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<CustomerResponsiveShellState>();
  }

  @override
  State<CustomerResponsiveShell> createState() =>
      CustomerResponsiveShellState();
}

class CustomerResponsiveShellState extends State<CustomerResponsiveShell> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseDatabase _firebaseDatabase = FirebaseDatabase.instance;

  late int _currentIndex;
  Widget? _customBody;
  UserModel? _user;
  List<NotificationModel> _notifications = [];
  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;
  StreamSubscription<DatabaseEvent>? _userProfileSubscription;
  final Set<String> _playedNotificationIds = {};

  void _markNotificationLocallyRead(String notificationId) {
    setState(() {
      _notifications = _notifications.map((n) {
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

  void _markAllNotificationsLocallyRead() {
    setState(() {
      _notifications = _notifications.map((n) {
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _customBody = widget.customBody;
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AIService>().addListener(_handleAIAction);
      }
    });
  }

  void showCustomBody(Widget body) {
    setState(() {
      _customBody = body;
    });
  }

  void clearCustomBody() {
    setState(() {
      _customBody = null;
    });
  }

  void setIndex(int index) {
    setState(() {
      _currentIndex = index;
      _customBody = null;
    });
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
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

    if (intent is BookingIntent) {
      final action = intent.parameters['action']?.toString() ?? '';
      if (action == 'book_vehicle' || action == 'search_vehicles') {
        setIndex(1);
      } else {
        setIndex(2);
      }
      aiService.clearLastIntent();
    } else if (intent is RewardIntent) {
      setIndex(4);
      aiService.clearLastIntent();
    } else if (intent is SupportIntent) {
      setIndex(7);
      aiService.clearLastIntent();
    } else if (intent is ProfileIntent) {
      setIndex(6);
      aiService.clearLastIntent();
    } else if (intent is BranchIntent) {
      setIndex(3);
      aiService.clearLastIntent();
    } else if (intent is HistoryIntent) {
      setIndex(5);
      aiService.clearLastIntent();
    } else if (intent is DashboardIntent) {
      setIndex(0);
      aiService.clearLastIntent();
    } else if (intent is VehicleSearchIntent) {
      setIndex(1);
      aiService.clearLastIntent();
    } else if (intent is NotificationIntent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CustomerNotificationsScreen(),
        ),
      );
      aiService.clearLastIntent();
    }
  }

  Future<void> _loadUserData() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      try {
        final userModel = await _databaseService.getUser(currentUser.uid);
        if (mounted) {
          setState(() {
            _user = userModel;
          });
          _subscribeNotifications(currentUser.uid);
          _subscribeUserProfile(currentUser.uid);
        }
      } catch (e) {
        debugPrint('Error fetching user for shell: $e');
      }
    }
  }

  void _subscribeUserProfile(String userId) {
    _userProfileSubscription?.cancel();
    _userProfileSubscription = _firebaseDatabase
        .ref()
        .child('users')
        .child(userId)
        .onValue
        .listen((event) {
          if (!mounted ||
              !event.snapshot.exists ||
              event.snapshot.value == null) {
            return;
          }
          try {
            final raw = event.snapshot.value as Map<dynamic, dynamic>;
            final updatedUser = UserModel.fromMap(userId, raw);
            setState(() {
              _user = updatedUser;
            });
          } catch (e) {
            debugPrint('Error parsing realtime user profile: $e');
          }
        });
  }

  void _subscribeNotifications(String userId) {
    // ignore: avoid_print
    print("Customer UID: $userId");
    // ignore: avoid_print
    print("Listening to: notifications/$userId");
    _notificationsSubscription?.cancel();
    bool isInitial = true;
    _notificationsSubscription = _notificationService
        .getNotificationsStream(userId)
        .listen((notifs) {
          if (mounted) {
            final count = notifs.where((n) => !n.isRead).length;
            // ignore: avoid_print
            print("Unread count: $count");
            for (var notif in notifs) {
              if (!notif.isRead && !_playedNotificationIds.contains(notif.id)) {
                if (!isInitial) {
                  // ignore: avoid_print
                  print(
                    "Notification received: ${notif.title} - ${notif.message}",
                  );
                  // ignore: avoid_print
                  print("Playing notification sound");
                  _playNotificationSound();
                  _showNotificationSnackbar(notif);
                }
              }
              _playedNotificationIds.add(notif.id);
            }

            isInitial = false;

            setState(() {
              _notifications = notifs;
            });
          }
        });
  }

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
        debugPrint('SystemSound play error: $e');
      }
    }
  }

  void _showNotificationSnackbar(NotificationModel notif) {
    if (!mounted) return;
    final parsedColor = Color(int.parse(notif.color));

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: parsedColor.withValues(alpha: 0.1),
                child: Text(notif.icon, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.secondaryBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notif.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.lightText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  if (!notif.isRead) {
                    _markNotificationLocallyRead(notif.id);
                    await _notificationService.markAsRead(
                      notif.userId,
                      notif.id,
                    );
                  }
                  if (notif.actionRoute == 'Bookings' ||
                      notif.type == 'booking') {
                    setIndex(2);
                  } else if (notif.actionRoute == 'Payments' ||
                      notif.type == 'payment') {
                    setIndex(5);
                  } else if (notif.actionRoute == 'Support Inbox' ||
                      notif.actionRoute == 'Support' ||
                      notif.type == 'support') {
                    setIndex(7);
                  } else if (notif.actionRoute == 'Loyalty Rewards' ||
                      notif.type == 'reward') {
                    setIndex(4);
                  }
                },
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Future<void> _logout() async {
  //   final shouldLogout = await showDialog<bool>(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: const Text('Confirm Logout'),
  //         content: const Text('Do you want to log out?'),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context, false),
  //             child: const Text('No'),
  //           ),
  //           ElevatedButton(
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: AppColors.primaryOrange,
  //               foregroundColor: Colors.white,
  //             ),
  //             onPressed: () => Navigator.pop(context, true),
  //             child: const Text('Yes'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  //
  //   if (shouldLogout != true || !mounted) return;
  //
  //   final nav = Navigator.of(context);
  //   await _authService.logout();
  //   if (!mounted) return;
  //   nav.pushAndRemoveUntil(
  //     MaterialPageRoute(builder: (context) => LoginScreen(onLoggedIn: () {})),
  //     (route) => false,
  //   );
  // }

  String _getRelativeTimeString(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins min${mins == 1 ? "" : "s"} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hr${hours == 1 ? "" : "s"} ago';
    } else {
      return DateFormat('dd MMM').format(dateTime);
    }
  }

  Widget _getActiveScreen() {
    if (_customBody != null) {
      return _customBody!;
    }
    switch (_currentIndex) {
      case 0:
        return const CustomerHomeScreen();
      case 1:
        return const VehicleListScreen();
      case 2:
        return const MyBookingsScreen();
      case 3:
        return const BranchesMapScreen();
      case 4:
        return const RewardHistoryScreen();
      case 5:
        return const HistoryScreen();
      case 6:
        return const ProfileScreen();
      case 7:
        return const ContactSupportScreen();
      default:
        return const CustomerHomeScreen();
    }
  }

  String _getScreenTitle() {
    if (_customBody != null) {
      return 'Details';
    }
    switch (_currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Search Cars';
      case 2:
        return 'My Bookings';
      case 3:
        return 'Rental Hubs';
      case 4:
        return 'Loyalty Rewards';
      case 5:
        return 'Payments Ledger';
      case 6:
        return 'My Profile';
      case 7:
        return 'Support Desk';
      default:
        return context.watch<CompanySettingsProvider>().companyName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 950;
    final bool showMobileBottomNav = !isDesktop;
    final bool isCompactMobile = showMobileBottomNav && width < 380;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    // Mapping for Bottom Navigation Items (matches indices: 0, 1, 2, 5)
    int bottomNavIndex = 0;
    if (_currentIndex == 1) bottomNavIndex = 1;
    if (_currentIndex == 2) bottomNavIndex = 2;
    if (_currentIndex == 6) bottomNavIndex = 3;

    return PopScope(
      canPop: _customBody == null && _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_customBody != null) {
          clearCustomBody();
        } else if (_currentIndex != 0) {
          setIndex(0);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: showMobileBottomNav
            ? AppBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                centerTitle: false,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.directions_car_filled_rounded,
                        color: AppColors.primaryOrange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getScreenTitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompactMobile ? 14 : 16,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppColors.secondaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  _buildNotificationBell(unreadCount),
                  const SizedBox(width: 12),
                  _buildProfileAvatar(),
                  const SizedBox(width: 16),
                ],
              )
            : null,
        drawer: showMobileBottomNav ? _buildDrawer() : null,
        body: SafeArea(
          top: true,
          bottom: true,
          child: Row(
            children: [
              if (isDesktop) _buildSidebar(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDesktop) _buildHeader(unreadCount),
                    Expanded(
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double maxWidth = isDesktop
                                ? 1500
                                : constraints.maxWidth;
                            return Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxWidth),
                                child: _getActiveScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: showMobileBottomNav && _customBody == null
            ? Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  currentIndex: bottomNavIndex,
                  selectedItemColor: AppColors.primaryOrange,
                  unselectedItemColor: Colors.blueGrey[400],
                  showUnselectedLabels: true,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1B2436)
                      : Theme.of(context).cardColor,
                  elevation: 0,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 11,
                  ),
                  onTap: (index) {
                    setState(() {
                      if (index == 0) _currentIndex = 0;
                      if (index == 1) _currentIndex = 1;
                      if (index == 2) _currentIndex = 2;
                      if (index == 3) _currentIndex = 6;
                    });
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined),
                      activeIcon: Icon(Icons.dashboard_rounded),
                      label: 'Dashboard',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.search_rounded),
                      label: 'Search',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_today_outlined),
                      activeIcon: Icon(Icons.calendar_today_rounded),
                      label: 'Bookings',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline),
                      activeIcon: Icon(Icons.person_rounded),
                      label: 'Profile',
                    ),
                  ],
                ),
              )
            : null,
        floatingActionButton: AIFloatingButton(
          onTap: () async {
            final result = await showAIChatModal(context);
            if (result != null && result is String) {
              if (mounted) {
                if (result == 'search_vehicles') {
                  setIndex(1);
                } else if (result == 'view_bookings' || result == 'open_pending_bookings') {
                  setIndex(2);
                } else if (result == 'show_branches') {
                  setIndex(3);
                } else if (result == 'show_rewards') {
                  setIndex(4);
                } else if (result == 'view_history') {
                  setIndex(5);
                } else if (result == 'open_profile') {
                  setIndex(6);
                } else if (result == 'contact_support') {
                  setIndex(7);
                } else if (result == 'view_dashboard') {
                  setIndex(0);
                }
              }
              return;
            }
            if (result != null &&
                result is Map &&
                result['action'] == 'pay' &&
                context.mounted) {
              final bId = result['bookingId'];
              final method = result['method'];
              try {
                final bSnap = await FirebaseDatabase.instance
                    .ref()
                    .child('bookings')
                    .child(bId)
                    .get();
                if (bSnap.exists) {
                  final bData = Map<dynamic, dynamic>.from(bSnap.value as Map);
                  final booking = BookingModel.fromMap(bId, bData);
                  if (context.mounted) {
                    await BookingScreen.navigateToPayment(
                      context,
                      booking,
                      method,
                    );
                  }
                }
              } catch (e) {
                debugPrint(
                  'Error routing to checkout from floating button: $e',
                );
              }
            }
          },
          isOpen: false,
        ),
        floatingActionButtonLocation: _currentIndex == 3
            ? FloatingActionButtonLocation.startFloat
            : FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildNotificationBell(int unreadCount) {
    return PopupMenuButton<void>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tooltip: 'Notifications',
      padding: EdgeInsets.zero,
      itemBuilder: (context) {
        final recentNotifs = _notifications.take(10).toList();
        return [
          PopupMenuItem<void>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: Container(
              width: 340,
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          unreadCount > 0
                              ? 'Notifications ($unreadCount)'
                              : 'Notifications',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppColors.secondaryBlue,
                          ),
                        ),
                        if (_user != null &&
                            _notifications.any((n) => !n.isRead))
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              _markAllNotificationsLocallyRead();
                              await _notificationService.markAllAsRead(
                                _user!.id,
                              );
                            },
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
                  const Divider(height: 1),
                  if (recentNotifs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 40,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No notifications yet',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: recentNotifs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final notif = recentNotifs[index];
                          final parsedColor = Color(int.parse(notif.color));

                          return InkWell(
                            onTap: () async {
                              Navigator.pop(context);
                              if (!notif.isRead) {
                                _markNotificationLocallyRead(notif.id);
                                await _notificationService.markAsRead(
                                  notif.userId,
                                  notif.id,
                                );
                              }
                              if (notif.actionRoute == 'Bookings' ||
                                  notif.type == 'booking') {
                                setIndex(2);
                              } else if (notif.actionRoute == 'Payments' ||
                                  notif.type == 'payment') {
                                setIndex(5);
                              } else if (notif.actionRoute == 'Support Inbox' ||
                                  notif.actionRoute == 'Support' ||
                                  notif.type == 'support') {
                                setIndex(7);
                              } else if (notif.actionRoute ==
                                      'Loyalty Rewards' ||
                                  notif.type == 'reward') {
                                setIndex(4);
                              }
                            },
                            child: Container(
                              color: notif.isRead
                                  ? Colors.transparent
                                  : const Color(0xFFFFF7ED),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: parsedColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    child: Text(
                                      notif.icon,
                                      style: const TextStyle(fontSize: 12),
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
                                            color: AppColors.secondaryBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          notif.message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: notif.isRead
                                                ? Colors.grey[600]
                                                : Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _getRelativeTimeString(
                                            notif.createdAt,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 8,
                                            color: Colors.grey,
                                          ),
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
                  const Divider(height: 1),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CustomerNotificationsScreen(),
                        ),
                      ).then((route) {
                        if (route != null && route is String) {
                          if (route == 'Bookings') {
                            setIndex(2);
                          } else if (route == 'Payments') {
                            setIndex(5);
                          } else if (route == 'Support') {
                            setIndex(7);
                          }
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: const Text(
                        'View All Notifications',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
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
          color: Colors.grey[50],
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_outlined,
              color: AppColors.secondaryBlue,
              size: 20,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
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
    );
  }

  Widget _buildProfileAvatar() {
    final imageProvider = getAppImageProvider(_user?.profileImage);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() => _currentIndex = 6);
        },
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.lightGray,
          backgroundImage: imageProvider,
          child: _user?.profileImage.isNotEmpty != true || imageProvider == null
              ? const Icon(
                  Icons.person,
                  size: 18,
                  color: AppColors.secondaryBlue,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildHeader(int unreadCount) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B2436)
            : Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getScreenTitle(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.secondaryBlue,
            ),
          ),
          Row(
            children: [
              _buildNotificationBell(unreadCount),
              const SizedBox(width: 16),
              const VerticalDivider(width: 20, indent: 20, endIndent: 20),
              const SizedBox(width: 8),
              _buildProfileAvatar(),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user?.fullName ?? 'Customer',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : AppColors.secondaryBlue,
                    ),
                  ),
                  Text(
                    _user?.email ?? '',
                    style: TextStyle(fontSize: 10, color: Colors.blueGrey[400]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF172033)
          : AppColors.secondaryBlue,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const AppLogo(size: 24, fallbackColor: Colors.white),
                const SizedBox(width: 12),
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
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSidebarTile(Icons.dashboard_rounded, 'Dashboard', 0),
                _buildSidebarTile(Icons.search_rounded, 'Search Cars', 1),
                _buildSidebarTile(
                  Icons.calendar_today_rounded,
                  'My Bookings',
                  2,
                ),
                _buildSidebarTile(Icons.map_rounded, 'Branches', 3),
                _buildSidebarTile(Icons.stars_rounded, 'Loyalty Rewards', 4),
                _buildSidebarTile(Icons.history_rounded, 'History', 5),
                _buildSidebarTile(
                  Icons.support_agent_rounded,
                  'Support Desk',
                  7,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSidebarTile(IconData icon, String title, int index) {
    final bool isActive = _currentIndex == index && _customBody == null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isActive ? AppColors.primaryOrange : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: () {
            setIndex(index);
          },
          leading: Icon(
            icon,
            color: isActive ? Colors.white : Colors.blueGrey[300],
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.blueGrey[300],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF172033)
          : AppColors.secondaryBlue,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF172033)
                  : AppColors.secondaryBlue,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 32, fallbackColor: Colors.white),
                const SizedBox(height: 12),
                Text(
                  '${context.watch<CompanySettingsProvider>().companyName} SYSTEM',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerTile(Icons.dashboard_rounded, 'Dashboard', 0),
                _buildDrawerTile(Icons.search_rounded, 'Search Cars', 1),
                _buildDrawerTile(
                  Icons.calendar_today_rounded,
                  'My Bookings',
                  2,
                ),
                _buildDrawerTile(Icons.map_rounded, 'Branches', 3),
                _buildDrawerTile(Icons.history_rounded, 'History', 5),
                _buildDrawerTile(
                  Icons.support_agent_rounded,
                  'Support Desk',
                  7,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, int index) {
    final bool isActive = _currentIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppColors.primaryOrange : Colors.white70,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? AppColors.primaryOrange : Colors.white70,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close Drawer
        setIndex(index);
      },
    );
  }
}
