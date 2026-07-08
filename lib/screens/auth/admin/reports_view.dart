import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';

import '../../../constants/colors.dart';
import '../../../models/user_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/maintenance_job_model.dart';
import '../../../models/review_model.dart';
import '../../../services/file_download_helper.dart' if (dart.library.html) '../../../services/file_download_web.dart' as download_helper;
import '../../../services/company_settings_provider.dart';

class ReportsView extends StatefulWidget {
  final List<BookingModel> bookings;
  final List<PaymentModel> payments;
  final List<VehicleModel> vehicles;
  final List<UserModel> users;
  final List<MaintenanceJobModel> maintenanceJobs;
  final List<ReviewModel> reviews;
  final List<Map<String, dynamic>> rewardTransactions;
  final String? initialPeriod;
  final String? initialType;
  final VoidCallback? onClearAIFilters;

  const ReportsView({
    super.key,
    required this.bookings,
    required this.payments,
    required this.vehicles,
    required this.users,
    required this.maintenanceJobs,
    this.reviews = const [],
    this.rewardTransactions = const [],
    this.initialPeriod,
    this.initialType,
    this.onClearAIFilters,
  });

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  // Filter States
  String _selectedPeriod = 'This Month';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedReportType = 'Bookings';

  // Advanced Filters
  String _selectedBranch = 'All';
  String _selectedVehicle = 'All';
  String _selectedCustomer = 'All';
  String _selectedBookingStatus = 'All';
  String _selectedPaymentStatus = 'All';
  String _selectedVehicleStatus = 'All';
  String _selectedMembershipLevel = 'All';

