import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../../../constants/colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/reward_service.dart';
import 'booking_confirmation_screen.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/app_image.dart';
import '../../../services/receipt_upload_helper.dart'
    if (dart.library.html) '../../../services/receipt_upload_web.dart'
    as receipt_upload;

class BookingScreen extends StatefulWidget {
  final VehicleModel vehicle;

  const BookingScreen({super.key, required this.vehicle});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  final _notesController = TextEditingController();
  final _txnIdController = TextEditingController();
  DateTime? _pickupDate;
  DateTime? _returnDate;

  int _availablePoints = 0;
  int _pointsToRedeem = 0;
  final _pointsController = TextEditingController();
  String? _pointsError;

  String _paymentMethod = 'DuitNow QR'; // 'DuitNow QR', 'Online Bank Transfer', 'FPX Online Banking', 'Cash'
  String? _selectedBank;
  String _paymentOption = 'Deposit'; // 'Deposit' or 'Full'
  bool _loading = false;
  String? _userName;
  String? _userPhone;

  bool _qrEnabled = true;
  String? _qrCodeUrl;
  String? _bankName;
  String? _accountName;
  String? _accountNumber;
  String? _bankLogoUrl;

  // Step-tracker & payment state fields
  int _currentStep = 2; // 1: Select Car, 2: Booking Details, 3: Payment
  bool _agreeToTerms = false;
  bool _redeemPointsEnabled = false;

  final List<String> _fpxBanks = [
    'Maybank2u',
    'CIMB Clicks',
    'RHB Now',
    'Public Bank PBesecure',
    'Hong Leong Connect',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadQrSettings();
    receipt_upload.registerPlatformDropzone();
  }

  Future<void> _loadQrSettings() async {
    try {
      final settings = await _databaseService.getQrPaymentSettings().timeout(const Duration(seconds: 5));
      if (settings != null) {
        setState(() {
          _qrEnabled = settings['isEnabled'] ?? true;
          _qrCodeUrl = settings['qrCodeBase64'] ?? settings['qrCodeUrl'];
          _bankName = settings['bankName'];
          _accountName = settings['accountName'];
          _accountNumber = settings['accountNumber'];
          _bankLogoUrl = settings['bankLogoUrl'];
          
          if (!_qrEnabled && _paymentMethod == 'DuitNow QR') {
            _paymentMethod = 'FPX Online Banking';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading QR settings: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final profile = await _databaseService.getUser(user.uid).timeout(const Duration(seconds: 10));
        if (profile != null) {
          setState(() {
            _userName = profile.fullName;
            _userPhone = profile.phone;
            _availablePoints = profile.rewardPoints;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile in booking: $e');
    }
  }

  int get _rentalDays {
    if (_pickupDate == null || _returnDate == null) return 0;
    final diff = _returnDate!.difference(_pickupDate!).inDays;
    return diff <= 0 ? 1 : diff;
  }

  double get _totalPrice {
    return _rentalDays * widget.vehicle.pricePerDay;
  }

  double get _discountAmount {
    return _pointsToRedeem * 0.10;
  }

  double get _discountedTotal {
    final val = _totalPrice - _discountAmount;
    return val < 0.0 ? 0.0 : val;
  }

  double get _depositAmount {
    final calc = _discountedTotal * 0.3;
    final minDep = _discountedTotal < 150.0 ? _discountedTotal : 150.0;
    return calc < minDep ? minDep : calc;
  }

  double get _balanceAmount {
    final val = _discountedTotal - _depositAmount;
    return val < 0.0 ? 0.0 : val;
  }

  Future<void> _selectPickupDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primaryOrange,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Color(0xFFF8FAFC),
                  )
                : const ColorScheme.light(
                    primary: AppColors.primaryOrange,
                    onPrimary: Colors.white,
                    onSurface: AppColors.secondaryBlue,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _pickupDate = picked;
        if (_returnDate != null && _returnDate!.isBefore(_pickupDate!)) {
          _returnDate = null;
        }
      });
    }
  }

  Future<void> _selectReturnDate() async {
    if (_pickupDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pick-up date first')),
      );
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate!.add(const Duration(days: 1)),
      firstDate: _pickupDate!.add(const Duration(days: 1)),
      lastDate: _pickupDate!.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primaryOrange,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Color(0xFFF8FAFC),
                  )
                : const ColorScheme.light(
                    primary: AppColors.primaryOrange,
                    onPrimary: Colors.white,
                    onSurface: AppColors.secondaryBlue,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _returnDate = picked;
      });
    }
  }

