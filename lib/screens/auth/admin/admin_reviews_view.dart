import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../constants/colors.dart';
import '../../../models/review_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/review_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/user_session.dart';
import '../../../l10n/app_translations.dart';

class AdminReviewsView extends StatefulWidget {
  const AdminReviewsView({super.key});

  @override
  State<AdminReviewsView> createState() => _AdminReviewsViewState();
}

class _AdminReviewsViewState extends State<AdminReviewsView> {
  final ReviewService _reviewService = ReviewService();
  final VehicleService _vehicleService = VehicleService();

  List<ReviewModel> _reviews = [];
  Map<String, VehicleModel> _vehicleMap = {};
  bool _loading = true;
  String? _error;

  // Filter & Search Controls
  final TextEditingController _searchController = TextEditingController();
  String _selectedRatingFilter = 'All'; // 'All', '5', '4', '3', '2', '1'
  String _selectedVehicleFilter = 'All'; // 'All' or vehicleId

  StreamSubscription<DatabaseEvent>? _reviewsSubscription;

  @override
  void initState() {
    super.initState();
    _loadDependencies();
    _subscribeReviews();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _reviewsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDependencies() async {
    try {
      final vehicles = await _vehicleService.getVehicles();
      final Map<String, VehicleModel> vMap = {};
      for (final v in vehicles) {
        vMap[v.id] = v;
      }

      if (mounted) {
        setState(() {
          _vehicleMap = vMap;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[AdminReviewsView] Error loading vehicles: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _subscribeReviews() {
    _reviewsSubscription?.cancel();
    _reviewsSubscription = FirebaseDatabase.instance
        .ref()
        .child('reviews')
        .onValue
        .listen((event) {
      if (mounted) {
        final List<ReviewModel> list = [];
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final Map<dynamic, dynamic> data =
                event.snapshot.value as Map<dynamic, dynamic>;
            data.forEach((key, value) {
              if (value is Map) {
                list.add(ReviewModel.fromMap(key.toString(), value));
              }
            });
          } catch (e) {
            debugPrint('[AdminReviewsView] Error parsing reviews: $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() {
          _reviews = list;
          _loading = false;
        });
      }
    }, onError: (err) {
      debugPrint('[AdminReviewsView] Realtime subscription error: $err');
      if (mounted) {
        setState(() {
          _error = 'Failed to load live reviews: $err';
          _loading = false;
        });
      }
    });
  }

  List<ReviewModel> _getFilteredReviews() {
    final query = _searchController.text.trim().toLowerCase();

    return _reviews.where((r) {
      // Rating filter
      if (_selectedRatingFilter != 'All') {
        final targetRating = double.tryParse(_selectedRatingFilter) ?? 0.0;
        if (r.rating.floor() != targetRating.floor()) {
          return false;
        }
      }

      // Vehicle filter
      if (_selectedVehicleFilter != 'All' && r.vehicleId != _selectedVehicleFilter) {
        return false;
      }

      // Search query
      if (query.isNotEmpty) {
        final userName = r.userName.toLowerCase();
        final comment = r.comment.toLowerCase();
        final vehicle = _vehicleMap[r.vehicleId];
        final vehicleName = vehicle != null ? '${vehicle.brand} ${vehicle.model} ${vehicle.plateNumber}'.toLowerCase() : '';

        if (!userName.contains(query) &&
            !comment.contains(query) &&
            !vehicleName.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
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
        await _reviewService.deleteReview(review.id);
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
              content: Text('${"Failed to delete comment: ".tr(context)}$e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey[600]!;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;

    final bool canDelete = ReviewService.canManageComments(UserSession().currentRole);
    final filtered = _getFilteredReviews();

    // Summary calculations
    final double avgRating = _reviews.isEmpty
        ? 0.0
        : _reviews.fold(0.0, (sum, r) => sum + r.rating) / _reviews.length;
    final int fiveStarCount = _reviews.where((r) => r.rating >= 4.5).length;
    final int lowRatingCount = _reviews.where((r) => r.rating < 3.5).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Reviews & Feedback'.tr(context),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View and manage customer comments and ratings across the platform'.tr(context),
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Refresh'.tr(context)),
                onPressed: () {
                  setState(() => _loading = true);
                  _loadDependencies();
                  _subscribeReviews();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth > 900
                  ? (constraints.maxWidth - 48) / 4
                  : constraints.maxWidth > 600
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildSummaryCard(
                    width: cardWidth,
                    title: 'Total Reviews'.tr(context),
                    value: '${_reviews.length}',
                    icon: Icons.rate_review_rounded,
                    iconColor: Colors.blue,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textPrimary,
                    subTextColor: textSecondary,
                  ),
                  _buildSummaryCard(
                    width: cardWidth,
                    title: 'Average Rating'.tr(context),
                    value: '${avgRating.toStringAsFixed(1)} ⭐',
                    icon: Icons.star_rounded,
                    iconColor: Colors.amber,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textPrimary,
                    subTextColor: textSecondary,
                  ),
                  _buildSummaryCard(
                    width: cardWidth,
                    title: '5-Star Ratings'.tr(context),
                    value: '$fiveStarCount',
                    icon: Icons.thumb_up_alt_rounded,
                    iconColor: Colors.green,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textPrimary,
                    subTextColor: textSecondary,
                  ),
                  _buildSummaryCard(
                    width: cardWidth,
                    title: 'Low Rating Alerts'.tr(context),
                    value: '$lowRatingCount',
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.redAccent,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textColor: textPrimary,
                    subTextColor: textSecondary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Filters & Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search Input
                SizedBox(
                  width: 280,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search customer name or comment...'.tr(context),
                      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

                // Rating Filter
                DropdownButton<String>(
                  value: _selectedRatingFilter,
                  dropdownColor: cardColor,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                  items: [
                    DropdownMenuItem(value: 'All', child: Text('All Ratings'.tr(context))),
                    DropdownMenuItem(value: '5', child: Text('5 Stars ⭐⭐⭐⭐⭐'.tr(context))),
                    DropdownMenuItem(value: '4', child: Text('4 Stars ⭐⭐⭐⭐'.tr(context))),
                    DropdownMenuItem(value: '3', child: Text('3 Stars ⭐⭐⭐'.tr(context))),
                    DropdownMenuItem(value: '2', child: Text('2 Stars ⭐⭐'.tr(context))),
                    DropdownMenuItem(value: '1', child: Text('1 Star ⭐'.tr(context))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRatingFilter = val);
                  },
                ),

                // Vehicle Filter
                DropdownButton<String>(
                  value: _selectedVehicleFilter,
                  dropdownColor: cardColor,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                  items: [
                    DropdownMenuItem(value: 'All', child: Text('All Vehicles'.tr(context))),
                    ..._vehicleMap.values.map(
                      (v) => DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.brand} ${v.model} (${v.plateNumber})'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedVehicleFilter = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Content State
          if (_loading) ...[
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          ] else if (_error != null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ] else if (filtered.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40.0),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 48, color: textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'No reviews found matching the selected filters.'.tr(context),
                    style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ] else ...[
            // List of Review Cards
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final review = filtered[index];
                final vehicle = _vehicleMap[review.vehicleId];
                final vehicleName = vehicle != null
                    ? '${vehicle.brand} ${vehicle.model} (${vehicle.plateNumber})'
                    : '${"Vehicle ID: ".tr(context)}${review.vehicleId}';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.15),
                                child: Text(
                                  review.userName.isNotEmpty ? review.userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review.userName,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    vehicleName,
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(review.createdAt),
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                              if (canDelete) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  tooltip: 'Delete Comment'.tr(context),
                                  onPressed: () => _confirmAndDeleteComment(review),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Row(
                            children: List.generate(5, (starIdx) {
                              return Icon(
                                starIdx < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                color: Colors.amber,
                                size: 18,
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${review.rating.toStringAsFixed(1)} / 5.0',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                          ),
                        ],
                      ),
                      if (review.comment.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            review.comment,
                            style: TextStyle(fontSize: 13, height: 1.4, color: textPrimary),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
