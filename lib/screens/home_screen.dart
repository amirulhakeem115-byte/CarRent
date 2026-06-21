import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/branch_service.dart';
import '../services/vehicle_service.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/branch_model.dart';
import 'auth/login_screen.dart';
import 'auth/customer/home_screen.dart';
import 'auth/admin/dashboard_screen.dart';
import 'auth/customer/vehicle_list_screen.dart';
import 'auth/customer/vehicle_details_screen.dart';
import '../widgets/loading_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final BranchService _branchService = BranchService();
  final VehicleService _vehicleService = VehicleService();

  UserModel? _user;
  List<BranchModel> _branches = [];
  BranchModel? _selectedPickupBranch;
  DateTime? _pickupDate;
  DateTime? _returnDate;
  List<VehicleModel> _vehicles = [];
  bool _loading = true;
  String? _error;

  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactMessageController = TextEditingController();
  final _contactFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        try {
          _user = await _databaseService.getUser(currentUser.uid).timeout(const Duration(seconds: 4));
        } catch (userErr) {
          debugPrint('Error getting current user: $userErr. Continuing as guest/offline profile.');
        }
      }
      
      try {
        _branches = await _branchService.getBranches().timeout(const Duration(seconds: 5));
      } catch (branchErr) {
        debugPrint('Error getting branches: $branchErr. Using default branches.');
        _branches = _branchService.getDefaultBranches();
      }

      try {
        _vehicles = await _vehicleService.getVehicles().timeout(const Duration(seconds: 5));
      } catch (vehicleErr) {
        debugPrint('Error getting vehicles: $vehicleErr. Using default vehicles.');
        _vehicles = _vehicleService.getDefaultVehicles();
      }

      if (_branches.isNotEmpty) {
        _selectedPickupBranch = _branches.first;
      }
    } catch (e) {
      debugPrint('Unexpected error loading home data: $e');
      // Even on unexpected errors, make sure we have defaults
      if (_branches.isEmpty) _branches = _branchService.getDefaultBranches();
      if (_vehicles.isEmpty) _vehicles = _vehicleService.getDefaultVehicles();
      if (_branches.isNotEmpty) _selectedPickupBranch = _branches.first;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isPickup) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryOrange,
              onPrimary: Colors.white,
              onSurface: AppColors.secondaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isPickup) {
          _pickupDate = picked;
          if (_returnDate != null && _returnDate!.isBefore(_pickupDate!)) {
            _returnDate = null;
          }
        } else {
          _returnDate = picked;
        }
      });
    }
  }

  void _searchCars() {
    if (_selectedPickupBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup branch location.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VehicleListScreen(),
      ),
    );
  }

  void _submitContactForm() {
    if (!_contactFormKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you! Your message has been sent successfully. Our team will contact you shortly.'),
        backgroundColor: Colors.green,
      ),
    );
    _contactNameController.clear();
    _contactEmailController.clear();
    _contactMessageController.clear();
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60 : 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Branding logo
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_car_filled_rounded,
                        color: AppColors.primaryOrange,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CARRENT',
                        style: TextStyle(
                          fontSize: isDesktop ? 24 : 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondaryBlue,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  // Navigation Links
                  if (isDesktop)
                    Row(
                      children: [
                        _buildNavLink('Home', () {}),
                        _buildNavLink('Fleet', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const VehicleListScreen()),
                          );
                        }),
                        _buildNavLink('About Us', () {}),
                        _buildNavLink('Contact', () {}),
                      ],
                    ),
                  // Login/Register or Dashboard Button
                  ElevatedButton(
                    onPressed: () {
                      if (_user != null) {
                        if (_user!.role == 'admin') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
                          );
                        }
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        ).then((_) => _loadData());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                        vertical: isDesktop ? 16 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                    ),
                    child: Text(
                      _user != null ? 'MY DASHBOARD' : 'LOGIN / REGISTER',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: LoadingWidget(message: 'Loading Car Rental system...'))
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. HERO SECTION
                  _buildHeroSection(isDesktop),

                  // 2. STATISTICS SECTION
                  _buildStatsSection(isDesktop),

                  // 3. FEATURED FLEET SECTION
                  _buildFeaturedSection(isDesktop),

                  // 4. SERVICES SECTION
                  _buildServicesSection(isDesktop),

                  // 5. ABOUT US SECTION
                  _buildAboutSection(isDesktop),

                  // 6. CUSTOMER REVIEWS
                  _buildReviewsSection(isDesktop),

                  // 7. FAQ SECTION
                  _buildFAQSection(isDesktop),

                  // 8. CONTACT SECTION
                  _buildContactSection(isDesktop),

                  // 9. FOOTER
                  _buildFooter(isDesktop),
                ],
              ),
            ),
    );
  }

  Widget _buildNavLink(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.secondaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: isDesktop ? 80 : 40,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryBlue,
            AppColors.secondaryBlue.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Flex(
        direction: isDesktop ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Headline / Pitch Text
          Expanded(
            flex: isDesktop ? 1 : 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    '★ MALAYSIA\'S PREMIUM CAR RENTAL',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Drive First,\nPay Later.',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Experience Avis & Hertz standard car rental services in Malaysia. Premium vehicles, seamless bookings, and GPS tracking support.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                if (!isDesktop) const SizedBox(height: 20),
              ],
            ),
          ),
          const SizedBox(width: 40),
          // Right: Booking Form Card
          Expanded(
            flex: isDesktop ? 1 : 0,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Find Your Perfect Car',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select locations and travel schedules',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  // Pickup Branch
                  const Text('PICKUP LOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<BranchModel>(
                        value: _selectedPickupBranch,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryOrange),
                        items: _branches.map((b) {
                          return DropdownMenuItem(value: b, child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedPickupBranch = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date selection
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PICKUP DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectDate(context, true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGray,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: AppColors.primaryOrange),
                                    const SizedBox(width: 10),
                                    Text(
                                      _pickupDate == null
                                          ? 'Select Date'
                                          : '${_pickupDate!.day}/${_pickupDate!.month}/${_pickupDate!.year}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RETURN DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectDate(context, false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGray,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: AppColors.primaryOrange),
                                    const SizedBox(width: 10),
                                    Text(
                                      _returnDate == null
                                          ? 'Select Date'
                                          : '${_returnDate!.day}/${_returnDate!.month}/${_returnDate!.year}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _searchCars,
                      child: const Text('SEARCH VEHICLES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(bool isDesktop) {
    return Container(
      color: AppColors.lightGray,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: 40,
      ),
      child: Flex(
        direction: isDesktop ? Axis.horizontal : Axis.vertical,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(Icons.people_outline, '15,000+', 'Active Customers'),
          if (!isDesktop) const SizedBox(height: 20),
          _buildStatCard(Icons.directions_car_filled_rounded, '500+', 'Premium Fleet'),
          if (!isDesktop) const SizedBox(height: 20),
          _buildStatCard(Icons.verified_user_outlined, '99.8%', 'Rental Satisfaction'),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
          child: Icon(icon, color: AppColors.primaryOrange, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue)),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.lightText)),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedSection(bool isDesktop) {
    final availableFleet = _vehicles.where((v) => v.isAvailable).take(3).toList();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'FEATURED VEHICLES',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primaryOrange,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore Our Fleet Options',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 48),
          availableFleet.isEmpty
              ? Center(
                  child: Text(
                    'No featured vehicles listed currently.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: availableFleet.map((vehicle) {
                    return SizedBox(
                      width: 280,
                      child: Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.grey[150] ?? const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: vehicle.mainImage.isNotEmpty
                                  ? Image.network(
                                      vehicle.mainImage,
                                      height: 170,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        height: 170,
                                        color: Colors.grey[100],
                                        child: const Icon(Icons.car_rental, size: 48, color: Colors.grey),
                                      ),
                                    )
                                  : Container(
                                      height: 170,
                                      color: Colors.grey[100],
                                      child: const Icon(Icons.car_rental, size: 48, color: Colors.grey),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${vehicle.brand} ${vehicle.model}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.secondaryBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: AppColors.primaryOrange),
                                      const SizedBox(width: 4),
                                      Text(
                                        vehicle.branchName,
                                        style: const TextStyle(fontSize: 12, color: AppColors.lightText),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'RM ${vehicle.pricePerDay.toStringAsFixed(0)} / day',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: AppColors.secondaryBlue,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.primaryOrange,
                                        ),
                                        child: const Text('View Specs', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(bool isDesktop) {
    return Container(
      color: AppColors.lightGray,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'OUR SERVICES',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primaryOrange,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Flexible Rental Solutions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildServiceCard(Icons.car_rental, 'Short-Term Rental', 'Flexible daily and weekly rentals for personal use, road trips, or business excursions.'),
              _buildServiceCard(Icons.calendar_today, 'Long-Term Lease', 'Highly economical monthly leasing programs with maintenance and insurance coverage.'),
              _buildServiceCard(Icons.flight_takeoff, 'Airport Transfer', 'Convenient vehicle pickup and dropoff options directly at KLIA1, KLIA2, and Subang airports.'),
              _buildServiceCard(Icons.business_center, 'Corporate Fleet', 'Tailored corporate logistics management plans for businesses requiring dedicated fleet logistics.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(IconData icon, String title, String body) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
            child: Icon(icon, color: AppColors.primaryOrange, size: 24),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue)),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(fontSize: 13, color: AppColors.lightText, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: 80,
      ),
      child: Flex(
        direction: isDesktop ? Axis.horizontal : Axis.vertical,
        children: [
          Expanded(
            flex: isDesktop ? 1 : 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ABOUT US',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Providing Premium Journeys since 2026',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondaryBlue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'At CARRENT, we build a seamless platform designed to redefine vehicle mobility. Whether it is an airport transfer, long-term business leasing, or weekend getaway fleets, we supply top-tier vehicles under clean, transparent terms.',
                  style: TextStyle(fontSize: 14, color: AppColors.lightText, height: 1.6),
                ),
                const SizedBox(height: 24),
                _buildAboutBullet('Our Mission', 'To empower clients with reliable, well-maintained fleets through frictionless bookings.'),
                const SizedBox(height: 12),
                _buildAboutBullet('Our Vision', 'To establish Malaysia\'s safest, most reliable telematics-driven vehicle network.'),
                const SizedBox(height: 12),
                _buildAboutBullet('Why Choose Us', 'Dynamic DuitNow/FPX deposits, instant identity verification, and live telematics-backed security.'),
              ],
            ),
          ),
          const SizedBox(width: 48),
          Expanded(
            flex: isDesktop ? 1 : 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&q=80&w=800',
                height: 350,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 350,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image, size: 64, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutBullet(String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: AppColors.primaryOrange, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.darkText, height: 1.5),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                TextSpan(text: body, style: const TextStyle(color: AppColors.lightText)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(bool isDesktop) {
    return Container(
      color: AppColors.lightGray,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TESTIMONIALS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primaryOrange,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'What Our Customers Say',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildReviewCard('Amirul A.', 'Kuala Lumpur', 'Superb service! The Proton X50 was in pristine condition, and the mock-bypass quick login let me test the client checkout in seconds. Absolute Tesla website quality styling!'),
              _buildReviewCard('Sarah Tan', 'Shah Alam', 'Excellent customer service. The license verification took less than an hour, and renting a Myvi was extremely straightforward. Payments are well documented.'),
              _buildReviewCard('Mathias K.', 'Putrajaya', 'The GPS tracking layer is very responsive, allowing me to view where my rental car is in real time. Standard DuitNow QR makes deposits easy!'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(String name, String location, String text) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (_) => const Icon(Icons.star, color: AppColors.primaryOrange, size: 16)),
          ),
          const SizedBox(height: 16),
          Text(
            '"$text"',
            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.lightText, height: 1.5),
          ),
          const SizedBox(height: 20),
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
          Text(location, style: const TextStyle(fontSize: 11, color: AppColors.lightText)),
        ],
      ),
    );
  }

  Widget _buildFAQSection(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 120 : 20,
        vertical: 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'COMMON FAQS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primaryOrange,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Frequently Asked Questions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 48),
          _buildFAQItem('What documents are required to rent a vehicle?', 'You need a valid ID/Passport and a verified driving license upload in your profile to checkout a car reservation.'),
          const Divider(height: 1),
          _buildFAQItem('Is there a security deposit?', 'Yes. Deposits can be paid securely via DuitNow QR or FPX Online Banking, which are fully refunded upon safe return.'),
          const Divider(height: 1),
          _buildFAQItem('How does GPS tracking work?', 'Rented vehicles transmit latitude/longitude coordinates to Firebase Realtime Database. You can track your car location directly in your dashboard.'),
          const Divider(height: 1),
          _buildFAQItem('Can I return the vehicle to a different branch?', 'Yes. Select your preferred pickup and dropoff branches on the checkout page before making a payment.'),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, fontSize: 14),
      ),
      iconColor: AppColors.primaryOrange,
      collapsedIconColor: AppColors.secondaryBlue,
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            answer,
            style: const TextStyle(color: AppColors.lightText, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(bool isDesktop) {
    return Container(
      color: AppColors.lightGray,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 120 : 20,
        vertical: 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'GET IN TOUCH',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primaryOrange,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Contact Our Support Team',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _contactFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _contactNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Email is required';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactMessageController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'How can we help you?',
                      prefixIcon: Icon(Icons.message_outlined),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Message cannot be empty' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitContactForm,
                      child: const Text('SEND MESSAGE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      color: AppColors.secondaryBlue,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: 40,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2026 CARRENT PLATFORM. All rights reserved.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
              Row(
                children: [
                  IconButton(icon: Icon(Icons.facebook, color: Colors.white.withValues(alpha: 0.6)), onPressed: () {}),
                  IconButton(icon: Icon(Icons.camera_alt_outlined, color: Colors.white.withValues(alpha: 0.6)), onPressed: () {}),
                  IconButton(icon: Icon(Icons.alternate_email, color: Colors.white.withValues(alpha: 0.6)), onPressed: () {}),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
