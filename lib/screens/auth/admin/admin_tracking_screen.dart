import 'dart:async';
import 'package:flutter/material.dart';
import '../../../constants/colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/tracking_service.dart';
import '../customer/tracking_screen.dart';

class AdminTrackingScreen extends StatefulWidget {
  const AdminTrackingScreen({super.key});

  @override
  State<AdminTrackingScreen> createState() => _AdminTrackingScreenState();
}

class _AdminTrackingScreenState extends State<AdminTrackingScreen> {
  final VehicleService _vehicleService = VehicleService();
  final TrackingService _trackingService = TrackingService();

  List<VehicleModel> _vehicles = [];
  String _searchQuery = '';
  bool _loading = true;

  // Active coordinates database listener map
  final Map<String, StreamSubscription?> _subscriptions = {};
  final Map<String, double> _latitudes = {};
  final Map<String, double> _longitudes = {};
  final Map<String, double> _speeds = {};
  final Map<String, Timer?> _simulators = {};

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final list = await _vehicleService.getVehicles();
    setState(() {
      _vehicles = list;
      _loading = false;
    });

    // Setup streams & active route simulations for each vehicle
    for (var vehicle in _vehicles) {
      _simulators[vehicle.id] = _trackingService.startRouteSimulation(vehicle.id);
      _subscriptions[vehicle.id] = _trackingService
          .getVehicleLocationStream(vehicle.id)
          .listen((loc) {
        if (mounted && loc != null) {
          setState(() {
            _latitudes[vehicle.id] = loc.latitude;
            _longitudes[vehicle.id] = loc.longitude;
            _speeds[vehicle.id] = loc.speed;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _subscriptions.forEach((_, sub) => sub?.cancel());
    _simulators.forEach((_, sim) => sim?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _vehicles.where((v) {
      final name = '${v.brand} ${v.model}'.toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

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
        title: const Text('Fleet GPS Telematics Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
          : Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Fleet filter & details
                Expanded(
                  flex: isDesktop ? 2 : 0,
                  child: Container(
                    color: AppColors.lightGray,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FLEET MANAGEMENT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Active Telematics',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.secondaryBlue,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Search text box
                        TextField(
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search active vehicles...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text('No matching active rentals.', style: TextStyle(color: Colors.grey[500])),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final vehicle = filtered[index];
                                    final double speed = _speeds[vehicle.id] ?? 0.0;
                                    final double lat = _latitudes[vehicle.id] ?? 3.1344;
                                    final double lng = _longitudes[vehicle.id] ?? 101.6861;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.grey[200]!),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: CircleAvatar(
                                          backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
                                          child: const Icon(Icons.directions_car, color: AppColors.primaryOrange),
                                        ),
                                        title: Text(
                                          '${vehicle.brand} ${vehicle.model}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                                        ),
                                        subtitle: Text(
                                          'Speed: ${speed.toStringAsFixed(0)} km/h\nLat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.lightText),
                                        ),
                                        trailing: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.secondaryBlue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => TrackingScreen(vehicle: vehicle),
                                              ),
                                            );
                                          },
                                          child: const Text('TRACK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                // Right: Unified fleet tracking map
                Expanded(
                  flex: isDesktop ? 3 : 0,
                  child: Container(
                    height: isDesktop ? null : 400,
                    color: const Color(0xFF0F2D52),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: FleetMapCanvasPainter(
                              latitudes: _latitudes,
                              longitudes: _longitudes,
                              vehicles: _vehicles,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 20,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'FLEET SATELLITE RADAR VIEW',
                              style: TextStyle(
                                color: AppColors.primaryOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
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
}

class FleetMapCanvasPainter extends CustomPainter {
  final Map<String, double> latitudes;
  final Map<String, double> longitudes;
  final List<VehicleModel> vehicles;

  FleetMapCanvasPainter({
    required this.latitudes,
    required this.longitudes,
    required this.vehicles,
  });

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
      ..color = AppColors.primaryOrange.withValues(alpha: 0.2)
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

    // Draw primary Malaysian trunk route
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
    canvas.drawPath(path, paintLine);

    // Draw branch points
    final paintBranch = Paint()..color = Colors.blue;
    canvas.drawCircle(Offset(mapX(101.6861), mapY(3.1344)), 10, paintBranch); // KL
    canvas.drawCircle(Offset(mapX(101.4920), mapY(3.0805)), 10, paintBranch); // Shah Alam

    // Draw vehicle markers
    for (var v in vehicles) {
      final double lat = latitudes[v.id] ?? 3.1344;
      final double lng = longitudes[v.id] ?? 101.6861;

      final double x = mapX(lng);
      final double y = mapY(lat);

      final paintCar = Paint()..color = AppColors.primaryOrange;
      final paintPulse = Paint()..color = AppColors.primaryOrange.withValues(alpha: 0.2);

      canvas.drawCircle(Offset(x, y), 20, paintPulse);
      canvas.drawCircle(Offset(x, y), 8, paintCar);

      final labelStyle = const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold);
      _drawLabel(canvas, Offset(x, y - 16), '${v.brand} ${v.model}', labelStyle);
    }
  }

  void _drawLabel(Canvas canvas, Offset offset, String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset - Offset(textPainter.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant FleetMapCanvasPainter oldDelegate) {
    return true; // Simple repaint for telemetry radar updates
  }
}
