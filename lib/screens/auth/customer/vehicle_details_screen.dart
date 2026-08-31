import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/review_model.dart';
import '../../../models/maintenance_job_model.dart';
import '../../../services/maintenance_service.dart';
import '../../../constants/colors.dart';
import '../../../widgets/custom_app_bar.dart';
import 'booking_screen.dart';
import 'customer_responsive_shell.dart';
import '../../../widgets/app_image.dart';
import '../../../services/payment_restriction_service.dart';
import '../../../services/user_session.dart';
import '../../../services/review_service.dart';
import '../../../l10n/app_translations.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final VehicleModel vehicle;
  final bool hideAppBar;

  const VehicleDetailsScreen({
    super.key,
    required this.vehicle,
    this.hideAppBar = false,
  });

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
  Color get _subColor => _isDark ? const Color(0xFFCBD5E1) : AppColors.lightText;

  List<ReviewModel> _reviews = [];
  double _avgRating = 0.0;

  List<MaintenanceJobModel> _maintenanceJobs = [];
  
  int _selectedImageIndex = 0;

  late VehicleModel _vehicle;
  StreamSubscription<DatabaseEvent>? _vehicleSubscription;
  StreamSubscription<DatabaseEvent>? _reviewsSubscription;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
    _loadDetails();
    _subscribeToVehicle();
    _subscribeToReviews();
  }

  void _subscribeToVehicle() {
    _vehicleSubscription?.cancel();
    _vehicleSubscription = FirebaseDatabase.instance
        .ref()
        .child('vehicles')
        .child(widget.vehicle.id)
        .onValue
        .listen((event) {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        if (mounted) {
          setState(() {
            _vehicle = VehicleModel.fromMap(
              widget.vehicle.id,
              event.snapshot.value as Map<dynamic, dynamic>,
            );
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _vehicleSubscription?.cancel();
    _reviewsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    if (!mounted) return;
    try {
      final jobs = await MaintenanceService().getMaintenanceJobs().timeout(const Duration(seconds: 10));
      _maintenanceJobs = jobs.where((job) => job.vehicleId == widget.vehicle.id && job.showToCustomer && job.status == 'Completed').toList();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading vehicle details/maintenance: $e');
    }
  }

  void _handleBookNow() {
    if (PaymentRestrictionService().checkRestriction(context)) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(vehicle: _vehicle),
      ),
    ).then((_) => _loadDetails());
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1024;
    final bool isTablet = width >= 600 && width <= 1024;
    final bool isMobile = width < 600;
    
    final imagesList = _vehicle.gallery.isNotEmpty 
        ? _vehicle.gallery 
        : [_vehicle.mainImage];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.hideAppBar ? null : const CustomAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 60.0 : (isTablet ? 30.0 : 16.0),
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page Header with back button
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: _textColor, size: 24),
                    onPressed: () {
                      final shell = CustomerResponsiveShell.of(context);
                      if (shell != null) {
                        shell.clearCustomBody();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_vehicle.brand} ${_vehicle.model}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Responsive Layout Grid
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 65,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildImageGallerySection(imagesList, isMobile),
                          const SizedBox(height: 24),
                          _buildDescriptionSection(),
                          const SizedBox(height: 24),
                          _buildFeaturesSection(),
                          const SizedBox(height: 24),
                          _buildMaintenanceSection(),
                          const SizedBox(height: 24),
                          _buildReviewsSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 35,
                      child: _buildBookingPanel(showSpecs: true),
                    ),
                  ],
                )
              else if (isTablet)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImageGallerySection(imagesList, isMobile),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 55,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildDescriptionSection(),
                              const SizedBox(height: 24),
                              _buildFeaturesSection(),
                              const SizedBox(height: 24),
                              _buildMaintenanceSection(),
                              const SizedBox(height: 24),
                              _buildReviewsSection(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 45,
                          child: _buildBookingPanel(showSpecs: true),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImageGallerySection(imagesList, isMobile),
                    const SizedBox(height: 16),
                    _buildBookingPanel(showSpecs: false),
                    const SizedBox(height: 16),
                    _buildSpecsSection(),
                    const SizedBox(height: 16),
                    _buildDescriptionSection(),
                    const SizedBox(height: 16),
                    _buildFeaturesSection(),
                    const SizedBox(height: 16),
                    _buildMaintenanceSection(),
                    const SizedBox(height: 16),
                    _buildReviewsSection(),
                  ],
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF10B981);
      case 'booked':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  Widget _buildImageGallerySection(List<String> imagesList, bool isMobile) {
    final double imageHeight = isMobile ? 220 : 380;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : AppColors.borderGray,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppImage(
                  imageSrc: imagesList[_selectedImageIndex],
                  height: imageHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    height: imageHeight,
                    color: AppColors.lightGray,
                    child: const Icon(Icons.directions_car, size: 80, color: Colors.grey),
                  ),
                ),
              ),
              if (_vehicle.status.toLowerCase() == 'booked')
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'BOOKED'.tr(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PREMIUM CHOICE'.tr(context),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imagesList.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedImageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedImageIndex = index),
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryOrange : AppColors.borderGray,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AppImage(
                        imageSrc: imagesList[index],
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: AppColors.lightGray,
                          child: const Icon(Icons.directions_car, size: 24, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingPanel({required bool showSpecs}) {
    final bool isAvailable = _vehicle.status.toLowerCase() == 'available';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : AppColors.borderGray,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_vehicle.brand} ${_vehicle.model}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(_vehicle.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _vehicle.status.toUpperCase().tr(context),
                  style: TextStyle(
                    color: _getStatusColor(_vehicle.status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      _avgRating > 0 ? _avgRating.toStringAsFixed(1) : "4.8",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textColor),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      '(${_reviews.length} ${'reviews'.tr(context)})',
                      style: TextStyle(fontSize: 12, color: _subColor),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'DAILY RATE'.tr(context),
                    style: TextStyle(fontSize: 9, color: _subColor, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      'RM ${_vehicle.pricePerDay.toStringAsFixed(0)}/${'Day'.tr(context)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (showSpecs) ...[
            const SizedBox(height: 24),
            const Divider(color: AppColors.borderGray),
            const SizedBox(height: 16),
            _buildSpecsGrid(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[200],
                disabledForegroundColor: Colors.grey[400],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: isAvailable ? _handleBookNow : null,
              child: Text(
                isAvailable
                    ? 'Book Your Ride'.tr(context)
                    : _vehicle.status.toLowerCase() == 'booked'
                        ? 'Currently Booked'.tr(context)
                        : 'Under Maintenance'.tr(context),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : AppColors.borderGray,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specifications'.tr(context),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildSpecsGrid(),
        ],
      ),
    );
  }

  Widget _buildSpecsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildSpecCard('TRANSMISSION'.tr(context), _vehicle.transmission.tr(context), Icons.settings_input_component_outlined),
        _buildSpecCard('ENGINE'.tr(context), _vehicle.engine, Icons.offline_bolt_outlined, isLtr: true),
        _buildSpecCard('FUEL TYPE'.tr(context), _vehicle.fuelType.tr(context), Icons.local_gas_station_outlined),
        _buildSpecCard('SEATING'.tr(context), '${_vehicle.seats} ${'Seats'.tr(context)}', Icons.airline_seat_recline_normal_rounded, isLtr: true),
        _buildSpecCard('MILEAGE'.tr(context), '${_vehicle.mileage} ${'km'.tr(context)}', Icons.speed_rounded, isLtr: true),
        _buildSpecCard('MODEL YEAR'.tr(context), '${_vehicle.year}', Icons.calendar_today_rounded, isLtr: true),
        _buildSpecCard('AIR COND'.tr(context), _vehicle.ac ? 'Equipped'.tr(context) : 'N/A'.tr(context), Icons.ac_unit_rounded),
        _buildSpecCard('COLOR'.tr(context), _vehicle.color.tr(context), Icons.palette_outlined),
      ],
    );
  }

  Widget _buildSpecCard(String label, String value, IconData icon, {bool isLtr = false}) {
    final Widget valueWidget = Text(
      value,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _textColor),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E293B) : AppColors.lightGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : AppColors.borderGray,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primaryOrange, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(color: _subColor, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                isLtr
                    ? Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: valueWidget,
                      )
                    : valueWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : AppColors.borderGray,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description'.tr(context),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _textColor),
          ),
          const SizedBox(height: 12),
          Text(
            _vehicle.description.isNotEmpty
                ? _vehicle.description
                : 'No description provided for this vehicle.'.tr(context),
            style: TextStyle(color: _subColor, height: 1.6, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : AppColors.borderGray,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Car Equipment & Features'.tr(context),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 16),
          _vehicle.equipment.isEmpty
              ? Text(
                  'Standard package inclusions.'.tr(context),
                  style: TextStyle(color: _subColor, fontSize: 12),
                )
              : Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: _vehicle.equipment.map((item) {
                    return SizedBox(
                      width: 140,
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.primaryOrange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.tr(context),
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : AppColors.borderGray,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maintenance Records'.tr(context),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _textColor),
          ),
          const SizedBox(height: 16),
          _maintenanceJobs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No public maintenance logs recorded.'.tr(context),
                      style: TextStyle(color: _subColor, fontSize: 12),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _isDark ? const Color(0xFF334155) : AppColors.borderGray),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.5),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: _isDark ? const Color(0xFF1B2436) : AppColors.secondaryBlue),
                          children: [
                            _buildTableHeaderCell('SERVICE TYPE'.tr(context)),
                            _buildTableHeaderCell('DESCRIPTION'.tr(context)),
                            _buildTableHeaderCell('START DATE'.tr(context)),
                            _buildTableHeaderCell('END DATE'.tr(context)),
                          ],
                        ),
                        ..._maintenanceJobs.map((record) {
                          return TableRow(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: _isDark ? const Color(0xFF334155) : AppColors.borderGray)),
                            ),
                            children: [
                              _buildTableCell(record.title.tr(context), isBold: true),
                              _buildTableCell(record.description.isNotEmpty ? record.description.tr(context) : 'Routine servicing'.tr(context)),
                              _buildTableCell(record.startDate, isLtr: true),
                              _buildTableCell(record.endDate, isLtr: true),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false, bool isLtr = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Widget labelWidget = Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: isDark ? const Color(0xFFCBD5E1) : AppColors.secondaryBlue,
        fontSize: 11,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: isLtr
          ? Directionality(
              textDirection: ui.TextDirection.ltr,
              child: labelWidget,
            )
          : labelWidget,
    );
  }

  void _subscribeToReviews() {
    _reviewsSubscription?.cancel();
    _reviewsSubscription = FirebaseDatabase.instance
        .ref()
        .child('reviews')
        .orderByChild('vehicleId')
        .equalTo(widget.vehicle.id)
        .onValue
        .listen((event) {
      if (mounted) {
        final List<ReviewModel> reviews = [];
        double sum = 0.0;
        if (event.snapshot.exists && event.snapshot.value != null) {
          final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            try {
              final r = ReviewModel.fromMap(key.toString(), value as Map<dynamic, dynamic>);
              reviews.add(r);
              sum += r.rating;
            } catch (e) {
              debugPrint('Error parsing review in details: $e');
            }
          });
        }
        reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() {
          _reviews = reviews;
          _avgRating = reviews.isEmpty ? 0.0 : sum / reviews.length;
        });
      }
    });
  }

  Future<void> _confirmAndDeleteComment(ReviewModel review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Comment?'.tr(context)),
        content: Text('This comment will no longer be visible to the customer.'.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel'.tr(context)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete'.tr(context)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ReviewService().deleteReview(review.id);
        if (mounted) {
          setState(() {
            _reviews.removeWhere((r) => r.id == review.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Comment deleted successfully'.tr(context)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${'Failed to delete comment:'.tr(context)} $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Widget _buildReviewsSection() {
    final bool canDeleteComments = ReviewService.canManageComments(UserSession().currentRole);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : AppColors.borderGray,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customer Reviews'.tr(context),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _textColor),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      _avgRating > 0 ? _avgRating.toStringAsFixed(1) : "0.0",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textColor),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      '(${_reviews.length})',
                      style: TextStyle(fontSize: 12, color: _subColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _reviews.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No reviews yet for this vehicle.'.tr(context),
                      style: TextStyle(color: _subColor, fontSize: 12),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _reviews.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final review = _reviews[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  review.userName,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor),
                                ),
                                if (canDeleteComments) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _confirmAndDeleteComment(review),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Directionality(
                              textDirection: ui.TextDirection.ltr,
                              child: Text(
                                DateFormat('dd MMM yyyy').format(review.createdAt),
                                style: TextStyle(fontSize: 11, color: _subColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(5, (starIdx) {
                            return Icon(
                              starIdx < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          review.comment,
                          style: TextStyle(fontSize: 12, height: 1.4, color: _textColor),
                        ),
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }
}
