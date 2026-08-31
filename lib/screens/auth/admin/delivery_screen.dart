import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../constants/colors.dart';
import '../../../models/booking_model.dart';
import '../../../services/delivery_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../l10n/app_translations.dart';

class DeliveryView extends StatefulWidget {
  const DeliveryView({super.key});

  @override
  State<DeliveryView> createState() => _DeliveryViewState();
}

class _DeliveryViewState extends State<DeliveryView> {
  final DeliveryService _deliveryService = DeliveryService();
  List<BookingModel> _deliveryBookings = [];
  final Map<String, String> _userPhonesMap = {};
  final Map<String, String> _userNamesMap = {};
  bool _loading = true;
  String? _error;
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<BookingModel>>? _deliverySubscription;

  static const List<String> _statusFilters = [
    'All',
    'Pending',
    'Scheduled',
    'Assigned',
    'Out for Delivery',
    'Delivered',
    'Cancelled',
  ];

  static const List<String> _allDeliveryStatuses = [
    'Pending',
    'Scheduled',
    'Assigned',
    'Out for Delivery',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _subscribeToDeliveries();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _deliverySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final snap = await FirebaseDatabase.instance.ref().child('users').get();
      if (snap.exists && snap.value is Map) {
        final Map<dynamic, dynamic> users = snap.value as Map<dynamic, dynamic>;
        users.forEach((key, val) {
          if (val is Map) {
            final phone = val['phone'] ?? val['phoneNumber'] ?? val['userPhone'] ?? '';
            final name = val['fullName'] ?? val['name'] ?? val['userName'] ?? '';
            if (phone.toString().isNotEmpty) {
              _userPhonesMap[key.toString()] = phone.toString();
            }
            if (name.toString().isNotEmpty) {
              _userNamesMap[key.toString()] = name.toString();
            }
          }
        });
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading user details: $e');
    }
  }

  void _subscribeToDeliveries() {
    setState(() => _loading = true);
    _deliverySubscription = _deliveryService.getDeliveryStream().listen(
      (deliveries) {
        if (!mounted) return;
        setState(() {
          _deliveryBookings = deliveries;
          _loading = false;
          _error = null;
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to load delivery bookings: $err';
          _loading = false;
        });
      },
    );
  }

  String _normalizeDeliveryStatus(String rawStatus) {
    if (rawStatus.isEmpty) return 'Pending';
    final s = rawStatus.trim().toLowerCase();
    if (s == 'pending') return 'Pending';
    if (s == 'scheduled') return 'Scheduled';
    if (s == 'assigned') return 'Assigned';
    if (s == 'out for delivery' || s == 'outfordelivery' || s == 'out_for_delivery') {
      return 'Out for Delivery';
    }
    if (s == 'delivered') return 'Delivered';
    if (s == 'cancelled' || s == 'canceled') return 'Cancelled';
    return 'Pending';
  }

