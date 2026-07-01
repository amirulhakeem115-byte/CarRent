import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/branch_model.dart';
import '../../../services/branch_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../constants/colors.dart';
import '../../../services/file_download_helper.dart' if (dart.library.html) '../../../services/file_download_web.dart' as download_helper;
import '../../../services/location_helper.dart' if (dart.library.html) '../../../services/location_web.dart' as location_helper;


class BranchCluster {
  final double latitude;
  final double longitude;
  final List<BranchModel> items;

  BranchCluster({
    required this.latitude,
    required this.longitude,
    required this.items,
  });
}

class BranchesMapScreen extends StatefulWidget {
  const BranchesMapScreen({super.key});

  @override
  State<BranchesMapScreen> createState() => _BranchesMapScreenState();
}

class _BranchesMapScreenState extends State<BranchesMapScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor => _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;
  Color get _borderColor => _isDark ? const Color(0xFF334155) : AppColors.borderGray;

  final BranchService _branchService = BranchService();
  final MapController _mapController = MapController();
  StreamSubscription<List<BranchModel>>? _branchesSubscription;

  List<BranchModel> _activeBranches = [];
  List<BranchModel> _filteredBranches = [];
  bool _loading = true;
  String? _error;

  double _currentZoom = 9.0;
  LatLng _mapCenter = const LatLng(3.1390, 101.6869); // Default centered around Kuala Lumpur Sentral

  // Current user location (defaults to KL mock region)
  LatLng _currentUserLocation = const LatLng(3.1000, 101.7300);

  void _getUserGeolocation() {
    location_helper.getUserLocation().then((location) {
      if (location != null && mounted) {
        setState(() {
          _currentUserLocation = location;
        });
        _mapController.move(_currentUserLocation, 12.0);
      }
    }).catchError((e) {
      debugPrint('Failed to get geolocation: $e');
    });
  }

  // Search & Selection State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  BranchModel? _selectedBranch;
  bool _showRoute = false;
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _subscribeBranches();
    _getUserGeolocation();
    _searchController.addListener(_onSearchChanged);
  }

  void _subscribeBranches() {
    setState(() {
      _loading = true;
      _error = null;
    });

    _branchesSubscription?.cancel();
    _branchesSubscription = _branchService.getBranchesStream().listen(
      (branchesList) {
        if (mounted) {
          setState(() {
            // Only active branches shown to customers
            _activeBranches = branchesList.where((b) => b.status == 'Active').toList();
            _filterBranches();
            _loading = false;
          });
        }
      },
      onError: (err) {
        debugPrint('Error loading branch stream: $err.');
        if (mounted) {
          setState(() {
            _activeBranches = [];
            _filterBranches();
            _loading = false;
          });
        }
      },
    );
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _filterBranches();
    });
  }

  void _filterBranches() {
    if (_searchQuery.isEmpty) {
      _filteredBranches = List.from(_activeBranches);
    } else {
      _filteredBranches = _activeBranches.where((branch) {
        return branch.branchName.toLowerCase().contains(_searchQuery) ||
            branch.address.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  bool _isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  // Haversine formula to compute distance in km
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  void _findNearestBranch() {
    final validActive = _activeBranches.where((b) => _isValidLatLng(b.latitude, b.longitude)).toList();

    if (validActive.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active branches with valid coordinates found.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    BranchModel? nearest;
    double minDistance = double.maxFinite;

    for (var branch in validActive) {
      final dist = _calculateDistance(
        _currentUserLocation.latitude,
        _currentUserLocation.longitude,
        branch.latitude,
        branch.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = branch;
      }
    }

    if (nearest != null) {
      _selectBranch(nearest);
      setState(() {
        _showRoute = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Found nearest: ${nearest.branchName} (${minDistance.toStringAsFixed(1)} km away)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.secondaryBlue,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _selectBranch(BranchModel branch) {
    setState(() {
      _selectedBranch = branch;
      _isSearchFocused = false;
      if (_isValidLatLng(branch.latitude, branch.longitude)) {
        _mapCenter = LatLng(branch.latitude, branch.longitude);
        _mapController.move(_mapCenter, 12.5);
      }
    });
  }

  void _clearRoute() {
    setState(() {
      _showRoute = false;
    });
  }

  void _zoomToUserLocation() {
    _getUserGeolocation();
    _mapController.move(_currentUserLocation, 11.5);
  }

  // Custom clustering implementation
  List<dynamic> _getClusters() {
    final validActive = _filteredBranches.where((b) => _isValidLatLng(b.latitude, b.longitude)).toList();

    if (_currentZoom >= 11.0) {
      return validActive; // Return flat list at high zoom levels
    }

    // Dynamic threshold based on current zoom levels
    double threshold;
    if (_currentZoom < 6.0) {
      threshold = 1.8;
    } else if (_currentZoom < 8.0) {
      threshold = 0.85;
    } else if (_currentZoom < 10.0) {
      threshold = 0.32;
    } else {
      threshold = 0.12;
    }

    List<dynamic> clustered = [];
    List<BranchModel> remaining = List.from(validActive);

    while (remaining.isNotEmpty) {
      final first = remaining.removeAt(0);
      final List<BranchModel> clusterItems = [first];

      for (int i = remaining.length - 1; i >= 0; i--) {
        final other = remaining[i];
        final double dist = (first.latitude - other.latitude).abs() +
            (first.longitude - other.longitude).abs();
        if (dist < threshold) {
          clusterItems.add(other);
          remaining.removeAt(i);
        }
      }

      if (clusterItems.length > 1) {
        double sumLat = 0;
        double sumLng = 0;
        for (var item in clusterItems) {
          sumLat += item.latitude;
          sumLng += item.longitude;
        }
        clustered.add(BranchCluster(
          latitude: sumLat / clusterItems.length,
          longitude: sumLng / clusterItems.length,
          items: clusterItems,
        ));
      } else {
        clustered.add(first);
      }
    }

    return clustered;
  }

  @override
  void dispose() {
    _branchesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    final branchesAppBar = AppBar(
      backgroundColor: _isDark ? const Color(0xFF1B2436) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, color: _textColor, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Rental Hubs',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: _textColor,
        ),
      ),
    );

    if (_loading) {
      return Scaffold(
        appBar: branchesAppBar,
        body: const Center(
          child: LoadingWidget(message: 'Loading rental hubs...'),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: branchesAppBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _subscribeBranches,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: branchesAppBar,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // --- DESKTOP LAYOUT (SPLIT SCREEN) ---
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Side search & listing panel
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                right: BorderSide(color: _borderColor, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchHeader(isDesktop: true),
                Expanded(
                  child: _selectedBranch != null && !_isSearchFocused
                      ? _buildSelectedBranchDetailPanel()
                      : _buildBranchListWidget(isDesktop: true),
                ),
              ],
            ),
          ),
        ),
        // Map Panel
        Expanded(
          flex: 8,
          child: _buildMapWidget(),
        ),
      ],
    );
  }

  // --- MOBILE LAYOUT (FULL SCREEN STACK) ---
  Widget _buildMobileLayout() {
    return Stack(
      children: [
        // Map fills entire background
        Positioned.fill(
          child: _buildMapWidget(),
        ),

        // Floating Search & Overlay Card at Top
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Column(
            children: [
              _buildFloatingSearchCard(),
              if (_isSearchFocused && _filteredBranches.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildBranchListWidget(isDesktop: false),
                  ),
                ),
            ],
          ),
        ),

        // Floating Action Buttons Row (Right Side)
        Positioned(
          right: 16,
          bottom: _selectedBranch != null ? 240 : 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clear Route Button
              if (_showRoute) ...[
                FloatingActionButton.small(
                  heroTag: 'clear_route_btn',
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  onPressed: _clearRoute,
                  tooltip: 'Clear Route',
                  child: const Icon(Icons.route_outlined),
                ),
                const SizedBox(height: 12),
              ],
              // Find Nearest Hub Button
              FloatingActionButton.small(
                heroTag: 'find_nearest_btn',
                backgroundColor: AppColors.secondaryBlue,
                foregroundColor: Colors.white,
                onPressed: _findNearestBranch,
                tooltip: 'Find Nearest Hub',
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 12),
              // Current User Location Pin Locator Button
              FloatingActionButton.small(
                heroTag: 'current_loc_btn',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.secondaryBlue,
                onPressed: _zoomToUserLocation,
                tooltip: 'My Location',
                child: const Icon(Icons.gps_fixed),
              ),
            ],
          ),
        ),

        // Floating Selected Branch Panel at Bottom
        if (_selectedBranch != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: _borderColor),
              ),
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedBranch!.branchName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: _subColor),
                          onPressed: () => setState(() => _selectedBranch = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedBranch!.address,
                      style: TextStyle(color: _subColor, fontSize: 13, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: AppColors.primaryOrange),
                        const SizedBox(width: 6),
                        Text(
                          _selectedBranch!.phone,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textColor),
                        ),
                        const Spacer(),
                        Icon(Icons.access_time, size: 14, color: _subColor),
                        const SizedBox(width: 6),
                        Text(
                          _selectedBranch!.operatingHours,
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: _subColor),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _showRoute = true;
                              });
                            },
                            icon: const Icon(Icons.directions_outlined, size: 18),
                            label: const Text('Get Directions', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: _isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            download_helper.openUrl(
                              'https://www.google.com/maps/search/?api=1&query=${_selectedBranch!.latitude},${_selectedBranch!.longitude}',
                            );
                          },
                          icon: Icon(Icons.map_outlined, color: _textColor),
                          tooltip: 'Open in Maps',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- MAP WIDGET COMPONENT ---
  Widget _buildMapWidget() {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    final elements = _getClusters();
    final hasValidRoute = _showRoute && _selectedBranch != null && _isValidLatLng(_selectedBranch!.latitude, _selectedBranch!.longitude);

    // Calculate routing distance
    double routeDistance = 0;
    if (hasValidRoute) {
      routeDistance = _calculateDistance(
        _currentUserLocation.latitude,
        _currentUserLocation.longitude,
        _selectedBranch!.latitude,
        _selectedBranch!.longitude,
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _mapCenter,
            initialZoom: _currentZoom,
            onPositionChanged: (position, hasGesture) {
              if (position.zoom != null) {
                setState(() {
                  _currentZoom = position.zoom!;
                });
              }
            },
            onTap: (_, point) {
              setState(() {
                _isSearchFocused = false;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.carrent.app',
            ),
            if (hasValidRoute)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      _currentUserLocation,
                      LatLng(_selectedBranch!.latitude, _selectedBranch!.longitude),
                    ],
                    color: AppColors.primaryOrange,
                    strokeWidth: 4.5,
                    isDotted: true,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // Render Mock User Pin Indicator
                Marker(
                  point: _currentUserLocation,
                  width: 50,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Render Branch & Cluster Pins
                ...elements.map((el) {
                  if (el is BranchCluster) {
                    return Marker(
                      point: LatLng(el.latitude, el.longitude),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () {
                          final nextZoom = (_currentZoom + 2.0).clamp(3.0, 18.0);
                          _mapController.move(LatLng(el.latitude, el.longitude), nextZoom);
                          setState(() {
                            _currentZoom = nextZoom;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBlue.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${el.items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  } else if (el is BranchModel) {
                    final isSelected = _selectedBranch?.id == el.id;
                    return Marker(
                      point: LatLng(el.latitude, el.longitude),
                      width: 45,
                      height: 45,
                      child: GestureDetector(
                        onTap: () => _selectBranch(el),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: isSelected ? Colors.redAccent : AppColors.primaryOrange,
                              size: isSelected ? 42 : 34,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return null;
                }).whereType<Marker>(),
              ],
            ),
          ],
        ),

        // Route indicator overlay (On Desktop / Tablet)
        if (hasValidRoute && isDesktop)
          Positioned(
            top: 16,
            left: 16,
            child: Card(
              color: AppColors.secondaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car, color: AppColors.primaryOrange),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Live Map Routing Active',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Estimated straight line distance: ${routeDistance.toStringAsFixed(1)} km',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 16),
                      onPressed: _clearRoute,
                      tooltip: 'Clear Route',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- FLOATING SEARCH BAR (MOBILE) ---
  Widget _buildFloatingSearchCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.lightText),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onTap: () {
                  setState(() {
                    _isSearchFocused = true;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search rental hub by name...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _filterBranches();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- SIDEBAR SEARCH HEADER (DESKTOP) ---
  Widget _buildSearchHeader({required bool isDesktop}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context)) ...[
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textColor, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  'Branches & Hubs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Locate and request route navigation to our official service centers across Malaysia.',
            style: TextStyle(fontSize: 12, color: _subColor, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            style: TextStyle(color: _textColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search rental hubs by name...',
              hintStyle: TextStyle(color: _isDark ? Colors.white30 : Colors.grey, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: _subColor),
              filled: true,
              fillColor: _isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: _subColor),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _filterBranches();
                        });
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: _findNearestBranch,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Find Nearest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.lightGray,
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _zoomToUserLocation,
                icon: const Icon(Icons.gps_fixed, color: AppColors.secondaryBlue),
                tooltip: 'My Location',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- BRANCH LIST WIDGET PANEL ---
  Widget _buildBranchListWidget({required bool isDesktop}) {
    if (_filteredBranches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No active branches found.',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 12.0, vertical: 8),
      itemCount: _filteredBranches.length,
      itemBuilder: (context, index) {
        final branch = _filteredBranches[index];
        final isValid = _isValidLatLng(branch.latitude, branch.longitude);

        // Distance from mock user
        double distance = 0;
        if (isValid) {
          distance = _calculateDistance(
            _currentUserLocation.latitude,
            _currentUserLocation.longitude,
            branch.latitude,
            branch.longitude,
          );
        }

        final isSelected = _selectedBranch?.id == branch.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryOrange
                  : _borderColor,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.05 : 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (isValid) {
                  _selectBranch(branch);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Branch "${branch.branchName}" does not have valid GPS coordinates.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryOrange.withValues(alpha: 0.1)
                            : (_isDark ? const Color(0xFF0F172A) : AppColors.lightGray),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: isSelected ? AppColors.primaryOrange : _textColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  branch.branchName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _textColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (isValid) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${distance.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      color: AppColors.primaryOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            branch.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: _subColor,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 13, color: _subColor),
                              const SizedBox(width: 4),
                              Text(
                                branch.phone,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _subColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.access_time_outlined, size: 13, color: _subColor),
                              const SizedBox(width: 4),
                              Text(
                                branch.operatingHours,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _subColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- DESKTOP SIDEBAR DETAIL VIEW ---
  Widget _buildSelectedBranchDetailPanel() {
    if (_selectedBranch == null) return const SizedBox.shrink();

    final branch = _selectedBranch!;
    final isValid = _isValidLatLng(branch.latitude, branch.longitude);

    double distance = 0;
    if (isValid) {
      distance = _calculateDistance(
        _currentUserLocation.latitude,
        _currentUserLocation.longitude,
        branch.latitude,
        branch.longitude,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back to listing row
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedBranch = null;
                _showRoute = false;
              });
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.primaryOrange),
            label: const Text('Back to branch list', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(height: 16),
          Text(
            branch.branchName,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _textColor),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'ACTIVE SERVICE HUB',
              style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text('ADDRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _subColor, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(branch.address, style: TextStyle(fontSize: 13, color: _textColor, height: 1.4, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Text('CONTACT INFORMATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _subColor, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 16, color: _subColor),
              const SizedBox(width: 8),
              Text(branch.phone, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textColor)),
            ],
          ),
          const SizedBox(height: 20),
          Text('OPERATING HOURS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _subColor, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time_outlined, size: 16, color: _subColor),
              const SizedBox(width: 8),
              Text(branch.operatingHours, style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: _textColor, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          if (isValid) ...[
            Text('LOCATION ANALYSIS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _subColor, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(
              'Approx. Straight-line distance: ${distance.toStringAsFixed(1)} km away',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textColor),
            ),
          ],
          Divider(height: 40, color: _borderColor),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
            ),
            onPressed: () {
              setState(() {
                _showRoute = true;
              });
            },
            icon: const Icon(Icons.directions_outlined, size: 18),
            label: const Text('Show Directions on Map', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _textColor,
              side: BorderSide(color: _borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () {
              download_helper.openUrl(
                'https://www.google.com/maps/search/?api=1&query=${branch.latitude},${branch.longitude}',
              );
            },
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Open in Google Maps', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
