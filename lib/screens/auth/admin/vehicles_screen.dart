import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/branch_model.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/branch_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';
import '../../../widgets/app_image.dart';

class VehiclesView extends StatefulWidget {
  const VehiclesView({super.key});

  @override
  State<VehiclesView> createState() => _VehiclesViewState();
}

class _VehiclesViewState extends State<VehiclesView> {
  final VehicleService _vehicleService = VehicleService();
  final BranchService _branchService = BranchService();

  List<VehicleModel> _vehicles = [];
  List<BranchModel> _branches = [];
  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String _categoryFilter = 'All'; // 'All', 'Economy', 'Sedan', 'SUV', 'MPV'
  String _statusFilter = 'All'; // 'All', 'Available', 'Booked', 'Maintenance'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _vehicles = await _vehicleService.getVehicles().timeout(const Duration(seconds: 10));
      _branches = await _branchService.getBranches().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error loading vehicles data: $e');
      setState(() {
        _error = 'Failed to load fleet inventory. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showAddEditVehicleDialog({VehicleModel? vehicle}) {
    final isEdit = vehicle != null;
    final brandController = TextEditingController(text: vehicle?.brand);
    final modelController = TextEditingController(text: vehicle?.model);
    final yearController = TextEditingController(text: vehicle?.year.toString());
    final plateController = TextEditingController(text: vehicle?.plateNumber);
    final colorController = TextEditingController(text: vehicle?.color);
    final priceController = TextEditingController(text: vehicle?.pricePerDay.toString());
    final descController = TextEditingController(text: vehicle?.description);
    final mileageController = TextEditingController(text: vehicle?.mileage.toString());

    String transmission = vehicle?.transmission ?? 'Automatic';
    String fuelType = vehicle?.fuelType ?? 'Petrol';
    String category = vehicle?.category ?? 'Economy';
    String status = vehicle?.status ?? 'available';
    int seats = vehicle?.seats ?? 5;
    BranchModel? selectedBranch;

    if (isEdit && _branches.isNotEmpty) {
      final matching = _branches.where((b) => b.name == vehicle.branchName);
      if (matching.isNotEmpty) {
        selectedBranch = matching.first;
      }
    } else if (_branches.isNotEmpty) {
      selectedBranch = _branches.first;
    }

    final picker = ImagePicker();
    String? imageUrl = vehicle?.mainImage;
    bool uploadingImage = false;
    List<String> gallery = vehicle?.gallery != null ? List<String>.from(vehicle!.gallery) : [];
    bool uploadingGallery = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(isEdit ? 'Edit Vehicle Spec' : 'Add New Vehicle', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image selector box
                    GestureDetector(
                      onTap: uploadingImage
                          ? null
                          : () async {
                              try {
                                final pickedFile = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 35,
                                  maxWidth: 600,
                                  maxHeight: 600,
                                );
                                if (pickedFile != null) {
                                  setDialogState(() => uploadingImage = true);
                                  final bytes = await pickedFile.readAsBytes();
                                  final filename = 'vehicle_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                  final url = await _vehicleService.uploadVehicleImage(bytes, filename);
                                  setDialogState(() {
                                    imageUrl = url;
                                    uploadingImage = false;
                                  });
                                }
                              } catch (e) {
                                debugPrint('Error uploading image: $e');
                                setDialogState(() => uploadingImage = false);
                              }
                            },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: uploadingImage
                            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
                            : imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: AppImage(imageSrc: imageUrl!, fit: BoxFit.cover),
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.grey[400]),
                                        const SizedBox(height: 8),
                                        Text('Upload Car Photo', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                      ],
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Gallery Section
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Gallery Images',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondaryBlue),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...gallery.map((gImg) => Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AppImage(imageSrc: gImg, fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 10,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      gallery.remove(gImg);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )),
                          // Plus Button
                          InkWell(
                            onTap: uploadingGallery
                                ? null
                                : () async {
                                    try {
                                      final pickedFile = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 35,
                                        maxWidth: 600,
                                        maxHeight: 600,
                                      );
                                      if (pickedFile != null) {
                                        setDialogState(() => uploadingGallery = true);
                                        final bytes = await pickedFile.readAsBytes();
                                        final filename = 'vehicle_gal_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                        final url = await _vehicleService.uploadVehicleImage(bytes, filename);
                                        setDialogState(() {
                                          gallery.add(url);
                                          uploadingGallery = false;
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint('Error uploading gallery image: $e');
                                      setDialogState(() => uploadingGallery = false);
                                    }
                                  },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: uploadingGallery
                                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 2))
                                  : Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(controller: brandController, decoration: const InputDecoration(labelText: 'Brand / Make (e.g. Proton)')),
                    TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model (e.g. Saga)')),
                    TextField(controller: yearController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Manufacture Year')),
                    TextField(controller: plateController, decoration: const InputDecoration(labelText: 'Plate Number')),
                    TextField(controller: colorController, decoration: const InputDecoration(labelText: 'Exterior Color')),
                    TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rental Rate Per Day (RM)')),
                    TextField(controller: mileageController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mileage (km)')),
                    TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(labelText: 'Short Description')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: ['Economy', 'Sedan', 'SUV', 'MPV'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setDialogState(() => category = val!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: transmission,
                      decoration: const InputDecoration(labelText: 'Transmission'),
                      items: ['Automatic', 'Manual'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setDialogState(() => transmission = val!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: fuelType,
                      decoration: const InputDecoration(labelText: 'Fuel Type'),
                      items: ['Petrol', 'Diesel', 'Hybrid', 'Electric'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                      onChanged: (val) => setDialogState(() => fuelType = val!),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: seats,
                      decoration: const InputDecoration(labelText: 'Seats Count'),
                      items: [4, 5, 7, 8].map((s) => DropdownMenuItem(value: s, child: Text('$s Seats'))).toList(),
                      onChanged: (val) => setDialogState(() => seats = val!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Vehicle Status'),
                      items: const [
                        DropdownMenuItem(value: 'available', child: Text('Available')),
                        DropdownMenuItem(value: 'booked', child: Text('Booked')),
                        DropdownMenuItem(value: 'maintenance', child: Text('Under Maintenance')),
                      ],
                      onChanged: (val) => setDialogState(() => status = val!),
                    ),
                    if (_branches.isNotEmpty)
                      DropdownButtonFormField<BranchModel>(
                        initialValue: selectedBranch,
                        decoration: const InputDecoration(labelText: 'Assigned Branch Hub'),
                        items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
                        onChanged: (val) => setDialogState(() => selectedBranch = val),
                      ),
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
                    if (brandController.text.trim().isEmpty ||
                        modelController.text.trim().isEmpty ||
                        priceController.text.trim().isEmpty ||
                        plateController.text.trim().isEmpty) {
                      return;
                    }

                    final brand = brandController.text.trim();
                    final model = modelController.text.trim();
                    final year = int.tryParse(yearController.text.trim()) ?? DateTime.now().year;
                    final plate = plateController.text.trim().toUpperCase();
                    final color = colorController.text.trim();
                    final price = double.tryParse(priceController.text.trim()) ?? 150.0;
                    final desc = descController.text.trim();
                    final mileage = int.tryParse(mileageController.text.trim()) ?? 25000;

                    if (isEdit) {
                      await _vehicleService.updateVehicle(vehicle.id, {
                        'brand': brand,
                        'model': model,
                        'year': year,
                        'plateNumber': plate,
                        'color': color,
                        'transmission': transmission,
                        'fuelType': fuelType,
                        'seats': seats,
                        'pricePerDay': price,
                        'mainImage': imageUrl ?? vehicle.mainImage,
                        'description': desc,
                        'category': category,
                        'mileage': mileage,
                        'branchId': selectedBranch?.id ?? vehicle.branchId,
                        'branchName': selectedBranch?.name ?? vehicle.branchName,
                        'status': status,
                        'isAvailable': status == 'available',
                        'gallery': gallery,
                      });
                    } else {
                      final newVehicle = VehicleModel(
                        id: '',
                        brand: brand,
                        model: model,
                        year: year,
                        plateNumber: plate,
                        color: color,
                        transmission: transmission,
                        fuelType: fuelType,
                        seats: seats,
                        pricePerDay: price,
                        isAvailable: status == 'available',
                        status: status,
                        mainImage: imageUrl ?? 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
                        description: desc,
                        createdAt: DateTime.now().toIso8601String(),
                        category: category,
                        mileage: mileage,
                        branchId: selectedBranch?.id ?? '',
                        branchName: selectedBranch?.name ?? '',
                        gallery: gallery,
                      );
                      await _vehicleService.addVehicle(newVehicle);
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadData();
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Add Vehicle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteVehicle(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: const Text('Are you sure you want to remove this vehicle from the database?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _vehicleService.deleteVehicle(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingWidget(message: 'Loading fleet vehicles...'));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16, color: AppColors.secondaryBlue, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Loading'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    // Calculations based directly on status
    final totalVehicles = _vehicles.length;
    final availableVehicles = _vehicles.where((v) => v.status == 'available').length;
    final rentedVehicles = _vehicles.where((v) => v.status == 'booked').length;
    final maintenanceVehiclesCount = _vehicles.where((v) => v.status == 'maintenance').length;

    // Filters application
    final filteredVehicles = _vehicles.where((v) {
      final matchesSearch = '${v.brand} ${v.model}'.toLowerCase().contains(_searchQuery) || v.plateNumber.toLowerCase().contains(_searchQuery);
      final matchesCategory = _categoryFilter == 'All' || v.category.toLowerCase() == _categoryFilter.toLowerCase();
      
      bool matchesStatus = true;
      if (_statusFilter == 'Available') {
        matchesStatus = v.status == 'available';
      } else if (_statusFilter == 'Booked') {
        matchesStatus = v.status == 'booked';
      } else if (_statusFilter == 'Maintenance') {
        matchesStatus = v.status == 'maintenance';
      }

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fleet Inventory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue)),
                    Text('Manage vehicle assets, pricing models, and branch allocations.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showAddEditVehicleDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statistics Grid
            GridView.count(
              crossAxisCount: isDesktop ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              childAspectRatio: isDesktop ? 2.2 : 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard('Total Vehicles', totalVehicles.toString(), Icons.directions_car, Colors.indigo),
                _buildStatCard('Available Units', availableVehicles.toString(), Icons.check_circle_outline, Colors.green),
                _buildStatCard('Rented / Active Booked', rentedVehicles.toString(), Icons.car_rental, Colors.orange),
                _buildStatCard('Under Maintenance', maintenanceVehiclesCount.toString(), Icons.build_circle_outlined, Colors.redAccent),
              ],
            ),
            const SizedBox(height: 24),

            // Filters & Search Box Card
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by make, model, or plate number...',
                          prefixIcon: Icon(Icons.search, size: 20),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Category selector dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: _categoryFilter,
                        underline: const SizedBox(),
                        items: ['All', 'Economy', 'Sedan', 'SUV', 'MPV'].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _categoryFilter = val;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status selector dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        underline: const SizedBox(),
                        items: ['All', 'Available', 'Booked', 'Maintenance'].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _statusFilter = val;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Vehicles list container
            Expanded(
              child: filteredVehicles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No fleet assets found matching filters.', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = filteredVehicles[index];
                        
                        Color statusColor = Colors.green;
                        String statusLabel = 'AVAILABLE';
                        if (vehicle.status == 'maintenance') {
                          statusColor = Colors.redAccent;
                          statusLabel = 'MAINTENANCE';
                        } else if (vehicle.status == 'booked') {
                          statusColor = Colors.orange;
                          statusLabel = 'BOOKED';
                        }

                        return Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AppImage(
                                    imageSrc: vehicle.mainImage,
                                    height: 80,
                                    width: 110,
                                    fit: BoxFit.cover,
                                    placeholder: Container(
                                      height: 80,
                                      width: 110,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.directions_car, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${vehicle.brand} ${vehicle.model}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 9),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Plate: ${vehicle.plateNumber} | Category: ${vehicle.category} | Hub: ${vehicle.branchName.isNotEmpty ? vehicle.branchName : "General Hub"}',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            'RM ${vehicle.pricePerDay.toStringAsFixed(0)} / day',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange, fontSize: 14),
                                          ),
                                          const SizedBox(width: 24),
                                          const Text('Change Status:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey[300]!),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: vehicle.status,
                                                icon: const Icon(Icons.arrow_drop_down, size: 16),
                                                style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold),
                                                onChanged: (val) async {
                                                  if (val != null) {
                                                    await _vehicleService.updateVehicleStatus(vehicle.id, val);
                                                    _loadData();
                                                  }
                                                },
                                                items: const [
                                                  DropdownMenuItem(value: 'available', child: Text('Available')),
                                                  DropdownMenuItem(value: 'booked', child: Text('Booked')),
                                                  DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 20),
                                      onPressed: () => _showAddEditVehicleDialog(vehicle: vehicle),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                      onPressed: () => _deleteVehicle(vehicle.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
