import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../services/database_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../models/user_model.dart';

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
  String _selectedFilter = 'All'; // 'All', 'Open', 'Pending', 'Closed'
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
      _users = await _databaseService.getUsers().timeout(const Duration(seconds: 10));
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
        SnackBar(content: Text('Ticket status updated to $newStatus'), backgroundColor: Colors.green),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _sendReply(String ticketId, String replyText) async {
    if (replyText.trim().isEmpty) return;
    try {
      await _databaseService.sendTicketMessage(ticketId, replyText.trim(), 'admin');
    } catch (e) {
      debugPrint('Failed to send support reply: $e');
    }
  }


  void _showTicketDetails(Map<String, dynamic> ticket) {
    final String id = ticket['id'] ?? '';
    final String subject = ticket['subject'] ?? 'No Subject';
    final replyController = TextEditingController();

    UserModel? customer;
    try {
      customer = _users.firstWhere((u) => u.id == ticket['customerId']);
    } catch (_) {}
    final String name = customer?.fullName ?? 'Anonymous';
    final String email = customer?.email ?? 'No Email';

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
                    final currentTicket = snap.data!.firstWhere((t) => t['id'] == id);
                    status = currentTicket['status'] ?? 'Open';
                  } catch (_) {}
                }
                Color statusColor = Colors.orange;
                if (status.toLowerCase() == 'pending') statusColor = Colors.blue;
                if (status.toLowerCase() == 'closed') statusColor = Colors.green;

                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Support Ticket Specs', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: 600,
                    height: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ticket ID: $id', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 12),
                        Text('From: $name ($email)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryBlue)),
                        Text('Subject: $subject', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryOrange)),
                        const Divider(height: 20),
                        
                        // Reply History section
                        const Text('Conversation History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondaryBlue)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _databaseService.getTicketMessagesStream(id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
                              }
                              final messages = snapshot.data ?? [];
                              if (messages.isEmpty) {
                                return Center(child: Text('No replies yet.', style: TextStyle(color: Colors.grey[400], fontSize: 11)));
                              }
                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final r = messages[index];
                                  final bool isAdmin = r['senderRole'] == 'admin';
                                  final String rTime = r['timestamp'] ?? '';
                                  String fRTime = '';
                                  if (rTime.isNotEmpty) {
                                    try {
                                      fRTime = DateFormat('hh:mm a').format(DateTime.parse(rTime));
                                    } catch (_) {}
                                  }

                                  return Align(
                                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isAdmin ? AppColors.secondaryBlue : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(12),
                                          topRight: const Radius.circular(12),
                                          bottomLeft: isAdmin ? const Radius.circular(12) : Radius.zero,
                                          bottomRight: isAdmin ? Radius.zero : const Radius.circular(12),
                                        ),
                                        border: isAdmin ? null : Border.all(color: Colors.grey[200]!),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            r['message'] ?? '',
                                            style: TextStyle(color: isAdmin ? Colors.white : Colors.black, fontSize: 12),
                                          ),
                                          if (fRTime.isNotEmpty)
                                            Text(
                                              fRTime,
                                              style: TextStyle(color: isAdmin ? Colors.white60 : Colors.grey, fontSize: 8),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
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
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send, color: AppColors.primaryOrange),
                              onPressed: () async {
                                final text = replyController.text.trim();
                                if (text.isEmpty) return;
                                await _sendReply(id, text);
                                replyController.clear();
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        
                        // Status transitions dropdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Modify Ticket Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                            DropdownButton<String>(
                              value: ['Open', 'Pending', 'Closed'].contains(status) ? status : 'Open',
                              underline: const SizedBox(),
                              items: ['Open', 'Pending', 'Closed'].map((s) {
                                return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
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
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                );
              }
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingWidget(message: 'Loading support ticket systems...'));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16, color: AppColors.secondaryBlue, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadUsers, child: const Text('Retry Loading')),
          ],
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _databaseService.getTicketsStream(),
      builder: (context, snapshot) {
        final tickets = snapshot.data ?? [];

        // Calculations
        final totalTickets = tickets.length;
        final openTickets = tickets.where((m) => (m['status'] ?? 'Open').toString().toLowerCase() == 'open').length;
        final pendingTickets = tickets.where((m) => (m['status'] ?? '').toString().toLowerCase() == 'pending').length;
        final closedTickets = tickets.where((m) => (m['status'] ?? '').toString().toLowerCase() == 'closed').length;

        // Filters application
        final filteredTickets = tickets.where((msg) {
          UserModel? cust;
          try {
            cust = _users.firstWhere((u) => u.id == msg['customerId']);
          } catch (_) {}
          final name = cust?.fullName ?? '';
          final email = cust?.email ?? '';

          final matchesSearch = name.toLowerCase().contains(_searchQuery) ||
              email.toLowerCase().contains(_searchQuery) ||
              (msg['subject'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
              (msg['id'] ?? '').toString().toLowerCase().contains(_searchQuery);
          
          final String status = msg['status'] ?? 'Open';
          final matchesFilter = _selectedFilter == 'All' || status.toLowerCase() == _selectedFilter.toLowerCase();
          
          return matchesSearch && matchesFilter;
        }).toList();

        final double width = MediaQuery.of(context).size.width;
        final bool isDesktop = width > 1100;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Support Desk Inbox', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue)),
                      Text('Respond to customer tickets, coordinate technical inquiries, and close resolved issues.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.secondaryBlue),
                    onPressed: _loadUsers,
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
                childAspectRatio: isDesktop ? 2.2 : 1.5,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard('Total Tickets Received', totalTickets.toString(), Icons.mark_as_unread, Colors.indigo),
                  _buildStatCard('Open Tickets', openTickets.toString(), Icons.hourglass_top, Colors.orange),
                  _buildStatCard('Pending Tickets', pendingTickets.toString(), Icons.chat_bubble_outline, Colors.blue),
                  _buildStatCard('Closed Tickets', closedTickets.toString(), Icons.check_circle_outline, Colors.green),
                ],
              ),
              const SizedBox(height: 24),

              // Filters Card
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search tickets by customer name, email, subject, or ticket ID...',
                            prefixIcon: Icon(Icons.search, size: 20),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedFilter,
                          underline: const SizedBox(),
                          items: ['All', 'Open', 'Pending', 'Closed'].map((s) {
                            return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedFilter = val;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // List Grid container
              Expanded(
                child: filteredTickets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mail_outline_rounded, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No support tickets found matching search query.', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        child: isDesktop ? _buildDesktopTable(filteredTickets) : _buildMobileList(filteredTickets),
                      ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> ticketsList) {
    return ListView(
      children: [
        DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('Ticket ID', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Created Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Last Reply Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
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
            final String name = cust?.fullName ?? 'Anonymous';

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
            if (status.toLowerCase() == 'pending') statusColor = Colors.blue;
            if (status.toLowerCase() == 'closed') statusColor = Colors.green;

            return DataRow(
              cells: [
                DataCell(Text(id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(name)),
                DataCell(Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text(createdStr)),
                DataCell(Text(replyStr.isNotEmpty ? replyStr : 'N/A')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: AppColors.secondaryBlue, size: 18),
                    onPressed: () => _showTicketDetails(ticket),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> ticketsList) {
    return ListView.builder(
      itemCount: ticketsList.length,
      itemBuilder: (context, index) {
        final ticket = ticketsList[index];
        final String subject = ticket['subject'] ?? 'No Subject';
        final String status = ticket['status'] ?? 'Open';
        final String replyRaw = ticket['lastReplyAt'] ?? '';
        
        UserModel? cust;
        try {
          cust = _users.firstWhere((u) => u.id == ticket['customerId']);
        } catch (_) {}
        final String name = cust?.fullName ?? 'Anonymous';

        String replyStr = '';
        if (replyRaw.isNotEmpty) {
          try {
            replyStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(replyRaw));
          } catch (_) {}
        }

        Color statusColor = Colors.orange;
        if (status.toLowerCase() == 'pending') statusColor = Colors.blue;
        if (status.toLowerCase() == 'closed') statusColor = Colors.green;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
          elevation: 0,
          child: ListTile(
            title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From: $name', style: const TextStyle(fontSize: 12)),
                Text('Last Active: $replyStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
            onTap: () => _showTicketDetails(ticket),
          ),
        );
      },
    );
  }
}

