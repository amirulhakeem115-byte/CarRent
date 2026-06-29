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

  // Add/Edit Form State
  bool _isFormActive = false;
  BranchModel? _editingBranch;
  bool _isSelectingLocationFromMap = false;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hoursController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String _status = 'Active';

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
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _hoursController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  bool _isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  void _activateForm({BranchModel? branch}) {
    setState(() {
      _editingBranch = branch;
      _isFormActive = true;
      _isSelectingLocationFromMap = false;
      
      _nameController.text = branch?.branchName ?? '';
      _addressController.text = branch?.address ?? '';
      _phoneController.text = branch?.phone ?? '';
      _hoursController.text = branch?.operatingHours ?? '09:00 AM - 09:00 PM';
      _latController.text = branch != null ? branch.latitude.toString() : '3.0166';
      _lngController.text = branch != null ? branch.longitude.toString() : '101.7916';
      _status = branch?.status ?? 'Active';
    });
  }

  void _cancelForm() {
    setState(() {
      _isFormActive = false;
      _editingBranch = null;
      _isSelectingLocationFromMap = false;
    });
  }

  Future<void> _saveForm() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final hours = _hoursController.text.trim();
    final lat = double.tryParse(_latController.text.trim()) ?? 0.0;
    final lng = double.tryParse(_lngController.text.trim()) ?? 0.0;

    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch Name and Address are required!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      if (_editingBranch != null) {
        await _branchService.updateBranch(_editingBranch!.id, {
          'branchName': name,
          'name': name,
          'address': address,
          'phone': phone,
          'operatingHours': hours,
          'latitude': lat,
          'longitude': lng,
          'status': _status,
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
          status: _status,
        );
        await _branchService.addBranch(newBranch);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editingBranch != null ? 'Branch updated successfully' : 'Branch added successfully'), backgroundColor: Colors.green),
      );
      _cancelForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save branch: $e'), backgroundColor: Colors.redAccent),
      );
    }
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
    final isValid = _isValidLatLng(branch.latitude, branch.longitude);
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
                  const Icon(Icons.info_outline, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text('Status: ${branch.status}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    isValid
                        ? 'GPS: ${branch.latitude.toStringAsFixed(4)}, ${branch.longitude.toStringAsFixed(4)}'
                        : 'GPS: Missing/Invalid coordinates',
                    style: TextStyle(fontSize: 12, color: isValid ? Colors.grey : Colors.red, fontWeight: isValid ? FontWeight.normal : FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (isValid)
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

    final validMapBranches = _branches.where((b) => _isValidLatLng(b.latitude, b.longitude)).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Locations & Branches', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue)),
                          Text('Configure corporate branch details, latitude coordinates, and live pins.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (!_isFormActive) _buildAddBranchButton(),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Locations & Branches', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue)),
                        Text('Configure corporate branch details, latitude coordinates, and live pins.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    if (!_isFormActive) ...[
                      const SizedBox(height: 16),
                      _buildAddBranchButton(),
                    ],
                  ],
                ),
          const SizedBox(height: 24),

          // Statistics Grid
          GridView.count(
            crossAxisCount: isDesktop ? 2 : 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: isDesktop ? 5.5 : 3.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard('Total Seeded Branches', _branches.length.toString(), Icons.storefront, Colors.indigo),
              _buildStatCard('Active Hubs (Map Pins)', validMapBranches.where((b) => b.status == 'Active').length.toString(), Icons.pin_drop, Colors.green),
            ],
          ),
          const SizedBox(height: 24),

          // Split panel: Left (List or Form) and Right (Map)
          Expanded(
            child: Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Panel: Form or List
                Expanded(
                  flex: isDesktop ? 5 : 1,
                  child: _isFormActive ? _buildBranchForm() : _buildBranchList(),
                ),
                if (isDesktop) const SizedBox(width: 24) else const SizedBox(height: 24),

                // Right Panel: Interactive map
                Expanded(
                  flex: isDesktop ? 6 : 1,
                  child: Stack(
                    children: [
                      Card(
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
                                initialCenter: validMapBranches.isNotEmpty 
                                    ? LatLng(validMapBranches.first.latitude, validMapBranches.first.longitude) 
                                    : const LatLng(3.0166, 101.7916),
                                initialZoom: 7.0,
                                onTap: (tapPosition, point) {
                                  if (_isSelectingLocationFromMap) {
                                    setState(() {
                                      _latController.text = point.latitude.toStringAsFixed(6);
                                      _lngController.text = point.longitude.toStringAsFixed(6);
                                      _isSelectingLocationFromMap = false;
                                    });
                                  }
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.carrent.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    ...validMapBranches.map((branch) {
                                      final isActive = branch.status == 'Active';
                                      return Marker(
                                        point: LatLng(branch.latitude, branch.longitude),
                                        width: 40,
                                        height: 40,
                                        child: GestureDetector(
                                          onTap: () => _showBranchInfo(branch),
                                          child: Icon(
                                            Icons.location_on,
                                            color: isActive ? AppColors.primaryOrange : Colors.grey,
                                            size: 32,
                                          ),
                                        ),
                                      );
                                    }),
                                    if (_isFormActive) ...[
                                      // Render a temporary target marker if admin entered/selected valid lat/lng
                                      (() {
                                        final double? lat = double.tryParse(_latController.text);
                                        final double? lng = double.tryParse(_lngController.text);
                                        if (_isValidLatLng(lat, lng)) {
                                          return Marker(
                                            point: LatLng(lat!, lng!),
                                            width: 40,
                                            height: 40,
                                            child: const Icon(
                                              Icons.add_location_alt,
                                              color: Colors.redAccent,
                                              size: 36,
                                            ),
                                          );
                                        }
                                        return null;
                                      })()
                                    ].whereType<Marker>(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_isSelectingLocationFromMap)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Card(
                            color: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.touch_app, color: Colors.white),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Click anywhere on the map to set the branch coordinates!',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddBranchButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _activateForm(),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add Branch', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBranchList() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: _branches.isEmpty
          ? const Center(child: Text('No branches registered.'))
          : ListView.builder(
              itemCount: _branches.length,
              itemBuilder: (context, index) {
                final branch = _branches[index];
                final isValid = _isValidLatLng(branch.latitude, branch.longitude);
                final isActive = branch.status == 'Active';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? AppColors.lightGray : Colors.grey[200],
                    child: Icon(Icons.location_on_outlined, color: isActive ? AppColors.primaryOrange : Colors.grey, size: 20),
                  ),
                  title: Row(
                    children: [
                      Text(branch.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          branch.status.toUpperCase(),
                          style: TextStyle(color: isActive ? Colors.green : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch.address, style: const TextStyle(fontSize: 12)),
                      if (!isValid)
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                              SizedBox(width: 4),
                              Text('Missing/Invalid GPS Coordinates!', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      Text('Phone: ${branch.phone} | GPS: ${branch.latitude.toStringAsFixed(3)}, ${branch.longitude.toStringAsFixed(3)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isValid)
                        IconButton(
                          icon: const Icon(Icons.map_outlined, color: Colors.blue, size: 18),
                          onPressed: () {
                            _mapController.move(LatLng(branch.latitude, branch.longitude), 12.0);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 18),
                        onPressed: () => _activateForm(branch: branch),
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
    );
  }

  Widget _buildBranchForm() {
    final isEdit = _editingBranch != null;
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'Edit Branch' : 'Add Branch Location',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: _cancelForm,
                ),
              ],
            ),
            const Divider(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Branch Name', hintText: 'e.g. Kajang Hub'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address', hintText: 'Full physical address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number', hintText: 'e.g. +603-87391234'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hoursController,
              decoration: const InputDecoration(labelText: 'Operating Hours', hintText: 'e.g. 09:00 AM - 09:00 PM'),
            ),
            const SizedBox(height: 12),
            
            // Coordinates Row with "Select from map" trigger
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSelectingLocationFromMap ? Colors.redAccent : AppColors.lightGray,
                foregroundColor: _isSelectingLocationFromMap ? Colors.white : AppColors.secondaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  _isSelectingLocationFromMap = !_isSelectingLocationFromMap;
                });
              },
              icon: Icon(_isSelectingLocationFromMap ? Icons.touch_app : Icons.map),
              label: Text(_isSelectingLocationFromMap ? 'TAPPING ACTIVE...' : 'Select Location Directly From Map'),
            ),
            const SizedBox(height: 16),

            // Status Dropdown
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Branch Status'),
              items: ['Active', 'Inactive'].map((s) {
                return DropdownMenuItem(value: s, child: Text(s));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _status = val);
                }
              },
            ),
            const SizedBox(height: 24),

            // Form actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelForm,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saveForm,
                    child: const Text('Save Branch'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