  // Search and Pagination
  String _searchQuery = '';
  int _currentPage = 1;
  final int _rowsPerPage = 10;
  bool _showAdvancedFilters = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPeriod != null) {
      _selectedPeriod = widget.initialPeriod!;
    }
    if (widget.initialType != null) {
      _selectedReportType = widget.initialType!;
    }
  }

  @override
  void didUpdateWidget(covariant ReportsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPeriod != null && widget.initialPeriod != oldWidget.initialPeriod) {
      setState(() {
        _selectedPeriod = widget.initialPeriod!;
      });
    }
    if (widget.initialType != null && widget.initialType != oldWidget.initialType) {
      setState(() {
        _selectedReportType = widget.initialType!;
      });
    }
  }

  void _clearAIFilters() {
    if (widget.onClearAIFilters != null) {
      widget.onClearAIFilters!();
    }
  }

  // ── Database Helper Lookups ──────────────────────────────────────────────
  VehicleModel? _getVehicleById(String vehicleId) {
    try {
      return widget.vehicles.firstWhere((v) => v.id == vehicleId);
    } catch (_) {
      return null;
    }
  }

  UserModel? _getUserById(String userId) {
    try {
      return widget.users.firstWhere((u) => u.id == userId);
    } catch (_) {
      return null;
    }
  }

  // ── Date Filtering Helper ──────────────────────────────────────────────────
  bool _isDateInPeriod(DateTime date, String period, {DateTime? startDate, DateTime? endDate}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    switch (period) {
      case 'Today':
        return targetDate.isAtSameMomentAs(today);
      case 'Yesterday':
        return targetDate.isAtSameMomentAs(today.subtract(const Duration(days: 1)));
      case 'Last 7 Days':
        final start = today.subtract(const Duration(days: 6));
        return (targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
               (targetDate.isBefore(today) || targetDate.isAtSameMomentAs(today));
      case 'This Week':
        final start = today.subtract(Duration(days: today.weekday - 1));
        return (targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
               (targetDate.isBefore(today) || targetDate.isAtSameMomentAs(today));
      case 'Last Week':
        final start = today.subtract(Duration(days: today.weekday - 1 + 7));
        final end = start.add(const Duration(days: 6));
        return (targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
               (targetDate.isBefore(end) || targetDate.isAtSameMomentAs(end));
      case 'This Month':
        final start = DateTime(today.year, today.month, 1);
        return (targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
               (targetDate.isBefore(today) || targetDate.isAtSameMomentAs(today));
      case 'Last Month':
        final start = DateTime(today.year, today.month - 1, 1);
        final end = DateTime(today.year, today.month, 0);
        return (targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
               (targetDate.isBefore(end) || targetDate.isAtSameMomentAs(end));
      case 'Last 3 Months':
        final start = today.subtract(const Duration(days: 90));
        return (targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
               (targetDate.isBefore(today) || targetDate.isAtSameMomentAs(today));
      case 'Last 6 Months':
        final start = today.subtract(const Duration(days: 180));
        return (targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
               (targetDate.isBefore(today) || targetDate.isAtSameMomentAs(today));
      case 'This Year':
        final start = DateTime(today.year, 1, 1);
        return (targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
               (targetDate.isBefore(today) || targetDate.isAtSameMomentAs(today));
      case 'Last Year':
        final start = DateTime(today.year - 1, 1, 1);
        final end = DateTime(today.year - 1, 12, 31);
        return (targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
               (targetDate.isBefore(end) || targetDate.isAtSameMomentAs(end));
      case 'Custom Date Range':
        if (startDate == null || endDate == null) return true;
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final end = DateTime(endDate.year, endDate.month, endDate.day);
        return (targetDate.isAfter(start) || targetDate.isAtSameMomentAs(start)) && 
               (targetDate.isBefore(end) || targetDate.isAtSameMomentAs(end));
      default:
        return true;
    }
  }

  DateTime? _parseDateString(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd').parse(dateStr);
      } catch (_) {}
    }
    return null;
  }

  // ── Filtering Logic ────────────────────────────────────────────────────────
  List<BookingModel> _getFilteredBookings() {
    return widget.bookings.where((b) {
      if (!_isDateInPeriod(b.pickUpDate, _selectedPeriod, startDate: _startDate, endDate: _endDate)) return false;
      if (_selectedBranch != 'All') {
        final v = _getVehicleById(b.vehicleId);
        if (v == null || (v.branchName != _selectedBranch && v.branchId != _selectedBranch)) return false;
      }
      if (_selectedVehicle != 'All' && b.vehicleId != _selectedVehicle) return false;
      if (_selectedCustomer != 'All' && b.userId != _selectedCustomer) return false;
      if (_selectedBookingStatus != 'All' && b.status.toLowerCase() != _selectedBookingStatus.toLowerCase()) return false;
      if (_selectedVehicleStatus != 'All') {
        final v = _getVehicleById(b.vehicleId);
        if (v == null || v.status.toLowerCase() != _selectedVehicleStatus.toLowerCase()) return false;
      }
      if (_selectedMembershipLevel != 'All') {
        final u = _getUserById(b.userId);
        if (u == null || CompanySettingsProvider().determineLevel(u.rewardPoints) != _selectedMembershipLevel) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!b.id.toLowerCase().contains(q) &&
            !b.vehicleName.toLowerCase().contains(q) &&
            !b.userName.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<PaymentModel> _getFilteredPayments() {
    return widget.payments.where((p) {
      if (!_isDateInPeriod(p.paymentDate, _selectedPeriod, startDate: _startDate, endDate: _endDate)) return false;
      final b = widget.bookings.firstWhere((bk) => bk.id == p.bookingId, orElse: () => BookingModel(id: '', vehicleId: '', vehicleName: '', userId: '', userName: '', userPhone: '', pickUpDate: DateTime.now(), totalPrice: 0.0, depositAmount: 0.0, status: '', createdAt: DateTime.now()));
      if (b.id.isNotEmpty) {
        if (_selectedBranch != 'All') {
          final v = _getVehicleById(b.vehicleId);
          if (v == null || (v.branchName != _selectedBranch && v.branchId != _selectedBranch)) return false;
        }
        if (_selectedVehicle != 'All' && b.vehicleId != _selectedVehicle) return false;
        if (_selectedBookingStatus != 'All' && b.status.toLowerCase() != _selectedBookingStatus.toLowerCase()) return false;
        if (_selectedVehicleStatus != 'All') {
          final v = _getVehicleById(b.vehicleId);
          if (v == null || v.status.toLowerCase() != _selectedVehicleStatus.toLowerCase()) return false;
        }
      } else if (_selectedBranch != 'All' || _selectedVehicle != 'All' || _selectedBookingStatus != 'All' || _selectedVehicleStatus != 'All') {
        return false;
      }
      if (_selectedCustomer != 'All' && p.userId != _selectedCustomer) return false;
      final status = (p.paymentStatus ?? p.status).toLowerCase();
      if (_selectedPaymentStatus != 'All' && status != _selectedPaymentStatus.toLowerCase()) return false;
      if (_selectedMembershipLevel != 'All') {
        final u = _getUserById(p.userId);
        if (u == null || CompanySettingsProvider().determineLevel(u.rewardPoints) != _selectedMembershipLevel) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!p.id.toLowerCase().contains(q) && !p.bookingId.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<VehicleModel> _getFilteredVehicles() {
    return widget.vehicles.where((v) {
      final vDate = _parseDateString(v.createdAt);
      if (vDate != null && !_isDateInPeriod(vDate, _selectedPeriod, startDate: _startDate, endDate: _endDate)) return false;
      if (_selectedBranch != 'All' && v.branchName != _selectedBranch && v.branchId != _selectedBranch) return false;
      if (_selectedVehicle != 'All' && v.id != _selectedVehicle) return false;
      if (_selectedVehicleStatus != 'All' && v.status.toLowerCase() != _selectedVehicleStatus.toLowerCase()) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!v.brand.toLowerCase().contains(q) && !v.model.toLowerCase().contains(q) && !v.plateNumber.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<UserModel> _getFilteredCustomers() {
    return widget.users.where((u) => u.role == 'customer').where((u) {
      final uDate = _parseDateString(u.createdAt);
      if (uDate != null && !_isDateInPeriod(uDate, _selectedPeriod, startDate: _startDate, endDate: _endDate)) return false;
      if (_selectedCustomer != 'All' && u.id != _selectedCustomer) return false;
      if (_selectedMembershipLevel != 'All' && CompanySettingsProvider().determineLevel(u.rewardPoints) != _selectedMembershipLevel) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!u.fullName.toLowerCase().contains(q) && !u.email.toLowerCase().contains(q) && !u.phone.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<MaintenanceJobModel> _getFilteredMaintenance() {
    return widget.maintenanceJobs.where((j) {
      final jDate = _parseDateString(j.startDate);
      if (jDate != null && !_isDateInPeriod(jDate, _selectedPeriod, startDate: _startDate, endDate: _endDate)) return false;
      if (_selectedBranch != 'All') {
        final v = _getVehicleById(j.vehicleId);
        if (v == null || (v.branchName != _selectedBranch && v.branchId != _selectedBranch)) return false;
      }
      if (_selectedVehicle != 'All' && j.vehicleId != _selectedVehicle) return false;
      if (_selectedVehicleStatus != 'All') {
        final v = _getVehicleById(j.vehicleId);
        if (v == null || v.status.toLowerCase() != _selectedVehicleStatus.toLowerCase()) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!j.title.toLowerCase().contains(q) && !j.vehicleName.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<ReviewModel> _getFilteredReviews() {
    return widget.reviews.where((r) {
      if (!_isDateInPeriod(r.createdAt, _selectedPeriod, startDate: _startDate, endDate: _endDate)) return false;
      if (_selectedBranch != 'All') {
        final v = _getVehicleById(r.vehicleId);
        if (v == null || (v.branchName != _selectedBranch && v.branchId != _selectedBranch)) return false;
      }
      if (_selectedVehicle != 'All' && r.vehicleId != _selectedVehicle) return false;
      if (_selectedCustomer != 'All' && r.userId != _selectedCustomer) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!r.userName.toLowerCase().contains(q) && !r.comment.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredRewardTransactions() {
    return widget.rewardTransactions.where((tx) {
      final txDate = _parseDateString(tx['createdAt'] ?? '');
      if (txDate != null && !_isDateInPeriod(txDate, _selectedPeriod, startDate: _startDate, endDate: _endDate)) return false;
      if (_selectedCustomer != 'All' && tx['userId'] != _selectedCustomer) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final reason = (tx['reason'] ?? '').toString().toLowerCase();
        final type = (tx['type'] ?? '').toString().toLowerCase();
        if (!reason.contains(q) && !type.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  // ── Aggregated KPI Calculations ────────────────────────────────────────────
  Map<String, dynamic> _calculateKPIs() {
    final filteredBookings = _getFilteredBookings();
    final filteredPayments = _getFilteredPayments();
    final filteredMaintenance = _getFilteredMaintenance();
    final filteredRewardTxs = _getFilteredRewardTransactions();

    int totalBookings = filteredBookings.length;
    int completedBookings = filteredBookings.where((b) => b.status.toLowerCase() == 'completed' || b.isReturned).length;
    int cancelledBookings = filteredBookings.where((b) => b.status.toLowerCase() == 'cancelled' || b.status.toLowerCase() == 'rejected').length;
    int activeBookings = filteredBookings.where((b) => b.status.toLowerCase() == 'approved' || b.status.toLowerCase() == 'confirmed' || b.status.toLowerCase() == 'ongoing' || b.status.toLowerCase() == 'active').length;
    int overdueBookings = filteredBookings.where((b) => b.status.toLowerCase() == 'overdue').length;

    double totalRevenue = 0.0;
    int completedPayments = 0;
    for (var p in filteredPayments) {
      final status = (p.paymentStatus ?? p.status).toLowerCase();
      if (status == 'paid' || status == 'approved') {
        totalRevenue += p.amount;
        completedPayments++;
      }
    }
    int pendingPayments = filteredPayments.where((p) {
      final status = (p.paymentStatus ?? p.status).toLowerCase();
      return status == 'pending' || status == 'pending verification';
    }).length;

    double totalDuration = 0;
    for (var b in filteredBookings) {
      totalDuration += b.rentalDays;
    }
    double avgDuration = totalBookings > 0 ? totalDuration / totalBookings : 0.0;

    // Most Rented Vehicle
    String mostRentedVehicle = 'N/A';
    if (filteredBookings.isNotEmpty) {
      final Map<String, int> vehicleCounts = {};
      for (var b in filteredBookings) {
        vehicleCounts[b.vehicleName] = (vehicleCounts[b.vehicleName] ?? 0) + 1;
      }
      final sorted = vehicleCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      mostRentedVehicle = sorted.first.key;
    }

    // Most Active Customer
    String mostActiveCustomer = 'N/A';
    if (filteredBookings.isNotEmpty) {
      final Map<String, int> customerCounts = {};
      for (var b in filteredBookings) {
        customerCounts[b.userName] = (customerCounts[b.userName] ?? 0) + 1;
      }
      final sorted = customerCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      mostActiveCustomer = sorted.first.key;
    }

    int maintenanceJobs = filteredMaintenance.length;

    int rewardPointsIssued = 0;
    for (var tx in filteredRewardTxs) {
      final pts = tx['points'] as int? ?? 0;
      final type = (tx['type'] ?? '').toString();
      if (type == 'Earn' || type == 'Earned' || (type == 'Adjustment' && pts > 0)) {
        rewardPointsIssued += pts.abs();
      }
    }

    return {
      'totalBookings': totalBookings,
      'completedBookings': completedBookings,
      'cancelledBookings': cancelledBookings,
      'activeBookings': activeBookings,
      'revenue': totalRevenue,
      'pendingPayments': pendingPayments,
      'completedPayments': completedPayments,
      'avgDuration': avgDuration,
      'mostRentedVehicle': mostRentedVehicle,
      'mostActiveCustomer': mostActiveCustomer,
      'overdueBookings': overdueBookings,
      'maintenanceJobs': maintenanceJobs,
      'rewardPointsIssued': rewardPointsIssued,
    };
  }

  // ── Document Export Naming Helper ──────────────────────────────────────────
  String _getExportFileName(String reportType, String extension) {
    String periodStr = _selectedPeriod.replaceAll(' ', '_');
    if (_selectedPeriod == 'This Month') {
      periodStr = DateFormat('MMMM_yyyy').format(DateTime.now());
    } else if (_selectedPeriod == 'Last Month') {
      final prevMonth = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
      periodStr = DateFormat('MMMM_yyyy').format(prevMonth);
    } else if (_selectedPeriod == 'Custom Date Range') {
      final startStr = DateFormat('ddMMMyyyy').format(_startDate ?? DateTime.now());
      final endStr = DateFormat('ddMMMyyyy').format(_endDate ?? DateTime.now());
      periodStr = '${startStr}_to_$endStr';
    }
    return '${reportType}_Report_$periodStr.$extension';
  }

  // ── CSV Exporter ───────────────────────────────────────────────────────────
  void _exportCSV() {
    final type = _selectedReportType;
    final List<String> headers = _getReportHeaders(type);
    final List<List<String>> tableData = _getReportTableData(type);

    final buffer = StringBuffer();
    // Write Headers
    buffer.writeln(headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','));
    // Write Rows
    for (final row in tableData) {
      buffer.writeln(row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','));
    }

    final bytes = utf8.encode(buffer.toString());
    final fileName = _getExportFileName(type, 'csv');
    download_helper.downloadFile(Uint8List.fromList(bytes), fileName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$type report downloaded in CSV format!'), backgroundColor: Colors.green),
    );
  }

  // ── Excel Exporter ─────────────────────────────────────────────────────────
  void _exportExcel() {
    final type = _selectedReportType;
    var excelObj = Excel.createExcel();
    var sheet = excelObj[excelObj.getDefaultSheet() ?? 'Sheet1'];

    final List<String> headers = _getReportHeaders(type);
    final List<List<String>> tableData = _getReportTableData(type);

    // Header Row
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    // Data Rows
    for (final row in tableData) {
      sheet.appendRow(row.map((cell) {
        // Try parsing number
        final numVal = double.tryParse(cell.replaceAll('RM', '').replaceAll(' ', '').trim());
        if (numVal != null && !cell.contains(':') && !cell.contains('/')) {
          return DoubleCellValue(numVal);
        }
        return TextCellValue(cell);
      }).toList());
    }

    final fileBytes = excelObj.save();
    if (fileBytes != null) {
      final fileName = _getExportFileName(type, 'xlsx');
      download_helper.downloadFile(Uint8List.fromList(fileBytes), fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type report downloaded in Excel format!'), backgroundColor: Colors.green),
      );
    }
  }

  // ── PDF Exporter ───────────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    final type = _selectedReportType;
    final pdf = pw.Document();

    final List<String> headers = _getReportHeaders(type);
    final List<List<String>> tableData = _getReportTableData(type);
    final kpis = _calculateKPIs();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pdf_lib.PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('CARENT PLATFORM REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: pdf_lib.PdfColor.fromInt(0xFF1E3A8A))),
                pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10, color: pdf_lib.PdfColor.fromInt(0xFF6B7280))),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            // Subtitle & Filter Configuration
            pw.Text('$type Analysis - Period: $_selectedPeriod', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: pdf_lib.PdfColor.fromInt(0xFF374151))),
            pw.SizedBox(height: 5),
            pw.Text('Filters Active: Branch ($_selectedBranch), Vehicle ($_selectedVehicle), Customer ($_selectedCustomer)', style: pw.TextStyle(fontSize: 8, color: pdf_lib.PdfColor.fromInt(0xFF6B7280))),
            pw.SizedBox(height: 15),

            // Aggregate Metrics Block
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: pdf_lib.PdfColor.fromInt(0xFFF3F4F6),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Summary Aggregates', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: pdf_lib.PdfColor.fromInt(0xFF1F2937))),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Bookings: ${kpis['totalBookings']}', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Revenue: RM ${kpis['revenue'].toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Active Rentals: ${kpis['activeBookings']}', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Overdue Bookings: ${kpis['overdueBookings']}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Avg Duration: ${kpis['avgDuration'].toStringAsFixed(1)} Days', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Most Active: ${kpis['mostActiveCustomer']}', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Maintenance Jobs: ${kpis['maintenanceJobs']}', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Rewards Issued: ${kpis['rewardPointsIssued']} Points', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Data Table
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: tableData,
              border: pw.TableBorder.all(width: 0.5, color: pdf_lib.PdfColor.fromInt(0xFFE5E7EB)),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdf_lib.PdfColors.white, fontSize: 8),
              headerDecoration: pw.BoxDecoration(color: pdf_lib.PdfColor.fromInt(0xFF1E3A8A)),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 7),
              columnWidths: {
                0: const pw.FixedColumnWidth(100),
                1: const pw.FixedColumnWidth(100),
              },
            ),
            
            // Footer
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 5),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Confidential Business Record | Page 1 of 1', style: pw.TextStyle(fontSize: 7, color: pdf_lib.PdfColor.fromInt(0xFF9CA3AF))),
            ),
          ];
        },
      ),
    );

    final fileBytes = await pdf.save();
    final fileName = _getExportFileName(type, 'pdf');
    download_helper.downloadFile(fileBytes, fileName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type report downloaded in PDF format!'), backgroundColor: Colors.green),
      );
    }
  }

  // ── Table Schema Configurations ────────────────────────────────────────────
  List<String> _getReportHeaders(String type) {
    switch (type) {
      case 'Bookings':
        return ['Booking ID', 'Vehicle', 'Customer', 'Pickup Date', 'Return Date', 'Total Price', 'Status'];
      case 'Payments':
        return ['Payment ID', 'Booking ID', 'Amount', 'Method', 'Status', 'Transaction ID', 'Date'];
      case 'Revenue':
        return ['Payment ID', 'Booking ID', 'Amount', 'Method', 'Status', 'Date'];
      case 'Vehicles':
        return ['Brand & Model', 'Plate Number', 'Category', 'Daily Rate', 'Mileage', 'Branch', 'Status'];
      case 'Maintenance':
        return ['Job Title', 'Vehicle', 'Cost', 'Start Date', 'End Date', 'Status'];
      case 'Customers':
        return ['Name', 'Email', 'Phone', 'Membership Level', 'Points', 'Verified', 'Active'];
      case 'Reward Points':
        return ['User ID', 'Booking ID', 'Type', 'Points Change', 'Balance After', 'Reason', 'Date'];
      case 'Reviews':
        return ['Customer', 'Vehicle ID', 'Rating', 'Comment', 'Date'];
      case 'Open Rentals':
        return ['Booking ID', 'Vehicle', 'Customer', 'Pickup Date', 'Status'];
      case 'Overdue Rentals':
        return ['Booking ID', 'Vehicle', 'Customer', 'Due Date', 'Status'];
      default:
        return [];
    }
  }

  List<List<String>> _getReportTableData(String type) {
    switch (type) {
      case 'Bookings':
        return _getFilteredBookings().map((b) => [
          b.id.substring(0, min(8, b.id.length)),
          b.vehicleName,
          b.userName,
          DateFormat('dd/MM/yyyy').format(b.pickUpDate),
          b.isOpenRental ? 'Open Rental' : (b.returnDate != null ? DateFormat('dd/MM/yyyy').format(b.returnDate!) : 'N/A'),
          'RM ${b.totalPrice.toStringAsFixed(2)}',
          b.status.toUpperCase(),
        ]).toList();
      case 'Payments':
        return _getFilteredPayments().map((p) => [
          p.id.substring(0, min(8, p.id.length)),
          p.bookingId.substring(0, min(8, p.bookingId.length)),
          'RM ${p.amount.toStringAsFixed(2)}',
          p.paymentMethod,
          (p.paymentStatus ?? p.status).toUpperCase(),
          p.transactionId ?? 'N/A',
          DateFormat('dd/MM/yyyy').format(p.paymentDate),
        ]).toList();
      case 'Revenue':
        return _getFilteredPayments().where((p) {
          final s = (p.paymentStatus ?? p.status).toLowerCase();
          return s == 'paid' || s == 'approved';
        }).map((p) => [
          p.id.substring(0, min(8, p.id.length)),
          p.bookingId.substring(0, min(8, p.bookingId.length)),
          'RM ${p.amount.toStringAsFixed(2)}',
          p.paymentMethod,
          (p.paymentStatus ?? p.status).toUpperCase(),
          DateFormat('dd/MM/yyyy').format(p.paymentDate),
        ]).toList();
      case 'Vehicles':
        return _getFilteredVehicles().map((v) => [
          '${v.brand} ${v.model}',
          v.plateNumber,
          v.category,
          'RM ${v.pricePerDay.toStringAsFixed(2)}',
          '${v.mileage} KM',
          v.branchName.isEmpty ? 'Main Hub' : v.branchName,
          v.status.toUpperCase(),
        ]).toList();
      case 'Maintenance':
        return _getFilteredMaintenance().map((j) => [
          j.title,
          j.vehicleName,
          'RM ${j.cost.toStringAsFixed(2)}',
          j.startDate,
          j.endDate,
          j.status.toUpperCase(),
        ]).toList();
      case 'Customers':
        return _getFilteredCustomers().map((c) => [
          c.fullName,
          c.email,
          c.phone.isEmpty ? 'N/A' : c.phone,
          CompanySettingsProvider().determineLevel(c.rewardPoints),
          '${c.rewardPoints} pts',
          c.isVerified ? 'YES' : 'NO',
          c.isActive ? 'YES' : 'NO',
        ]).toList();
      case 'Reward Points':
        return _getFilteredRewardTransactions().map((tx) {
          final uId = tx['userId']?.toString() ?? '';
          final user = _getUserById(uId);
          return <String>[
            user?.fullName ?? uId.substring(0, min(6, uId.length)),
            (tx['bookingId'] ?? '').toString().substring(0, min(8, (tx['bookingId'] ?? '').toString().length)),
            (tx['type'] ?? '').toString().toUpperCase(),
            '${tx['points'] ?? 0}',
            '${tx['balanceAfter'] ?? 0}',
            (tx['reason'] ?? tx['comment'] ?? 'Loyalty Action').toString(),
            tx['createdAt'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(tx['createdAt'])) : 'N/A',
          ];
        }).toList();
      case 'Reviews':
        return _getFilteredReviews().map((r) => [
          r.userName,
          r.vehicleId.substring(0, min(8, r.vehicleId.length)),
          '${r.rating} ⭐',
          r.comment,
          DateFormat('dd/MM/yyyy').format(r.createdAt),
        ]).toList();
      case 'Open Rentals':
        return _getFilteredBookings().where((b) => b.isOpenRental).map((b) => [
          b.id.substring(0, min(8, b.id.length)),
          b.vehicleName,
          b.userName,
          DateFormat('dd/MM/yyyy').format(b.pickUpDate),
          b.status.toUpperCase(),
        ]).toList();
      case 'Overdue Rentals':
        return _getFilteredBookings().where((b) => b.status.toLowerCase() == 'overdue').map((b) => [
          b.id.substring(0, min(8, b.id.length)),
          b.vehicleName,
          b.userName,
          b.returnDate != null ? DateFormat('dd/MM/yyyy').format(b.returnDate!) : 'N/A',
          b.status.toUpperCase(),
        ]).toList();
      default:
        return [];
    }
  }

  // ── Render Method ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final isTablet = width > 600 && width <= 900;

    final kpis = _calculateKPIs();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          _buildHeaderRow(textPrimary, textSecondary, cardColor, borderColor),
          const SizedBox(height: 24),

          // Time period & Custom Range Selector
          _buildTimeframeCard(cardColor, textPrimary, textSecondary, borderColor),
          const SizedBox(height: 20),

          // Advanced Filter Accordion Panel
          _buildAdvancedFiltersPanel(cardColor, textPrimary, textSecondary, borderColor),
          const SizedBox(height: 24),

          // 13 KPI Metric Summary Grid
          _buildKPIGrid(kpis, isDesktop, isTablet, cardColor, textPrimary, textSecondary, borderColor),
          const SizedBox(height: 32),

          // Interactive Custom Charts Panel
          _buildChartsSection(isDesktop, cardColor, textPrimary, textSecondary, borderColor),
          const SizedBox(height: 32),

          // Detailed Table Section
          _buildDetailedTableSection(cardColor, textPrimary, textSecondary, borderColor),
        ],
      ),
    );
  }

  // ── UI Components Builders ──────────────────────────────────────────────────
  Widget _buildHeaderRow(Color textPrimary, Color textSecondary, Color cardColor, Color borderColor) {
    final hasActiveAIFilters = widget.initialPeriod != null || widget.initialType != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Operations Reports Center', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textPrimary)),
                  if (hasActiveAIFilters) ...[
                    const SizedBox(width: 12),
                    Chip(
                      label: const Text('AI Synced', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.primaryOrange,
                      deleteIcon: const Icon(Icons.close, size: 12, color: Colors.white),
                      onDeleted: _clearAIFilters,
                    ),
                  ],
                ],
              ),
              Text('Generate operational analytics ledgers based on filters and custom date periods.', style: TextStyle(fontSize: 13, color: textSecondary)),
            ],
          ),
        ),
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
              onPressed: _exportCSV,
              icon: const Icon(Icons.file_download, size: 16),
              label: const Text('CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white),
              onPressed: _exportExcel,
              icon: const Icon(Icons.table_view, size: 16),
              label: const Text('Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeframeCard(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    final isCustom = _selectedPeriod == 'Custom Date Range';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, color: AppColors.primaryOrange, size: 20),
              const SizedBox(width: 8),
              Text('Report Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Today',
              'Yesterday',
              'Last 7 Days',
              'This Week',
              'Last Week',
              'This Month',
              'Last Month',
              'Last 3 Months',
              'Last 6 Months',
              'This Year',
              'Last Year',
              'Custom Date Range',
            ].map((p) {
              final isSel = _selectedPeriod == p;
              return ChoiceChip(
                label: Text(p, style: TextStyle(color: isSel ? Colors.white : textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                selected: isSel,
                selectedColor: AppColors.primaryOrange,
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: isSel ? Colors.transparent : borderColor),
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedPeriod = p;
                      _currentPage = 1;
                      _clearAIFilters();
                    });
                  }
                },
              );
            }).toList(),
          ),
          if (isCustom) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          _startDate = date;
                          _currentPage = 1;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(_startDate == null ? 'Select Start Date' : DateFormat('dd MMM yyyy').format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          _endDate = date;
                          _currentPage = 1;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(_endDate == null ? 'Select End Date' : DateFormat('dd MMM yyyy').format(_endDate!)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedFiltersPanel(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.tune, color: AppColors.primaryOrange, size: 20),
            title: Text('Advanced filters & segments', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
            subtitle: Text('Filter by Branch, Customer, Statuses, Vehicle properties', style: TextStyle(fontSize: 11, color: textSecondary)),
            trailing: IconButton(
              icon: Icon(_showAdvancedFilters ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
            ),
          ),
          if (_showAdvancedFilters) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.8,
                    children: [
                      // Branch Dropdown
                      _buildFilterDropdown('Branch Location', _selectedBranch, ['All', 'Kuala Lumpur', 'Main Hub', 'Kajang', 'PenangHub'], (val) {
                        setState(() => _selectedBranch = val!);
                      }, textPrimary, textSecondary),
                      // Vehicle Dropdown
                      _buildFilterDropdown('Vehicle', _selectedVehicle, ['All', ...widget.vehicles.map((v) => v.id)], (val) {
                        setState(() => _selectedVehicle = val!);
                      }, textPrimary, textSecondary, itemLabelBuilder: (val) {
                        if (val == 'All') return 'All Vehicles';
                        final v = _getVehicleById(val);
                        return v != null ? '${v.brand} ${v.model} (${v.plateNumber})' : val;
                      }),
                      // Customer Dropdown
                      _buildFilterDropdown('Customer', _selectedCustomer, ['All', ...widget.users.where((u) => u.role == 'customer').map((u) => u.id)], (val) {
                        setState(() => _selectedCustomer = val!);
                      }, textPrimary, textSecondary, itemLabelBuilder: (val) {
                        if (val == 'All') return 'All Customers';
                        final u = _getUserById(val);
                        return u != null ? u.fullName : val;
                      }),
                      // Booking Status
                      _buildFilterDropdown('Booking Status', _selectedBookingStatus, ['All', 'Pending', 'Approved', 'Confirmed', 'Ongoing', 'Completed', 'Cancelled', 'Overdue'], (val) {
                        setState(() => _selectedBookingStatus = val!);
                      }, textPrimary, textSecondary),
                      // Payment Status
                      _buildFilterDropdown('Payment Status', _selectedPaymentStatus, ['All', 'Pending', 'Paid', 'Approved', 'Rejected'], (val) {
                        setState(() => _selectedPaymentStatus = val!);
                      }, textPrimary, textSecondary),
                      // Vehicle Availability Status
                      _buildFilterDropdown('Vehicle Status', _selectedVehicleStatus, ['All', 'Available', 'Booked', 'Maintenance', 'Inactive'], (val) {
                        setState(() => _selectedVehicleStatus = val!);
                      }, textPrimary, textSecondary),
                      // Membership Levels
                      _buildFilterDropdown('Membership Level', _selectedMembershipLevel, ['All', 'Bronze', 'Silver', 'Gold', 'Premium'], (val) {
                        setState(() => _selectedMembershipLevel = val!);
                      }, textPrimary, textSecondary),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedBranch = 'All';
                            _selectedVehicle = 'All';
                            _selectedCustomer = 'All';
                            _selectedBookingStatus = 'All';
                            _selectedPaymentStatus = 'All';
                            _selectedVehicleStatus = 'All';
                            _selectedMembershipLevel = 'All';
                            _searchQuery = '';
                            _currentPage = 1;
                          });
                        },
                        child: const Text('Reset All Filters', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged, Color textPrimary, Color textSecondary, {String Function(String)? itemLabelBuilder}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
        const SizedBox(height: 4),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
            ),
            style: TextStyle(color: textPrimary, fontSize: 11),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  itemLabelBuilder != null ? itemLabelBuilder(item) : item,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildKPIGrid(Map<String, dynamic> kpis, bool isDesktop, bool isTablet, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    int crossAxisCount = 5;
    if (!isDesktop) {
      crossAxisCount = isTablet ? 3 : 2;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.35,
      children: [
        _buildMetricCard('Total Bookings', '${kpis['totalBookings']}', Icons.bookmark_added_rounded, Colors.purple, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Completed Bookings', '${kpis['completedBookings']}', Icons.verified_rounded, Colors.green, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Cancelled Bookings', '${kpis['cancelledBookings']}', Icons.cancel_outlined, Colors.red, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Active Rentals', '${kpis['activeBookings']}', Icons.directions_car_rounded, Colors.blue, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Total Revenue', 'RM ${kpis['revenue'].toStringAsFixed(2)}', Icons.payments_rounded, Colors.teal, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Pending Payments', '${kpis['pendingPayments']}', Icons.hourglass_empty_rounded, Colors.orange, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Cleared Payments', '${kpis['completedPayments']}', Icons.check_circle_rounded, Colors.greenAccent[700]!, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Avg Duration', '${kpis['avgDuration'].toStringAsFixed(1)} Days', Icons.timelapse_rounded, Colors.indigo, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Popular Vehicle', kpis['mostRentedVehicle'], Icons.stars_rounded, Colors.amber, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Active Customer', kpis['mostActiveCustomer'], Icons.person_pin_rounded, Colors.cyan, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Overdue Bookings', '${kpis['overdueBookings']}', Icons.alarm_on_rounded, Colors.pink, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Maintenance Jobs', '${kpis['maintenanceJobs']}', Icons.build_circle_rounded, Colors.blueGrey, cardColor, textPrimary, textSecondary, borderColor),
        _buildMetricCard('Reward Points Issued', '${kpis['rewardPointsIssued']} pts', Icons.military_tech_rounded, Colors.deepOrange, cardColor, textPrimary, textSecondary, borderColor),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(title, style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold))),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary), overflow: TextOverflow.ellipsis, maxLines: 2),
        ],
      ),
    );
  }

  // ── Charts Implementation ──────────────────────────────────────────────────
  Widget _buildChartsSection(bool isDesktop, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interactive Analytics & Visuals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 16),
            if (isWide) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildRevenueAndBookingsChartCard(cardColor, textPrimary, textSecondary, borderColor)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildPaymentsAndVehicleUsageCard(cardColor, textPrimary, textSecondary, borderColor)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildOverdueAndMaintenanceChartCard(cardColor, textPrimary, textSecondary, borderColor)),
                ],
              ),
            ] else ...[
              _buildRevenueAndBookingsChartCard(cardColor, textPrimary, textSecondary, borderColor),
              const SizedBox(height: 20),
              _buildPaymentsAndVehicleUsageCard(cardColor, textPrimary, textSecondary, borderColor),
              const SizedBox(height: 20),
              _buildOverdueAndMaintenanceChartCard(cardColor, textPrimary, textSecondary, borderColor),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRevenueAndBookingsChartCard(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    final filteredPayments = _getFilteredPayments().where((p) {
      final s = (p.paymentStatus ?? p.status).toLowerCase();
      return s == 'paid' || s == 'approved';
    }).toList();

    // Group revenue by date
    final Map<String, double> revenueByDate = {};
    for (var p in filteredPayments) {
      final dStr = DateFormat('dd MMM').format(p.paymentDate);
      revenueByDate[dStr] = (revenueByDate[dStr] ?? 0.0) + p.amount;
    }
    final revEntries = revenueByDate.entries.toList();
    if (revEntries.length > 7) {
      revEntries.removeRange(7, revEntries.length); // limit to 7 points for visual clarity
    }

    final filteredBookings = _getFilteredBookings();
    final Map<String, int> bookingsByDate = {};
    for (var b in filteredBookings) {
      final dStr = DateFormat('dd MMM').format(b.pickUpDate);
      bookingsByDate[dStr] = (bookingsByDate[dStr] ?? 0) + 1;
    }
    final bookingEntries = bookingsByDate.entries.toList();
    if (bookingEntries.length > 7) {
      bookingEntries.removeRange(7, bookingEntries.length);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue and Bookings Trends', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 16),
          Text('Approved Revenue Trend (Last 7 Active Days)', style: TextStyle(fontSize: 11, color: textSecondary)),
          const SizedBox(height: 10),
          Container(
            height: 140,
            padding: const EdgeInsets.only(top: 10),
            child: revEntries.isEmpty
                ? const Center(child: Text('No revenue records in this period'))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: revEntries.map((e) {
                      final maxVal = revEntries.map((entry) => entry.value).reduce(max);
                      final pct = maxVal > 0 ? e.value / maxVal : 0.0;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('RM ${e.value.toStringAsFixed(0)}', style: TextStyle(fontSize: 8, color: textPrimary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            width: 24,
                            height: 80 * pct,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.green, Colors.teal[300]!], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(e.key, style: TextStyle(fontSize: 8, color: textSecondary)),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Text('Booking Volume Trend (Last 7 Active Days)', style: TextStyle(fontSize: 11, color: textSecondary)),
          const SizedBox(height: 10),
          Container(
            height: 140,
            padding: const EdgeInsets.only(top: 10),
            child: bookingEntries.isEmpty
                ? const Center(child: Text('No bookings records in this period'))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: bookingEntries.map((e) {
                      final maxVal = bookingEntries.map((entry) => entry.value).reduce(max);
                      final pct = maxVal > 0 ? e.value / maxVal : 0.0;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${e.value}', style: TextStyle(fontSize: 8, color: textPrimary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            width: 24,
                            height: 80 * pct,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.purple, Colors.pink[300]!], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(e.key, style: TextStyle(fontSize: 8, color: textSecondary)),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsAndVehicleUsageCard(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    final filteredPayments = _getFilteredPayments();
    final Map<String, double> methodAmounts = {};
    for (var p in filteredPayments) {
      final method = p.paymentMethod.isEmpty ? 'FPX' : p.paymentMethod;
      methodAmounts[method] = (methodAmounts[method] ?? 0.0) + p.amount;
    }
    final methodEntries = methodAmounts.entries.toList();

    final filteredBookings = _getFilteredBookings();
    final Map<String, int> vehicleCounts = {};
    for (var b in filteredBookings) {
      vehicleCounts[b.vehicleName] = (vehicleCounts[b.vehicleName] ?? 0) + 1;
    }
    final usageEntries = vehicleCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topUsage = usageEntries.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payments & Vehicle Usage Metrics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 20),
          Text('Payment Volume Distribution by Method', style: TextStyle(fontSize: 11, color: textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: methodEntries.isEmpty
                ? const Center(child: Text('No payment methods recorded'))
                : Row(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CustomPaint(
                          painter: DonutChartPainter(
                            values: methodEntries.map((e) => e.value).toList(),
                            colors: const [Colors.amber, Colors.blue, Colors.teal, Colors.purple],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(methodEntries.length, (idx) {
                            final e = methodEntries[idx];
                            final colors = const [Colors.amber, Colors.blue, Colors.teal, Colors.purple];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, color: colors[idx % colors.length]),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('${e.key}: RM ${e.value.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: textPrimary), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            );
                          }),
                        ),
                      )
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Text('Top Active Rented Fleet Units', style: TextStyle(fontSize: 11, color: textSecondary)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: topUsage.isEmpty
                ? const Center(child: Text('No active rental logs in this period'))
                : Column(
                    children: topUsage.map((e) {
                      final maxVal = topUsage.first.value;
                      final pct = maxVal > 0 ? e.value / maxVal : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            SizedBox(width: 100, child: Text(e.key, style: TextStyle(fontSize: 10, color: textPrimary), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  backgroundColor: borderColor,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${e.value} times', style: TextStyle(fontSize: 10, color: textSecondary)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueAndMaintenanceChartCard(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    final filteredBookings = _getFilteredBookings();
    final overdueCount = filteredBookings.where((b) => b.status.toLowerCase() == 'overdue').length;
    final onTimeCount = filteredBookings.where((b) => b.status.toLowerCase() == 'completed' || b.status.toLowerCase() == 'returned').length;

    final filteredMaintenance = _getFilteredMaintenance();
    double totalMaintCost = 0.0;
    final Map<String, double> maintCostsByVehicle = {};
    for (var j in filteredMaintenance) {
      totalMaintCost += j.cost;
      maintCostsByVehicle[j.vehicleName] = (maintCostsByVehicle[j.vehicleName] ?? 0.0) + j.cost;
    }
    final topMaint = maintCostsByVehicle.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final limitMaint = topMaint.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overdue Reservations & Maintenance Cost Analytics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final childWidget = [
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overdue vs Completed Rentals Ratio', style: TextStyle(fontSize: 11, color: textSecondary)),
                      const SizedBox(height: 12),
                      Container(
                        height: 110,
                        padding: const EdgeInsets.only(top: 10),
                        child: (overdueCount == 0 && onTimeCount == 0)
                            ? const Center(child: Text('No relevant booking logs'))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('$overdueCount', style: TextStyle(fontSize: 9, color: textPrimary, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 32,
                                        height: overdueCount + onTimeCount > 0 ? (overdueCount / (overdueCount + onTimeCount)) * 80 : 0.0,
                                        color: Colors.redAccent,
                                      ),
                                      const SizedBox(height: 6),
                                      const Text('Overdue', style: TextStyle(fontSize: 8, color: Colors.redAccent)),
                                    ],
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('$onTimeCount', style: TextStyle(fontSize: 9, color: textPrimary, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 32,
                                        height: overdueCount + onTimeCount > 0 ? (onTimeCount / (overdueCount + onTimeCount)) * 80 : 0.0,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(height: 6),
                                      const Text('Returned', style: TextStyle(fontSize: 8, color: Colors.green)),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                if (!isWide) const SizedBox(height: 20),
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fleet Maintenance Costs by Vehicle Unit (Total: RM ${totalMaintCost.toStringAsFixed(0)})', style: TextStyle(fontSize: 11, color: textSecondary)),
                      const SizedBox(height: 10),
                      limitMaint.isEmpty
                          ? const Center(child: Text('No maintenance logs recorded'))
                          : Column(
                              children: limitMaint.map((e) {
                                final maxVal = limitMaint.first.value;
                                final pct = maxVal > 0 ? e.value / maxVal : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      SizedBox(width: 100, child: Text(e.key, style: TextStyle(fontSize: 10, color: textPrimary), overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: pct,
                                            minHeight: 8,
                                            backgroundColor: borderColor,
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('RM ${e.value.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: textSecondary)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
              ];
              return isWide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: childWidget) : Column(children: childWidget);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedTableSection(Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = _selectedReportType;
    final List<String> headers = _getReportHeaders(type);
    final List<List<String>> tableData = _getReportTableData(type);

    // Apply pagination
    final int totalRecords = tableData.length;
    final int totalPages = (totalRecords / _rowsPerPage).ceil();
    final int startIdx = (_currentPage - 1) * _rowsPerPage;
    final int endIdx = min(startIdx + _rowsPerPage, totalRecords);
    final paginatedData = totalRecords > 0 ? tableData.sublist(startIdx, endIdx) : [];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Control Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                // Module Selectors Row
                DropdownButton<String>(
                  value: _selectedReportType,
                  dropdownColor: cardColor,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  items: [
                    'Bookings',
                    'Payments',
                    'Revenue',
                    'Vehicles',
                    'Maintenance',
                    'Customers',
                    'Reward Points',
                    'Reviews',
                    'Open Rentals',
                    'Overdue Rentals',
                  ].map((t) => DropdownMenuItem(value: t, child: Text('$t Ledger'))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedReportType = val;
                        _currentPage = 1;
                        _clearAIFilters();
                      });
                    }
                  },
                ),
                // Table Search
                SizedBox(
                  width: 300,
                  height: 36,
                  child: TextField(
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 16),
                      hintText: 'Search records...',
                      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                        _currentPage = 1;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Records List
          if (paginatedData.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open_rounded, size: 48, color: textSecondary),
                    const SizedBox(height: 12),
                    Text('No operational records found matching the active filters', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ] else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF1B2436) : Colors.grey[50]),
                columns: headers.map<DataColumn>((h) => DataColumn(label: Text(h, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)))).toList().cast<DataColumn>(),
                rows: paginatedData.map<DataRow>((row) {
                  return DataRow(
                    cells: row.map<DataCell>((cell) => DataCell(Text(cell, style: TextStyle(color: textPrimary, fontSize: 12)))).toList().cast<DataCell>(),
                  );
                }).toList().cast<DataRow>(),
              ),
            ),
            const Divider(height: 1),
            // Pagination Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Showing ${startIdx + 1} to $endIdx of $totalRecords records', style: TextStyle(fontSize: 12, color: textSecondary)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 14),
                        onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                      ),
                      Text('Page $_currentPage of ${max(1, totalPages)}', style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 14),
                        onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    double total = values.fold(0, (sum, item) => sum + item);
    if (total == 0) return;

    double startAngle = -pi / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.4;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweepAngle = (values[i] / total) * 2 * pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) => true;
}
