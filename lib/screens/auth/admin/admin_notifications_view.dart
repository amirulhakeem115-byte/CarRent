import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../constants/colors.dart';
import '../../../services/notification_service.dart';
import '../../../models/notification_model.dart';
import '../../../widgets/loading_widget.dart';

class AdminNotificationsView extends StatefulWidget {
  final Function(String, String?) onNavigateTab;

  const AdminNotificationsView({
    super.key,
    required this.onNavigateTab,
  });

  @override
  State<AdminNotificationsView> createState() => _AdminNotificationsViewState();
}

class _AdminNotificationsViewState extends State<AdminNotificationsView> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _searchQuery = '';
  String _selectedType = 'All';
  String _selectedStatus = 'All'; // All, Unread, Read
  String _selectedDateRange = 'All Time'; // All Time, Today, Last 7 Days, Last 30 Days

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
    'system'
  ];

  Widget _buildHeaderButtons(List<NotificationModel> allNotifs, String userId) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (allNotifs.any((n) => !n.isRead))
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryOrange,
              side: const BorderSide(color: AppColors.primaryOrange),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await _notificationService.markAllAsRead(userId);
            },
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('Mark All Read', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        if (allNotifs.any((n) => n.isRead))
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[50],
              foregroundColor: Colors.redAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await _notificationService.clearReadNotifications(userId);
            },
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: const Text('Clear Read', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'Search alert title or messages...',
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        fillColor: Colors.grey[50],
        filled: true,
      ),
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedStatus,
      decoration: const InputDecoration(labelText: 'Read Status', border: OutlineInputBorder()),
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

  Widget _buildCategoryFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedType,
      decoration: const InputDecoration(labelText: 'Event Category', border: OutlineInputBorder()),
      items: _typesList.map((t) {
        return DropdownMenuItem(
          value: t,
          child: Text(t.substring(0, 1).toUpperCase() + t.substring(1)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedType = val);
      },
    );
  }

  Widget _buildDateRangeFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedDateRange,
      decoration: const InputDecoration(labelText: 'Date Range', border: OutlineInputBorder()),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('User not authenticated'));
    }

    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.getNotificationsStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget(message: 'Loading notification logs...'));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading logs: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final allNotifs = snapshot.data ?? [];
        final filteredNotifs = allNotifs.where((n) {
          // 1. Search Query
          final query = _searchQuery.toLowerCase();
          final matchesQuery = n.title.toLowerCase().contains(query) || n.message.toLowerCase().contains(query);

          // 2. Category Type
          final matchesType = _selectedType == 'All' || n.type == _selectedType;

          // 3. Status Read/Unread
          bool matchesStatus = true;
          if (_selectedStatus == 'Unread') {
            matchesStatus = !n.isRead;
          } else if (_selectedStatus == 'Read') {
            matchesStatus = n.isRead;
          }

          // 4. Date Range
          bool matchesDate = true;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          if (_selectedDateRange == 'Today') {
            matchesDate = n.createdAt.isAfter(today);
          } else if (_selectedDateRange == 'Last 7 Days') {
            matchesDate = n.createdAt.isAfter(today.subtract(const Duration(days: 7)));
          } else if (_selectedDateRange == 'Last 30 Days') {
            matchesDate = n.createdAt.isAfter(today.subtract(const Duration(days: 30)));
          }

          return matchesQuery && matchesType && matchesStatus && matchesDate;
        }).toList();

        final unreadCount = filteredNotifs.where((n) => !n.isRead).length;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return isWide
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Notification Audit Center',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
                                  ),
                                  Text(
                                    'View real-time event logs, system logins, and audit verification actions.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            _buildHeaderButtons(allNotifs, currentUser.uid),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notification Audit Center',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
                                ),
                                Text(
                                  'View real-time event logs and audit actions.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildHeaderButtons(allNotifs, currentUser.uid),
                          ],
                        );
                },
              ),
              const SizedBox(height: 24),

              // Filter Controls Card
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(flex: 3, child: _buildSearchField()),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildStatusFilter()),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildCategoryFilter()),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildDateRangeFilter()),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSearchField(),
                              const SizedBox(height: 12),
                              _buildStatusFilter(),
                              const SizedBox(height: 12),
                              _buildCategoryFilter(),
                              const SizedBox(height: 12),
                              _buildDateRangeFilter(),
                            ],
                          ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Filter Summary Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filteredNotifs.length} notifications ($unreadCount unread)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryBlue),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedType != 'All' || _selectedStatus != 'All' || _selectedDateRange != 'All Time')
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _selectedType = 'All';
                          _selectedStatus = 'All';
                          _selectedDateRange = 'All Time';
                        });
                      },
                      child: const Text('Reset Filters', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Main Notification List
              Expanded(
                child: filteredNotifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No matching notifications found', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredNotifs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notif = filteredNotifs[index];
                          final parsedColor = Color(int.parse(notif.color));

                          return Container(
                            decoration: BoxDecoration(
                              color: notif.isRead ? Colors.white : const Color(0xFFFFF7ED), // Highlight unread with orange tint
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: notif.isRead ? Colors.grey[200]! : AppColors.primaryOrange.withValues(alpha: 0.15),
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: parsedColor.withValues(alpha: 0.1),
                                child: Text(notif.icon, style: const TextStyle(fontSize: 20)),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontWeight: notif.isRead ? FontWeight.bold : FontWeight.w900,
                                        fontSize: 14,
                                        color: AppColors.secondaryBlue,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd MMM, hh:mm a').format(notif.createdAt),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  notif.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: notif.isRead ? Colors.grey[600] : Colors.grey[800],
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      notif.isRead ? Icons.mark_as_unread_outlined : Icons.mark_chat_read_outlined,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                    tooltip: notif.isRead ? 'Mark as Unread' : 'Mark as Read',
                                    onPressed: () async {
                                      await _notificationService.toggleReadStatus(notif.userId, notif.id, !notif.isRead);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                                    tooltip: 'Delete Log',
                                    onPressed: () async {
                                      await _notificationService.deleteNotification(notif.userId, notif.id);
                                    },
                                  ),
                                ],
                              ),
                              onTap: () async {
                                if (!notif.isRead) {
                                  await _notificationService.markAsRead(notif.userId, notif.id);
                                }
                                if (notif.actionRoute.isNotEmpty && notif.actionRoute != 'Dashboard') {
                                  widget.onNavigateTab(notif.actionRoute, notif.relatedId);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
