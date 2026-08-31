import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../constants/colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/maintenance_job_model.dart';
import '../../../models/vehicle_expense_model.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/maintenance_service.dart';
import '../../../services/vehicle_expense_service.dart';
import '../../../widgets/app_image.dart';
import '../../../l10n/app_translations.dart';

class VehicleFinancialReportsView extends StatefulWidget {
  const VehicleFinancialReportsView({super.key});

  @override
  State<VehicleFinancialReportsView> createState() => _VehicleFinancialReportsViewState();
}

class _VehicleFinancialReportsViewState extends State<VehicleFinancialReportsView> {
  final VehicleService _vehicleService = VehicleService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  final MaintenanceService _maintenanceService = MaintenanceService();
  final VehicleExpenseService _expenseService = VehicleExpenseService();

  List<VehicleModel> _vehicles = [];
  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  List<MaintenanceJobModel> _maintenanceJobs = [];
  Map<String, List<VehicleExpenseModel>> _manualExpensesMap = {};

  bool _loading = true;
  String? _error;

  // Search & Filter
  final TextEditingController _searchController = TextEditingController();
  final String _selectedBranch = 'All';
  String _selectedStatus = 'All';

  StreamSubscription? _vehiclesSub;
  StreamSubscription? _bookingsSub;
  StreamSubscription? _paymentsSub;
  StreamSubscription? _expensesSub;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _subscribeRealtimeData();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _vehiclesSub?.cancel();
    _bookingsSub?.cancel();
    _paymentsSub?.cancel();
    _expensesSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      final results = await Future.wait([
        _vehicleService.getVehicles(forceRefresh: false),
        _bookingService.getBookings(forceRefresh: false),
        _paymentService.getPayments(forceRefresh: false),
        _maintenanceService.getMaintenanceJobs(forceRefresh: false),
        _expenseService.getAllExpenses(),
      ]);

      final vehicles = results[0] as List<VehicleModel>;
      final bookings = results[1] as List<BookingModel>;
      final payments = results[2] as List<PaymentModel>;
      final maintenance = results[3] as List<MaintenanceJobModel>;
      final manualExpenses = results[4] as List<VehicleExpenseModel>;

