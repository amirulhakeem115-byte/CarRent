import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../models/user_model.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/app_image.dart';

class AdminProfileView extends StatefulWidget {
  const AdminProfileView({super.key});

  @override
  State<AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends State<AdminProfileView> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final VehicleService _vehicleService = VehicleService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  UserModel? _adminUser;
  bool _loading = true;
  String? _error;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Security Controllers
  final _securityFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  // Stats
  int _totalVehicles = 0;
  int _totalBookingsApproved = 0;
  int _totalPaymentsApproved = 0;
  String _lastLoginTime = 'Never';

  // Image Picker
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileAndStats();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndStats() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        // Fetch Admin profile
        final user = await _databaseService.getUser(currentUser.uid);
        if (user != null) {
          _adminUser = user;
          _nameController.text = user.fullName;
          _emailController.text = user.email;
          _phoneController.text = user.phone;
        }

        // Fetch Stats
        final results = await Future.wait([
          _vehicleService.getVehicles(),
          _bookingService.getBookings(),
          _paymentService.getPayments(),
        ]).timeout(const Duration(seconds: 15));

        final vehiclesList = results[0] as List;
        final bookingsList = results[1] as List;
        final paymentsList = results[2] as List;

        _totalVehicles = vehiclesList.length;
        _totalBookingsApproved = bookingsList
            .where((b) => b.status == 'approved' || b.status == 'ongoing' || b.status == 'completed')
            .length;
        
        _totalPaymentsApproved = paymentsList
            .where((p) => p.status == 'paid' || p.status == 'approved')
            .length;

        // Retrieve last login from DB
        final snap = FirebaseAuth.instance.currentUser?.metadata;
        if (snap != null && snap.lastSignInTime != null) {
          _lastLoginTime = DateFormat('dd MMM yyyy, hh:mm a').format(snap.lastSignInTime!.toLocal());
        }
      }
    } catch (e) {
      debugPrint('Error loading admin profile details: $e');
      setState(() {
        _error = 'Failed to load profile details and fleet activity logs.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _savePersonalInformation() async {
    if (_adminUser == null) return;
    if (!_formKey.currentState!.validate()) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final updatedData = {
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };
      await _databaseService.updateUser(_adminUser!.id, updatedData);
      
      // Update email in Auth if modified (Note: Requires reauth, usually not done directly without verify flow)
      // For now, keep email synced locally in DB and notify user.
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Personal profile settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadProfileAndStats();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update personal details: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_securityFormKey.currentState!.validate()) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.updatePassword(_newPasswordController.text.trim());
        
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Password change failed.';
      if (e.code == 'requires-recent-login') {
        msg = 'Sensitive operation. Please logout and login again to update credentials.';
      } else if (e.message != null) {
        msg = e.message!;
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    if (_adminUser == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        
        setState(() => _loading = true);
        await _databaseService.updateUser(_adminUser!.id, {'profileImage': base64Image});
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Profile photo updated!'), backgroundColor: Colors.green),
        );
        await _loadProfileAndStats();
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _removeProfileImage() async {
    if (_adminUser == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _loading = true);
      await _databaseService.updateUser(_adminUser!.id, {'profileImage': ''});
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Profile photo removed'), backgroundColor: Colors.orange),
      );
      await _loadProfileAndStats();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to remove image: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 950;

    if (_loading && _adminUser == null) {
      return const Center(child: LoadingWidget(message: 'Retrieving Admin Profile settings...'));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadProfileAndStats, child: const Text('Retry')),
          ],
        ),
      );
    }

    final String joinDate = _adminUser != null && _adminUser!.createdAt.isNotEmpty
        ? DateFormat('dd MMMM yyyy').format(DateTime.parse(_adminUser!.createdAt))
        : 'Unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          const Text(
            'Admin Profile Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
          ),
          const Text(
            'Manage security, credentials, details, and view fleet operations achievements.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          Builder(
            builder: (context) {
              final col1 = Column(
                children: [
                  // Picture Box Card
                  _buildCard(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.1),
                          backgroundImage: getAppImageProvider(_adminUser?.profileImage),
                          child: _adminUser?.profileImage.isNotEmpty != true
                              ? const Icon(Icons.person, size: 54, color: AppColors.secondaryBlue)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _adminUser?.fullName ?? 'Administrator',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.secondaryBlue),
                        ),
                        Text(
                          'Super Administrator',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primaryOrange),
                                foregroundColor: AppColors.primaryOrange,
                              ),
                              onPressed: _pickProfileImage,
                              icon: const Icon(Icons.upload, size: 14),
                              label: const Text('Upload Photo', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            if (_adminUser?.profileImage.isNotEmpty == true)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  foregroundColor: Colors.redAccent,
                                ),
                                onPressed: _removeProfileImage,
                                icon: const Icon(Icons.delete_outline, size: 14),
                                label: const Text('Remove', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Fleet Activity Stats Card
                  _buildCard(
                    title: 'Account Activity Logs',
                    icon: Icons.history,
                    child: Column(
                      children: [
                        _buildStatRow('Created Date', joinDate, Icons.calendar_today, Colors.blue),
                        const Divider(),
                        _buildStatRow('Last Telematics Login', _lastLoginTime, Icons.login, Colors.green),
                        const Divider(),
                        _buildStatRow('Total Fleet Vehicles', '$_totalVehicles units', Icons.directions_car, Colors.indigo),
                        const Divider(),
                        _buildStatRow('Approved Rental Bookings', '$_totalBookingsApproved contracts', Icons.book_online, Colors.purple),
                        const Divider(),
                        _buildStatRow('Processed Fleet Revenues', '$_totalPaymentsApproved transactions', Icons.monetization_on, Colors.teal),
                      ],
                    ),
                  ),
                ],
              );

              final col2 = Column(
                children: [
                  // Personal Information Form
                  _buildCard(
                    title: 'Personal Information Details',
                    icon: Icons.person_outline_outlined,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Display Name',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            enabled: false, // Core user account email requires secure validation to change
                            decoration: const InputDecoration(
                              labelText: 'Account Email Address (Read-only)',
                              prefixIcon: Icon(Icons.mail_outline),
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Support Contact Phone',
                              prefixIcon: Icon(Icons.phone_android_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _savePersonalInformation,
                            child: const Text('Save Details', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Password Settings Card
                  _buildCard(
                    title: 'Account Security Settings',
                    icon: Icons.lock_outline,
                    child: Form(
                      key: _securityFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPass,
                            decoration: InputDecoration(
                              labelText: 'New Account Password',
                              prefixIcon: const Icon(Icons.password),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureNewPass ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPass,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              prefixIcon: const Icon(Icons.lock_reset),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPass ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v != _newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _changePassword,
                            child: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );

              return isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: col1),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: col2),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        col1,
                        const SizedBox(height: 24),
                        col2,
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCard({String? title, IconData? icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.secondaryBlue, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.secondaryBlue),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            radius: 18,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryBlue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
