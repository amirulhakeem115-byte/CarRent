import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/booking_model.dart';
import '../../../services/booking_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';

class BookingsView extends StatefulWidget {
  const BookingsView({super.key});

  @override
  State<BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends State<BookingsView> {
  final BookingService _bookingService = BookingService();

  List<BookingModel> _bookings = [];
  bool _loading = true;
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Ongoing', 'Completed', 'Cancelled', 'Overdue'
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  StreamSubscription<List<BookingModel>>? _bookingsSubscription;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _subscribeToBookings();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _subscribeToBookings() {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = _bookingService.getBookingsStream().listen((bookingsList) {
      if (mounted) {
        setState(() {
          _bookings = bookingsList;
          _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _bookings = await _bookingService.getBookings().timeout(const Duration(seconds: 10));
      _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      setState(() {
        _error = 'Failed to load booking records. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateStatus(BookingModel booking, String status) async {
    await _bookingService.updateBookingStatus(
      booking.id,
      status,
      booking.userId,
      booking.vehicleId,
      booking.vehicleName,
    );
    _loadBookings();
  }

  void _showBookingDetails(BookingModel booking) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: sheetBg,
      builder: (context) {
        Color statusColor = Colors.orange;
        final bStat = booking.status.toLowerCase();
        if (bStat == 'approved') statusColor = Colors.green;
        if (bStat == 'ongoing' || bStat == 'active') statusColor = Colors.blue;
        if (bStat == 'completed') statusColor = Colors.indigo;
        if (bStat == 'cancelled' || bStat == 'rejected') statusColor = Colors.redAccent;
        if (bStat == 'overdue') statusColor = Colors.red;

        return Padding(
          padding: EdgeInsets.only(
            top: 24, left: 24, right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reservation Specification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(booking.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow(context, 'Reservation Ref ID', booking.id),
                _buildDetailRow(context, 'Vehicle Name', booking.vehicleName),
                _buildDetailRow(context, 'Customer Name', booking.userName),
                _buildDetailRow(context, 'Customer Phone', booking.userPhone),
                _buildDetailRow(context, 'Rental Duration', '${dateFormat.format(booking.pickUpDate)} to ${dateFormat.format(booking.returnDate)} (${booking.rentalDays} days)'),
                _buildDetailRow(context, 'Deposit Lodged', 'RM ${booking.depositAmount.toStringAsFixed(2)}'),
                _buildDetailRow(context, 'Total Cost', 'RM ${booking.totalPrice.toStringAsFixed(2)}'),
                if (booking.notes != null && booking.notes!.isNotEmpty)
                  _buildDetailRow(context, 'Special Remarks', booking.notes!, isItalic: true),
                const Divider(height: 32),
                Text('Transition Rental State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (booking.status == 'pending') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'approved');
                        },
                        child: const Text('Approve Reservation'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'rejected');
                        },
                        child: const Text('Reject & Deny'),
                      ),
                    ],
                    if (booking.status == 'approved' || booking.status == 'Confirmed' || booking.status == 'confirmed') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'active');
                        },
                        child: const Text('Handover Keys (Active)'),
                      ),
                    ],
                    if (booking.status == 'ongoing' || booking.status.toLowerCase() == 'active' || booking.status.toLowerCase() == 'overdue') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'completed');
                        },
                        child: const Text('Return Keys (Mark Completed)'),
                      ),
                    ],
                    if (booking.status != 'cancelled' && booking.status != 'completed' && booking.status != 'rejected') ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'cancelled');
                        },
                        child: const Text('Cancel Booking'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isItalic = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 7,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingWidget(message: 'Loading booking archives...'));
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
            ElevatedButton(onPressed: _loadBookings, child: const Text('Retry')),
          ],
        ),
      );
    }

    // Calculations
    final totalBookings = _bookings.length;
    final activeBookings = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return s == 'approved' || s == 'ongoing' || s == 'active' || s == 'overdue' || s == 'confirmed';
    }).length;
    final completedBookings = _bookings.where((b) => b.status.toLowerCase() == 'completed').length;
    final cancelledBookings = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return s == 'cancelled' || s == 'rejected';
    }).length;

    // Filtering
    final filteredBookings = _bookings.where((b) {
      final matchesSearch = b.id.toLowerCase().contains(_searchQuery) ||
          b.userName.toLowerCase().contains(_searchQuery) ||
          b.vehicleName.toLowerCase().contains(_searchQuery);
      final matchesStatus = _selectedFilter == 'All' || b.status.toLowerCase() == _selectedFilter.toLowerCase();
      return matchesSearch && matchesStatus;
    }).toList();

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1100;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reservation Registry', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary)),
              Text('Audit rental schedules, verify security deposits, and handover keys.', style: TextStyle(fontSize: 12, color: textSecondary)),
            ],
          ),
          const SizedBox(height: 24),

          GridView.count(
            crossAxisCount: isDesktop ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: isDesktop ? 2.2 : 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard('Total Bookings', totalBookings.toString(), Icons.book_online, Colors.indigo, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
              _buildStatCard('Active / Ongoing', activeBookings.toString(), Icons.directions_car, Colors.orange, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
              _buildStatCard('Completed Trips', completedBookings.toString(), Icons.done_all, Colors.green, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
              _buildStatCard('Cancelled / Denied', cancelledBookings.toString(), Icons.cancel_presentation_outlined, Colors.redAccent, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
            ],
          ),
          const SizedBox(height: 24),

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
                            hintText: 'Search by booking ID, vehicle model, or customer name...',
                            hintStyle: TextStyle(color: textSecondary),
                            prefixIcon: Icon(Icons.search, size: 20, color: textSecondary),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildStatusFilterDropdown(isDark: isDark, cardColor: surfaceColor, textPrimary: textPrimary, borderColor: borderColor),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by booking ID, vehicle or customer...',
                          hintStyle: TextStyle(color: textSecondary),
                          prefixIcon: Icon(Icons.search, size: 20, color: textSecondary),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatusFilterDropdown(isDark: isDark, cardColor: surfaceColor, textPrimary: textPrimary, borderColor: borderColor),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // List / Table view
          filteredBookings.isEmpty
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
                        Icon(Icons.calendar_today_outlined, size: 64, color: textSecondary),
                        const SizedBox(height: 16),
                        Text('No reservations found matching search queries.', style: TextStyle(color: textSecondary)),
                      ],
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: isDesktop
                      ? _buildDesktopTable(filteredBookings, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary)
                      : _buildMobileList(filteredBookings, isDark: isDark, cardColor: cardColor, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {
    required bool isDark, required Color cardColor, required Color textPrimary, required Color textSecondary, required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<BookingModel> bookings, {required bool isDark, required Color textPrimary, required Color textSecondary}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        dividerThickness: 1,
        columns: [
          DataColumn(label: Text('Booking ID', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Pickup Date', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Return Date', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Amount (RM)', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary))),
        ],
        rows: bookings.map((b) {
          Color statusColor = Colors.orange;
          final bStat = b.status.toLowerCase();
          if (bStat == 'approved') statusColor = Colors.green;
          if (bStat == 'ongoing' || bStat == 'active') statusColor = Colors.blue;
          if (bStat == 'completed') statusColor = Colors.indigo;
          if (bStat == 'cancelled' || bStat == 'rejected') statusColor = Colors.redAccent;
          if (bStat == 'overdue') statusColor = Colors.red;
          final dateFormat = DateFormat('yyyy-MM-dd');
          return DataRow(cells: [
            DataCell(Text(b.id.substring(0, b.id.length > 8 ? 8 : b.id.length), style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary))),
            DataCell(Text(b.userName, style: TextStyle(color: textPrimary))),
            DataCell(Text(b.vehicleName, style: TextStyle(color: textPrimary))),
            DataCell(Text(dateFormat.format(b.pickUpDate), style: TextStyle(color: textSecondary))),
            DataCell(Text(dateFormat.format(b.returnDate), style: TextStyle(color: textSecondary))),
            DataCell(Text('RM ${b.totalPrice.toStringAsFixed(2)}', style: TextStyle(color: textPrimary))),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(b.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.visibility_outlined, color: textPrimary, size: 18),
                  onPressed: () => _showBookingDetails(b),
                ),
                if (bStat == 'active' || bStat == 'ongoing' || bStat == 'overdue') ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _confirmCompleteBooking(b),
                    icon: const Icon(Icons.check_circle_outline, size: 12),
                    label: const Text('Complete Booking', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildMobileList(List<BookingModel> bookings, {required bool isDark, required Color cardColor, required Color textPrimary, required Color textSecondary, required Color borderColor}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        Color statusColor = Colors.orange;
        final bStat = b.status.toLowerCase();
        if (bStat == 'approved') statusColor = Colors.green;
        if (bStat == 'ongoing' || bStat == 'active') statusColor = Colors.blue;
        if (bStat == 'completed') statusColor = Colors.indigo;
        if (bStat == 'cancelled' || bStat == 'rejected') statusColor = Colors.redAccent;
        if (bStat == 'overdue') statusColor = Colors.red;
        final dateFormat = DateFormat('yyyy-MM-dd');
        return Card(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8F9FA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              ListTile(
                title: Text(b.vehicleName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Customer: ${b.userName}', style: TextStyle(fontSize: 12, color: textSecondary)),
                    Text('${dateFormat.format(b.pickUpDate)} → ${dateFormat.format(b.returnDate)}', style: TextStyle(fontSize: 12, color: textSecondary)),
                    Text('RM ${b.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(b.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                onTap: () => _showBookingDetails(b),
              ),
              if (bStat == 'active' || bStat == 'ongoing' || bStat == 'overdue')
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _confirmCompleteBooking(b),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text('Complete Booking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusFilterDropdown({required bool isDark, required Color cardColor, required Color textPrimary, required Color borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButton<String>(
        value: _selectedFilter,
        underline: const SizedBox(),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
        items: ['All', 'Pending', 'Approved', 'Ongoing', 'Completed', 'Cancelled', 'Overdue'].map((s) {
          return DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: textPrimary, fontSize: 13)));
        }).toList(),
        onChanged: (val) {
          if (val != null) setState(() => _selectedFilter = val);
        },
      ),
    );
  }

  Future<void> _confirmCompleteBooking(BookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Complete Booking',
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.secondaryBlue),
          ),
          content: Text(
            'Are you sure the customer has returned the vehicle?',
            style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Complete Booking', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _bookingService.updateBookingStatus(
        booking.id,
        'completed',
        booking.userId,
        booking.vehicleId,
        booking.vehicleName,
      );
      _loadBookings();
    }
  }
}
