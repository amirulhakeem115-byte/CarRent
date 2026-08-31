import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../l10n/app_translations.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../services/payment_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/booking_hold_service.dart';
import '../../../widgets/app_image.dart';
import '../../../constants/colors.dart';

class MakePaymentScreen extends StatefulWidget {
  final BookingModel booking;
  final List<PaymentModel> existingPayments;

  const MakePaymentScreen({
    super.key,
    required this.booking,
    this.existingPayments = const [],
  });

  @override
  State<MakePaymentScreen> createState() => _MakePaymentScreenState();
}

class _MakePaymentScreenState extends State<MakePaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _amountController = TextEditingController();

  // Step 1: Purpose ("rental" vs "delivery")
  String _selectedPurpose = 'rental';

  // Step 2: Payment Method
  String _selectedPaymentMethod = 'DuitNow QR';

  // Admin Payment Settings
  String? _bankName;
  String? _accountName;
  String? _accountNumber;
  String? _qrCodeUrl;
  String? _bankLogoUrl;
  StreamSubscription<Map<String, dynamic>>? _qrSettingsSub;

  // Receipt image data
  String? _receiptBase64;
  String? _receiptFileName;
  bool _isSubmitting = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor => _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;
  Color get _cardBg => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _borderColor => _isDark ? const Color(0xFF334155) : AppColors.borderGray;

  @override
  void initState() {
    super.initState();
    _recalculateDefaultAmount();
    _amountController.addListener(_onAmountChanged);
    _loadPaymentSettings();
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  void _loadPaymentSettings() {
    // 1. Initial snapshot fetch
    _databaseService.getQrPaymentSettings().then((settings) {
      if (settings != null && mounted) {
        _applySettings(settings);
      }
    }).catchError((e) {
      debugPrint('Error fetching initial QR settings: $e');
    });

    // 2. Real-time stream subscription
    _qrSettingsSub = _databaseService.getQrPaymentSettingsStream().listen((settings) {
      if (mounted && settings.isNotEmpty) {
        _applySettings(settings);
      }
    });
  }

  void _applySettings(Map<String, dynamic> settings) {
    setState(() {
      _bankName = settings['bankName']?.toString();
      _accountName = settings['accountName']?.toString();
      _accountNumber = settings['accountNumber']?.toString();
      _qrCodeUrl = settings['qrCodeBase64']?.toString() ??
          settings['qrCodeUrl']?.toString() ??
          settings['qrCode']?.toString();
      _bankLogoUrl = settings['bankLogoUrl']?.toString();
    });
  }

  String _getVal(String? val, String fallback) {
    if (val == null || val.trim().isEmpty) return fallback;
    return val.trim();
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _qrSettingsSub?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  // Calculate approved payments per purpose
  double get _approvedRentalPaid {
    final approvedList = widget.existingPayments.where((p) {
      if (p.bookingId != widget.booking.id) return false;
      final purpose = p.paymentPurpose.toLowerCase();
      if (purpose != 'rental') return false;
      final s = p.status.toLowerCase();
      final ps = (p.paymentStatus ?? '').toLowerCase();
      return s == 'approved' || s == 'paid' || ps == 'approved' || ps == 'paid';
    }).toList();

    double sum = approvedList.fold(0.0, (acc, p) => acc + p.amount);
    final bStat = widget.booking.status.toLowerCase();
    if (approvedList.isEmpty &&
        (bStat == 'approved' ||
            bStat == 'confirmed' ||
            bStat == 'active' ||
            bStat == 'ongoing' ||
            bStat == 'completed')) {
      sum = widget.booking.depositAmount;
    }
    return sum;
  }

  double get _approvedDeliveryPaid {
    final approvedList = widget.existingPayments.where((p) {
      if (p.bookingId != widget.booking.id) return false;
      final purpose = p.paymentPurpose.toLowerCase();
      if (purpose != 'delivery') return false;
      final s = p.status.toLowerCase();
      final ps = (p.paymentStatus ?? '').toLowerCase();
      return s == 'approved' || s == 'paid' || ps == 'approved' || ps == 'paid';
    }).toList();

    return approvedList.fold(0.0, (acc, p) => acc + p.amount);
  }

  int _getElapsedDays(BookingModel booking) {
    final pickup = booking.actualPickupTimestamp ?? booking.pickUpDate;
    final diff = DateTime.now().difference(pickup);
    final days = (diff.inHours / 24.0).ceil();
    return days <= 0 ? 1 : days;
  }

  bool _isOngoing(BookingModel booking) {
    final s = booking.status.toLowerCase();
    return s == 'active' ||
        s == 'ongoing' ||
        s == 'approved' ||
        s == 'confirmed' ||
        s == 'overdue' ||
        s == 'return requested' ||
        s == 'awaiting return inspection' ||
        s == 'awaiting final payment';
  }

  double get _totalRentalAmount {
    if (widget.booking.status == 'Awaiting Final Payment' && widget.booking.finalAmount > 0) {
      return widget.booking.finalAmount;
    }
    if (widget.booking.isOpenRental && _isOngoing(widget.booking)) {
      final days = _getElapsedDays(widget.booking);
      return days * widget.booking.totalPrice;
    }
    return widget.booking.totalPrice;
  }

  double get _rentalDiscount {
    return widget.booking.discountAmount + widget.booking.promotionDiscountAmount;
  }

  double get _remainingRentalBalance {
    final rem = _totalRentalAmount - _approvedRentalPaid - _rentalDiscount;
    return rem < 0 ? 0.0 : rem;
  }

  double get _deliveryFee {
    return widget.booking.deliveryFee;
  }

  double get _remainingDeliveryBalance {
    final rem = _deliveryFee - _approvedDeliveryPaid;
    return rem < 0 ? 0.0 : rem;
  }

  double get _selectedRemainingBalance {
    return _selectedPurpose == 'rental'
        ? _remainingRentalBalance
        : _remainingDeliveryBalance;
  }

  void _recalculateDefaultAmount() {
    final rem = _selectedRemainingBalance;
    _amountController.text = rem.toStringAsFixed(2);
  }

  Future<void> _pickReceipt() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final lowerName = image.name.toLowerCase();
        String mime = 'image/jpeg';
        if (lowerName.endsWith('.png')) mime = 'image/png';
        if (lowerName.endsWith('.webp')) mime = 'image/webp';
        if (lowerName.endsWith('.pdf')) mime = 'application/pdf';

        setState(() {
          _receiptBase64 = 'data:$mime;base64,${base64Encode(bytes)}';
          _receiptFileName = image.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting receipt: $e')),
      );
    }
  }

  Future<void> _submitPayment() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid payment amount greater than RM 0.00'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final maxRemaining = _selectedRemainingBalance;
    if (amount > maxRemaining + 0.01 && maxRemaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount cannot exceed the remaining balance of RM ${maxRemaining.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_receiptBase64 == null || _receiptBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt upload is required before submitting.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    final holdStatus =
        await BookingHoldService().checkVehicleHold(widget.booking.vehicleId);
    if (holdStatus['isHoldActive'] == true) {
      final String msg = holdStatus['message'] ??
          BookingHoldService.defaultBlockedMessage;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final payment = PaymentModel(
        id: '',
        bookingId: widget.booking.id,
        userId: currentUser.uid,
        amount: amount,
        depositAmount: 0.0,
        balanceAmount: maxRemaining - amount < 0 ? 0.0 : maxRemaining - amount,
        paymentMethod: _selectedPaymentMethod,
        status: 'Pending Verification',
        paymentStatus: 'Pending Verification',
        paymentDate: now,
        receiptImage: _receiptBase64,
        receiptFile: _receiptBase64,
        paymentPurpose: _selectedPurpose,
        uploadedAt: now.toIso8601String(),
      );

      await _paymentService.createPayment(payment);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Payment Submitted', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Payment submitted successfully. Your payment is waiting for admin verification.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context, true); // Return to MyBookingsScreen
              },
              child: const Text('Back to My Bookings'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit payment: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 850;

    final String displayBookingId =
        'BK-${widget.booking.id.substring(0, widget.booking.id.length > 8 ? 8 : widget.booking.id.length).toUpperCase()}';
    final double amountToPay = (_amountController.text.isEmpty
        ? _selectedRemainingBalance
        : (double.tryParse(_amountController.text) ?? _selectedRemainingBalance));
    final String refNo = 'CR${widget.booking.id.toUpperCase()}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payment'.tr(context),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP HEADER SUMMARY BAR
                _buildTopHeaderCard(displayBookingId),
                const SizedBox(height: 24),

                // 2. PAYMENT PURPOSE & AMOUNT SELECTION CARD
                _buildPaymentPurposeAndAmountSection(isDesktop),
                const SizedBox(height: 24),

                // 3. SECTION 1: SELECT PAYMENT METHOD
                _buildPaymentMethodSection(isDesktop),
                const SizedBox(height: 24),

                // 3. SECTION 2: PAYMENT DETAILS (QR / BANK / FPX BOX)
                _buildPaymentDetailsSection(
                    displayBookingId, refNo, amountToPay, isDesktop),
                const SizedBox(height: 24),

                // 4. SECTION 3: UPLOAD RECEIPT (REQUIRED)
                _buildUploadReceiptSection(isDesktop),
                const SizedBox(height: 24),

                // 5. SECTION 4: ACTION BUTTON
                _buildSubmitButton(),
                const SizedBox(height: 20),

                // 6. SECTION 5: FOOTER SECURITY NOTICE
                _buildFooterSecurityBanner(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderCard(String displayBookingId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 600;
          final titleWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment'.tr(context),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Complete your payment to confirm your booking.'.tr(context),
                style: TextStyle(fontSize: 13, color: _subColor),
              ),
            ],
          );

          final summaryBoxWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Booking ID'.tr(context),
                        style: TextStyle(fontSize: 10, color: _subColor)),
                    const SizedBox(height: 2),
                    Text(
                      displayBookingId,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _textColor),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount Due'.tr(context),
                        style: TextStyle(fontSize: 10, color: _subColor)),
                    const SizedBox(height: 2),
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        'RM ${_selectedRemainingBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primaryOrange),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status'.tr(context),
                        style: TextStyle(fontSize: 10, color: _subColor)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Pending Payment'.tr(context),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (isSmall) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                const SizedBox(height: 16),
                summaryBoxWidget,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              titleWidget,
              summaryBoxWidget,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentPurposeAndAmountSection(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Purpose & Amount'.tr(context),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select what you are paying for and enter amount:'.tr(context),
            style: TextStyle(fontSize: 12, color: _subColor),
          ),
          const SizedBox(height: 16),

          // Purpose Selector (Rental vs Delivery)
          Row(
            children: [
              Expanded(
                child: _buildPurposeCard(
                  id: 'rental',
                  title: 'Rental Payment'.tr(context),
                  subtitle: 'Payment for vehicle rental'.tr(context),
                  remainingText: 'RM ${_remainingRentalBalance.toStringAsFixed(2)}',
                  icon: Icons.directions_car_filled_rounded,
                  badgeColor: Colors.teal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPurposeCard(
                  id: 'delivery',
                  title: 'Delivery Fee'.tr(context),
                  subtitle: 'Payment for vehicle delivery'.tr(context),
                  remainingText: 'RM ${_remainingDeliveryBalance.toStringAsFixed(2)}',
                  icon: Icons.local_shipping_outlined,
                  badgeColor: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Amount Input Box with "Pay Full Amount" button
          Text(
            'Payment Amount (RM)'.tr(context),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                const Text(
                  'RM ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
                Expanded(
                  child: Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0.00',
                      ),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onPressed: _recalculateDefaultAmount,
                  icon: const Icon(Icons.account_balance_wallet_outlined,
                      size: 16),
                  label: Text(
                    'Pay Full Amount'.tr(context),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeCard({
    required String id,
    required String title,
    required String subtitle,
    required String remainingText,
    required IconData icon,
    required Color badgeColor,
  }) {
    final isSelected = _selectedPurpose == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPurpose = id;
          _recalculateDefaultAmount();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOrange.withValues(alpha: 0.05)
              : _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : _borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? AppColors.primaryOrange : _subColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color:
                            isSelected ? AppColors.primaryOrange : _textColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primaryOrange : _subColor,
                      width: isSelected ? 5 : 2,
                    ),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: _subColor),
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Text(
                '${'Remaining Balance:'.tr(context)} $remainingText',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Select Payment Method'.tr(context),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your preferred payment method'.tr(context),
            style: TextStyle(fontSize: 12, color: _subColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMethodCard(
                  id: 'DuitNow QR',
                  title: 'QR Payment'.tr(context),
                  subtitle: 'Scan QR code to pay instantly'.tr(context),
                  icon: Icons.qr_code_2_rounded,
                  iconBg: AppColors.primaryOrange.withValues(alpha: 0.1),
                  iconColor: AppColors.primaryOrange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMethodCard(
                  id: 'Bank Transfer',
                  title: 'Bank Transfer'.tr(context),
                  subtitle: 'Transfer to our bank account'.tr(context),
                  icon: Icons.account_balance_rounded,
                  iconBg: _isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  iconColor:
                      _isDark ? Colors.white70 : AppColors.secondaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    final isSelected = _selectedPaymentMethod == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOrange.withValues(alpha: 0.05)
              : _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : _borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primaryOrange : _subColor,
                      width: isSelected ? 6 : 2,
                    ),
                    color: Colors.white,
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? AppColors.primaryOrange : _textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: _subColor),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsSection(
      String displayBookingId, String refNo, double amountToPay, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2. Payment Details'.tr(context),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (_selectedPaymentMethod == 'DuitNow QR'
                    ? 'Complete your payment using QR code'
                    : 'Complete your payment using bank transfer')
                .tr(context),
            style: TextStyle(fontSize: 12, color: _subColor),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildPaymentLeftBox()),
                      const SizedBox(width: 24),
                      Expanded(
                          flex: 6,
                          child: _buildPaymentRightBox(
                              displayBookingId, refNo, amountToPay)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPaymentLeftBox(),
                      const SizedBox(height: 20),
                      _buildPaymentRightBox(displayBookingId, refNo, amountToPay),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentLeftBox() {
    final isQr = _selectedPaymentMethod == 'DuitNow QR';

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isQr
                    ? AppColors.primaryOrange.withValues(alpha: 0.1)
                    : AppColors.secondaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isQr ? Icons.qr_code_2 : Icons.account_balance,
                color: isQr
                    ? AppColors.primaryOrange
                    : AppColors.secondaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (isQr ? 'QR Payment' : 'Bank Transfer').tr(context),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _textColor,
                    ),
                  ),
                  Text(
                    (isQr
                            ? 'Scan the QR code using your banking app'
                            : 'Transfer funds directly to our bank account')
                        .tr(context),
                    style: TextStyle(fontSize: 11, color: _subColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isQr) ...[
          MouseRegion(
            cursor: (_qrCodeUrl != null && _qrCodeUrl!.isNotEmpty)
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: () {
                if (_qrCodeUrl != null && _qrCodeUrl!.isNotEmpty) {
                  _showFullQrDialog(context, _qrCodeUrl!);
                }
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 190,
                        height: 190,
                        child: (_qrCodeUrl != null && _qrCodeUrl!.isNotEmpty)
                            ? AppImage(
                                imageSrc: _qrCodeUrl!,
                                fit: BoxFit.contain,
                                placeholder: const Center(
                                    child: CircularProgressIndicator()),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.qr_code_2_rounded,
                                      size: 80, color: Colors.grey),
                                  const SizedBox(height: 6),
                                  Text(
                                    'DuitNow QR code loaded from Admin Settings'
                                        .tr(context),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (_qrCodeUrl != null && _qrCodeUrl!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.zoom_in,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to enlarge QR Code'.tr(context),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${'Merchant:'.tr(context)} ${_getVal(_accountName, 'CarRent Sdn. Bhd.')}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 12, color: _subColor),
              const SizedBox(width: 4),
              Text(
                'All payments are secure and encrypted'.tr(context),
                style: TextStyle(fontSize: 10, color: _subColor),
              ),
            ],
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                if (_bankLogoUrl != null && _bankLogoUrl!.isNotEmpty)
                  SizedBox(
                    height: 50,
                    child: AppImage(
                        imageSrc: _bankLogoUrl!,
                        fit: BoxFit.contain,
                        placeholder: const SizedBox()),
                  )
                else
                  const Icon(Icons.account_balance_rounded,
                      size: 60, color: AppColors.primaryOrange),
                const SizedBox(height: 12),
                Text(
                  _getVal(_bankName, 'Maybank Islamic Berhad'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getVal(_accountName, 'CarRent Enterprise Sdn Bhd'),
                  style: TextStyle(fontSize: 12, color: _subColor),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: _subColor),
                    const SizedBox(width: 4),
                    Text(
                      'All payments are secure and encrypted'.tr(context),
                      style: TextStyle(fontSize: 10, color: _subColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentRightBox(
      String displayBookingId, String refNo, double amountToPay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              _buildDetailRow(
                  'Amount to Pay'.tr(context), 'RM ${amountToPay.toStringAsFixed(2)}',
                  isOrange: true),
              const Divider(height: 16),
              _buildDetailRow('Booking ID'.tr(context), displayBookingId,
                  isCopyable: true, copyValue: displayBookingId),
              const Divider(height: 16),
              _buildDetailRow('Bank Name'.tr(context),
                  _getVal(_bankName, 'Maybank Islamic Berhad')),
              const Divider(height: 16),
              _buildDetailRow('Account Name'.tr(context),
                  _getVal(_accountName, 'CarRent Enterprise Sdn Bhd')),
              const Divider(height: 16),
              _buildDetailRow('Account Number'.tr(context),
                  _getVal(_accountNumber, '562106789012'),
                  isCopyable: true,
                  copyValue: _getVal(_accountNumber, '562106789012')),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Notice Alert Box (Without Expires In as requested)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please complete the payment. Once payment is done, upload your receipt and click the button below.'
                      .tr(context),
                  style: TextStyle(
                    fontSize: 12,
                    color: _textColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isOrange = false, bool isCopyable = false, String? copyValue}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: _subColor)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isOrange ? AppColors.primaryOrange : _textColor,
                ),
              ),
            ),
            if (isCopyable) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: copyValue ?? value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied to clipboard!'.tr(context)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.copy_rounded,
                      size: 14, color: AppColors.primaryOrange),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildUploadReceiptSection(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Upload Payment Receipt'.tr(context),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(Required)'.tr(context),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Please upload your payment receipt as proof of payment.'.tr(context),
            style: TextStyle(fontSize: 12, color: _subColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickReceipt,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _receiptBase64 == null
                            ? _borderColor
                            : Colors.green,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 28,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Click to upload or drag and drop'.tr(context),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'JPG, PNG, PDF (Max 5MB)'.tr(context),
                          style: TextStyle(fontSize: 11, color: _subColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_receiptBase64 != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long,
                              color: Colors.green, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _receiptFileName ?? 'receipt.jpg',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Row(
                                children: [
                                  Text(
                                    'Attached',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.check_circle,
                                      size: 14, color: Colors.green),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() {
                              _receiptBase64 = null;
                              _receiptFileName = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _isSubmitting ? null : _submitPayment,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.check_circle_outline, size: 22),
        label: Text(
          (_isSubmitting
                  ? 'Submitting Payment...'
                  : "I've Completed Payment")
              .tr(context),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterSecurityBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                _isDark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.shield_outlined, color: Colors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your payment is secure and encrypted.'.tr(context),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _textColor,
                  ),
                ),
                Text(
                  'You will receive a notification once your payment is verified.'
                      .tr(context),
                  style: TextStyle(fontSize: 11, color: _subColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullQrDialog(BuildContext context, String qrUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_2,
                            color: AppColors.primaryOrange, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'DuitNow QR Payment'.tr(context),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : AppColors.secondaryBlue,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 16),
                const SizedBox(height: 8),
                Text(
                  'Scan the QR code using your banking app to complete payment:'
                      .tr(context),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: SizedBox(
                      width: 300,
                      height: 300,
                      child: AppImage(
                        imageSrc: qrUrl,
                        fit: BoxFit.contain,
                        placeholder:
                            const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.zoom_in,
                        size: 14, color: AppColors.primaryOrange),
                    const SizedBox(width: 4),
                    Text(
                      'Pinch or double tap to zoom in'.tr(context),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Close'.tr(context),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
