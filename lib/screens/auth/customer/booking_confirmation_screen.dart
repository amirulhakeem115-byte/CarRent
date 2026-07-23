import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../models/booking_model.dart';
import '../../../models/vehicle_model.dart';
import 'customer_responsive_shell.dart';
import '../../../widgets/app_image.dart';
import '../../../services/receipt_service.dart';
import '../../../services/company_settings_provider.dart';
import '../../../widgets/app_logo.dart';

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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

    final int days = booking.rentalDays <= 0 ? 1 : booking.rentalDays;
    final int pointsEarned = (booking.totalPrice / 10).floor();

    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey[600]!;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderTheme = isDark
        ? const Color(0xFF334155)
        : AppColors.borderGray.withValues(alpha: 0.8);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1B2436) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrimary,
            size: 20,
          ),
          onPressed: () {
            final shell = CustomerResponsiveShell.of(context);
            if (shell != null) {
              shell.setIndex(0);
            }
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Booking Confirmation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  children: [
                    // SUCCESS HEADER WITH MICRO-ANIMATED CHECK
                    const AnimatedCheckIcon(),
                    const SizedBox(height: 16),
                    Text(
                      'Booking Successful!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your vehicle reservation is confirmed and ready. Check the History page to monitor your ongoing car status.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // DETAILS CARD
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderTheme),
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
                              child: () {
                                final leftPanel = Column(
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
                                                color: isDark
                                                    ? const Color(0xFF0F172A)
                                                    : AppColors.lightGray,
                                                child: const Icon(
                                                  Icons.car_rental,
                                                  size: 60,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              height: 180,
                                              width: double.infinity,
                                              color: isDark
                                                  ? const Color(0xFF0F172A)
                                                  : AppColors.lightGray,
                                              child: const Icon(
                                                Icons.directions_car,
                                                size: 80,
                                                color: Colors.grey,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      '${vehicle.brand} ${vehicle.model}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.tag_rounded,
                                          size: 14,
                                          color: AppColors.primaryOrange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          vehicle.plateNumber.toUpperCase(),
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        const Icon(
                                          Icons.color_lens_outlined,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          vehicle.color,
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(color: Colors.white10),
                                    const SizedBox(height: 16),
                                    _infoBlock(
                                      Icons.my_location,
                                      'Pick Up & Return Hub',
                                      vehicle.branchName.isNotEmpty
                                          ? vehicle.branchName
                                          : 'HQ Central Branch',
                                      isDark,
                                    ),
                                  ],
                                );

                                final rightPanel = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RESERVATION DETAILS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _detailRow(
                                      'Booking Reference',
                                      booking.id.toUpperCase(),
                                      isDark,
                                      isCode: true,
                                    ),
                                    _detailRow(
                                      'Status',
                                      booking.status,
                                      isDark,
                                      highlightValue: true,
                                    ),
                                    _detailRow(
                                      'Check-in Date',
                                      dateTimeFormat.format(booking.pickUpDate),
                                      isDark,
                                    ),
                                    _detailRow(
                                      'Check-out Date',
                                      booking.isOpenRental
                                          ? 'Open Rental'
                                          : (booking.returnDate != null
                                                ? dateTimeFormat.format(
                                                    booking.returnDate!,
                                                  )
                                                : ""),
                                      isDark,
                                    ),
                                    _detailRow(
                                      'Rental Duration',
                                      '$days Day${days == 1 ? '' : 's'}',
                                      isDark,
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(color: Colors.white10),
                                    const SizedBox(height: 16),
                                    Text(
                                      'PAYMENT SUMMARY',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _detailRow(
                                      'Payment Method',
                                      paymentMethod,
                                      isDark,
                                    ),
                                    if (booking.promotionDiscountAmount > 0)
                                      _detailRow(
                                        'Promotion (${booking.promotionCode ?? booking.promotionName ?? "Applied"})',
                                        '- RM ${booking.promotionDiscountAmount.toStringAsFixed(2)}',
                                        isDark,
                                        highlightValue: true,
                                      ),
                                    _detailRow(
                                      'Points Redeemed',
                                      '${booking.pointsRedeemed} Points',
                                      isDark,
                                      isPoints: booking.pointsRedeemed > 0,
                                    ),
                                    _detailRow(
                                      'Total Rent Price',
                                      'RM ${booking.totalPrice.toStringAsFixed(2)}',
                                      isDark,
                                      isPrice: true,
                                    ),
                                    if (booking.depositAmount > 0)
                                      _detailRow(
                                        'Deposit Paid',
                                        'RM ${booking.depositAmount.toStringAsFixed(2)}',
                                        isDark,
                                        highlightValue: true,
                                      ),
                                  ],
                                );

                                return Flex(
                                  direction: isDesktop
                                      ? Axis.horizontal
                                      : Axis.vertical,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    isDesktop
                                        ? Expanded(flex: 5, child: leftPanel)
                                        : leftPanel,
                                    if (isDesktop) ...[
                                      const SizedBox(width: 40),
                                      Container(
                                        width: 1,
                                        height: 320,
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : AppColors.borderGray,
                                      ),
                                      const SizedBox(width: 40),
                                    ] else ...[
                                      const SizedBox(height: 24),
                                      const Divider(),
                                      const SizedBox(height: 24),
                                    ],
                                    isDesktop
                                        ? Expanded(flex: 6, child: rightPanel)
                                        : rightPanel,
                                  ],
                                );
                              }(),
                            ),
                            // Action Panel at bottom of details card
                            Container(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : AppColors.lightGray.withValues(alpha: 0.5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 20,
                              ),
                              child: () {
                                final textWidget = RichText(
                                  textAlign: isDesktop
                                      ? TextAlign.start
                                      : TextAlign.center,
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFFCBD5E1)
                                          : AppColors.secondaryBlue,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'Congratulations! You earned ',
                                      ),
                                      TextSpan(
                                        text: '$pointsEarned loyalty points',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const TextSpan(
                                        text:
                                            ' from this reservation transaction.',
                                      ),
                                    ],
                                  ),
                                );

                                return Flex(
                                  direction: isDesktop
                                      ? Axis.horizontal
                                      : Axis.vertical,
                                  children: [
                                    const Icon(
                                      Icons.stars_rounded,
                                      color: Colors.amber,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12, height: 8),
                                    isDesktop
                                        ? Expanded(child: textWidget)
                                        : textWidget,
                                    if (!isDesktop) const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: AppColors.primaryOrange,
                                        ),
                                        foregroundColor:
                                            AppColors.primaryOrange,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: () {
                                        ReceiptService().viewReceipt(
                                          context,
                                          booking.id,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.receipt_long_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Digital Invoice',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ACTION BUTTONS
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final shell = CustomerResponsiveShell.of(context);
                            if (shell != null) {
                              shell.setIndex(0);
                            }
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.home_outlined),
                          label: const Text(
                            'Return Home',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: textPrimary),
                            foregroundColor: textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final shell = CustomerResponsiveShell.of(context);
                            if (shell != null) {
                              shell.setIndex(2); // Index of "My Bookings"
                            }
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text(
                            'My Bookings',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(isDesktop, isDark),
          ],
        ),
      ),
    );
  }

  Widget _infoBlock(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryOrange, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFFF8FAFC)
                      : AppColors.secondaryBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    String label,
    String value,
    bool isDark, {
    bool isCode = false,
    bool isPrice = false,
    bool isPoints = false,
    bool highlightValue = false,
  }) {
    TextStyle valueStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue,
      fontSize: 13,
    );

    if (isCode) {
      valueStyle = TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        color: isDark
            ? const Color(0xFFCBD5E1)
            : AppColors.secondaryBlue.withValues(alpha: 0.8),
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
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.lightText,
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

  Widget _buildFooter(bool isDesktop, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
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
                crossAxisAlignment: isDesktop
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLogo(
                        size: 16,
                        fallbackColor: isDark
                            ? const Color(0xFFF8FAFC)
                            : AppColors.secondaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CompanySettingsProvider().companyName.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? const Color(0xFFF8FAFC)
                              : AppColors.secondaryBlue,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2026 ${CompanySettingsProvider().companyName.toUpperCase()}. ALL RIGHTS RESERVED.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
              if (!isDesktop) const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildFooterLink('Privacy Policy'),
                  _buildFooterLink('Terms of Service'),
                  _buildFooterLink('Fleet Management'),
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

class AnimatedCheckIcon extends StatefulWidget {
  const AnimatedCheckIcon({super.key});

  @override
  State<AnimatedCheckIcon> createState() => _AnimatedCheckIconState();
}

class _AnimatedCheckIconState extends State<AnimatedCheckIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.2),
            width: 4,
          ),
        ),
        child: const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 48,
        ),
      ),
    );
  }
}
