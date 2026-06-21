import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../constants/colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import 'booking_confirmation_screen.dart';
import '../../../widgets/loading_widget.dart';

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

  String _paymentMethod = 'DuitNow QR'; // 'DuitNow QR', 'FPX Online Banking', 'Cash'
  String? _selectedBank; // Maybank, CIMB, RHB, Public Bank, Hong Leong
  String _paymentOption = 'Deposit'; // 'Deposit' or 'Full'
  bool _loading = false;
  String? _userName;
  String? _userPhone;

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

  double get _depositAmount {
    // 30% of total price as deposit, minimum RM 150
    final calc = _totalPrice * 0.3;
    return calc < 150 ? 150.0 : calc;
  }

  double get _balanceAmount {
    return _totalPrice - _depositAmount;
  }

  Future<void> _selectPickupDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate!.add(const Duration(days: 1)),
      firstDate: _pickupDate!.add(const Duration(days: 1)),
      lastDate: _pickupDate!.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
      _showDuitNowDialog();
    } else if (_paymentMethod == 'FPX Online Banking') {
      _showFPXDialog();
    } else {
      _showCashConfirmationDialog();
    }
  }

  // DUITNOW QR payment flow
  void _showDuitNowDialog() {
    final payAmount = _paymentOption == 'Deposit' ? _depositAmount : _totalPrice;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pay via DuitNow QR', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Scan the QR code below to complete the deposit payment transfer.', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                // Stylized high-fidelity representation of DuitNow QR
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
                      const Expanded(
                        child: Icon(Icons.qr_code_2, size: 120, color: Colors.black),
                      ),
                      Text('RM ${payAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Upload/Paste your DuitNow Transaction Reference ID below:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _txnIdController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Ref: 123456789012',
                    labelText: 'Transaction Reference ID',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
              onPressed: () {
                if (_txnIdController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter the DuitNow reference ID.')),
                  );
                  return;
                }
                Navigator.pop(context);
                _processBooking(status: 'pending', txId: _txnIdController.text.trim());
              },
              child: const Text('VERIFY PAYMENT', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // FPX Online Banking payment flow
  void _showFPXDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Your Bank', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choose your preferred FPX online banking bank portal to authorize payment:'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBank,
                        hint: const Text('Choose a bank'),
                        isExpanded: true,
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
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                  onPressed: _selectedBank == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          _simulateFPXGateway();
                        },
                  child: const Text('PROCEED', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _simulateFPXGateway() {
    // Shows custom dialog simulating redirection to Maybank/CIMB secure authorize page
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryOrange),
              const SizedBox(height: 20),
              Text('Redirecting to $_selectedBank portal...', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Please authorize the FPX secure payment window.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pop(context); // close simulation loading dialog
      _processBooking(status: 'paid', txId: 'FPX-${_selectedBank?.substring(0, 3).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}');
    });
  }

  // Cash payment confirmation
  void _showCashConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cash Payment Verification', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
          content: const Text(
            'Your booking will be placed in a pending verification status. You must complete the cash payment at the pickup branch counter before vehicle keys can be released.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
              onPressed: () {
                Navigator.pop(context);
                _processBooking(status: 'pending', txId: 'CASH-BRANCH-${DateTime.now().millisecondsSinceEpoch}');
              },
              child: const Text('RESERVE', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Core Booking processor
  Future<void> _processBooking({required String status, required String txId}) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null || _userName == null) return;

    setState(() => _loading = true);

    try {
      final String bookingId = FirebaseDatabase.instance.ref().child('bookings').push().key!;
      
      final booking = BookingModel(
        id: bookingId,
        vehicleId: widget.vehicle.id,
        vehicleName: '${widget.vehicle.brand} ${widget.vehicle.model}',
        userId: currentUser.uid,
        userName: _userName!,
        userPhone: _userPhone ?? '',
        pickUpDate: _pickupDate!,
        returnDate: _returnDate!,
        totalPrice: _totalPrice,
        depositAmount: _depositAmount,
        status: status == 'paid' ? 'approved' : 'pending',
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      // Save Booking
      await _bookingService.createBooking(booking);

      // Save Payment record
      final payAmount = _paymentOption == 'Deposit' ? _depositAmount : _totalPrice;
      final payment = PaymentModel(
        id: '',
        bookingId: bookingId,
        userId: currentUser.uid,
        amount: payAmount,
        depositAmount: _depositAmount,
        balanceAmount: _paymentOption == 'Deposit' ? _balanceAmount : 0.0,
        paymentMethod: _paymentMethod,
        status: status,
        transactionId: txId,
        paymentDate: DateTime.now(),
      );

      await _paymentService.createPayment(payment);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmationScreen(
            booking: booking,
            vehicle: widget.vehicle,
          ),
        ),
        (route) => false,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.secondaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Rent Reservation Checkout',
          style: TextStyle(color: AppColors.secondaryBlue, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: LoadingWidget(message: 'Processing your reservation booking...'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle summary
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    color: AppColors.lightGray,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: widget.vehicle.mainImage.isNotEmpty
                                ? Image.network(
                                    widget.vehicle.mainImage,
                                    height: 80,
                                    width: 100,
                                    fit: BoxFit.cover,
                                     errorBuilder: (_, _, _) => Container(
                                      height: 80,
                                      width: 100,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.car_rental, color: Colors.grey),
                                    ),
                                  )
                                : Container(
                                    height: 80,
                                    width: 100,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.car_rental, color: Colors.grey),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.vehicle.brand.toUpperCase(),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  widget.vehicle.model,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'RM ${widget.vehicle.pricePerDay.toStringAsFixed(0)} / day',
                                  style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Date Selectors
                  const Text('Select Rental Dates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectPickupDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderGray),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pick-up Date', style: TextStyle(color: AppColors.lightText, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  _pickupDate != null ? dateFormat.format(_pickupDate!) : 'Select Date',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectReturnDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderGray),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Return Date', style: TextStyle(color: AppColors.lightText, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  _returnDate != null ? dateFormat.format(_returnDate!) : 'Select Date',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Notes
                  const Text('Special Requests / Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Need child seat, airport terminal pickup...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Deposit choices
                  const Text('Payment Option', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Pay Deposit Only')),
                          selected: _paymentOption == 'Deposit',
                          selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                          backgroundColor: AppColors.lightGray,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _paymentOption == 'Deposit' ? AppColors.primaryOrange : AppColors.secondaryBlue,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _paymentOption = 'Deposit';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Pay Full Amount')),
                          selected: _paymentOption == 'Full',
                          selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                          backgroundColor: AppColors.lightGray,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _paymentOption == 'Full' ? AppColors.primaryOrange : AppColors.secondaryBlue,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _paymentOption = 'Full';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Payment Method
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderGray),
                        ),
                        child: DropdownButton<String>(
                          value: _paymentMethod,
                          underline: const SizedBox(),
                          items: ['DuitNow QR', 'FPX Online Banking', 'Cash'].map((val) {
                            return DropdownMenuItem(
                              value: val,
                              child: Text(val, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _paymentMethod = val;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Price breakdown
                  if (_rentalDays > 0) ...[
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text('Price Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
                    const SizedBox(height: 12),
                    _buildPriceRow('Rental Duration', '$_rentalDays days'),
                    _buildPriceRow('Price / Day', 'RM ${widget.vehicle.pricePerDay.toStringAsFixed(2)}'),
                    _buildPriceRow('Total Cost', 'RM ${_totalPrice.toStringAsFixed(2)}', isBold: true),
                    const Divider(height: 24),
                    _buildPriceRow('Deposit Amount (RM 150 min)', 'RM ${_depositAmount.toStringAsFixed(2)}',
                        isBold: _paymentOption == 'Deposit', color: AppColors.primaryOrange),
                    _buildPriceRow('Balance Amount', 'RM ${_balanceAmount.toStringAsFixed(2)}'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                         color: AppColors.primaryOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Checkout Amount Due Now:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondaryBlue),
                          ),
                          Text(
                            _paymentOption == 'Deposit'
                                ? 'RM ${_depositAmount.toStringAsFixed(2)}'
                                : 'RM ${_totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _pickupDate != null && _returnDate != null ? _triggerPaymentFlow : null,
                      child: const Text('CONFIRM RESERVATION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: isBold ? 15 : 13,
      color: color ?? AppColors.secondaryBlue,
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
