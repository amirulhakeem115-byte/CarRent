import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';

import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/branch_service.dart';
import '../../../models/user_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/branch_model.dart';

import 'vehicles_screen.dart';
import 'bookings_screen.dart';
import 'payments_screen.dart';
import 'customers_screen.dart';
import 'branches_screen.dart';
import 'support_inbox_screen.dart';
import 'vehicle_maintenance_screen.dart';
import 'qr_settings_view.dart';
import '../../../services/maintenance_service.dart';
import '../../../models/maintenance_job_model.dart';
import '../login_screen.dart';
import '../../../widgets/loading_widget.dart';
import '../../../services/file_download_helper.dart' if (dart.library.html) '../../../services/file_download_web.dart' as download_helper;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final VehicleService _vehicleService = VehicleService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  final MaintenanceService _maintenanceService = MaintenanceService();

  int _totalCars = 0;
  int _totalBookings = 0;
  int _totalCustomers = 0;
  double _totalRevenue = 0.0;
  int _pendingPaymentsCount = 0;
  int _pendingLicensesCount = 0;
  int _availableCars = 0;
  int _bookedCars = 0;
  int _maintenanceCars = 0;

  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  List<VehicleModel> _vehicles = [];
  List<UserModel> _users = [];
  List<MaintenanceJobModel> _maintenanceJobs = [];
  List<BranchModel> _branches = [];
  bool _loading = true;
  String? _error;

  BookingModel? _selectedQrBooking;
  String _activeTab = 'Dashboard';
  StreamSubscription<List<BranchModel>>? _branchesSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _subscribeBranches();
  }

  void _subscribeBranches() {
    _branchesSubscription = BranchService().getBranchesStream().listen((branchesList) {
      if (mounted) {
        setState(() {
          _branches = branchesList;
        });
      }
    });
  }

  @override
  void dispose() {
    _branchesSubscription?.cancel();
    super.dispose();
  }


  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _databaseService.getUsers(),
        _vehicleService.getVehicles(),
        _bookingService.getBookings(),
        _paymentService.getPayments(),
        _maintenanceService.getMaintenanceJobs(),
      ]).timeout(const Duration(seconds: 15));

      _users = results[0] as List<UserModel>;
      _vehicles = results[1] as List<VehicleModel>;
      _bookings = results[2] as List<BookingModel>;
      _payments = results[3] as List<PaymentModel>;
      _maintenanceJobs = results[4] as List<MaintenanceJobModel>;

      _totalCustomers = _users.where((u) => u.role == 'customer').length;
      _totalCars = _vehicles.length;
      _totalBookings = _bookings.length;
      _availableCars = _vehicles.where((v) => v.status == 'available').length;
      _bookedCars = _vehicles.where((v) => v.status == 'booked').length;
      _maintenanceCars = _vehicles.where((v) => v.status == 'maintenance').length;
      _pendingLicensesCount = _users.where((u) => u.role == 'customer' && u.licenseStatus == 'pending').length;

      double revenue = 0.0;
      for (var payment in _payments) {
        final status = payment.status.toLowerCase();
        if (status == 'paid' || status == 'approved') {
          revenue += payment.amount;
        }
      }
      _totalRevenue = revenue;

      _pendingPaymentsCount = _payments.where((p) => p.status == 'pending' || p.status == 'Pending Verification').length;

      if (_bookings.isNotEmpty) {
        final pendingBookings = _bookings.where((b) => b.status == 'pending').toList();
        if (pendingBookings.isNotEmpty) {
          _selectedQrBooking = pendingBookings.first;
        } else {
          _selectedQrBooking = _bookings.first;
        }
      }
    } catch (e) {
      debugPrint('Dashboard loading error: $e');
      setState(() {
        _error = 'Failed to load dashboard statistics. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _exportExcel(String type) {
    var excelObj = Excel.createExcel();
    var sheet = excelObj[excelObj.getDefaultSheet() ?? 'Sheet1'];
    
    if (type == 'Bookings') {
      sheet.appendRow([
        TextCellValue('Booking ID'),
        TextCellValue('Vehicle'),
        TextCellValue('Customer'),
        TextCellValue('Phone'),
        TextCellValue('Pick Up Date'),
        TextCellValue('Return Date'),
        TextCellValue('Total Price (RM)'),
        TextCellValue('Status'),
        TextCellValue('Created At')
      ]);
      for (var booking in _bookings) {
        sheet.appendRow([
          TextCellValue(booking.id),
          TextCellValue(booking.vehicleName),
          TextCellValue(booking.userName),
          TextCellValue(booking.userPhone),
          TextCellValue(booking.pickUpDate.toIso8601String()),
          TextCellValue(booking.returnDate.toIso8601String()),
          DoubleCellValue(booking.totalPrice),
          TextCellValue(booking.status),
          TextCellValue(booking.createdAt.toIso8601String()),
        ]);
      }
    } else if (type == 'Payments' || type == 'Revenue') {
      sheet.appendRow([
        TextCellValue('Payment ID'),
        TextCellValue('Customer Name'),
        TextCellValue('Booking ID'),
        TextCellValue('Amount (RM)'),
        TextCellValue('Method'),
        TextCellValue('Status'),
        TextCellValue('Transaction ID'),
        TextCellValue('Date')
      ]);
      double sum = 0.0;
      for (var payment in _payments) {
        String customerName = 'Unknown';
        try {
          final matchedUser = _users.firstWhere((u) => u.id == payment.userId);
          customerName = matchedUser.fullName;
        } catch (_) {}
        sheet.appendRow([
          TextCellValue(payment.id),
          TextCellValue(customerName),
          TextCellValue(payment.bookingId),
          DoubleCellValue(payment.amount),
          TextCellValue(payment.paymentMethod),
          TextCellValue(payment.status),
          TextCellValue(payment.transactionId ?? 'N/A'),
          TextCellValue(payment.paymentDate.toIso8601String()),
        ]);
        final status = payment.status.toLowerCase();
        if (status == 'paid' || status == 'approved') {
          sum += payment.amount;
        }

      }
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('Total Successful Revenue (RM):'),
        DoubleCellValue(sum)
      ]);
    } else if (type == 'Customers') {
      sheet.appendRow([
        TextCellValue('Customer ID'),
        TextCellValue('Full Name'),
        TextCellValue('Email'),
        TextCellValue('Phone'),
        TextCellValue('Address'),
        TextCellValue('Verified'),
        TextCellValue('Active')
      ]);
      for (var user in _users) {
        if (user.role == 'customer') {
          sheet.appendRow([
            TextCellValue(user.id),
            TextCellValue(user.fullName),
            TextCellValue(user.email),
            TextCellValue(user.phone),
            TextCellValue(user.address),
            TextCellValue(user.isVerified ? 'Yes' : 'No'),
            TextCellValue(user.isActive ? 'Yes' : 'No'),
          ]);
        }
      }
    } else if (type == 'Vehicles') {
      sheet.appendRow([
        TextCellValue('Vehicle ID'),
        TextCellValue('Brand'),
        TextCellValue('Model'),
        TextCellValue('Category'),
        TextCellValue('Plate Number'),
        TextCellValue('Color'),
        TextCellValue('Transmission'),
        TextCellValue('Fuel Type'),
        TextCellValue('Price/Day (RM)'),
        TextCellValue('Availability'),
      ]);
      for (var vehicle in _vehicles) {
        sheet.appendRow([
          TextCellValue(vehicle.id),
          TextCellValue(vehicle.brand),
          TextCellValue(vehicle.model),
          TextCellValue(vehicle.category),
          TextCellValue(vehicle.plateNumber),
          TextCellValue(vehicle.color),
          TextCellValue(vehicle.transmission),
          TextCellValue(vehicle.fuelType),
          DoubleCellValue(vehicle.pricePerDay),
          TextCellValue(vehicle.isAvailable ? 'Available' : 'Booked'),
        ]);
      }
    } else if (type == 'Maintenance') {
      sheet.appendRow([
        TextCellValue('Job ID'),
        TextCellValue('Vehicle Unit'),
        TextCellValue('Service / Repair Type'),
        TextCellValue('Cost (RM)'),
        TextCellValue('Scheduled Date'),
        TextCellValue('Notes'),
        TextCellValue('Status')
      ]);
      double sumCost = 0.0;
      for (var job in _maintenanceJobs) {
        sheet.appendRow([
          TextCellValue(job.id),
          TextCellValue(job.vehicleName),
          TextCellValue(job.serviceType),
          DoubleCellValue(job.cost),
          TextCellValue(job.date),
          TextCellValue(job.notes),
          TextCellValue(job.status),
        ]);
        sumCost += job.cost;
      }
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('Total Maintenance Cost (RM):'),
        DoubleCellValue(sumCost)
      ]);
    }

    final fileBytes = excelObj.save();
    if (fileBytes != null) {
      download_helper.downloadFile(Uint8List.fromList(fileBytes), 'CARRENT_${type}_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type report downloaded in Excel format!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _exportPdf(String type) async {
    final pdf = pw.Document();
    
    List<List<String>> tableData = [];
    List<String> headers = [];

    if (type == 'Bookings') {
      headers = ['Vehicle', 'Customer', 'Period', 'Price', 'Status'];
      tableData = _bookings.map((b) => [
        b.vehicleName,
        b.userName,
        '${DateFormat('dd/MM').format(b.pickUpDate)} - ${DateFormat('dd/MM').format(b.returnDate)}',
        'RM ${b.totalPrice.toStringAsFixed(0)}',
        b.status.toUpperCase()
      ]).toList();
    } else if (type == 'Payments' || type == 'Revenue') {
      headers = ['Date', 'Customer', 'Booking Ref', 'Amount', 'Status'];
      double sum = 0.0;
      tableData = _payments.map((p) {
        String customerName = 'Unknown';
        try {
          final matchedUser = _users.firstWhere((u) => u.id == p.userId);
          customerName = matchedUser.fullName;
        } catch (_) {}
        if (p.status == 'paid') {
          sum += p.amount;
        }
        return [
          DateFormat('dd/MM/yyyy').format(p.paymentDate),
          customerName,
          p.bookingId.substring(0, p.bookingId.length > 8 ? 8 : p.bookingId.length),
          'RM ${p.amount.toStringAsFixed(2)}',
          p.status.toUpperCase()
        ];
      }).toList();
      tableData.add(['', 'TOTAL REVENUE:', '', 'RM ${sum.toStringAsFixed(2)}', '']);
    } else if (type == 'Customers') {
      headers = ['Name', 'Email', 'Phone', 'Verified', 'Active'];
      tableData = _users.where((u) => u.role == 'customer').map((u) => [
        u.fullName,
        u.email,
        u.phone,
        u.isVerified ? 'YES' : 'NO',
        u.isActive ? 'YES' : 'NO'
      ]).toList();
    } else if (type == 'Vehicles') {
      headers = ['Vehicle Unit', 'Category', 'Plate', 'Daily Rate', 'Status'];
      tableData = _vehicles.map((v) => [
        '${v.brand} ${v.model}',
        v.category,
        v.plateNumber,
        'RM ${v.pricePerDay.toStringAsFixed(0)}',
        v.isAvailable ? 'AVAILABLE' : 'BOOKED'
      ]).toList();
    } else if (type == 'Maintenance') {
      headers = ['Vehicle Unit', 'Service Type', 'Date', 'Cost', 'Status'];
      double sumCost = 0.0;
      tableData = _maintenanceJobs.map((j) {
        sumCost += j.cost;
        return [
          j.vehicleName,
          j.serviceType,
          j.date,
          'RM ${j.cost.toStringAsFixed(2)}',
          j.status.toUpperCase()
        ];
      }).toList();
      tableData.add(['', 'TOTAL COST:', '', 'RM ${sumCost.toStringAsFixed(2)}', '']);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pdf_lib.PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CARRENT PLATFORM REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22, color: pdf_lib.PdfColor.fromInt(0xFF1A237E))),
                  pw.Text('Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10, color: pdf_lib.PdfColor.fromInt(0xFF757575))),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('$type Analytics Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: pdf_lib.PdfColor.fromInt(0xFFFF9800))),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: tableData,
              border: pw.TableBorder.all(width: 0.5, color: pdf_lib.PdfColor.fromInt(0xFFE0E0E0)),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdf_lib.PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: pdf_lib.PdfColor.fromInt(0xFF1A237E)),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Page 1 of 1 | Confidential Business Record', style: pw.TextStyle(fontSize: 8, color: pdf_lib.PdfColor.fromInt(0xFF9E9E9E))),
            ),
          ];
        },
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    final fileBytes = await pdf.save();
    download_helper.downloadFile(fileBytes, 'CARRENT_${type}_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    messenger.showSnackBar(
      SnackBar(content: Text('$type report downloaded in PDF format!'), backgroundColor: Colors.green),
    );
  }

  void _showBranchInfo(String name, String address, String phone, String operatingHours, double lat, double lng) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Address: $address', style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Text('Phone: $phone', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Operating Hours: $operatingHours', style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                download_helper.openUrl('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
              },
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Open in Google Maps'),
            ),
          ],
        );
      },
    );
  }

  void _showQRSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Select Booking to Receive Payment', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _bookings.length,
              itemBuilder: (context, index) {
                final booking = _bookings[index];
                return ListTile(
                  title: Text(booking.vehicleName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Customer: ${booking.userName} | RM ${booking.totalPrice.toStringAsFixed(0)}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: booking.status == 'pending' ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      booking.status.toUpperCase(),
                      style: TextStyle(color: booking.status == 'pending' ? Colors.orange : Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedQrBooking = booking;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _approveQrPayment() async {
    if (_selectedQrBooking == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Find matching payment record if exists
      final matching = _payments.where((p) => p.bookingId == _selectedQrBooking!.id);
      if (matching.isNotEmpty) {
        final payment = matching.first;
        await _paymentService.updatePaymentStatus(payment.id, 'paid', payment.userId);
      }
      await _bookingService.updateBookingStatus(
        _selectedQrBooking!.id,
        'approved',
        _selectedQrBooking!.userId,
        _selectedQrBooking!.vehicleId,
        _selectedQrBooking!.vehicleName,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Payment approved and booking marked as Paid!'), backgroundColor: Colors.green),
      );
      _loadDashboardData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to process payment: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1100;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(context),
          Expanded(
            child: _loading
                ? const Center(child: LoadingWidget(message: 'Syncing dashboard with Firebase...'))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                            const SizedBox(height: 16),
                            Text(_error!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadDashboardData, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _buildActiveBody(isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBody(bool isDesktop) {
    switch (_activeTab) {
      case 'Dashboard':
        return Column(
          children: [
            _buildHeader(isDesktop),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopStatsGrid(isDesktop),
                    const SizedBox(height: 24),
                    _buildMiddleSection(isDesktop),
                    const SizedBox(height: 24),
                    _buildBottomSection(isDesktop),
                  ],
                ),
              ),
            ),
          ],
        );
      case 'Cars':
        return Column(
          children: [
            _buildHeader(isDesktop),
            const Expanded(child: VehiclesView()),
          ],
        );
      case 'Bookings':
        return Column(
          children: [
            _buildHeader(isDesktop),
            const Expanded(child: BookingsView()),
          ],
        );
      case 'Customers':
        return Column(
          children: [
            _buildHeader(isDesktop),
            const Expanded(child: CustomersView()),
          ],
        );
      case 'Payments':
        return Column(
          children: [
            _buildHeader(isDesktop),
            const Expanded(child: PaymentsView()),
          ],
        );
      case 'Locations':
        return Column(
          children: [
            _buildHeader(isDesktop),
            const Expanded(child: BranchesView()),
          ],
        );
      case 'Support Inbox':
        return Column(
          children: [
            _buildHeader(isDesktop),
            const Expanded(child: SupportInboxView()),
          ],
        );
      case 'Vehicle Maintenance':
        return Column(
          children: [
            _buildHeader(isDesktop),
            const Expanded(child: VehicleMaintenanceView()),
          ],
        );
      case 'QR Settings':
        return Column(
          children: [
            _buildHeader(isDesktop),
            const Expanded(child: QrSettingsView()),
          ],
        );
      default:
        return const Center(child: Text('Unknown Tab'));
    }
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      color: AppColors.secondaryBlue,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.directions_car_filled, color: AppColors.primaryOrange, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'CARRENT',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          _buildSidebarTile(Icons.dashboard_outlined, 'Dashboard', () => setState(() => _activeTab = 'Dashboard')),
          _buildSidebarTile(Icons.directions_car_filled_outlined, 'Cars', () => setState(() => _activeTab = 'Cars')),
          _buildSidebarTile(Icons.calendar_today_outlined, 'Bookings', () => setState(() => _activeTab = 'Bookings')),
          _buildSidebarTile(Icons.people_outline_rounded, 'Customers', () => setState(() => _activeTab = 'Customers')),
          _buildSidebarTile(Icons.payment_outlined, 'Payments', () => setState(() => _activeTab = 'Payments')),
          _buildSidebarTile(Icons.build_outlined, 'Vehicle Maintenance', () => setState(() => _activeTab = 'Vehicle Maintenance')),
          _buildSidebarTile(Icons.storefront_outlined, 'Locations', () => setState(() => _activeTab = 'Locations')),
          _buildSidebarTile(Icons.mail_outline_rounded, 'Support Inbox', () => setState(() => _activeTab = 'Support Inbox')),
          _buildSidebarTile(Icons.qr_code_2, 'QR Settings', () => setState(() => _activeTab = 'QR Settings')),
          const Spacer(),
          const Divider(color: Colors.white24, height: 1),
          _buildSidebarTile(Icons.logout, 'Logout', () async {
            final nav = Navigator.of(context);
            await _authService.logout();
            nav.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarTile(IconData icon, String title, VoidCallback onTap) {
    final bool isActive = _activeTab == title;
    return InkWell(
      onTap: () {
        onTap();
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.pop(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 20),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!isDesktop) ...[
                IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.secondaryBlue),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activeTab == 'Dashboard' ? 'Dashboard Overview' : _activeTab,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
                  ),
                  Text(
                    _activeTab == 'Dashboard' ? 'Welcome back, Administrator' : 'CARRENT Platform Management',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.secondaryBlue),
                onPressed: _loadDashboardData,
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppColors.secondaryBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatsGrid(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: isDesktop ? 6 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.3 : 1.3,
          children: [
            _buildStatsCard('Total Users', '$_totalCustomers users', Icons.people, Colors.indigo),
            _buildStatsCard('Total Vehicles', '$_totalCars units', Icons.directions_car_filled, Colors.blue),
            _buildStatsCard('Total Revenue', 'RM ${_totalRevenue.toStringAsFixed(0)}', Icons.monetization_on, Colors.green),
            _buildStatsCard('Total Bookings', '$_totalBookings runs', Icons.book_online, Colors.purple),
            _buildStatsCard('Pending Payments', '$_pendingPaymentsCount checks', Icons.hourglass_top, Colors.orange),
            _buildStatsCard('Pending Licenses', '$_pendingLicensesCount checks', Icons.badge_outlined, Colors.redAccent),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Vehicle Fleet Status Summary',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: isDesktop ? 3 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 2.2 : 3.5,
          children: [
            _buildStatsCard('Available Cars', '$_availableCars units', Icons.check_circle_outline, Colors.green),
            _buildStatsCard('Booked Cars', '$_bookedCars units', Icons.block, Colors.redAccent),
            _buildStatsCard('Maintenance Cars', '$_maintenanceCars units', Icons.build_circle_outlined, Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 24),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleSection(bool isDesktop) {
    return Flex(
      direction: isDesktop ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart 1: Revenue Line Chart
        Expanded(
          flex: isDesktop ? 2 : 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Revenue Chart',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: CustomPaint(
                    painter: DashboardLineChartPainter(
                      values: [3000, 4500, 7000, 6200, 9500, _totalRevenue],
                      labels: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                    ),
                    child: Container(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isDesktop) const SizedBox(width: 24),
        if (!isDesktop) const SizedBox(height: 24),
        // QR Code Payment Scanner Pane
        Expanded(
          flex: isDesktop ? 1 : 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Scan to Receive Payment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue),
                ),
                const SizedBox(height: 12),
                if (_selectedQrBooking != null) ...[
                  Center(
                    child: Image.network(
                      'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=carrent://payment?bookingId=${_selectedQrBooking!.id}&amount=${_selectedQrBooking!.totalPrice}',
                      height: 140,
                      width: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code, size: 100, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedQrBooking!.vehicleName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryBlue),
                  ),
                  Text(
                    'Due: RM ${_selectedQrBooking!.totalPrice.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showQRSelectionDialog,
                          child: const Text('Change Booking', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _approveQrPayment,
                          child: const Text('Approve Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 40),
                  const Text('No bookings available to charge.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 40),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection(bool isDesktop) {
    return Flex(
      direction: isDesktop ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headquarters Info & Map
        Expanded(
          flex: isDesktop ? 2 : 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Malaysian Branch Map Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
                    const SizedBox(height: 8),
                    const Text(
                      'HQ Location: Presint 1 Terminal Hub, 62000 Putrajaya | Working hours: Mon - Fri: 9:00 AM - 6:00 PM PST',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
                      onPressed: () => download_helper.openUrl('https://www.google.com/maps/search/?api=1&query=3.0166,101.7916'),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open HQ in Google Maps'),
                    ),
                  ],
                ),
              ),
              Container(
                height: 250,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(3.0166, 101.7916), // Kajang HQ
                    initialZoom: 7.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.carrent.app',
                    ),
                    MarkerLayer(
                      markers: _branches.map((branch) {
                        final isHq = branch.branchName.toLowerCase().contains('kajang') || branch.branchName.toLowerCase().contains('headquarters');
                        return Marker(
                          point: LatLng(branch.latitude, branch.longitude),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showBranchInfo(branch.branchName, branch.address, branch.phone, branch.operatingHours, branch.latitude, branch.longitude),
                            child: Icon(
                              Icons.location_on,
                              color: isHq ? Colors.red : AppColors.primaryOrange,
                              size: isHq ? 36 : 32,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isDesktop) const SizedBox(width: 24),
        if (!isDesktop) const SizedBox(height: 24),
        // Export Panel & Recent Payments
        Expanded(
          flex: isDesktop ? 1 : 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Generate Operations Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
                const SizedBox(height: 16),
                const Text('PAYMENT LEDGER STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPaymentStatItem('Total', '${_payments.length}', Colors.blue),
                    _buildPaymentStatItem('Pending', '$_pendingPaymentsCount', Colors.orange),
                    _buildPaymentStatItem('Success', '${_payments.where((p) => p.status == 'paid').length}', Colors.green),
                    _buildPaymentStatItem('Failed', '${_payments.where((p) => p.status == 'failed' || p.status == 'refunded').length}', Colors.red),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('SELECT REPORT MODULE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildReportTile('Revenue'),
                    _buildReportTile('Bookings'),
                    _buildReportTile('Vehicles'),
                    _buildReportTile('Customers'),
                    _buildReportTile('Maintenance'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildReportTile(String title) {
    return Container(
      width: 100,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showReportOptions(title),
        child: Column(
          children: [
            const Icon(Icons.file_copy_outlined, color: AppColors.secondaryBlue, size: 20),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: AppColors.secondaryBlue)),
          ],
        ),
      ),
    );
  }

  void _showReportOptions(String reportName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Export $reportName Report', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.secondaryBlue)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  Navigator.pop(context);
                  _exportExcel(reportName);
                },
                icon: const Icon(Icons.table_view),
                label: const Text('Download Excel (.XLSX)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  Navigator.pop(context);
                  _exportPdf(reportName);
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Download PDF Document', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashboardLineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  DashboardLineChartPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paintLine = Paint()
      ..color = AppColors.primaryOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final paintFill = Paint()
      ..style = PaintingStyle.fill;

    final double maxVal = values.reduce((a, b) => a > b ? a : b);
    final double stepX = size.width / (values.length - 1);
    
    final path = Path();
    final fillPath = Path();
    
    for (int i = 0; i < values.length; i++) {
      final double x = i * stepX;
      final double y = size.height - 30 - ((values[i] / maxVal) * (size.height - 60));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height - 30);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (i == values.length - 1) {
        fillPath.lineTo(x, size.height - 30);
        fillPath.close();
      }

      // Draw labels
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), size.height - 15));
    }

    final gradient = LinearGradient(
      colors: [AppColors.primaryOrange.withValues(alpha: 0.3), AppColors.primaryOrange.withValues(alpha: 0.0)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    
    paintFill.shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
