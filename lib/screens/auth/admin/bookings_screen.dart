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
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Ongoing', 'Completed', 'Cancelled'
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBookings();
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (context) {
        Color statusColor = Colors.orange;
        if (booking.status == 'approved') statusColor = Colors.green;
        if (booking.status == 'ongoing') statusColor = Colors.blue;
        if (booking.status == 'completed') statusColor = Colors.indigo;
        if (booking.status == 'cancelled' || booking.status == 'rejected') statusColor = Colors.redAccent;

        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
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
                    const Text('Reservation Specification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
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
                
                _buildDetailRow('Reservation Ref ID', booking.id),
                _buildDetailRow('Vehicle Name', booking.vehicleName),
                _buildDetailRow('Customer Name', booking.userName),
                _buildDetailRow('Customer Phone', booking.userPhone),
                _buildDetailRow('Rental Duration', '${dateFormat.format(booking.pickUpDate)} to ${dateFormat.format(booking.returnDate)} (${booking.rentalDays} days)'),
                _buildDetailRow('Deposit Lodged', 'RM ${booking.depositAmount.toStringAsFixed(2)}'),
                _buildDetailRow('Total Cost', 'RM ${booking.totalPrice.toStringAsFixed(2)}'),
                if (booking.notes != null && booking.notes!.isNotEmpty)
                  _buildDetailRow('Special Remarks', booking.notes!, isItalic: true),
                  
                const Divider(height: 32),
                const Text('Transition Rental State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryBlue)),
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
                    if (booking.status == 'approved') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'ongoing');
                        },
                        child: const Text('Handover Keys (Ongoing)'),
                      ),
                    ],
                    if (booking.status == 'ongoing') ...[
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

  Widget _buildDetailRow(String label, String value, {bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 7,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                color: AppColors.secondaryBlue,
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
    final activeBookings = _bookings.where((b) => b.status == 'approved' || b.status == 'ongoing').length;
    final completedBookings = _bookings.where((b) => b.status == 'completed').length;
    final cancelledBookings = _bookings.where((b) => b.status == 'cancelled' || b.status == 'rejected').length;

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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reservation Registry', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue)),
              Text('Audit rental schedules, verify security deposits, and handover keys.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
              _buildStatCard('Total Bookings', totalBookings.toString(), Icons.book_online, Colors.indigo),
              _buildStatCard('Active / Ongoing', activeBookings.toString(), Icons.directions_car, Colors.orange),
              _buildStatCard('Completed Trips', completedBookings.toString(), Icons.done_all, Colors.green),
              _buildStatCard('Cancelled / Denied', cancelledBookings.toString(), Icons.cancel_presentation_outlined, Colors.redAccent),
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
                        hintText: 'Search by booking ID, vehicle model, or customer name...',
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
                      items: ['All', 'Pending', 'Approved', 'Ongoing', 'Completed', 'Cancelled'].map((s) {
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

          // List / Table view
          Expanded(
            child: filteredBookings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No reservations found matching search queries.', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: isDesktop ? _buildDesktopTable(filteredBookings) : _buildMobileList(filteredBookings),
                  ),
          ),
        ],
      ),
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

  Widget _buildDesktopTable(List<BookingModel> bookings) {
    return ListView(
      children: [
        DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('Booking ID', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Pickup Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Return Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Amount (RM)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Detail', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: bookings.map((b) {
            Color statusColor = Colors.orange;
            if (b.status == 'approved') statusColor = Colors.green;
            if (b.status == 'ongoing') statusColor = Colors.blue;
            if (b.status == 'completed') statusColor = Colors.indigo;
            if (b.status == 'cancelled' || b.status == 'rejected') statusColor = Colors.redAccent;

            final dateFormat = DateFormat('yyyy-MM-dd');

            return DataRow(
              cells: [
                DataCell(Text(b.id.substring(0, b.id.length > 8 ? 8 : b.id.length), style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(b.userName)),
                DataCell(Text(b.vehicleName)),
                DataCell(Text(dateFormat.format(b.pickUpDate))),
                DataCell(Text(dateFormat.format(b.returnDate))),
                DataCell(Text('RM ${b.totalPrice.toStringAsFixed(2)}')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      b.status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: AppColors.secondaryBlue, size: 18),
                    onPressed: () => _showBookingDetails(b),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMobileList(List<BookingModel> bookings) {
    return ListView.builder(
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        Color statusColor = Colors.orange;
        if (b.status == 'approved') statusColor = Colors.green;
        if (b.status == 'ongoing') statusColor = Colors.blue;
        if (b.status == 'completed') statusColor = Colors.indigo;
        if (b.status == 'cancelled' || b.status == 'rejected') statusColor = Colors.redAccent;

        final dateFormat = DateFormat('yyyy-MM-dd');

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
          elevation: 0,
          child: ListTile(
            title: Text(b.vehicleName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Customer: ${b.userName}', style: const TextStyle(fontSize: 12)),
                Text('Date: ${dateFormat.format(b.pickUpDate)} to ${dateFormat.format(b.returnDate)}', style: const TextStyle(fontSize: 12)),
                Text('Amount: RM ${b.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    b.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, size: 16),
              ],
            ),
            onTap: () => _showBookingDetails(b),
          ),
        );
      },
    );
  }
}
