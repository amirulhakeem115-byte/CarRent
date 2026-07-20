import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../constants/colors.dart';
import '../../../services/notification_service.dart';
import '../../../models/notification_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../widgets/loading_widget.dart';
import 'reward_history_screen.dart';
import '../../../services/receipt_service.dart';
import '../../../services/user_role_cache.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const int _notificationsLoadLimit = 120;

  String _searchQuery = '';
  String _selectedType = 'All';
  String _selectedStatus = 'All'; // All, Unread, Read

  final List<String> _typesList = [
    'All',
    'booking',
    'payment',
    'support',
    'reward',
    'general',
  ];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  bool get _isPhone => MediaQuery.of(context).size.width < 420;
  Color get _textColor =>
      _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor =>
      _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;
  Color get _borderColor =>
      _isDark ? const Color(0xFF334155) : AppColors.borderGray;

  double _rf(double base, {double min = 9, double max = 24}) {
    final width = MediaQuery.of(context).size.width;
    final factor = (width / 390).clamp(0.86, 1.0);
    final size = base * factor;
    if (size < min) return min;
    if (size > max) return max;
    return size;
  }

  Stream<List<NotificationModel>>? _notificationsStream;

  Future<void> _reloadNotifications({bool forceTokenRefresh = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (forceTokenRefresh) {
      try {
        await currentUser.getIdToken(true);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _notificationsStream = _notificationService.getNotificationsStream(
        currentUser.uid,
        limit: _notificationsLoadLimit,
        includeAdminNotifications: false,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _reloadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _notificationsStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in first.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _isDark ? const Color(0xFF1B2436) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications Centre',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _textColor),
            onPressed: () => _reloadNotifications(forceTokenRefresh: true),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: LoadingWidget(message: 'Syncing notifications...'),
            );
          }

          if (snapshot.hasError) {
            final raw = snapshot.error.toString();
            final isPermission = raw.toLowerCase().contains(
              'permission-denied',
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPermission
                          ? 'Notifications access is currently denied by backend rules.'
                          : 'Failed to load notifications.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPermission
                          ? 'Tap retry after refreshing session. If it persists, Firebase rules must allow your user to read notifications.'
                          : raw,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _subColor, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _reloadNotifications(forceTokenRefresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final allNotifs = snapshot.data ?? [];
          final filteredNotifs = allNotifs.where((n) {
            // 1. Search filter
            final q = _searchQuery.toLowerCase().trim();
            final matchesSearch =
                q.isEmpty ||
                n.title.toLowerCase().contains(q) ||
                n.message.toLowerCase().contains(q);

            // 2. Category filter
            final matchesType =
                _selectedType == 'All' ||
                n.type.toLowerCase() == _selectedType.toLowerCase();

            // 3. Status filter
            bool matchesStatus = true;
            if (_selectedStatus == 'Unread') {
              matchesStatus = !n.isRead;
            } else if (_selectedStatus == 'Read') {
              matchesStatus = n.isRead;
            }

            return matchesSearch && matchesType && matchesStatus;
          }).toList();

          final unreadCount = allNotifs.where((n) => !n.isRead).length;

          return Column(
            children: [
              // Search & Filter header cards
              _buildFilterSection(allNotifs, currentUser.uid),

              // Summary status text row
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isPhone ? 16 : 24,
                  vertical: _isPhone ? 6 : 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Showing ${filteredNotifs.length} alerts ($unreadCount unread)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _rf(12, min: 10),
                        color: _textColor,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty ||
                        _selectedType != 'All' ||
                        _selectedStatus != 'All')
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedType = 'All';
                            _selectedStatus = 'All';
                          });
                        },
                        child: Text(
                          'Reset Filters',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                            fontSize: _rf(12, min: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Notifications List
              Expanded(
                child: filteredNotifs.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isPhone ? 12 : 20,
                          vertical: _isPhone ? 6 : 8,
                        ),
                        itemCount: filteredNotifs.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: _isPhone ? 10 : 12),
                        itemBuilder: (context, index) {
                          final notif = filteredNotifs[index];
                          return _buildNotificationCard(notif, currentUser.uid);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(List<NotificationModel> allNotifs, String userId) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        _isPhone ? 12 : 20,
        10,
        _isPhone ? 12 : 20,
        10,
      ),
      padding: EdgeInsets.all(_isPhone ? 12 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search input field
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(color: _textColor, fontSize: _rf(13, min: 11)),
            decoration: InputDecoration(
              hintText: 'Search notifications...',
              hintStyle: TextStyle(
                color: _isDark ? Colors.white30 : Colors.grey,
                fontSize: _rf(13, min: 11),
              ),
              prefixIcon: Icon(Icons.search, size: 20, color: _subColor),
              contentPadding: EdgeInsets.symmetric(
                vertical: _isPhone ? 6 : 8,
                horizontal: _isPhone ? 8 : 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filters selection Row
          _isPhone
              ? Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(color: _textColor, fontSize: _rf(12)),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(
                          color: _subColor,
                          fontSize: _rf(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      items: _typesList.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(
                            t.substring(0, 1).toUpperCase() + t.substring(1),
                            style: TextStyle(fontSize: _rf(12)),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(color: _textColor, fontSize: _rf(12)),
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: TextStyle(
                          color: _subColor,
                          fontSize: _rf(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text(
                            'All Status',
                            style: TextStyle(fontSize: _rf(12)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Unread',
                          child: Text(
                            'Unread',
                            style: TextStyle(fontSize: _rf(12)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Read',
                          child: Text(
                            'Read',
                            style: TextStyle(fontSize: _rf(12)),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        dropdownColor: Theme.of(context).cardColor,
                        style: TextStyle(color: _textColor, fontSize: _rf(12)),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(
                            color: _subColor,
                            fontSize: _rf(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        items: _typesList.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(
                              t.substring(0, 1).toUpperCase() + t.substring(1),
                              style: TextStyle(fontSize: _rf(12)),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        dropdownColor: Theme.of(context).cardColor,
                        style: TextStyle(color: _textColor, fontSize: _rf(12)),
                        decoration: InputDecoration(
                          labelText: 'Status',
                          labelStyle: TextStyle(
                            color: _subColor,
                            fontSize: _rf(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text(
                              'All Status',
                              style: TextStyle(fontSize: _rf(12)),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Unread',
                            child: Text(
                              'Unread',
                              style: TextStyle(fontSize: _rf(12)),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Read',
                            child: Text(
                              'Read',
                              style: TextStyle(fontSize: _rf(12)),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 12),

          // Action buttons Row
          Wrap(
            alignment: WrapAlignment.end,
            runSpacing: 6,
            spacing: 6,
            children: [
              if (allNotifs.any((n) => !n.isRead))
                TextButton.icon(
                  onPressed: () async {
                    await _notificationService.markAllAsRead(userId);
                  },
                  icon: Icon(
                    Icons.done_all,
                    size: _rf(14, min: 12),
                    color: AppColors.primaryOrange,
                  ),
                  label: Text(
                    'Mark All Read',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: _rf(11, min: 10),
                    ),
                  ),
                ),
              if (allNotifs.any((n) => n.isRead))
                TextButton.icon(
                  onPressed: () async {
                    await _notificationService.clearReadNotifications(userId);
                  },
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    size: _rf(14, min: 12),
                    color: Colors.redAccent,
                  ),
                  label: Text(
                    'Clear Read',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: _rf(11, min: 10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: _isDark ? const Color(0xFF334155) : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No matching notifications',
            style: TextStyle(fontWeight: FontWeight.bold, color: _textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search query or filters.',
            style: TextStyle(color: _subColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif, String userId) {
    final parsedColor = Color(int.parse(notif.color));
    final formattedDate = DateFormat('dd MMM, hh:mm a').format(notif.createdAt);
    final isPhone = _isPhone;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: notif.isRead
              ? Theme.of(context).cardColor
              : (_isDark ? const Color(0xFF2C2420) : const Color(0xFFFFF7ED)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isRead
                ? _borderColor
                : AppColors.primaryOrange.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isPhone ? 12 : 16,
            vertical: isPhone ? 6 : 8,
          ),
          minLeadingWidth: isPhone ? 38 : 40,
          leading: CircleAvatar(
            radius: isPhone ? 18 : 20,
            backgroundColor: parsedColor.withValues(alpha: 0.1),
            child: Text(
              notif.icon,
              style: TextStyle(fontSize: _rf(16, min: 14)),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notif.title,
                style: TextStyle(
                  fontWeight: notif.isRead ? FontWeight.bold : FontWeight.w900,
                  fontSize: _rf(13, min: 11),
                  color: _textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                formattedDate,
                style: TextStyle(fontSize: _rf(9, min: 8), color: _subColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.message,
                  style: TextStyle(
                    fontSize: _rf(11, min: 10),
                    height: 1.3,
                    color: notif.isRead ? _subColor : _textColor,
                  ),
                  maxLines: isPhone ? 5 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (notif.type == 'pickup_reminder_customer') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () =>
                            _showBookingDetails(context, notif.relatedId),
                        child: Text(
                          'View Booking',
                          style: TextStyle(
                            fontSize: _rf(10, min: 9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () => _sendOnMyWayStatus(notif.relatedId),
                        child: Text(
                          "I'm On My Way",
                          style: TextStyle(
                            fontSize: _rf(10, min: 9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (notif.type == 'return_reminder_customer') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () => _sendOnMyWayStatus(notif.relatedId),
                        child: Text(
                          "I'm On My Way",
                          style: TextStyle(
                            fontSize: _rf(10, min: 9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: const BorderSide(
                            color: AppColors.primaryOrange,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () => _showExtendRentalGuidance(),
                        child: Text(
                          "Extend Rental",
                          style: TextStyle(
                            fontSize: _rf(10, min: 9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        notif.isRead
                            ? Icons.mark_as_unread_outlined
                            : Icons.mark_chat_read_outlined,
                        color: _subColor,
                        size: _rf(16, min: 14),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 16,
                      onPressed: () async {
                        await _notificationService.toggleReadStatus(
                          userId,
                          notif.id,
                          !notif.isRead,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: _subColor,
                        size: _rf(16, min: 14),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 16,
                      onPressed: () async {
                        await _notificationService.deleteNotification(
                          userId,
                          notif.id,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          onTap: () => _handleNotificationTap(notif, userId),
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(
    NotificationModel notif,
    String userId,
  ) async {
    // 1. Mark as read immediately
    if (!notif.isRead) {
      await _notificationService.markAsRead(userId, notif.id);
    }

    if (!mounted) return;

    final typeLower = notif.type.toLowerCase();

    // 2. Perform redirection
    if (typeLower == 'booking' && notif.relatedId.isNotEmpty) {
      _showBookingDetails(context, notif.relatedId);
    } else if (typeLower == 'payment' && notif.relatedId.isNotEmpty) {
      _showPaymentDetails(context, notif.relatedId);
    } else if (typeLower == 'support') {
      Navigator.pop(context, 'Support');
    } else if (typeLower == 'reward') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RewardHistoryScreen()),
      );
    } else {
      // Fallback
      if (notif.actionRoute == 'Bookings') {
        Navigator.pop(context, 'Bookings');
      } else if (notif.actionRoute == 'Payments') {
        Navigator.pop(context, 'Payments');
      } else if (notif.actionRoute == 'Support Desk') {
        Navigator.pop(context, 'Support');
      }
    }
  }

  // ✅ UPDATED: Fixed _showBookingDetails method
  Future<void> _showBookingDetails(
    BuildContext context,
    String bookingId,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      ),
    );

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (context.mounted) Navigator.pop(context);
        return;
      }

      // 1. Get booking details
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('bookings')
          .child(bookingId)
          .get();

      if (!snap.exists || snap.value == null) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking record no longer exists.')),
          );
        }
        return;
      }

      final booking = BookingModel.fromMap(
        bookingId,
        snap.value as Map<dynamic, dynamic>,
      );

      // 2. Check if booking is paid - SAFER APPROACH
      bool isPaid = false;

      // Query payments by bookingId
      try {
        final paySnap = await FirebaseDatabase.instance
            .ref()
            .child('payments')
            .orderByChild('bookingId')
            .equalTo(bookingId)
            .get();

        if (paySnap.exists && paySnap.value != null) {
          final Map pMap = paySnap.value as Map;
          for (var pValue in pMap.values) {
            if (pValue is Map) {
              final pStatus =
                  (pValue['paymentStatus'] ?? pValue['status'] ?? '')
                      .toString()
                      .toLowerCase();
              if (pStatus == 'approved' || pStatus == 'paid') {
                isPaid = true;
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Could not query payments: $e');
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _showBookingDetailsDialog(context, booking, isPaid: isPaid);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading booking details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error fetching booking details: $e');
    }
  }

  Future<void> _showPaymentDetails(
    BuildContext context,
    String paymentId,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      ),
    );

    try {
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('payments')
          .child(paymentId)
          .get();
      if (context.mounted) Navigator.pop(context); // Close loading indicator

      if (snap.exists && snap.value != null) {
        final payment = PaymentModel.fromMap(
          paymentId,
          snap.value as Map<dynamic, dynamic>,
        );
        if (context.mounted) {
          _showPaymentDetailsDialog(context, payment);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment transaction details no longer exist.'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Safety pop
      debugPrint('Error fetching payment details: $e');
    }
  }

  void _showBookingDetailsDialog(
    BuildContext context,
    BookingModel booking, {
    bool isPaid = false,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy');
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final maxSheetHeight = MediaQuery.of(context).size.height * 0.82;
        final isPhone = MediaQuery.of(context).size.width < 420;
        return Padding(
          padding: EdgeInsets.only(
            top: isPhone ? 16 : 24,
            left: isPhone ? 16 : 24,
            right: isPhone ? 16 : 24,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + (isPhone ? 16 : 24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Booking Specification',
                          style: TextStyle(
                            fontSize: _rf(16, min: 14),
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          booking.status.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: _rf(10, min: 9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isPhone ? 14 : 20),
                  _buildDetailRow('Reservation Ref ID', booking.id),
                  _buildDetailRow('Vehicle Name', booking.vehicleName),
                  _buildDetailRow(
                    'Rental Days',
                    booking.isOpenRental
                        ? 'Open Ended'
                        : '${booking.rentalDays} days',
                  ),
                  _buildDetailRow(
                    'Rental Duration',
                    booking.isOpenRental
                        ? '${dateFormat.format(booking.pickUpDate)} to OPEN RENTAL'
                        : '${dateFormat.format(booking.pickUpDate)} to ${booking.returnDate != null ? dateFormat.format(booking.returnDate!) : ""}',
                  ),
                  _buildDetailRow(
                    'Security Deposit',
                    'RM ${booking.depositAmount.toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Total Price Paid',
                    'RM ${booking.totalPrice.toStringAsFixed(2)}',
                  ),
                  if (booking.notes != null && booking.notes!.isNotEmpty)
                    _buildDetailRow('Remarks', booking.notes!),
                  if (isPaid) ...[
                    const SizedBox(height: 16),
                    Divider(color: _borderColor),
                    const SizedBox(height: 12),
                    Text(
                      'Receipt Documents',
                      style: TextStyle(
                        fontSize: _rf(12, min: 10),
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: isPhone ? 9 : 10,
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              ReceiptService().viewReceipt(context, booking.id);
                            },
                            icon: Icon(
                              Icons.visibility,
                              size: _rf(14, min: 12),
                            ),
                            label: Text(
                              'View',
                              style: TextStyle(
                                fontSize: _rf(11, min: 10),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isDark
                                  ? const Color(0xFF0F172A)
                                  : AppColors.secondaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: isPhone ? 9 : 10,
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              ReceiptService().downloadReceipt(
                                context,
                                booking.id,
                              );
                            },
                            icon: Icon(Icons.download, size: _rf(14, min: 12)),
                            label: Text(
                              'Download',
                              style: TextStyle(
                                fontSize: _rf(11, min: 10),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: isPhone ? 16 : 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isPhone ? 12 : 14,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: _rf(13, min: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPaymentDetailsDialog(BuildContext context, PaymentModel payment) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final maxSheetHeight = MediaQuery.of(context).size.height * 0.82;
        final isPhone = MediaQuery.of(context).size.width < 420;
        return Padding(
          padding: EdgeInsets.only(
            top: isPhone ? 16 : 24,
            left: isPhone ? 16 : 24,
            right: isPhone ? 16 : 24,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + (isPhone ? 16 : 24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Payment Transaction',
                          style: TextStyle(
                            fontSize: _rf(16, min: 14),
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (payment.paymentStatus ?? payment.status)
                              .toUpperCase(),
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: _rf(10, min: 9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isPhone ? 14 : 20),
                  _buildDetailRow('Transaction ID', payment.id),
                  _buildDetailRow('Booking Ref ID', payment.bookingId),
                  _buildDetailRow(
                    'Paid Amount',
                    'RM ${payment.amount.toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Method Type',
                    payment.paymentMethod.toUpperCase(),
                  ),
                  _buildDetailRow(
                    'Lodged At',
                    dateFormat.format(payment.paymentDate),
                  ),
                  if (payment.transactionId != null)
                    _buildDetailRow('Reference Ref', payment.transactionId!),
                  if (payment.rejectionReason != null &&
                      payment.rejectionReason!.isNotEmpty)
                    _buildDetailRow(
                      'Rejection Reason',
                      payment.rejectionReason!,
                      isItalic: true,
                    ),
                  SizedBox(height: isPhone ? 16 : 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isPhone ? 12 : 14,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: _rf(13, min: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isItalic = false}) {
    final compact = _isPhone;
    final labelSize = _rf(12, min: 10);
    final valueSize = _rf(12, min: 10);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: _subColor,
                fontSize: labelSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: valueSize,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                color: _textColor,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: _subColor,
                fontSize: labelSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: valueSize,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                color: _textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendOnMyWayStatus(String bookingId) async {
    try {
      final currentUser = _auth.currentUser;
      final uid = currentUser?.uid ?? 'unauthenticated';
      final role = currentUser != null ? await UserRoleCache.getRole(currentUser.uid) : 'customer';

      debugPrint('[STEP 1] Customer clicked I\'m On My Way in notifications screen (Booking ID: $bookingId)');
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('bookings')
          .child(bookingId)
          .get();
      if (!snap.exists || snap.value == null) throw 'Booking not found';
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final booking = BookingModel.fromMap(bookingId, data);

      final effectiveUserId = uid.isNotEmpty && uid != 'unauthenticated' ? uid : booking.userId;

      debugPrint('=== BOOKING STATUS UPDATE TRACE ===');
      debugPrint('Current UID: $uid');
      debugPrint('Current Role: $role');
      debugPrint('Booking ID: $bookingId');
      debugPrint('Firebase path being updated: bookings/$bookingId');
      debugPrint('Old Status: ${booking.customerStatus ?? booking.status}');
      debugPrint('New Status: on_my_way');
      debugPrint('===================================');

      await FirebaseDatabase.instance
          .ref()
          .child('bookings')
          .child(bookingId)
          .update({
        'customerStatus': 'on_my_way',
        'userId': effectiveUserId,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      debugPrint('[STEP 2] Booking status updated successfully (Booking ID: $bookingId)');

      // Safely perform notification write without blocking or failing status update
      try {
        final notificationService = NotificationService();
        final bool isPickup = booking.status.toLowerCase() != 'active' &&
                              booking.status.toLowerCase() != 'ongoing' &&
                              booking.status.toLowerCase() != 'overdue';
        final String actionMsg = isPickup ? "pick up" : "return";

        await notificationService.notifyAllAdmins(
          title: isPickup ? "Customer On the Way 🚗" : "Return Request",
          message: isPickup
              ? 'Customer "${booking.userName}" is on the way to pick up Vehicle "${booking.vehicleName}".'
              : 'Customer ${booking.userName} is on the way to return ${booking.vehicleName}. Please prepare for vehicle inspection.',
          type: isPickup ? 'on_my_way' : 'return_request',
          icon: '🚗',
          color: '0xFF10B981',
          relatedId: bookingId,
          actionRoute: 'Bookings',
        );

        await notificationService.createNotification(
          userId: effectiveUserId,
          title: "Status Updated: On My Way",
          message: "You have notified the Admin that you are on your way to $actionMsg ${booking.vehicleName}.",
          type: 'booking',
          icon: '🚗',
          color: '0xFF10B981',
          relatedId: bookingId,
          actionRoute: 'Dashboard',
        );
      } catch (notifErr) {
        debugPrint('[CustomerNotificationsScreen] Warning: notification creation failed: $notifErr');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Status sent to admin: You are on your way!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to send status: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _showExtendRentalGuidance() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Extend Active Rental",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
            ),
          ),
          content: Text(
            "To request a rental contract extension, please contact CARENT Corporate Support directly at +60 3-2274 1234 or visit the nearest branch center.",
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
