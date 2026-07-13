import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../services/receipt_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor =>
      _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor =>
      _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;
  Color get _borderColor =>
      _isDark ? const Color(0xFF334155) : AppColors.borderGray;

  final AuthService _authService = AuthService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  late TabController _tabController;
  List<BookingModel> _bookings = [];
  List<BookingModel> _allUserBookings = [];
  List<PaymentModel> _payments = [];
  bool _loading = true;
  String? _error;
  String? _paymentsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _paymentsError = null;
    });
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      List<BookingModel> allUserBookings = [];
      List<PaymentModel> payments = [];
      String? bookingsError;
      String? paymentsError;

      try {
        allUserBookings = await _bookingService
            .getUserBookings(uid)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        bookingsError = _formatLoadErrorMessage(e);
      }

      try {
        payments = await _paymentService
            .getUserPayments(uid)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        paymentsError = _formatLoadErrorMessage(e);
      }

      if (mounted) {
        setState(() {
          _bookings = allUserBookings
              .where(
                (b) =>
                    b.status == 'Completed' ||
                    b.status == 'Cancelled' ||
                    b.status == 'cancelled',
              )
              .toList();
          _allUserBookings = allUserBookings;
          _payments = payments;
          _paymentsError = paymentsError;

          if (bookingsError != null && allUserBookings.isEmpty) {
            _error = bookingsError;
          }

          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatLoadErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  String _formatLoadErrorMessage(Object error) {
    final message = error.toString();
    final normalized = message.toLowerCase();

    if (normalized.contains('permission denied')) {
      return 'Access denied by Firebase rules for this data. Please ensure you are logged in with the correct account and that Realtime Database rules allow this user to read payment history.';
    }

    if (normalized.contains('not logged in')) {
      return 'You are not logged in. Please sign in again and retry.';
    }

    if (normalized.contains('timeout')) {
      return 'Request timed out. Please check your connection and try again.';
    }

    // Avoid rendering large native stack traces in UI.
    final firstLine = message.split('\n').first.trim();
    if (firstLine.isEmpty) {
      return 'Unable to load history data. Please try again.';
    }
    return firstLine;
  }

  Widget _buildLoadErrorView(String message) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 44, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'approved':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'refunded':
        return const Color(0xFF3B82F6);
      default:
        return AppColors.lightText;
    }
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _showReceiptOptions(BookingModel booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receipt Options',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Booking ID: #${booking.id.toUpperCase()}',
                style: TextStyle(fontSize: 11, color: _subColor),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.visibility, color: _textColor),
                title: Text(
                  'View Receipt',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ReceiptService().viewReceipt(context, booking.id);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.download,
                  color: AppColors.primaryOrange,
                ),
                title: Text(
                  'Download PDF',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ReceiptService().downloadReceipt(context, booking.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookingsList() {
    if (_bookings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: 'No Past Bookings',
        subtitle: 'Completed or cancelled bookings will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        final b = _bookings[index];
        final int days;
        if (b.isOpenRental) {
          if (b.actualReturnTimestamp != null &&
              b.actualPickupTimestamp != null) {
            final diff = b.actualReturnTimestamp!.difference(
              b.actualPickupTimestamp!,
            );
            final d = (diff.inHours / 24.0).ceil();
            days = d <= 0 ? 1 : d;
          } else {
            days = 1;
          }
        } else {
          days = b.returnDate != null
              ? b.returnDate!.difference(b.pickUpDate).inDays
              : 0;
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isDark
                            ? const Color(0xFF0F172A)
                            : AppColors.lightGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        color: _textColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.vehicleName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Booking #${b.id.substring(0, 8).toUpperCase()}',
                            style: TextStyle(fontSize: 11, color: _subColor),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(b.status),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: _borderColor),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _infoTile(
                        Icons.calendar_today_outlined,
                        'Pick Up',
                        DateFormat('dd MMM yyyy').format(b.pickUpDate),
                      ),
                    ),
                    Expanded(
                      child: _infoTile(
                        Icons.event_rounded,
                        'Return',
                        b.isOpenRental
                            ? 'Open Rental'
                            : (b.returnDate != null
                                  ? DateFormat(
                                      'dd MMM yyyy',
                                    ).format(b.returnDate!)
                                  : ""),
                      ),
                    ),
                    Expanded(
                      child: _infoTile(
                        Icons.timer_outlined,
                        'Duration',
                        '$days Day${days == 1 ? '' : 's'}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: _subColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'RM ${b.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                    Builder(
                      builder: (context) {
                        final paymentList = _payments
                            .where((p) => p.bookingId == b.id)
                            .toList();
                        final payment = paymentList.isNotEmpty
                            ? paymentList.first
                            : null;
                        final isPaid =
                            b.status.toLowerCase() == 'completed' ||
                            (payment != null &&
                                (payment.paymentStatus?.toLowerCase() ==
                                        'approved' ||
                                    payment.status.toLowerCase() ==
                                        'approved' ||
                                    payment.paymentStatus?.toLowerCase() ==
                                        'paid' ||
                                    payment.status.toLowerCase() == 'paid'));
                        if (isPaid) {
                          return OutlinedButton.icon(
                            onPressed: () => _showReceiptOptions(b),
                            icon: const Icon(
                              Icons.receipt_long_rounded,
                              size: 12,
                              color: AppColors.primaryOrange,
                            ),
                            label: const Text(
                              'Receipt',
                              style: TextStyle(
                                color: AppColors.primaryOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.primaryOrange,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openReceiptLightbox(PaymentModel payment) {
    if (payment.receiptImage == null || payment.receiptImage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No receipt file uploaded.')),
      );
      return;
    }
    final isPdf =
        payment.receiptImage!.toLowerCase().contains('.pdf') ||
        payment.receiptImage!.startsWith('data:application/pdf');

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.black54,
                elevation: 0,
                title: Text(
                  isPdf ? 'PDF Receipt' : 'Receipt Image',
                  style: const TextStyle(color: Colors.white),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.black87,
                  alignment: Alignment.center,
                  child: isPdf
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.redAccent,
                              size: 80,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'PDF Receipt Document Uploaded',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        )
                      : InteractiveViewer(
                          child: Image.memory(
                            base64Decode(payment.receiptImage!.split(',').last),
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentsList() {
    if (_paymentsError != null && _payments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Unable to Load Payments',
        subtitle: _paymentsError!,
      );
    }

    if (_payments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No Payment History',
        subtitle: 'Your payment transactions will appear here.',
      );
    }

    final bookingMap = {for (var b in _allUserBookings) b.id: b};

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final p = _payments[index];
        final statusStr = p.paymentStatus ?? p.status;
        final booking = bookingMap[p.bookingId];
        final vehicleName = booking?.vehicleName ?? 'Vehicle';
        final paymentTimeStr =
            p.paymentTime ?? DateFormat('HH:mm:ss').format(p.paymentDate);

        final isPdf =
            p.receiptImage != null &&
            (p.receiptImage!.toLowerCase().contains('.pdf') ||
                p.receiptImage!.startsWith('data:application/pdf'));

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primaryOrange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicleName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Booking Reference: #${p.bookingId.substring(0, p.bookingId.length > 8 ? 8 : p.bookingId.length).toUpperCase()}',
                            style: TextStyle(fontSize: 11, color: _subColor),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(statusStr),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: _borderColor),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoTile(
                            Icons.calendar_today_outlined,
                            'Date',
                            DateFormat('dd MMM yyyy').format(p.paymentDate),
                          ),
                          const SizedBox(height: 12),
                          _infoTile(
                            Icons.access_time_rounded,
                            'Time',
                            paymentTimeStr,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoTile(
                            Icons.payment_outlined,
                            'Method',
                            p.paymentMethod,
                          ),
                          const SizedBox(height: 12),
                          _infoTile(
                            Icons.fingerprint_rounded,
                            'Ref ID',
                            p.transactionId ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                    if (p.receiptImage != null && p.receiptImage!.isNotEmpty)
                      GestureDetector(
                        onTap: () => _openReceiptLightbox(p),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            border: Border.all(color: _borderColor),
                            borderRadius: BorderRadius.circular(12),
                            color: _isDark
                                ? const Color(0xFF0F172A)
                                : Colors.grey[50],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: isPdf
                                ? const Center(
                                    child: Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.redAccent,
                                      size: 28,
                                    ),
                                  )
                                : Image.memory(
                                    base64Decode(
                                      p.receiptImage!.split(',').last,
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) =>
                                        const Icon(
                                          Icons.receipt_long,
                                          size: 24,
                                        ),
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: _borderColor),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Amount',
                          style: TextStyle(
                            fontSize: 11,
                            color: _subColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'RM ${p.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                    if (p.receiptImage != null && p.receiptImage!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _openReceiptLightbox(p),
                        icon: const Icon(
                          Icons.receipt_rounded,
                          size: 12,
                          color: AppColors.primaryOrange,
                        ),
                        label: const Text(
                          'View Uploaded Receipt',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.primaryOrange,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                  ],
                ),
                if (p.rejectionReason != null && p.rejectionReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Reason: ${p.rejectionReason}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFEF4444),
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
        );
      },
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: _subColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: _subColor)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: _isDark ? const Color(0xFF334155) : AppColors.borderGray,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _subColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryOrange,
            unselectedLabelColor: _subColor,
            indicatorColor: AppColors.primaryOrange,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('Past Bookings'),
                    if (_bookings.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_bookings.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('Payments'),
                    if (_payments.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_payments.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryOrange,
                    strokeWidth: 2.5,
                  ),
                )
              : _error != null
              ? _buildLoadErrorView(_error!)
              : TabBarView(
                  controller: _tabController,
                  children: [_buildBookingsList(), _buildPaymentsList()],
                ),
        ),
      ],
    );
  }
}
