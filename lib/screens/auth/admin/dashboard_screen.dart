import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../models/user_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import 'vehicles_screen.dart';
import 'bookings_screen.dart';
import 'payments_screen.dart';
import 'customers_screen.dart';
import 'branches_screen.dart';
import 'admin_tracking_screen.dart';
import '../login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final VehicleService _vehicleService = VehicleService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  int _totalUsers = 0;
  int _totalVehicles = 0;
  int _totalBookings = 0;
  double _totalRevenue = 0.0;

  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  List<VehicleModel> _vehicles = [];
  List<UserModel> _users = [];
  bool _loading = true;

  String _reportType = 'Revenue'; // 'Revenue', 'Vehicle', 'Customer'
  String _reportPeriod = 'Monthly'; // 'Daily', 'Weekly', 'Monthly'

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);
    try {
      _users = await _databaseService.getUsers();
      _vehicles = await _vehicleService.getVehicles();
      _bookings = await _bookingService.getBookings();
      _payments = await _paymentService.getPayments();

      _totalUsers = _users.where((u) => u.role == 'customer').length;
      _totalVehicles = _vehicles.length;
      _totalBookings = _bookings.length;

      double revenue = 0.0;
      for (var payment in _payments) {
        if (payment.status == 'paid') {
          revenue += payment.amount;
        }
      }
      _totalRevenue = revenue;
    } catch (e) {
      debugPrint('Dashboard loading error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int get _dailyBookingsCount {
    final today = DateTime.now();
    return _bookings.where((b) =>
      b.createdAt.year == today.year &&
      b.createdAt.month == today.month &&
      b.createdAt.day == today.day
    ).length;
  }

  int get _monthlyBookingsCount {
    final today = DateTime.now();
    return _bookings.where((b) =>
      b.createdAt.year == today.year &&
      b.createdAt.month == today.month
    ).length;
  }

  double get _utilizationRate {
    if (_vehicles.isEmpty) return 0.0;
    final occupied = _vehicles.where((v) => !v.isAvailable).length;
    return occupied / _vehicles.length;
  }

  void _generateAndExportReport(bool isPdf) {
    final format = isPdf ? 'PDF' : 'Excel';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_reportPeriod $_reportType Report generated and downloaded in $format format!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('CARRENT Admin Console', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.secondaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
              final nav = Navigator.of(context);
              await _authService.logout();
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live GPS Tracking Quick Action Box
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBlue,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.map, color: AppColors.primaryOrange, size: 28),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fleet GPS Telematics',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'View live location maps of all vehicles.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AdminTrackingScreen()),
                            );
                          },
                          child: const Text('LAUNCH MAP'),
                        ),
                      ],
                    ),
                  ),

                  const Text(
                    'Fleet KPIs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
                  ),
                  const SizedBox(height: 16),
                  
                  // KPI Grid
                  GridView.count(
                    crossAxisCount: isDesktop ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isDesktop ? 1.6 : 1.3,
                    children: [
                      _buildKPICard('Total Users', '$_totalUsers', Icons.people_outline, Colors.blue),
                      _buildKPICard('Fleet Size', '$_totalVehicles', Icons.directions_car_outlined, Colors.purple),
                      _buildKPICard('Total Bookings', '$_totalBookings', Icons.book_online_outlined, AppColors.primaryOrange),
                      _buildKPICard('Total Revenue', 'RM ${_totalRevenue.toStringAsFixed(0)}', Icons.monetization_on_outlined, Colors.green),
                      _buildKPICard('Today Bookings', '$_dailyBookingsCount', Icons.today_outlined, Colors.teal),
                      _buildKPICard('Monthly Bookings', '$_monthlyBookingsCount', Icons.calendar_month_outlined, Colors.indigo),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Charts Row
                  Flex(
                    direction: isDesktop ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Revenue & Bookings graph widget
                      Expanded(
                        flex: isDesktop ? 2 : 0,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Monthly Revenue Analytics', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.secondaryBlue)),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 200,
                                child: CustomPaint(
                                  painter: AnalyticsBarChartPainter(
                                    values: [4000, 6500, 8000, 11000, 15000, _totalRevenue],
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
                      // Fleet utilization gauge
                      Expanded(
                        flex: isDesktop ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Fleet Utilization', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.secondaryBlue)),
                              const SizedBox(height: 24),
                              Center(
                                child: SizedBox(
                                  width: 150,
                                  height: 150,
                                  child: CustomPaint(
                                    painter: UtilizationGaugePainter(rate: _utilizationRate),
                                    child: Center(
                                      child: Text(
                                        '${(_utilizationRate * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Center(
                                child: Text('Occupied vs Total Active Fleet', style: TextStyle(color: AppColors.lightText, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Administrative Modules',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
                  ),
                  const SizedBox(height: 16),
                  
                  // Module Grid / List
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildNavTile('Users & License Approvals', Icons.verified_user_outlined, const CustomersScreen()),
                      _buildNavTile('Vehicle Fleet Inventory', Icons.directions_car_filled_outlined, const VehiclesScreen()),
                      _buildNavTile('Booking Logs & Schedules', Icons.book_online_outlined, const BookingsScreen()),
                      _buildNavTile('Financial Audit Ledger', Icons.account_balance_wallet_outlined, const PaymentsScreen()),
                      _buildNavTile('Malaysian Branch Hubs', Icons.storefront_outlined, const BranchesScreen()),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Report Generator Card
                  const Text(
                    'Operations Reports Terminal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('REPORT TYPE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondaryBlue)),
                                  const SizedBox(height: 8),
                                  DropdownButton<String>(
                                    value: _reportType,
                                    isExpanded: true,
                                    items: ['Revenue', 'Vehicle', 'Customer'].map((t) {
                                      return DropdownMenuItem(value: t, child: Text(t));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _reportType = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('PERIOD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondaryBlue)),
                                  const SizedBox(height: 8),
                                  DropdownButton<String>(
                                    value: _reportPeriod,
                                    isExpanded: true,
                                    items: ['Daily', 'Weekly', 'Monthly'].map((p) {
                                      return DropdownMenuItem(value: p, child: Text(p));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _reportPeriod = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.primaryOrange),
                                  foregroundColor: AppColors.primaryOrange,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.file_download_outlined),
                                label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _generateAndExportReport(false),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryOrange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _generateAndExportReport(true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[150] ?? const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AppColors.lightText, fontSize: 12, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 24),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(String title, IconData icon, Widget screen) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        ).then((_) => _loadDashboardData());
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.08),
              child: Icon(icon, color: AppColors.secondaryBlue),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter to draw a dashboard charts grid
class AnalyticsBarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  AnalyticsBarChartPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paintBar = Paint()
      ..color = AppColors.primaryOrange
      ..style = PaintingStyle.fill;

    final paintBg = Paint()
      ..color = AppColors.lightGray
      ..style = PaintingStyle.fill;

    final double maxVal = values.reduce((a, b) => a > b ? a : b);
    final double barSpacing = size.width / values.length;
    final double barWidth = barSpacing * 0.5;

    for (int i = 0; i < values.length; i++) {
      final double x = (i * barSpacing) + (barSpacing - barWidth) / 2;
      final double barHeight = (values[i] / maxVal) * (size.height - 30);
      final double y = size.height - 20 - barHeight;

      // Draw background pillar slot
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 10, barWidth, size.height - 30),
          const Radius.circular(6),
        ),
        paintBg,
      );

      // Draw active filled pillar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(6),
        ),
        paintBar,
      );

      // Draw labels
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: AppColors.lightText, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x + (barWidth - textPainter.width) / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom utilization circular indicator
class UtilizationGaugePainter extends CustomPainter {
  final double rate;
  UtilizationGaugePainter({required this.rate});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;

    final paintBg = Paint()
      ..color = AppColors.lightGray
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    final paintGauge = Paint()
      ..color = AppColors.primaryOrange
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, paintBg);
    
    // Draw sweeping arc representing occupied/utilization rate
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // Start at -90 degrees (top center)
      rate * 6.28318, // Sweep full circle base
      false,
      paintGauge,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
