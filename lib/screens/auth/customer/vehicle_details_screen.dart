import 'package:flutter/material.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/review_model.dart';
import '../../../services/review_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import 'booking_screen.dart';
import 'profile_screen.dart';

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
  bool _isUserVerified = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _loadingReviews = true);
    _reviews = await _reviewService.getVehicleReviews(widget.vehicle.id);
    _avgRating = await _reviewService.getAverageRating(widget.vehicle.id);
    
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      final profile = await _databaseService.getUser(currentUser.uid);
      if (profile != null) {
        _isUserVerified = profile.isVerified;
      }
    }
    setState(() => _loadingReviews = false);
  }

  void _handleBookNow() {
    if (!_isUserVerified) {
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
                backgroundColor: const Color(0xFF1E3C72),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image & Back Button Hero Section
            Stack(
              children: [
                Hero(
                  tag: 'vehicle_image_${widget.vehicle.id}',
                  child: widget.vehicle.mainImage.isNotEmpty
                      ? Image.network(
                          widget.vehicle.mainImage,
                          height: 280,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 280,
                            color: Colors.grey[200],
                            child: const Icon(Icons.car_rental, size: 80, color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: 280,
                          color: Colors.grey[200],
                          child: const Icon(Icons.car_rental, size: 80, color: Colors.grey),
                        ),
                ),
                Positioned(
                  left: 20,
                  top: 50,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand & Model title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.vehicle.brand.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.vehicle.model,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'RM ${widget.vehicle.pricePerDay.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3C72),
                            ),
                          ),
                          Text(
                            'per day',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Star Rating Summary
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        _avgRating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${_reviews.length} reviews)',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.vehicle.isAvailable
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.vehicle.isAvailable ? 'Available' : 'Currently Booked',
                          style: TextStyle(
                            color: widget.vehicle.isAvailable ? Colors.green : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Specifications Row
                  const Text(
                    'Specifications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSpecItem(Icons.airline_seat_recline_normal, '${widget.vehicle.seats} Seats'),
                      _buildSpecItem(Icons.settings, widget.vehicle.transmission),
                      _buildSpecItem(Icons.local_gas_station_outlined, widget.vehicle.fuelType),
                      _buildSpecItem(Icons.palette_outlined, widget.vehicle.color),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Branch card
                  const Text(
                    'Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.grey[50],
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF1E3C72),
                            child: Icon(Icons.location_on, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.vehicle.branchName.isNotEmpty
                                      ? widget.vehicle.branchName
                                      : 'General Hub',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pick-up and drop-off at this branch point.',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.vehicle.description.isNotEmpty
                        ? widget.vehicle.description
                        : 'No description provided for this vehicle. Contact agent for further specification.',
                    style: TextStyle(color: Colors.grey[600], height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  // Reviews Section
                  const Text(
                    'Customer Feedback',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 12),
                  _loadingReviews
                      ? const Center(child: CircularProgressIndicator())
                      : _reviews.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No reviews yet for this vehicle. Be the first to rent and review!',
                                style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                              ),
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
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(16),
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
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3C72),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: widget.vehicle.isAvailable ? _handleBookNow : null,
            child: Text(
              widget.vehicle.isAvailable ? 'RENT NOW' : 'NOT AVAILABLE',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String text) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1E3C72), size: 24),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          ),
        ],
      ),
    );
  }
}