  Color _getStatusColor(String rawStatus) {
    final norm = _normalizeDeliveryStatus(rawStatus);
    switch (norm) {
      case 'Pending':
        return Colors.orange;
      case 'Scheduled':
        return Colors.blue;
      case 'Assigned':
        return Colors.purple;
      case 'Out for Delivery':
        return AppColors.primaryOrange;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _getCustomerPhone(BookingModel booking) {
    if (booking.userPhone.isNotEmpty) return booking.userPhone;
    final fromMap = _userPhonesMap[booking.userId];
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    return 'Not Provided';
  }

  String _getCustomerName(BookingModel booking) {
    if (booking.userName.isNotEmpty) return booking.userName;
    final fromMap = _userNamesMap[booking.userId];
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    return 'Customer';
  }

  void _showDeliveryDetailsDialog(BookingModel booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String currentStatus = _normalizeDeliveryStatus(booking.deliveryStatus);
    final feeController = TextEditingController(
      text: booking.deliveryFee > 0
          ? booking.deliveryFee.toStringAsFixed(2)
          : '0.00',
    );
    bool isSaving = false;

    final customerName = _getCustomerName(booking);
    final customerPhone = _getCustomerPhone(booking);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final statusColor = _getStatusColor(currentStatus);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded, color: AppColors.primaryOrange, size: 24),
                      const SizedBox(width: 8),
                      Text('Delivery Management'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentStatus.toUpperCase().tr(context),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Ref & Booking Ref
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildModalRow('Delivery Reference'.tr(context), '#DEL-${booking.id.substring(0, booking.id.length > 6 ? 6 : booking.id.length).toUpperCase()}'),
                          _buildModalRow('Booking Reference'.tr(context), '#${booking.id.toUpperCase()}'),
                          _buildModalRow('Vehicle Name'.tr(context), booking.vehicleName),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Customer Details Card
                    Text('CUSTOMER INFORMATION'.tr(context), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          _buildModalRow('Customer Name'.tr(context), customerName),
                          _buildModalRow('Customer Phone'.tr(context), customerPhone),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Delivery Address Card
                    Text('DELIVERY LOCATION & TIME'.tr(context), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  booking.deliveryAddress != null && booking.deliveryAddress!.isNotEmpty
                                      ? booking.deliveryAddress!
                                      : 'Customer address not specified'.tr(context),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${"Delivery Date:".tr(context)} ${booking.deliveryDate != null ? DateFormat('dd MMM yyyy').format(booking.deliveryDate!) : DateFormat('dd MMM yyyy').format(booking.pickUpDate)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                '${"Time:".tr(context)} ${booking.deliveryTime ?? "Morning Slot"}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Delivery Fee Input
                    Text('SET DELIVERY FEE'.tr(context), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: feeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.secondaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Delivery Fee (RM)'.tr(context),
                        prefixText: 'RM ',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Update Status Section
                    Text('CHANGE DELIVERY STATUS'.tr(context), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentStatus,
                          isExpanded: true,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.secondaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          items: _allDeliveryStatuses.map((st) {
                            return DropdownMenuItem<String>(
                              value: st,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(st),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(st.tr(context)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => currentStatus = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel'.tr(context)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final feeVal = double.tryParse(feeController.text.trim()) ?? 0.0;
                          try {
                            await _deliveryService.updateDeliveryDetails(
                              bookingId: booking.id,
                              newStatus: currentStatus,
                              deliveryFee: feeVal,
                              userId: booking.userId,
                              vehicleName: booking.vehicleName,
                              updateFee: true,
                            );
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Delivery details updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Save & Notify Customer'.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: LoadingWidget(message: 'Loading delivery bookings...'.tr(context)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _subscribeToDeliveries, child: Text('Retry'.tr(context))),
          ],
        ),
      );
    }

    final filteredDeliveries = _deliveryBookings.where((b) {
      final normStatus = _normalizeDeliveryStatus(b.deliveryStatus);
      final matchesStatus = _selectedStatusFilter == 'All' ||
          normStatus.toLowerCase() == _selectedStatusFilter.toLowerCase();
      final name = _getCustomerName(b).toLowerCase();
      final phone = _getCustomerPhone(b).toLowerCase();
      final addr = (b.deliveryAddress ?? '').toLowerCase();
      final matchesSearch = b.id.toLowerCase().contains(_searchQuery) ||
          name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          b.vehicleName.toLowerCase().contains(_searchQuery) ||
          addr.contains(_searchQuery);
      return matchesStatus && matchesSearch;
    }).toList();

    int pendingCount = _deliveryBookings.where((b) => _normalizeDeliveryStatus(b.deliveryStatus) == 'Pending').length;
    int scheduledCount = _deliveryBookings.where((b) => _normalizeDeliveryStatus(b.deliveryStatus) == 'Scheduled').length;
    int outForDeliveryCount = _deliveryBookings.where((b) => _normalizeDeliveryStatus(b.deliveryStatus) == 'Out for Delivery').length;
    int deliveredCount = _deliveryBookings.where((b) => _normalizeDeliveryStatus(b.deliveryStatus) == 'Delivered').length;
    double totalDeliveryFees = _deliveryBookings.fold(0.0, (acc, b) => acc + b.deliveryFee);

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1100;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Delivery Management'.tr(context),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary),
                  ),
                  Text(
                    'Track vehicle deliveries, update dispatch statuses, set delivery fees, and manage drop-off locations.'.tr(context),
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top Stats Grid
          GridView.count(
            crossAxisCount: isDesktop ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: isDesktop ? 2.2 : 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard('Pending / Scheduled', '${pendingCount + scheduledCount}', Icons.event_available, Colors.blue, isDark: isDark, cardBg: cardBg, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
              _buildStatCard('Out for Delivery', outForDeliveryCount.toString(), Icons.local_shipping, AppColors.primaryOrange, isDark: isDark, cardBg: cardBg, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
              _buildStatCard('Delivered Successfully', deliveredCount.toString(), Icons.check_circle_outline, Colors.green, isDark: isDark, cardBg: cardBg, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
              _buildStatCard('Total Delivery Revenue', 'RM ${totalDeliveryFees.toStringAsFixed(2)}', Icons.monetization_on, Colors.purple, isDark: isDark, cardBg: cardBg, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
            ],
          ),
          const SizedBox(height: 24),

          // Filters & Search
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by delivery ref, customer, phone, vehicle, or address...'.tr(context),
                          hintStyle: TextStyle(color: textSecondary),
                          prefixIcon: Icon(Icons.search, color: textSecondary),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusFilters.map((st) {
                      final isSel = _selectedStatusFilter == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(st.tr(context)),
                          selected: isSel,
                          selectedColor: AppColors.primaryOrange,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : textPrimary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedStatusFilter = st);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Delivery List / Table
          filteredDeliveries.isEmpty
              ? Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 54, color: textSecondary),
                        const SizedBox(height: 12),
                        Text('No delivery bookings matching criteria.'.tr(context), style: TextStyle(color: textSecondary)),
                      ],
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: isDesktop
                      ? _buildDesktopTable(filteredDeliveries, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor)
                      : _buildMobileList(filteredDeliveries, isDark: isDark, cardBg: cardBg, textPrimary: textPrimary, textSecondary: textSecondary, borderColor: borderColor),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {required bool isDark, required Color cardBg, required Color textPrimary, required Color textSecondary, required Color borderColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
                Text(label.tr(context), style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<BookingModel> items, {required bool isDark, required Color textPrimary, required Color textSecondary, required Color borderColor}) {
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: headerBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(flex: 10, child: Text('Delivery Ref'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary))),
              Expanded(flex: 10, child: Text('Booking Ref'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary))),
              Expanded(flex: 13, child: Text('Customer'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary))),
              Expanded(flex: 10, child: Text('Phone'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary))),
              Expanded(flex: 11, child: Text('Vehicle'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary))),
              Expanded(flex: 16, child: Text('Delivery Address'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary))),
              Expanded(flex: 11, child: Text('Date & Time'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary))),
              Expanded(flex: 8, child: Text('Fee'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary))),
              Expanded(flex: 9, child: Text('Status'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary))),
              SizedBox(width: 50, child: Text('Action'.tr(context), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (ctx, i) => Divider(height: 1, color: borderColor),
          itemBuilder: (ctx, i) {
            final b = items[i];
            final normStatus = _normalizeDeliveryStatus(b.deliveryStatus);
            final stColor = _getStatusColor(normStatus);
            final delRef = '#DEL-${b.id.substring(0, b.id.length > 6 ? 6 : b.id.length).toUpperCase()}';
            final cName = _getCustomerName(b);
            final cPhone = _getCustomerPhone(b);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(flex: 10, child: Text(delRef, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textPrimary))),
                  Expanded(flex: 10, child: Text('#${b.id.toUpperCase()}', style: TextStyle(fontSize: 11, color: textSecondary))),
                  Expanded(flex: 13, child: Text(cName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary), softWrap: true)),
                  Expanded(flex: 10, child: Text(cPhone, style: TextStyle(fontSize: 11, color: textSecondary), softWrap: true)),
                  Expanded(flex: 11, child: Text(b.vehicleName, style: TextStyle(fontSize: 12, color: textPrimary), softWrap: true)),
                  Expanded(flex: 16, child: Text(b.deliveryAddress ?? 'Customer address not specified', style: TextStyle(fontSize: 11, color: textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  Expanded(
                    flex: 11,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(b.deliveryDate ?? b.pickUpDate), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                        Text(b.deliveryTime ?? 'Morning', style: TextStyle(fontSize: 10, color: textSecondary)),
                      ],
                    ),
                  ),
                  Expanded(flex: 8, child: Text('RM ${b.deliveryFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple))),
                  Expanded(
                    flex: 9,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: stColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(normStatus.toUpperCase(), style: TextStyle(color: stColor, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryOrange, size: 20),
                        tooltip: 'Manage Delivery',
                        onPressed: () => _showDeliveryDetailsDialog(b),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileList(List<BookingModel> items, {required bool isDark, required Color cardBg, required Color textPrimary, required Color textSecondary, required Color borderColor}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final b = items[i];
        final normStatus = _normalizeDeliveryStatus(b.deliveryStatus);
        final stColor = _getStatusColor(normStatus);
        final delRef = '#DEL-${b.id.substring(0, b.id.length > 6 ? 6 : b.id.length).toUpperCase()}';
        final cName = _getCustomerName(b);
        final cPhone = _getCustomerPhone(b);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderColor)),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showDeliveryDetailsDialog(b),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(delRef, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: stColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(normStatus.toUpperCase(), style: TextStyle(color: stColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${"Customer:".tr(context)} $cName', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                  Text('${"Phone:".tr(context)} $cPhone', style: TextStyle(fontSize: 12, color: textSecondary)),
                  Text('${"Vehicle:".tr(context)} ${b.vehicleName}', style: TextStyle(fontSize: 12, color: textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(child: Text(b.deliveryAddress ?? 'Customer address not specified'.tr(context), style: TextStyle(fontSize: 12, color: textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${"Fee:".tr(context)} RM ${b.deliveryFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                      Text(DateFormat('dd MMM yyyy').format(b.deliveryDate ?? b.pickUpDate), style: TextStyle(fontSize: 11, color: textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
