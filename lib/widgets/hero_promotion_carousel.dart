import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../constants/colors.dart';
import '../models/promotion_model.dart';
import '../services/promotion_service.dart';
import '../widgets/app_image.dart';
import '../screens/auth/customer/customer_responsive_shell.dart';

class HeroPromotionCarousel extends StatefulWidget {
  final List<PromotionModel> promotions;
  final Function(PromotionModel)? onPromotionTap;

  const HeroPromotionCarousel({
    super.key,
    required this.promotions,
    this.onPromotionTap,
  });

  @override
  State<HeroPromotionCarousel> createState() => _HeroPromotionCarouselState();
}

class _HeroPromotionCarouselState extends State<HeroPromotionCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.93);
  final Set<String> _viewedPromoIds = {};
  Timer? _autoSlideTimer;
  int _currentPage = 0;

  List<PromotionModel> get _activePromotions {
    final now = DateTime.now();
    return widget.promotions.where((p) {
      if (!p.active) return false;
      if (now.isBefore(p.startDate)) return false;
      if (now.isAfter(p.endDate)) return false;
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
    _trackInitialView();
  }

  @override
  void didUpdateWidget(covariant HeroPromotionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.promotions != oldWidget.promotions) {
      _trackInitialView();
    }
  }

  void _trackInitialView() {
    final active = _activePromotions;
    if (active.isNotEmpty && _currentPage < active.length) {
      final currentPromo = active[_currentPage];
      if (!_viewedPromoIds.contains(currentPromo.id)) {
        _viewedPromoIds.add(currentPromo.id);
        PromotionService().recordView(currentPromo.id);
      }
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final active = _activePromotions;
      if (active.length <= 1 || !mounted) return;
      int nextPage = (_currentPage + 1) % active.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _activePromotions;
    if (active.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_offer_rounded,
                      color: AppColors.primaryOrange,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'FEATURED OFFERS & PROMOTIONS',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.secondaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentPage + 1}/${active.length}',
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 195,
          child: PageView.builder(
            controller: _pageController,
            itemCount: active.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              final promo = active[index];
              if (!_viewedPromoIds.contains(promo.id)) {
                _viewedPromoIds.add(promo.id);
                PromotionService().recordView(promo.id);
              }
            },
            itemBuilder: (context, index) {
              final promo = active[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildBannerCard(context, promo, isDark),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(active.length, (idx) {
              final bool isSelected = idx == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryOrange
                      : (isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCard(BuildContext context, PromotionModel promo, bool isDark) {
    final discountLabel = promo.discountType == 'percentage'
        ? '${promo.discountValue.toStringAsFixed(0)}% OFF'
        : 'RM ${promo.discountValue.toStringAsFixed(0)} OFF';

    return GestureDetector(
      onTap: () {
        PromotionService().recordClick(promo.id);
        if (widget.onPromotionTap != null) {
          widget.onPromotionTap!(promo);
        } else {
          showPromotionDetailsDialog(context, promo);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Banner Background Image
              Positioned.fill(
                child: promo.bannerUrl.isNotEmpty
                    ? AppImage(
                        imageSrc: promo.bannerUrl,
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
                      ),
              ),

              // Gradient Overlay for Readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),

              // Content Layer
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Discount Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primaryOrange, Color(0xFFEA580C)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bolt,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                discountLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Auto Apply / Code Pill
                        if (promo.autoApply)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'AUTO-APPLY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (promo.promoCode != null &&
                            promo.promoCode!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'CODE: ${promo.promoCode}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Title & Subtitle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          promo.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (promo.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            promo.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Bottom Row: Date & Action CTA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Valid until ${DateFormat('dd MMM').format(promo.endDate)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Offer',
                                style: TextStyle(
                                  color: AppColors.secondaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.secondaryBlue,
                                size: 14,
                              ),
                            ],
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
    );
  }
}

/// Promotion Cards Section (Smaller Horizontal Promo Cards)
class PromotionCardsSection extends StatelessWidget {
  final List<PromotionModel> promotions;
  final Function(PromotionModel)? onPromotionTap;

  const PromotionCardsSection({
    super.key,
    required this.promotions,
    this.onPromotionTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = promotions.where((p) {
      if (!p.active) return false;
      if (now.isBefore(p.startDate)) return false;
      if (now.isAfter(p.endDate)) return false;
      return true;
    }).toList();

    if (active.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Special Deals & Discounts',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark ? Colors.white : AppColors.secondaryBlue,
              ),
            ),
            Text(
              '${active.length} Available',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 155,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final promo = active[index];
              return _buildCompactCard(context, promo, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactCard(BuildContext context, PromotionModel promo, bool isDark) {
    final discountText = promo.discountType == 'percentage'
        ? '${promo.discountValue.toStringAsFixed(0)}%'
        : 'RM ${promo.discountValue.toStringAsFixed(0)}';

    return GestureDetector(
      onTap: () {
        PromotionService().recordClick(promo.id);
        if (onPromotionTap != null) {
          onPromotionTap!(promo);
        } else {
          showPromotionDetailsDialog(context, promo);
        }
      },
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$discountText OFF',
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (promo.promoCode != null && promo.promoCode!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      promo.promoCode!,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.secondaryBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  promo.subtitle.isNotEmpty ? promo.subtitle : promo.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exp: ${DateFormat('dd MMM').format(promo.endDate)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.grey[500],
                  ),
                ),
                const Text(
                  'Apply >',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Promotion Details Dialog
void showPromotionDetailsDialog(BuildContext context, PromotionModel promo) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final DateFormat format = DateFormat('dd MMMM yyyy');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Top Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: promo.bannerUrl.isNotEmpty
                            ? AppImage(imageSrc: promo.bannerUrl, fit: BoxFit.cover)
                            : Container(
                                color: AppColors.secondaryBlue,
                                child: const Center(
                                  child: Icon(
                                    Icons.local_offer,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title & Subtitle
                    Text(
                      promo.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.secondaryBlue,
                      ),
                    ),
                    if (promo.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        promo.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Discount & Code Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryOrange.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'DISCOUNT BENEFIT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryOrange,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    promo.discountType == 'percentage'
                                        ? '${promo.discountValue.toStringAsFixed(0)}% OFF Total Rental'
                                        : 'RM ${promo.discountValue.toStringAsFixed(2)} Instant Rebate',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryOrange,
                                    ),
                                  ),
                                ],
                              ),
                              if (promo.autoApply)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Auto Applied',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (promo.promoCode != null && promo.promoCode!.isNotEmpty) ...[
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'PROMO CODE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      promo.promoCode!,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                        color: isDark ? Colors.white : AppColors.secondaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: promo.promoCode!),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Promo code "${promo.promoCode}" copied to clipboard!',
                                        ),
                                        backgroundColor: AppColors.primaryOrange,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.copy_rounded, size: 14),
                                  label: const Text('Copy Code'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Validity & Requirements
                    Text(
                      'Promotion Conditions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.secondaryBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      Icons.calendar_today_rounded,
                      'Validity Period',
                      '${format.format(promo.startDate)} to ${format.format(promo.endDate)}',
                      isDark,
                    ),
                    if (promo.minimumBookingAmount != null)
                      _buildInfoRow(
                        Icons.shopping_bag_outlined,
                        'Minimum Booking',
                        'RM ${promo.minimumBookingAmount!.toStringAsFixed(2)}',
                        isDark,
                      ),
                    if (promo.maximumDiscount != null)
                      _buildInfoRow(
                        Icons.discount_outlined,
                        'Maximum Discount Cap',
                        'RM ${promo.maximumDiscount!.toStringAsFixed(2)}',
                        isDark,
                      ),
                    if (promo.applicableCategories.isNotEmpty)
                      _buildInfoRow(
                        Icons.category_outlined,
                        'Vehicle Categories',
                        promo.applicableCategories.join(', '),
                        isDark,
                      ),
                    const SizedBox(height: 16),

                    // Description & T&C
                    Text(
                      'About This Offer',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.secondaryBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      promo.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),

                    if (promo.termsAndConditions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.secondaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: promo.termsAndConditions
                            .map(
                              (tc) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(
                                        tc,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    CustomerResponsiveShell.of(context)?.setIndex(1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Book Vehicle with This Offer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildInfoRow(IconData icon, String title, String value, bool isDark) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryOrange),
        const SizedBox(width: 10),
        Text(
          '$title: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.secondaryBlue,
            ),
          ),
        ),
      ],
    ),
  );
}
