import 'package:flutter/material.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/branch_service.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/branch_model.dart';
import '../../../constants/colors.dart';
import '../../../widgets/custom_app_bar.dart';
import 'vehicle_details_screen.dart';
import '../../../widgets/loading_widget.dart';

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
  String? _error;

  // Search & Filter State
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTransmission;
  String? _selectedCategory;
  final double _maxPrice = 1000.0;
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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _allVehicles = await _vehicleService.getVehicles().timeout(const Duration(seconds: 10));
      _branches = await _branchService.getBranches().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error loading fleet vehicles: $e');
      setState(() {
        _error = 'Failed to load fleet vehicles. Please verify your connection.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 750;

    // Filter logic
    final filteredVehicles = _allVehicles.where((vehicle) {
      final matchesSearch = vehicle.brand.toLowerCase().contains(_searchQuery) ||
          vehicle.model.toLowerCase().contains(_searchQuery);
      final matchesTransmission =
          _selectedTransmission == null || vehicle.transmission == _selectedTransmission;
      final matchesPrice = vehicle.pricePerDay <= _maxPrice;
      final matchesBranch = _selectedBranch == null || vehicle.branchName == _selectedBranch!.name;
      final matchesCategory = _selectedCategory == null || 
          (vehicle.model.toLowerCase().contains(_selectedCategory!.toLowerCase()));
      return matchesSearch && matchesTransmission && matchesPrice && matchesBranch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(),
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
                            color: AppColors.secondaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
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
              : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60.0 : 20.0,
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back arrow and title section
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.secondaryBlue, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Fleet',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.secondaryBlue,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Select a vehicle to view detailed specifications and availability.',
                              style: TextStyle(fontSize: 14, color: AppColors.lightText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Search Filters Row
                  _buildFilterBar(),
                  const SizedBox(height: 32),

                  // Vehicle Grid matching Image Reference 4
                  filteredVehicles.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(Icons.car_rental, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No vehicles matching selected filters found.', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          alignment: WrapAlignment.center,
                          children: filteredVehicles.map((vehicle) {
                            // Extract display details matching image reference 4
                            final isCoupe = vehicle.model.toLowerCase().contains('coupe');
                            final categoryTag = isCoupe ? 'COUPÉ' : 'SEDAN';

                            return Container(
                              width: 320,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Image & category tag block
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        child: vehicle.mainImage.isNotEmpty
                                            ? Image.network(
                                                vehicle.mainImage,
                                                height: 180,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => Container(
                                                  height: 180,
                                                  color: Colors.grey[200],
                                                  child: const Icon(Icons.car_rental, size: 48, color: Colors.grey),
                                                ),
                                              )
                                            : Container(
                                                height: 180,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.car_rental, size: 48, color: Colors.grey),
                                              ),
                                      ),
                                      // Absolute positioned category tag
                                      Positioned(
                                        right: 12,
                                        top: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryOrange,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            categoryTag,
                                            style: const TextStyle(
                                              color: AppColors.secondaryBlue,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Details Card Body
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${vehicle.brand} ${vehicle.model}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.secondaryBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        
                                        // Specifications horizontal list matching reference image
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildSpecBadge(Icons.settings, vehicle.transmission == 'Automatic' ? 'Automat' : 'Manual'),
                                            _buildSpecBadge(Icons.speed, vehicle.engine),
                                            _buildSpecBadge(Icons.ac_unit, 'AC'),
                                          ],
                                        ),
                                        const SizedBox(height: 20),

                                        // Full width Navy button
                                        SizedBox(
                                          width: double.infinity,
                                          height: 44,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF5A738E), // Greyish-Blue in mockup
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              elevation: 0,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                                                ),
                                              ).then((_) => _loadData());
                                            },
                                            child: const Text(
                                              'View Details',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 60),

                  // Rental Demand Utilization Section matching Image Reference 4
                  _buildRentalDemandSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search Brand / Model',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedTransmission,
                hint: const Text('Transmission'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: 'Automatic', child: Text('Automatic')),
                  DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                ],
                onChanged: (val) {
                  setState(() => _selectedTransmission = val);
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedCategory,
                hint: const Text('Category'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Categories')),
                  DropdownMenuItem(value: 'Sedan', child: Text('Sedan')),
                  DropdownMenuItem(value: 'Coupe', child: Text('Coupe')),
                ],
                onChanged: (val) {
                  setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<BranchModel>(
                value: _selectedBranch,
                hint: const Text('Branch Hub'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Branches')),
                  ..._branches.map((b) => DropdownMenuItem(value: b, child: Text(b.name))),
                ],
                onChanged: (val) {
                  setState(() => _selectedBranch = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primaryOrange),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildRentalDemandSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up, color: AppColors.primaryOrange, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Rental Demand',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryBlue,
                    ),
                  ),
                ],
              ),
              Text(
                'LIVE DATA',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Monthly utilization rates for the current selection',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 32),

          // Utilization progress indicators
          _buildDemandRow('Mercedes Sedan', 0.92, '92%'),
          const SizedBox(height: 20),
          _buildDemandRow('Mercedes Coupe', 0.78, '78%'),
          const SizedBox(height: 32),

          // Legend dots
          Row(
            children: [
              _buildLegendDot(const Color(0xFF8E6B23), 'Current Demand'),
              const SizedBox(width: 24),
              _buildLegendDot(Colors.grey[400]!, 'Market Average'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemandRow(String vehicleName, double rate, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              vehicleName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryBlue),
            ),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryBlue),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E6B23)), // Gold-Brown in mockup
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
