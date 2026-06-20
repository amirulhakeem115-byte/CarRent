import 'package:flutter/material.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/branch_service.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/branch_model.dart';
import 'vehicle_details_screen.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  final VehicleService _vehicleService = VehicleService();
  final BranchService _branchService = BranchService();

  List<VehicleModel> _allVehicles = [];
  List<BranchModel> _branches = [];
  bool _loading = true;

  // Search & Filter State
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTransmission;
  int? _selectedSeats;
  double _maxPrice = 1000.0;
  BranchModel? _selectedBranch;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _allVehicles = await _vehicleService.getVehicles();
    _branches = await _branchService.getBranches();
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter logic
    final filteredVehicles = _allVehicles.where((vehicle) {
      final matchesSearch = vehicle.brand.toLowerCase().contains(_searchQuery) ||
          vehicle.model.toLowerCase().contains(_searchQuery);
      final matchesTransmission =
          _selectedTransmission == null || vehicle.transmission == _selectedTransmission;
      final matchesSeats = _selectedSeats == null || vehicle.seats == _selectedSeats;
      final matchesPrice = vehicle.pricePerDay <= _maxPrice;
      final matchesBranch = _selectedBranch == null || vehicle.branchName == _selectedBranch!.name;
      return matchesSearch && matchesTransmission && matchesSeats && matchesPrice && matchesBranch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find Your Vehicle',
          style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar & Filter Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      // Search TextField
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search brand or model...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Expandable Filters
                      ExpansionTile(
                        title: const Text(
                          'Advanced Filters',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
                        ),
                        leading: const Icon(Icons.filter_list, color: Color(0xFF1E3C72)),
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        children: [
                          // Transmission filter
                          Row(
                            children: [
                              const Text('Transmission: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Auto'),
                                selected: _selectedTransmission == 'Automatic',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedTransmission = selected ? 'Automatic' : null;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Manual'),
                                selected: _selectedTransmission == 'Manual',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedTransmission = selected ? 'Manual' : null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Seats filter
                          Row(
                            children: [
                              const Text('Seats: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              ...[2, 4, 5, 7].map((s) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text('$s'),
                                    selected: _selectedSeats == s,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedSeats = selected ? s : null;
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Branch Location Dropdown
                          Row(
                            children: [
                              const Text('Branch: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<BranchModel>(
                                      value: _selectedBranch,
                                      isExpanded: true,
                                      hint: const Text('All Locations'),
                                      items: [
                                        const DropdownMenuItem<BranchModel>(
                                          value: null,
                                          child: Text('All Locations'),
                                        ),
                                        ..._branches.map((b) => DropdownMenuItem(
                                              value: b,
                                              child: Text(b.name),
                                            )),
                                      ],
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedBranch = val;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Price Per Day filter
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Max Price / Day: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text('RM ${_maxPrice.toStringAsFixed(0)}'),
                                ],
                              ),
                              Slider(
                                value: _maxPrice,
                                min: 50,
                                max: 1000,
                                divisions: 19,
                                activeColor: const Color(0xFF1E3C72),
                                onChanged: (val) {
                                  setState(() {
                                    _maxPrice = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Vehicles list
                Expanded(
                  child: filteredVehicles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.car_rental_rounded, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No matching cars found', style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filteredVehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = filteredVehicles[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                      child: vehicle.mainImage.isNotEmpty
                                          ? Image.network(
                                              vehicle.mainImage,
                                              height: 110,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(
                                                height: 110,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.car_rental, color: Colors.grey),
                                              ),
                                            )
                                          : Container(
                                              height: 110,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.car_rental, color: Colors.grey),
                                            ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  vehicle.brand,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[500],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  vehicle.model,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF2C3E50),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.settings, size: 12, color: Colors.grey[400]),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      vehicle.transmission,
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'RM ${vehicle.pricePerDay.toStringAsFixed(0)}/d',
                                                    style: const TextStyle(
                                                      color: Color(0xFF1E3C72),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.circle,
                                                  size: 10,
                                                  color: vehicle.isAvailable ? Colors.green : Colors.redAccent,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
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
    );
  }
}
