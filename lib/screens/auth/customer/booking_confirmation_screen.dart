import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../models/booking_model.dart';
import '../../../models/vehicle_model.dart';
import 'customer_responsive_shell.dart';
import '../../../widgets/app_image.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final BookingModel booking;
  final VehicleModel vehicle;
  final String paymentMethod;
  final String paymentStatus;

  const BookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.vehicle,
    this.paymentMethod = 'Online Bank Transfer',
    this.paymentStatus = 'Paid',
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 850;
    final dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

    final int days = booking.rentalDays <= 0 ? 1 : booking.rentalDays;
    final int pointsEarned = (booking.totalPrice / 10).floor();

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.secondaryBlue, size: 20),
          onPressed: () {
            final shell = CustomerResponsiveShell.of(context);
            if (shell != null) {
              shell.setIndex(0);
            }
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Booking Confirmation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.secondaryBlue,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    // SUCCESS HEADER
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2), width: 4),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Booking Successful!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.secondaryBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your vehicle reservation is confirmed and ready.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // DETAILS CARD
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderGray.withValues(alpha: 0.8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          children: [
                            // Main contents
                            Padding(
                              padding: const EdgeInsets.all(28.0),
                              child: Flex(
                                direction: isDesktop ? Axis.horizontal : Axis.vertical,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // LEFT PANEL - Vehicle info
                                  Expanded(
                                    flex: isDesktop ? 5 : 0,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Vehicle Image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: vehicle.mainImage.isNotEmpty
                                              ? AppImage(
                                                  imageSrc: vehicle.mainImage,
                                                  height: 180,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  placeholder: Container(
                                                    height: 180,
                                                    color: AppColors.lightGray,
                                                    child: const Icon(Icons.car_rental, size: 60, color: Colors.grey),
                                                  ),
                                                )
                                              : Container(
                                                  height: 180,
                                                  color: AppColors.lightGray,
                                                  child: const Icon(Icons.car_rental, size: 60, color: Colors.grey),
                                                ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          vehicle.brand,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryOrange,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${vehicle.brand} ${vehicle.model}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.secondaryBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.check, color: Colors.green, size: 14),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Confirmed',
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.lightGray,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: AppColors.borderGray),
                                              ),
                                              child: Text(
                                                vehicle.transmission,
                                                style: const TextStyle(
                                                  color: AppColors.secondaryBlue,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (isDesktop) const SizedBox(width: 40) else const SizedBox(height: 32),

                                  // RIGHT PANEL - Invoice details
                                  Expanded(
                                    flex: isDesktop ? 6 : 0,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'RENTAL DETAILS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.lightText,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInvoiceRow('Booking ID', booking.id, isCode: true),
                                        _buildInvoiceRow('Pickup Location', vehicle.branchName.isNotEmpty ? vehicle.branchName : 'Main Corporate Hub'),
                                        _buildInvoiceRow('Pickup Date & Time', dateTimeFormat.format(booking.pickUpDate)),
                                        _buildInvoiceRow('Return Date & Time', dateTimeFormat.format(booking.returnDate)),
                                        _buildInvoiceRow('Rental Duration', '$days Day${days == 1 ? "" : "s"}'),
                                        _buildInvoiceRow('Payment Method', paymentMethod),
                                        _buildInvoiceRow('Payment Status', paymentStatus, highlightValue: true),
                                        const Divider(height: 24),
                                        _buildInvoiceRow(
                                          'Total Amount Paid',
                                          'RM ${booking.totalPrice.toStringAsFixed(2)}',
                                          isPrice: true,
                                        ),
                                        _buildInvoiceRow(
                                          'Loyalty Points Earned',
                                          '+$pointsEarned Points',
                                          isPoints: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ACTIONS CARD
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderGray.withValues(alpha: 0.8)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'What would you like to do next?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondaryBlue,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Flex(
                            direction: isDesktop ? Axis.horizontal : Axis.vertical,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryOrange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  final shell = CustomerResponsiveShell.of(context);
                                  if (shell != null) {
                                    shell.setIndex(2); // Switches to My Bookings tab
                                  }
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                                label: const Text('View My Booking', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (isDesktop) const SizedBox(width: 16) else const SizedBox(height: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.secondaryBlue,
                                  side: const BorderSide(color: AppColors.borderGray, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                ),
                                onPressed: () {
                                  final shell = CustomerResponsiveShell.of(context);
                                  if (shell != null) {
                                    shell.setIndex(1); // Switches to Search Cars tab
                                  }
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.directions_car_rounded, size: 18),
                                label: const Text('Browse More Cars', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (isDesktop) const SizedBox(width: 16) else const SizedBox(height: 12),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.lightText,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                onPressed: () {
                                  final shell = CustomerResponsiveShell.of(context);
                                  if (shell != null) {
                                    shell.setIndex(0); // Switches to Dashboard
                                  }
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.dashboard_rounded, size: 18),
                                label: const Text('Return to Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(
    String label,
    String value, {
    bool isCode = false,
    bool isPrice = false,
    bool isPoints = false,
    bool highlightValue = false,
  }) {
    TextStyle valueStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.secondaryBlue,
      fontSize: 13,
    );

    if (isCode) {
      valueStyle = TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        color: AppColors.secondaryBlue.withValues(alpha: 0.8),
        fontSize: 12,
      );
    } else if (isPrice) {
      valueStyle = const TextStyle(
        fontWeight: FontWeight.w900,
        color: AppColors.primaryOrange,
        fontSize: 18,
      );
    } else if (isPoints) {
      valueStyle = const TextStyle(
        fontWeight: FontWeight.w900,
        color: Colors.green,
        fontSize: 14,
      );
    } else if (highlightValue) {
      valueStyle = const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.green,
        fontSize: 13,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.lightText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: valueStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
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
