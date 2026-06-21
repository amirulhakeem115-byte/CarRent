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
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/loading_widget.dart';

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
  bool _loading = true;
  String? _error;

  // Image Picker
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
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
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() {
        _error = 'Failed to load profile details. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    if (_user == null) return;
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) {
        final dummyUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';
        await _databaseService.updateUser(_user!.id, {'profileImage': dummyUrl});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully'), backgroundColor: Colors.green),
        );
        _loadProfileData();
      }
    } catch (e) {
      debugPrint('Profile photo pick error: $e');
    }
  }

  Future<void> _pickLicenseImage() async {
    if (_user == null) return;
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) {
        final dummyUrl = 'https://images.unsplash.com/photo-1554774853-aae0a22c8aa4?auto=format&fit=crop&q=80&w=400';
        await _databaseService.updateUser(_user!.id, {
          'licenseImage': dummyUrl,
          'isVerified': false,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driving License uploaded and is awaiting approval'), backgroundColor: AppColors.primaryOrange),
        );
        _loadProfileData();
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
                                backgroundImage: _user?.profileImage.isNotEmpty == true
                                    ? NetworkImage(_user!.profileImage)
                                    : null,
                                child: _user?.profileImage.isNotEmpty != true
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
                        // Edit profile button with pencil icon
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: _showEditProfileDialog,
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
                                        color: _user != null && _user!.isVerified
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _user != null && _user!.isVerified ? 'VERIFIED' : 'UNVERIFIED',
                                        style: TextStyle(
                                          color: _user != null && _user!.isVerified ? Colors.green : Colors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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

                                        return Card(
                                          color: const Color(0xFFF8F9FA),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 0,
                                          margin: const EdgeInsets.only(bottom: 12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
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