  void _triggerPaymentFlow() {
    if (_pickupDate == null || _returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pick-up and return dates')),
      );
      return;
    }

    if (_paymentMethod == 'DuitNow QR') {
      _showPaymentDialog(isQr: true);
    } else if (_paymentMethod == 'Online Bank Transfer') {
      _showPaymentDialog(isQr: false);
    } else if (_paymentMethod == 'FPX Online Banking') {
      _showFPXDialog();
    } else {
      _showCashConfirmationDialog();
    }
  }

  void _showFPXDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textColor = isDark ? const Color(0xFFCBD5E1) : Colors.black87;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.transparent)),
              title: Text('Select Your Bank', style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Choose your preferred FPX online banking bank portal to authorize payment:', style: TextStyle(color: textColor, fontSize: 13)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        value: _selectedBank,
                        hint: Text('Choose a bank', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                        isExpanded: true,
                        style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue, fontWeight: FontWeight.bold),
                        items: _fpxBanks.map((bank) {
                          return DropdownMenuItem(value: bank, child: Text(bank));
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            _selectedBank = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCEL', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                  onPressed: _selectedBank != null
                      ? () {
                          Navigator.pop(context);
                          _simulateFPXGateway();
                        }
                      : null,
                  child: const Text('PROCEED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _simulateFPXGateway() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          if (dialogCtx.mounted) {
            Navigator.of(dialogCtx).pop(); // Close the simulation dialog using its own context
          }
          
          final payAmount = _paymentOption == 'Deposit' ? _depositAmount : _discountedTotal;
          final DateFormat timeFormat = DateFormat('HH:mm:ss');
          final now = DateTime.now();
          final autoTime = timeFormat.format(now);

          _processBooking(
            status: 'Approved',
            txId: 'FPX-${_selectedBank?.substring(0, 3).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}',
            amount: payAmount,
            paymentDate: now,
            paymentTime: autoTime,
          );
        });

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.transparent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryOrange),
              const SizedBox(height: 20),
              Text('Redirecting to $_selectedBank portal...', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              Text('Please authorize the FPX secure payment window.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey)),
            ],
          ),
        );
      },
    );
  }

  void _showCashConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payAmount = _paymentOption == 'Deposit' ? _depositAmount : _discountedTotal;
    final DateFormat timeFormat = DateFormat('HH:mm:ss');
    final now = DateTime.now();
    final autoTime = timeFormat.format(now);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textColor = isDark ? const Color(0xFFCBD5E1) : Colors.black87;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.transparent)),
          title: Text('Cash Payment Confirmation', style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
          content: Text(
            'Confirming this booking will place it in an active booked status. You can pay RM ${payAmount.toStringAsFixed(2)} at the branch counter on pickup.',
            style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
              onPressed: () {
                Navigator.pop(context);
                _processBooking(
                  status: 'Approved',
                  txId: 'CASH-BRANCH-${DateTime.now().millisecondsSinceEpoch}',
                  amount: payAmount,
                  paymentDate: now,
                  paymentTime: autoTime,
                );
              },
              child: const Text('CONFIRM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showPaymentDialog({required bool isQr}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payAmount = _paymentOption == 'Deposit' ? _depositAmount : _discountedTotal;
    final DateFormat dialogDateFormat = DateFormat('yyyy-MM-dd');
    final DateFormat timeFormat = DateFormat('HH:mm:ss');
    final now = DateTime.now();
    final autoDate = dialogDateFormat.format(now);
    final autoTime = timeFormat.format(now);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool hasPaid = false;
        String? receiptBase64;
        String? receiptName;
        int? receiptSize;
        String? errorMsg;

        final referenceController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            receipt_upload.onReceiptUploadedCallback = (String base64, String name, int size) {
              setDialogState(() {
                if (base64 == 'error:size' || size > 10 * 1024 * 1024) {
                  errorMsg = 'File size exceeds 10MB limit.';
                  receiptBase64 = null;
                  receiptName = null;
                  receiptSize = null;
                } else if (base64 == 'error:format') {
                  errorMsg = 'Invalid file format. Only JPG, JPEG, PNG, and PDF are accepted.';
                  receiptBase64 = null;
                  receiptName = null;
                  receiptSize = null;
                } else {
                  errorMsg = null;
                  receiptBase64 = base64;
                  receiptName = name;
                  receiptSize = size;
                }
              });
            };

            final bool canSubmit =
                receiptBase64 != null && referenceController.text.trim().isNotEmpty;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.transparent)),
              title: Text(
                hasPaid ? 'Upload Transaction Receipt' : (isQr ? 'Pay via DuitNow QR' : 'Online Bank Transfer'),
                style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasPaid) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.transparent),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BOOKING SUMMARY',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Vehicle: ${widget.vehicle.brand} ${widget.vehicle.model}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue),
                            ),
                            Text(
                              'Dates: ${dialogDateFormat.format(_pickupDate!)} to ${dialogDateFormat.format(_returnDate!)} ($_rentalDays days)',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : AppColors.secondaryBlue),
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Price:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                                Text('RM ${_totalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Amount Due ($_paymentOption):', style: const TextStyle(fontSize: 12, color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                                Text('RM ${payAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isQr) ...[
                        Text('Scan the QR code or transfer to the bank account below to complete the deposit payment transfer.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87, fontSize: 13)),
                        const SizedBox(height: 20),
                        if (_qrCodeUrl != null && _qrCodeUrl!.isNotEmpty)
                          Container(
                            width: 200,
                            height: 200,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[200]!, width: 2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  color: Colors.pink,
                                  width: double.infinity,
                                  height: 30,
                                  alignment: Alignment.center,
                                  child: const Text('DuitNow QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                                Expanded(
                                  child: AppImage(
                                    imageSrc: _qrCodeUrl,
                                    fit: BoxFit.contain,
                                    placeholder: const Icon(Icons.qr_code_2, size: 120, color: Colors.black),
                                  ),
                                ),
                                Text('RM ${payAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.qr_code_2, size: 100, color: Colors.grey),
                          ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Text('Please transfer the payment amount to the corporate bank account details listed below.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87, fontSize: 13)),
                        const SizedBox(height: 16),
                      ],
                      if (_bankName != null && _bankName!.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Bank Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_bankLogoUrl != null && _bankLogoUrl!.isNotEmpty) ...[
                                  AppImage(
                                    imageSrc: _bankLogoUrl!,
                                    height: 18,
                                    placeholder: const SizedBox(),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(_bankName!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Account Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            Text(_accountName ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFCBD5E1) : AppColors.secondaryBlue)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Account Number:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            Text(_accountNumber ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFCBD5E1) : AppColors.secondaryBlue)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                      ],
                    ] else ...[
                      Text(
                        'Please upload a copy of your transaction receipt to proceed with payment verification.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      if (kIsWeb) ...[
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const HtmlElementView(viewType: 'receipt-dropzone'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryOrange, side: const BorderSide(color: AppColors.primaryOrange)),
                          onPressed: () async {
                            final file = await receipt_upload.pickReceiptFile();
                            if (file != null) {
                              setDialogState(() {
                                if (file.base64Data == 'error:size' || file.size > 10 * 1024 * 1024) {
                                  errorMsg = 'File size exceeds 10MB limit.';
                                  receiptBase64 = null;
                                } else {
                                  errorMsg = null;
                                  receiptBase64 = file.base64Data;
                                  receiptName = file.name;
                                  receiptSize = file.size;
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.file_open),
                          label: const Text('Browse Files'),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.secondaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final file = await receipt_upload.pickReceiptFile();
                            if (file != null) {
                              setDialogState(() {
                                if (file.base64Data == 'error:size' || file.size > 10 * 1024 * 1024) {
                                  errorMsg = 'File size exceeds 10MB limit.';
                                  receiptBase64 = null;
                                } else {
                                  errorMsg = null;
                                  receiptBase64 = file.base64Data;
                                  receiptName = file.name;
                                  receiptSize = file.size;
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.file_upload),
                          label: const Text('SELECT RECEIPT FILE'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (errorMsg != null)
                        Text(
                          errorMsg!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      if (receiptBase64 != null) ...[
                        const SizedBox(height: 12),
                        Text('Receipt Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.secondaryBlue)),
                        const SizedBox(height: 8),
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(12),
                            color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: receiptName!.toLowerCase().endsWith('.pdf') || receiptBase64!.startsWith('data:application/pdf')
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 54),
                                      const SizedBox(height: 6),
                                      Text(
                                        receiptName ?? 'Receipt.pdf',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (receiptSize != null)
                                        Text(
                                          '${(receiptSize! / 1024 / 1024).toStringAsFixed(2)} MB',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                    ],
                                  )
                                : Image.memory(
                                    base64Decode(receiptBase64!.split(',').last),
                                    fit: BoxFit.contain,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              receiptBase64 = null;
                              receiptName = null;
                              receiptSize = null;
                              errorMsg = null;
                            });
                          },
                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                          label: const Text('Remove File', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: referenceController,
                        onChanged: (_) => setDialogState(() {}),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Transaction Reference ID *',
                          labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                          hintText: 'e.g., Ref: 123456789012',
                          hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
                          border: const OutlineInputBorder(),
                          helperText: 'Found on your bank transfer confirmation',
                          helperStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Payment Amount (RM)',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                          suffixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                        ),
                        child: Text(
                          'RM ${payAmount.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.secondaryBlue),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Payment Date',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                          suffixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                        ),
                        child: Text(
                          autoDate,
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.secondaryBlue),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Payment Time',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                          suffixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                        ),
                        child: Text(
                          autoTime,
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.secondaryBlue),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🔒 Amount, date and time are auto-filled and cannot be edited.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!hasPaid) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('CANCEL', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                    onPressed: () {
                      setDialogState(() {
                        hasPaid = true;
                      });
                    },
                    child: const Text('I HAVE PAID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        hasPaid = false;
                      });
                    },
                    child: Text('BACK', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                    onPressed: canSubmit
                        ? () {
                            final txId = referenceController.text.trim();
                            Navigator.pop(context);
                            _processBooking(
                              status: 'Approved',
                              txId: txId,
                              amount: payAmount,
                              paymentDate: now,
                              paymentTime: autoTime,
                              receiptImage: receiptBase64,
                            );
                          }
                        : null,
                    child: Text(
                      canSubmit ? 'SUBMIT TRANSACTION' : 'UPLOAD RECEIPT & ENTER REF ID',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  // Core Booking processor
  Future<void> _processBooking({
    required String status,
    required String txId,
    required double amount,
    required DateTime paymentDate,
    String? receiptImage,
    String? paymentTime,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    final String activeUserName = _userName ?? currentUser.displayName ?? currentUser.email?.split('@').first ?? 'Customer';

    setState(() => _loading = true);

    try {
      // 1. Validate dates
      final nowToday = DateTime.now();
      final todayStart = DateTime(nowToday.year, nowToday.month, nowToday.day);
      if (_pickupDate == null) {
        throw 'Please select a pickup date.';
      }
      if (_pickupDate!.isBefore(todayStart)) {
        throw 'Pickup date cannot be in the past.';
      }
      if (_returnDate == null) {
        throw 'Please select a return date.';
      }
      if (!_returnDate!.isAfter(_pickupDate!)) {
        throw 'Return date must be after the pickup date.';
      }

      // 2. Validate vehicle exists and is available
      final vehicleSnap = await FirebaseDatabase.instance.ref().child('vehicles').child(widget.vehicle.id).get();
      if (!vehicleSnap.exists) {
        throw 'The selected vehicle does not exist.';
      }
      final vehicleData = vehicleSnap.value as Map<dynamic, dynamic>;
      final freshStatus = (vehicleData['status'] ?? '').toString().toLowerCase();
      if (freshStatus != 'available') {
        throw 'This vehicle is no longer available (Current status: $freshStatus).';
      }

      final String bookingId = FirebaseDatabase.instance.ref().child('bookings').push().key!;
      
      final booking = BookingModel(
        id: bookingId,
        vehicleId: widget.vehicle.id,
        vehicleName: '${widget.vehicle.brand} ${widget.vehicle.model}',
        userId: currentUser.uid,
        userName: activeUserName,
        userPhone: _userPhone ?? '',
        pickUpDate: _pickupDate!,
        returnDate: _returnDate!,
        totalPrice: _discountedTotal,
        depositAmount: _depositAmount,
        status: 'Confirmed', // Confirmed automatically
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: DateTime.now(),
        pointsRedeemed: _pointsToRedeem,
        discountAmount: _discountAmount,
        pointsRedeemedProcessed: _pointsToRedeem > 0,
        rewardPointsAwarded: false,
      );

      // Save Booking
      await _bookingService.createBooking(booking);

      // Save Payment record
      final payment = PaymentModel(
        id: '',
        bookingId: bookingId,
        userId: currentUser.uid,
        amount: amount,
        depositAmount: _depositAmount,
        balanceAmount: _paymentOption == 'Deposit' ? _discountedTotal - amount : 0.0,
        paymentMethod: _paymentMethod,
        status: 'Approved', // Auto-approved
        paymentStatus: 'Approved',
        transactionId: txId,
        paymentDate: paymentDate,
        receiptImage: receiptImage,
        receiptFile: receiptImage,
        uploadedAt: DateTime.now().toIso8601String(),
        customerUid: currentUser.uid,
        paymentTime: paymentTime,
      );

      await _paymentService.createPayment(payment);

      // Deduct reward points immediately if any were redeemed
      if (_pointsToRedeem > 0) {
        try {
          await RewardPointsService().deductPointsForBooking(bookingId);
        } catch (rewardErr) {
          debugPrint('Error auto-deducting reward points: $rewardErr');
        }
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmationScreen(
            booking: booking,
            vehicle: widget.vehicle,
            paymentMethod: _paymentMethod,
            paymentStatus: 'Paid',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _txnIdController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  // --- WIDGET BUILD AND HELPERS WITH PREMIUM THEME AND DESIGN ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1B2436) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue),
          onPressed: () {
            if (_currentStep == 3) {
              setState(() => _currentStep = 2);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _currentStep == 2 ? 'Rent Reservation Checkout' : 'Payment Details',
          style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          if (_currentStep == 3)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: isDark ? Colors.greenAccent : Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text('Secure Payment', style: TextStyle(color: isDark ? Colors.greenAccent : Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: LoadingWidget(message: 'Processing your reservation booking...'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildProgressIndicator(isDark),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _currentStep == 2
                        ? _buildStep2BookingDetails(isDark)
                        : _buildStep3PaymentMockup(isDark),
                  ),
                ],
              ),
            ),
    );
  }

  // Progress stepper bar
  Widget _buildProgressIndicator(bool isDark) {
    final primaryColor = AppColors.primaryOrange;
    final mutedColor = isDark ? const Color(0xFF334155) : Colors.grey[300]!;
    final textColorActive = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final textColorMuted = isDark ? const Color(0xFF94A3B8) : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      color: isDark ? const Color(0xFF1B2436) : Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _progressNode('1', 'Select Car', false, primaryColor, textColorMuted, isDark),
          _progressDivider(primaryColor),
          _progressNode('2', 'Booking Details', _currentStep == 2, primaryColor, _currentStep == 2 ? textColorActive : textColorMuted, isDark),
          _progressDivider(_currentStep == 3 ? primaryColor : mutedColor),
          _progressNode('3', 'Payment', _currentStep == 3, primaryColor, _currentStep == 3 ? textColorActive : textColorMuted, isDark),
        ],
      ),
    );
  }

  Widget _progressNode(String number, String label, bool isActive, Color activeColor, Color textColor, bool isDark) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : (isDark ? const Color(0xFF0F172A) : Colors.grey[200]),
            border: Border.all(color: isActive ? activeColor : Colors.grey[400]!),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : Colors.grey[600]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
        ),
      ],
    );
  }

  Widget _progressDivider(Color color) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8).copyWith(bottom: 16),
      color: color,
    );
  }

  // STEP 2: Booking Details Panel Screen
  Widget _buildStep2BookingDetails(bool isDark) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final headingStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Vehicle preview
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppImage(
                  imageSrc: widget.vehicle.mainImage,
                  height: 70,
                  width: 90,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    height: 70,
                    width: 90,
                    color: Colors.grey[200],
                    child: const Icon(Icons.directions_car, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vehicle.brand.toUpperCase(),
                      style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : Colors.grey[500], fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.vehicle.model,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${widget.vehicle.pricePerDay.toStringAsFixed(0)} / day',
                      style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Date select
        Text('Select Rental Dates', style: headingStyle),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selectPickupDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pick-up Date', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.lightText, fontSize: 10)),
                      const SizedBox(height: 4),
                      Text(
                        _pickupDate != null ? dateFormat.format(_pickupDate!) : 'Select Date',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.secondaryBlue, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _selectReturnDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Return Date', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.lightText, fontSize: 10)),
                      const SizedBox(height: 4),
                      Text(
                        _returnDate != null ? dateFormat.format(_returnDate!) : 'Select Date',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.secondaryBlue, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. Special notes
        Text('Special Requests / Notes (Optional)', style: headingStyle),
        const SizedBox(height: 10),
        TextField(
          controller: _notesController,
          maxLines: 2,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. Need child seat, airport terminal pickup...',
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),

        // 4. Payment option choices (Deposit vs Full)
        Text('Payment Option', style: headingStyle),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Pay Deposit Only')),
                selected: _paymentOption == 'Deposit',
                selectedColor: AppColors.primaryOrange.withValues(alpha: 0.25),
                backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.lightGray,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: _paymentOption == 'Deposit' ? AppColors.primaryOrange : (isDark ? const Color(0xFFCBD5E1) : AppColors.secondaryBlue),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _paymentOption == 'Deposit' ? AppColors.primaryOrange : borderColor)),
                onSelected: (selected) {
                  setState(() {
                    _paymentOption = 'Deposit';
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Pay Full Amount')),
                selected: _paymentOption == 'Full',
                selectedColor: AppColors.primaryOrange.withValues(alpha: 0.25),
                backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.lightGray,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: _paymentOption == 'Full' ? AppColors.primaryOrange : (isDark ? const Color(0xFFCBD5E1) : AppColors.secondaryBlue),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _paymentOption == 'Full' ? AppColors.primaryOrange : borderColor)),
                onSelected: (selected) {
                  setState(() {
                    _paymentOption = 'Full';
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // 5. Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: (_pickupDate != null && _returnDate != null && widget.vehicle.status.toLowerCase() == 'available')
                ? () {
                    setState(() {
                      _currentStep = 3;
                    });
                  }
                : null,
            child: const Text('Proceed to Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // STEP 3: REDESIGNED PAYMENT PAGE (MOCKUP CONCEPT)
  Widget _buildStep3PaymentMockup(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey[100]!;
    final headingStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue);
    final textMuted = isDark ? const Color(0xFF94A3B8) : Colors.grey[500]!;

    final pickupDateStr = DateFormat('dd MMM yyyy').format(_pickupDate!);
    final returnDateStr = DateFormat('dd MMM yyyy').format(_returnDate!);

    final payAmount = _paymentOption == 'Deposit' ? _depositAmount : _discountedTotal;
    
    // Dynamic premium booking ID based on time
    final String tempId = widget.vehicle.id.length > 4 ? widget.vehicle.id.substring(0, 4).toUpperCase() : '0017';
    final String refIdDisplay = 'BK-${DateFormat('yyyyMMdd').format(DateTime.now())}-$tempId';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Booking Summary Card
        Text('Booking Summary', style: headingStyle),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Booking ID: #$refIdDisplay',
                      style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppImage(
                      imageSrc: widget.vehicle.mainImage,
                      height: 80,
                      width: 100,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        height: 80,
                        width: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.car_rental, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.vehicle.brand} ${widget.vehicle.model}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _specLabel(widget.vehicle.category, isDark),
                            const SizedBox(width: 8),
                            _specLabel(widget.vehicle.transmission, isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 10),
              // Route list
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.radio_button_checked, color: AppColors.primaryOrange, size: 14),
                      Container(width: 2, height: 26, color: AppColors.primaryOrange.withValues(alpha: 0.3)),
                      const Icon(Icons.location_on, color: AppColors.primaryOrange, size: 14),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pick-up',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted),
                            ),
                          ],
                        ),
                        Text(
                          widget.vehicle.branchName.isNotEmpty ? widget.vehicle.branchName : "KL Sentral Branch",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : AppColors.secondaryBlue),
                        ),
                        Text(
                          '$pickupDateStr • 10:00 AM',
                          style: TextStyle(fontSize: 10, color: textMuted),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Return',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted),
                            ),
                          ],
                        ),
                        Text(
                          widget.vehicle.branchName.isNotEmpty ? widget.vehicle.branchName : "KLIA Branch",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : AppColors.secondaryBlue),
                        ),
                        Text(
                          '$returnDateStr • 10:00 AM',
                          style: TextStyle(fontSize: 10, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: AppColors.primaryOrange, size: 16),
                    const SizedBox(width: 10),
                    Text(
                      'Duration',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                    ),
                    const Spacer(),
                    Text(
                      '$_rentalDays Days',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isDark ? Colors.white : AppColors.secondaryBlue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Price Breakdown Card
        Text('Price Breakdown', style: headingStyle),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              _buildPriceRow('Base Rental ($_rentalDays Days)', 'RM ${_totalPrice.toStringAsFixed(2)}', isDark: isDark),
              _buildPriceRow('Extra Charges', 'RM 0.00', isDark: isDark),
              _buildPriceRow('Tax (6% SST)', 'RM 0.00', isDark: isDark),
              if (_pointsToRedeem > 0)
                _buildPriceRow('Discount', '- RM ${_discountAmount.toStringAsFixed(2)}', color: Colors.green, isDark: isDark),
              const Divider(color: Colors.white10, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppColors.secondaryBlue),
                  ),
                  Text(
                    'RM ${_discountedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primaryOrange),
                  ),
                ],
              ),
              if (_paymentOption == 'Deposit') ...[
                const SizedBox(height: 8),
                _buildPriceRow('Deposit Due Now', 'RM ${_depositAmount.toStringAsFixed(2)}', color: AppColors.primaryOrange, isBold: true, isDark: isDark),
                _buildPriceRow('Remaining Balance', 'RM ${_balanceAmount.toStringAsFixed(2)}', isDark: isDark),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Reward Points Toggle/Management Card
        if (_availablePoints > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppColors.primaryOrange, size: 20),
                        const SizedBox(width: 8),
                        Text('Redeem Reward Points', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.secondaryBlue)),
                      ],
                    ),
                    Switch(
                      value: _redeemPointsEnabled,
                      activeThumbColor: AppColors.primaryOrange,
                      onChanged: (val) {
                        setState(() {
                          _redeemPointsEnabled = val;
                          if (!val) {
                            _pointsToRedeem = 0;
                            _pointsController.clear();
                            _pointsError = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (_redeemPointsEnabled) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Balance: ${_availablePoints.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} Points',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : AppColors.secondaryBlue),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 60,
                              child: TextField(
                                controller: _pointsController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Enter points',
                                  hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey, fontSize: 12),
                                  errorText: _pointsError,
                                  errorStyle: const TextStyle(fontSize: 9),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onChanged: (val) {
                                  if (val.isEmpty) {
                                    setState(() {
                                      _pointsError = null;
                                      _pointsToRedeem = 0;
                                    });
                                    return;
                                  }
                                  final parsed = int.tryParse(val) ?? -1;
                                  setState(() {
                                    if (parsed < 0) {
                                      _pointsError = 'Points must be positive';
                                      _pointsToRedeem = 0;
                                    } else if (parsed > _availablePoints) {
                                      _pointsError = 'Exceeds balance';
                                      _pointsToRedeem = 0;
                                    } else if (parsed * 0.10 > _totalPrice) {
                                      _pointsError = 'Discount exceeds total';
                                      _pointsToRedeem = 0;
                                    } else {
                                      _pointsError = null;
                                      _pointsToRedeem = parsed;
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text('Use Points', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                            const SizedBox(height: 2),
                            Text(
                              '- RM ${(_pointsToRedeem * 0.10).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primaryOrange),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 4. Payment Method Card
        Text('Payment Method', style: headingStyle),
        const SizedBox(height: 10),
        Column(
          children: [
            _paymentMethodOption(
              'FPX Online Banking',
              'Pay securely via your preferred bank',
              Icons.account_balance,
              isDark,
            ),
            const SizedBox(height: 10),
            _paymentMethodOption(
              'DuitNow QR',
              'Scan and pay with DuitNow QR code',
              Icons.qr_code,
              isDark,
            ),
            const SizedBox(height: 10),
            _paymentMethodOption(
              'Cash',
              'Pay in cash when you pick up the car',
              Icons.payments,
              isDark,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 5. Secure & Trusted Badging Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user_rounded, color: isDark ? Colors.greenAccent : Colors.green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secure & Trusted',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white : AppColors.secondaryBlue),
                    ),
                    Text(
                      'Your payment is encrypted and secure.',
                      style: TextStyle(fontSize: 10, color: textMuted),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  _badgeChip('PCI DSS', isDark),
                  _badgeChip('SSL', isDark),
                  _badgeChip('FPX', isDark),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 6. Terms check
        Row(
          children: [
            Checkbox(
              value: _agreeToTerms,
              activeColor: AppColors.primaryOrange,
              onChanged: (val) {
                setState(() {
                  _agreeToTerms = val ?? false;
                });
              },
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black87, fontSize: 11),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Payment Policy',
                      style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 7. Pay button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: (_agreeToTerms && widget.vehicle.status.toLowerCase() == 'available')
                ? _triggerPaymentFlow
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 16),
                const SizedBox(width: 8),
                const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text('RM ${payAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _specLabel(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : AppColors.secondaryBlue),
      ),
    );
  }

  Widget _paymentMethodOption(String title, String subtitle, IconData icon, bool isDark) {
    final isSelected = _paymentMethod == title || (_paymentMethod == 'Online Bank Transfer' && title == 'DuitNow QR');
    final activeBorderColor = AppColors.primaryOrange;
    final defaultBorderColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;

    return InkWell(
      onTap: () {
        setState(() {
          _paymentMethod = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? activeBorderColor : defaultBorderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primaryOrange : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.1) : (isDark ? const Color(0xFF0F172A) : AppColors.lightGray),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? AppColors.primaryOrange : Colors.grey, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.secondaryBlue),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeChip(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : Colors.green),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false, Color? color, required bool isDark}) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: isBold ? 14 : 12,
      color: color ?? (isDark ? const Color(0xFFCBD5E1) : AppColors.secondaryBlue),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
