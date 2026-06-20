import 'dart:async';
import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/tracking_model.dart';
import '../../../services/tracking_service.dart';

class TrackingScreen extends StatefulWidget {
  final VehicleModel vehicle;
  const TrackingScreen({super.key, required this.vehicle});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final TrackingService _trackingService = TrackingService();
  StreamSubscription<TrackingModel?>? _subscription;
  TrackingModel? _currentLocation;
  Timer? _simulationTimer;
  final List<String> _telemetryLogs = [];

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    _subscription = _trackingService
        .getVehicleLocationStream(widget.vehicle.id)
        .listen((loc) {
      if (mounted) {
        setState(() {
          _currentLocation = loc;
          if (loc != null) {
            _addLog('Telemetry update: Lat ${loc.latitude.toStringAsFixed(4)}, Lng ${loc.longitude.toStringAsFixed(4)}, Speed: ${loc.speed.toStringAsFixed(0)} km/h');
          }
        });
      }
    });

    // Automatically trigger mock hardware simulator for preview
    _simulationTimer = _trackingService.startRouteSimulation(widget.vehicle.id);
    _addLog('Initializing Telematics Interface...');
    _addLog('Connected to GPS Tracker (Teltonika FMB920)');
    _addLog('Awaiting satellite fix...');
  }

  void _addLog(String msg) {
    setState(() {
      _telemetryLogs.insert(0, '[${DateTime.now().toIso8601String().substring(11, 19)}] $msg');
      if (_telemetryLogs.length > 20) {
        _telemetryLogs.removeLast();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.secondaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Track Rented Vehicle - ${widget.vehicle.brand} ${widget.vehicle.model}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Flex(
        direction: isDesktop ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left panel: Telemetry stats and logs
          Expanded(
            flex: isDesktop ? 2 : 0,
            child: Container(
              color: AppColors.lightGray,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TELEMETRY DASHBOARD',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.primaryOrange,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Live Tracker Control',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: AppColors.secondaryBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Quick KPI boxes
                    _buildKPIWidget(),
                    const SizedBox(height: 24),
                    // Current Position card
                    _buildLocationCard(),
                    const SizedBox(height: 24),
                    // Console logger
                    const Text(
                      'Telematics Logs',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.secondaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView.builder(
                        itemCount: _telemetryLogs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              _telemetryLogs[index],
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontFamily: 'Courier',
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Right panel: Simulated interactive route map canvas
          Expanded(
            flex: isDesktop ? 3 : 0,
            child: Container(
              height: isDesktop ? null : 400,
              color: const Color(0xFF0F2D52),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: MapCanvasPainter(
                        carLat: _currentLocation?.latitude ?? 3.1344,
                        carLng: _currentLocation?.longitude ?? 101.6861,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'SIMULATOR ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIWidget() {
    return Row(
      children: [
        Expanded(
          child: _buildKPICard(
            Icons.speed_outlined,
            '${_currentLocation?.speed.toStringAsFixed(0) ?? "0"} km/h',
            'Current Speed',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKPICard(
            Icons.timer_outlined,
            _currentLocation?.speed != null && _currentLocation!.speed > 0
                ? '25 mins'
                : 'Stopped',
            'Estimated ETA',
          ),
        ),
      ],
    );
  }

  Widget _buildKPICard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryOrange, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.lightText),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.1),
            child: const Icon(Icons.gps_fixed, color: AppColors.secondaryBlue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GPS Coordinates',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentLocation != null
                      ? 'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}, Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}'
                      : 'Awaiting telematics feed...',
                  style: const TextStyle(fontSize: 13, color: AppColors.lightText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Draw a beautiful custom canvas showing a map layout with streets and the driving car path
class MapCanvasPainter extends CustomPainter {
  final double carLat;
  final double carLng;

  MapCanvasPainter({required this.carLat, required this.carLng});

  @override
  void paint(Canvas canvas, Size size) {
    final paintRoad = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintRoute = Paint()
      ..color = AppColors.primaryOrange.withValues(alpha: 0.4)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    // Draw grid background
    final paintGrid = Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.2);
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paintGrid);
    }
    for (double j = 0; j < size.height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paintGrid);
    }

    // Map the GPS coordinate scope into local canvas pixels
    // Origin is at KL Sentral: Lat 3.1344, Lng 101.6861
    // Final destination: Lat 3.0805, Lng 101.4920
    final double startLat = 3.1400;
    final double startLng = 101.6900;
    final double endLat = 3.0600;
    final double endLng = 101.4800;

    double mapX(double lng) {
      return ((lng - startLng) / (endLng - startLng)) * size.width;
    }

    double mapY(double lat) {
      return ((lat - startLat) / (endLat - startLat)) * size.height;
    }

    // Draw main route path (roads)
    final path = Path()
      ..moveTo(mapX(101.6861), mapY(3.1344)) // KL Sentral
      ..lineTo(mapX(101.6701), mapY(3.1284)) // Mid Valley
      ..lineTo(mapX(101.6498), mapY(3.1168)) // PJ Asia
      ..lineTo(mapX(101.6128), mapY(3.1044)) // Kelana Jaya
      ..lineTo(mapX(101.5644), mapY(3.0901)) // Subang Jaya
      ..lineTo(mapX(101.5204), mapY(3.0768)) // Glenmarie
      ..lineTo(mapX(101.5037), mapY(3.0697)) // Batu Tiga
      ..lineTo(mapX(101.4897), mapY(3.0733)) // Shah Alam
      ..lineTo(mapX(101.4920), mapY(3.0805)); // Seksyen 7

    canvas.drawPath(path, paintRoad);
    canvas.drawPath(path, paintRoute);

    // Draw divider dashed effect inside roads
    canvas.drawPath(path, paintLine);

    // Draw branch points
    final paintBranch = Paint()..color = Colors.blue;
    canvas.drawCircle(Offset(mapX(101.6861), mapY(3.1344)), 10, paintBranch); // KL
    canvas.drawCircle(Offset(mapX(101.4920), mapY(3.0805)), 10, paintBranch); // Shah Alam

    // Draw labels
    const textStyle = TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold);
    _drawLabel(canvas, Offset(mapX(101.6861), mapY(3.1344) - 20), 'KL Sentral Branch', textStyle);
    _drawLabel(canvas, Offset(mapX(101.4920), mapY(3.0805) - 20), 'Shah Alam Hub', textStyle);

    // Draw active vehicle car marker
    final double carX = mapX(carLng);
    final double carY = mapY(carLat);

    final paintCarCircle = Paint()..color = AppColors.primaryOrange;
    final paintPulse = Paint()..color = AppColors.primaryOrange.withValues(alpha: 0.3);

    // Dynamic pulse ring
    canvas.drawCircle(Offset(carX, carY), 24, paintPulse);
    canvas.drawCircle(Offset(carX, carY), 10, paintCarCircle);

    // Draw a car indicator inner core
    final paintInner = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(carX, carY), 4, paintInner);
  }

  void _drawLabel(Canvas canvas, Offset offset, String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset - Offset(textPainter.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant MapCanvasPainter oldDelegate) {
    return oldDelegate.carLat != carLat || oldDelegate.carLng != carLng;
  }
}