      final Map<String, List<VehicleExpenseModel>> expMap = {};
      for (final exp in manualExpenses) {
        expMap.putIfAbsent(exp.vehicleId, () => []).add(exp);
      }

      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _bookings = bookings;
          _payments = payments;
          _maintenanceJobs = maintenance;
          _manualExpensesMap = expMap;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[VehicleFinancialReports] Data load error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load financial data: $e';
          _loading = false;
        });
      }
    }
  }

  void _subscribeRealtimeData() {
    _vehiclesSub?.cancel();
    _vehiclesSub = _vehicleService.getVehiclesStream().listen((list) {
      if (mounted) setState(() => _vehicles = list);
    });

    _bookingsSub?.cancel();
    _bookingsSub = _bookingService.getBookingsStream().listen((list) {
      if (mounted) setState(() => _bookings = list);
    });

    _paymentsSub?.cancel();
    _paymentsSub = _paymentService.getPaymentsStream().listen((list) {
      if (mounted) setState(() => _payments = list);
    });

    _expensesSub?.cancel();
    _expensesSub = _expenseService.getAllExpensesStream().listen((map) {
      if (mounted) setState(() => _manualExpensesMap = map);
    });
  }

  // ---------------------------------------------------------------------------
  // Financial Calculations for a given vehicle
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _calculateVehicleFinances(VehicleModel vehicle) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final prevMonth = prevMonthDate.month;
    final prevYear = prevMonthDate.year;

    // 1. INCOME CALCULATION
    // Valid bookings for this vehicle (excluding cancelled/rejected)
    final vehicleBookings = _bookings.where((b) {
      if (b.vehicleId != vehicle.id) return false;
      final s = b.status.toLowerCase();
      if (s.contains('cancel') || s.contains('reject') || s.contains('denied') || s.contains('waiting for payment')) {
        return false;
      }
      return true;
    }).toList();

    double currentMonthIncome = 0.0;
    double prevMonthIncome = 0.0;
    double lifetimeIncome = 0.0;

    for (final b in vehicleBookings) {
      // Find matching approved/paid payments if any
      final matchingPayments = _payments.where((p) {
        if (p.bookingId != b.id) return false;
        final ps = (p.paymentStatus ?? p.status).toLowerCase();
        return ps == 'paid' || ps == 'approved';
      }).toList();

      double bAmount = b.totalPrice;
      if (matchingPayments.isNotEmpty) {
        bAmount = matchingPayments.fold(0.0, (sum, p) => sum + p.amount);
      }

      final bDate = matchingPayments.isNotEmpty ? matchingPayments.first.paymentDate : b.pickUpDate;
      lifetimeIncome += bAmount;

      if (bDate.year == currentYear && bDate.month == currentMonth) {
        currentMonthIncome += bAmount;
      } else if (bDate.year == prevYear && bDate.month == prevMonth) {
        prevMonthIncome += bAmount;
      }
    }

    // 2. MAINTENANCE EXPENSES
    final vehicleMaintenance = _maintenanceJobs.where((m) {
      if (m.vehicleId != vehicle.id) return false;
      return m.status.toLowerCase() != 'cancelled';
    }).toList();

    double currentMonthMaintenance = 0.0;
    double prevMonthMaintenance = 0.0;
    double lifetimeMaintenance = 0.0;

    for (final m in vehicleMaintenance) {
      final mDate = DateTime.tryParse(m.startDate) ?? DateTime.tryParse(m.createdAt) ?? now;
      lifetimeMaintenance += m.cost;

      if (mDate.year == currentYear && mDate.month == currentMonth) {
        currentMonthMaintenance += m.cost;
      } else if (mDate.year == prevYear && mDate.month == prevMonth) {
        prevMonthMaintenance += m.cost;
      }
    }

    // 3. MANUAL OTHER EXPENSES
    final manualExpenses = _manualExpensesMap[vehicle.id] ?? [];
    double currentMonthOtherExpenses = 0.0;
    double prevMonthOtherExpenses = 0.0;
    double lifetimeOtherExpenses = 0.0;

    for (final exp in manualExpenses) {
      lifetimeOtherExpenses += exp.amount;

      if (exp.date.year == currentYear && exp.date.month == currentMonth) {
        currentMonthOtherExpenses += exp.amount;
      } else if (exp.date.year == prevYear && exp.date.month == prevMonth) {
        prevMonthOtherExpenses += exp.amount;
      }
    }

    // COMBINED EXPENSES & PROFITS
    final currentMonthExpenses = currentMonthMaintenance + currentMonthOtherExpenses;
    final prevMonthExpenses = prevMonthMaintenance + prevMonthOtherExpenses;
    final lifetimeExpenses = lifetimeMaintenance + lifetimeOtherExpenses;

    final currentMonthProfit = currentMonthIncome - currentMonthExpenses;
    final prevMonthProfit = prevMonthIncome - prevMonthExpenses;
    final lifetimeProfit = lifetimeIncome - lifetimeExpenses;

    // MONTH OVER MONTH COMPARISONS
    final incomeDiff = currentMonthIncome - prevMonthIncome;
    final expenseDiff = currentMonthExpenses - prevMonthExpenses;
    final profitDiff = currentMonthProfit - prevMonthProfit;

    double profitChangePct = 0.0;
    if (prevMonthProfit != 0) {
      profitChangePct = ((currentMonthProfit - prevMonthProfit) / prevMonthProfit.abs()) * 100;
    } else if (currentMonthProfit > 0) {
      profitChangePct = 100.0;
    } else if (currentMonthProfit < 0) {
      profitChangePct = -100.0;
    }

    return {
      'currentMonthIncome': currentMonthIncome,
      'prevMonthIncome': prevMonthIncome,
      'lifetimeIncome': lifetimeIncome,
      'currentMonthMaintenance': currentMonthMaintenance,
      'prevMonthMaintenance': prevMonthMaintenance,
      'lifetimeMaintenance': lifetimeMaintenance,
      'currentMonthOtherExpenses': currentMonthOtherExpenses,
      'prevMonthOtherExpenses': prevMonthOtherExpenses,
      'lifetimeOtherExpenses': lifetimeOtherExpenses,
      'currentMonthExpenses': currentMonthExpenses,
      'prevMonthExpenses': prevMonthExpenses,
      'lifetimeExpenses': lifetimeExpenses,
      'currentMonthProfit': currentMonthProfit,
      'prevMonthProfit': prevMonthProfit,
      'lifetimeProfit': lifetimeProfit,
      'incomeDiff': incomeDiff,
      'expenseDiff': expenseDiff,
      'profitDiff': profitDiff,
      'profitChangePct': profitChangePct,
      'vehicleBookings': vehicleBookings,
      'vehicleMaintenance': vehicleMaintenance,
      'manualExpenses': manualExpenses,
    };
  }

  List<VehicleModel> _getFilteredVehicles() {
    final query = _searchController.text.trim().toLowerCase();
    return _vehicles.where((v) {
      if (_selectedBranch != 'All' && v.branchName != _selectedBranch && v.branchId != _selectedBranch) {
        return false;
      }
      if (_selectedStatus != 'All' && v.status.toLowerCase() != _selectedStatus.toLowerCase()) {
        return false;
      }
      if (query.isNotEmpty) {
        final name = '${v.brand} ${v.model}'.toLowerCase();
        final plate = v.plateNumber.toLowerCase();
        if (!name.contains(query) && !plate.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey[600]!;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;

    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)));
    }

    final filteredVehicles = _getFilteredVehicles();

    // Fleet Global Summary Calculations
    double fleetCurrentIncome = 0.0;
    double fleetCurrentExpenses = 0.0;
    double fleetCurrentProfit = 0.0;
    String topEarningCar = 'N/A';
    double topCarIncome = -1.0;

    for (final v in _vehicles) {
      final stats = _calculateVehicleFinances(v);
      final cInc = stats['currentMonthIncome'] as double;
      final cExp = stats['currentMonthExpenses'] as double;
      final cProf = stats['currentMonthProfit'] as double;

      fleetCurrentIncome += cInc;
      fleetCurrentExpenses += cExp;
      fleetCurrentProfit += cProf;

      if (cInc > topCarIncome && cInc > 0) {
        topCarIncome = cInc;
        topEarningCar = '${v.brand} ${v.model}';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Financial Reports'.tr(context),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Comprehensive revenue, maintenance cost, manual expenses, and net profit analysis'.tr(context),
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Refresh Data'.tr(context)),
                onPressed: () {
                  setState(() => _loading = true);
                  _loadAllData();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Fleet KPI Summary Row
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 900
                  ? (constraints.maxWidth - 48) / 4
                  : constraints.maxWidth > 600
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildKpiCard(
                    width: cardWidth,
                    title: 'Current Month Revenue'.tr(context),
                    value: 'RM ${fleetCurrentIncome.toStringAsFixed(2)}',
                    icon: Icons.payments_outlined,
                    iconColor: Colors.green,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textPrimary,
                    subTextColor: textSecondary,
                  ),
                  _buildKpiCard(
                    width: cardWidth,
                    title: 'Current Month Expenses'.tr(context),
                    value: 'RM ${fleetCurrentExpenses.toStringAsFixed(2)}',
                    icon: Icons.receipt_long_outlined,
                    iconColor: Colors.orange,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textPrimary,
                    subTextColor: textSecondary,
                  ),
                  _buildKpiCard(
                    width: cardWidth,
                    title: 'Current Net Profit'.tr(context),
                    value: 'RM ${fleetCurrentProfit.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: fleetCurrentProfit >= 0 ? Colors.teal : Colors.redAccent,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textPrimary,
                    subTextColor: textSecondary,
                  ),
                  _buildKpiCard(
                    width: cardWidth,
                    title: 'Top Earning Vehicle'.tr(context),
                    value: topEarningCar,
                    icon: Icons.emoji_events_outlined,
                    iconColor: Colors.amber,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textPrimary,
                    subTextColor: textSecondary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by car brand, model, plate...'.tr(context),
                      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedStatus,
                  dropdownColor: cardColor,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                  items: [
                    DropdownMenuItem(value: 'All', child: Text('All Vehicle Statuses'.tr(context))),
                    DropdownMenuItem(value: 'Available', child: Text('Available'.tr(context))),
                    DropdownMenuItem(value: 'Booked', child: Text('Booked'.tr(context))),
                    DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance'.tr(context))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Vehicles Financial Cards Grid / Table
          if (filteredVehicles.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_car_outlined, size: 48, color: textSecondary),
                  const SizedBox(height: 12),
                  Text('No vehicles found matching filters.'.tr(context), style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredVehicles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final vehicle = filteredVehicles[index];
                final stats = _calculateVehicleFinances(vehicle);

                final cIncome = stats['currentMonthIncome'] as double;
                final cExp = stats['currentMonthExpenses'] as double;
                final cProfit = stats['currentMonthProfit'] as double;
                final pProfit = stats['prevMonthProfit'] as double;
                final pctChange = stats['profitChangePct'] as double;

                final isProfitUp = pctChange >= 0;

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AppImage(
                              imageSrc: vehicle.mainImage,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.directions_car, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${vehicle.brand} ${vehicle.model}',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${vehicle.plateNumber} • ${vehicle.branchName.isNotEmpty ? vehicle.branchName : "Main Hub".tr(context)}',
                                  style: TextStyle(fontSize: 12, color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isProfitUp ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isProfitUp ? Colors.green : Colors.redAccent),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isProfitUp ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 14,
                                  color: isProfitUp ? Colors.green : Colors.redAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${pctChange >= 0 ? "+" : ""}${pctChange.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isProfitUp ? Colors.green : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      // Stats Row
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _buildMiniStat('Current Month Revenue'.tr(context), 'RM ${cIncome.toStringAsFixed(2)}', Colors.green, textSecondary),
                          _buildMiniStat('Current Month Expenses'.tr(context), 'RM ${cExp.toStringAsFixed(2)}', Colors.orange, textSecondary),
                          _buildMiniStat('Current Month Net Profit'.tr(context), 'RM ${cProfit.toStringAsFixed(2)}', cProfit >= 0 ? Colors.teal : Colors.redAccent, textSecondary),
                          _buildMiniStat('Previous Month Profit'.tr(context), 'RM ${pProfit.toStringAsFixed(2)}', textPrimary, textSecondary),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.analytics_outlined, size: 16),
                          label: Text('View Detailed Financial Report'.tr(context)),
                          onPressed: () => _openVehicleDetailsReport(vehicle, stats),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color valColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: valColor)),
      ],
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Vehicle Detailed Financial Report Modal / Sheet
  // ---------------------------------------------------------------------------
  void _openVehicleDetailsReport(VehicleModel vehicle, Map<String, dynamic> stats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _VehicleDetailReportModalContent(
            vehicle: vehicle,
            initialStats: stats,
            onExpenseChanged: () {
              _loadAllData();
            },
          ),
        );
      },
    );
  }
}

// =============================================================================
// Vehicle Financial Details Modal Content
// =============================================================================
class _VehicleDetailReportModalContent extends StatefulWidget {
  final VehicleModel vehicle;
  final Map<String, dynamic> initialStats;
  final VoidCallback onExpenseChanged;

  const _VehicleDetailReportModalContent({
    required this.vehicle,
    required this.initialStats,
    required this.onExpenseChanged,
  });

  @override
  State<_VehicleDetailReportModalContent> createState() => _VehicleDetailReportModalContentState();
}

class _VehicleDetailReportModalContentState extends State<_VehicleDetailReportModalContent> {
  final VehicleExpenseService _expenseService = VehicleExpenseService();
  int _activeTab = 0; // 0: Overview & Comparison, 1: Income History, 2: Maintenance Expenses, 3: Other Manual Expenses

  Future<void> _showAddOrEditExpenseDialog({VehicleExpenseModel? expense}) async {
    final cleanVehicleId = widget.vehicle.id.trim();
    if (cleanVehicleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add expense: Invalid or empty vehicle ID.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final titleController = TextEditingController(text: expense?.title ?? '');
    final amountController = TextEditingController(
      text: expense != null ? expense.amount.toStringAsFixed(2) : '',
    );
    final descController = TextEditingController(text: expense?.description ?? '');
    DateTime selectedDate = expense?.date ?? DateTime.now();
    String category = expense?.category ?? 'Insurance';
    String? inlineError;
    bool isSaving = false;

    final categories = [
      'Insurance',
      'Road Tax',
      'Car Wash',
      'Accessories',
      'Fuel',
      'Inspection',
      'Other',
    ];

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setInnerState) {
          return AlertDialog(
            title: Text(expense == null ? 'Add Manual Vehicle Expense'.tr(context) : 'Edit Vehicle Expense'.tr(context)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inlineError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              inlineError!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  TextField(
                    controller: titleController,
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: 'Expense Name / Title *'.tr(context),
                      hintText: 'e.g. Annual Road Tax Renewal'.tr(context),
                      prefixIcon: const Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    enabled: !isSaving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (RM) *'.tr(context),
                      hintText: 'e.g. 500.00'.tr(context),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: 'Category *'.tr(context),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.tr(context)))).toList(),
                    onChanged: isSaving
                        ? null
                        : (val) {
                            if (val != null) setInnerState(() => category = val);
                          },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text('Expense Date *'.tr(context)),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: isSaving
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setInnerState(() => selectedDate = picked);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    enabled: !isSaving,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description / Notes'.tr(context),
                      hintText: 'Optional expense details...'.tr(context),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
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
                        final title = titleController.text.trim();
                        final amountStr = amountController.text.trim();
                        final amount = double.tryParse(amountStr);

                        if (title.isEmpty) {
                          setInnerState(() => inlineError = 'Please enter an expense title/name.'.tr(context));
                          return;
                        }
                        if (amount == null || amount <= 0) {
                          setInnerState(() => inlineError = 'Please enter a valid amount greater than 0.'.tr(context));
                          return;
                        }

                        setInnerState(() {
                          isSaving = true;
                          inlineError = null;
                        });

                        try {
                          final expenseId = expense != null
                              ? expense.id
                              : _expenseService.generateExpenseId(cleanVehicleId);

                          final expModel = VehicleExpenseModel(
                            id: expenseId,
                            vehicleId: cleanVehicleId,
                            title: title,
                            amount: amount,
                            date: selectedDate,
                            category: category,
                            description: descController.text.trim(),
                            createdAt: expense?.createdAt ?? DateTime.now(),
                          );

                          debugPrint('[VehicleFinancialReport] Saving expense...');
                          debugPrint(' - vehicleId: $cleanVehicleId');
                          debugPrint(' - expenseId: $expenseId');
                          debugPrint(' - payload: ${expModel.toMap()}');

                          if (expense == null) {
                            await _expenseService.addExpense(expModel);
                          } else {
                            await _expenseService.updateExpense(expModel);
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx, true);
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${"Expense".tr(context)} "${expModel.title}" ${"saved successfully!".tr(context)}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            widget.onExpenseChanged();
                            setState(() {});
                          }
                        } catch (e, stack) {
                          debugPrint('[VehicleFinancialReport] ERROR saving expense: $e\n$stack');
                          setInnerState(() {
                            isSaving = false;
                            inlineError = 'Database error: $e';
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save expense: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Save Expense'.tr(context)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmAndDeleteExpense(VehicleExpenseModel expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Expense?'.tr(context)),
        content: Text('${"Are you sure you want to delete".tr(context)} "${expense.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr(context))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'.tr(context)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        debugPrint('[VehicleFinancialReport] Deleting expense ${expense.id} for vehicle ${widget.vehicle.id}');
        await _expenseService.deleteExpense(widget.vehicle.id, expense.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Expense "${expense.title}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onExpenseChanged();
          setState(() {});
        }
      } catch (e) {
        debugPrint('[VehicleFinancialReport] ERROR deleting expense: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete expense: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey[600]!;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;

    final stats = widget.initialStats;
    final bookings = (stats['vehicleBookings'] as List<BookingModel>?) ?? [];
    final maintenance = (stats['vehicleMaintenance'] as List<MaintenanceJobModel>?) ?? [];
    final manualExp = (stats['manualExpenses'] as List<VehicleExpenseModel>?) ?? [];

    final cIncome = stats['currentMonthIncome'] as double;
    final cExpenses = stats['currentMonthExpenses'] as double;
    final cProfit = stats['currentMonthProfit'] as double;
    final lProfit = stats['lifetimeProfit'] as double;
    final pctChange = stats['profitChangePct'] as double;

    return Column(
      children: [
        // Modal Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics, color: AppColors.primaryOrange),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${"Financial Report: ".tr(context)}${widget.vehicle.brand} ${widget.vehicle.model}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                      ),
                      Text('${"Plate: ".tr(context)}${widget.vehicle.plateNumber}', style: TextStyle(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ],
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),

        // Navigation Tabs Bar
        Container(
          color: cardColor,
          child: Row(
            children: [
              _buildTabButton(0, 'Overview & Comparison'.tr(context), Icons.insert_chart_outlined),
              _buildTabButton(1, '${"Income".tr(context)} (${bookings.length})', Icons.payments_outlined),
              _buildTabButton(2, '${"Maintenance".tr(context)} (${maintenance.length})', Icons.build_outlined),
              _buildTabButton(3, '${"Other Expenses".tr(context)} (${manualExp.length})', Icons.receipt_long_outlined),
            ],
          ),
        ),

        // Body Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: IndexedStack(
              index: _activeTab,
              children: [
                // 0: OVERVIEW & COMPARISON & CHARTS
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Financial Lifetime & Monthly Overview Cards
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildSummaryCard('Current Month Revenue', 'RM ${cIncome.toStringAsFixed(2)}', Colors.green, cardColor, borderColor, textPrimary, textSecondary),
                        _buildSummaryCard('Current Month Expenses', 'RM ${cExpenses.toStringAsFixed(2)}', Colors.orange, cardColor, borderColor, textPrimary, textSecondary),
                        _buildSummaryCard('Current Month Profit', 'RM ${cProfit.toStringAsFixed(2)}', cProfit >= 0 ? Colors.teal : Colors.redAccent, cardColor, borderColor, textPrimary, textSecondary),
                        _buildSummaryCard('Lifetime Net Profit', 'RM ${lProfit.toStringAsFixed(2)}', Colors.indigo, cardColor, borderColor, textPrimary, textSecondary),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Financial Comparison Table
                    Text('Month-Over-Month Financial Comparison'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                      child: Table(
                        border: TableBorder.symmetric(inside: BorderSide(color: borderColor)),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: isDark ? const Color(0xFF1B2436) : Colors.grey[100]),
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text('Metric'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('Current Month'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('Previous Month'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('Difference / Change'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                          TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text('Revenue'.tr(context), style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('RM ${cIncome.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('RM ${(stats['prevMonthIncome'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('RM ${(stats['incomeDiff'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                            ],
                          ),
                          TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text('Expenses'.tr(context), style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('RM ${cExpenses.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('RM ${(stats['prevMonthExpenses'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('RM ${(stats['expenseDiff'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                            ],
                          ),
                          TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text('Net Profit'.tr(context), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('RM ${cProfit.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cProfit >= 0 ? Colors.teal : Colors.redAccent))),
                              Padding(padding: const EdgeInsets.all(10), child: Text('RM ${(stats['prevMonthProfit'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  '${pctChange >= 0 ? "+" : ""}${pctChange.toStringAsFixed(1)}%',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: pctChange >= 0 ? Colors.green : Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 1: INCOME HISTORY
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paid & Completed Rental Income History'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                    const SizedBox(height: 10),
                    bookings.isEmpty
                        ? Padding(padding: const EdgeInsets.all(20), child: Text('No paid booking income records found for this car.'.tr(context)))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: bookings.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final b = bookings[idx];
                              return ListTile(
                                title: Text('${b.userName} • RM ${b.totalPrice.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                                subtitle: Text('${"Pickup: ".tr(context)}${DateFormat('dd MMM yyyy').format(b.pickUpDate)} • ${"Status: ".tr(context)}${b.status.tr(context).toUpperCase()}'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text('RM ${b.totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                  ],
                ),

                // 2: MAINTENANCE EXPENSES (Auto-integrated)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Vehicle Maintenance Expenses (Auto-Synced)'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text('Auto-synced from Maintenance Page'.tr(context), style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    maintenance.isEmpty
                        ? Padding(padding: const EdgeInsets.all(20), child: Text('No maintenance records for this car.'.tr(context)))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: maintenance.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final m = maintenance[idx];
                              return ListTile(
                                title: Text(m.title, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                                subtitle: Text('${"Date: ".tr(context)}${m.startDate} • ${"Status: ".tr(context)}${m.status.tr(context)}'),
                                trailing: Text('- RM ${m.cost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              );
                            },
                          ),
                  ],
                ),

                // 3: OTHER MANUAL EXPENSES
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Manual Vehicle Expenses (Insurance, Road Tax, etc.)'.tr(context), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text('Add Expense'.tr(context)),
                          onPressed: () => _showAddOrEditExpenseDialog(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    manualExp.isEmpty
                        ? Padding(padding: const EdgeInsets.all(20), child: Text('No manual expenses added yet. Click "Add Expense" to add insurance, tax, wash, or fuel costs.'.tr(context)))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: manualExp.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final exp = manualExp[idx];
                              return ListTile(
                                title: Text('${exp.title} (${exp.category.tr(context)})', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                                subtitle: Text('${"Date: ".tr(context)}${DateFormat('dd MMM yyyy').format(exp.date)} ${exp.description.isNotEmpty ? "• ${exp.description}" : ""}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('- RM ${exp.amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                      onPressed: () => _showAddOrEditExpenseDialog(expense: exp),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      onPressed: () => _confirmAndDeleteExpense(exp),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final bool isSelected = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isSelected ? AppColors.primaryOrange : Colors.transparent, width: 2.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? AppColors.primaryOrange : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label.tr(context),
                style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primaryOrange : Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.tr(context), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
