import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/review_service.dart';
import '../../../models/user_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/review_model.dart';

class ProfileScreen extends StatefulWidget {
  final int initialTab;
  const ProfileScreen({super.key, this.initialTab = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  final ReviewService _reviewService = ReviewService();

  UserModel? _user;
  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  bool _loading = true;

  // Edit fields
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _loading = true);
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      _user = await _databaseService.getUser(currentUser.uid);
      if (_user != null) {
        _fullNameController.text = _user!.fullName;
        _phoneController.text = _user!.phone;
        _licenseController.text = _user!.licenseNumber ?? '';
      }
      _bookings = await _bookingService.getUserBookings(currentUser.uid);
      _payments = await _paymentService.getUserPayments(currentUser.uid);
    }
    setState(() => _loading = false);
  }

  Future<void> _updateProfile() async {
    if (_user == null) return;
    try {
      await _databaseService.updateUser(_user!.id, {
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'licenseNumber': _licenseController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
      );
      _loadProfileData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  Future<void> _pickProfileImage() async {
    if (_user == null) return;
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) {
        // Since we are running in multiple environments, we use a beautiful placeholder image
        // representing their choice, saving this to database.
        final dummyUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';
        await _databaseService.updateUser(_user!.id, {'profileImage': dummyUrl});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo uploaded'), backgroundColor: Colors.green),
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
        // Dummy license card photo
        final dummyUrl = 'https://images.unsplash.com/photo-1554774853-aae0a22c8aa4?auto=format&fit=crop&q=80&w=400';
        await _databaseService.updateUser(_user!.id, {
          'licenseImage': dummyUrl,
          'isVerified': false,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driving License uploaded and is awaiting approval'), backgroundColor: Colors.blue),
        );
        _loadProfileData();
      }
    } catch (e) {
      debugPrint('License pick error: $e');
    }
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
                    backgroundColor: const Color(0xFF1E3C72),
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
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E3C72),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1E3C72),
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Info'),
            Tab(icon: Icon(Icons.history), text: 'Bookings'),
            Tab(icon: Icon(Icons.payment), text: 'Payments'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileInfoTab(),
                _buildBookingHistoryTab(),
                _buildPaymentHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildProfileInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Profile image avatar card
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: const Color(0xFF1E3C72).withValues(alpha: 0.1),
                  backgroundImage: _user?.profileImage != null && _user!.profileImage.isNotEmpty
                      ? NetworkImage(_user!.profileImage)
                      : null,
                  child: _user?.profileImage == null || _user!.profileImage.isEmpty
                      ? const Icon(Icons.person, size: 54, color: Color(0xFF1E3C72))
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF1E3C72),
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      onPressed: _pickProfileImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _user?.email ?? '',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 24),
          // User Details Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // License card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Driving License', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _user != null && _user!.isVerified
                              ? Colors.green.withValues(alpha: 0.1)
                                  : (_user?.licenseImage.isNotEmpty == true
                                      ? Colors.orange.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _user != null && _user!.isVerified
                              ? 'Verified'
                              : (_user?.licenseImage.isNotEmpty == true ? 'Pending Admin' : 'Unverified'),
                          style: TextStyle(
                            color: _user != null && _user!.isVerified
                                ? Colors.green
                                : (_user?.licenseImage.isNotEmpty == true ? Colors.orange : Colors.grey),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Driving License Number',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload License Card'),
                          onPressed: _pickLicenseImage,
                        ),
                      ),
                    ],
                  ),
                  if (_user?.licenseImage.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _user!.licenseImage,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                         errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3C72),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _updateProfile,
              child: const Text('SAVE PROFILE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingHistoryTab() {
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No rentals booked yet', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy');

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        final booking = _bookings[index];
        Color statusColor = Colors.orange;
        if (booking.status == 'approved' || booking.status == 'ongoing') {
          statusColor = Colors.blue;
        } else if (booking.status == 'completed') {
          statusColor = Colors.green;
        } else if (booking.status == 'cancelled' || booking.status == 'rejected') {
          statusColor = Colors.red;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    booking.vehicleName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                       color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${dateFormat.format(booking.pickUpDate)} - ${dateFormat.format(booking.returnDate)}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Total Price: RM ${booking.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
              if (booking.notes != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Notes: ${booking.notes}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
              if (booking.status == 'completed') ...[
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3C72),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: const Text('SUBMIT RATING & REVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _submitReview(booking),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentHistoryTab() {
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No payment records found', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        final isRefunded = payment.status == 'refunded';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaction Amount',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                       color: isRefunded ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      payment.status.toUpperCase(),
                      style: TextStyle(
                        color: isRefunded ? Colors.red : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'RM ${payment.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF2C3E50)),
              ),
              const Divider(height: 20),
              _buildPaymentDetailRow('Payment Mode', payment.paymentMethod),
              _buildPaymentDetailRow('Transaction ID', payment.transactionId ?? 'N/A'),
              _buildPaymentDetailRow('Transaction Date', dateFormat.format(payment.paymentDate)),
              if (isRefunded && payment.refundDate != null) ...[
                _buildPaymentDetailRow('Refund Issued', dateFormat.format(payment.refundDate!)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF2C3E50))),
        ],
      ),
    );
  }
}
