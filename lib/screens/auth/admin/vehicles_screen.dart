import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/branch_model.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/branch_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final VehicleService _vehicleService = VehicleService();
  final BranchService _branchService = BranchService();

  List<VehicleModel> _vehicles = [];
  List<BranchModel> _branches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVehiclesAndBranches();
  }

  Future<void> _loadVehiclesAndBranches() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _vehicles = await _vehicleService.getVehicles().timeout(const Duration(seconds: 10));
      _branches = await _branchService.getBranches().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error loading vehicles/branches: $e');
      setState(() {
        _error = 'Failed to load vehicles list. Please check your connection.';
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

    String transmission = vehicle?.transmission ?? 'Automatic';
    String fuelType = vehicle?.fuelType ?? 'Petrol';
    int seats = vehicle?.seats ?? 5;
    BranchModel? selectedBranch;

    if (isEdit && _branches.isNotEmpty) {
      final matching = _branches.where((b) => b.name == vehicle.branchName);
      if (matching.isNotEmpty) {
        selectedBranch = matching.first;
      }
    }

    final picker = ImagePicker();
    String? imageUrl = vehicle?.mainImage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(isEdit ? 'Edit Vehicle' : 'Add Vehicle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: brandController, decoration: const InputDecoration(labelText: 'Brand')),
                    TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model')),
                    TextField(
                      controller: yearController,
                      decoration: const InputDecoration(labelText: 'Year'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(controller: plateController, decoration: const InputDecoration(labelText: 'Plate Number')),
                    TextField(controller: colorController, decoration: const InputDecoration(labelText: 'Color')),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price Per Day (RM)'),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: transmission,
                      decoration: const InputDecoration(labelText: 'Transmission'),
                      items: ['Automatic', 'Manual']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => transmission = val);
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: fuelType,
                      decoration: const InputDecoration(labelText: 'Fuel Type'),
                      items: ['Petrol', 'Diesel', 'Hybrid', 'Electric']
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => fuelType = val);
                      },
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: seats,
                      decoration: const InputDecoration(labelText: 'Seats'),
                      items: [2, 4, 5, 7, 8]
                          .map((s) => DropdownMenuItem(value: s, child: Text('$s Seats')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => seats = val);
                      },
                    ),
                    DropdownButtonFormField<BranchModel>(
                      initialValue: selectedBranch,
                      decoration: const InputDecoration(labelText: 'Branch Hub'),
                      hint: const Text('Select Location'),
                      items: _branches
                          .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedBranch = val);
                      },
                    ),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Add Vehicle Image'),
                      onPressed: () async {
                        try {
                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                          if (picked != null) {
                            // Professional stock vehicle mockup image url
                            imageUrl = 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600';
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Mock Image Selected')),
                              );
                            }
                          }
                        } catch (e) {
                          debugPrint('Image pick error: $e');
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (brandController.text.trim().isEmpty ||
                        modelController.text.trim().isEmpty ||
                        priceController.text.trim().isEmpty) {
                      return;
                    }

                    final brand = brandController.text.trim();
                    final model = modelController.text.trim();
                    final year = int.tryParse(yearController.text.trim()) ?? DateTime.now().year;
                    final price = double.tryParse(priceController.text.trim()) ?? 150.0;
                    final desc = descController.text.trim();
                    final plate = plateController.text.trim();
                    final color = colorController.text.trim();

                    if (isEdit) {
                      await _vehicleService.updateVehicle(vehicle.id, {
                        'brand': brand,
                        'model': model,
                        'year': year,
                        'plateNumber': plate,
                        'color': color,
                        'pricePerDay': price,
                        'transmission': transmission,
                        'fuelType': fuelType,
                        'seats': seats,
                        'description': desc,
                        'mainImage': imageUrl ?? vehicle.mainImage,
                        'branchId': selectedBranch?.id ?? '',
                        'branchName': selectedBranch?.name ?? '',
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
                        isAvailable: true,
                        mainImage: imageUrl ?? 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
                        description: desc,
                        createdAt: DateTime.now().toIso8601String(),
                        branchId: selectedBranch?.id ?? '',
                        branchName: selectedBranch?.name ?? '',
                      );
                      await _vehicleService.addVehicle(newVehicle);
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadVehiclesAndBranches();
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
      _loadVehiclesAndBranches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Manage Vehicles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: LoadingWidget(message: 'Loading fleet vehicles...'))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1A237E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadVehiclesAndBranches,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry Loading'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
          : _vehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No vehicles found in fleet', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = _vehicles[index];
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
                              child: vehicle.mainImage.isNotEmpty
                                  ? Image.network(
                                      vehicle.mainImage,
                                      height: 70,
                                      width: 90,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        height: 70,
                                        width: 90,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.car_rental, color: Colors.grey),
                                      ),
                                    )
                                  : Container(
                                      height: 70,
                                      width: 90,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.car_rental, color: Colors.grey),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${vehicle.brand} ${vehicle.model}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    'Plate: ${vehicle.plateNumber} | Hub: ${vehicle.branchName.isNotEmpty ? vehicle.branchName : 'General'}',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        'RM ${vehicle.pricePerDay.toStringAsFixed(0)}/day',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 13),
                                      ),
                                      const SizedBox(width: 12),
                                      // Quick Availability Switch
                                      Text(
                                        vehicle.isAvailable ? 'Available' : 'Booked',
                                        style: TextStyle(
                                          color: vehicle.isAvailable ? Colors.green : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Switch(
                                        value: vehicle.isAvailable,
                                        activeThumbColor: Colors.green,
                                        onChanged: (val) async {
                                          await _vehicleService.toggleAvailability(vehicle.id, val);
                                          _loadVehiclesAndBranches();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showAddEditVehicleDialog(vehicle: vehicle),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A237E),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddEditVehicleDialog(),
      ),
    );
  }
}
