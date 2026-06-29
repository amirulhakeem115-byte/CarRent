import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../constants/colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../widgets/app_image.dart';

class AdminTrackingView extends StatefulWidget {
  final List<VehicleModel> vehicles;
  final Map<String, Map<String, dynamic>> liveLocations;

  const AdminTrackingView({
    super.key,
    required this.vehicles,
    required this.liveLocations,
  });

  @override
  State<AdminTrackingView> createState() => _AdminTrackingViewState();
}

class _AdminTrackingViewState extends State<AdminTrackingView> {
  final MapController _mapController = MapController();
  String _searchQuery = '';
  Map<String, dynamic>? _selectedVehicle;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 950;

    final filtered = widget.vehicles.where((v) {
      final name = '${v.brand} ${v.model}'.toLowerCase();
      final plate = v.plateNumber.toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || plate.contains(_searchQuery.toLowerCase());
    }).toList();

    return Row(
      children: [
        // Left details and filter pane
        if (isDesktop)
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey[200]!)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FLEET TELEMATICS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fleet GPS Center',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondaryBlue,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search brand or plate...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No vehicles found'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final vehicle = filtered[index];
                            final loc = widget.liveLocations[vehicle.id];
                            final double speed = loc != null ? (loc['speed'] as num).toDouble() : 0.0;
                            final double lat = loc != null ? (loc['latitude'] as num).toDouble() : 3.1344;
                            final double lng = loc != null ? (loc['longitude'] as num).toDouble() : 101.6861;
                            final bool isMoving = speed > 0;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 48,
                                  height: 36,
                                  color: Colors.grey[100],
                                  child: AppImage(
                                    imageSrc: vehicle.mainImage,
                                    placeholder: const Icon(Icons.directions_car, size: 20, color: Colors.grey),
                                  ),
                                ),
                              ),
                              title: Text(
                                '${vehicle.brand} ${vehicle.model}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryBlue),
                              ),
                              subtitle: Text(
                                '${vehicle.plateNumber} • ${speed.toStringAsFixed(0)} km/h',
                                style: TextStyle(fontSize: 11, color: isMoving ? Colors.green : Colors.grey),
                              ),
                              onTap: () {
                                final tv = {
                                  'vehicle': vehicle,
                                  'latitude': lat,
                                  'longitude': lng,
                                  'speed': speed,
                                };
                                setState(() {
                                  _selectedVehicle = tv;
                                });
                                _mapController.move(LatLng(lat, lng), 13);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

        // Right Map view
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(3.1344, 101.6861),
                  initialZoom: 10.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.carrent.app',
                  ),
                  MarkerLayer(
                    markers: widget.vehicles.map((v) {
                      final loc = widget.liveLocations[v.id];
                      final double lat = loc != null ? (loc['latitude'] as num).toDouble() : 3.1344;
                      final double lng = loc != null ? (loc['longitude'] as num).toDouble() : 101.6861;
                      final double speed = loc != null ? (loc['speed'] as num).toDouble() : 0.0;

                      return Marker(
                        point: LatLng(lat, lng),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () {
                            final tv = {
                              'vehicle': v,
                              'latitude': lat,
                              'longitude': lng,
                              'speed': speed,
                            };
                            setState(() {
                              _selectedVehicle = tv;
                            });
                            _mapController.move(LatLng(lat, lng), 13);
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryOrange.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryOrange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.directions_car, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Float Details Overlay Card
              if (_selectedVehicle != null)
                Positioned(
                  top: 20,
                  left: 20,
                  right: isDesktop ? null : 20,
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Active Vehicle Detail', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, fontSize: 13)),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() => _selectedVehicle = null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 70,
                                height: 50,
                                color: Colors.grey[100],
                                child: AppImage(
                                  imageSrc: (_selectedVehicle!['vehicle'] as VehicleModel).mainImage,
                                  placeholder: const Icon(Icons.directions_car),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${(_selectedVehicle!['vehicle'] as VehicleModel).brand} ${(_selectedVehicle!['vehicle'] as VehicleModel).model}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryBlue),
                                  ),
                                  Text(
                                    (_selectedVehicle!['vehicle'] as VehicleModel).plateNumber,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _buildOverlayDetailRow('GPS Latitude', _selectedVehicle!['latitude'].toStringAsFixed(6)),
                        _buildOverlayDetailRow('GPS Longitude', _selectedVehicle!['longitude'].toStringAsFixed(6)),
                        _buildOverlayDetailRow('Current Speed', '${_selectedVehicle!['speed'].toStringAsFixed(0)} km/h'),
                        _buildOverlayDetailRow('Telematics Feed', 'Active (Teltonika GPS)'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondaryBlue)),
        ],
      ),
    );
  }
}
