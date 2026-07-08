import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../models/review_model.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/branch_service.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/branch_model.dart';
import '../../../constants/colors.dart';
import 'vehicle_details_screen.dart';
import 'customer_responsive_shell.dart';
import '../../../widgets/app_image.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor =>
      _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor =>
      _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;
  Color get _borderColor =>
      _isDark ? const Color(0xFF334155) : AppColors.borderGray;
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
  double _priceBudget = 1000.0;
  String? _selectedAvailability;
  BranchModel? _selectedBranch;
  String _sortBy = 'recommended';
  bool _isGridView = true;

  StreamSubscription<List<VehicleModel>>? _vehiclesSubscription;
  StreamSubscription<DatabaseEvent>? _allReviewsSubscription;
  Map<String, List<ReviewModel>> _vehicleReviewsCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToVehicles();
    _subscribeToReviews();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      }
    });
  }

  void _subscribeToVehicles() {
    _vehiclesSubscription?.cancel();
    _vehiclesSubscription = _vehicleService.getVehiclesStream().listen((
      vehiclesList,
    ) {
      if (mounted) {
        setState(() {
          _allVehicles = vehiclesList;
        });
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _allVehicles = [];
      _branches = [];
    });
    try {
      final branchesList = await _branchService.getBranches().timeout(
        const Duration(seconds: 8),
      );
      if (mounted) {
        setState(() {
          _branches = branchesList;
        });
      }
    } catch (e) {
      debugPrint('Error loading branches: $e.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vehiclesSubscription?.cancel();
    _allReviewsSubscription?.cancel();
    super.dispose();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_searchController.text.isNotEmpty) count++;
    if (_selectedTransmission != null) count++;
    if (_selectedCategory != null) count++;
    if (_selectedBranch != null) count++;
    if (_selectedAvailability != null) count++;
    if (_priceBudget < 1000.0) count++;
    return count;
  }

  void _subscribeToReviews() {
    _allReviewsSubscription?.cancel();
    _allReviewsSubscription = FirebaseDatabase.instance
        .ref()
        .child('reviews')
        .onValue
        .listen((event) {
          if (mounted) {
            final Map<String, List<ReviewModel>> cache = {};
            if (event.snapshot.exists && event.snapshot.value != null) {
              final Map<dynamic, dynamic> data =
                  event.snapshot.value as Map<dynamic, dynamic>;
              data.forEach((key, value) {
                try {
                  final r = ReviewModel.fromMap(
                    key.toString(),
                    value as Map<dynamic, dynamic>,
                  );
                  cache.putIfAbsent(r.vehicleId, () => []).add(r);
                } catch (e) {
                  debugPrint('Error parsing review in search cache: $e');
                }
              });
            }
            setState(() {
              _vehicleReviewsCache = cache;
            });
          }
        });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedTransmission = null;
      _selectedCategory = null;
      _selectedBranch = null;
      _selectedAvailability = null;
      _priceBudget = 1000.0;
      _sortBy = 'recommended';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Normalization of state values to avoid assertion errors in dropdowns
    final availableTransmissions = [null, 'Automatic', 'Manual'];
    if (!availableTransmissions.contains(_selectedTransmission)) {
      _selectedTransmission = null;
    }

    final availableCategories = [null, 'Economy', 'Sedan', 'SUV', 'MPV'];
    if (!availableCategories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }

    if (_selectedBranch != null &&
        !_branches.any((b) => b.id == _selectedBranch!.id)) {
      _selectedBranch = null;
    } else if (_selectedBranch != null) {
      _selectedBranch = _branches.firstWhere(
        (b) => b.id == _selectedBranch!.id,
      );
    }

    final availableAvailabilities = [
      null,
      'available',
      'booked',
      'maintenance',
    ];
    if (!availableAvailabilities.contains(_selectedAvailability)) {
      _selectedAvailability = null;
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 950;

    // Filter logic
    final filteredVehicles = _allVehicles.where((vehicle) {
      final matchesSearch =
          vehicle.brand.toLowerCase().contains(_searchQuery) ||
          vehicle.model.toLowerCase().contains(_searchQuery);
      final matchesTransmission =
          _selectedTransmission == null ||
          vehicle.transmission == _selectedTransmission;
      final matchesPrice = vehicle.pricePerDay <= _priceBudget;
      final matchesBranch =
          _selectedBranch == null ||
          vehicle.branchName == _selectedBranch!.name;
      final matchesCategory =
          _selectedCategory == null ||
          vehicle.category.toLowerCase() == _selectedCategory!.toLowerCase();
      final matchesAvailability =
          _selectedAvailability == null ||
          vehicle.status.toLowerCase() == _selectedAvailability!.toLowerCase();
      return matchesSearch &&
          matchesTransmission &&
          matchesPrice &&
          matchesBranch &&
          matchesCategory &&
          matchesAvailability;
    }).toList();

    // Sort logic
    if (_sortBy == 'price_asc') {
      filteredVehicles.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
    } else if (_sortBy == 'price_desc') {
      filteredVehicles.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
    } else if (_sortBy == 'brand_asc') {
      filteredVehicles.sort(
        (a, b) => (a.brand + a.model).compareTo(b.brand + b.model),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
                strokeWidth: 2.5,
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
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
                  _buildPageHeader(context),
                  const SizedBox(height: 24),
                  _buildToolbar(isDesktop),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isDesktop) ...[
                        Container(
                          width: 280,
                          margin: const EdgeInsets.only(right: 24),
                          child: _buildDesktopFiltersPanel(),
                        ),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildResultsGridOrList(
                              filteredVehicles,
                              isDesktop,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore Fleet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose from our premium registered cars and start your journey.',
                style: TextStyle(fontSize: 12, color: _subColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(bool isDesktop) {
    final Widget searchField = Container(
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: _textColor, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search brand / model...',
          hintStyle: TextStyle(
            color: _isDark ? Colors.white30 : Colors.grey,
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.search, size: 20, color: _subColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );

    final Widget sortDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: Theme.of(context).cardColor,
          value: _sortBy,
          items: const [
            DropdownMenuItem(value: 'recommended', child: Text('Recommended')),
            DropdownMenuItem(
              value: 'price_asc',
              child: Text('Price: Low to High'),
            ),
            DropdownMenuItem(
              value: 'price_desc',
              child: Text('Price: High to Low'),
            ),
            DropdownMenuItem(value: 'brand_asc', child: Text('Brand: A-Z')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _sortBy = val);
            }
          },
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          icon: Icon(Icons.sort, size: 16, color: _textColor),
        ),
      ),
    );

    final Widget viewToggle = Container(
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _isGridView = true),
            icon: Icon(
              Icons.grid_view_rounded,
              size: 18,
              color: _isGridView ? AppColors.primaryOrange : Colors.grey,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _isGridView = false),
            icon: Icon(
              Icons.view_list_rounded,
              size: 18,
              color: !_isGridView ? AppColors.primaryOrange : Colors.grey,
            ),
          ),
        ],
      ),
    );

    final Widget mobileFilterButton = IconButton(
      onPressed: _showMobileFiltersBottomSheet,
      icon: Badge(
        label: Text('$_activeFiltersCount'),
        isLabelVisible: _activeFiltersCount > 0,
        child: Icon(Icons.tune, color: _textColor),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                sortDropdown,
                const SizedBox(width: 12),
                viewToggle,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: sortDropdown),
                    const SizedBox(width: 8),
                    viewToggle,
                    const SizedBox(width: 4),
                    mobileFilterButton,
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopFiltersPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Select Your Ride" - Now at the top of filters panel
          Text(
            'Select Your Ride',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: _borderColor),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.secondaryBlue,
                ),
              ),
              if (_activeFiltersCount > 0)
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 0),

          // Search Brand/Model - Moved here from toolbar
          const SizedBox(height: 2),
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          // Transmission
          _buildDropdownSectionTitle('TRANSMISSION'),
          _buildDropdownField(
            value: _selectedTransmission,
            items: const [
              DropdownMenuItem(value: null, child: Text('All Transmissions')),
              DropdownMenuItem(value: 'Automatic', child: Text('Automatic')),
              DropdownMenuItem(value: 'Manual', child: Text('Manual')),
            ],
            onChanged: (val) {
              setState(() => _selectedTransmission = val);
            },
          ),
          const SizedBox(height: 16),
          // Category
          _buildDropdownSectionTitle('CATEGORY'),
          _buildDropdownField(
            value: _selectedCategory,
            items: const [
              DropdownMenuItem(value: null, child: Text('All Categories')),
              DropdownMenuItem(value: 'Economy', child: Text('Economy')),
              DropdownMenuItem(value: 'Sedan', child: Text('Sedan')),
              DropdownMenuItem(value: 'SUV', child: Text('SUV')),
              DropdownMenuItem(value: 'MPV', child: Text('MPV')),
            ],
            onChanged: (val) {
              setState(() => _selectedCategory = val);
            },
          ),
          const SizedBox(height: 16),
          // Branch
          _buildDropdownSectionTitle('BRANCH HUB'),
          _buildDropdownField(
            value: _selectedBranch,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Branches')),
              ..._branches.map(
                (b) => DropdownMenuItem(value: b, child: Text(b.name)),
              ),
            ],
            onChanged: (val) {
              setState(() => _selectedBranch = val);
            },
          ),
          const SizedBox(height: 16),
          // Availability
          _buildDropdownSectionTitle('AVAILABILITY'),
          _buildDropdownField(
            value: _selectedAvailability,
            items: const [
              DropdownMenuItem(value: null, child: Text('All Availability')),
              DropdownMenuItem(value: 'available', child: Text('Available')),
              DropdownMenuItem(value: 'booked', child: Text('Booked')),
              DropdownMenuItem(
                value: 'maintenance',
                child: Text('Under Maintenance'),
              ),
            ],
            onChanged: (val) {
              setState(() => _selectedAvailability = val);
            },
          ),
          const SizedBox(height: 24),
          // Budget Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DAILY BUDGET',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                'RM ${_priceBudget.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryOrange,
              inactiveTrackColor: Colors.grey[200],
              thumbColor: AppColors.primaryOrange,
              overlayColor: AppColors.primaryOrange.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: _priceBudget,
              min: 0,
              max: 1000,
              divisions: 50,
              onChanged: (val) {
                setState(() => _priceBudget = val);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // "Select Your Ride" at the top of mobile filters
                      Text(
                        'Select Your Ride',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose from our premium registered cars and start your journey.',
                        style: TextStyle(fontSize: 13, color: _subColor),
                      ),
                      const SizedBox(height: 20),
                      Divider(color: _borderColor),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _textColor,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _resetFilters();
                              setSheetState(() {});
                            },
                            child: const Text(
                              'Reset All',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search bar in mobile filters
                      Container(
                        decoration: BoxDecoration(
                          color: _isDark
                              ? const Color(0xFF0F172A)
                              : AppColors.lightGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: _textColor, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search brand or model...',
                            hintStyle: TextStyle(
                              color: _isDark ? Colors.white30 : Colors.grey,
                              fontSize: 13,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 18,
                              color: _subColor,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.toLowerCase();
                            });
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdownSectionTitle('Transmission'),
                      _buildDropdownField(
                        value: _selectedTransmission,
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('All Transmissions'),
                          ),
                          DropdownMenuItem(
                            value: 'Automatic',
                            child: Text('Automatic'),
                          ),
                          DropdownMenuItem(
                            value: 'Manual',
                            child: Text('Manual'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedTransmission = val);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownSectionTitle('Category'),
                      _buildDropdownField(
                        value: _selectedCategory,
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('All Categories'),
                          ),
                          DropdownMenuItem(
                            value: 'Economy',
                            child: Text('Economy'),
                          ),
                          DropdownMenuItem(
                            value: 'Sedan',
                            child: Text('Sedan'),
                          ),
                          DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                          DropdownMenuItem(value: 'MPV', child: Text('MPV')),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedCategory = val);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownSectionTitle('Branch Hub'),
                      _buildDropdownField(
                        value: _selectedBranch,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Branches'),
                          ),
                          ..._branches.map(
                            (b) =>
                                DropdownMenuItem(value: b, child: Text(b.name)),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedBranch = val);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownSectionTitle('Availability'),
                      _buildDropdownField(
                        value: _selectedAvailability,
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('All Availability'),
                          ),
                          DropdownMenuItem(
                            value: 'available',
                            child: Text('Available'),
                          ),
                          DropdownMenuItem(
                            value: 'booked',
                            child: Text('Booked'),
                          ),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Under Maintenance'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedAvailability = val);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daily Budget',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _textColor,
                            ),
                          ),
                          Text(
                            'RM ${_priceBudget.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primaryOrange,
                          inactiveTrackColor: _isDark
                              ? const Color(0xFF0F172A)
                              : Colors.grey[200],
                          thumbColor: AppColors.primaryOrange,
                        ),
                        child: Slider(
                          value: _priceBudget,
                          min: 0,
                          max: 1000,
                          divisions: 50,
                          onChanged: (val) {
                            setState(() => _priceBudget = val);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _subColor,
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          style: TextStyle(
            color: _textColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          dropdownColor: Theme.of(context).cardColor,
        ),
      ),
    );
  }

  Widget _buildResultsGridOrList(List<VehicleModel> vehicles, bool isDesktop) {
    if (vehicles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : Colors.grey[100]!,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_car_filled_outlined,
                size: 48,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              const Text(
                'No matching vehicles found',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.secondaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try adjusting your filter terms or click reset to start over.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _resetFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Reset Filters',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isGridView) {
      final int crossAxisCount = isDesktop
          ? 3
          : (MediaQuery.of(context).size.width > 600 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: vehicles.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 18,
          mainAxisSpacing: 18,
          childAspectRatio: isDesktop
              ? 0.68
              : (crossAxisCount == 1 ? 1.06 : 0.72),
        ),
        itemBuilder: (context, index) {
          return _buildGridCard(vehicles[index]);
        },
      );
    } else {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: vehicles.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return _buildListCard(vehicles[index]);
        },
      );
    }
  }

  Widget _buildGridCard(VehicleModel vehicle) {
    final vehicleReviews = _vehicleReviewsCache[vehicle.id] ?? [];
    final reviewsCount = vehicleReviews.length;
    double avgRating = 0.0;
    if (vehicleReviews.isNotEmpty) {
      avgRating =
          vehicleReviews.map((r) => r.rating).reduce((a, b) => a + b) /
          vehicleReviews.length;
    }
    final bool isAvailable = vehicle.status.toLowerCase() == 'available';
    final Color statusColor = isAvailable
        ? const Color(0xFF10B981)
        : vehicle.status.toLowerCase() == 'booked'
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);
    final bool isDesktop = MediaQuery.of(context).size.width > 950;
    final double imageHeight = isDesktop ? 130 : 100;
    final double contentPadding = isDesktop ? 12 : 10;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Container(
                  height: imageHeight,
                  width: double.infinity,
                  color: _isDark
                      ? const Color(0xFF0F172A)
                      : AppColors.lightGray,
                  child: AppImage(
                    imageSrc: vehicle.mainImage,
                    fit: BoxFit.cover,
                    placeholder: const Icon(
                      Icons.directions_car,
                      color: Colors.grey,
                      size: 48,
                    ),
                  ),
                ),
              ),
              if (vehicle.status.toLowerCase() == 'booked')
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'BOOKED',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vehicle.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(contentPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${vehicle.brand} ${vehicle.model}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _textColor,
                        ),
                      ),
                    ),
                    if (!isDesktop)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'DAILY RATE',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'RM ${vehicle.pricePerDay.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      avgRating > 0 ? avgRating.toStringAsFixed(1) : '4.8',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($reviewsCount)',
                      style: TextStyle(fontSize: 10, color: _subColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        vehicle.branchName.isNotEmpty
                            ? vehicle.branchName
                            : 'General Hub',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSpecTag(
                      Icons.airline_seat_recline_normal,
                      '${vehicle.seats} Seats',
                    ),
                    _buildSpecTag(
                      Icons.settings_input_component,
                      vehicle.transmission,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: _borderColor),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: isDesktop
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.end,
                  children: [
                    if (isDesktop)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DAILY RATE',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'RM ${vehicle.pricePerDay.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: _textColor,
                            ),
                          ),
                        ],
                      ),
                    if (isDesktop)
                      ElevatedButton(
                        onPressed: isAvailable
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CustomerResponsiveShell(
                                          initialIndex: 1,
                                          customBody: VehicleDetailsScreen(
                                            vehicle: vehicle,
                                            hideAppBar: true,
                                          ),
                                        ),
                                  ),
                                ).then((_) => _loadData());
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAvailable
                              ? AppColors.primaryOrange
                              : (_isDark
                                    ? const Color(0xFF0F172A)
                                    : Colors.grey[200]),
                          foregroundColor: isAvailable
                              ? Colors.white
                              : (_isDark ? Colors.white30 : Colors.grey[400]),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          isAvailable ? 'Book Now' : 'Booked',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isAvailable
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CustomerResponsiveShell(
                                            initialIndex: 1,
                                            customBody: VehicleDetailsScreen(
                                              vehicle: vehicle,
                                              hideAppBar: true,
                                            ),
                                          ),
                                    ),
                                  ).then((_) => _loadData());
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAvailable
                                ? AppColors.primaryOrange
                                : (_isDark
                                      ? const Color(0xFF0F172A)
                                      : Colors.grey[200]),
                            foregroundColor: isAvailable
                                ? Colors.white
                                : (_isDark ? Colors.white30 : Colors.grey[400]),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            isAvailable ? 'Book Now' : 'Booked',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(VehicleModel vehicle) {
    final vehicleReviews = _vehicleReviewsCache[vehicle.id] ?? [];
    final reviewsCount = vehicleReviews.length;
    double avgRating = 0.0;
    if (vehicleReviews.isNotEmpty) {
      avgRating =
          vehicleReviews.map((r) => r.rating).reduce((a, b) => a + b) /
          vehicleReviews.length;
    }
    final bool isAvailable = vehicle.status.toLowerCase() == 'available';
    final Color statusColor = isAvailable
        ? const Color(0xFF10B981)
        : vehicle.status.toLowerCase() == 'booked'
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useHorizontal = constraints.maxWidth > 550;

        if (!useHorizontal) {
          return _buildGridCard(vehicle);
        }

        return Container(
          height: 140,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(15),
                    ),
                    child: Container(
                      width: 180,
                      height: double.infinity,
                      color: _isDark
                          ? const Color(0xFF0F172A)
                          : AppColors.lightGray,
                      child: AppImage(
                        imageSrc: vehicle.mainImage,
                        fit: BoxFit.cover,
                        placeholder: const Icon(
                          Icons.directions_car,
                          color: Colors.grey,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  if (vehicle.status.toLowerCase() == 'booked')
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.7),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(15),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'BOOKED',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        vehicle.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${vehicle.brand} ${vehicle.model}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  avgRating > 0
                                      ? avgRating.toStringAsFixed(1)
                                      : '4.8',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _textColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($reviewsCount)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _subColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    vehicle.branchName.isNotEmpty
                                        ? vehicle.branchName
                                        : 'General Hub',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildSpecTag(
                                  Icons.airline_seat_recline_normal,
                                  '${vehicle.seats} Seats',
                                ),
                                const SizedBox(width: 8),
                                _buildSpecTag(
                                  Icons.settings_input_component,
                                  vehicle.transmission,
                                ),
                                const SizedBox(width: 8),
                                _buildSpecTag(
                                  Icons.local_gas_station,
                                  vehicle.fuelType,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      VerticalDivider(width: 24, color: _borderColor),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'DAILY RATE',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'RM ${vehicle.pricePerDay.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: isAvailable
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CustomerResponsiveShell(
                                              initialIndex: 1,
                                              customBody: VehicleDetailsScreen(
                                                vehicle: vehicle,
                                                hideAppBar: true,
                                              ),
                                            ),
                                      ),
                                    ).then((_) => _loadData());
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAvailable
                                  ? AppColors.primaryOrange
                                  : (_isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.grey[200]),
                              foregroundColor: isAvailable
                                  ? Colors.white
                                  : (_isDark
                                        ? Colors.white30
                                        : Colors.grey[400]),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              isAvailable ? 'Book Now' : 'Booked',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _subColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: _subColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
