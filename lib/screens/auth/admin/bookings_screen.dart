import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../models/booking_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';

class BookingsView extends StatefulWidget {
  const BookingsView({super.key});

  @override
  State<BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends State<BookingsView> {
  final BookingService _bookingService = BookingService();
  final VehicleService _vehicleService = VehicleService();

  List<BookingModel> _bookings = [];
  List<VehicleModel> _vehicles = [];
  bool _loading = true;
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Ongoing', 'Completed', 'Cancelled', 'Overdue'
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  StreamSubscription<List<BookingModel>>? _bookingsSubscription;
  StreamSubscription<List<VehicleModel>>? _vehiclesSubscription;

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

    _vehiclesSubscription?.cancel();
    _vehiclesSubscription = _vehicleService.getVehiclesStream().listen((vList) {
      if (mounted) {
        setState(() {
          _vehicles = vList;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bookingsSubscription?.cancel();
    _vehiclesSubscription?.cancel();
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
    double pricePerDay = 100.0;
    try {
      pricePerDay = _vehicles.firstWhere((v) => v.id == booking.vehicleId).pricePerDay;
    } catch (_) {}
    final overdue = BookingService.getOverdueDetails(booking, pricePerDay);
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
                _buildDetailRow(
                  context,
                  'Rental Duration',
                  booking.isOpenRental
                      ? '${dateFormat.format(booking.pickUpDate)} to OPEN RENTAL (Open Ended)'
                      : '${dateFormat.format(booking.pickUpDate)} to ${booking.returnDate != null ? dateFormat.format(booking.returnDate!) : ""} (${booking.rentalDays} days)',
                ),
                _buildDetailRow(context, 'Deposit Lodged', 'RM ${booking.depositAmount.toStringAsFixed(2)}'),
                _buildDetailRow(
                  context,
                  booking.isOpenRental && booking.status.toLowerCase() == 'active' ? 'Current Estimated Cost' : 'Total Cost',
                  booking.isOpenRental && booking.status.toLowerCase() == 'active'
                      ? 'RM ${_getDynamicPrice(booking).toStringAsFixed(2)} (for ${_getElapsedDays(booking)} days)'
                      : 'RM ${booking.totalPrice.toStringAsFixed(2)}',
                ),
                if (overdue['isOverdue'] == true) ...[
                  _buildDetailRow(context, '⚠️ Overdue Duration', '${overdue['days']} days, ${overdue['hours']} hours', textColor: Colors.redAccent),
                  _buildDetailRow(context, '⚠️ Late Fees Accrued', 'RM ${overdue['charges'].toStringAsFixed(2)}', textColor: Colors.redAccent),
                  _buildDetailRow(context, '⚠️ Current Total', 'RM ${(booking.totalPrice + overdue['charges']).toStringAsFixed(2)}', textColor: Colors.redAccent),
                ],
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
                        child: Text(booking.isOpenRental ? 'Vehicle Picked Up' : 'Handover Keys (Active)'),
                      ),
                    ],
                    if (booking.status.toLowerCase() == 'return requested' ||
                        booking.status == 'ongoing' ||
                        booking.status.toLowerCase() == 'active' ||
                        booking.status.toLowerCase() == 'overdue') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _showReturnInspectionDialog(booking);
                        },
                        child: const Text('Inspect & Complete Return'),
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
                if (booking.extensionRequest != null &&
                    booking.extensionRequest!['status'] == 'pending') ...[
                  const Divider(height: 32),
                  Text('Extension Request Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                  const SizedBox(height: 8),
                  _buildDetailRow(context, 'Requested Return', DateFormat('dd MMM yyyy hh:mm a').format(DateTime.parse(booking.extensionRequest!['newReturnDate']))),
                  _buildDetailRow(context, 'Additional Cost', 'RM ${booking.extensionRequest!['additionalCost'].toStringAsFixed(2)}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () async {
                          Navigator.pop(context);
                          setState(() => _loading = true);
                          await _bookingService.approveExtension(booking.id);
                          _loadBookings();
                        },
                        child: const Text('Approve Extension'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          setState(() => _loading = true);
                          await _bookingService.rejectExtension(booking.id);
                          _loadBookings();
                        },
                        child: const Text('Reject Extension'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isItalic = false, Color? textColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = textColor ?? (isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue);
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
      return s == 'approved' || s == 'ongoing' || s == 'active' || s == 'overdue' || s == 'confirmed' || s == 'return requested';
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
      final matchesStatus = _selectedFilter == 'All' ||
          b.status.toLowerCase() == _selectedFilter.toLowerCase() ||
          (_selectedFilter == 'Ongoing' && (b.status.toLowerCase() == 'active' || b.status.toLowerCase() == 'ongoing' || b.status.toLowerCase() == 'return requested' || b.status.toLowerCase() == 'overdue'));
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
            DataCell(Text(
              b.isOpenRental
                  ? 'OPEN RENTAL'
                  : (b.returnDate != null ? dateFormat.format(b.returnDate!) : ""),
              style: TextStyle(
                color: b.isOpenRental ? Colors.green : textSecondary,
                fontWeight: b.isOpenRental ? FontWeight.bold : FontWeight.normal,
              ),
            )),
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
                if (bStat == 'return requested' || bStat == 'active' || bStat == 'ongoing' || bStat == 'overdue') ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showReturnInspectionDialog(b),
                    icon: const Icon(Icons.check_circle_outline, size: 12),
                    label: const Text('Inspect & Complete', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
                    Text(
                      b.isOpenRental
                          ? '${dateFormat.format(b.pickUpDate)} → OPEN RENTAL'
                          : '${dateFormat.format(b.pickUpDate)} → ${b.returnDate != null ? dateFormat.format(b.returnDate!) : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: b.isOpenRental ? Colors.green : textSecondary,
                        fontWeight: b.isOpenRental ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
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
              if (bStat == 'return requested' || bStat == 'active' || bStat == 'ongoing' || bStat == 'overdue')
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
                      onPressed: () => _showReturnInspectionDialog(b),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text('Inspect & Complete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  Future<void> _showReturnInspectionDialog(BookingModel booking) async {
    final mileageController = TextEditingController(text: '10000');
    final damageController = TextEditingController();
    final damageFeeController = TextEditingController(text: '0.00');
    final cleaningController = TextEditingController(text: '0.00');
    final extraController = TextEditingController(text: '0.00');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.secondaryBlue;

    try {
      final snap = await FirebaseDatabase.instance.ref().child('vehicles').child(booking.vehicleId).get();
      if (snap.exists) {
        final curMil = (snap.value as Map)['mileage']?.toString() ?? '10000';
        mileageController.text = curMil;
      }
    } catch (_) {}

    String selectedCondition = 'Excellent';
    String selectedFuel = 'Full (8/8)';

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Return Vehicle Inspection',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        content: StatefulBuilder(
          builder: (ctx2, setInnerState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCondition,
                  decoration: const InputDecoration(labelText: 'Vehicle Condition'),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: textColor),
                  items: ['Excellent', 'Good', 'Fair', 'Damaged'].map((c) {
                    return DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: textColor)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setInnerState(() => selectedCondition = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedFuel,
                  decoration: const InputDecoration(labelText: 'Fuel Level'),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: textColor),
                  items: ['Full (8/8)', '3/4', '1/2', '1/4', 'Empty'].map((f) {
                    return DropdownMenuItem(value: f, child: Text(f, style: TextStyle(color: textColor)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setInnerState(() => selectedFuel = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mileageController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(labelText: 'Current Mileage (km)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: damageController,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(labelText: 'Damage Notes / Description', hintText: 'Describe any new damages'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: damageFeeController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(labelText: 'Damage Fee (RM)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cleaningController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(labelText: 'Cleaning Fee (RM)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: extraController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(labelText: 'Extra Charges / Fees (RM)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete Return', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final double cleanFee = double.tryParse(cleaningController.text.trim()) ?? 0.0;
      final double damageFee = double.tryParse(damageFeeController.text.trim()) ?? 0.0;
      final double extraFee = double.tryParse(extraController.text.trim()) ?? 0.0;
      final int mil = int.tryParse(mileageController.text.trim()) ?? 0;

      final Map<String, dynamic> inspectionData = {
        'condition': selectedCondition,
        'fuelLevel': selectedFuel,
        'mileage': mil,
        'damageNotes': damageController.text.trim().isNotEmpty ? damageController.text.trim() : 'None',
        'damageFee': damageFee,
        'cleaningFee': cleanFee,
        'extraCharges': extraFee,
        'completedAt': DateTime.now().toIso8601String(),
      };

      setState(() => _loading = true);
      try {
        await _bookingService.completeReturn(booking.id, inspectionData);
        
        if (mil > 0) {
          await FirebaseDatabase.instance.ref().child('vehicles').child(booking.vehicleId).update({'mileage': mil});
        }

        _loadBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle returned and booking completed successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to complete return: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  int _getElapsedDays(BookingModel booking) {
    final pickup = booking.actualPickupTimestamp ?? booking.pickUpDate;
    final diff = DateTime.now().difference(pickup);
    final days = (diff.inHours / 24.0).ceil();
    return days <= 0 ? 1 : days;
  }

  double _getDynamicPrice(BookingModel booking) {
    if (!booking.isOpenRental || booking.status.toLowerCase() != 'active') {
      return booking.totalPrice;
    }
    final days = _getElapsedDays(booking);
    return days * booking.totalPrice;
  }
}
