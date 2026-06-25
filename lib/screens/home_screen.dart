import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
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
import '../widgets/app_image.dart';

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
  final _contactSubjectController = TextEditingController();
  final _contactMessageController = TextEditingController();
  final _contactFormKey = GlobalKey<FormState>();
  bool _loadingSupport = false;

  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

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
          if (_user != null && mounted) {
            if (_user!.role == 'admin') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
              );
              return;
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
              );
              return;
            }
          }
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

  Future<void> _submitContactForm() async {
    if (!_contactFormKey.currentState!.validate()) return;
    setState(() => _loadingSupport = true);
    try {
      await _databaseService.submitSupportMessage(
        name: _contactNameController.text.trim(),
        email: _contactEmailController.text.trim(),
        subject: _contactSubjectController.text.trim(),
        message: _contactMessageController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your message has been sent successfully. Our team will contact you shortly.'),
            backgroundColor: Colors.green,
          ),
        );
        _contactNameController.clear();
        _contactEmailController.clear();
        _contactSubjectController.clear();
        _contactMessageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSupport = false);
      }
    }
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactSubjectController.dispose();
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
        preferredSize: const Size.fromHeight(80),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 80 : 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Branding logo with gradient-like look
                      GestureDetector(
                        onTap: () => _scrollToSection(_homeKey),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.directions_car_filled_rounded,
                                  color: AppColors.primaryOrange,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'CARRENT',
                                style: TextStyle(
                                  fontSize: isDesktop ? 22 : 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.secondaryBlue,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Navigation Links using NavHoverLink
                      if (isDesktop)
                        Row(
                          children: [
                            NavHoverLink(text: 'Home', onTap: () => _scrollToSection(_homeKey)),
                            NavHoverLink(text: 'Fleet', onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const VehicleListScreen()),
                              );
                            }),
                            NavHoverLink(text: 'About Us', onTap: () => _scrollToSection(_aboutKey)),
                            NavHoverLink(text: 'Contact', onTap: () => _scrollToSection(_contactKey)),
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
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.hovered)) {
                                return AppColors.primaryOrange;
                              }
                              return AppColors.secondaryBlue;
                            },
                          ),
                          foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                          padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                            EdgeInsets.symmetric(
                              horizontal: isDesktop ? 24 : 16,
                              vertical: isDesktop ? 18 : 12,
                            ),
                          ),
                          shape: WidgetStateProperty.all<OutlinedBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          elevation: WidgetStateProperty.all<double>(0),
                        ),
                        child: Text(
                          _user != null ? 'MY DASHBOARD' : 'LOGIN / REGISTER',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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



  Widget _buildHeroSection(bool isDesktop) {
    return Container(
      key: _homeKey,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: isDesktop ? 100 : 40,
      ),
      decoration: const BoxDecoration(
        color: AppColors.secondaryBlue,
        image: DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&q=80&w=1200'),
          fit: BoxFit.cover,
          opacity: 0.12,
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: AppColors.primaryOrange, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'MALAYSIA\'S #1 PREMIUM FLEET',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -1,
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(text: 'Drive First.\n'),
                      TextSpan(
                        text: 'Pay Later.',
                        style: TextStyle(color: AppColors.primaryOrange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Redefining mobility in Malaysia. Experience premium logistics, transparent payment schedules, and verified safety with Avis & Hertz standards.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _scrollToSection(_aboutKey),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                        shadowColor: AppColors.primaryOrange.withValues(alpha: 0.4),
                      ),
                      child: const Text('Explore Benefits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const VehicleListScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        children: [
                          Text('Browse Fleet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isDesktop) const SizedBox(height: 40),
              ],
            ),
          ),
          if (isDesktop) const SizedBox(width: 60),
          // Right: Booking Form Card
          Expanded(
            flex: isDesktop ? 1 : 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Book Your Ride',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Premium cars. Instant confirmation.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 24),
                      // Pickup Branch
                      const Text('PICKUP LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 5, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<BranchModel>(
                            value: _selectedPickupBranch,
                            isExpanded: true,
                            icon: const Icon(Icons.location_on_outlined, color: AppColors.primaryOrange),
                            items: _branches.map((b) {
                              return DropdownMenuItem(
                                value: b,
                                child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, fontSize: 13)),
                              );
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
                                const Text('PICKUP DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, letterSpacing: 0.5)),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _selectDate(context, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[200]!),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 5, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: AppColors.primaryOrange),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _pickupDate == null
                                                ? 'Select Date'
                                                : '${_pickupDate!.day}/${_pickupDate!.month}/${_pickupDate!.year}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                                            overflow: TextOverflow.ellipsis,
                                          ),
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
                                const Text('RETURN DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, letterSpacing: 0.5)),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _selectDate(context, false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[200]!),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 5, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: AppColors.primaryOrange),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _returnDate == null
                                                ? 'Select Date'
                                                : '${_returnDate!.day}/${_returnDate!.month}/${_returnDate!.year}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                                            overflow: TextOverflow.ellipsis,
                                          ),
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
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                            shadowColor: AppColors.primaryOrange.withValues(alpha: 0.4),
                          ),
                          onPressed: _searchCars,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 18),
                              SizedBox(width: 8),
                              Text('SEARCH CARS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 60,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(Icons.people_outline, '15,000+', 'Active Customers'),
              if (!isDesktop)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.grey[200], thickness: 1, indent: 40, endIndent: 40),
                )
              else
                SizedBox(height: 50, child: VerticalDivider(color: Colors.grey[200], thickness: 1)),
              _buildStatCard(Icons.directions_car_filled_rounded, '500+', 'Premium Fleet'),
              if (!isDesktop)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.grey[200], thickness: 1, indent: 40, endIndent: 40),
                )
              else
                SizedBox(height: 50, child: VerticalDivider(color: Colors.grey[200], thickness: 1)),
              _buildStatCard(Icons.verified_user_outlined, '99.8%', 'Rental Satisfaction'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.primaryOrange, size: 28),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue, letterSpacing: -0.5),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.lightText, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedSection(bool isDesktop) {
    final availableFleet = _vehicles.where((v) => v.isAvailable).take(3).toList();

    return Container(
      color: AppColors.lightGray,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 100,
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
              fontSize: 12,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Explore Our Premium Fleet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                'Browse through our meticulously curated collection of high-performance vehicles, perfect for business trips or personal journeys across Malaysia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 56),
          availableFleet.isEmpty
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car_filled_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No featured vehicles listed currently.',
                          style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
              : Wrap(
                  spacing: 32,
                  runSpacing: 32,
                  alignment: WrapAlignment.center,
                  children: availableFleet.map((vehicle) {
                    return VehicleHoverCard(vehicle: vehicle);
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
        horizontal: isDesktop ? 80 : 20,
        vertical: 100,
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
              fontSize: 12,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Flexible Rental Solutions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 56),
          Wrap(
            spacing: 32,
            runSpacing: 32,
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
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primaryOrange, size: 24),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(fontSize: 13, color: AppColors.lightText, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(bool isDesktop) {
    return Padding(
      key: _aboutKey,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 100,
      ),
      child: Flex(
        direction: isDesktop ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    fontSize: 12,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Providing Premium Journeys since 2026',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondaryBlue,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'At CARRENT, we build a seamless platform designed to redefine vehicle mobility. Whether it is an airport transfer, long-term business leasing, or weekend getaway fleets, we supply top-tier vehicles under clean, transparent terms.',
                  style: TextStyle(fontSize: 15, color: AppColors.lightText, height: 1.6),
                ),
                const SizedBox(height: 32),
                _buildAboutBullet('Our Mission', 'To empower clients with reliable, well-maintained fleets through frictionless bookings.'),
                const SizedBox(height: 16),
                _buildAboutBullet('Our Vision', 'To establish Malaysia\'s safest, most reliable telematics-driven vehicle network.'),
                const SizedBox(height: 16),
                _buildAboutBullet('Why Choose Us', 'Dynamic DuitNow/FPX deposits, instant identity verification, and live telematics-backed security.'),
              ],
            ),
          ),
          if (isDesktop) const SizedBox(width: 80) else const SizedBox(height: 48),
          Expanded(
            flex: isDesktop ? 1 : 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&q=80&w=800',
                  height: 400,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 400,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, size: 64, color: Colors.grey),
                  ),
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
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 100,
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
              fontSize: 12,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'What Our Customers Say',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 56),
          Wrap(
            spacing: 32,
            runSpacing: 32,
            alignment: WrapAlignment.center,
            children: [
              _buildReviewCard(
                'Amirul A.',
                'Kuala Lumpur',
                'Superb service! The Proton X50 was in pristine condition, and the rental process was smooth. Highly recommend CARRENT for their professional fleet!',
                'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=120',
              ),
              _buildReviewCard(
                'Sarah Tan',
                'Shah Alam',
                'Excellent customer service. The Perodua Axia was extremely fuel-efficient and clean. Renting was straightforward and payments were secure.',
                'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=120',
              ),
              _buildReviewCard(
                'Mathias K.',
                'Putrajaya',
                'The GPS tracking layer is very responsive, allowing me to view where my rental car is in real time. Standard DuitNow QR makes deposits easy!',
                'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&q=80&w=120',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(String name, String location, String text, String avatarUrl) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (_) => const Icon(Icons.star_rounded, color: AppColors.primaryOrange, size: 18)),
          ),
          const SizedBox(height: 20),
          Text(
            '"$text"',
            style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: AppColors.lightText, height: 1.6, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(avatarUrl),
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                  Text(location, style: const TextStyle(fontSize: 11, color: AppColors.lightText, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection(bool isDesktop) {
    return Container(
      color: AppColors.lightGray,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 120 : 20,
        vertical: 100,
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
              fontSize: 12,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Frequently Asked Questions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 56),
          _buildFAQItem('What documents are required to rent a vehicle?', 'You need a valid ID/Passport and a verified driving license upload in your profile to checkout a car reservation.'),
          _buildFAQItem('Is there a security deposit?', 'Yes. Deposits can be paid securely via DuitNow QR or FPX Online Banking, which are fully refunded upon safe return.'),
          _buildFAQItem('How does GPS tracking work?', 'Rented vehicles transmit latitude/longitude coordinates to Firebase Realtime Database. You can track your car location directly in your dashboard.'),
          _buildFAQItem('Can I return the vehicle to a different branch?', 'Yes. Select your preferred pickup and dropoff branches on the checkout page before making a payment.'),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          title: Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, fontSize: 14),
          ),
          iconColor: AppColors.primaryOrange,
          collapsedIconColor: AppColors.secondaryBlue,
          shape: Border.all(color: Colors.transparent),
          collapsedShape: Border.all(color: Colors.transparent),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: const TextStyle(color: AppColors.lightText, fontSize: 13, height: 1.6, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(bool isDesktop) {
    final newsletterController = TextEditingController();
    return Container(
      key: _contactKey,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 100,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Contact Info + Newsletter
              Expanded(
                flex: isDesktop ? 4 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GET IN TOUCH',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Let\'s Start a Conversation',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.secondaryBlue,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Have queries about corporate leases, custom drop-off branches, or DuitNow deposit approvals? Contact our support staff or subscribe to receive our weekly seasonal updates and promotional codes.',
                      style: TextStyle(color: AppColors.lightText, fontSize: 15, height: 1.6),
                    ),
                    const SizedBox(height: 36),
                    // Contact Info Cards
                    _buildContactInfoItem(Icons.location_on_outlined, 'Headquarters', 'Presint 1 Terminal Hub, 62000 Putrajaya'),
                    const SizedBox(height: 16),
                    _buildContactInfoItem(Icons.phone_outlined, 'Direct Phone Support', '+603-8888 1234 (HQ)'),
                    const SizedBox(height: 16),
                    _buildContactInfoItem(Icons.mail_outline_rounded, 'Corporate Email Desk', 'support@carrent.com.my'),
                    const SizedBox(height: 48),
                    // Newsletter Block
                    const Text(
                      'SUBSCRIBE TO NEWSLETTER',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newsletterController,
                            decoration: InputDecoration(
                              labelText: 'Your Email Address',
                              hintText: 'Enter your email',
                              filled: true,
                              fillColor: AppColors.lightGray,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (newsletterController.text.trim().isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Thank you for subscribing to CARRENT!'), backgroundColor: Colors.green),
                              );
                              newsletterController.clear();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Subscribe', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isDesktop) const SizedBox(width: 80) else const SizedBox(height: 48),
              // Right side: Support Contact Form Card
              Expanded(
                flex: isDesktop ? 5 : 0,
                child: Container(
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[100]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _contactFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Send Us a Message',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
                        ),
                        const SizedBox(height: 20),
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
                          controller: _contactSubjectController,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            hintText: 'What is this regarding?',
                            prefixIcon: Icon(Icons.subject_outlined),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Subject is required' : null,
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
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                              shadowColor: AppColors.primaryOrange.withValues(alpha: 0.4),
                            ),
                            onPressed: _loadingSupport ? null : _submitContactForm,
                            child: _loadingSupport
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('SEND MESSAGE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
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
      ),
    );
  }

  Widget _buildContactInfoItem(IconData icon, String title, String detail) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryOrange, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(fontSize: 14, color: AppColors.secondaryBlue, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      color: AppColors.secondaryBlue,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 80,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flex(
                direction: isDesktop ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Col 1: Logo + Slogan
                  SizedBox(
                    width: isDesktop ? 280 : double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                  Icons.directions_car_filled_rounded,
                                  color: AppColors.primaryOrange,
                                  size: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'CARRENT',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Malaysia\'s premier telematics-driven vehicle network. Experience seamless bookings, transparent payment plans, and professional fleets.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.6),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            _buildSocialIcon(Icons.facebook),
                            const SizedBox(width: 10),
                            _buildSocialIcon(Icons.camera_alt_outlined),
                            const SizedBox(width: 10),
                            _buildSocialIcon(Icons.alternate_email),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isDesktop) const SizedBox(height: 40),
                  // Col 2: Services
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SERVICES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0)),
                      const SizedBox(height: 20),
                      _buildFooterLink('Short-Term Rental'),
                      _buildFooterLink('Long-Term Lease'),
                      _buildFooterLink('Airport Transfer'),
                      _buildFooterLink('Corporate Fleet'),
                    ],
                  ),
                  if (!isDesktop) const SizedBox(height: 40),
                  // Col 3: Quick Links
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('QUICK LINKS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0)),
                      const SizedBox(height: 20),
                      _buildFooterLink('Search Vehicles'),
                      _buildFooterLink('Customer Login'),
                      _buildFooterLink('Frequently Asked Questions'),
                      _buildFooterLink('Contact Support Desk'),
                    ],
                  ),
                  if (!isDesktop) const SizedBox(height: 40),
                  // Col 4: Contact HQ
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CARRENT HQ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0)),
                      const SizedBox(height: 20),
                      Text('Presint 1 Terminal Hub,', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                      Text('62000 Putrajaya, Malaysia', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                      const SizedBox(height: 12),
                      Text('Phone: +603-8888 1234', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                      Text('Email: support@carrent.com.my', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 60),
              Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '© 2026 CARRENT PLATFORM. All rights reserved.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                  ),
                  Text(
                    'SaaS Web Platform v2.0',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
    );
  }

  Widget _buildFooterLink(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
      ),
    );
  }
}

class NavHoverLink extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const NavHoverLink({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  State<NavHoverLink> createState() => _NavHoverLinkState();
}

class _NavHoverLinkState extends State<NavHoverLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _isHovered ? FontWeight.bold : FontWeight.w600,
                  color: _isHovered ? AppColors.primaryOrange : AppColors.secondaryBlue,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2,
                width: _isHovered ? 20 : 0,
                color: AppColors.primaryOrange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VehicleHoverCard extends StatefulWidget {
  final VehicleModel vehicle;
  const VehicleHoverCard({super.key, required this.vehicle});

  @override
  State<VehicleHoverCard> createState() => _VehicleHoverCardState();
}

class _VehicleHoverCardState extends State<VehicleHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: v.status == 'available' ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 320,
        transform: Matrix4.translationValues(0.0, (_isHovered && v.status == 'available') ? -8.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: (_isHovered && v.status == 'available') ? 0.08 : 0.03),
              blurRadius: (_isHovered && v.status == 'available') ? 20 : 10,
              offset: Offset(0, (_isHovered && v.status == 'available') ? 10 : 4),
            ),
          ],
          border: Border.all(
            color: (_isHovered && v.status == 'available') ? AppColors.primaryOrange.withValues(alpha: 0.5) : Colors.grey[200]!,
            width: (_isHovered && v.status == 'available') ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                  child: AppImage(
                    imageSrc: v.mainImage,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      height: 180,
                      color: Colors.grey[100],
                      child: const Icon(Icons.car_rental, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBlue.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      v.category.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ),
                
                // Status Overlay Over Vehicle Image
                if (v.status == 'available')
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71), // Green Badge
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'AVAILABLE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (v.status == 'booked') ...[
                  // Dark overlay
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  // Diagonal stamp
                  Positioned.fill(
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.2, // diagonal angle
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE74C3C), width: 3),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Text(
                            'BOOKED',
                            style: TextStyle(
                              color: Color(0xFFE74C3C),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (v.status == 'maintenance') ...[
                  // Dark overlay
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  // Diagonal stamp
                  Positioned.fill(
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE67E22), width: 3),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.build, color: Color(0xFFE67E22), size: 14),
                              SizedBox(width: 6),
                              Text(
                                'MAINTENANCE',
                                style: TextStyle(
                                  color: Color(0xFFE67E22),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${v.brand} ${v.model}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.secondaryBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primaryOrange),
                      const SizedBox(width: 4),
                      Text(
                        v.branchName.isNotEmpty ? v.branchName : 'General Hub',
                        style: const TextStyle(fontSize: 12, color: AppColors.lightText, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Specifications Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSpecBadge(Icons.airline_seat_recline_normal, '${v.seats} Seats'),
                      _buildSpecBadge(Icons.settings_input_component, v.transmission),
                      _buildSpecBadge(Icons.local_gas_station_outlined, v.fuelType),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DAILY RATE', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          Text(
                            'RM ${v.pricePerDay.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppColors.secondaryBlue,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: v.status == 'available' ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VehicleDetailsScreen(vehicle: v),
                            ),
                          );
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: (_isHovered && v.status == 'available') ? 2 : 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14),
                          ],
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
    );
  }

  Widget _buildSpecBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.lightText),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 10, color: AppColors.lightText, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
