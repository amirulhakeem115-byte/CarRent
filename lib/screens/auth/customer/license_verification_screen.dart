import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/company_settings_provider.dart';
import '../../../models/user_model.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../widgets/app_logo.dart';
import '../login_screen.dart';
import 'customer_responsive_shell.dart';

class LicenseVerificationScreen extends StatefulWidget {
  const LicenseVerificationScreen({super.key});

  @override
  State<LicenseVerificationScreen> createState() =>
      _LicenseVerificationScreenState();
}

class _LicenseVerificationScreenState extends State<LicenseVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _databaseService = DatabaseService();
  final _picker = ImagePicker();

  final _licenseNumberController = TextEditingController();
  String _selectedClass = 'Class D';
  DateTime? _expiryDate;
  XFile? _licenseImage;
  bool _submitting = false;

  UserModel? _user;
  bool _loadingUser = true;
  StreamSubscription? _userSubscription;

  final List<String> _licenseClasses = [
    'Class D (Car)',
    'Class DA (Automatic Car)',
    'Class B2 (Motorcycle)',
    'Class B (Heavy Motorcycle)',
    'Class E (Heavy Truck)',
  ];

  @override
  void initState() {
    super.initState();
    _subscribeUser();
  }

  void _subscribeUser() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      setState(() => _loadingUser = false);
      return;
    }
    _userSubscription = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(currentUser.uid)
        .onValue
        .listen((event) {
          if (event.snapshot.exists && event.snapshot.value != null) {
            try {
              final data = event.snapshot.value as Map<dynamic, dynamic>;
              final userModel = UserModel.fromMap(currentUser.uid, data);
              if (mounted) {
                setState(() {
                  _user = userModel;
                  _loadingUser = false;
                  if (_licenseNumberController.text.isEmpty &&
                      userModel.licenseNumber != null) {
                    _licenseNumberController.text = userModel.licenseNumber!;
                  }
                });
                // Auto redirect if approved
                if (userModel.licenseStatus == 'approved') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerResponsiveShell(),
                    ),
                  );
                }
              }
            } catch (e) {
              debugPrint('Error parsing user data in verification screen: $e');
            }
          }
        });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked != null) {
        setState(() {
          _licenseImage = picked;
        });
      }
    } catch (e) {
      debugPrint('Error picking license image: $e');
    }
  }

  Future<void> _selectExpiryDate() async {
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
        _expiryDate = picked;
      });
    }
  }

  Future<void> _submitVerification() async {
    if (_user == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a photo of your driving license.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick your license expiry date.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final bytes = await _licenseImage!.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final formattedExpiry = DateFormat('dd / MM / yyyy').format(_expiryDate!);

      await _databaseService.updateUser(_user!.id, {
        'licenseNumber': _licenseNumberController.text.trim().toUpperCase(),
        'licenseClass': _selectedClass,
        'licenseExpiry': formattedExpiry,
        'licenseImage': base64Image,
        'licenseStatus': 'pending',
        'licenseRejectionReason': '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Driving License uploaded! Status is now pending verification.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _logout() async {
    final nav = Navigator.of(context);
    await _authService.logout();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen(onLoggedIn: () {})),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final companyName = context.watch<CompanySettingsProvider>().companyName;

    if (_loadingUser) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryOrange),
              const SizedBox(height: 16),
              Text(
                'Retrieving verification status...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.secondaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget content = const SizedBox.shrink();

    if (_user != null) {
      final status = _user!.licenseStatus;
      if (status == 'pending') {
        content = _buildPendingState(companyName, isDark);
      } else if (status == 'rejected') {
        content = _buildUploadForm(companyName, isDark, isRejection: true);
      } else {
        content = _buildUploadForm(companyName, isDark);
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const AppLogo(size: 24, fallbackColor: AppColors.primaryOrange),
            const SizedBox(width: 8),
            Text(
              companyName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.secondaryBlue,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: isDark ? Colors.white70 : AppColors.secondaryBlue,
            ),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingState(String companyName, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_empty_rounded,
                  size: 64,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verification In Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.secondaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Our administration team is currently reviewing your driving license verification request. This usually takes less than 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFFCBD5E1) : AppColors.lightText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.primaryOrange,
                ),
                title: const Text(
                  'License Number',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                subtitle: Text(
                  _user?.licenseNumber ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.class_outlined,
                  color: AppColors.primaryOrange,
                ),
                title: const Text(
                  'Class Type',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                subtitle: Text(
                  _user?.licenseClass ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.date_range_outlined,
                  color: AppColors.primaryOrange,
                ),
                title: const Text(
                  'Expiration Date',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                subtitle: Text(
                  _user?.licenseExpiry ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _subscribeUser,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text(
            'Check Status Now',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadForm(
    String companyName,
    bool isDark, {
    bool isRejection = false,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isRejection ? 'Verification Rejected' : 'Verify Driving License',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRejection
                ? 'Your submission was not approved. Please see the details below.'
                : 'Upload your valid driving license card photograph to checkout reservation vehicles.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFFCBD5E1) : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 24),
          if (isRejection &&
              _user?.licenseRejectionReason.isNotEmpty == true) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REJECTION REASON:',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user!.licenseRejectionReason,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.red[800],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Form card inputs
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // License Number input
                const Text(
                  '  Driving License Number',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                CustomTextField(
                  controller: _licenseNumberController,
                  labelText: '',
                  hintText: 'e.g., WQX123456',
                  prefixIcon: Icons.badge_outlined,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Driving License Number is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // License Class select dropdown
                const Text(
                  '  License Classification Class',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedClass.contains('DA')
                      ? 'Class DA (Automatic Car)'
                      : 'Class D (Car)',
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.class_outlined,
                      color: AppColors.primaryOrange,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF1F2937)
                      : Colors.white,
                  items: _licenseClasses.map((String cls) {
                    return DropdownMenuItem<String>(
                      value: cls,
                      child: Text(
                        cls,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedClass =
                            '${val.split(' ')[0]} ${val.split(' ')[1]}';
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Expiry Date picker
                const Text(
                  '  License Expiry Date',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _selectExpiryDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _expiryDate == null
                              ? 'Select Date'
                              : DateFormat(
                                  'dd / MM / yyyy',
                                ).format(_expiryDate!),
                          style: TextStyle(
                            color: _expiryDate == null
                                ? Colors.grey
                                : (isDark ? Colors.white : Colors.black),
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: AppColors.primaryOrange,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Card Photo Upload
                const Text(
                  '  Driving License Card Photo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                    ),
                    alignment: Alignment.center,
                    child: _licenseImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: AppColors.primaryOrange,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Upload photo card from gallery',
                                style: TextStyle(
                                  fontSize: 12,
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
                                size: 44,
                                color: Colors.green,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Card Photo Selected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tap to change card photograph',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Submit Button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _submitting ? null : _submitVerification,
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Submit Documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
