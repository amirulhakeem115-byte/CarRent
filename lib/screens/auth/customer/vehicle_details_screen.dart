import 'package:flutter/material.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/review_model.dart';
import '../../../models/user_model.dart';
import '../../../models/maintenance_job_model.dart';
import '../../../services/review_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/maintenance_service.dart';
import '../../../constants/colors.dart';
import '../../../widgets/custom_app_bar.dart';
import 'booking_screen.dart';
import 'profile_screen.dart';
import '../../../widgets/app_image.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final VehicleModel vehicle;

  const VehicleDetailsScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  List<ReviewModel> _reviews = [];
  double _avgRating = 0.0;
  bool _loadingReviews = true;
  UserModel? _userModel;
  List<MaintenanceJobModel> _maintenanceJobs = [];
  
  // Selected gallery image index
  int _selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (!mounted) return;
    setState(() => _loadingReviews = true);
    try {
      _reviews = await _reviewService.getVehicleReviews(widget.vehicle.id).timeout(const Duration(seconds: 10));
      _avgRating = await _reviewService.getAverageRating(widget.vehicle.id).timeout(const Duration(seconds: 10));
      
      final jobs = await MaintenanceService().getMaintenanceJobs().timeout(const Duration(seconds: 10));
      _maintenanceJobs = jobs.where((job) => job.vehicleId == widget.vehicle.id && job.showToCustomer).toList();

      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final profile = await _databaseService.getUser(currentUser.uid).timeout(const Duration(seconds: 10));
        if (profile != null) {
          _userModel = profile;
        }
      }
    } catch (e) {
      debugPrint('Error loading vehicle details/reviews/maintenance: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingReviews = false);
      }
    }
  }


  void _handleBookNow() {
    final currentUser = _authService.currentUser;
    final uid = currentUser?.uid;
    final isVerified = _userModel?.isVerified ?? false;
    final licenseNumber = _userModel?.licenseNumber;
    final hasLicenseImage = _userModel?.licenseImage != null && _userModel!.licenseImage.isNotEmpty;
    final approvalStatus = _userModel?.licenseStatus ?? 'unprovided';

    debugPrint('[BookingValidation] User Verification Check:');
    debugPrint('[BookingValidation]   - uid: $uid');
    debugPrint('[BookingValidation]   - isVerified: $isVerified');
    debugPrint('[BookingValidation]   - licenseNumber: $licenseNumber');
    debugPrint('[BookingValidation]   - licenseImage exists: $hasLicenseImage');
    debugPrint('[BookingValidation]   - approvalStatus: $approvalStatus');

    final bool canBook = isVerified || (hasLicenseImage && approvalStatus != 'rejected' && approvalStatus != 'unprovided');

    if (!canBook) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Driving License Required'),
          content: const Text(
            'To rent a vehicle, you must submit your driving license for verification. Would you like to upload it now in your profile?',
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
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                ).then((_) => _loadDetails());
              },
              child: const Text('Go to Profile'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(vehicle: widget.vehicle),
      ),
    ).then((_) => _loadDetails());
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;
    
    // Fallback images if list is empty
    final imagesList = widget.vehicle.gallery.isNotEmpty 
        ? widget.vehicle.gallery 
        : [widget.vehicle.mainImage];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Back button below header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60.0 : 20.0,
                vertical: 20.0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.secondaryBlue, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // Two-column responsive details grid matching Image Reference 5
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60.0 : 20.0),
              child: Flex(
                direction: isDesktop ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // Left Column: Big Image, Gallery, Equipment, Maintenance Table
                  Expanded(
                    flex: isDesktop ? 5 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main large image with Premium tag
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                             child: AppImage(
                                imageSrc: imagesList[_selectedImageIndex],
                                height: 380,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  height: 380,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.car_rental, size: 80, color: Colors.grey),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              top: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC5943B), // Premium Gold in mockup
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'PREMIUM CHOICE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Image Gallery thumbnails
                        SizedBox(
                          height: 70,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: imagesList.length,
                            itemBuilder: (context, index) {
                              final isSelected = index == _selectedImageIndex;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedImageIndex = index),
                                child: Container(
                                  width: 90,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primaryOrange : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: AppImage(
                                      imageSrc: imagesList[index],
                                      fit: BoxFit.cover,
                                      placeholder: Container(
                                        color: Colors.grey[100],
                                        child: const Icon(Icons.directions_car, size: 24, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Description
                        const Text(
                          'Description',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.vehicle.description.isNotEmpty
                              ? widget.vehicle.description
                              : 'No description provided for this vehicle.',
                          style: TextStyle(color: Colors.grey[600], height: 1.5, fontSize: 14),
                        ),
                        const SizedBox(height: 32),

                        // Car Equipment checklist (Image Reference 5)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Car Equipment',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondaryBlue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 20,
                                runSpacing: 12,
                                children: widget.vehicle.equipment.map((item) {
                                  return SizedBox(
                                    width: 130,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Color(0xFF8E6B23), size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          item,
                                          style: const TextStyle(
                                            color: AppColors.secondaryBlue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Maintenance History Table (Image Reference 5)
                        const Text(
                          'Maintenance History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                        ),
                        const SizedBox(height: 12),
                        _maintenanceJobs.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(24),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[200]!),
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.grey[50],
                                ),
                                child: const Center(
                                  child: Text(
                                    'No maintenance history available for this vehicle.',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(1.5),
                                      1: FlexColumnWidth(2.5),
                                      2: FlexColumnWidth(1),
                                      3: FlexColumnWidth(1),
                                    },
                                    children: [
                                      // Table Header matching orange/gold mockup header
                                      TableRow(
                                        decoration: const BoxDecoration(color: AppColors.primaryOrange),
                                        children: [
                                          _buildTableHeaderCell('SERVICE TYPE'),
                                          _buildTableHeaderCell('NOTES / REMARKS'),
                                          _buildTableHeaderCell('DATE'),
                                          _buildTableHeaderCell('STATUS'),
                                        ],
                                      ),
                                      // Table Rows from parsed model maintenance records
                                      ..._maintenanceJobs.map((record) {
                                        return TableRow(
                                          decoration: const BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                          ),
                                          children: [
                                            _buildTableCell(record.serviceType, isSection: true),
                                            _buildTableCell(record.notes.isNotEmpty ? record.notes : 'N/A'),
                                            _buildTableCell(record.date),
                                            _buildTableCell(record.status),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                        const SizedBox(height: 48),

                      ],
                    ),
                  ),
                  if (isDesktop) const SizedBox(width: 32),
                  if (!isDesktop) const SizedBox(height: 32),

                  // Right Column: Spec Attributes Grid & Reservation Card
                  Expanded(
                    flex: isDesktop ? 4 : 0,
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
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
                          // Vehicle Title Name
                          Text(
                            '${widget.vehicle.brand} ${widget.vehicle.model}'.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.secondaryBlue,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Rating and Price
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_avgRating > 0 ? _avgRating.toStringAsFixed(1) : "4.8"}/5',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'RM ${widget.vehicle.pricePerDay.toStringAsFixed(0)}/Months', // matches "Months" typo in image
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Spec Attributes 6-grid matching Image Reference 5
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 2.2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            children: [
                              _buildSpecCard('GEAR BOX', widget.vehicle.transmission, Icons.settings),
                              _buildSpecCard('ENGINE', widget.vehicle.engine, Icons.offline_bolt_outlined),
                              _buildSpecCard('FUEL TYPE', widget.vehicle.fuelType, Icons.local_gas_station_outlined),
                              _buildSpecCard('SEATS', '${widget.vehicle.seats} Seats', Icons.airline_seat_recline_normal),
                              _buildSpecCard('MILEAGE', '${widget.vehicle.mileage} km', Icons.speed),
                              _buildSpecCard('YEAR', '${widget.vehicle.year}', Icons.calendar_today_outlined),
                              _buildSpecCard('AC', widget.vehicle.ac ? 'Yes' : 'No', Icons.ac_unit_outlined),
                              _buildSpecCard('COLOR', widget.vehicle.color, Icons.palette_outlined),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Rental Demand Progress Trend Indicator
                          const Text(
                            'RENTAL DEMAND TREND',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text(
                                'JUN',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondaryBlue),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: widget.vehicle.rentalDemand / 100.0,
                                    minHeight: 10,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E6B23)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Solid Rent Now action button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC5943B), // Matches button color in Image Reference 5
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: widget.vehicle.status == 'available' ? _handleBookNow : null,
                              child: Text(
                                widget.vehicle.status == 'booked'
                                    ? 'Currently Booked'
                                    : widget.vehicle.status == 'maintenance'
                                        ? 'Under Maintenance'
                                        : 'Rent Now',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Review section
            _buildReviewsSection(isDesktop),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isSection = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.secondaryBlue,
          fontSize: 11,
          fontWeight: isSection ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSpecCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3ED), // Light beige background in mockup
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8E6B23), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondaryBlue),
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

  Widget _buildReviewsSection(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 60.0 : 20.0, vertical: 40.0),
      child: Container(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 24),
            const Text(
              'Customer Feedback',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
            ),
            const SizedBox(height: 16),
            _loadingReviews
                ? const Center(child: CircularProgressIndicator())
                : _reviews.isEmpty
                    ? Text(
                        'No reviews yet for this vehicle. Be the first to rent and review!',
                        style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          final rev = _reviews[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[250] ?? const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rev.userName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (i) => Icon(
                                          Icons.star,
                                          size: 14,
                                          color: i < rev.rating ? Colors.amber : Colors.grey[300],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  rev.comment,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
