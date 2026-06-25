import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../models/branch_model.dart';
import '../../../services/branch_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';
import '../../../services/file_download_helper.dart' if (dart.library.html) '../../../services/file_download_web.dart' as download_helper;

class BranchesView extends StatefulWidget {
  const BranchesView({super.key});

  @override
  State<BranchesView> createState() => _BranchesViewState();
}

class _BranchesViewState extends State<BranchesView> {
  final BranchService _branchService = BranchService();

  List<BranchModel> _branches = [];
  bool _loading = true;
  String? _error;
  final MapController _mapController = MapController();
  StreamSubscription<List<BranchModel>>? _branchesSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeBranches();
  }

  void _subscribeBranches() {
    _branchesSubscription?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    _branchesSubscription = _branchService.getBranchesStream().listen((branchesList) {
      if (mounted) {
        setState(() {
          _branches = branchesList;
          _loading = false;
          _error = null;
        });
      }
    }, onError: (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load branch list: $e';
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _branchesSubscription?.cancel();
    super.dispose();
  }

  void _showAddEditBranchDialog({BranchModel? branch}) {
    final isEdit = branch != null;
    final nameController = TextEditingController(text: branch?.branchName);
    final addressController = TextEditingController(text: branch?.address);
    final phoneController = TextEditingController(text: branch?.phone);
    final hoursController = TextEditingController(text: branch != null ? branch.operatingHours : '09:00 AM - 09:00 PM');
    final latController = TextEditingController(text: branch != null ? branch.latitude.toString() : '3.0166');
    final lngController = TextEditingController(text: branch != null ? branch.longitude.toString() : '101.7916');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(isEdit ? 'Edit Branch Location' : 'Add Branch Location', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Branch Name')),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
                TextField(controller: hoursController, decoration: const InputDecoration(labelText: 'Operating Hours')),
                TextField(controller: latController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Latitude')),
                TextField(controller: lngController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Longitude')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (nameController.text.trim().isEmpty || addressController.text.trim().isEmpty) return;

                final name = nameController.text.trim();
                final address = addressController.text.trim();
                final phone = phoneController.text.trim();
                final hours = hoursController.text.trim();
                final lat = double.tryParse(latController.text.trim()) ?? 3.0166;
                final lng = double.tryParse(lngController.text.trim()) ?? 101.7916;

                if (isEdit) {
                  await _branchService.updateBranch(branch.id, {
                    'branchName': name,
                    'name': name,
                    'address': address,
                    'phone': phone,
                    'operatingHours': hours,
                    'latitude': lat,
                    'longitude': lng,
                  });
                } else {
                  final newBranch = BranchModel(
                    id: '',
                    branchName: name,
                    address: address,
                    phone: phone,
                    operatingHours: hours,
                    latitude: lat,
                    longitude: lng,
                  );
                  await _branchService.addBranch(newBranch);
                }

                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: Text(isEdit ? 'Save Changes' : 'Add Branch'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBranch(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Branch'),
        content: const Text('Are you sure you want to remove this branch from locations listing?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _branchService.deleteBranch(id);
    }
  }

  void _showBranchInfo(BranchModel branch) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(branch.branchName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(branch.address, style: const TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: AppColors.primaryOrange),
                  const SizedBox(width: 6),
                  Text(branch.phone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Text(branch.operatingHours, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text('GPS: ${branch.latitude.toStringAsFixed(4)}, ${branch.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                download_helper.openUrl('https://www.google.com/maps/search/?api=1&query=${branch.latitude},${branch.longitude}');
              },
              child: const Text('Open in Google Maps'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingWidget(message: 'Loading business locations...'));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _subscribeBranches, child: const Text('Retry')),
          ],
        ),
      );
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1000;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Locations & Branches', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue)),
                  Text('Configure corporate branch details, latitude coordinates, and live pins.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showAddEditBranchDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Branch', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Statistics Grid
          GridView.count(
            crossAxisCount: isDesktop ? 2 : 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: isDesktop ? 4.5 : 3.0,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard('Total Seeded Branches', _branches.length.toString(), Icons.storefront, Colors.indigo),
              _buildStatCard('Active Hubs (Map Pins)', _branches.length.toString(), Icons.pin_drop, Colors.green),
            ],
          ),
          const SizedBox(height: 24),

          // Split panel: Map and List
          Expanded(
            child: Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // List of Branches
                Expanded(
                  flex: isDesktop ? 5 : 0,
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: _branches.isEmpty
                        ? const Center(child: Text('No branches registered.'))
                        : ListView.builder(
                            itemCount: _branches.length,
                            itemBuilder: (context, index) {
                              final branch = _branches[index];
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.lightGray,
                                  child: Icon(Icons.location_on_outlined, color: AppColors.primaryOrange, size: 20),
                                ),
                                title: Text(branch.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(branch.address, style: const TextStyle(fontSize: 12)),
                                    Text('Phone: ${branch.phone} | Lat: ${branch.latitude.toStringAsFixed(3)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.map_outlined, color: Colors.blue, size: 18),
                                      onPressed: () {
                                        _mapController.move(LatLng(branch.latitude, branch.longitude), 12.0);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 18),
                                      onPressed: () => _showAddEditBranchDialog(branch: branch),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                      onPressed: () => _deleteBranch(branch.id),
                                    ),
                                  ],
                                ),
                                onTap: () => _showBranchInfo(branch),
                              );
                            },
                          ),
                  ),
                ),
                if (isDesktop) const SizedBox(width: 24) else const SizedBox(height: 24),

                // Interactive map
                Expanded(
                  flex: isDesktop ? 5 : 0,
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _branches.isNotEmpty ? LatLng(_branches.first.latitude, _branches.first.longitude) : const LatLng(3.0166, 101.7916),
                            initialZoom: 7.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.carrent.app',
                            ),
                            MarkerLayer(
                              markers: _branches.map((branch) {
                                return Marker(
                                  point: LatLng(branch.latitude, branch.longitude),
                                  width: 40,
                                  height: 40,
                                  child: GestureDetector(
                                    onTap: () => _showBranchInfo(branch),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: AppColors.primaryOrange,
                                      size: 32,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
