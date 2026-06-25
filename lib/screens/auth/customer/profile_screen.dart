import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/review_service.dart';
import '../../../models/user_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/review_model.dart';
import '../../../models/payment_model.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../services/receipt_upload_helper.dart'
    if (dart.library.html) '../../../services/receipt_upload_web.dart'
    as receipt_upload;
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/app_image.dart';
import '../login_screen.dart';

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

  UserModel? _user;
  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  bool _loading = true;
  String? _error;

  // Image Picker
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    receipt_upload.registerPlatformDropzone();
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
        final results = await Future.wait([
          _databaseService.getUser(currentUser.uid),
          _bookingService.getUserBookings(currentUser.uid),
          _paymentService.getUserPayments(currentUser.uid),
        ]).timeout(const Duration(seconds: 10));
        _user = results[0] as UserModel?;
        _bookings = results[1] as List<BookingModel>;
        _payments = results[2] as List<PaymentModel>;
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
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
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (isSaving) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(color: AppColors.primaryOrange),
                    const SizedBox(height: 8),
                    const Text('Saving...', style: TextStyle(color: Colors.grey)),
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
            await _databaseService.updateUser(_user!.id, {'profileImage': base64Image});
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile photo updated successfully'), backgroundColor: Colors.green),
            );
            _loadProfileData();
          },
        );
      }
    } catch (e) {
      debugPrint('Profile photo pick error: $e');
    }
  }

  Future<void> _pickLicenseImage() async {
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
          title: 'Preview Driver License',
          onSave: () async {
            final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
            await _databaseService.updateUser(_user!.id, {
              'licenseImage': base64Image,
              'isVerified': false,
              'licenseStatus': 'pending',
              'licenseRejectionReason': '',
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Driving License uploaded and is awaiting approval'), backgroundColor: AppColors.primaryOrange),
            );
            _loadProfileData();
          },
        );
      }
    } catch (e) {
      debugPrint('License pick error: $e');
    }
  }

  void _showEditProfileDialog() {
    if (_user == null) return;

    final nameController = TextEditingController(text: _user!.fullName);
    final phoneController = TextEditingController(text: _user!.phone);
    final addressController = TextEditingController(text: _user!.address);
    final licenseController = TextEditingController(text: _user!.licenseNumber ?? '');
    final classController = TextEditingController(text: _user!.licenseClass);
    final expiryController = TextEditingController(text: _user!.licenseExpiry);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Residential Address', prefixIcon: Icon(Icons.home_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: licenseController,
                  decoration: const InputDecoration(labelText: 'License Number', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classController,
                  decoration: const InputDecoration(labelText: 'License Class', prefixIcon: Icon(Icons.class_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expiryController,
                  decoration: const InputDecoration(labelText: 'Expiry Date', prefixIcon: Icon(Icons.calendar_today_outlined)),
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
                  'licenseNumber': licenseController.text.trim().toUpperCase(),
                  'licenseClass': classController.text.trim(),
                  'licenseExpiry': expiryController.text.trim(),
                });
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          starVal <= selectedRating ? Icons.star : Icons.star_border,
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      const SnackBar(content: Text('Review submitted! Thank you.'), backgroundColor: Colors.green),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(),
      body: _loading
          ? const Center(child: LoadingWidget(message: 'Loading profile details...'))
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
                          onPressed: _loadProfileData,
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
                children: [
                  // Profile Header Banner Card (Image Reference 2)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
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
                                backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.1),
                                backgroundImage: getAppImageProvider(_user?.profileImage),
                                child: _user?.profileImage.isNotEmpty != true || getAppImageProvider(_user?.profileImage) == null
                                    ? const Icon(Icons.person, size: 36, color: AppColors.secondaryBlue)
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: AppColors.primaryOrange, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
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
                                _user?.fullName.isNotEmpty == true ? _user!.fullName : 'Username',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondaryBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _user?.email ?? '',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: _showEditProfileDialog,
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              icon: const Icon(Icons.logout, size: 16),
                              label: const Text('Logout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                final nav = Navigator.of(context);
                                await _authService.logout();
                                nav.pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                                _buildDetailRow('RESIDENTIAL ADDRESS', _user?.address ?? 'N/A'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // 2. Driving Credentials Card
                            _buildInfoCard(
                              title: 'Driving Credentials',
                              icon: Icons.badge_outlined,
                              children: [
                                _buildDetailRow('LICENSE CLASS', _user?.licenseClass ?? 'Class DA'),
                                 Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'STATUS',
                                      style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _user == null
                                            ? Colors.grey.withValues(alpha: 0.1)
                                            : _user!.licenseStatus == 'approved'
                                                ? Colors.green.withValues(alpha: 0.1)
                                                : _user!.licenseStatus == 'rejected'
                                                    ? Colors.red.withValues(alpha: 0.1)
                                                    : Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _user == null
                                            ? 'License Status: Not Provided'
                                            : _user!.licenseStatus == 'approved'
                                                ? 'License Status: Approved'
                                                : _user!.licenseStatus == 'rejected'
                                                    ? 'License Status: Rejected'
                                                    : 'License Status: Pending',
                                        style: TextStyle(
                                          color: _user == null
                                              ? Colors.grey
                                              : _user!.licenseStatus == 'approved'
                                                  ? Colors.green
                                                  : _user!.licenseStatus == 'rejected'
                                                      ? Colors.red
                                                      : Colors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_user != null && _user!.licenseStatus == 'rejected' && _user!.licenseRejectionReason.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Rejection Reason: ${_user!.licenseRejectionReason}',
                                      style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                _buildDetailRow('LICENSE NUMBER', _user?.licenseNumber ?? 'Not Provided'),
                                _buildDetailRow('EXPIRY DATE', _user?.licenseExpiry ?? '12 / 2028'),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[200],
                                      foregroundColor: AppColors.secondaryBlue,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                                    label: const Text('Update Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    onPressed: _pickLicenseImage,
                                  ),
                                ),
                              ],
                            ),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Recent Bookings',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                                  ),
                                  TextButton(
                                    onPressed: _loadProfileData,
                                    child: const Text('View All', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Statistics Row
                              Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: width > 600 ? 4 : 2,
                                  childAspectRatio: width > 600 ? 2.5 : 2.0,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  children: [
                                    _buildStatMiniTile('Total Bookings', '${_bookings.length}', Icons.book_online, Colors.blue),
                                    _buildStatMiniTile('Active Bookings', '${_bookings.where((b) => b.status == 'approved' || b.status == 'active' || b.status == 'ongoing').length}', Icons.directions_car, Colors.orange),
                                    _buildStatMiniTile('Completed', '${_bookings.where((b) => b.status == 'completed').length}', Icons.check_circle_outline, Colors.green),
                                    _buildStatMiniTile('Total Spent', 'RM ${_bookings.where((b) => b.status == 'completed' || b.status == 'active' || b.status == 'approved' || b.status == 'ongoing').fold(0.0, (sum, b) => sum + b.totalPrice).toStringAsFixed(0)}', Icons.monetization_on, Colors.indigo),
                                  ],
                                ),
                              ),
                              _bookings.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Column(
                                          children: [
                                            Icon(Icons.history_toggle_off, size: 48, color: Colors.grey[300]),
                                            const SizedBox(height: 12),
                                            Text('No rental history found.', style: TextStyle(color: Colors.grey[500])),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _bookings.length > 5 ? 5 : _bookings.length,
                                      itemBuilder: (context, index) {
                                        final booking = _bookings[index];
                                        final dateFormat = DateFormat('dd MMM yyyy');
                                        
                                        Color statusColor = Colors.orange;
                                        if (booking.status == 'approved' || booking.status == 'ongoing') {
                                          statusColor = Colors.blue;
                        } else if (booking.status == 'completed') {
                                          statusColor = Colors.green;
                                        } else if (booking.status == 'cancelled' || booking.status == 'rejected') {
                                          statusColor = Colors.red;
                                        }
                                        final paymentList = _payments.where((p) => p.bookingId == booking.id).toList();
                                        final payment = paymentList.isNotEmpty ? paymentList.first : null;

                                        return Card(
                                          color: const Color(0xFFF8F9FA),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 0,
                                          margin: const EdgeInsets.only(bottom: 12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    // Left rounded vehicle image
                                                    Container(
                                                      width: 80,
                                                      height: 60,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Icon(Icons.directions_car, color: Colors.grey),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    // Center detail text block
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            booking.vehicleName,
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryBlue),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            'Booking ID: #${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length).toUpperCase()}',
                                                            style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.calendar_today, size: 10, color: Colors.grey),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                '${dateFormat.format(booking.pickUpDate)} - ${dateFormat.format(booking.returnDate)}',
                                                                style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.payments_outlined, size: 10, color: Colors.grey),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                'RM ${booking.totalPrice.toStringAsFixed(2)}',
                                                                style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    // Right status badge
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: statusColor.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        booking.status.toUpperCase(),
                                                        style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (payment != null) ...[
                                                  const Divider(height: 16),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Text(
                                                            'Payment Status: ',
                                                            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                                          ),
                                                          _buildPaymentBadge(payment),
                                                        ],
                                                      ),
                                                      if (payment.paymentStatus == 'Rejected')
                                                        TextButton.icon(
                                                          onPressed: () => _showReUploadReceiptDialog(payment),
                                                          icon: const Icon(Icons.replay_outlined, size: 14, color: AppColors.primaryOrange),
                                                          label: const Text(
                                                            'Re-upload Receipt',
                                                            style: TextStyle(color: AppColors.primaryOrange, fontSize: 11, fontWeight: FontWeight.bold),
                                                          ),
                                                          style: TextButton.styleFrom(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  if (payment.paymentStatus == 'Rejected' && payment.rejectionReason != null && payment.rejectionReason!.isNotEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        'Rejection Reason: ${payment.rejectionReason}',
                                                        style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
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
                                                        backgroundColor: AppColors.secondaryBlue,
                                                        foregroundColor: Colors.white,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                      ),
                                                      icon: const Icon(Icons.rate_review, size: 14),
                                                      label: const Text('SUBMIT REVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                      onPressed: () => _submitReview(booking),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? receiptBase64;
        String? receiptName;
        int? receiptSize;
        String? errorMsg;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Register callback to update dialog state
            receipt_upload.onReceiptUploadedCallback = (String base64, String name, int size) {
              setDialogState(() {
                if (base64 == 'error:size' || size > 10 * 1024 * 1024) {
                  errorMsg = 'File size exceeds 10MB limit.';
                  receiptBase64 = null;
                  receiptName = null;
                  receiptSize = null;
                } else if (base64 == 'error:format') {
                  errorMsg = 'Invalid file format. Only JPG, JPEG, PNG, and PDF are accepted.';
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Re-upload Payment Receipt', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Upload a new, valid transaction receipt proof to clear verification.', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    if (kIsWeb) ...[
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const HtmlElementView(viewType: 'receipt-dropzone'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final file = await receipt_upload.pickReceiptFile();
                          if (file != null) {
                            setDialogState(() {
                              if (file.base64Data == 'error:size' || file.size > 10 * 1024 * 1024) {
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final file = await receipt_upload.pickReceiptFile();
                          if (file != null) {
                            setDialogState(() {
                              if (file.base64Data == 'error:size' || file.size > 10 * 1024 * 1024) {
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
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
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
                          child: receiptName!.toLowerCase().endsWith('.pdf') || receiptBase64!.startsWith('data:application/pdf')
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 54),
                                    const SizedBox(height: 6),
                                    Text(
                                      receiptName ?? 'Receipt.pdf',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (receiptSize != null)
                                      Text(
                                        '${(receiptSize! / 1024 / 1024).toStringAsFixed(2)} MB',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                        label: const Text('Remove File', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ],
                    if (isSubmitting) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(color: AppColors.primaryOrange),
                      const SizedBox(height: 8),
                      const Text('Uploading proof...', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                  onPressed: receiptBase64 == null || isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          try {
                            // Update payments record
                            await FirebaseDatabase.instance.ref().child('payments').child(payment.id).update({
                              'receiptImage': receiptBase64,
                              'receiptFile': receiptBase64,
                              'paymentStatus': 'Pending Verification',
                              'status': 'pending',
                              'uploadedAt': DateTime.now().toIso8601String(),
                              'rejectionReason': '',
                            });
                            // Set booking back to pending
                            await FirebaseDatabase.instance.ref().child('bookings').child(payment.bookingId).update({
                              'status': 'pending',
                              'updatedAt': DateTime.now().toIso8601String(),
                            });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('New receipt uploaded successfully! Waiting for verification.'), backgroundColor: Colors.green),
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
                  child: const Text('SUBMIT PROOF', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatMiniTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 4, offset: const Offset(0, 2)),
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
                Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
