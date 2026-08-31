import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../services/booking_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/vehicle_service.dart';

class StaffQuickBookingModalSheet extends StatefulWidget {
  final String initialSource; // 'phone' or 'walkIn' or 'whatsapp'
  final VoidCallback? onBookingCreated;

  const StaffQuickBookingModalSheet({
    super.key,
    required this.initialSource,
    this.onBookingCreated,
  });

  @override
  State<StaffQuickBookingModalSheet> createState() => _StaffQuickBookingModalSheetState();
}

class _StaffQuickBookingModalSheetState extends State<StaffQuickBookingModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final BookingService _bookingService = BookingService();
  final VehicleService _vehicleService = VehicleService();
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  late String _selectedSource;

  // Customer Selection / Creation
  bool _useExistingCustomer = true;
  List<UserModel> _customerList = [];
  UserModel? _selectedCustomer;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _passportController = TextEditingController();
  final TextEditingController _drivingLicenseController = TextEditingController();

  // Vehicle Selection
  List<VehicleModel> _allVehicles = [];
  List<BookingModel> _allBookings = [];
  List<VehicleModel> _availableVehicles = [];
  VehicleModel? _selectedVehicle;

  // Dates & Time
  DateTime _pickUpDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _pickUpTime = TimeOfDay.now();
  DateTime _returnDate = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _returnTime = TimeOfDay.now();
  bool _isOpenRental = false;

  // Delivery
  bool _isDelivery = false;
  final TextEditingController _deliveryAddressController = TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController(text: '0.00');

  // Pricing & Payment
  final TextEditingController _depositController = TextEditingController(text: '100.00');
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'Cash'; // Cash, Card, QR, Online
  String _initialStatus = 'Approved'; // Staff created bookings default to Approved or Ongoing

  bool _loadingDependencies = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.initialSource;
    _loadDependencies();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _passportController.dispose();
    _drivingLicenseController.dispose();
    _deliveryAddressController.dispose();
    _deliveryFeeController.dispose();
    _depositController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    try {
      final vehicles = await _vehicleService.getVehicles();
      final users = await _databaseService.getUsers();
      final bookings = await _bookingService.getBookings(forceRefresh: true);

      final customersOnly = users.where((u) => u.normalizedRole == 'customer' || u.role == 'customer').toList();

      if (mounted) {
        setState(() {
          _allVehicles = vehicles;
          _allBookings = bookings;
          _customerList = customersOnly;
          if (customersOnly.isNotEmpty) {
            final firstCust = customersOnly.first;
            _selectedCustomer = firstCust;
            _customerNameController.text = firstCust.fullName;
            _customerPhoneController.text = firstCust.phone;
            _passportController.text = firstCust.effectivePassportNumber;
            _drivingLicenseController.text = firstCust.effectiveDrivingLicenseNumber;
          }
          _recalculateAvailableVehicles();
          _loadingDependencies = false;
        });
      }
    } catch (e) {
      debugPrint('[StaffQuickBookingModal] Error loading dependencies: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load vehicles or bookings: $e';
          _loadingDependencies = false;
        });
      }
    }
  }

  void _recalculateAvailableVehicles() {
    final pickUpCombined = DateTime(
      _pickUpDate.year, _pickUpDate.month, _pickUpDate.day,
      _pickUpTime.hour, _pickUpTime.minute,
    );
    final returnCombined = _isOpenRental
        ? pickUpCombined.add(const Duration(days: 365))
        : DateTime(
            _returnDate.year, _returnDate.month, _returnDate.day,
            _returnTime.hour, _returnTime.minute,
          );

    final reqStart = pickUpCombined;
    final reqEnd = returnCombined.isBefore(reqStart)
        ? reqStart.add(const Duration(hours: 1))
        : returnCombined;

    final List<VehicleModel> filtered = [];

    for (final v in _allVehicles) {
      final vStatus = v.status.trim().toLowerCase();
      if (vStatus == 'maintenance' || vStatus == 'inactive' || vStatus == 'disabled') {
        continue;
      }

      bool isBlocked = false;
      for (final b in _allBookings) {
        if (b.vehicleId != v.id) continue;

        if (!BookingService.shouldBlockVehicleInventory(b.status, isReturned: b.isReturned)) {
          continue;
        }

        final bStart = b.pickUpDate;
        final bEnd = b.returnDate != null
            ? b.returnDate!
            : (b.isOpenRental ? DateTime.now().add(const Duration(days: 365)) : bStart);

        // Check range overlap: [reqStart, reqEnd] overlaps [bStart, bEnd]
        if (!reqEnd.isBefore(bStart) && !reqStart.isAfter(bEnd)) {
          isBlocked = true;
          break;
        }
      }

      if (!isBlocked) {
        filtered.add(v);
      }
    }

    _availableVehicles = filtered;

    if (_selectedVehicle != null && _availableVehicles.any((v) => v.id == _selectedVehicle!.id)) {
      // Keep selected vehicle
    } else if (_availableVehicles.isNotEmpty) {
      _selectedVehicle = _availableVehicles.first;
    } else {
      _selectedVehicle = null;
    }
  }

  double get _calculatedTotalPrice {
    if (_selectedVehicle == null) return 0.0;
    final rate = _selectedVehicle!.pricePerDay;
    final delFee = double.tryParse(_deliveryFeeController.text.trim()) ?? 0.0;

    if (_isOpenRental) {
      return rate + delFee;
    }

    final pickDateTime = DateTime(
      _pickUpDate.year, _pickUpDate.month, _pickUpDate.day,
      _pickUpTime.hour, _pickUpTime.minute,
    );
    final retDateTime = DateTime(
      _returnDate.year, _returnDate.month, _returnDate.day,
      _returnTime.hour, _returnTime.minute,
    );

    int days = retDateTime.difference(pickDateTime).inDays;
    if (retDateTime.difference(pickDateTime).inHours % 24 > 2) {
      days += 1;
    }
    if (days <= 0) days = 1;

    return (days * rate) + delFee;
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      setState(() => _errorMessage = 'Please select a vehicle for this booking.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final String bookingId = 'b_${DateTime.now().millisecondsSinceEpoch}';

      final pickUpCombined = DateTime(
        _pickUpDate.year, _pickUpDate.month, _pickUpDate.day,
        _pickUpTime.hour, _pickUpTime.minute,
      );
      final returnCombined = _isOpenRental
          ? pickUpCombined.add(const Duration(days: 365))
          : DateTime(
              _returnDate.year, _returnDate.month, _returnDate.day,
              _returnTime.hour, _returnTime.minute,
            );

      final isStillAvailable = await _bookingService.isVehicleAvailableForDates(
        _selectedVehicle!.id,
        pickUpCombined,
        returnCombined,
      );

      if (!isStillAvailable) {
        final freshBookings = await _bookingService.getBookings(forceRefresh: true);
        if (mounted) {
          setState(() {
            _allBookings = freshBookings;
            _recalculateAvailableVehicles();
            _submitting = false;
            _errorMessage = 'This vehicle is no longer available for the selected period. Please choose another vehicle.';
          });
        }
        return;
      }

      final String custId = _useExistingCustomer && _selectedCustomer != null
          ? _selectedCustomer!.id
          : 'walkin_${DateTime.now().millisecondsSinceEpoch}';
      final String custName = _customerNameController.text.trim().isNotEmpty
          ? _customerNameController.text.trim()
          : 'Staff Customer';
      final String custPhone = _customerPhoneController.text.trim().isNotEmpty
          ? _customerPhoneController.text.trim()
          : 'N/A';

      final String passportNum = _passportController.text.trim();
      final String licenseNum = _drivingLicenseController.text.trim();

      final double deposit = double.tryParse(_depositController.text.trim()) ?? 0.0;
      final double deliveryFee = double.tryParse(_deliveryFeeController.text.trim()) ?? 0.0;

      final booking = BookingModel(
        id: bookingId,
        vehicleId: _selectedVehicle!.id,
        vehicleName: '${_selectedVehicle!.brand} ${_selectedVehicle!.model} (${_selectedVehicle!.plateNumber})',
        userId: custId,
        userName: custName,
        userPhone: custPhone,
        pickUpDate: pickUpCombined,
        returnDate: returnCombined,
        totalPrice: _calculatedTotalPrice,
        depositAmount: deposit,
        status: _initialStatus,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: DateTime.now(),
        paymentMethod: _paymentMethod,
        isOpenRental: _isOpenRental,
        bookingSource: _selectedSource,
        passportNumber: passportNum,
        drivingLicenseNumber: licenseNum,
        isDelivery: _isDelivery,
        deliveryFee: _isDelivery ? deliveryFee : 0.0,
        deliveryAddress: _isDelivery ? _deliveryAddressController.text.trim() : null,
      );

      await _bookingService.createBooking(booking);

      if (custId.isNotEmpty && !custId.startsWith('walkin_')) {
        try {
          await _databaseService.updateUser(custId, {
            'passportNumber': passportNum,
            'idNumber': passportNum,
            'drivingLicenseNumber': licenseNum,
            'licenseNumber': licenseNum,
          });
        } catch (_) {}
      }

      try {
        final label = booking.bookingSourceLabel;
        await _notificationService.notifyBookingEvent(
          eventName: 'New $label Booking Created',
          customerName: custName,
          vehicleName: _selectedVehicle!.model,
          bookingId: bookingId,
          details: 'Staff created a $label booking via CarRent Staff Portal.',
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${booking.bookingSourceLabel} booking created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onBookingCreated?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[StaffQuickBookingModal] Error creating booking: $e');
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = 'Failed to create booking: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final double maxHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(
                  _selectedSource == 'phone' ? Icons.phone_in_talk_rounded : Icons.directions_walk_rounded,
                  color: _selectedSource == 'phone' ? Colors.orange : Colors.purple,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedSource == 'phone' ? 'New Phone Call Booking' : 'New Walk-in Customer Booking',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textPrimary),
                      ),
                      const Text(
                        'Staff quick booking creation form',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body Content
          if (_loadingDependencies)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 1. BOOKING SOURCE SELECTOR
                      Text('Booking Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildSourceOption('phone', 'Phone Call', Icons.phone_in_talk_rounded, Colors.orange),
                          const SizedBox(width: 8),
                          _buildSourceOption('walkIn', 'Walk-in', Icons.directions_walk_rounded, Colors.purple),
                          const SizedBox(width: 8),
                          _buildSourceOption('whatsapp', 'WhatsApp', Icons.chat_rounded, Colors.green),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 2. CUSTOMER SELECTION / CREATION
                      Row(
                        children: [
                          Text('Customer Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _useExistingCustomer = !_useExistingCustomer;
                              });
                            },
                            icon: Icon(_useExistingCustomer ? Icons.person_add_rounded : Icons.contacts_rounded, size: 16),
                            label: Text(_useExistingCustomer ? 'New Walk-in Entry' : 'Select Registered Customer', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_useExistingCustomer && _customerList.isNotEmpty) ...[
                        DropdownButtonFormField<UserModel>(
                          initialValue: _selectedCustomer,
                          decoration: InputDecoration(
                            labelText: 'Select Registered Customer',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: _customerList.map((c) {
                            return DropdownMenuItem<UserModel>(
                              value: c,
                              child: Text('${c.fullName} (${c.phone.isNotEmpty ? c.phone : c.email})', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCustomer = val;
                                _customerNameController.text = val.fullName;
                                _customerPhoneController.text = val.phone;
                                _passportController.text = val.effectivePassportNumber;
                                _drivingLicenseController.text = val.effectiveDrivingLicenseNumber;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextFormField(
                        controller: _customerNameController,
                        decoration: InputDecoration(
                          labelText: 'Customer Full Name *',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Customer name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customerPhoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number *',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passportController,
                        decoration: InputDecoration(
                          labelText: 'Passport Number *',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Passport Number is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _drivingLicenseController,
                        decoration: InputDecoration(
                          labelText: 'Driving License Number *',
                          prefixIcon: const Icon(Icons.card_membership_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Driving License Number is required' : null,
                      ),
                      const SizedBox(height: 20),

                      // 3. VEHICLE SELECTION
                      Text('Vehicle Selection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                      const SizedBox(height: 8),
                      if (_availableVehicles.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.event_busy_rounded, color: Colors.redAccent, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No vehicles available for the selected dates.',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        DropdownButtonFormField<VehicleModel>(
                          initialValue: _selectedVehicle,
                          decoration: InputDecoration(
                            labelText: 'Available Vehicles (${_availableVehicles.length}) *',
                            prefixIcon: const Icon(Icons.directions_car),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: _availableVehicles.map((v) {
                            return DropdownMenuItem<VehicleModel>(
                              value: v,
                              child: Text('${v.brand} ${v.model} (${v.plateNumber}) • RM ${v.pricePerDay.toStringAsFixed(0)}/day'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedVehicle = val);
                            }
                          },
                          validator: (val) => val == null ? 'Please select an available vehicle' : null,
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 4. RENTAL DATES & TIMES
                      Text('Rental Duration & Dates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              tileColor: borderColor.withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              title: const Text('Pick-up Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              subtitle: Text(DateFormat('dd MMM yyyy').format(_pickUpDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              trailing: const Icon(Icons.calendar_month, size: 20),
                              onTap: () async {
                                final selected = await showDatePicker(
                                  context: context,
                                  initialDate: _pickUpDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (selected != null) {
                                  setState(() {
                                    _pickUpDate = selected;
                                    _recalculateAvailableVehicles();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ListTile(
                              tileColor: borderColor.withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              title: const Text('Pick-up Time', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              subtitle: Text(_pickUpTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              trailing: const Icon(Icons.access_time, size: 20),
                              onTap: () async {
                                final selected = await showTimePicker(context: context, initialTime: _pickUpTime);
                                if (selected != null) {
                                  setState(() {
                                    _pickUpTime = selected;
                                    _recalculateAvailableVehicles();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      SwitchListTile(
                        title: const Text('Open-ended Rental (No fixed return date)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Charge per day as vehicle remains active', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        value: _isOpenRental,
                        onChanged: (val) {
                          setState(() {
                            _isOpenRental = val;
                            _recalculateAvailableVehicles();
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),

                      if (!_isOpenRental) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                tileColor: borderColor.withValues(alpha: 0.15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                title: const Text('Return Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                subtitle: Text(DateFormat('dd MMM yyyy').format(_returnDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                trailing: const Icon(Icons.calendar_month, size: 20),
                                onTap: () async {
                                  final selected = await showDatePicker(
                                    context: context,
                                    initialDate: _returnDate.isBefore(_pickUpDate) ? _pickUpDate.add(const Duration(days: 1)) : _returnDate,
                                    firstDate: _pickUpDate,
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (selected != null) {
                                    setState(() {
                                      _returnDate = selected;
                                      _recalculateAvailableVehicles();
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ListTile(
                                tileColor: borderColor.withValues(alpha: 0.15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                title: const Text('Return Time', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                subtitle: Text(_returnTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                trailing: const Icon(Icons.access_time, size: 20),
                                onTap: () async {
                                  final selected = await showTimePicker(context: context, initialTime: _returnTime);
                                  if (selected != null) {
                                    setState(() {
                                      _returnTime = selected;
                                      _recalculateAvailableVehicles();
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),

                      // 5. DELIVERY OPTION
                      SwitchListTile(
                        title: const Text('Vehicle Delivery Option', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Deliver car to customer address', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        value: _isDelivery,
                        onChanged: (val) => setState(() => _isDelivery = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_isDelivery) ...[
                        TextFormField(
                          controller: _deliveryAddressController,
                          decoration: InputDecoration(
                            labelText: 'Delivery Address *',
                            prefixIcon: const Icon(Icons.location_on),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => _isDelivery && (v == null || v.trim().isEmpty) ? 'Delivery address is required' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _deliveryFeeController,
                          decoration: InputDecoration(
                            labelText: 'Delivery Fee (RM)',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 6. PRICING, DEPOSIT & PAYMENT METHOD
                      Text('Payment & Cost Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Estimated Rental Price', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                SizedBox(height: 2),
                                Text('Auto-calculated based on vehicle & dates', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              'RM ${_calculatedTotalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryOrange),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _depositController,
                              decoration: InputDecoration(
                                labelText: 'Security Deposit (RM)',
                                prefixIcon: const Icon(Icons.shield_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _paymentMethod,
                              decoration: InputDecoration(
                                labelText: 'Payment Method',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: ['Cash', 'Card', 'QR', 'Online'].map((m) {
                                return DropdownMenuItem(value: m, child: Text(m));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _paymentMethod = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _initialStatus,
                        decoration: InputDecoration(
                          labelText: 'Initial Booking Status',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: ['Approved', 'Ongoing', 'Confirmed', 'Pending'].map((st) {
                          return DropdownMenuItem(value: st, child: Text(st.toUpperCase()));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _initialStatus = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Staff Internal Notes (Optional)',
                          prefixIcon: const Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // SUBMIT BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedSource == 'phone' ? Colors.orange : (_selectedSource == 'walkIn' ? Colors.purple : AppColors.primaryOrange),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _submitting ? null : _submitBooking,
                          icon: _submitting ? const SizedBox.shrink() : const Icon(Icons.check_circle_rounded),
                          label: _submitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Confirm & Save ${_selectedSource == 'phone' ? 'Phone' : (_selectedSource == 'walkIn' ? 'Walk-in' : 'Staff')} Booking', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceOption(String value, String label, IconData icon, Color color) {
    final isSelected = _selectedSource == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedSource = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade400,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
