import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../services/theme_provider.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/review_service.dart';
import '../../../models/user_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/review_model.dart';
import '../../../models/payment_model.dart';
import '../../../services/vehicle_service.dart';
import '../../../models/vehicle_model.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'reward_history_screen.dart';
import '../../../services/receipt_upload_helper.dart'
    if (dart.library.html) '../../../services/receipt_upload_web.dart'
    as receipt_upload;
import '../../../widgets/app_image.dart';
import '../login_screen.dart';
import '../../../services/file_download_helper.dart'
    if (dart.library.html) '../../../services/file_download_web.dart'
    as download_helper;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  final ReviewService _reviewService = ReviewService();
  final VehicleService _vehicleService = VehicleService();

  UserModel? _user;
  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  List<VehicleModel> _vehicles = [];
  bool _loading = true;
  String? _error;

  String? _qrCodeUrl;
  String? _bankName;
  String? _accountName;
  String? _accountNumber;
  String? _bankLogoUrl;

  // Image Picker
  final _picker = ImagePicker();

  // Identity and License Controllers
  final _idNumberController = TextEditingController();
  String _selectedIdType = 'National ID';
  XFile? _idImageFile;
  bool _uploadingId = false;

  final _licenseNumberController = TextEditingController();
  String _selectedLicenseClass = 'Class D';
  DateTime? _licenseExpiryDate;
  XFile? _licenseImageFile;
  bool _uploadingLicense = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    receipt_upload.registerPlatformDropzone();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        _user = await _databaseService
            .getUser(currentUser.uid)
            .timeout(const Duration(seconds: 5));
        if (_user == null) {
          throw Exception("User profile not found in database");
        }

        if (mounted) {
          setState(() {
            _loading = false;
            if (_idNumberController.text.isEmpty) {
              _idNumberController.text = _user?.idNumber ?? '';
            }
            if (_user?.idType.isNotEmpty == true) {
              _selectedIdType = _user!.idType;
            }
            if (_licenseNumberController.text.isEmpty &&
                _user?.licenseNumber != null) {
              _licenseNumberController.text = _user!.licenseNumber!;
            }
            if (_user?.licenseClass.isNotEmpty == true) {
              _selectedLicenseClass = _user!.licenseClass;
            }
            if (_user?.licenseExpiry.isNotEmpty == true) {
              try {
                _licenseExpiryDate = DateFormat(
                  'dd / MM / yyyy',
                ).parse(_user!.licenseExpiry);
              } catch (_) {}
            }
          });
        }

        // Fetch bookings, payments, QR settings, and vehicles asynchronously in the background
        Future.wait([
              _bookingService.getUserBookings(currentUser.uid),
              _paymentService.getUserPayments(currentUser.uid),
              _databaseService.getQrPaymentSettings(),
              _vehicleService.getVehicles(),
            ])
            .timeout(const Duration(seconds: 10))
            .then((results) {
              if (mounted) {
                setState(() {
                  _bookings = results[0] as List<BookingModel>;
                  _payments = results[1] as List<PaymentModel>;
                  final qrSettings = results[2] as Map<String, dynamic>?;
                  _vehicles = results[3] as List<VehicleModel>;
                  if (qrSettings != null) {
                    _qrCodeUrl =
                        qrSettings['qrCodeBase64'] ?? qrSettings['qrCodeUrl'];
                    _bankName = qrSettings['bankName'];
                    _accountName = qrSettings['accountName'];
                    _accountNumber = qrSettings['accountNumber'];
                    _bankLogoUrl = qrSettings['bankLogoUrl'];
                  }
                });
              }
            })
            .catchError((err) {
              debugPrint(
                'Error loading background data for ProfileScreen: $err',
              );
              if (mounted) {
                setState(() {
                  if (_vehicles.isEmpty) {
                    _vehicles = [];
                  }
                });
              }
            });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load profile details. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showImagePreviewDialog({
    required Uint8List imageBytes,
    required String title,
    required Future<void> Function() onSave,
  }) async {
    bool isSaving = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryBlue,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(imageBytes, fit: BoxFit.cover),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (isSaving) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Saving...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });
                          try {
                            await onSave();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = 'Save failed: $e';
                            });
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickProfileImage() async {
    if (_user == null) return;
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 35,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        await _showImagePreviewDialog(
          imageBytes: bytes,
          title: 'Preview Profile Photo',
          onSave: () async {
            final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
            await _databaseService.updateUser(_user!.id, {
              'profileImage': base64Image,
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _loadProfileData();
          },
        );
      }
    } catch (e) {
      debugPrint('Profile photo pick error: $e');
    }
  }

  void _showEditProfileDialog() {
    if (_user == null) return;

    final nameController = TextEditingController(text: _user!.fullName);
    final phoneController = TextEditingController(text: _user!.phone);
    final addressController = TextEditingController(text: _user!.address);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Profile Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryBlue,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Residential Address',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
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
                backgroundColor: AppColors.secondaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await _databaseService.updateUser(_user!.id, {
                  'fullName': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'address': addressController.text.trim(),
                });
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadProfileData();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _submitReview(BookingModel booking) {
    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text('Rate ${booking.vehicleName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How was your rental experience?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1.0;
                      return IconButton(
                        icon: Icon(
                          starVal <= selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = starVal;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Share your feedback...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
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
                  ),
                  onPressed: () async {
                    if (commentController.text.trim().isEmpty) return;

                    final review = ReviewModel(
                      id: '',
                      vehicleId: booking.vehicleId,
                      userId: booking.userId,
                      userName: booking.userName,
                      rating: selectedRating,
                      comment: commentController.text.trim(),
                      createdAt: DateTime.now(),
                    );

                    await _reviewService.submitReview(review);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Review submitted! Thank you.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryOrange,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_error != null) {
      return Center(
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
                onPressed: _loadProfileData,
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
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60.0 : 20.0,
        vertical: 24.0,
      ),
      child: Column(
        children: [
          // Profile Header Banner Card (Image Reference 2)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                // Avatar clickable to change profile photo
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.secondaryBlue.withValues(
                          alpha: 0.1,
                        ),
                        backgroundImage: getAppImageProvider(
                          _user?.profileImage,
                        ),
                        child:
                            _user?.profileImage.isNotEmpty != true ||
                                getAppImageProvider(_user?.profileImage) == null
                            ? const Icon(
                                Icons.person,
                                size: 36,
                                color: AppColors.secondaryBlue,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Username + Email details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user?.fullName.isNotEmpty == true
                            ? _user!.fullName
                            : 'Username',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : AppColors.secondaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _user?.email ?? '',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: AppColors.primaryOrange,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_user?.rewardPoints ?? 0} Points',
                            style: const TextStyle(
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit profile and logout buttons row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _showEditProfileDialog,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await _authService.logout();
                        nav.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) =>
                                LoginScreen(onLoggedIn: () {}),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Dual Column layout (Grid layout in mockup)
          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Personal info & credentials
              Expanded(
                flex: isDesktop ? 4 : 0,
                child: Column(
                  children: [
                    // 1. Personal Information Card
                    _buildInfoCard(
                      title: 'Personal Information',
                      icon: Icons.person_outline,
                      children: [
                        _buildDetailRow('EMAIL ADDRESS', _user?.email ?? 'N/A'),
                        _buildDetailRow('PHONE NUMBER', _user?.phone ?? 'N/A'),
                        _buildDetailRow(
                          'RESIDENTIAL ADDRESS',
                          _user?.address ?? 'N/A',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Loyalty Rewards
                    _buildInfoCard(
                      title: 'Loyalty Rewards',
                      icon: Icons.stars_rounded,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CURRENT BALANCE',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_user?.rewardPoints ?? 0} Points',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryOrange,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              icon: const Icon(Icons.history, size: 14),
                              label: const Text(
                                'View Ledger',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RewardHistoryScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Theme Settings
                    _buildInfoCard(
                      title: 'Theme Settings',
                      icon: Icons.brightness_6_outlined,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'THEME MODE',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    themeProvider.themeMode == ThemeMode.system
                                        ? 'System Default'
                                        : themeProvider.themeMode ==
                                              ThemeMode.light
                                        ? 'Light Mode'
                                        : 'Dark Mode',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.secondaryBlue,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownButton<ThemeMode>(
                              value: themeProvider.themeMode,
                              onChanged: (mode) {
                                if (mode != null) {
                                  themeProvider.setThemeMode(mode);
                                }
                              },
                              dropdownColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : AppColors.secondaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: ThemeMode.system,
                                  child: Text('System'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.light,
                                  child: Text('Light'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.dark,
                                  child: Text('Dark'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. Identity Verification
                    _buildIdentityVerificationCard(isDark),
                  ],
                ),
              ),
              if (isDesktop) const SizedBox(width: 24),
              if (!isDesktop) const SizedBox(height: 24),

              // Right Column: Recent Bookings (Grid Right in mockup)
              Expanded(
                flex: isDesktop ? 5 : 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Bookings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.secondaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Statistics Row
                      SizedBox(
                        height: isDesktop ? 240 : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: isDesktop ? 2 : 2,
                            childAspectRatio: isDesktop ? 2.2 : 2.0,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            children: [
                              _buildStatMiniTile(
                                'Total Bookings',
                                '${_bookings.length}',
                                Icons.book_online,
                                Colors.blue,
                              ),
                              _buildStatMiniTile(
                                'Active Bookings',
                                '${_bookings.where((b) => b.status == 'approved' || b.status == 'active' || b.status == 'ongoing').length}',
                                Icons.directions_car,
                                Colors.orange,
                              ),
                              _buildStatMiniTile(
                                'Completed',
                                '${_bookings.where((b) => b.status == 'completed').length}',
                                Icons.check_circle_outline,
                                Colors.green,
                              ),
                              _buildStatMiniTile(
                                'Total Spent',
                                'RM ${_bookings.where((b) => b.status == 'completed' || b.status == 'active' || b.status == 'approved' || b.status == 'ongoing').fold(0.0, (sum, b) => sum + b.totalPrice).toStringAsFixed(0)}',
                                Icons.monetization_on,
                                Colors.indigo,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _bookings.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.history_toggle_off,
                                      size: 48,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No rental history found.',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _bookings.length > 5
                                  ? 5
                                  : _bookings.length,
                              itemBuilder: (context, index) {
                                final booking = _bookings[index];
                                final dateFormat = DateFormat('dd MMM yyyy');

                                Color statusColor = Colors.orange;
                                if (booking.status == 'approved' ||
                                    booking.status == 'ongoing') {
                                  statusColor = Colors.blue;
                                } else if (booking.status == 'completed') {
                                  statusColor = Colors.green;
                                } else if (booking.status == 'cancelled' ||
                                    booking.status == 'rejected') {
                                  statusColor = Colors.red;
                                }
                                final paymentList = _payments
                                    .where((p) => p.bookingId == booking.id)
                                    .toList();
                                final payment = paymentList.isNotEmpty
                                    ? paymentList.first
                                    : null;

                                return Card(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF8F9FA),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : Colors.grey[200]!,
                                    ),
                                  ),
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // Left rounded vehicle image
                                            Container(
                                              width: 80,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.directions_car,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Center detail text block
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    booking.vehicleName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: AppColors
                                                          .secondaryBlue,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Booking ID: #${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length).toUpperCase()}',
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.calendar_today,
                                                        size: 10,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${dateFormat.format(booking.pickUpDate)} - ${dateFormat.format(booking.returnDate)}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.payments_outlined,
                                                        size: 10,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'RM ${booking.totalPrice.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Right status badge
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                booking.status.toUpperCase(),
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (payment != null) ...[
                                          const Divider(height: 16),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text(
                                                    'Payment Status: ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  _buildPaymentBadge(payment),
                                                ],
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (payment.receiptImage !=
                                                          null &&
                                                      payment
                                                          .receiptImage!
                                                          .isNotEmpty) ...[
                                                    TextButton.icon(
                                                      onPressed: () =>
                                                          _openReceiptLightbox(
                                                            payment,
                                                          ),
                                                      icon: const Icon(
                                                        Icons
                                                            .visibility_outlined,
                                                        size: 14,
                                                        color: AppColors
                                                            .secondaryBlue,
                                                      ),
                                                      label: const Text(
                                                        'View Receipt',
                                                        style: TextStyle(
                                                          color: AppColors
                                                              .secondaryBlue,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  if (payment.paymentStatus ==
                                                      'Rejected')
                                                    TextButton.icon(
                                                      onPressed:
                                                          _vehicles.any(
                                                            (v) =>
                                                                v.id ==
                                                                    booking
                                                                        .vehicleId &&
                                                                v.status.toLowerCase() ==
                                                                    'maintenance',
                                                          )
                                                          ? null
                                                          : () =>
                                                                _showReUploadReceiptDialog(
                                                                  payment,
                                                                ),
                                                      icon: Icon(
                                                        Icons.replay_outlined,
                                                        size: 14,
                                                        color:
                                                            _vehicles.any(
                                                              (v) =>
                                                                  v.id ==
                                                                      booking
                                                                          .vehicleId &&
                                                                  v.status.toLowerCase() ==
                                                                      'maintenance',
                                                            )
                                                            ? Colors.grey
                                                            : AppColors
                                                                  .primaryOrange,
                                                      ),
                                                      label: Text(
                                                        _vehicles.any(
                                                              (v) =>
                                                                  v.id ==
                                                                      booking
                                                                          .vehicleId &&
                                                                  v.status.toLowerCase() ==
                                                                      'maintenance',
                                                            )
                                                            ? 'Under Maintenance'
                                                            : 'Re-upload Receipt',
                                                        style: TextStyle(
                                                          color:
                                                              _vehicles.any(
                                                                (v) =>
                                                                    v.id ==
                                                                        booking
                                                                            .vehicleId &&
                                                                    v.status.toLowerCase() ==
                                                                        'maintenance',
                                                              )
                                                              ? Colors.grey
                                                              : AppColors
                                                                    .primaryOrange,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          if (payment.paymentStatus ==
                                                  'Rejected' &&
                                              payment.rejectionReason != null &&
                                              payment
                                                  .rejectionReason!
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Rejection Reason: ${payment.rejectionReason}',
                                                style: const TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                        if (booking.status == 'completed') ...[
                                          const Divider(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 32,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.secondaryBlue,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.rate_review,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                'SUBMIT REVIEW',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _submitReview(booking),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(PaymentModel payment) {
    Color badgeColor = Colors.orange;
    String badgeText = 'Pending Verification';

    if (payment.paymentStatus == 'Approved') {
      badgeColor = Colors.green;
      badgeText = 'Approved';
    } else if (payment.paymentStatus == 'Rejected') {
      badgeColor = Colors.red;
      badgeText = 'Rejected';
    } else if (payment.paymentStatus == 'Pending Verification') {
      badgeColor = Colors.amber;
      badgeText = 'Pending Verification';
    } else {
      badgeText = payment.paymentStatus ?? 'Pending Verification';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showReUploadReceiptDialog(PaymentModel payment) {
    final DateFormat dialogDateFormat = DateFormat('yyyy-MM-dd');
    BookingModel? booking;
    try {
      booking = _bookings.firstWhere((b) => b.id == payment.bookingId);
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? receiptBase64;
        String? receiptName;
        int? receiptSize;
        String? errorMsg;
        bool isSubmitting = false;

        final amountController = TextEditingController(
          text: payment.amount.toStringAsFixed(2),
        );
        final referenceController = TextEditingController(
          text: payment.transactionId ?? '',
        );
        DateTime selectedPaymentDate = payment.paymentDate;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Register callback to update dialog state
            receipt_upload.onReceiptUploadedCallback =
                (String base64, String name, int size) {
                  setDialogState(() {
                    if (base64 == 'error:size' || size > 10 * 1024 * 1024) {
                      errorMsg = 'File size exceeds 10MB limit.';
                      receiptBase64 = null;
                      receiptName = null;
                      receiptSize = null;
                    } else if (base64 == 'error:format') {
                      errorMsg =
                          'Invalid file format. Only JPG, JPEG, PNG, and PDF are accepted.';
                      receiptBase64 = null;
                      receiptName = null;
                      receiptSize = null;
                    } else {
                      errorMsg = null;
                      receiptBase64 = base64;
                      receiptName = name;
                      receiptSize = size;
                    }
                  });
                };

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Re-upload Payment Receipt',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryBlue,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (booking != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BOOKING SUMMARY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Vehicle: ${booking.vehicleName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.secondaryBlue,
                              ),
                            ),
                            Text(
                              'Dates: ${dialogDateFormat.format(booking.pickUpDate)} to ${dialogDateFormat.format(booking.returnDate)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryBlue,
                              ),
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Price:',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'RM ${booking.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Deposit Amount:',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'RM ${booking.depositAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_bankName != null && _bankName!.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Bank Name:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_bankLogoUrl != null &&
                                  _bankLogoUrl!.isNotEmpty) ...[
                                AppImage(
                                  imageSrc: _bankLogoUrl!,
                                  height: 18,
                                  placeholder: const SizedBox(),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                _bankName!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Account Number:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _accountNumber ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Account Name:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _accountName ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_qrCodeUrl != null && _qrCodeUrl!.isNotEmpty) ...[
                        Center(
                          child: Container(
                            width: 140,
                            height: 140,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: AppImage(
                              imageSrc: _qrCodeUrl,
                              fit: BoxFit.contain,
                              placeholder: const Icon(
                                Icons.qr_code_2,
                                size: 80,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const Divider(),
                    ],
                    const Text(
                      'Upload a new, valid transaction receipt proof to clear verification.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (kIsWeb) ...[
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const HtmlElementView(
                          viewType: 'receipt-dropzone',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final file = await receipt_upload.pickReceiptFile();
                          if (file != null) {
                            setDialogState(() {
                              if (file.base64Data == 'error:size' ||
                                  file.size > 10 * 1024 * 1024) {
                                errorMsg = 'File size exceeds 10MB limit.';
                                receiptBase64 = null;
                              } else {
                                errorMsg = null;
                                receiptBase64 = file.base64Data;
                                receiptName = file.name;
                                receiptSize = file.size;
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.file_open),
                        label: const Text('Browse Files'),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final file = await receipt_upload.pickReceiptFile();
                          if (file != null) {
                            setDialogState(() {
                              if (file.base64Data == 'error:size' ||
                                  file.size > 10 * 1024 * 1024) {
                                errorMsg = 'File size exceeds 10MB limit.';
                                receiptBase64 = null;
                              } else {
                                errorMsg = null;
                                receiptBase64 = file.base64Data;
                                receiptName = file.name;
                                receiptSize = file.size;
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.file_upload),
                        label: const Text('SELECT RECEIPT FILE'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (errorMsg != null)
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    if (receiptBase64 != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[50],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              receiptName!.toLowerCase().endsWith('.pdf') ||
                                  receiptBase64!.startsWith(
                                    'data:application/pdf',
                                  )
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.redAccent,
                                      size: 54,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      receiptName ?? 'Receipt.pdf',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (receiptSize != null)
                                      Text(
                                        '${(receiptSize! / 1024 / 1024).toStringAsFixed(2)} MB',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                )
                              : Image.memory(
                                  base64Decode(receiptBase64!.split(',').last),
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            receiptBase64 = null;
                            receiptName = null;
                            receiptSize = null;
                            errorMsg = null;
                          });
                        },
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        label: const Text(
                          'Remove File',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Reference ID',
                        hintText: 'e.g., Ref: 123456789012',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (RM)',
                        hintText: 'e.g., 150.00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedPaymentDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(const Duration(days: 7)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedPaymentDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          dialogDateFormat.format(selectedPaymentDate),
                        ),
                      ),
                    ),
                    if (isSubmitting) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(
                        color: AppColors.primaryOrange,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Uploading proof...',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                  ),
                  onPressed: receiptBase64 == null || isSubmitting
                      ? null
                      : () async {
                          final txId = referenceController.text.trim();
                          if (txId.isEmpty) {
                            setDialogState(() {
                              errorMsg =
                                  'Please enter Transaction Reference ID.';
                            });
                            return;
                          }
                          final parsedAmount = double.tryParse(
                            amountController.text.trim(),
                          );
                          if (parsedAmount == null || parsedAmount <= 0) {
                            setDialogState(() {
                              errorMsg = 'Please enter a valid payment amount.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                          });
                          try {
                            // Update payments record
                            await FirebaseDatabase.instance
                                .ref()
                                .child('payments')
                                .child(payment.id)
                                .update({
                                  'receiptImage': receiptBase64,
                                  'receiptFile': receiptBase64,
                                  'paymentStatus': 'Pending Verification',
                                  'status': 'pending',
                                  'uploadedAt': DateTime.now()
                                      .toIso8601String(),
                                  'rejectionReason': '',
                                  'transactionId': txId,
                                  'amount': parsedAmount,
                                  'paymentDate': selectedPaymentDate
                                      .toIso8601String(),
                                });
                            // Set booking back to pending
                            await FirebaseDatabase.instance
                                .ref()
                                .child('bookings')
                                .child(payment.bookingId)
                                .update({
                                  'status': 'pending',
                                  'updatedAt': DateTime.now().toIso8601String(),
                                });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'New receipt uploaded successfully! Waiting for verification.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            _loadProfileData();
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMsg = 'Upload failed: $e';
                            });
                          }
                        },
                  child: const Text(
                    'SUBMIT PROOF',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openReceiptLightbox(PaymentModel payment) {
    if (payment.receiptImage == null || payment.receiptImage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No receipt file uploaded for this transaction.'),
        ),
      );
      return;
    }

    final isPdf =
        payment.receiptImage!.toLowerCase().contains('.pdf') ||
        payment.receiptImage!.startsWith('data:application/pdf');

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.black54,
                elevation: 0,
                title: Text(
                  isPdf ? 'PDF Receipt document' : 'Receipt Image Lightbox',
                  style: const TextStyle(color: Colors.white),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: () {
                      try {
                        final rawBase64 = payment.receiptImage!.split(',').last;
                        final bytes = base64Decode(rawBase64);
                        final ext = isPdf ? 'pdf' : 'png';
                        download_helper.downloadFile(
                          bytes,
                          'receipt_${payment.id}.$ext',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'File download initiated successfully.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Download failed: $e'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  color: Colors.black87,
                  alignment: Alignment.center,
                  child: isPdf
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.redAccent,
                              size: 100,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'PDF Receipt Document Uploaded',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                try {
                                  final rawBase64 = payment.receiptImage!
                                      .split(',')
                                      .last;
                                  final bytes = base64Decode(rawBase64);
                                  download_helper.downloadFile(
                                    bytes,
                                    'receipt_${payment.id}.pdf',
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Download failed: $e'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Download PDF file to view'),
                            ),
                          ],
                        )
                      : InteractiveViewer(
                          panEnabled: true,
                          boundaryMargin: const EdgeInsets.all(20),
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(
                            base64Decode(payment.receiptImage!.split(',').last),
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryOrange, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.secondaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? const Color(0xFF334155) : null),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatMiniTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.secondaryBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // --- IDENTITY & LICENSE UPLOAD FUNCTIONS ---
  Future<void> _pickIdImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked != null) {
        setState(() {
          _idImageFile = picked;
        });
      }
    } catch (e) {
      debugPrint('Error picking ID image: $e');
    }
  }

  Future<void> _pickLicenseImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked != null) {
        setState(() {
          _licenseImageFile = picked;
        });
      }
    } catch (e) {
      debugPrint('Error picking license image: $e');
    }
  }

  Future<void> _submitIdVerification() async {
    if (_user == null) return;
    if (_idNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your National ID or Passport number.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_idImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select/upload your ID card or Passport photo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _uploadingId = true);
    try {
      final bytes = await _idImageFile!.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      await _databaseService.updateUser(_user!.id, {
        'idNumber': _idNumberController.text.trim().toUpperCase(),
        'idType': _selectedIdType,
        'idImage': base64Image,
        'idStatus': 'pending',
        'idUploadDate': DateFormat('dd / MM / yyyy').format(DateTime.now()),
        'idRejectionReason': '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ID/Passport uploaded for verification successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadProfileData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload ID/Passport: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingId = false);
      }
    }
  }

  Future<void> _submitLicenseVerification() async {
    if (_user == null) return;
    if (_licenseNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Driving License number.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_licenseExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your license expiry date.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_licenseImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select/upload your driving license card photo.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _uploadingLicense = true);
    try {
      final bytes = await _licenseImageFile!.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      await _databaseService.updateUser(_user!.id, {
        'licenseNumber': _licenseNumberController.text.trim().toUpperCase(),
        'licenseClass': _selectedLicenseClass,
        'licenseExpiry': DateFormat(
          'dd / MM / yyyy',
        ).format(_licenseExpiryDate!),
        'licenseImage': base64Image,
        'licenseStatus': 'pending',
        'licenseUploadDate': DateFormat(
          'dd / MM / yyyy',
        ).format(DateTime.now()),
        'licenseRejectionReason': '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Driving License uploaded for verification successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadProfileData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload driving license: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingLicense = false);
      }
    }
  }

  Future<void> _selectLicenseExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.primaryOrange,
                    surface: Color(0xFF1E293B),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.secondaryBlue,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _licenseExpiryDate = picked;
      });
    }
  }

  Widget _buildIdentityVerificationCard(bool isDark) {
    if (_user == null) return const SizedBox.shrink();

    final idStatus = _user!.idStatus;
    final licenseStatus = _user!.licenseStatus;

    return _buildInfoCard(
      title: 'Identity Verification',
      icon: Icons.verified_user_outlined,
      children: [
        // Document 1: ID / Passport
        _buildDocumentVerificationRow(
          title: 'National ID or Passport',
          status: idStatus,
          rejectionReason: _user!.idRejectionReason,
          isDark: isDark,
          uploadWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ID Type',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _selectedIdType,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: const [
                  DropdownMenuItem(
                    value: 'National ID',
                    child: Text('National ID / IC'),
                  ),
                  DropdownMenuItem(
                    value: 'Passport',
                    child: Text('International Passport'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedIdType = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Document Number',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              CustomTextField(
                controller: _idNumberController,
                labelText: '',
                hintText: 'Enter ID or Passport Number',
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: 12),
              const Text(
                'Document Photo Card',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: _pickIdImage,
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                  ),
                  alignment: Alignment.center,
                  child: _idImageFile == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 24,
                              color: AppColors.primaryOrange,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Upload document photo',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 28,
                              color: Colors.green,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Document Selected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _uploadingId ? null : _submitIdVerification,
                child: _uploadingId
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit ID / Passport',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // Document 2: Driving License
        _buildDocumentVerificationRow(
          title: 'Driving License',
          status: licenseStatus,
          rejectionReason: _user!.licenseRejectionReason,
          isDark: isDark,
          uploadWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'License Number',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              CustomTextField(
                controller: _licenseNumberController,
                labelText: '',
                hintText: 'Enter License Number',
                prefixIcon: Icons.card_membership_outlined,
              ),
              const SizedBox(height: 12),
              const Text(
                'License Classification Class',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _selectedLicenseClass.contains('DA')
                    ? 'Class DA (Automatic Car)'
                    : 'Class D (Car)',
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: const [
                  DropdownMenuItem(
                    value: 'Class D (Car)',
                    child: Text('Class D (Car)'),
                  ),
                  DropdownMenuItem(
                    value: 'Class DA (Automatic Car)',
                    child: Text('Class DA (Automatic Car)'),
                  ),
                  DropdownMenuItem(
                    value: 'Class B2 (Motorcycle)',
                    child: Text('Class B2 (Motorcycle)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(
                      () => _selectedLicenseClass =
                          '${val.split(' ')[0]} ${val.split(' ')[1]}',
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Expiry Date',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: _selectLicenseExpiryDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _licenseExpiryDate == null
                            ? 'Select Expiry Date'
                            : DateFormat(
                                'dd / MM / yyyy',
                              ).format(_licenseExpiryDate!),
                        style: TextStyle(
                          fontSize: 13,
                          color: _licenseExpiryDate == null
                              ? Colors.grey
                              : (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.primaryOrange,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'License Card Photo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: _pickLicenseImage,
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                  ),
                  alignment: Alignment.center,
                  child: _licenseImageFile == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 24,
                              color: AppColors.primaryOrange,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Upload license photo',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 28,
                              color: Colors.green,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Card Photo Selected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _uploadingLicense
                    ? null
                    : _submitLicenseVerification,
                child: _uploadingLicense
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Driving License',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentVerificationRow({
    required String title,
    required String status,
    required String rejectionReason,
    required bool isDark,
    required Widget uploadWidget,
  }) {
    Color statusColor = Colors.grey;
    String statusText = 'Not Uploaded';

    if (status == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Pending Review';
    } else if (status == 'approved') {
      statusColor = Colors.green;
      statusText = 'Approved';
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'Rejected';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.secondaryBlue,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Reason: $rejectionReason',
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ),
        ],
        if (status == 'pending') ...[
          const SizedBox(height: 12),
          const Text(
            'Documents submitted and awaiting verification review.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
        if (status == 'unprovided' || status == 'rejected') ...[
          const SizedBox(height: 16),
          uploadWidget,
        ],
      ],
    );
  }
}
