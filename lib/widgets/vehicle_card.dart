import 'package:flutter/material.dart';
import '../models/vehicle_model.dart';
import '../constants/colors.dart';
import '../screens/auth/customer/vehicle_details_screen.dart';

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
        onTap: onTap ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                ),
              );
            },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Image with Availability Chip
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: vehicle.mainImage.isNotEmpty
                      ? Image.network(
                          vehicle.mainImage,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 160,
                            color: AppColors.lightGray,
                            child: const Icon(
                              Icons.directions_car_filled_rounded,
                              size: 48,
                              color: AppColors.lightText,
                            ),
                          ),
                        )
                      : Container(
                          height: 160,
                          color: AppColors.lightGray,
                          child: const Icon(
                            Icons.directions_car_filled_rounded,
                            size: 48,
                            color: AppColors.lightText,
                          ),
                        ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: vehicle.isAvailable
                          ? const Color(0xFF2ECC71).withValues(alpha: 0.9)
                          : const Color(0xFFE74C3C).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      vehicle.isAvailable ? 'AVAILABLE' : 'RENTED',
                      style: const TextStyle(
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
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                            ),
                          );
                        },
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
