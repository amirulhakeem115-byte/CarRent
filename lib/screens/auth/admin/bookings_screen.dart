import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/booking_model.dart';
import '../../../services/booking_service.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final BookingService _bookingService = BookingService();

  List<BookingModel> _bookings = [];
  bool _loading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    _bookings = await _bookingService.getBookings();
    // Sort bookings by date descending
    _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() => _loading = false);
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Booking Detail Sheet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(booking.status.toUpperCase(), style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Vehicle Name', booking.vehicleName),
                _buildDetailRow('Customer Name', booking.userName),
                _buildDetailRow('Customer Phone', booking.userPhone),
                _buildDetailRow('Rental Duration', '${dateFormat.format(booking.pickUpDate)} to ${dateFormat.format(booking.returnDate)} (${booking.rentalDays} days)'),
                _buildDetailRow('Deposit Lodged', 'RM ${booking.depositAmount.toStringAsFixed(2)}'),
                _buildDetailRow('Total Cost due', 'RM ${booking.totalPrice.toStringAsFixed(2)}'),
                if (booking.notes != null) _buildDetailRow('Special Requests', booking.notes!, isItalic: true),
                const Divider(height: 32),
                const Text('Transition Rental State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (booking.status == 'pending') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'approved');
                        },
                        child: const Text('Approve'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'rejected');
                        },
                        child: const Text('Reject'),
                      ),
                    ],
                    if (booking.status == 'approved') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'ongoing');
                        },
                        child: const Text('Start Rental (Ongoing)'),
                      ),
                    ],
                    if (booking.status == 'ongoing') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'completed');
                        },
                        child: const Text('Mark Completed'),
                      ),
                    ],
                    if (booking.status != 'cancelled' && booking.status != 'completed' && booking.status != 'rejected') ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                        onPressed: () {
                          Navigator.pop(context);
                          _updateStatus(booking, 'cancelled');
                        },
                        child: const Text('Cancel Rental'),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              color: const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBookings = _bookings.where((b) {
      if (_selectedFilter == 'all') return true;
      return b.status == _selectedFilter;
    }).toList();

    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Manage Bookings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Horizontal scrollable filter chips
                Container(
                  color: Colors.white,
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    children: ['all', 'pending', 'approved', 'rejected', 'ongoing', 'completed', 'cancelled']
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(f.toUpperCase()),
                                selected: _selectedFilter == f,
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedFilter = f);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: filteredBookings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('No bookings found matching filters', style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredBookings.length,
                          itemBuilder: (context, index) {
                            final booking = filteredBookings[index];

                            Color statusColor = Colors.orange;
                            if (booking.status == 'approved' || booking.status == 'ongoing') {
                              statusColor = Colors.blue;
                            } else if (booking.status == 'completed') {
                              statusColor = Colors.green;
                            } else if (booking.status == 'cancelled' || booking.status == 'rejected') {
                              statusColor = Colors.red;
                            }

                            return GestureDetector(
                              onTap: () => _showBookingDetails(booking),
                              child: Card(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            booking.vehicleName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              booking.status.toUpperCase(),
                                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Text(
                                        'Customer: ${booking.userName} (${booking.userPhone})',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_month, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${dateFormat.format(booking.pickUpDate)} to ${dateFormat.format(booking.returnDate)}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
