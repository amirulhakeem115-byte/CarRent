import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../models/booking_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/payment_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/booking_source_badge.dart';
import '../../../widgets/staff_quick_booking_modal_sheet.dart';
import '../../../constants/colors.dart';
import '../../../l10n/app_translations.dart';

class BookingsView extends StatefulWidget {
  const BookingsView({super.key});

  @override
  State<BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends State<BookingsView> {
  final BookingService _bookingService = BookingService();
  final VehicleService _vehicleService = VehicleService();
  final PaymentService _paymentService = PaymentService();

  List<BookingModel> _bookings = [];
  List<VehicleModel> _vehicles = [];
  List<PaymentModel> _payments = [];
  bool _loading = true;
  String _selectedFilter =
      'All'; // 'All', 'Pending', 'Approved', 'Ongoing', 'Completed', 'Cancelled', 'Overdue'
  String _selectedAdminTab = 'Bookings'; // 'Bookings', 'Active Rentals'
  String _activeRentalDateFilter =
      'All'; // 'All', 'Today', 'Tomorrow', 'Next 7 Days', 'Custom Date'
  DateTime? _customRentalDate;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  StreamSubscription<List<BookingModel>>? _bookingsSubscription;
  StreamSubscription<List<VehicleModel>>? _vehiclesSubscription;
  StreamSubscription<List<PaymentModel>>? _paymentsSubscription;

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
    _bookingsSubscription = _bookingService.getBookingsStream().listen((
      bookingsList,
    ) {
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

    _paymentsSubscription?.cancel();
    _paymentsSubscription = _paymentService.getPaymentsStream().listen((pList) {
      if (mounted) {
        setState(() {
          _payments = pList;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bookingsSubscription?.cancel();
    _vehiclesSubscription?.cancel();
    _paymentsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBookings({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_bookings.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _bookingService.getBookings(forceRefresh: forceRefresh),
        _paymentService.getPayments(forceRefresh: forceRefresh),
      ]);
      _bookings = results[0] as List<BookingModel>;
      _payments = results[1] as List<PaymentModel>;
      _bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      if (_bookings.isEmpty) {
        setState(() {
          _error = 'Failed to load booking records. Please try again.';
        });
      }
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

  Color _getBookingStatusColor(String status, bool isDark) {
    final s = status.trim().toLowerCase();
    if (s == 'pending') {
      return isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280); // Grey
    }
    if (s == 'approved' || s == 'confirmed') {
      return const Color(0xFF10B981); // Green
    }
    if (s == 'on the way' || s == 'ontheway' || s == 'on_the_way') {
      return const Color(0xFF3B82F6); // Blue
    }
    if (s == 'ongoing' || s == 'active' || s == 'rental active') {
      return isDark ? const Color(0xFF22D3EE) : const Color(0xFF00ACC1); // Cyan
    }
    if (s == 'waiting for return approval' ||
        s == 'return requested' ||
        s == 'awaiting return inspection' ||
        s == 'awaiting final payment' ||
        s == 'return_requested') {
      return isDark
          ? const Color(0xFFFB923C)
          : const Color(0xFFEA580C); // Orange / Deep Amber (High visibility)
    }
    if (s == 'completed') {
      return isDark
          ? const Color(0xFF60A5FA)
          : const Color(0xFF1E3A8A); // Dark Blue
    }
    if (s == 'cancelled' || s == 'canceled' || s == 'rejected') {
      return const Color(0xFFEF4444); // Red
    }
    if (s == 'overdue') {
      return isDark
          ? const Color(0xFFF87171)
          : const Color(0xFFB91C1C); // Crimson Red
    }
    return isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  }

  void _showBookingDetails(BookingModel booking) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    double pricePerDay = 100.0;
    try {
      pricePerDay = _vehicles
          .firstWhere((v) => v.id == booking.vehicleId)
          .pricePerDay;
    } catch (_) {}
    final overdue = BookingService.getOverdueDetails(booking, pricePerDay);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: sheetBg,
      builder: (context) {
        final isCompactMobile = MediaQuery.of(context).size.width < 420;
        final bStat = booking.status.trim().toLowerCase();
        final isCompleted = bStat == 'completed';
        final isCancelled = bStat == 'cancelled' || bStat == 'canceled';
        final hideTransitionStateSection = isCompleted || isCancelled;
        final statusColor = _getBookingStatusColor(booking.status, isDark);

        final double overdueCharge = overdue['isOverdue'] == true ? (overdue['charges'] as double) : 0.0;
        final double totalAmount = booking.isOpenRental
            ? _getDynamicPrice(booking)
            : (booking.totalPrice + overdueCharge);

        final bookingPayments = _payments.where((p) {
          if (p.bookingId != booking.id) return false;
          final s = p.status.toLowerCase();
          final ps = (p.paymentStatus ?? '').toLowerCase();
          return s == 'approved' || s == 'paid' || ps == 'approved' || ps == 'paid';
        }).toList();

        double amountPaid = bookingPayments.fold(0.0, (sum, p) => sum + p.amount);
        if (bookingPayments.isEmpty &&
            (bStat == 'approved' ||
                bStat == 'confirmed' ||
                bStat == 'active' ||
                bStat == 'ongoing' ||
                bStat == 'completed')) {
          amountPaid = booking.depositAmount;
        }

        final double discount = booking.discountAmount + booking.promotionDiscountAmount;
        final double remainingBalance = math.max(0.0, totalAmount - amountPaid - discount);

        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: isCompactMobile ? 16 : 24,
            right: isCompactMobile ? 16 : 24,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    Text(
                      'Reservation Specification'.tr(context),
                      style: TextStyle(
                        fontSize: isCompactMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    BookingSourceBadge(bookingSource: booking.bookingSource),
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
                        booking.status.toUpperCase().tr(context),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: isCompactMobile ? 9 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow(context, 'Reservation Ref ID'.tr(context), booking.id),
                _buildDetailRow(context, 'Vehicle Name'.tr(context), booking.vehicleName),
                _buildDetailRow(context, 'Customer Name'.tr(context), booking.userName),
                _buildDetailRow(context, 'Customer Phone'.tr(context), booking.userPhone),
                _buildDetailRow(
                  context,
                  'Rental Duration'.tr(context),
                  booking.isOpenRental
                      ? '${dateFormat.format(booking.pickUpDate)} to OPEN RENTAL (${"Open Ended".tr(context)})'
                      : '${dateFormat.format(booking.pickUpDate)} to ${booking.returnDate != null ? dateFormat.format(booking.returnDate!) : ""} (${booking.rentalDays} ${"days".tr(context)})',
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  context,
                  booking.isOpenRental && bStat == 'active'
                      ? 'Total Amount (Estimated)'.tr(context)
                      : 'Total Amount'.tr(context),
                  'RM ${totalAmount.toStringAsFixed(2)}',
                ),
                _buildDetailRow(
                  context,
                  'Amount Paid'.tr(context),
                  'RM ${amountPaid.toStringAsFixed(2)}',
                  textColor: Colors.teal,
                ),
                _buildDetailRow(
                  context,
                  'Discount'.tr(context),
                  'RM ${discount.toStringAsFixed(2)}',
                  textColor: Colors.purple,
                ),
                _buildDetailRow(
                  context,
                  'Remaining Balance'.tr(context),
                  'RM ${remainingBalance.toStringAsFixed(2)}',
                  textColor: remainingBalance > 0 ? Colors.orange : Colors.green,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  context,
                  'Deposit Lodged'.tr(context),
                  'RM ${booking.depositAmount.toStringAsFixed(2)}',
                ),
                if (overdue['isOverdue'] == true) ...[
                  _buildDetailRow(
                    context,
                    '⚠️ Overdue Duration'.tr(context),
                    '${overdue['days']} ${"days".tr(context)}, ${overdue['hours']} ${"hours".tr(context)}',
                    textColor: Colors.redAccent,
                  ),
                  _buildDetailRow(
                    context,
                    '⚠️ Late Fees Accrued'.tr(context),
                    'RM ${overdue['charges'].toStringAsFixed(2)}',
                    textColor: Colors.redAccent,
                  ),
                ],
                if (booking.notes != null && booking.notes!.isNotEmpty)
                  _buildDetailRow(
                    context,
                    'Special Remarks'.tr(context),
                    booking.notes!,
                    isItalic: true,
                  ),
                if (!hideTransitionStateSection) ...[
                  const Divider(height: 32),
                  Text(
                    'Transition Rental State'.tr(context),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!hideTransitionStateSection)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (booking.status == 'pending') ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _updateStatus(booking, 'approved');
                          },
                          child: Text('Approve Reservation'.tr(context)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _updateStatus(booking, 'rejected');
                          },
                          child: Text('Reject & Deny'.tr(context)),
                        ),
                      ],
                      if (booking.status == 'approved' ||
                          booking.status == 'Confirmed' ||
                          booking.status == 'confirmed') ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _updateStatus(booking, 'active');
                          },
                          child: Text(
                            booking.isOpenRental
                                ? 'Vehicle Picked Up'.tr(context)
                                : 'Handover Keys (Active)'.tr(context),
                          ),
                        ),
                      ],
                      if (booking.status.toLowerCase() == 'return requested' ||
                          booking.status.toLowerCase() ==
                              'awaiting return inspection' ||
                          booking.status == 'ongoing' ||
                          booking.status.toLowerCase() == 'active' ||
                          booking.status.toLowerCase() == 'overdue') ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showReturnInspectionDialog(booking);
                          },
                          child: Text(
                            booking.isOpenRental
                                ? 'Complete Return Inspection'.tr(context)
                                : 'Inspect & Complete Return'.tr(context),
                          ),
                        ),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showApplyDiscountDialog(booking);
                        },
                        icon: const Icon(Icons.local_offer_rounded, size: 16),
                        label: Text('Apply Discount'.tr(context)),
                      ),
                      if (booking.status != 'cancelled' &&
                          booking.status != 'completed' &&
                          booking.status != 'rejected') ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _updateStatus(booking, 'cancelled');
                          },
                          child: Text('Cancel Booking'.tr(context)),
                        ),
                      ],
                    ],
                  ),
                if (booking.extensionRequest != null &&
                    booking.extensionRequest!['status'] == 'pending') ...[
                  const Divider(height: 32),
                  Text(
                    'Extension Request Details'.tr(context),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    context,
                    'Requested Return'.tr(context),
                    DateFormat('dd MMM yyyy hh:mm a').format(
                      DateTime.parse(
                        booking.extensionRequest!['newReturnDate'],
                      ),
                    ),
                  ),
                  _buildDetailRow(
                    context,
                    'Additional Cost'.tr(context),
                    'RM ${booking.extensionRequest!['additionalCost'].toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          setState(() => _loading = true);
                          await _bookingService.approveExtension(booking.id);
                          _loadBookings();
                        },
                        child: Text('Approve Extension'.tr(context)),
                      ),
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
                        child: Text('Reject Extension'.tr(context)),
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

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isItalic = false,
    Color? textColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final isCompactMobile = media.size.width < 420;
    final hasLargeText = media.textScaler.scale(1.0) > 1.15;
    final textPrimary =
        textColor ??
        (isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue);
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;

    final stackedLayout = isCompactMobile || hasLargeText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: stackedLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: isCompactMobile ? 11.5 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  softWrap: true,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isCompactMobile ? 11.5 : 13,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                    color: textPrimary,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: isCompactMobile ? 11.5 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 7,
                  child: Text(
                    value,
                    softWrap: true,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isCompactMobile ? 11.5 : 13,
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
      return Center(
        child: LoadingWidget(message: 'Loading booking archives...'.tr(context)),
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
              _error!.tr(context),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.secondaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBookings,
              child: Text('Retry'.tr(context)),
            ),
          ],
        ),
      );
    }

    // Calculations
    final totalBookings = _bookings.length;
    final activeBookings = _bookings
        .where((b) => BookingService.isActiveBooking(b.status))
        .length;
    final completedBookings = _bookings
        .where((b) => b.status.toLowerCase() == 'completed')
        .length;
    final cancelledBookings = _bookings.where((b) {
      final s = b.status.toLowerCase();
      return s == 'cancelled' || s == 'canceled' || s == 'rejected';
    }).length;

    // Filtering
    final filteredBookings = _bookings.where((b) {
      final matchesSearch =
          b.id.toLowerCase().contains(_searchQuery) ||
          b.userName.toLowerCase().contains(_searchQuery) ||
          b.vehicleName.toLowerCase().contains(_searchQuery);
      final matchesStatus =
          _selectedFilter == 'All' ||
          b.status.toLowerCase() == _selectedFilter.toLowerCase() ||
          (_selectedFilter == 'Ongoing' && BookingService.isOngoingStatus(b.status)) ||
          (_selectedFilter == 'Active' && BookingService.isActiveBooking(b.status));
      return matchesSearch && matchesStatus;
    }).toList();

    final activeRentals = _bookings.where((b) {
      return _isActiveRentalStatus(b.status) &&
          _matchesActiveRentalDateFilter(b);
    }).toList()..sort((a, b) => a.pickUpDate.compareTo(b.pickUpDate));

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
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedAdminTab == 'Bookings'
                          ? 'Reservation Registry'.tr(context)
                          : 'Active Rentals'.tr(context),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      _selectedAdminTab == 'Bookings'
                          ? 'Audit rental schedules, verify security deposits, and handover keys.'.tr(context)
                          : 'Track currently active rentals with pickup-return visibility.'.tr(context),
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => StaffQuickBookingModalSheet(
                          initialSource: 'phone',
                          onBookingCreated: _loadBookings,
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                    label: Text('Phone Booking'.tr(context), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => StaffQuickBookingModalSheet(
                          initialSource: 'walkIn',
                          onBookingCreated: _loadBookings,
                        ),
                      );
                    },
                    icon: const Icon(Icons.directions_walk_rounded, size: 16),
                    label: Text('Walk-in Booking'.tr(context), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildAdminTabSwitcher(
            isDark: isDark,
            cardColor: cardColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            borderColor: borderColor,
          ),
          const SizedBox(height: 20),

          GridView.count(
            crossAxisCount: isDesktop ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: isDesktop ? 2.2 : 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(
                'Total Bookings',
                totalBookings.toString(),
                Icons.book_online,
                Colors.indigo,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Active / Ongoing',
                activeBookings.toString(),
                Icons.directions_car,
                Colors.orange,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Completed Trips',
                completedBookings.toString(),
                Icons.done_all,
                Colors.green,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Cancelled / Denied',
                cancelledBookings.toString(),
                Icons.cancel_presentation_outlined,
                Colors.redAccent,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_selectedAdminTab == 'Bookings') ...[
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
                                  'Search by booking ID, vehicle model, or customer name...'.tr(context),
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
                        _buildStatusFilterDropdown(
                          isDark: isDark,
                          cardColor: surfaceColor,
                          textPrimary: textPrimary,
                          borderColor: borderColor,
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
                                'Search by booking ID, vehicle or customer...'.tr(context),
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
                        _buildStatusFilterDropdown(
                          isDark: isDark,
                          cardColor: surfaceColor,
                          textPrimary: textPrimary,
                          borderColor: borderColor,
                        ),
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
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 64,
                            color: textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No reservations found matching search queries.',
                            style: TextStyle(color: textSecondary),
                          ),
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
                        ? _buildDesktopTable(
                            filteredBookings,
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          )
                        : _buildMobileList(
                            filteredBookings,
                            isDark: isDark,
                            cardColor: cardColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                          ),
                  ),
          ] else ...[
            _buildActiveRentalDateFilters(
              isDark: isDark,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
            ),
            const SizedBox(height: 16),
            activeRentals.isEmpty
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
                          Icon(
                            Icons.directions_car_outlined,
                            size: 64,
                            color: textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No active rentals found for this date filter.'.tr(context),
                            style: TextStyle(color: textSecondary),
                          ),
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
                        ? _buildActiveRentalsDesktopTable(
                            activeRentals,
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          )
                        : _buildActiveRentalsMobileList(
                            activeRentals,
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                          ),
                  ),
          ],
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
                Text(
                  label.tr(context),
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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
    List<BookingModel> bookings, {
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      children: [
        // Responsive Header Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: headerBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 10,
                child: Text(
                  'Booking Ref'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  'Customer Name'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 13,
                child: Text(
                  'Vehicle'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 11,
                child: Text(
                  'Pickup Date'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 11,
                child: Text(
                  'Return Date'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  'Total'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 9,
                child: Text(
                  'Paid'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 9,
                child: Text(
                  'Remaining'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 9,
                child: Text(
                  'Status'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'Actions'.tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
            ],
          ),
        ),

        // Item Rows (Zero Horizontal Scroll)
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bookings.length,
          separatorBuilder: (ctx, i) => Divider(height: 1, color: borderColor),
          itemBuilder: (ctx, i) {
            final b = bookings[i];
            final Color statusColor = _getBookingStatusColor(b.status, isDark);
            final bStat = b.status.toLowerCase();

            final bookingPayments = _payments.where((p) {
              if (p.bookingId != b.id) return false;
              final s = p.status.toLowerCase();
              final ps = (p.paymentStatus ?? '').toLowerCase();
              return s == 'approved' || s == 'paid' || ps == 'approved' || ps == 'paid';
            }).toList();

            double amountPaid = bookingPayments.fold(0.0, (sum, p) => sum + p.amount);
            if (bookingPayments.isEmpty &&
                (bStat == 'approved' ||
                    bStat == 'confirmed' ||
                    bStat == 'active' ||
                    bStat == 'ongoing' ||
                    bStat == 'completed')) {
              amountPaid = b.depositAmount;
            }

            final double totalAmount = b.isOpenRental && bStat == 'active'
                ? _getDynamicPrice(b)
                : b.totalPrice;
            final double discount = b.discountAmount + b.promotionDiscountAmount;
            final double remaining = math.max(0.0, totalAmount - amountPaid - discount);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // 1. Booking Ref
                  Expanded(
                    flex: 10,
                    child: Tooltip(
                      message: b.id,
                      child: Text(
                        '#${b.id.toUpperCase()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // 2. Customer Name
                  Expanded(
                    flex: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          b.userName.isNotEmpty ? b.userName : 'Customer',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: textPrimary,
                          ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 2),
                        BookingSourceBadge(bookingSource: b.bookingSource, compact: true),
                      ],
                    ),
                  ),
                  // 3. Vehicle
                  Expanded(
                    flex: 13,
                    child: Text(
                      b.vehicleName,
                      style: TextStyle(fontSize: 12, color: textPrimary),
                      softWrap: true,
                    ),
                  ),
                  // 4. Pickup Date
                  Expanded(
                    flex: 11,
                    child: Text(
                      dateFormat.format(b.pickUpDate),
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ),
                  // 5. Return Date or OPEN RENTAL
                  Expanded(
                    flex: 11,
                    child: Text(
                      b.isOpenRental
                          ? 'OPEN RENTAL'
                          : (b.returnDate != null
                              ? dateFormat.format(b.returnDate!)
                              : "OPEN RENTAL"),
                      style: TextStyle(
                        fontSize: 11,
                        color: b.isOpenRental ? Colors.teal : textSecondary,
                        fontWeight: b.isOpenRental ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  // 6. Total Amount
                  Expanded(
                    flex: 10,
                    child: Text(
                      'RM ${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                  ),
                  // 7. Paid
                  Expanded(
                    flex: 9,
                    child: Text(
                      'RM ${amountPaid.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ),
                  // 8. Remaining
                  Expanded(
                    flex: 9,
                    child: Text(
                      'RM ${remaining.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: remaining > 0 ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                  // 9. Status
                  Expanded(
                    flex: 9,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          b.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  // 10. Actions
                  SizedBox(
                    width: 70,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.visibility_outlined,
                            color: AppColors.primaryOrange,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Booking Details',
                          onPressed: () => _showBookingDetails(b),
                        ),
                        if (bStat == 'return requested' ||
                            bStat == 'awaiting return inspection' ||
                            bStat == 'active' ||
                            bStat == 'ongoing' ||
                            bStat == 'overdue') ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.fact_check_outlined,
                              color: Colors.teal,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Return Inspection',
                            onPressed: () => _showReturnInspectionDialog(b),
                          ),
                        ],
                      ],
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

  Widget _buildMobileList(
    List<BookingModel> bookings, {
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        final Color statusColor = _getBookingStatusColor(b.status, isDark);
        final bStat = b.status.toLowerCase();
        final dateFormat = DateFormat('yyyy-MM-dd');
        return Card(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8F9FA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              ListTile(
                title: Text(
                  b.vehicleName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textPrimary,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Customer: ${b.userName}',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    Text(
                      b.isOpenRental
                          ? '${dateFormat.format(b.pickUpDate)} → OPEN RENTAL'
                          : '${dateFormat.format(b.pickUpDate)} → ${b.returnDate != null ? dateFormat.format(b.returnDate!) : "OPEN RENTAL"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: b.isOpenRental ? Colors.green : textSecondary,
                        fontWeight: b.isOpenRental
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      'RM ${b.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                        b.status.toUpperCase(),
                        maxLines: 2,
                        softWrap: true,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () => _showBookingDetails(b),
              ),
              if (bStat == 'return requested' ||
                  bStat == 'awaiting return inspection' ||
                  bStat == 'active' ||
                  bStat == 'ongoing' ||
                  bStat == 'overdue')
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _showReturnInspectionDialog(b),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: Text(
                        b.isOpenRental
                            ? 'Complete Return Inspection'
                            : 'Inspect & Complete',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildStatusFilterDropdown({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
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
        style: TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        items:
            [
              'All',
              'Pending',
              'Approved',
              'Ongoing',
              'Completed',
              'Cancelled',
              'Overdue',
            ].map((s) {
              return DropdownMenuItem(
                value: s,
                child: Text(
                  s,
                  style: TextStyle(color: textPrimary, fontSize: 13),
                ),
              );
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
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('vehicles')
          .child(booking.vehicleId)
          .get();
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
          booking.isOpenRental
              ? 'Return Car Inspection'
              : 'Return Vehicle Inspection',
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
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Condition',
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  style: TextStyle(color: textColor),
                  items: ['Excellent', 'Good', 'Fair', 'Damaged'].map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c, style: TextStyle(color: textColor)),
                    );
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
                  dropdownColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  style: TextStyle(color: textColor),
                  items: ['Full (8/8)', '3/4', '1/2', '1/4', 'Empty'].map((f) {
                    return DropdownMenuItem(
                      value: f,
                      child: Text(f, style: TextStyle(color: textColor)),
                    );
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
                  decoration: const InputDecoration(
                    labelText: 'Current Mileage (km)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: damageController,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(
                    labelText: 'Damage Notes / Description',
                    hintText: 'Describe any new damages',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: damageFeeController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(
                    labelText: 'Damage Fee (RM)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cleaningController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(
                    labelText: 'Cleaning Fee (RM)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: extraController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(
                    labelText: 'Extra Charges / Fees (RM)',
                  ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              booking.isOpenRental
                  ? 'Complete Return Inspection'
                  : 'Complete Return',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final double cleanFee =
          double.tryParse(cleaningController.text.trim()) ?? 0.0;
      final double damageFee =
          double.tryParse(damageFeeController.text.trim()) ?? 0.0;
      final double extraFee =
          double.tryParse(extraController.text.trim()) ?? 0.0;
      final int mil = int.tryParse(mileageController.text.trim()) ?? 0;

      final Map<String, dynamic> inspectionData = {
        'condition': selectedCondition,
        'fuelLevel': selectedFuel,
        'mileage': mil,
        'damageNotes': damageController.text.trim().isNotEmpty
            ? damageController.text.trim()
            : 'None',
        'damageFee': damageFee,
        'cleaningFee': cleanFee,
        'extraCharges': extraFee,
        'completedAt': DateTime.now().toIso8601String(),
      };

      setState(() => _loading = true);
      try {
        await _bookingService.completeReturn(booking.id, inspectionData);

        if (mil > 0) {
          await FirebaseDatabase.instance
              .ref()
              .child('vehicles')
              .child(booking.vehicleId)
              .update({'mileage': mil});
        }

        _loadBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                booking.isOpenRental
                    ? 'Return inspection completed. Awaiting final payment.'
                    : 'Vehicle returned and booking completed successfully.',
              ),
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

  bool _isActiveRentalStatus(String status) {
    return BookingService.isActiveBooking(status);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _matchesActiveRentalDateFilter(BookingModel booking) {
    if (_activeRentalDateFilter == 'All') return true;

    final pickupDate = _dateOnly(booking.pickUpDate);
    final returnDate = booking.returnDate != null ? _dateOnly(booking.returnDate!) : null;
    final today = _dateOnly(DateTime.now());

    switch (_activeRentalDateFilter) {
      case 'Today':
        if (pickupDate == today) return true;
        if (returnDate != null && !pickupDate.isAfter(today) && !returnDate.isBefore(today)) return true;
        if (returnDate == null && !pickupDate.isAfter(today)) return true;
        return false;
      case 'Tomorrow':
        final tomorrow = today.add(const Duration(days: 1));
        if (pickupDate == tomorrow) return true;
        if (returnDate != null && !pickupDate.isAfter(tomorrow) && !returnDate.isBefore(tomorrow)) return true;
        if (returnDate == null && !pickupDate.isAfter(tomorrow)) return true;
        return false;
      case 'Next 7 Days':
        final end = today.add(const Duration(days: 6));
        if (!pickupDate.isBefore(today) && !pickupDate.isAfter(end)) return true;
        if (returnDate != null && !pickupDate.isAfter(end) && !returnDate.isBefore(today)) return true;
        if (returnDate == null && !pickupDate.isAfter(end)) return true;
        return false;
      case 'Custom Date':
        if (_customRentalDate == null) return true;
        final target = _dateOnly(_customRentalDate!);
        if (pickupDate == target) return true;
        if (returnDate != null && !pickupDate.isAfter(target) && !returnDate.isBefore(target)) return true;
        if (returnDate == null && !pickupDate.isAfter(target)) return true;
        return false;
      default:
        return true;
    }
  }

  String _remainingDaysText(BookingModel booking) {
    if (booking.returnDate == null || booking.isOpenRental) {
      return 'Open Rental';
    }

    final today = _dateOnly(DateTime.now());
    final returnDate = _dateOnly(booking.returnDate!);
    final diff = returnDate.difference(today).inDays;
    if (diff < 0) {
      return '${diff.abs()} day(s) overdue';
    }
    if (diff == 0) {
      return 'Due today';
    }
    return '$diff day(s) left';
  }

  Widget _buildAdminTabSwitcher({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    Widget tabChip(String label) {
      final bool selected = _selectedAdminTab == label;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (_selectedAdminTab != label) {
              setState(() => _selectedAdminTab = label);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryOrange.withValues(
                      alpha: isDark ? 0.25 : 0.12,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.primaryOrange : Colors.transparent,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primaryOrange : textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          tabChip('Bookings'),
          const SizedBox(width: 8),
          tabChip('Active Rentals'),
        ],
      ),
    );
  }

  Widget _buildActiveRentalDateFilters({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final options = ['All', 'Today', 'Tomorrow', 'Next 7 Days', 'Custom Date'];
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option.tr(context)),
              selected: _activeRentalDateFilter == option,
              selectedColor: AppColors.primaryOrange.withValues(
                alpha: isDark ? 0.25 : 0.12,
              ),
              labelStyle: TextStyle(
                color: _activeRentalDateFilter == option
                    ? AppColors.primaryOrange
                    : textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              side: BorderSide(
                color: _activeRentalDateFilter == option
                    ? AppColors.primaryOrange
                    : borderColor,
              ),
              backgroundColor: cardColor,
              onSelected: (_) {
                setState(() {
                  _activeRentalDateFilter = option;
                  if (option != 'Custom Date') {
                    _customRentalDate = null;
                  }
                });
              },
            ),
          if (_activeRentalDateFilter == 'Custom Date')
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textPrimary,
                side: BorderSide(color: borderColor),
                backgroundColor: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
              ),
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _customRentalDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    _customRentalDate = pickedDate;
                  });
                }
              },
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: Text(
                _customRentalDate == null
                    ? 'Pick date'.tr(context)
                    : DateFormat('dd MMM yyyy').format(_customRentalDate!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveRentalsDesktopTable(
    List<BookingModel> rentals, {
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: headerBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 16,
                child: Text(
                  'Customer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 16,
                child: Text(
                  'Vehicle',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  'Pickup Date',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  'Return Date',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  'Booking Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  'Remaining Days',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rentals.length,
          separatorBuilder: (ctx, i) => Divider(height: 1, color: borderColor),
          itemBuilder: (ctx, i) {
            final rental = rentals[i];
            final statusColor = _getBookingStatusColor(rental.status, isDark);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 16,
                    child: Text(
                      rental.userName,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textPrimary),
                      softWrap: true,
                    ),
                  ),
                  Expanded(
                    flex: 16,
                    child: Text(
                      rental.vehicleName,
                      style: TextStyle(fontSize: 12, color: textPrimary),
                      softWrap: true,
                    ),
                  ),
                  Expanded(
                    flex: 14,
                    child: Text(
                      dateFormat.format(rental.pickUpDate),
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 14,
                    child: Text(
                      rental.returnDate == null
                          ? 'OPEN RENTAL'
                          : dateFormat.format(rental.returnDate!),
                      style: TextStyle(
                        fontSize: 12,
                        color: rental.returnDate == null
                            ? Colors.teal
                            : textSecondary,
                        fontWeight: rental.returnDate == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 14,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rental.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 14,
                    child: Text(
                      _remainingDaysText(rental),
                      style: TextStyle(
                        fontSize: 12,
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
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

  Widget _buildActiveRentalsMobileList(
    List<BookingModel> rentals, {
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rentals.length,
      itemBuilder: (context, index) {
        final rental = rentals[index];
        final statusColor = _getBookingStatusColor(rental.status, isDark);
        return Card(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8F9FA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              rental.userName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textPrimary,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${"Vehicle:".tr(context)} ${rental.vehicleName}',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                Text(
                  '${"Pickup:".tr(context)} ${dateFormat.format(rental.pickUpDate)}',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                Text(
                  rental.returnDate == null
                      ? '${"Return:".tr(context)} ${"OPEN RENTAL".tr(context)}'
                      : '${"Return:".tr(context)} ${dateFormat.format(rental.returnDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: rental.returnDate == null
                        ? Colors.green
                        : textSecondary,
                    fontWeight: rental.returnDate == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${"Remaining:".tr(context)} ${_remainingDaysText(rental)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
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
                    rental.status.toUpperCase().tr(context),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () => _showBookingDetails(rental),
          ),
        );
      },
    );
  }



  void _showApplyDiscountDialog(BookingModel booking) {
    final discountController = TextEditingController(
      text: booking.discountAmount > 0
          ? booking.discountAmount.toStringAsFixed(2)
          : '',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.secondaryBlue;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Apply Discount'.tr(context),
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${"Booking Ref".tr(context)}: #${booking.id.toUpperCase()}',
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              '${"Customer Name".tr(context)}: ${booking.userName}',
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 16),
            Text(
              'Discount Amount (RM):'.tr(context),
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                prefixText: 'RM ',
                hintText: 'e.g. 30.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'.tr(context)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final discountVal =
                  double.tryParse(discountController.text.trim()) ?? 0.0;
              if (discountVal < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Discount amount cannot be negative.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() => _loading = true);
              try {
                await FirebaseDatabase.instance
                    .ref()
                    .child('bookings')
                    .child(booking.id)
                    .update({
                  'discountAmount': discountVal,
                  'updatedAt': DateTime.now().toIso8601String(),
                });
                _loadBookings();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Discount of RM ${discountVal.toStringAsFixed(2)} applied successfully.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                setState(() => _loading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to apply discount: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text('Save Discount'.tr(context)),
          ),
        ],
      ),
    );
  }
}
