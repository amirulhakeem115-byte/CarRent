import 'package:flutter/material.dart';
import '../models/vehicle_model.dart';
import '../constants/colors.dart';
import '../screens/auth/customer/vehicle_details_screen.dart';
import 'app_image.dart';

/// A card widget to display vehicle details such as brand, model, price, transmission,
/// fuel type, seats, and availability status.
class VehicleCard extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback? onTap;

  const VehicleCard({
    super.key,
    required this.vehicle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderGray),
      ),
      child: InkWell(
        onTap: vehicle.status == 'available'
            ? (onTap ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                    ),
                  );
                })
            : null,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Image with Availability Chip
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: AppImage(
                    imageSrc: vehicle.mainImage,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      height: 160,
                      color: AppColors.lightGray,
                      child: const Icon(
                        Icons.directions_car_filled_rounded,
                        size: 48,
                        color: AppColors.lightText,
                      ),
                    ),
                  ),
                ),
                
                // Status Overlay Over Vehicle Image
                if (vehicle.status == 'available')
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71), // Green Badge
                        borderRadius: BorderRadius.circular(30),
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
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (vehicle.status == 'booked') ...[
                  // Dark overlay
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (vehicle.status == 'maintenance') ...[
                  // Dark overlay
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                              Icon(Icons.build, color: Color(0xFFE67E22), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'MAINTENANCE',
                                style: TextStyle(
                                  color: Color(0xFFE67E22),
                                  fontSize: 14,
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
            // Details Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.brand} ${vehicle.model}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: AppColors.primaryOrange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vehicle.branchName.isNotEmpty ? vehicle.branchName : 'Unknown Location',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.lightText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Specifications Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSpecItem(Icons.airline_seat_recline_normal, '${vehicle.seats} Seats'),
                      _buildSpecItem(Icons.settings, vehicle.transmission),
                      _buildSpecItem(Icons.local_gas_station, vehicle.fuelType),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderGray, height: 1),
                  const SizedBox(height: 12),
                  // Price and Action Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PRICE PER DAY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.lightText,
                            ),
                          ),
                          Text(
                            'RM ${vehicle.pricePerDay.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.secondaryBlue,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: vehicle.status == 'available' ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                            ),
                          );
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          elevation: 0,
                        ),
                        child: const Text(
                          'DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
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

  Widget _buildSpecItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.lightText),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.lightText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
