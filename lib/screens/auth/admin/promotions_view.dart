import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../constants/colors.dart';
import '../../../models/promotion_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/promotion_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/app_image.dart';

class PromotionsView extends StatefulWidget {
  const PromotionsView({super.key});

  @override
  State<PromotionsView> createState() => _PromotionsViewState();
}

class _PromotionsViewState extends State<PromotionsView> {
  final PromotionService _promotionService = PromotionService();
  final VehicleService _vehicleService = VehicleService();
  final ScrollController _promotionsTableScrollController = ScrollController();

  List<PromotionModel> _promotions = [];
  List<VehicleModel> _vehicles = [];
  bool _loading = true;
  String? _error;
  bool _showScrollRightHint = false;

  String _searchQuery = '';
  String _selectedStatusFilter =
      'All'; // All, Active, Inactive, Expired, Scheduled

  @override
  void initState() {
    super.initState();
    _promotionsTableScrollController.addListener(_updateTableScrollHint);
    _loadData();
  }

  @override
  void dispose() {
    _promotionsTableScrollController
      ..removeListener(_updateTableScrollHint)
      ..dispose();
    super.dispose();
  }

  void _updateTableScrollHint() {
    if (!mounted || !_promotionsTableScrollController.hasClients) return;
    final position = _promotionsTableScrollController.position;
    final canScrollRight = position.maxScrollExtent > 0;
    final isAtRightEdge = position.pixels >= (position.maxScrollExtent - 4.0);
    final shouldShow = canScrollRight && !isAtRightEdge;
    if (_showScrollRightHint != shouldShow) {
      setState(() {
        _showScrollRightHint = shouldShow;
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _promotionService.getPromotions(forceRefresh: true),
        _vehicleService.getVehicles(),
      ]);

      if (mounted) {
        setState(() {
          _promotions = results[0] as List<PromotionModel>;
          _vehicles = results[1] as List<VehicleModel>;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateTableScrollHint();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load promotions: $e';
          _loading = false;
        });
      }
    }
  }

  int get _activeCount => _promotions.where((p) => p.isCurrentlyActive).length;

  int get _totalViews => _promotions.fold(0, (sum, p) => sum + p.viewsCount);
  int get _totalClicks => _promotions.fold(0, (sum, p) => sum + p.clicksCount);
  int get _totalBookings =>
      _promotions.fold(0, (sum, p) => sum + p.bookingsCount);
  double get _totalRevenue =>
      _promotions.fold(0.0, (sum, p) => sum + p.revenueGenerated);
  double get _totalDiscount =>
      _promotions.fold(0.0, (sum, p) => sum + p.totalDiscountGiven);

