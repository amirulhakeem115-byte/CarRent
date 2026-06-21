import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../models/booking_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../widgets/custom_app_bar.dart';
import 'home_screen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final BookingModel booking;
  final VehicleModel vehicle;

  const BookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 750;
    final dateFormat = DateFormat('dd MMM yyyy');

    final rentalDays = booking.returnDate.difference(booking.pickUpDate).inDays;
    final days = rentalDays <= 0 ? 1 : rentalDays;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Back Arrow
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 60.0 : 20.0,
                vertical: 20.0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.secondaryBlue, size: 28),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
                      (route) => false,
                    );
                  },
                ),
              ),
            ),

            // Success Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Booking Confirmed!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your ride is ready for pick-up.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Vehicle Image Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: vehicle.mainImage.isNotEmpty
                      ? Image.network(
                          vehicle.mainImage,
                          height: isDesktop ? 400 : 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 250,
                            color: Colors.grey[100],
                            child: const Icon(Icons.car_rental, size: 80, color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: 250,
                          color: Colors.grey[100],
                          child: const Icon(Icons.car_rental, size: 80, color: Colors.grey),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Booking Summary Details Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Booking Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.secondaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Flex(
                      direction: isDesktop ? Axis.horizontal : Axis.vertical,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rental Period',
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${dateFormat.format(booking.pickUpDate)} - ${dateFormat.format(booking.returnDate)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Pickup / Drop-off',
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vehicle.branchName.isNotEmpty ? vehicle.branchName : 'General Hub Branch',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, fontSize: 13),
                            ),
                          ],
                        ),
                        if (!isDesktop) const SizedBox(height: 20),
                        // Right Column
                        Column(
                          crossAxisAlignment: isDesktop ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Breakdown',
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Daily Rate (RM${vehicle.pricePerDay.toStringAsFixed(0)} x $days)',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Total Amount Paid',
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RM ${booking.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.primaryOrange,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Return to Home Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: 250,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondaryBlue,
                    side: const BorderSide(color: AppColors.secondaryBlue, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Return to Home',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),

            // Footer
            _buildFooter(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      color: const Color(0xFFFFFBEB),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60.0 : 20.0,
        vertical: 40.0,
      ),
      child: Column(
        children: [
          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  const Text(
                    'CARRENT PLATFORM',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondaryBlue,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2026 CARRENT PLATFORM. ALL RIGHTS RESERVED.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
              if (!isDesktop) const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFooterLink('Privacy Policy'),
                  const SizedBox(width: 16),
                  _buildFooterLink('Terms of Service'),
                  const SizedBox(width: 16),
                  _buildFooterLink('Fleet Management'),
                  const SizedBox(width: 16),
                  _buildFooterLink('Contact Us'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return InkWell(
      onTap: () {},
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
