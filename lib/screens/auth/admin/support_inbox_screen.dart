import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../services/database_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../models/user_model.dart';
import '../../../widgets/animated_widgets.dart';

class SupportInboxView extends StatefulWidget {
  const SupportInboxView({super.key});

  @override
  State<SupportInboxView> createState() => _SupportInboxViewState();
}

class _SupportInboxViewState extends State<SupportInboxView> {
  final DatabaseService _databaseService = DatabaseService();

  List<UserModel> _users = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'All'; // 'All', 'Open', 'In Progress', 'Closed'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _users = await _databaseService.getUsers().timeout(
        const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Error loading users for support: $e');
      setState(() {
        _error = 'Failed to load user records. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateStatus(String ticketId, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _databaseService.updateTicketStatus(ticketId, newStatus);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ticket status updated to $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _sendReply(String ticketId, String replyText) async {
    if (replyText.trim().isEmpty) return;
    try {
      await _databaseService.sendTicketMessage(
        ticketId,
        replyText.trim(),
        'admin',
      );
    } catch (e) {
      debugPrint('Failed to send support reply: $e');
    }
  }

  void _showTicketDetails(Map<String, dynamic> ticket) {
    final String id = ticket['id'] ?? '';
    final String subject = ticket['subject'] ?? 'No Subject';
    final String customerId = (ticket['customerId'] ?? ticket['userId'] ?? ticket['customerUid'] ?? '').toString();
    final bool isLegacyTicket = customerId.trim().isEmpty;
    final replyController = TextEditingController();
    final scrollController = ScrollController();

    UserModel? customer;
    try {
      customer = _users.firstWhere((u) => u.id == ticket['customerId']);
    } catch (_) {}
    final String name = customer?.fullName ?? ticket['customerName'] ?? 'Customer';
    final String email = customer?.email ?? 'No Email';

    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _databaseService.getTicketsStream(),
              builder: (context, snap) {
                String status = ticket['status'] ?? 'Open';
                if (snap.hasData) {
                  try {
                    final currentTicket = snap.data!.firstWhere(
                      (t) => t['id'] == id,
                    );
                    status = currentTicket['status'] ?? 'Open';
                  } catch (_) {}
                }
                Color statusColor = Colors.orange;
                if (status.toLowerCase() == 'pending' ||
                    status.toLowerCase() == 'in progress') {
                  statusColor = Colors.blue;
                }
                if (status.toLowerCase() == 'closed') {
                  statusColor = Colors.green;
                }

                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'Support Ticket Specs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondaryBlue,
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
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: MediaQuery.of(context).size.height * 0.7,
                    constraints: const BoxConstraints(
                      maxWidth: 600,
                      maxHeight: 500,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ticket ID: $id',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'From: $name ($email)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.secondaryBlue,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Subject: $subject',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primaryOrange,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isLegacyTicket) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade700),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This support ticket was created using an older version of the system.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Divider(height: 20),

                        // Reply History section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Conversation History',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.secondaryBlue,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Live Real-time Sync',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _databaseService.getTicketMessagesStream(
                              id,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryOrange,
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(
                                      'Error loading messages: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                    ),
                                  ),
                                );
                              }
                              final messages = snapshot.data ?? [];
                              if (messages.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No replies yet.',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              }
                              scrollToBottom();
                              return ListView.builder(
                                controller: scrollController,
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final r = messages[index];
                                  final bool isAdmin =
                                      r['senderRole'] == 'admin';
                                  final String senderName = r['senderName'] ??
                                      (isAdmin ? 'Support Admin' : name);
                                  final String senderRole = (r['senderRole'] ?? 'customer').toUpperCase();
                                  final String rTime = r['timestamp'] ?? '';
                                  String fRTime = '';
                                  if (rTime.isNotEmpty) {
                                    try {
                                      fRTime = DateFormat(
                                        'hh:mm a',
                                      ).format(DateTime.parse(rTime));
                                    } catch (_) {
                                      fRTime = rTime;
                                    }
                                  }

                                  return Align(
                                    alignment: isAdmin
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      constraints: const BoxConstraints(maxWidth: 380),
                                      decoration: BoxDecoration(
                                        color: isAdmin
                                            ? AppColors.secondaryBlue
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(14),
                                          topRight: const Radius.circular(14),
                                          bottomLeft: isAdmin
                                              ? const Radius.circular(14)
                                              : Radius.zero,
                                          bottomRight: isAdmin
                                              ? Radius.zero
                                              : const Radius.circular(14),
                                        ),
                                        border: isAdmin
                                            ? null
                                            : Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.03),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isAdmin
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                senderName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                  color: isAdmin
                                                      ? AppColors.primaryOrange
                                                      : AppColors.secondaryBlue,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 1,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isAdmin
                                                      ? AppColors.primaryOrange.withValues(alpha: 0.2)
                                                      : AppColors.secondaryBlue.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  senderRole,
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                    color: isAdmin
                                                        ? AppColors.primaryOrange
                                                        : AppColors.secondaryBlue,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            r['message'] ?? '',
                                            style: TextStyle(
                                              color: isAdmin
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 13,
                                              height: 1.35,
                                            ),
                                          ),
                                          if (fRTime.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              fRTime,
                                              style: TextStyle(
                                                color: isAdmin
                                                    ? Colors.white70
                                                    : Colors.grey[600],
                                                fontSize: 9,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quick reply composer
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: replyController,
                                decoration: const InputDecoration(
                                  hintText: 'Type reply message...',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (val) async {
                                  final text = val.trim();
                                  if (text.isEmpty) return;
                                  replyController.clear();
                                  await _sendReply(id, text);
                                  scrollToBottom();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: AppColors.primaryOrange,
                              ),
                              onPressed: () async {
                                final text = replyController.text.trim();
                                if (text.isEmpty) return;
                                replyController.clear();
                                await _sendReply(id, text);
                                scrollToBottom();
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Status transitions dropdown
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            const Text(
                              'Modify Ticket Status:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondaryBlue,
                              ),
                            ),
                            DropdownButton<String>(
                              value:
                                  [
                                    'Open',
                                    'In Progress',
                                    'Closed',
                                  ].contains(status)
                                  ? status
                                  : 'Open',
                              underline: const SizedBox(),
                              items: ['Open', 'In Progress', 'Closed'].map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null && val != status) {
                                  _updateStatus(id, val);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        scrollController.dispose();
                        replyController.dispose();
                        Navigator.pop(context);
                      },
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: LoadingWidget(message: 'Loading support ticket systems...'),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.secondaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Retry Loading'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _databaseService.getTicketsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: LoadingWidget(message: 'Connecting to live ticket stream...'),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading tickets: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final tickets = snapshot.data ?? [];

        // Calculations
        final totalTickets = tickets.length;
        final openTickets = tickets
            .where(
              (m) => (m['status'] ?? 'Open').toString().toLowerCase() == 'open',
            )
            .length;
        final inProgressTickets = tickets.where((m) {
          final s = (m['status'] ?? '').toString().toLowerCase();
          return s == 'pending' || s == 'in progress';
        }).length;
        final closedTickets = tickets
            .where(
              (m) => (m['status'] ?? '').toString().toLowerCase() == 'closed',
            )
            .length;

        // Filters application
        final filteredTickets = tickets.where((msg) {
          UserModel? cust;
          try {
            cust = _users.firstWhere((u) => u.id == msg['customerId']);
          } catch (_) {}
          final String name = (cust?.fullName != null && cust!.fullName.isNotEmpty)
              ? cust.fullName
              : (msg['customerName'] ?? 'Customer').toString();
          final String email = (cust?.email != null && cust!.email.isNotEmpty)
              ? cust.email
              : (msg['customerEmail'] ?? '').toString();

          final String subject = (msg['subject'] ?? '').toString();
          final String id = (msg['id'] ?? '').toString();

          final matchesSearch = _searchQuery.isEmpty ||
              name.toLowerCase().contains(_searchQuery) ||
              email.toLowerCase().contains(_searchQuery) ||
              subject.toLowerCase().contains(_searchQuery) ||
              id.toLowerCase().contains(_searchQuery);

          final String status = (msg['status'] ?? 'Open').toString();
          final matchesFilter =
              _selectedFilter == 'All' ||
              status.toLowerCase() == _selectedFilter.toLowerCase() ||
              (_selectedFilter.toLowerCase() == 'in progress' && status.toLowerCase() == 'pending');

          return matchesSearch && matchesFilter;
        }).toList();

        final double width = MediaQuery.of(context).size.width;
        final bool isDesktop = width > 1100;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final surfaceColor = isDark
            ? const Color(0xFF111827)
            : const Color(0xFFF1F5F9);
        final textPrimary = isDark
            ? const Color(0xFFF8FAFC)
            : AppColors.secondaryBlue;
        final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
        final borderColor = isDark
            ? const Color(0xFF334155)
            : Colors.grey.shade200;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title Row
              isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Support Desk Inbox',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              'Respond to customer tickets, coordinate inquiries, and close resolved issues.',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: textPrimary),
                          onPressed: _loadUsers,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Support Desk Inbox',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh, color: textPrimary),
                              onPressed: _loadUsers,
                            ),
                          ],
                        ),
                        Text(
                          'Respond to customer tickets, coordinate inquiries, and close resolved issues.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
              const SizedBox(height: 24),

              // Statistics Grid
              GridView.count(
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                childAspectRatio: isDesktop ? 2.2 : 1.28,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard(
                    'Total Tickets Received',
                    totalTickets.toString(),
                    Icons.mark_as_unread,
                    Colors.indigo,
                    isDark: isDark,
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                  _buildStatCard(
                    'Open Tickets',
                    openTickets.toString(),
                    Icons.hourglass_top,
                    Colors.orange,
                    isDark: isDark,
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                  _buildStatCard(
                    'In Progress Tickets',
                    inProgressTickets.toString(),
                    Icons.chat_bubble_outline,
                    Colors.blue,
                    isDark: isDark,
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                  _buildStatCard(
                    'Closed Tickets',
                    closedTickets.toString(),
                    Icons.check_circle_outline,
                    Colors.green,
                    isDark: isDark,
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    borderColor: borderColor,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filters Card
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(16),
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: textPrimary),
                              decoration: InputDecoration(
                                hintText:
                                    'Search tickets by customer name, email, subject, or ticket ID...',
                                hintStyle: TextStyle(color: textSecondary),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 20,
                                  color: textSecondary,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedFilter,
                              underline: const SizedBox(),
                              dropdownColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              items: ['All', 'Open', 'In Progress', 'Closed']
                                  .map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    );
                                  })
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedFilter = val);
                                }
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _searchController,
                            style: TextStyle(color: textPrimary),
                            decoration: InputDecoration(
                              hintText:
                                  'Search tickets by name, email, subject or ID...',
                              hintStyle: TextStyle(color: textSecondary),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 20,
                                color: textSecondary,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedFilter,
                              underline: const SizedBox(),
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              items: ['All', 'Open', 'In Progress', 'Closed']
                                  .map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    );
                                  })
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedFilter = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // List / Table
              filteredTickets.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: const AnimatedEmptyState(
                        icon: Icons.mail_outline_rounded,
                        title: 'No Support Tickets Found',
                        subtitle:
                            'No tickets match your search query or status filter.',
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: isDesktop
                          ? _buildDesktopTable(
                              filteredTickets,
                              isDark: isDark,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            )
                          : _buildMobileList(
                              filteredTickets,
                              isDark: isDark,
                              cardColor: cardColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              borderColor: borderColor,
                            ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool isCompactMobile = MediaQuery.of(context).size.width <= 600;

    return Container(
      padding: EdgeInsets.all(isCompactMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompactMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isCompactMobile ? 20 : 22),
          ),
          SizedBox(width: isCompactMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: isCompactMobile ? 9 : 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isCompactMobile ? 2 : 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isCompactMobile ? 14 : 15,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(
    List<Map<String, dynamic>> ticketsList, {
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        ),
        dividerThickness: 1,
        columns: [
          DataColumn(
            label: Text(
              'Ticket ID',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Customer',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Subject',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Created Date',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Last Reply Date',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Action',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
        ],
        rows: ticketsList.map((ticket) {
          final String id = ticket['id'] ?? '';
          final String subject = ticket['subject'] ?? 'No Subject';
          final String status = ticket['status'] ?? 'Open';
          final String createdRaw = ticket['createdAt'] ?? '';
          final String replyRaw = ticket['lastReplyAt'] ?? '';

          UserModel? cust;
          try {
            cust = _users.firstWhere((u) => u.id == ticket['customerId']);
          } catch (_) {}
          final String name = (cust?.fullName != null && cust!.fullName.isNotEmpty)
              ? cust.fullName
              : (ticket['customerName'] ?? 'Customer').toString();
          final String email = (cust?.email != null && cust!.email.isNotEmpty)
              ? cust.email
              : (ticket['customerEmail'] ?? 'No Email').toString();

          String createdStr = '';
          if (createdRaw.isNotEmpty) {
            try {
              createdStr = DateFormat(
                'yyyy-MM-dd HH:mm',
              ).format(DateTime.parse(createdRaw));
            } catch (_) {}
          }
          String replyStr = '';
          if (replyRaw.isNotEmpty) {
            try {
              replyStr = DateFormat(
                'yyyy-MM-dd HH:mm',
              ).format(DateTime.parse(replyRaw));
            } catch (_) {}
          }

          Color statusColor = Colors.orange;
          if (status.toLowerCase() == 'pending' ||
              status.toLowerCase() == 'in progress') {
            statusColor = Colors.blue;
          }
          if (status.toLowerCase() == 'closed') {
            statusColor = Colors.green;
          }

          final bool isUnread = (status.toLowerCase() == 'open');

          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUnread) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 10,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textPrimary),
                ),
              ),
              DataCell(
                Text(createdStr.isNotEmpty ? createdStr : 'N/A', style: TextStyle(color: textSecondary, fontSize: 11)),
              ),
              DataCell(
                Text(
                  replyStr.isNotEmpty ? replyStr : 'N/A',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              DataCell(
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: textPrimary,
                    size: 18,
                  ),
                  onPressed: () => _showTicketDetails(ticket),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileList(
    List<Map<String, dynamic>> ticketsList, {
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ticketsList.length,
      itemBuilder: (context, index) {
        final ticket = ticketsList[index];
        final String id = ticket['id'] ?? '';
        final String subject = ticket['subject'] ?? 'No Subject';
        final String status = ticket['status'] ?? 'Open';
        final String createdRaw = ticket['createdAt'] ?? '';
        final String replyRaw = ticket['lastReplyAt'] ?? '';

        UserModel? cust;
        try {
          cust = _users.firstWhere((u) => u.id == ticket['customerId']);
        } catch (_) {}
        final String name = (cust?.fullName != null && cust!.fullName.isNotEmpty)
            ? cust.fullName
            : (ticket['customerName'] ?? 'Customer').toString();
        final String email = (cust?.email != null && cust!.email.isNotEmpty)
            ? cust.email
            : (ticket['customerEmail'] ?? 'No Email').toString();

        String createdStr = '';
        if (createdRaw.isNotEmpty) {
          try {
            createdStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(createdRaw));
          } catch (_) {}
        }
        String replyStr = '';
        if (replyRaw.isNotEmpty) {
          try {
            replyStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(replyRaw));
          } catch (_) {}
        }

        Color statusColor = Colors.orange;
        if (status.toLowerCase() == 'pending' ||
            status.toLowerCase() == 'in progress') {
          statusColor = Colors.blue;
        }
        if (status.toLowerCase() == 'closed') {
          statusColor = Colors.green;
        }

        final bool isUnread = (status.toLowerCase() == 'open');

        return ListTile(
          leading: isUnread
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          title: Text(
            subject,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'From: $name ($email)',
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
              Text(
                'ID: #${id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase()} | Created: $createdStr',
                style: TextStyle(fontSize: 10, color: textSecondary),
              ),
              Text(
                'Last Active: ${replyStr.isNotEmpty ? replyStr : "N/A"}',
                style: TextStyle(fontSize: 10, color: textSecondary),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () => _showTicketDetails(ticket),
        );
      },
    );
  }
}