  List<PromotionModel> get _filteredPromotions {
    return _promotions.where((p) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = p.name.toLowerCase().contains(q);
        final codeMatch = (p.promoCode ?? '').toLowerCase().contains(q);
        final descMatch = p.description.toLowerCase().contains(q);
        if (!nameMatch && !codeMatch && !descMatch) return false;
      }

      // Status filter
      if (_selectedStatusFilter == 'Active' && !p.isCurrentlyActive) {
        return false;
      }
      if (_selectedStatusFilter == 'Inactive' && p.active) {
        return false;
      }
      if (_selectedStatusFilter == 'Expired' && !p.isExpired) {
        return false;
      }
      if (_selectedStatusFilter == 'Scheduled' && !p.isScheduled) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return StreamBuilder<List<PromotionModel>>(
      stream: _promotionService.getPromotionsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _promotions = snapshot.data!;
        }

        return Container(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          child: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(
                        child: LoadingWidget(
                          message: 'Loading promotions & discounts...',
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(_error!),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Dashboard Header Cards
                            _buildDashboardHeaderGrid(isDesktop, isDark),
                            const SizedBox(height: 24),

                            // 2. Action Bar & Controls
                            _buildActionBar(isDesktop, isDark),
                            const SizedBox(height: 20),

                            // 3. Promotions List / Table
                            _filteredPromotions.isEmpty
                                ? _buildEmptyState(isDark)
                                : isDesktop
                                ? _buildPromotionsTable(isDark)
                                : _buildPromotionsCardList(isDark),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardHeaderGrid(bool isDesktop, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width > 1200
            ? 3
            : width > 700
            ? 3
            : 1;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount == 1 ? 2.8 : 2.2,
          children: [
            _buildStatCard(
              title: 'Active Promotions',
              value: '$_activeCount',
              subtitle: '$_totalViews Views • $_totalClicks Clicks',
              icon: Icons.local_offer_rounded,
              color: AppColors.primaryOrange,
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Bookings Converted',
              value: '$_totalBookings',
              subtitle: 'Successful promo bookings',
              icon: Icons.directions_car_filled_rounded,
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Revenue Generated',
              value: 'RM ${_totalRevenue.toStringAsFixed(0)}',
              subtitle:
                  'RM ${_totalDiscount.toStringAsFixed(0)} discounts saved',
              icon: Icons.payments_rounded,
              color: const Color(0xFF3B82F6),
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? const Color(0xFFF8FAFC)
                        : AppColors.secondaryBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(bool isDesktop, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Flex(
        direction: isDesktop ? Axis.horizontal : Axis.vertical,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: isDesktop ? 1 : 0,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by promo name or code...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.primaryOrange,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : AppColors.lightGray,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : AppColors.lightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatusFilter,
                      dropdownColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.secondaryBlue,
                      ),
                      items:
                          [
                            'All',
                            'Active',
                            'Inactive',
                            'Scheduled',
                            'Expired',
                          ].map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text('Filter: $status'),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStatusFilter = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isDesktop) const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            onPressed: () => _openPromotionDialog(),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Create Promotion',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 64,
            color: isDark ? const Color(0xFF64748B) : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Promotions Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a promotional discount to boost customer bookings.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _openPromotionDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add First Promotion'),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsTable(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _showScrollRightHint
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Row(
                      key: const ValueKey('promo-scroll-hint'),
                      children: [
                        Icon(
                          Icons.swipe_right_alt_rounded,
                          size: 16,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Scroll right to see more columns',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Scrollbar(
            controller: _promotionsTableScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            radius: const Radius.circular(12),
            thickness: 7,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateTableScrollHint();
                });
                return false;
              },
              child: SingleChildScrollView(
                controller: _promotionsTableScrollController,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
                  ),
                  dataRowMinHeight: 70,
                  dataRowMaxHeight: 85,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'PROMOTION NAME',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'DISCOUNT VALUE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'VALIDITY PERIOD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'STATUS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'CREATED / UPDATED',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'ACTIONS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  rows: _filteredPromotions.map((promo) {
                    return DataRow(
                      cells: [
                        DataCell(_buildNameCell(promo, isDark)),
                        DataCell(_buildDiscountCell(promo, isDark)),
                        DataCell(_buildValidityCell(promo, isDark)),
                        DataCell(_buildStatusBadge(promo)),
                        DataCell(_buildDateCell(promo, isDark)),
                        DataCell(_buildActionsCell(promo, isDark)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameCell(PromotionModel promo, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Text(
              promo.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.secondaryBlue,
              ),
            ),
            if (promo.autoApply) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'AUTO-APPLY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (promo.promoCode != null && promo.promoCode!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Code: ${promo.promoCode}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
        ],
        const SizedBox(height: 2),
        Text(
          promo.description,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white60 : Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDiscountCell(PromotionModel promo, bool isDark) {
    final String discountStr = promo.discountType == 'percentage'
        ? '${promo.discountValue.toStringAsFixed(1)}%'
        : 'RM ${promo.discountValue.toStringAsFixed(2)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          discountStr,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: AppColors.primaryOrange,
          ),
        ),
        if (promo.maximumDiscount != null && promo.maximumDiscount! > 0)
          Text(
            'Max: RM ${promo.maximumDiscount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
        if (promo.minimumBookingAmount != null &&
            promo.minimumBookingAmount! > 0)
          Text(
            'Min spend: RM ${promo.minimumBookingAmount!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
      ],
    );
  }

  Widget _buildValidityCell(PromotionModel promo, bool isDark) {
    final format = DateFormat('dd MMM yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Start: ${format.format(promo.startDate)}',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        Text(
          'End:   ${format.format(promo.endDate)}',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(PromotionModel promo) {
    Color color;
    String label = promo.statusText;

    switch (label) {
      case 'Active':
        color = const Color(0xFF10B981);
        break;
      case 'Scheduled':
        color = const Color(0xFF3B82F6);
        break;
      case 'Expired':
        color = const Color(0xFFEF4444);
        break;
      case 'Inactive':
      default:
        color = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCell(PromotionModel promo, bool isDark) {
    final format = DateFormat('dd MMM yyyy, HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Created: ${format.format(promo.createdAt)}',
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white60 : Colors.grey[600],
          ),
        ),
        Text(
          'Updated: ${format.format(promo.updatedAt)}',
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white60 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCell(PromotionModel promo, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: promo.active,
          activeThumbColor: AppColors.primaryOrange,
          onChanged: (val) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await _promotionService.togglePromotionActive(promo.id, val);
            } catch (e) {
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
          onPressed: () => _openPromotionDialog(existing: promo),
          tooltip: 'Edit Promotion',
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline,
            size: 20,
            color: Colors.redAccent,
          ),
          onPressed: () => _confirmDeletePromotion(promo),
          tooltip: 'Delete Promotion',
        ),
      ],
    );
  }

  Widget _buildPromotionsCardList(bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredPromotions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final promo = _filteredPromotions[index];
        final format = DateFormat('dd MMM yyyy');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      promo.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : AppColors.secondaryBlue,
                      ),
                    ),
                  ),
                  _buildStatusBadge(promo),
                ],
              ),
              if (promo.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  promo.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ],
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discount: ${promo.discountType == 'percentage' ? "${promo.discountValue}%" : "RM ${promo.discountValue.toStringAsFixed(2)}"}'
                        '${promo.maximumDiscount != null ? " (Max RM ${promo.maximumDiscount})" : ""}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryOrange,
                          fontSize: 14,
                        ),
                      ),
                      if (promo.promoCode != null &&
                          promo.promoCode!.isNotEmpty)
                        Text(
                          'Code: ${promo.promoCode}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Validity: ${format.format(promo.startDate)} - ${format.format(promo.endDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Switch(
                        value: promo.active,
                        activeThumbColor: AppColors.primaryOrange,
                        onChanged: (val) async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _promotionService.togglePromotionActive(
                              promo.id,
                              val,
                            );
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blue,
                          size: 20,
                        ),
                        onPressed: () => _openPromotionDialog(existing: promo),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _confirmDeletePromotion(promo),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeletePromotion(PromotionModel promo) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Promotion'),
          content: Text(
            'Are you sure you want to delete "${promo.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  await _promotionService.deletePromotion(promo.id);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Promotion deleted successfully.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('$e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openPromotionDialog({PromotionModel? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PromotionFormDialog(
          existing: existing,
          vehicles: _vehicles,
          promotionService: _promotionService,
        );
      },
    );
  }
}

class PromotionFormDialog extends StatefulWidget {
  final PromotionModel? existing;
  final List<VehicleModel> vehicles;
  final PromotionService promotionService;

  const PromotionFormDialog({
    super.key,
    this.existing,
    required this.vehicles,
    required this.promotionService,
  });

  @override
  State<PromotionFormDialog> createState() => _PromotionFormDialogState();
}

class _PromotionFormDialogState extends State<PromotionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _subtitleController;
  late TextEditingController _descController;
  late TextEditingController _bannerUrlController;
  late TextEditingController _discountValController;
  late TextEditingController _minBookingController;
  late TextEditingController _maxDiscountController;
  late TextEditingController _promoCodeController;
  late TextEditingController _termsController;

  String _discountType = 'percentage'; // 'percentage' or 'fixed'
  bool _active = true;
  bool _autoApply = false;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  List<String> _selectedVehicleTypes = [];
  List<String> _selectedVehicleBrands = [];
  List<String> _selectedVehicleIds = [];
  List<String> _selectedApplicableCategories = [];

  bool _submitting = false;
  String? _formError;

  final List<String> _availableCategories = [
    'Sedan',
    'SUV',
    'Hatchback',
    'Luxury',
    'MPV',
    'Compact',
    'Van',
  ];

  List<String> get _availableBrands {
    final brands = widget.vehicles.map((v) => v.brand).toSet().toList();
    if (brands.isEmpty) {
      return ['Honda', 'Toyota', 'BMW', 'Proton', 'Perodua', 'Nissan', 'Mazda'];
    }
    return brands;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameController = TextEditingController(text: p?.name ?? '');
    _subtitleController = TextEditingController(text: p?.subtitle ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _bannerUrlController = TextEditingController(text: p?.bannerUrl ?? '');
    _discountValController = TextEditingController(
      text: p != null ? p.discountValue.toString() : '',
    );
    _minBookingController = TextEditingController(
      text: p?.minimumBookingAmount != null
          ? p!.minimumBookingAmount.toString()
          : '',
    );
    _maxDiscountController = TextEditingController(
      text: p?.maximumDiscount != null ? p!.maximumDiscount.toString() : '',
    );
    _promoCodeController = TextEditingController(text: p?.promoCode ?? '');
    _termsController = TextEditingController(
      text: p?.termsAndConditions.join('\n') ?? '',
    );

    _discountType = p?.discountType ?? 'percentage';
    _active = p?.active ?? true;
    _autoApply = p?.autoApply ?? false;

    _startDate = p?.startDate ?? DateTime.now();
    _endDate = p?.endDate ?? DateTime.now().add(const Duration(days: 30));

    _selectedVehicleTypes = List.from(p?.vehicleTypes ?? []);
    _selectedVehicleBrands = List.from(p?.vehicleBrands ?? []);
    _selectedVehicleIds = List.from(p?.vehicleIds ?? []);
    _selectedApplicableCategories = List.from(p?.applicableCategories ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _descController.dispose();
    _bannerUrlController.dispose();
    _discountValController.dispose();
    _minBookingController.dispose();
    _maxDiscountController.dispose();
    _promoCodeController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _pickBannerImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 900,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final url = await widget.promotionService.uploadPromotionBanner(
          bytes,
          file.name,
        );
        setState(() {
          _bannerUrlController.text = url;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _applyPresetTemplate(PromotionModel preset) {
    setState(() {
      _nameController.text = preset.name;
      _subtitleController.text = preset.subtitle;
      _descController.text = preset.description;
      _bannerUrlController.text = preset.bannerUrl;
      _discountType = preset.discountType;
      _discountValController.text = preset.discountValue.toString();
      _promoCodeController.text = preset.promoCode ?? '';
      _autoApply = preset.autoApply;
      _minBookingController.text =
          preset.minimumBookingAmount?.toString() ?? '';
      _maxDiscountController.text = preset.maximumDiscount?.toString() ?? '';
      _termsController.text = preset.termsAndConditions.join('\n');
      _selectedApplicableCategories = List.from(preset.applicableCategories);
    });
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate.isBefore(_startDate)) {
      setState(() {
        _formError = 'End date cannot be before start date.';
      });
      return;
    }

    final double? discountVal = double.tryParse(
      _discountValController.text.trim(),
    );
    if (discountVal == null || discountVal <= 0) {
      setState(() {
        _formError = 'Discount value must be greater than zero.';
      });
      return;
    }

    if (_discountType == 'percentage' && discountVal > 100) {
      setState(() {
        _formError = 'Percentage discount cannot exceed 100%.';
      });
      return;
    }

    final promoCodeText = _promoCodeController.text.trim().toUpperCase();
    if (promoCodeText.isNotEmpty) {
      final isUnique = await widget.promotionService.isPromoCodeUnique(
        promoCodeText,
        excludeId: widget.existing?.id,
      );
      if (!isUnique) {
        setState(() {
          _formError =
              'Promo code "$promoCodeText" is already in use by another promotion.';
        });
        return;
      }
    }

    final termsList = _termsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() {
      _submitting = true;
      _formError = null;
    });

    try {
      final now = DateTime.now();
      final promo = PromotionModel(
        id: widget.existing?.id ?? '',
        name: _nameController.text.trim(),
        subtitle: _subtitleController.text.trim(),
        description: _descController.text.trim(),
        discountType: _discountType,
        discountValue: discountVal,
        startDate: _startDate,
        endDate: _endDate,
        active: _active,
        bannerUrl: _bannerUrlController.text.trim(),
        vehicleTypes: _selectedVehicleTypes,
        vehicleBrands: _selectedVehicleBrands,
        vehicleIds: _selectedVehicleIds,
        applicableCategories: _selectedApplicableCategories,
        termsAndConditions: termsList,
        minimumBookingAmount: double.tryParse(
          _minBookingController.text.trim(),
        ),
        maximumDiscount: double.tryParse(_maxDiscountController.text.trim()),
        promoCode: promoCodeText.isNotEmpty ? promoCodeText : null,
        autoApply: _autoApply,
        viewsCount: widget.existing?.viewsCount ?? 0,
        clicksCount: widget.existing?.clicksCount ?? 0,
        bookingsCount: widget.existing?.bookingsCount ?? 0,
        revenueGenerated: widget.existing?.revenueGenerated ?? 0.0,
        totalDiscountGiven: widget.existing?.totalDiscountGiven ?? 0.0,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.existing != null) {
        await widget.promotionService.updatePromotion(promo);
      } else {
        await widget.promotionService.createPromotion(promo);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existing != null
                  ? 'Promotion updated successfully!'
                  : 'Promotion created successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _formError = 'Failed to save promotion: $e';
          _submitting = false;
        });
      }
    }
  }

  Widget _buildLiveBannerPreview(bool isDark) {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'PROMOTION BANNER TITLE';
    final subtitle = _subtitleController.text.trim().isNotEmpty
        ? _subtitleController.text.trim()
        : 'Exclusive holiday promotional offer subtitle';
    final valStr = double.tryParse(_discountValController.text.trim()) ?? 0.0;
    final discountLabel = _discountType == 'percentage'
        ? '${valStr.toStringAsFixed(0)}% OFF'
        : 'RM ${valStr.toStringAsFixed(0)} OFF';
    final promoCode = _promoCodeController.text.trim().toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LIVE PROMOTIONAL BANNER PREVIEW (16:9)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: AppColors.primaryOrange,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Customer App Preview',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _bannerUrlController.text.isNotEmpty
                      ? AppImage(
                          imageSrc: _bannerUrlController.text,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.white38,
                              size: 48,
                            ),
                          ),
                        ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              discountLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (_autoApply)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'AUTO-APPLY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (promoCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'CODE: $promoCode',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Valid: ${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'View Offer',
                              style: TextStyle(
                                color: AppColors.secondaryBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final format = DateFormat('dd MMM yyyy');
    final presets = widget.promotionService.getPresetBannerTemplates();

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.local_offer, color: AppColors.primaryOrange),
          const SizedBox(width: 10),
          Text(
            widget.existing != null
                ? 'Edit Promotion & Banner'
                : 'Create New Promotion Banner',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_formError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formError!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Preset Banner Templates Selector
                if (widget.existing == null) ...[
                  const Text(
                    'Quick Presets & High-Res Templates',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presets.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(
                              Icons.flash_on,
                              size: 14,
                              color: AppColors.primaryOrange,
                            ),
                            label: Text(
                              p.name,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () => _applyPresetTemplate(p),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Promotion Title & Subtitle
                TextFormField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Promotion Title *',
                    hintText: 'e.g., EID MEGA CELEBRATION SALE',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter promotion name'
                      : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _subtitleController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Banner Subtitle (Optional)',
                    hintText:
                        'e.g., Enjoy 20% OFF all vehicle rentals across Malaysia!',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Banner Image Upload & URL
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bannerUrlController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Banner Image URL or Base64 *',
                          hintText:
                              'https://images.unsplash.com/... or upload image file',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.image),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _pickBannerImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 18,
                        ),
                      ),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: const Text('Upload'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Live Banner Preview Card
                _buildLiveBannerPreview(isDark),
                const SizedBox(height: 20),

                // 4. Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Full Description *',
                    hintText:
                        'e.g., Celebrate the festive season with family road trips! Get 20% off all fleet rentals.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter description'
                      : null,
                ),
                const SizedBox(height: 16),

                // 3. Discount Type & Value Row
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: _discountType,
                        decoration: const InputDecoration(
                          labelText: 'Discount Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Percentage (%)'),
                          ),
                          DropdownMenuItem(
                            value: 'fixed',
                            child: Text('Fixed Amount (RM)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _discountType = val;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _discountValController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Discount Value *',
                          hintText: _discountType == 'percentage'
                              ? '15.0'
                              : '50.00',
                          suffixText: _discountType == 'percentage'
                              ? '%'
                              : 'RM',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Enter value';
                          final val = double.tryParse(v.trim());
                          if (val == null || val <= 0) return 'Invalid number';
                          if (_discountType == 'percentage' && val > 100) {
                            return 'Max 100%';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Start & End Date Pickers Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectStartDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 20),
                          ),
                          child: Text(format.format(_startDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _selectEndDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 20),
                          ),
                          child: Text(format.format(_endDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 5. Active & Auto Apply Switches Row
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text(
                          'Active Status',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          _active ? 'Active' : 'Inactive',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _active,
                        activeThumbColor: AppColors.primaryOrange,
                        onChanged: (val) => setState(() => _active = val),
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text(
                          'Auto Apply',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Auto apply to eligible bookings',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _autoApply,
                        activeThumbColor: AppColors.primaryOrange,
                        onChanged: (val) => setState(() => _autoApply = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 6. Promo Code
                TextFormField(
                  controller: _promoCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Promotion Code (Optional)',
                    hintText: 'e.g., SUMMER2026',
                    border: OutlineInputBorder(),
                    helperText:
                        'Leave empty for auto-apply promotions without promo code requirement.',
                  ),
                ),
                const SizedBox(height: 16),

                // 7. Minimum Booking & Maximum Discount Amounts
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minBookingController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Min Booking (RM)',
                          hintText: 'e.g. 150.00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxDiscountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Max Discount Cap (RM)',
                          hintText: 'e.g. 50.00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 8. Vehicle Types Filter
                const Text(
                  'Applicable Vehicle Types (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _availableCategories.map((type) {
                    final isSelected = _selectedVehicleTypes.contains(type);
                    return FilterChip(
                      label: Text(type),
                      selected: isSelected,
                      selectedColor: AppColors.primaryOrange.withValues(
                        alpha: 0.2,
                      ),
                      checkmarkColor: AppColors.primaryOrange,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedVehicleTypes.add(type);
                          } else {
                            _selectedVehicleTypes.remove(type);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 9. Vehicle Brands Filter
                const Text(
                  'Applicable Vehicle Brands (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _availableBrands.map((brand) {
                    final isSelected = _selectedVehicleBrands.contains(brand);
                    return FilterChip(
                      label: Text(brand),
                      selected: isSelected,
                      selectedColor: AppColors.primaryOrange.withValues(
                        alpha: 0.2,
                      ),
                      checkmarkColor: AppColors.primaryOrange,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedVehicleBrands.add(brand);
                          } else {
                            _selectedVehicleBrands.remove(brand);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 10. Specific Vehicles Filter
                if (widget.vehicles.isNotEmpty) ...[
                  const Text(
                    'Specific Vehicles (Optional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: widget.vehicles.map((v) {
                        final isSelected = _selectedVehicleIds.contains(v.id);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(
                            '${v.brand} ${v.model} (${v.plateNumber})',
                          ),
                          value: isSelected,
                          activeColor: AppColors.primaryOrange,
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedVehicleIds.add(v.id);
                              } else {
                                _selectedVehicleIds.remove(v.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 11. Terms & Conditions
                TextFormField(
                  controller: _termsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Terms & Conditions (One per line)',
                    hintText:
                        'e.g.,\nValid for registered users.\nApplicable on rentals 2+ days.\nCannot combine with other offers.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.existing != null ? 'Save Changes' : 'Create Promotion',
                ),
        ),
      ],
    );
  }
}
