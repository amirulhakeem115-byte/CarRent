import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/branch_service.dart';
import '../services/vehicle_service.dart';
import '../services/company_settings_provider.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/branch_model.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'auth/customer/customer_responsive_shell.dart';
import 'auth/admin/dashboard_screen.dart';
import 'auth/customer/vehicle_list_screen.dart';
import 'auth/customer/vehicle_details_screen.dart';
import '../widgets/loading_widget.dart';
import '../widgets/app_image.dart';
import '../widgets/app_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // AI Generated Car Images - Multiple reliable sources
  static const String _aiCarImage1 =
      'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=800&h=500';

  static const String _aiCarImage2 =
      'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=800&h=500';

  static const String _aiCarImage3 =
      'https://images.unsplash.com/photo-1614200187524-dc4b892acf16?auto=format&fit=crop&q=80&w=800&h=500';

  // Using a reliable high-quality car image with transparent-like background
  static const String _aiCarImageUrl =
      'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=800&h=500';

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

  static const List<Map<String, dynamic>> _supplementalBranchOptions = [
    {
      'id': 'kl_klcc',
      'branchName': 'Kuala Lumpur - KLCC',
      'address': 'Suria KLCC Concourse Level, 50088 Kuala Lumpur',
      'phone': '+603-23821234',
      'latitude': 3.1579,
      'longitude': 101.7123,
    },
    {
      'id': 'kl_mid_valley',
      'branchName': 'Kuala Lumpur - Mid Valley',
      'address': 'Mid Valley Megamall Arrival Bay, 59200 Kuala Lumpur',
      'phone': '+603-22871234',
      'latitude': 3.1186,
      'longitude': 101.6769,
    },
    {
      'id': 'johor_bahru_city_square',
      'branchName': 'Johor Bahru - City Square',
      'address': 'City Square Arrival Bay, 80000 Johor Bahru, Johor',
      'phone': '+607-2231234',
      'latitude': 1.4631,
      'longitude': 103.7649,
    },
    {
      'id': 'kelantan_kota_bharu',
      'branchName': 'Kelantan - Kota Bharu',
      'address': 'Jalan Sultan Yahya Petra, 15200 Kota Bharu, Kelantan',
      'phone': '+609-7481234',
      'latitude': 6.1254,
      'longitude': 102.2381,
    },
    {
      'id': 'penang_george_town',
      'branchName': 'Penang - George Town',
      'address': 'Lebuh Pantai Service Hub, 10300 George Town, Penang',
      'phone': '+604-2611234',
      'latitude': 5.4141,
      'longitude': 100.3288,
    },
    {
      'id': 'melaka_sentral',
      'branchName': 'Melaka - Melaka Sentral',
      'address': 'Terminal Melaka Sentral, 75400 Melaka',
      'phone': '+606-2881234',
      'latitude': 2.2343,
      'longitude': 102.2530,
    },
    {
      'id': 'perak_ipoh',
      'branchName': 'Perak - Ipoh',
      'address': 'Jalan Sultan Abdul Jalil Hub, 30300 Ipoh, Perak',
      'phone': '+605-2411234',
      'latitude': 4.5975,
      'longitude': 101.0901,
    },
    {
      'id': 'pahang_kuantan',
      'branchName': 'Pahang - Kuantan',
      'address': 'Jalan Besar Service Centre, 25000 Kuantan, Pahang',
      'phone': '+609-5171234',
      'latitude': 3.8077,
      'longitude': 103.3260,
    },
    {
      'id': 'sabah_kota_kinabalu',
      'branchName': 'Sabah - Kota Kinabalu',
      'address': 'Jalan Tun Fuad Stephens, 88000 Kota Kinabalu, Sabah',
      'phone': '+6088-212345',
      'latitude': 5.9804,
      'longitude': 116.0735,
    },
    {
      'id': 'sarawak_kuching',
      'branchName': 'Sarawak - Kuching',
      'address': 'Jalan Padungan Mobility Hub, 93100 Kuching, Sarawak',
      'phone': '+6082-241234',
      'latitude': 1.5533,
      'longitude': 110.3592,
    },
  ];

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

  List<BranchModel> _buildHomeBranchOptions(List<BranchModel> branches) {
    if (branches.isEmpty) {
      branches = _branchService.getDefaultBranches();
    }

    final existingNames = branches
        .map((branch) => branch.branchName.trim().toLowerCase())
        .toSet();
    final expandedBranches = <BranchModel>[];
    BranchModel? branchTemplate;

    for (final branch in branches) {
      expandedBranches.add(branch);
      branchTemplate ??= branch;
    }

    final template =
        branchTemplate ?? _branchService.getDefaultBranches().first;

    for (final option in _supplementalBranchOptions) {
      final optionName = option['branchName'].toString().toLowerCase();
      if (existingNames.contains(optionName)) {
        continue;
      }
      expandedBranches.add(
        BranchModel(
          id: option['id'] as String,
          branchName: option['branchName'] as String,
          address: option['address'] as String,
          phone: option['phone'] as String,
          latitude: option['latitude'] as double,
          longitude: option['longitude'] as double,
          operatingHours: template.operatingHours,
          status: template.status,
        ),
      );
    }

    return expandedBranches;
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
          _user = await _databaseService
              .getUser(currentUser.uid)
              .timeout(const Duration(seconds: 4));
          if (_user != null && mounted) {
            if (_user!.role == 'admin') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminDashboardScreen(),
                ),
              );
              return;
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerResponsiveShell(),
                ),
              );
              return;
            }
          }
        } catch (userErr) {
          debugPrint(
            'Error getting current user: $userErr. Continuing as guest/offline profile.',
          );
        }
      }

      try {
        _branches = _buildHomeBranchOptions(
          await _branchService.getBranches().timeout(
            const Duration(seconds: 8),
          ),
        );
      } catch (branchErr) {
        debugPrint('Error getting branches: $branchErr.');
        _branches = _buildHomeBranchOptions([]);
      }

      try {
        _vehicles = await _vehicleService.getVehicles().timeout(
          const Duration(seconds: 8),
        );
      } catch (vehicleErr) {
        debugPrint('Error getting vehicles: $vehicleErr.');
        _vehicles = [];
      }

      // Set initial branch selection
      if (_branches.isNotEmpty && _selectedPickupBranch == null) {
        _selectedPickupBranch = _branches.first;
      }
    } catch (e) {
      debugPrint('Unexpected error loading home data: $e');
      if (mounted) {
        setState(
          () => _error = 'Failed to load data. Please check your connection.',
        );
      }
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
        const SnackBar(
          content: Text('Please select a pickup branch location.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VehicleListScreen()),
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
            content: Text(
              'Thank you! Your message has been sent successfully. Our team will contact you shortly.',
            ),
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

  List<DropdownMenuItem<BranchModel>> _buildBranchDropdownItems() {
    return [
      const DropdownMenuItem<BranchModel>(
        value: null,
        child: _BranchDropdownItem(
          label: '--Please select--',
          isPlaceholder: true,
        ),
      ),
      ..._branches.map((branch) {
        return DropdownMenuItem<BranchModel>(
          value: branch,
          child: _BranchDropdownItem(label: branch.name),
        );
      }),
    ];
  }

  Widget _buildHeaderNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        NavHoverLink(text: 'Home', onTap: () => _scrollToSection(_homeKey)),
        NavHoverLink(
          text: 'About Us',
          onTap: () => _scrollToSection(_aboutKey),
        ),
        NavHoverLink(
          text: 'Contact',
          onTap: () => _scrollToSection(_contactKey),
        ),
      ],
    );
  }

  void _navigateToDashboardOrLogin() {
    if (_user != null) {
      if (_user!.role == 'admin') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerResponsiveShell(),
          ),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen(onLoggedIn: () {})),
      ).then((_) => _loadData());
    }
  }

  Widget _buildMobileEndDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_homeKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Us'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_aboutKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Contact Us'),
              onTap: () {
                Navigator.pop(context);
                _scrollToSection(_contactKey);
              },
            ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToDashboardOrLogin();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
            ),
          ],
        ),
      ),
    );
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
    final companyName = context.watch<CompanySettingsProvider>().companyName;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      endDrawer: isDesktop ? null : _buildMobileEndDrawer(),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isDesktop ? 80 : 124),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 80 : 20,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => _scrollToSection(_homeKey),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Row(
                                children: [
                                  const AppLogo(
                                    size: 28,
                                    fallbackColor: AppColors.primaryOrange,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    companyName,
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
                          if (isDesktop) ...[
                            _buildHeaderNavigation(),
                            ElevatedButton(
                              onPressed: _navigateToDashboardOrLogin,
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith<Color?>((
                                      Set<WidgetState> states,
                                    ) {
                                      if (states.contains(
                                        WidgetState.hovered,
                                      )) {
                                        return AppColors.primaryOrange;
                                      }
                                      return AppColors.secondaryBlue;
                                    }),
                                foregroundColor: WidgetStateProperty.all<Color>(
                                  Colors.white,
                                ),
                                padding:
                                    WidgetStateProperty.all<EdgeInsetsGeometry>(
                                      const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 18,
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
                                _user != null
                                    ? 'MY DASHBOARD'
                                    : 'LOGIN / REGISTER',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ] else
                            Builder(
                              builder: (context) => IconButton(
                                onPressed: () =>
                                    Scaffold.of(context).openEndDrawer(),
                                icon: const Icon(
                                  Icons.menu_rounded,
                                  color: AppColors.secondaryBlue,
                                  size: 28,
                                ),
                                tooltip: 'Menu',
                              ),
                            ),
                        ],
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
          ? const Center(
              child: LoadingWidget(message: 'Loading Car Rental system...'),
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

  Widget _buildCarImage(bool isDesktop) {
    final double height = isDesktop ? 420 : 220;
    final double iconSize = isDesktop ? 140 : 100;

    return Container(
      height: height,
      alignment: Alignment.center,
      child: Image.network(
        _aiCarImageUrl,
        height: height,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            height: height,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Try fallback image
          return Image.network(
            'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=800&h=500',
            height: height,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                height: height,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryOrange,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Ultimate fallback - icon
              return Icon(
                Icons.directions_car,
                color: Colors.white.withValues(alpha: 0.8),
                size: iconSize,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(bool isDesktop) {
    return Container(
      key: _homeKey,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: isDesktop ? 80 : 40,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondaryBlue,
            AppColors.secondaryBlue.withValues(alpha: 0.9),
          ],
        ),
        image: const DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&q=80&w=1200',
          ),
          fit: BoxFit.cover,
          opacity: 0.10,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 14 : 10,
                    vertical: isDesktop ? 8 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryOrange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        color: AppColors.primaryOrange,
                        size: isDesktop ? 14 : 10,
                      ),
                      SizedBox(width: isDesktop ? 6 : 4),
                      Text(
                        'MALAYSIA\'S #1 PREMIUM FLEET',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: isDesktop ? 10 : 8,
                          letterSpacing: isDesktop ? 1.5 : 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isDesktop ? 28 : 16),
                Text(
                  'Drive First,\nPay Later.',
                  style: TextStyle(
                    fontSize: isDesktop ? 52 : 28,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: isDesktop ? -1 : -0.5,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isDesktop ? 20 : 12),
                Text(
                  'Redefining mobility in Malaysia. Experience premium logistics, transparent payment schedules, and verified safety with Avis & Hertz standards.',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 13,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: isDesktop ? 1.6 : 1.5,
                  ),
                ),
                SizedBox(height: isDesktop ? 40 : 24),
                Flex(
                  direction: isDesktop ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: isDesktop
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.stretch,
                ),
                if (!isDesktop) const SizedBox(height: 30),
              ],
            ),
          ),
          if (isDesktop) const SizedBox(width: 60),
          // Right: Car Image (AI generated)
          Expanded(
            flex: isDesktop ? 1 : 0,
            child: Align(
              alignment: isDesktop ? Alignment.centerRight : Alignment.center,
              child: _buildCarImage(isDesktop),
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
              _buildStatCard(
                Icons.people_outline,
                '15,000+',
                'Active Customers',
              ),
              if (!isDesktop)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: Colors.grey[200],
                    thickness: 1,
                    indent: 40,
                    endIndent: 40,
                  ),
                )
              else
                SizedBox(
                  height: 50,
                  child: VerticalDivider(color: Colors.grey[200], thickness: 1),
                ),
              _buildStatCard(
                Icons.directions_car_filled_rounded,
                '500+',
                'Premium Fleet',
              ),
              if (!isDesktop)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: Colors.grey[200],
                    thickness: 1,
                    indent: 40,
                    endIndent: 40,
                  ),
                )
              else
                SizedBox(
                  height: 50,
                  child: VerticalDivider(color: Colors.grey[200], thickness: 1),
                ),
              _buildStatCard(
                Icons.verified_user_outlined,
                '99.8%',
                'Rental Satisfaction',
              ),
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
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.secondaryBlue,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.lightText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedSection(bool isDesktop) {
    final availableFleet = _vehicles
        .where((v) => v.isAvailable)
        .take(3)
        .toList();

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
          Text(
            'Explore Our Premium Fleet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 36 : 28,
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
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  height: 1.5,
                ),
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
                        Icon(
                          Icons.directions_car_filled_outlined,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No featured vehicles listed currently.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.bold,
                          ),
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
          Text(
            'Flexible Rental Solutions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 36 : 28,
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
              _buildServiceCard(
                Icons.car_rental,
                'Short-Term Rental',
                'Flexible daily and weekly rentals for personal use, road trips, or business excursions.',
              ),
              _buildServiceCard(
                Icons.calendar_today,
                'Long-Term Lease',
                'Highly economical monthly leasing programs with maintenance and insurance coverage.',
              ),
              _buildServiceCard(
                Icons.flight_takeoff,
                'Airport Transfer',
                'Convenient vehicle pickup and dropoff options directly at KLIA1, KLIA2, and Subang airports.',
              ),
              _buildServiceCard(
                Icons.business_center,
                'Corporate Fleet',
                'Tailored corporate logistics management plans for businesses requiring dedicated fleet logistics.',
              ),
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
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.lightText,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
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
                Text(
                  'Providing Premium Journeys since 2026',
                  style: TextStyle(
                    fontSize: isDesktop ? 36 : 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondaryBlue,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'At ${Provider.of<CompanySettingsProvider>(context).companyName}, we build a seamless platform designed to redefine vehicle mobility. Whether it is an airport transfer, long-term business leasing, or weekend getaway fleets, we supply top-tier vehicles under clean, transparent terms.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.lightText,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                _buildAboutBullet(
                  'Our Mission',
                  'To empower clients with reliable, well-maintained fleets through frictionless bookings.',
                ),
                const SizedBox(height: 16),
                _buildAboutBullet(
                  'Our Vision',
                  'To establish Malaysia\'s safest, most reliable telematics-driven vehicle network.',
                ),
                const SizedBox(height: 16),
                _buildAboutBullet(
                  'Why Choose Us',
                  'Dynamic DuitNow/FPX deposits, instant identity verification, and live telematics-backed security.',
                ),
              ],
            ),
          ),
          if (isDesktop)
            const SizedBox(width: 80)
          else
            const SizedBox(height: 48),
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
                    child: const Icon(
                      Icons.image,
                      size: 64,
                      color: Colors.grey,
                    ),
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
        const Icon(
          Icons.check_circle_outline,
          color: AppColors.primaryOrange,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.darkText,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryBlue,
                  ),
                ),
                TextSpan(
                  text: body,
                  style: const TextStyle(color: AppColors.lightText),
                ),
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
          Text(
            'What Our Customers Say',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 36 : 28,
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
                'Superb service! The Proton X50 was in pristine condition, and the rental process was smooth. Highly recommend ${Provider.of<CompanySettingsProvider>(context).companyName} for their professional fleet!',
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

  Widget _buildReviewCard(
    String name,
    String location,
    String text,
    String avatarUrl,
  ) {
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
            children: List.generate(
              5,
              (_) => const Icon(
                Icons.star_rounded,
                color: AppColors.primaryOrange,
                size: 18,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '"$text"',
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.lightText,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
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
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryBlue,
                    ),
                  ),
                  Text(
                    location,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.lightText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
          Text(
            'Frequently Asked Questions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 36 : 28,
              fontWeight: FontWeight.w900,
              color: AppColors.secondaryBlue,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 56),
          _buildFAQItem(
            'What documents are required to rent a vehicle?',
            'You need a valid ID/Passport and a verified driving license upload in your profile to checkout a car reservation.',
          ),
          _buildFAQItem(
            'Is there a security deposit?',
            'Yes. Deposits can be paid securely via DuitNow QR or FPX Online Banking, which are fully refunded upon safe return.',
          ),
          _buildFAQItem(
            'How does GPS tracking work?',
            'Rented vehicles transmit latitude/longitude coordinates to Firebase Realtime Database. You can track your car location directly in your dashboard.',
          ),
          _buildFAQItem(
            'Can I return the vehicle to a different branch?',
            'Yes. Select your preferred pickup and dropoff branches on the checkout page before making a payment.',
          ),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryBlue,
              fontSize: 14,
            ),
          ),
          iconColor: AppColors.primaryOrange,
          collapsedIconColor: AppColors.secondaryBlue,
          shape: Border.all(color: Colors.transparent),
          collapsedShape: Border.all(color: Colors.transparent),
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 20,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontSize: 13,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(bool isDesktop) {
    InputDecoration contactInputDecoration({
      required String label,
      required String hint,
      required IconData icon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.lightGray,
        labelStyle: const TextStyle(color: Colors.black87),
        hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
        prefixIconColor: Colors.black54,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.secondaryBlue,
            width: 1.4,
          ),
        ),
      );
    }

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
              // Left side: Contact Info
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
                    Text(
                      'Let\'s Start a Conversation',
                      style: TextStyle(
                        fontSize: isDesktop ? 36 : 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.secondaryBlue,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Have queries about corporate leases, custom drop-off branches, or DuitNow deposit approvals? Contact our support staff for assistance.',
                      style: TextStyle(
                        color: AppColors.lightText,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 36),
                    // Contact Info Cards
                    _buildContactInfoItem(
                      Icons.location_on_outlined,
                      'Headquarters',
                      'Presint 1 Terminal Hub, 62000 Putrajaya',
                    ),
                    const SizedBox(height: 16),
                    _buildContactInfoItem(
                      Icons.phone_outlined,
                      'Direct Phone Support',
                      '+603-8888 1234 (HQ)',
                    ),
                    const SizedBox(height: 16),
                    _buildContactInfoItem(
                      Icons.mail_outline_rounded,
                      'Corporate Email Desk',
                      Provider.of<CompanySettingsProvider>(
                        context,
                      ).companyEmail,
                    ),
                  ],
                ),
              ),
              if (isDesktop)
                const SizedBox(width: 80)
              else
                const SizedBox(height: 48),
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
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.secondaryBlue,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _contactNameController,
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          decoration: contactInputDecoration(
                            label: 'Full Name',
                            hint: 'Enter your name',
                            icon: Icons.person_outline,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contactEmailController,
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          decoration: contactInputDecoration(
                            label: 'Email Address',
                            hint: 'Enter your email',
                            icon: Icons.email_outlined,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return 'Email is required';
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val))
                              return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contactSubjectController,
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          decoration: contactInputDecoration(
                            label: 'Subject',
                            hint: 'What is this regarding?',
                            icon: Icons.subject_outlined,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Subject is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contactMessageController,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          decoration: contactInputDecoration(
                            label: 'Message',
                            hint: 'How can we help you?',
                            icon: Icons.message_outlined,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Message cannot be empty'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                              shadowColor: AppColors.primaryOrange.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            onPressed: _loadingSupport
                                ? null
                                : _submitContactForm,
                            child: _loadingSupport
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'SEND MESSAGE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                              child: const AppLogo(
                                size: 24,
                                fallbackColor: AppColors.primaryOrange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Provider.of<CompanySettingsProvider>(
                                context,
                              ).companyName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          Provider.of<CompanySettingsProvider>(
                            context,
                          ).companyDescription,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                            height: 1.6,
                          ),
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
                      const Text(
                        'SERVICES',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
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
                      const Text(
                        'QUICK LINKS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
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
                      Text(
                        '${Provider.of<CompanySettingsProvider>(context).companyName} HQ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        Provider.of<CompanySettingsProvider>(
                          context,
                        ).companyAddress,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Phone: ${Provider.of<CompanySettingsProvider>(context).companyPhone}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Email: ${Provider.of<CompanySettingsProvider>(context).companyEmail}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 60),
              Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1),
              const SizedBox(height: 24),
              Flex(
                direction: isDesktop ? Axis.horizontal : Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isDesktop
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    '© 2026 ${Provider.of<CompanySettingsProvider>(context).companyName}. All rights reserved.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(
                    width: isDesktop ? 16 : 0,
                    height: isDesktop ? 0 : 8,
                  ),
                  Text(
                    'SaaS Web Platform v2.0',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
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
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _BranchDropdownItem extends StatefulWidget {
  final String label;
  final bool isPlaceholder;

  const _BranchDropdownItem({required this.label, this.isPlaceholder = false});

  @override
  State<_BranchDropdownItem> createState() => _BranchDropdownItemState();
}

class _BranchDropdownItemState extends State<_BranchDropdownItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isPlaceholder
        ? AppColors.lightText
        : AppColors.secondaryBlue;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovered
              ? AppColors.primaryOrange.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Text(
          widget.label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: textColor,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class NavHoverLink extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const NavHoverLink({super.key, required this.text, required this.onTap});

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
                  color: _isHovered
                      ? AppColors.primaryOrange
                      : AppColors.secondaryBlue,
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
      cursor: v.status.toLowerCase() == 'available'
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 320,
        transform: Matrix4.translationValues(
          0.0,
          (_isHovered && v.status.toLowerCase() == 'available') ? -8.0 : 0.0,
          0.0,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: (_isHovered && v.status.toLowerCase() == 'available')
                    ? 0.08
                    : 0.03,
              ),
              blurRadius: (_isHovered && v.status.toLowerCase() == 'available')
                  ? 20
                  : 10,
              offset: Offset(
                0,
                (_isHovered && v.status.toLowerCase() == 'available') ? 10 : 4,
              ),
            ),
          ],
          border: Border.all(
            color: (_isHovered && v.status.toLowerCase() == 'available')
                ? AppColors.primaryOrange.withValues(alpha: 0.5)
                : Colors.grey[200]!,
            width: (_isHovered && v.status.toLowerCase() == 'available')
                ? 1.5
                : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(23),
                  ),
                  child: AppImage(
                    imageSrc: v.mainImage,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      height: 180,
                      color: Colors.grey[100],
                      child: const Icon(
                        Icons.car_rental,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBlue.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      v.category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Status Overlay Over Vehicle Image
                if (v.status.toLowerCase() == 'available')
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
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
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(23),
                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE74C3C),
                              width: 3,
                            ),
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
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(23),
                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE67E22),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.build,
                                color: Color(0xFFE67E22),
                                size: 14,
                              ),
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
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.primaryOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        v.branchName.isNotEmpty ? v.branchName : 'General Hub',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.lightText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Specifications Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSpecBadge(
                        Icons.airline_seat_recline_normal,
                        '${v.seats} Seats',
                      ),
                      _buildSpecBadge(
                        Icons.settings_input_component,
                        v.transmission,
                      ),
                      _buildSpecBadge(
                        Icons.local_gas_station_outlined,
                        v.fuelType,
                      ),
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
                          const Text(
                            'DAILY RATE',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
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
                        onPressed: v.status.toLowerCase() == 'available'
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        VehicleDetailsScreen(vehicle: v),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation:
                              (_isHovered &&
                                  v.status.toLowerCase() == 'available')
                              ? 2
                              : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Book Now',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
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
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.lightText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
