import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
      _vehicles = await _vehicleService.getVehicles().timeout(
        const Duration(seconds: 10),
      );
      _branches = await _branchService.getBranches().timeout(
        const Duration(seconds: 10),
      );
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
    showDialog<bool>(
      context: context,
      builder: (context) => VehicleFormDialog(
        vehicle: vehicle,
        branches: _branches,
        vehicleService: _vehicleService,
      ),
    ).then((updated) {
      if (updated == true) {
        _loadData();
      }
    });
  }

  Future<void> _deleteVehicle(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: const Text(
          'Are you sure you want to remove this vehicle from the database?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
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
    // Defensive check for Category and Status filter dropdowns to avoid assertion errors
    final availableCategoriesFilter = ['All', 'Economy', 'Sedan', 'SUV', 'MPV'];
    if (!availableCategoriesFilter.contains(_categoryFilter)) {
      _categoryFilter = 'All';
    }

    final availableStatusesFilter = [
      'All',
      'Available',
      'Booked',
      'Maintenance',
      'Inactive',
    ];
    if (!availableStatusesFilter.contains(_statusFilter)) {
      _statusFilter = 'All';
    }

    if (_loading) {
      return const Center(
        child: LoadingWidget(message: 'Loading fleet vehicles...'),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Calculations based directly on status
    final totalVehicles = _vehicles.length;
    final availableVehicles = _vehicles
        .where((v) => v.status.toLowerCase() == 'available')
        .length;
    final rentedVehicles = _vehicles
        .where((v) => v.status.toLowerCase() == 'booked')
        .length;
    final maintenanceVehiclesCount = _vehicles
        .where((v) => v.status.toLowerCase() == 'maintenance')
        .length;

    // Filters application
    final filteredVehicles = _vehicles.where((v) {
      final matchesSearch =
          '${v.brand} ${v.model}'.toLowerCase().contains(_searchQuery) ||
          v.plateNumber.toLowerCase().contains(_searchQuery);
      final matchesCategory =
          _categoryFilter == 'All' ||
          v.category.toLowerCase() == _categoryFilter.toLowerCase();

      bool matchesStatus = true;
      if (_statusFilter != 'All') {
        matchesStatus = v.status.toLowerCase() == _statusFilter.toLowerCase();
      }

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1100;
    final bool isAndroidMobile =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        width <= 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor = isDark
        ? const Color(0xFF111827)
        : const Color(0xFFF1F5F9);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Header row
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fleet Inventory',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Manage vehicle assets, pricing models, and branch allocations.',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildAddVehicleButton(),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fleet Inventory',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Manage vehicle assets, pricing models, and branch allocations.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildAddVehicleButton(),
                  ],
                ),
          const SizedBox(height: 24),

          // Statistics Grid
          GridView.count(
            crossAxisCount: isDesktop ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: isDesktop ? 2.2 : (isAndroidMobile ? 1.26 : 1.5),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(
                'Total Vehicles',
                totalVehicles.toString(),
                Icons.directions_car,
                Colors.indigo,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Available Units',
                availableVehicles.toString(),
                Icons.check_circle_outline,
                Colors.green,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Rented / Active Booked',
                rentedVehicles.toString(),
                Icons.car_rental,
                Colors.orange,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Under Maintenance',
                maintenanceVehiclesCount.toString(),
                Icons.build_circle_outlined,
                Colors.redAccent,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters & Search Box Container
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: isDesktop
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search by make/ model/ plate number',
                            hintStyle: TextStyle(
                              color: textSecondary.withValues(alpha: 0.7),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 20,
                              color: textSecondary,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildCategoryDropdown(
                        isDark: isDark,
                        cardColor: surfaceColor,
                        textPrimary: textPrimary,
                        borderColor: borderColor,
                      ),
                      const SizedBox(width: 12),
                      _buildStatusDropdown(
                        isDark: isDark,
                        cardColor: surfaceColor,
                        textPrimary: textPrimary,
                        borderColor: borderColor,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by make/ model/ plate number',
                          hintStyle: TextStyle(
                            color: textSecondary.withValues(alpha: 0.7),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20,
                            color: textSecondary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCategoryDropdown(
                              isDark: isDark,
                              cardColor: surfaceColor,
                              textPrimary: textPrimary,
                              borderColor: borderColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusDropdown(
                              isDark: isDark,
                              cardColor: surfaceColor,
                              textPrimary: textPrimary,
                              borderColor: borderColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Vehicles list container
          filteredVehicles.isEmpty
              ? Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 64,
                          color: textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No fleet assets found matching filters.',
                          style: TextStyle(color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = filteredVehicles[index];

                    Color statusColor = Colors.green;
                    String statusLabel = 'AVAILABLE';
                    final statusLower = vehicle.status.toLowerCase();
                    if (statusLower == 'maintenance') {
                      statusColor = Colors.redAccent;
                      statusLabel = 'MAINTENANCE';
                    } else if (statusLower == 'booked') {
                      statusColor = Colors.orange;
                      statusLabel = 'BOOKED';
                    } else if (statusLower == 'inactive') {
                      statusColor = Colors.grey;
                      statusLabel = 'INACTIVE';
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      child: isDesktop
                          ? Row(
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
                                      color: surfaceColor,
                                      child: Icon(
                                        Icons.directions_car,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${vehicle.brand} ${vehicle.model}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Plate: ${vehicle.plateNumber} | Category: ${vehicle.category} | Hub: ${vehicle.branchName.isNotEmpty ? vehicle.branchName : "General Hub"}',
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            'RM ${vehicle.pricePerDay.toStringAsFixed(0)} / day',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryOrange,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          Text(
                                            'Change Status:',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textSecondary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildChangeStatusDropdown(
                                            vehicle,
                                            isDark: isDark,
                                            cardColor: surfaceColor,
                                            textPrimary: textPrimary,
                                            borderColor: borderColor,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: textPrimary,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _showAddEditVehicleDialog(
                                            vehicle: vehicle,
                                          ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _deleteVehicle(vehicle.id),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AppImage(
                                    imageSrc: vehicle.mainImage,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: Container(
                                      height: 150,
                                      width: double.infinity,
                                      color: surfaceColor,
                                      child: Icon(
                                        Icons.directions_car,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${vehicle.brand} ${vehicle.model}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Plate: ${vehicle.plateNumber} | Category: ${vehicle.category}\nHub: ${vehicle.branchName.isNotEmpty ? vehicle.branchName : "General Hub"}',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'RM ${vehicle.pricePerDay.toStringAsFixed(0)} / day',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryOrange,
                                    fontSize: 15,
                                  ),
                                ),
                                Divider(height: 20, color: borderColor),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Status:',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: textSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildChangeStatusDropdown(
                                          vehicle,
                                          isDark: isDark,
                                          cardColor: surfaceColor,
                                          textPrimary: textPrimary,
                                          borderColor: borderColor,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            color: textPrimary,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _showAddEditVehicleDialog(
                                                vehicle: vehicle,
                                              ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _deleteVehicle(vehicle.id),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildAddVehicleButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _showAddEditVehicleDialog(),
      icon: const Icon(Icons.add, size: 18),
      label: const Text(
        'Add Vehicle',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCategoryDropdown({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButton<String>(
        value: _categoryFilter,
        underline: const SizedBox(),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        items: ['All', 'Economy', 'Sedan', 'SUV', 'MPV'].map((s) {
          return DropdownMenuItem(value: s, child: Text(s));
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _categoryFilter = val;
            });
          }
        },
      ),
    );
  }

  Widget _buildStatusDropdown({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButton<String>(
        value: _statusFilter,
        underline: const SizedBox(),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        items: ['All', 'Available', 'Booked', 'Maintenance', 'Inactive'].map((
          s,
        ) {
          return DropdownMenuItem(value: s, child: Text(s));
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _statusFilter = val;
            });
          }
        },
      ),
    );
  }

  Widget _buildChangeStatusDropdown(
    VehicleModel vehicle, {
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 32,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:
              [
                'Available',
                'Booked',
                'Maintenance',
                'Inactive',
              ].contains(vehicle.status)
              ? vehicle.status
              : 'Available',
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 11,
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
          onChanged: (val) async {
            if (val != null) {
              await _vehicleService.updateVehicleStatus(vehicle.id, val);
              _loadData();
            }
          },
          items: const [
            DropdownMenuItem(value: 'Available', child: Text('Available')),
            DropdownMenuItem(value: 'Booked', child: Text('Booked')),
            DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool isCompactMobile = MediaQuery.of(context).size.width <= 600;

    return Container(
      padding: EdgeInsets.all(isCompactMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompactMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isCompactMobile ? 22 : 24),
          ),
          SizedBox(width: isCompactMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: isCompactMobile ? 10 : 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isCompactMobile ? 2 : 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isCompactMobile ? 14 : 16,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleFormDialog extends StatefulWidget {
  final VehicleModel? vehicle;
  final List<BranchModel> branches;
  final VehicleService vehicleService;

  const VehicleFormDialog({
    super.key,
    this.vehicle,
    required this.branches,
    required this.vehicleService,
  });

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _plateController;
  late final TextEditingController _colorController;
  late final TextEditingController _priceController;
  late final TextEditingController _descController;
  late final TextEditingController _mileageController;

  late String _transmission;
  late String _fuelType;
  late String _category;
  late String _status;
  late int _seats;
  BranchModel? _selectedBranch;

  String? _imageUrl;
  bool _uploadingImage = false;
  late List<String> _gallery;
  bool _uploadingGallery = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _brandController = TextEditingController(text: vehicle?.brand ?? '');
    _modelController = TextEditingController(text: vehicle?.model ?? '');
    _yearController = TextEditingController(
      text: vehicle != null ? vehicle.year.toString() : '',
    );
    _plateController = TextEditingController(text: vehicle?.plateNumber ?? '');
    _colorController = TextEditingController(text: vehicle?.color ?? '');
    _priceController = TextEditingController(
      text: vehicle != null ? vehicle.pricePerDay.toString() : '',
    );
    _descController = TextEditingController(text: vehicle?.description ?? '');
    _mileageController = TextEditingController(
      text: vehicle != null ? vehicle.mileage.toString() : '',
    );

    _transmission = vehicle?.transmission ?? 'Automatic';
    _fuelType = vehicle?.fuelType ?? 'Petrol';
    _category = vehicle?.category ?? 'Economy';
    _status = vehicle?.status ?? 'Available';
    _seats = vehicle?.seats ?? 5;

    // Defensive validation for Dialog dropdown values
    final availableCategories = ['Economy', 'Sedan', 'SUV', 'MPV'];
    if (!availableCategories.contains(_category)) {
      _category = 'Economy';
    }

    final availableTransmissions = ['Automatic', 'Manual'];
    if (!availableTransmissions.contains(_transmission)) {
      _transmission = 'Automatic';
    }

    final availableFuelTypes = ['Petrol', 'Diesel', 'Hybrid', 'Electric'];
    if (!availableFuelTypes.contains(_fuelType)) {
      _fuelType = 'Petrol';
    }

    final availableSeats = [4, 5, 7, 8];
    if (!availableSeats.contains(_seats)) {
      _seats = 5;
    }

    final statusLower = _status.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (statusLower == 'available') {
      _status = 'Available';
    } else if (statusLower == 'booked' ||
        statusLower == 'reserved' ||
        statusLower == 'rented' ||
        statusLower == 'activebooked' ||
        statusLower == 'bookedvehicle') {
      _status = 'Booked';
    } else if (statusLower == 'maintenance') {
      _status = 'Maintenance';
    } else if (statusLower == 'inactive') {
      _status = 'Inactive';
    } else {
      _status = 'Available';
    }

    if (vehicle != null && widget.branches.isNotEmpty) {
      final matching = widget.branches.where(
        (b) => b.name == vehicle.branchName || b.id == vehicle.branchId,
      );
      if (matching.isNotEmpty) {
        _selectedBranch = matching.first;
      }
    } else if (widget.branches.isNotEmpty) {
      _selectedBranch = widget.branches.first;
    }

    if (_selectedBranch != null &&
        !widget.branches.any((b) => b.id == _selectedBranch!.id)) {
      _selectedBranch = widget.branches.isNotEmpty
          ? widget.branches.first
          : null;
    } else if (_selectedBranch != null) {
      _selectedBranch = widget.branches.firstWhere(
        (b) => b.id == _selectedBranch!.id,
      );
    }

    _imageUrl = vehicle?.mainImage;
    _gallery = vehicle?.gallery != null
        ? List<String>.from(vehicle!.gallery)
        : [];
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehicle != null;
    final isDarkDialog = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        isEdit ? 'Edit Vehicle Spec' : 'Add New Vehicle',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDarkDialog ? Colors.white : Colors.black,
        ),
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image selector box
              GestureDetector(
                onTap: _uploadingImage
                    ? null
                    : () async {
                        try {
                          final pickedFile = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 35,
                            maxWidth: 600,
                            maxHeight: 600,
                          );
                          if (pickedFile != null) {
                            setState(() => _uploadingImage = true);
                            final bytes = await pickedFile.readAsBytes();
                            final filename =
                                'vehicle_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            final url = await widget.vehicleService
                                .uploadVehicleImage(bytes, filename);
                            setState(() {
                              _imageUrl = url;
                              _uploadingImage = false;
                            });
                          }
                        } catch (e) {
                          debugPrint('Error uploading image: $e');
                          setState(() => _uploadingImage = false);
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
                  child: _uploadingImage
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryOrange,
                          ),
                        )
                      : _imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AppImage(
                            imageSrc: _imageUrl!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 36,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload Car Photo',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.secondaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._gallery.map(
                      (gImg) => SizedBox(
                        width: 88,
                        height: 80,
                        child: Stack(
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
                                child: AppImage(
                                  imageSrc: gImg,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 10,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _gallery.remove(gImg);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Plus Button
                    InkWell(
                      onTap: _uploadingGallery
                          ? null
                          : () async {
                              try {
                                final pickedFile = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 35,
                                  maxWidth: 600,
                                  maxHeight: 600,
                                );
                                if (pickedFile != null) {
                                  setState(() => _uploadingGallery = true);
                                  final bytes = await pickedFile.readAsBytes();
                                  final filename =
                                      'vehicle_gal_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                  final url = await widget.vehicleService
                                      .uploadVehicleImage(bytes, filename);
                                  setState(() {
                                    _gallery.add(url);
                                    _uploadingGallery = false;
                                  });
                                }
                              } catch (e) {
                                debugPrint('Error uploading gallery image: $e');
                                setState(() => _uploadingGallery = false);
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
                        child: _uploadingGallery
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryOrange,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.grey[400],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand / Make (e.g. Proton)',
                ),
              ),
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model (e.g. Saga)',
                ),
              ),
              TextField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Manufacture Year',
                ),
              ),
              TextField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: 'Plate Number'),
              ),
              TextField(
                controller: _colorController,
                decoration: const InputDecoration(labelText: 'Exterior Color'),
              ),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rental Rate Per Day (RM)',
                ),
              ),
              TextField(
                controller: _mileageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Mileage (km)'),
              ),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Short Description',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['Economy', 'Sedan', 'SUV', 'MPV']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
              ),
              DropdownButtonFormField<String>(
                initialValue: _transmission,
                decoration: const InputDecoration(labelText: 'Transmission'),
                items: ['Automatic', 'Manual']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _transmission = val!),
              ),
              DropdownButtonFormField<String>(
                initialValue: _fuelType,
                decoration: const InputDecoration(labelText: 'Fuel Type'),
                items: ['Petrol', 'Diesel', 'Hybrid', 'Electric']
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) => setState(() => _fuelType = val!),
              ),
              DropdownButtonFormField<int>(
                initialValue: _seats,
                decoration: const InputDecoration(labelText: 'Seats Count'),
                items: [4, 5, 7, 8]
                    .map(
                      (s) =>
                          DropdownMenuItem(value: s, child: Text('$s Seats')),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _seats = val!),
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Vehicle Status'),
                items: const [
                  DropdownMenuItem(
                    value: 'Available',
                    child: Text('Available'),
                  ),
                  DropdownMenuItem(value: 'Booked', child: Text('Booked')),
                  DropdownMenuItem(
                    value: 'Maintenance',
                    child: Text('Under Maintenance'),
                  ),
                  DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                ],
                onChanged: (val) => setState(() => _status = val!),
              ),
              if (widget.branches.isNotEmpty)
                DropdownButtonFormField<BranchModel>(
                  initialValue: _selectedBranch,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Branch Hub',
                  ),
                  items: widget.branches
                      .map(
                        (b) => DropdownMenuItem(value: b, child: Text(b.name)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedBranch = val),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            if (_brandController.text.trim().isEmpty ||
                _modelController.text.trim().isEmpty ||
                _priceController.text.trim().isEmpty ||
                _plateController.text.trim().isEmpty) {
              return;
            }

            final brand = _brandController.text.trim();
            final model = _modelController.text.trim();
            final year =
                int.tryParse(_yearController.text.trim()) ??
                DateTime.now().year;
            final plate = _plateController.text.trim().toUpperCase();
            final color = _colorController.text.trim();
            final price =
                double.tryParse(_priceController.text.trim()) ?? 150.0;
            final desc = _descController.text.trim();
            final mileage =
                int.tryParse(_mileageController.text.trim()) ?? 25000;

            if (isEdit) {
              await widget.vehicleService.updateVehicle(widget.vehicle!.id, {
                'brand': brand,
                'model': model,
                'year': year,
                'plateNumber': plate,
                'color': color,
                'transmission': _transmission,
                'fuelType': _fuelType,
                'seats': _seats,
                'pricePerDay': price,
                'mainImage': _imageUrl ?? widget.vehicle!.mainImage,
                'description': desc,
                'category': _category,
                'mileage': mileage,
                'branchId': _selectedBranch?.id ?? widget.vehicle!.branchId,
                'branchName':
                    _selectedBranch?.name ?? widget.vehicle!.branchName,
                'status': _status,
                'isAvailable': _status == 'Available',
                'gallery': _gallery,
              });
            } else {
              final newVehicle = VehicleModel(
                id: '',
                brand: brand,
                model: model,
                year: year,
                plateNumber: plate,
                color: color,
                transmission: _transmission,
                fuelType: _fuelType,
                seats: _seats,
                pricePerDay: price,
                isAvailable: _status == 'Available',
                status: _status,
                mainImage:
                    _imageUrl ??
                    'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=600',
                description: desc,
                createdAt: DateTime.now().toIso8601String(),
                category: _category,
                mileage: mileage,
                branchId: _selectedBranch?.id ?? '',
                branchName: _selectedBranch?.name ?? '',
                gallery: _gallery,
              );
              await widget.vehicleService.addVehicle(newVehicle);
            }

            if (!context.mounted) return;
            Navigator.pop(context, true);
          },
          child: Text(isEdit ? 'Save Changes' : 'Add Vehicle'),
        ),
      ],
    );
  }
}
