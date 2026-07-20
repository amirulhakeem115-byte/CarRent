class PromotionModel {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String discountType; // 'percentage' or 'fixed'
  final double discountValue; // % e.g. 15.0 or fixed RM e.g. 50.0
  final DateTime startDate;
  final DateTime endDate;
  final bool active;
  final String bannerUrl; // High-res 16:9 banner image URL or base64
  final List<String> vehicleTypes; // Optional vehicle type filter
  final List<String> vehicleBrands; // Optional vehicle brand filter
  final List<String> vehicleIds; // Optional specific vehicle filter
  final List<String> applicableCategories; // Optional category filter e.g. SUV, Sedan
  final List<String> termsAndConditions; // List of T&C guidelines
  final double? minimumBookingAmount; // Optional min booking amount
  final double? maximumDiscount; // Optional max discount cap
  final String? promoCode; // Optional promo code (uppercase)
  final bool autoApply; // True if auto-applied to eligible bookings

  // Analytics
  final int viewsCount;
  final int clicksCount;
  final int bookingsCount;
  final double revenueGenerated;
  final double totalDiscountGiven;

  final DateTime createdAt;
  final DateTime updatedAt;

  PromotionModel({
    required this.id,
    required this.name,
    this.subtitle = '',
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.startDate,
    required this.endDate,
    this.active = true,
    this.bannerUrl = '',
    this.vehicleTypes = const [],
    this.vehicleBrands = const [],
    this.vehicleIds = const [],
    this.applicableCategories = const [],
    this.termsAndConditions = const [],
    this.minimumBookingAmount,
    this.maximumDiscount,
    this.promoCode,
    this.autoApply = false,
    this.viewsCount = 0,
    this.clicksCount = 0,
    this.bookingsCount = 0,
    this.revenueGenerated = 0.0,
    this.totalDiscountGiven = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCurrentlyActive {
    if (!active) return false;
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  bool get isExpired {
    final now = DateTime.now();
    return now.isAfter(endDate);
  }

  bool get isScheduled {
    final now = DateTime.now();
    return now.isBefore(startDate);
  }

  String get statusText {
    if (!active) return 'Inactive';
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 'Scheduled';
    if (now.isAfter(endDate)) return 'Expired';
    return 'Active';
  }

  String get statusState {
    if (!active) return 'Paused';
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 'Upcoming';
    if (now.isAfter(endDate)) return 'Expired';
    return 'Active';
  }

  factory PromotionModel.fromMap(String id, Map<dynamic, dynamic> data) {
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    return PromotionModel(
      id: id,
      name: data['name'] ?? '',
      subtitle: data['subtitle'] ?? '',
      description: data['description'] ?? '',
      discountType: data['discountType'] ?? 'percentage',
      discountValue: (data['discountValue'] ?? 0.0).toDouble(),
      startDate: DateTime.parse(
        data['startDate'] ?? DateTime.now().toIso8601String(),
      ),
      endDate: DateTime.parse(
        data['endDate'] ?? DateTime.now().toIso8601String(),
      ),
      active: data['active'] ?? true,
      bannerUrl: data['bannerUrl'] ?? '',
      vehicleTypes: parseStringList(data['vehicleTypes']),
      vehicleBrands: parseStringList(data['vehicleBrands']),
      vehicleIds: parseStringList(data['vehicleIds']),
      applicableCategories: parseStringList(data['applicableCategories']),
      termsAndConditions: parseStringList(data['termsAndConditions']),
      minimumBookingAmount: data['minimumBookingAmount'] != null
          ? (data['minimumBookingAmount'] as num).toDouble()
          : null,
      maximumDiscount: data['maximumDiscount'] != null
          ? (data['maximumDiscount'] as num).toDouble()
          : null,
      promoCode: data['promoCode']?.toString().toUpperCase().trim(),
      autoApply: data['autoApply'] ?? false,
      viewsCount: (data['viewsCount'] ?? 0) is num ? (data['viewsCount'] as num).toInt() : 0,
      clicksCount: (data['clicksCount'] ?? 0) is num ? (data['clicksCount'] as num).toInt() : 0,
      bookingsCount: (data['bookingsCount'] ?? 0) is num ? (data['bookingsCount'] as num).toInt() : 0,
      revenueGenerated: (data['revenueGenerated'] ?? 0.0) is num ? (data['revenueGenerated'] as num).toDouble() : 0.0,
      totalDiscountGiven: (data['totalDiscountGiven'] ?? 0.0) is num ? (data['totalDiscountGiven'] as num).toDouble() : 0.0,
      createdAt: DateTime.parse(
        data['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        data['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'active': active,
      'bannerUrl': bannerUrl,
      'vehicleTypes': vehicleTypes,
      'vehicleBrands': vehicleBrands,
      'vehicleIds': vehicleIds,
      'applicableCategories': applicableCategories,
      'termsAndConditions': termsAndConditions,
      'minimumBookingAmount': minimumBookingAmount,
      'maximumDiscount': maximumDiscount,
      'promoCode': promoCode?.toUpperCase().trim(),
      'autoApply': autoApply,
      'viewsCount': viewsCount,
      'clicksCount': clicksCount,
      'bookingsCount': bookingsCount,
      'revenueGenerated': revenueGenerated,
      'totalDiscountGiven': totalDiscountGiven,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  PromotionModel copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? description,
    String? discountType,
    double? discountValue,
    DateTime? startDate,
    DateTime? endDate,
    bool? active,
    String? bannerUrl,
    List<String>? vehicleTypes,
    List<String>? vehicleBrands,
    List<String>? vehicleIds,
    List<String>? applicableCategories,
    List<String>? termsAndConditions,
    double? minimumBookingAmount,
    double? maximumDiscount,
    String? promoCode,
    bool? autoApply,
    int? viewsCount,
    int? clicksCount,
    int? bookingsCount,
    double? revenueGenerated,
    double? totalDiscountGiven,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromotionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      active: active ?? this.active,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      vehicleBrands: vehicleBrands ?? this.vehicleBrands,
      vehicleIds: vehicleIds ?? this.vehicleIds,
      applicableCategories: applicableCategories ?? this.applicableCategories,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      minimumBookingAmount: minimumBookingAmount ?? this.minimumBookingAmount,
      maximumDiscount: maximumDiscount ?? this.maximumDiscount,
      promoCode: promoCode ?? this.promoCode,
      autoApply: autoApply ?? this.autoApply,
      viewsCount: viewsCount ?? this.viewsCount,
      clicksCount: clicksCount ?? this.clicksCount,
      bookingsCount: bookingsCount ?? this.bookingsCount,
      revenueGenerated: revenueGenerated ?? this.revenueGenerated,
      totalDiscountGiven: totalDiscountGiven ?? this.totalDiscountGiven,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
