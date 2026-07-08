import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../constants/colors.dart';
import '../../../services/notification_service.dart';
import '../../../models/notification_model.dart';
import '../../../widgets/loading_widget.dart';
import '../../../services/booking_service.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminNotificationsView extends StatefulWidget {
  final Function(String, String?) onNavigateTab;

  const AdminNotificationsView({super.key, required this.onNavigateTab});

  @override
  State<AdminNotificationsView> createState() => _AdminNotificationsViewState();
}

class _AdminNotificationsViewState extends State<AdminNotificationsView> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _searchQuery = '';
  String _selectedType = 'All';
  String _selectedStatus = 'All';
  String _selectedDateRange = 'All Time';

  final List<String> _typesList = [
    'All',
    'booking',
    'payment',
    'customer',
    'support',
    'maintenance',
    'vehicle',
    'location',
    'security',
    'system',
  ];

  Stream<List<NotificationModel>>? _notificationsStream;

  @override
  void initState() {
    super.initState();
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _notificationsStream = _notificationService.getNotificationsStream(
        currentUser.uid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _notificationsStream == null) {
      return const Center(child: Text('User not authenticated'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor = isDark
        ? const Color(0xFF111827)
        : const Color(0xFFF1F5F9);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingWidget(message: 'Loading notification logs...'),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading logs: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final allNotifs = snapshot.data ?? [];
        final filteredNotifs = allNotifs.where((n) {
          final query = _searchQuery.toLowerCase();
          final matchesQuery =
              n.title.toLowerCase().contains(query) ||
              n.message.toLowerCase().contains(query);
          final matchesType = _selectedType == 'All' || n.type == _selectedType;
          bool matchesStatus = true;
          if (_selectedStatus == 'Unread') {
            matchesStatus = !n.isRead;
          } else if (_selectedStatus == 'Read') {
            matchesStatus = n.isRead;
          }
          bool matchesDate = true;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          if (_selectedDateRange == 'Today') {
            matchesDate = n.createdAt.isAfter(today);
          } else if (_selectedDateRange == 'Last 7 Days') {
            matchesDate = n.createdAt.isAfter(
              today.subtract(const Duration(days: 7)),
            );
          } else if (_selectedDateRange == 'Last 30 Days') {
            matchesDate = n.createdAt.isAfter(
              today.subtract(const Duration(days: 30)),
            );
          }
          return matchesQuery && matchesType && matchesStatus && matchesDate;
        }).toList();

        final unreadCount = filteredNotifs.where((n) => !n.isRead).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification Audit Center',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              'View real-time event logs, system logins, and audit verification actions.',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        _buildHeaderButtons(
                          allNotifs,
                          currentUser.uid,
                          isDark: isDark,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notification Audit Center',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'View real-time event logs and audit actions.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        const SizedBox(height: 12),
                        _buildHeaderButtons(
                          allNotifs,
                          currentUser.uid,
                          isDark: isDark,
                        ),
                      ],
                    ),
              const SizedBox(height: 24),

              // Filter Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildSearchField(
                              isDark: isDark,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildStatusFilter(
                              isDark: isDark,
                              cardColor: surfaceColor,
                              textPrimary: textPrimary,
                              borderColor: borderColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildCategoryFilter(
                              isDark: isDark,
                              cardColor: surfaceColor,
                              textPrimary: textPrimary,
                              borderColor: borderColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildDateRangeFilter(
                              isDark: isDark,
                              cardColor: surfaceColor,
                              textPrimary: textPrimary,
                              borderColor: borderColor,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSearchField(
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 12),
                          _buildStatusFilter(
                            isDark: isDark,
                            cardColor: surfaceColor,
                            textPrimary: textPrimary,
                            borderColor: borderColor,
                          ),
                          const SizedBox(height: 12),
                          _buildCategoryFilter(
                            isDark: isDark,
                            cardColor: surfaceColor,
                            textPrimary: textPrimary,
                            borderColor: borderColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDateRangeFilter(
                            isDark: isDark,
                            cardColor: surfaceColor,
                            textPrimary: textPrimary,
                            borderColor: borderColor,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // Summary row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filteredNotifs.length} notifications ($unreadCount unread)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: textPrimary,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty ||
                      _selectedType != 'All' ||
                      _selectedStatus != 'All' ||
                      _selectedDateRange != 'All Time')
                    TextButton(
                      onPressed: () => setState(() {
                        _searchQuery = '';
                        _selectedType = 'All';
                        _selectedStatus = 'All';
                        _selectedDateRange = 'All Time';
                      }),
                      child: const Text(
                        'Reset Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Notification List — natural scroll (no Expanded)
              filteredNotifs.isEmpty
                  ? Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 64,
                              color: textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matching notifications found',
                              style: TextStyle(
                                color: textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredNotifs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notif = filteredNotifs[index];
                        final parsedColor = Color(int.parse(notif.color));
                        final bool isCompactMobile = !isDesktop && width <= 600;

                        // Unread highlight
                        final tileColor = notif.isRead
                            ? cardColor
                            : (isDark
                                  ? const Color(
                                      0xFF1E293B,
                                    ).withValues(alpha: 0.9)
                                  : const Color(0xFFFFF7ED));

                        final tileBorder = notif.isRead
                            ? borderColor
                            : AppColors.primaryOrange.withValues(alpha: 0.3);

                        return Container(
                          decoration: BoxDecoration(
                            color: tileColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: tileBorder),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              if (!notif.isRead) {
                                await _notificationService.markAsRead(
                                  notif.userId,
                                  notif.id,
                                );
                              }
                              if (notif.actionRoute.isNotEmpty &&
                                  notif.actionRoute != 'Dashboard') {
                                widget.onNavigateTab(
                                  notif.actionRoute,
                                  notif.relatedId,
                                );
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompactMobile ? 16 : 20,
                                vertical: isCompactMobile ? 16 : 12,
                              ),
                              child: isCompactMobile
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: parsedColor
                                                  .withValues(
                                                    alpha: isDark ? 0.25 : 0.1,
                                                  ),
                                              child: Text(
                                                notif.icon,
                                                style: const TextStyle(
                                                  fontSize: 18,
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
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: notif.isRead
                                                          ? FontWeight.bold
                                                          : FontWeight.w900,
                                                      fontSize: 18,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    DateFormat(
                                                      'dd MMM, hh:mm a',
                                                    ).format(notif.createdAt),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          notif.message,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.45,
                                            color: textSecondary,
                                          ),
                                        ),
                                        if (notif.type == 'pickup_reminder_admin') ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primaryOrange,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                onPressed: () {
                                                  if (notif.actionRoute.isNotEmpty && notif.actionRoute != 'Dashboard') {
                                                    widget.onNavigateTab(notif.actionRoute, notif.relatedId);
                                                  }
                                                },
                                                child: const Text('View Booking', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.teal,
                                                  side: const BorderSide(color: Colors.teal),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                onPressed: () => _confirmCustomerPickup(notif.relatedId),
                                                child: const Text("Customer Picked Up", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (notif.type == 'return_reminder_admin') ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primaryOrange,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                onPressed: () {
                                                  if (notif.actionRoute.isNotEmpty && notif.actionRoute != 'Dashboard') {
                                                    widget.onNavigateTab(notif.actionRoute, notif.relatedId);
                                                  }
                                                },
                                                child: const Text('View Booking', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.teal,
                                                  side: const BorderSide(color: Colors.teal),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                onPressed: () => _confirmVehicleReturn(notif.relatedId),
                                                child: const Text("Vehicle Returned", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                notif.isRead
                                                    ? Icons
                                                          .mark_as_unread_outlined
                                                    : Icons
                                                          .mark_chat_read_outlined,
                                                color: textSecondary,
                                                size: 20,
                                              ),
                                              tooltip: notif.isRead
                                                  ? 'Mark as Unread'
                                                  : 'Mark as Read',
                                              onPressed: () async {
                                                await _notificationService
                                                    .toggleReadStatus(
                                                      notif.userId,
                                                      notif.id,
                                                      !notif.isRead,
                                                    );
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline_rounded,
                                                color: textSecondary,
                                                size: 20,
                                              ),
                                              tooltip: 'Delete Log',
                                              onPressed: () async {
                                                await _notificationService
                                                    .deleteNotification(
                                                      notif.userId,
                                                      notif.id,
                                                    );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 0,
                                            vertical: 0,
                                          ),
                                      leading: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: parsedColor.withValues(
                                          alpha: isDark ? 0.25 : 0.1,
                                        ),
                                        child: Text(
                                          notif.icon,
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notif.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: notif.isRead
                                                    ? FontWeight.bold
                                                    : FontWeight.w900,
                                                fontSize: 14,
                                                color: textPrimary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            DateFormat(
                                              'dd MMM, hh:mm a',
                                            ).format(notif.createdAt),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              notif.message,
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.4,
                                                color: textSecondary,
                                              ),
                                            ),
                                            if (notif.type == 'pickup_reminder_admin') ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.primaryOrange,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                    onPressed: () {
                                                      if (notif.actionRoute.isNotEmpty && notif.actionRoute != 'Dashboard') {
                                                        widget.onNavigateTab(notif.actionRoute, notif.relatedId);
                                                      }
                                                    },
                                                    child: const Text('View Booking', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  OutlinedButton(
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.teal,
                                                      side: const BorderSide(color: Colors.teal),
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                    onPressed: () => _confirmCustomerPickup(notif.relatedId),
                                                    child: const Text("Customer Picked Up", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (notif.type == 'return_reminder_admin') ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.primaryOrange,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                    onPressed: () {
                                                      if (notif.actionRoute.isNotEmpty && notif.actionRoute != 'Dashboard') {
                                                        widget.onNavigateTab(notif.actionRoute, notif.relatedId);
                                                      }
                                                    },
                                                    child: const Text('View Booking', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  OutlinedButton(
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.teal,
                                                      side: const BorderSide(color: Colors.teal),
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                    ),
                                                    onPressed: () => _confirmVehicleReturn(notif.relatedId),
                                                    child: const Text("Vehicle Returned", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              notif.isRead
                                                  ? Icons
                                                        .mark_as_unread_outlined
                                                  : Icons
                                                        .mark_chat_read_outlined,
                                              color: textSecondary,
                                              size: 20,
                                            ),
                                            tooltip: notif.isRead
                                                ? 'Mark as Unread'
                                                : 'Mark as Read',
                                            onPressed: () async {
                                              await _notificationService
                                                  .toggleReadStatus(
                                                    notif.userId,
                                                    notif.id,
                                                    !notif.isRead,
                                                  );
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              color: textSecondary,
                                              size: 20,
                                            ),
                                            tooltip: 'Delete Log',
                                            onPressed: () async {
                                              await _notificationService
                                                  .deleteNotification(
                                                    notif.userId,
                                                    notif.id,
                                                  );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderButtons(
    List<NotificationModel> allNotifs,
    String userId, {
    required bool isDark,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (allNotifs.any((n) => !n.isRead))
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              foregroundColor: AppColors.primaryOrange,
              side: const BorderSide(color: AppColors.primaryOrange),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async =>
                await _notificationService.markAllAsRead(userId),
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text(
              'Mark All Read',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        if (allNotifs.any((n) => n.isRead))
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF2D1B1B)
                  : Colors.red.shade50,
              foregroundColor: Colors.redAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async =>
                await _notificationService.clearReadNotifications(userId),
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: const Text(
              'Clear Read',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      style: TextStyle(color: textPrimary),
      decoration: InputDecoration(
        hintText: 'Search alert title or messages...',
        hintStyle: TextStyle(color: textSecondary),
        prefixIcon: Icon(Icons.search, color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String label,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        isExpanded: true,
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(color: textPrimary, fontSize: 13),
        hint: Text(label, style: TextStyle(color: textPrimary, fontSize: 13)),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStatusFilter({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    return _buildDropdown<String>(
      value: _selectedStatus,
      label: 'Read Status',
      isDark: isDark,
      cardColor: cardColor,
      textPrimary: textPrimary,
      borderColor: borderColor,
      items: const [
        DropdownMenuItem(value: 'All', child: Text('All Logs')),
        DropdownMenuItem(value: 'Unread', child: Text('Unread Alerts')),
        DropdownMenuItem(value: 'Read', child: Text('Read Logs')),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedStatus = val);
      },
    );
  }

  Widget _buildCategoryFilter({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    return _buildDropdown<String>(
      value: _selectedType,
      label: 'Category',
      isDark: isDark,
      cardColor: cardColor,
      textPrimary: textPrimary,
      borderColor: borderColor,
      items: _typesList
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: Text(t[0].toUpperCase() + t.substring(1)),
            ),
          )
          .toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedType = val);
      },
    );
  }

  Widget _buildDateRangeFilter({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    return _buildDropdown<String>(
      value: _selectedDateRange,
      label: 'Date Range',
      isDark: isDark,
      cardColor: cardColor,
      textPrimary: textPrimary,
      borderColor: borderColor,
      items: const [
        DropdownMenuItem(value: 'All Time', child: Text('All Time')),
        DropdownMenuItem(value: 'Today', child: Text('Today')),
        DropdownMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
        DropdownMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days')),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedDateRange = val);
      },
    );
  }

  Future<void> _confirmCustomerPickup(String bookingId) async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('bookings')
          .child(bookingId)
          .get();
      if (snap.exists && snap.value != null) {
        final Map bookingMap = snap.value as Map;
        await BookingService().updateBookingStatus(
          bookingId,
          'active',
          bookingMap['userId']?.toString() ?? '',
          bookingMap['vehicleId']?.toString() ?? '',
          bookingMap['vehicleName']?.toString() ?? '',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Handover confirmed. Booking is now Active.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  Future<void> _confirmVehicleReturn(String bookingId) async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('bookings')
          .child(bookingId)
          .get();
      if (snap.exists && snap.value != null) {
        final Map bookingMap = snap.value as Map;
        await BookingService().updateBookingStatus(
          bookingId,
          'completed',
          bookingMap['userId']?.toString() ?? '',
          bookingMap['vehicleId']?.toString() ?? '',
          bookingMap['vehicleName']?.toString() ?? '',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Return confirmed. Booking is now Completed.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }
}
