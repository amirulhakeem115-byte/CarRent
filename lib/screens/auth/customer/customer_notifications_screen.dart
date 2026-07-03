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

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() => _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState extends State<CustomerNotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _searchQuery = '';
  String _selectedType = 'All';
  String _selectedStatus = 'All'; // All, Unread, Read

  final List<String> _typesList = [
    'All',
    'booking',
    'payment',
    'support',
    'reward',
    'general'
  ];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor => _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;
  Color get _borderColor => _isDark ? const Color(0xFF334155) : AppColors.borderGray;

  Stream<List<NotificationModel>>? _notificationsStream;

  @override
  void initState() {
    super.initState();
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _notificationsStream = _notificationService.getNotificationsStream(currentUser.uid);
    }
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
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingWidget(message: 'Syncing notifications...'));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load notifications: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final allNotifs = snapshot.data ?? [];
          final filteredNotifs = allNotifs.where((n) {
            // 1. Search filter
            final q = _searchQuery.toLowerCase().trim();
            final matchesSearch = q.isEmpty ||
                n.title.toLowerCase().contains(q) ||
                n.message.toLowerCase().contains(q);

            // 2. Category filter
            final matchesType = _selectedType == 'All' || n.type.toLowerCase() == _selectedType.toLowerCase();

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${filteredNotifs.length} alerts ($unreadCount unread)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _textColor),
                    ),
                    if (_searchQuery.isNotEmpty || _selectedType != 'All' || _selectedStatus != 'All')
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedType = 'All';
                            _selectedStatus = 'All';
                          });
                        },
                        child: const Text('Reset Filters', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                      ),
                  ],
                ),
              ),

              // Notifications List
              Expanded(
                child: filteredNotifs.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: filteredNotifs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
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
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: const EdgeInsets.all(16),
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
            style: TextStyle(color: _textColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search notifications...',
              hintStyle: TextStyle(color: _isDark ? Colors.white30 : Colors.grey, fontSize: 13),
              prefixIcon: Icon(Icons.search, size: 20, color: _subColor),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(color: _textColor, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: _subColor, fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                  items: _typesList.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t.substring(0, 1).toUpperCase() + t.substring(1), style: const TextStyle(fontSize: 12)),
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
                  style: TextStyle(color: _textColor, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: TextStyle(color: _subColor, fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Status', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Unread', child: Text('Unread', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Read', child: Text('Read', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (allNotifs.any((n) => !n.isRead))
                TextButton.icon(
                  onPressed: () async {
                    await _notificationService.markAllAsRead(userId);
                  },
                  icon: const Icon(Icons.done_all, size: 14, color: AppColors.primaryOrange),
                  label: const Text('Mark All Read', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              const SizedBox(width: 12),
              if (allNotifs.any((n) => n.isRead))
                TextButton.icon(
                  onPressed: () async {
                    await _notificationService.clearReadNotifications(userId);
                  },
                  icon: const Icon(Icons.delete_sweep_outlined, size: 14, color: Colors.redAccent),
                  label: const Text('Clear Read', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
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
          Icon(Icons.notifications_off_outlined, size: 64, color: _isDark ? const Color(0xFF334155) : Colors.grey[300]),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: parsedColor.withValues(alpha: 0.1),
            child: Text(notif.icon, style: const TextStyle(fontSize: 16)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  notif.title,
                  style: TextStyle(
                    fontWeight: notif.isRead ? FontWeight.bold : FontWeight.w900,
                    fontSize: 13,
                    color: _textColor,
                  ),
                ),
              ),
              Text(
                formattedDate,
                style: TextStyle(fontSize: 9, color: _subColor),
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
                    fontSize: 11,
                    height: 1.3,
                    color: notif.isRead ? _subColor : _textColor,
                  ),
                ),
                if (notif.type == 'pickup_reminder_customer') ...[
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
                        onPressed: () => _showBookingDetails(context, notif.relatedId),
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
                        onPressed: () => _sendOnMyWayStatus(notif.relatedId),
                        child: const Text("I'm On My Way", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
                if (notif.type == 'return_reminder_customer') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _sendOnMyWayStatus(notif.relatedId),
                        child: const Text("I'm On My Way", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: const BorderSide(color: AppColors.primaryOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _showExtendRentalGuidance(),
                        child: const Text("Extend Rental", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
                  notif.isRead ? Icons.mark_as_unread_outlined : Icons.mark_chat_read_outlined,
                  color: _subColor,
                  size: 16,
                ),
                onPressed: () async {
                  await _notificationService.toggleReadStatus(userId, notif.id, !notif.isRead);
                },
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: _subColor, size: 16),
                onPressed: () async {
                  await _notificationService.deleteNotification(userId, notif.id);
                },
              ),
            ],
          ),
          onTap: () => _handleNotificationTap(notif, userId),
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(NotificationModel notif, String userId) async {
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

  Future<void> _showBookingDetails(BuildContext context, String bookingId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
    );

    try {
      final snap = await FirebaseDatabase.instance.ref().child('bookings').child(bookingId).get();
      // Fetch payments
      final paySnap = await FirebaseDatabase.instance.ref().child('payments').orderByChild('bookingId').equalTo(bookingId).get();
      bool isPaid = false;
      if (paySnap.exists && paySnap.value != null) {
        final Map pMap = paySnap.value as Map;
        for (var pValue in pMap.values) {
          if (pValue is Map) {
            final pStatus = (pValue['paymentStatus'] ?? pValue['status'] ?? '').toString().toLowerCase();
            if (pStatus == 'approved' || pStatus == 'paid') {
              isPaid = true;
              break;
            }
          }
        }
      }

      if (context.mounted) Navigator.pop(context); // Close loading indicator

      if (snap.exists && snap.value != null) {
        final booking = BookingModel.fromMap(bookingId, snap.value as Map<dynamic, dynamic>);
        if (context.mounted) {
          _showBookingDetailsDialog(context, booking, isPaid: isPaid);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking record details no longer exist.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Safety pop
      debugPrint('Error fetching booking details: $e');
    }
  }

  Future<void> _showPaymentDetails(BuildContext context, String paymentId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
    );

    try {
      final snap = await FirebaseDatabase.instance.ref().child('payments').child(paymentId).get();
      if (context.mounted) Navigator.pop(context); // Close loading indicator

      if (snap.exists && snap.value != null) {
        final payment = PaymentModel.fromMap(paymentId, snap.value as Map<dynamic, dynamic>);
        if (context.mounted) {
          _showPaymentDetailsDialog(context, payment);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment transaction details no longer exist.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Safety pop
      debugPrint('Error fetching payment details: $e');
    }
  }

  void _showBookingDetailsDialog(BuildContext context, BookingModel booking, {bool isPaid = false}) {
    final dateFormat = DateFormat('dd MMM yyyy');
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Booking Specification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(booking.status.toUpperCase(), style: const TextStyle(color: AppColors.primaryOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Reservation Ref ID', booking.id),
              _buildDetailRow('Vehicle Name', booking.vehicleName),
              _buildDetailRow('Rental Days', '${booking.rentalDays} days'),
              _buildDetailRow('Rental Duration', '${dateFormat.format(booking.pickUpDate)} to ${dateFormat.format(booking.returnDate)}'),
              _buildDetailRow('Security Deposit', 'RM ${booking.depositAmount.toStringAsFixed(2)}'),
              _buildDetailRow('Total Price Paid', 'RM ${booking.totalPrice.toStringAsFixed(2)}'),
              if (booking.notes != null && booking.notes!.isNotEmpty)
                _buildDetailRow('Remarks', booking.notes!),
              if (isPaid) ...[
                const SizedBox(height: 16),
                Divider(color: _borderColor),
                const SizedBox(height: 12),
                Text('Receipt Documents', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          ReceiptService().viewReceipt(context, booking.id);
                        },
                        icon: const Icon(Icons.visibility, size: 14),
                        label: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDark ? const Color(0xFF0F172A) : AppColors.secondaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          ReceiptService().downloadReceipt(context, booking.id);
                        },
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text('Download', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Transaction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text((payment.paymentStatus ?? payment.status).toUpperCase(), style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Transaction ID', payment.id),
              _buildDetailRow('Booking Ref ID', payment.bookingId),
              _buildDetailRow('Paid Amount', 'RM ${payment.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Method Type', payment.paymentMethod.toUpperCase()),
              _buildDetailRow('Lodged At', dateFormat.format(payment.paymentDate)),
              if (payment.transactionId != null)
                _buildDetailRow('Reference Ref', payment.transactionId!),
              if (payment.rejectionReason != null && payment.rejectionReason!.isNotEmpty)
                _buildDetailRow('Rejection Reason', payment.rejectionReason!, isItalic: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: TextStyle(color: _subColor, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
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
      await FirebaseDatabase.instance.ref().child('bookings').child(bookingId).update({'customerStatus': 'on_my_way'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Status sent to admin: You are on your way!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send status: $e")),
        );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Extend Active Rental", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.secondaryBlue)),
          content: Text(
            "To request a rental contract extension, please contact CARENT Corporate Support directly at +60 3-2274 1234 or visit the nearest branch center.",
            style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
