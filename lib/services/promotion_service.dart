import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/promotion_model.dart';
import 'user_role_cache.dart';
import 'notification_service.dart';

class PromotionValidationResult {
  final bool isValid;
  final String message;
  final PromotionModel? promotion;
  final double discountAmount;

  PromotionValidationResult({
    required this.isValid,
    required this.message,
    this.promotion,
    this.discountAmount = 0.0,
  });
}

class PromotionService {
  static final PromotionService _instance = PromotionService._internal();
  factory PromotionService() => _instance;
  PromotionService._internal();

  final DatabaseReference _primaryDb = FirebaseDatabase.instance.ref().child('promotions');
  final DatabaseReference _fallbackDb = FirebaseDatabase.instance.ref().child('company_settings').child('promotions');

  List<PromotionModel>? _cachedPromotions;
  DateTime? _lastFetchTime;

  /// Clear memory cache
  void clearCache() {
    _cachedPromotions = null;
    _lastFetchTime = null;
  }

  /// Verify authenticated Admin role before executing write operations
  Future<void> _verifyAdminPermission(String operation, String targetPath) async {
    final user = FirebaseAuth.instance.currentUser;
    final String currentUid = user?.uid ?? 'unauthenticated';
    String currentRole = 'unauthenticated';
    if (user != null) {
      currentRole = await UserRoleCache.getRole(user.uid);
    }

    final isAuthorized = user != null &&
        (currentRole.toLowerCase() == 'admin' || currentRole.toLowerCase() == 'super_admin');

    debugPrint('[PromotionService] [$operation] Target DB Path: $targetPath');
    debugPrint('[PromotionService] [$operation] Current Authenticated UID: $currentUid');
    debugPrint('[PromotionService] [$operation] Current User Role: $currentRole');
    debugPrint('[PromotionService] [$operation] Admin Authorization Status: ${isAuthorized ? "AUTHORIZED" : "DENIED"}');

    if (!isAuthorized) {
      final errorMsg =
          'PERMISSION DENIED: Cannot $operation promotion. Only authenticated Admin users are permitted. '
          '(Current UID: $currentUid, Role: $currentRole, Path: $targetPath)';
      debugPrint('[PromotionService] ERROR: $errorMsg');
      throw Exception(errorMsg);
    }
  }

  List<PromotionModel> _parseSnapshot(DataSnapshot snapshot) {
    final List<PromotionModel> list = [];
    if (snapshot.exists && snapshot.value != null) {
      final rawData = snapshot.value;
      if (rawData is Map) {
        rawData.forEach((key, value) {
          if (value is Map) {
            try {
              list.add(PromotionModel.fromMap(key.toString(), value));
            } catch (e) {
              debugPrint('Error parsing promotion $key: $e');
            }
          }
        });
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Get stream of all promotions in real-time
  Stream<List<PromotionModel>> getPromotionsStream() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'unauthenticated';
    debugPrint('[FIREBASE TRACE] Screen="Promotions", Function="getPromotionsStream", Path="/promotions", Operation="ReadStream", UID="$uid"');
    return _primaryDb.onValue.map((event) {
      return _parseSnapshot(event.snapshot);
    }).handleError((error) {
      debugPrint('[PromotionService] [getPromotionsStream] Stream read exception on /promotions: $error. Returning empty list safely.');
      return <PromotionModel>[];
    });
  }

  /// Get list of all promotions (uses cache if fresh within 30 seconds, with fallback path)
  Future<List<PromotionModel>> getPromotions({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedPromotions != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inSeconds < 30) {
      return _cachedPromotions!;
    }

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'unauthenticated';
    final role = user != null ? await UserRoleCache.getRole(user.uid) : 'unauthenticated';

    debugPrint('[FIREBASE TRACE] Screen="Promotions", Function="getPromotions", Path="/promotions", Operation="Read", UID="$uid", Role="$role"');

    try {
      final snapshot = await _primaryDb.get().timeout(const Duration(seconds: 5));
      if (snapshot.exists && snapshot.value != null) {
        final list = _parseSnapshot(snapshot);
        _cachedPromotions = list;
        _lastFetchTime = DateTime.now();
        return list;
      }
    } on FirebaseException catch (e) {
      debugPrint('[PromotionService] Primary path "promotions" read warning: Code ${e.code}, Message: ${e.message}');
    } catch (e) {
      debugPrint('[PromotionService] Primary path read error: $e');
    }

    // Attempt fallback read path: company_settings/promotions
    try {
      debugPrint('[FIREBASE TRACE] Screen="Promotions", Function="getPromotions", Path="company_settings/promotions", Operation="Read", UID="$uid", Role="$role"');
      final snapshot = await _fallbackDb.get().timeout(const Duration(seconds: 5));
      if (snapshot.exists && snapshot.value != null) {
        final list = _parseSnapshot(snapshot);
        _cachedPromotions = list;
        _lastFetchTime = DateTime.now();
        return list;
      }
    } catch (e) {
      debugPrint('[PromotionService] Fallback path read error: $e');
    }

    return _cachedPromotions ?? [];
  }

  /// Create a new promotion with path resilience
  Future<void> createPromotion(PromotionModel promo) async {
    await _verifyAdminPermission('create', 'promotions');

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'unauthenticated';
    final role = user != null ? await UserRoleCache.getRole(user.uid) : 'unauthenticated';
    final now = DateTime.now();

    // 1. Try primary path: promotions/
    try {
      final ref = promo.id.isNotEmpty ? _primaryDb.child(promo.id) : _primaryDb.push();
      final String promoId = promo.id.isNotEmpty ? promo.id : ref.key!;
      final newPromo = promo.copyWith(id: promoId, createdAt: promo.createdAt, updatedAt: now);

      await ref.set(newPromo.toMap()).timeout(const Duration(seconds: 8));
      clearCache();
      await NotificationService().notifyPromotionEvent(
        eventName: 'Promotion Created',
        promoId: promoId,
        promoCode: promo.promoCode ?? 'NO CODE',
        promoName: promo.name,
        details: 'created new promotion "${promo.name}".',
        priority: 'normal',
        icon: '🏷️',
        color: '0xFF8B5CF6',
      );
      debugPrint('[PromotionService] Successfully created promotion at primary path: promotions/$promoId');
      return;
    } on FirebaseException catch (e) {
      debugPrint('[PromotionService] Primary path "promotions" write failed: Code ${e.code}, Message: ${e.message}. Attempting fallback path "company_settings/promotions"...');
    } catch (e) {
      debugPrint('[PromotionService] Primary path write error: $e');
    }

    // 2. Try fallback path: company_settings/promotions/
    try {
      final ref = promo.id.isNotEmpty ? _fallbackDb.child(promo.id) : _fallbackDb.push();
      final String promoId = promo.id.isNotEmpty ? promo.id : ref.key!;
      final newPromo = promo.copyWith(id: promoId, createdAt: promo.createdAt, updatedAt: now);

      await ref.set(newPromo.toMap()).timeout(const Duration(seconds: 8));
      clearCache();
      await NotificationService().notifyAllAdmins(
        title: 'Promotion Created 🏷️',
        message: 'New promotion created: "${promo.name}" (${promo.promoCode ?? 'No Code'}).',
        type: 'promotion',
        icon: '🏷️',
        color: '0xFF8B5CF6',
        relatedId: promoId,
        actionRoute: 'Promotions & Discounts',
      );
      debugPrint('[PromotionService] Successfully created promotion at fallback path: company_settings/promotions/$promoId');
      return;
    } on FirebaseException catch (e) {
      debugPrint('[PromotionService] FIREBASE ERROR creating promotion (fallback failed):');
      debugPrint('  - Target DB Path: company_settings/promotions');
      debugPrint('  - Current Authenticated UID: $uid');
      debugPrint('  - Current User Role: $role');
      debugPrint('  - Firebase Exception Code: ${e.code}');
      debugPrint('  - Firebase Exception Message: ${e.message}');
      throw Exception('Failed to create promotion: ${e.message} (Code: ${e.code})');
    } catch (e) {
      debugPrint('[PromotionService] Unexpected error creating promotion: $e');
      rethrow;
    }
  }

  /// Update an existing promotion with path resilience
  Future<void> updatePromotion(PromotionModel promo) async {
    await _verifyAdminPermission('update', 'promotions/${promo.id}');

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'unauthenticated';
    final role = user != null ? await UserRoleCache.getRole(user.uid) : 'unauthenticated';
    final updatedPromo = promo.copyWith(updatedAt: DateTime.now());

    // 1. Try primary path
    try {
      await _primaryDb
          .child(promo.id)
          .update(updatedPromo.toMap())
          .timeout(const Duration(seconds: 8));
      clearCache();
      debugPrint('[PromotionService] Successfully updated promotion at primary path: promotions/${promo.id}');
      return;
    } on FirebaseException catch (e) {
      debugPrint('[PromotionService] Primary update failed (Code ${e.code}). Trying fallback path...');
    } catch (e) {
      debugPrint('[PromotionService] Primary update error: $e');
    }

    // 2. Try fallback path
    try {
      await _fallbackDb
          .child(promo.id)
          .update(updatedPromo.toMap())
          .timeout(const Duration(seconds: 8));
      clearCache();
      debugPrint('[PromotionService] Successfully updated promotion at fallback path: company_settings/promotions/${promo.id}');
      return;
    } on FirebaseException catch (e) {
      debugPrint('[PromotionService] FIREBASE ERROR updating promotion:');
      debugPrint('  - Target DB Path: company_settings/promotions/${promo.id}');
      debugPrint('  - Current Authenticated UID: $uid');
      debugPrint('  - Current User Role: $role');
      debugPrint('  - Firebase Exception Code: ${e.code}');
      debugPrint('  - Firebase Exception Message: ${e.message}');
      throw Exception('Failed to update promotion: ${e.message} (Code: ${e.code})');
    } catch (e) {
      debugPrint('[PromotionService] Error updating promotion: $e');
      rethrow;
    }
  }

  /// Delete a promotion with path resilience
  Future<void> deletePromotion(String id) async {
    await _verifyAdminPermission('delete', 'promotions/$id');

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'unauthenticated';
    final role = user != null ? await UserRoleCache.getRole(user.uid) : 'unauthenticated';

    try {
      await _primaryDb.child(id).remove().timeout(const Duration(seconds: 8));
      clearCache();
      debugPrint('[PromotionService] Successfully deleted promotion at primary path: promotions/$id');
      return;
    } on FirebaseException catch (e) {
      debugPrint('[PromotionService] Primary delete failed (Code ${e.code}). Trying fallback path...');
    } catch (e) {
      debugPrint('[PromotionService] Primary delete error: $e');
    }

    try {
      await _fallbackDb.child(id).remove().timeout(const Duration(seconds: 8));
      clearCache();
      debugPrint('[PromotionService] Successfully deleted promotion at fallback path: company_settings/promotions/$id');
      return;
    } on FirebaseException catch (e) {
      debugPrint('[PromotionService] FIREBASE ERROR deleting promotion:');
      debugPrint('  - Target DB Path: company_settings/promotions/$id');
      debugPrint('  - Current Authenticated UID: $uid');
      debugPrint('  - Current User Role: $role');
      debugPrint('  - Firebase Exception Code: ${e.code}');
      debugPrint('  - Firebase Exception Message: ${e.message}');
      throw Exception('Failed to delete promotion: ${e.message} (Code: ${e.code})');
    } catch (e) {
      debugPrint('[PromotionService] Error deleting promotion: $e');
      rethrow;
    }
  }

  /// Quickly toggle active status with path resilience
  Future<void> togglePromotionActive(String id, bool active) async {
    await _verifyAdminPermission('toggle active', 'promotions/$id');

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'unauthenticated';
    final role = user != null ? await UserRoleCache.getRole(user.uid) : 'unauthenticated';
    final updateData = {
      'active': active,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      await _primaryDb.child(id).update(updateData).timeout(const Duration(seconds: 8));
      clearCache();
      await NotificationService().notifyPromotionEvent(
        eventName: active ? 'Promotion Activated' : 'Promotion Deactivated',
        promoId: id,
        promoCode: 'PROMO',
        promoName: 'Promotion',
        details: active ? 'promotion activated.' : 'promotion deactivated.',
        priority: 'normal',
        icon: active ? '✅' : '⏸️',
        color: active ? '0xFF10B981' : '0xFFEF4444',
      );
      debugPrint('[PromotionService] Successfully toggled active=$active at primary path: promotions/$id');
      return;
    } on FirebaseException catch (e) {
      debugPrint('[PromotionService] Primary toggle active failed (Code ${e.code}). Trying fallback path...');
    } catch (e) {
      debugPrint('[PromotionService] Primary toggle active error: $e');
    }

    try {
      await _fallbackDb.child(id).update(updateData).timeout(const Duration(seconds: 8));
      clearCache();
      debugPrint('[PromotionService] Successfully toggled active=$active at fallback path: company_settings/promotions/$id');
      return;
    } on FirebaseException catch (e) {
      debugPrint('[PromotionService] FIREBASE ERROR toggling active status:');
      debugPrint('  - Target DB Path: company_settings/promotions/$id');
      debugPrint('  - Current Authenticated UID: $uid');
      debugPrint('  - Current User Role: $role');
      debugPrint('  - Firebase Exception Code: ${e.code}');
      debugPrint('  - Firebase Exception Message: ${e.message}');
      throw Exception('Failed to toggle active status: ${e.message} (Code: ${e.code})');
    } catch (e) {
      debugPrint('[PromotionService] Error toggling active status: $e');
      rethrow;
    }
  }

  /// Validate if a promo code is unique
  Future<bool> isPromoCodeUnique(String code, {String? excludeId}) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return true;
    final promotions = await getPromotions();
    for (var p in promotions) {
      if (p.promoCode != null &&
          p.promoCode!.toUpperCase() == cleanCode &&
          p.id != excludeId) {
        return false;
      }
    }
    return true;
  }

  /// Check if a promotion is valid for a given booking context
  PromotionValidationResult validatePromotion(
    PromotionModel promo, {
    required double bookingAmount,
    String? vehicleId,
    String? vehicleType,
    String? vehicleBrand,
    DateTime? checkDate,
  }) {
    final now = checkDate ?? DateTime.now();

    // 1. Must be active flag
    if (!promo.active) {
      return PromotionValidationResult(
        isValid: false,
        message: 'This promotion is currently inactive.',
      );
    }

    // 2. Date check (expired / not started)
    if (now.isBefore(promo.startDate)) {
      return PromotionValidationResult(
        isValid: false,
        message: 'This promotion has not started yet.',
      );
    }
    if (now.isAfter(promo.endDate)) {
      return PromotionValidationResult(
        isValid: false,
        message: 'This promotion has expired.',
      );
    }

    // 3. Minimum booking amount check
    if (promo.minimumBookingAmount != null &&
        promo.minimumBookingAmount! > 0 &&
        bookingAmount < promo.minimumBookingAmount!) {
      return PromotionValidationResult(
        isValid: false,
        message:
            'Minimum booking amount of RM ${promo.minimumBookingAmount!.toStringAsFixed(2)} required for this promotion.',
      );
    }

    // 4. Vehicle type check
    if (promo.vehicleTypes.isNotEmpty && vehicleType != null) {
      final matches = promo.vehicleTypes.any(
        (t) => t.toLowerCase() == vehicleType.toLowerCase(),
      );
      if (!matches) {
        return PromotionValidationResult(
          isValid: false,
          message: 'This promotion is not valid for $vehicleType vehicles.',
        );
      }
    }

    // 5. Vehicle brand check
    if (promo.vehicleBrands.isNotEmpty && vehicleBrand != null) {
      final matches = promo.vehicleBrands.any(
        (b) => b.toLowerCase() == vehicleBrand.toLowerCase(),
      );
      if (!matches) {
        return PromotionValidationResult(
          isValid: false,
          message: 'This promotion is not valid for $vehicleBrand vehicles.',
        );
      }
    }

    // 6. Specific vehicle check
    if (promo.vehicleIds.isNotEmpty && vehicleId != null) {
      if (!promo.vehicleIds.contains(vehicleId)) {
        return PromotionValidationResult(
          isValid: false,
          message: 'This promotion is not valid for the selected vehicle.',
        );
      }
    }

    final discount = calculateDiscountAmount(promo, bookingAmount);

    return PromotionValidationResult(
      isValid: true,
      message: 'Promotion applied successfully!',
      promotion: promo,
      discountAmount: discount,
    );
  }

  /// Calculate exact discount amount for a promotion
  double calculateDiscountAmount(PromotionModel promo, double bookingAmount) {
    if (bookingAmount <= 0) return 0.0;
    double rawDiscount = 0.0;

    if (promo.discountType == 'percentage') {
      rawDiscount = bookingAmount * (promo.discountValue / 100.0);
    } else {
      rawDiscount = promo.discountValue;
    }

    if (promo.maximumDiscount != null && promo.maximumDiscount! > 0) {
      if (rawDiscount > promo.maximumDiscount!) {
        rawDiscount = promo.maximumDiscount!;
      }
    }

    if (rawDiscount > bookingAmount) {
      rawDiscount = bookingAmount;
    }

    return rawDiscount < 0 ? 0.0 : rawDiscount;
  }

  /// Find the best auto-apply promotion for a booking context
  Future<PromotionValidationResult?> findBestAutoApplyPromotion({
    required double bookingAmount,
    String? vehicleId,
    String? vehicleType,
    String? vehicleBrand,
  }) async {
    final promotions = await getPromotions();
    final now = DateTime.now();

    PromotionModel? bestPromo;
    double maxDiscount = 0.0;

    for (var promo in promotions) {
      if (!promo.autoApply) continue;
      final result = validatePromotion(
        promo,
        bookingAmount: bookingAmount,
        vehicleId: vehicleId,
        vehicleType: vehicleType,
        vehicleBrand: vehicleBrand,
        checkDate: now,
      );

      if (result.isValid && result.discountAmount > maxDiscount) {
        maxDiscount = result.discountAmount;
        bestPromo = promo;
      }
    }

    if (bestPromo != null) {
      return PromotionValidationResult(
        isValid: true,
        message: 'Auto-applied promotion: ${bestPromo.name}',
        promotion: bestPromo,
        discountAmount: maxDiscount,
      );
    }

    return null;
  }

  /// Validate promo code entered by user
  Future<PromotionValidationResult> validatePromoCode(
    String code, {
    required double bookingAmount,
    String? vehicleId,
    String? vehicleType,
    String? vehicleBrand,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return PromotionValidationResult(
        isValid: false,
        message: 'Please enter a promotion code.',
      );
    }

    final promotions = await getPromotions();
    PromotionModel? targetPromo;

    for (var p in promotions) {
      if (p.promoCode != null && p.promoCode!.toUpperCase() == cleanCode) {
        targetPromo = p;
        break;
      }
    }

    if (targetPromo == null) {
      return PromotionValidationResult(
        isValid: false,
        message: 'Invalid promo code.',
      );
    }

    return validatePromotion(
      targetPromo,
      bookingAmount: bookingAmount,
      vehicleId: vehicleId,
      vehicleType: vehicleType,
      vehicleBrand: vehicleBrand,
    );
  }

  /// Record a view event for promotion banner
  Future<void> recordView(String promoId) async {
    if (promoId.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final role = await UserRoleCache.getRole(user.uid);
      if (role.toLowerCase() != 'admin' && role.toLowerCase() != 'super_admin') {
        return; // Analytics transactions on /promotions restricted to Admin
      }
      final ref = _primaryDb.child(promoId).child('viewsCount');
      await ref.runTransaction((Object? current) {
        int val = (current is num) ? current.toInt() : 0;
        return Transaction.success(val + 1);
      });
    } catch (e) {
      debugPrint('[PromotionService] Error recording view analytics: $e');
    }
  }

  /// Record a click event when banner/promo card is tapped
  Future<void> recordClick(String promoId) async {
    if (promoId.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final role = await UserRoleCache.getRole(user.uid);
      if (role.toLowerCase() != 'admin' && role.toLowerCase() != 'super_admin') {
        return; // Analytics transactions on /promotions restricted to Admin
      }
      final ref = _primaryDb.child(promoId).child('clicksCount');
      await ref.runTransaction((Object? current) {
        int val = (current is num) ? current.toInt() : 0;
        return Transaction.success(val + 1);
      });
    } catch (e) {
      debugPrint('[PromotionService] Error recording click analytics: $e');
    }
  }

  /// Record a completed booking using promotion
  Future<void> recordBooking(String promoId, double revenue, double discountGiven) async {
    if (promoId.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final role = await UserRoleCache.getRole(user.uid);
      if (role.toLowerCase() != 'admin' && role.toLowerCase() != 'super_admin') {
        return; // Analytics transactions on /promotions restricted to Admin
      }
      final promoRef = _primaryDb.child(promoId);
      await promoRef.runTransaction((Object? currentData) {
        if (currentData == null || currentData is! Map) {
          return Transaction.abort();
        }
        final map = Map<String, dynamic>.from(currentData);
        final currentBookings = (map['bookingsCount'] ?? 0) is num ? (map['bookingsCount'] as num).toInt() : 0;
        final currentRev = (map['revenueGenerated'] ?? 0.0) is num ? (map['revenueGenerated'] as num).toDouble() : 0.0;
        final currentDiscount = (map['totalDiscountGiven'] ?? 0.0) is num ? (map['totalDiscountGiven'] as num).toDouble() : 0.0;

        map['bookingsCount'] = currentBookings + 1;
        map['revenueGenerated'] = currentRev + revenue;
        map['totalDiscountGiven'] = currentDiscount + discountGiven;
        return Transaction.success(map);
      });
      clearCache();
    } catch (e) {
      debugPrint('[PromotionService] Error recording booking analytics: $e');
    }
  }

  /// Upload banner image (converts to Base64 data URL)
  Future<String> uploadPromotionBanner(Uint8List bytes, String filename) async {
    try {
      final String base64Str = base64Encode(bytes);
      final String mimeType = filename.toLowerCase().endsWith('.png')
          ? 'image/png'
          : filename.toLowerCase().endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      return 'data:$mimeType;base64,$base64Str';
    } catch (e) {
      debugPrint('[PromotionService] Error uploading promotion banner image: $e');
      rethrow;
    }
  }

  /// Seed preset banners if no promotions exist
  Future<void> seedDefaultPromotions() async {
    final existing = await getPromotions();
    if (existing.isNotEmpty) return;

    final presets = getPresetBannerTemplates();
    for (var promo in presets) {
      try {
        await createPromotion(promo);
      } catch (e) {
        debugPrint('Error seeding preset promotion ${promo.name}: $e');
      }
    }
  }

  /// Get preset high-res banner templates for admin preview & quick selection
  List<PromotionModel> getPresetBannerTemplates() {
    final now = DateTime.now();
    final nextMonth = now.add(const Duration(days: 30));

    return [
      PromotionModel(
        id: 'preset_eid_sale',
        name: 'EID MEGA CELEBRATION SALE',
        subtitle: 'Enjoy 20% OFF all vehicle rentals across Malaysia!',
        description: 'Celebrate the festive season with family road trips! Get an automatic 20% discount on all sedan, MPV, and luxury fleet rentals.',
        discountType: 'percentage',
        discountValue: 20.0,
        startDate: now,
        endDate: nextMonth,
        active: true,
        bannerUrl: 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&q=80&w=1200',
        promoCode: 'EIDSALE',
        autoApply: true,
        minimumBookingAmount: 100.0,
        maximumDiscount: 150.0,
        termsAndConditions: [
          'Valid for all registered users.',
          'Applicable on rentals 2 days and above.',
          'Cannot be combined with other promo codes.'
        ],
        createdAt: now,
        updatedAt: now,
      ),
      PromotionModel(
        id: 'preset_weekend_deal',
        name: 'WEEKEND ESCAPE DEAL',
        subtitle: 'Flat RM 30.00 Instant Rebate on Weekend SUV Rentals!',
        description: 'Planning a weekend getaway? Take RM30 OFF any SUV or Crossover rental pick-ups from Friday to Sunday.',
        discountType: 'fixed',
        discountValue: 30.0,
        startDate: now,
        endDate: nextMonth,
        active: true,
        bannerUrl: 'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&q=80&w=1200',
        promoCode: 'WEEKEND30',
        applicableCategories: ['SUV'],
        autoApply: false,
        minimumBookingAmount: 150.0,
        termsAndConditions: [
          'Valid on SUV vehicle categories only.',
          'Requires promo code WEEKEND30 at checkout.'
        ],
        createdAt: now,
        updatedAt: now,
      ),
      PromotionModel(
        id: 'preset_welcome_offer',
        name: 'NEW USER WELCOME GIFT',
        subtitle: 'Get RM 50.00 OFF your very first luxury car booking!',
        description: 'Welcome to CARRENT! Enjoy a massive RM50 discount on your inaugural rental booking with us.',
        discountType: 'fixed',
        discountValue: 50.0,
        startDate: now,
        endDate: nextMonth,
        active: true,
        bannerUrl: 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&q=80&w=1200',
        promoCode: 'WELCOME50',
        autoApply: true,
        minimumBookingAmount: 200.0,
        termsAndConditions: [
          'Valid for first-time customer bookings.',
          'Minimum booking total of RM 200.00.'
        ],
        createdAt: now,
        updatedAt: now,
      ),
      PromotionModel(
        id: 'preset_long_trip',
        name: 'LONG TRIP ROAD EXPLORER',
        subtitle: 'Save 15% on long-distance road trips over 3 days!',
        description: 'Going on an extended holiday or business trip? Enjoy 15% off when renting for 3 days or longer.',
        discountType: 'percentage',
        discountValue: 15.0,
        startDate: now,
        endDate: nextMonth,
        active: true,
        bannerUrl: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=1200',
        promoCode: 'LONGTRIP15',
        autoApply: false,
        minimumBookingAmount: 250.0,
        maximumDiscount: 200.0,
        termsAndConditions: [
          'Minimum rental period 3 days.',
          'Maximum discount capped at RM 200.00.'
        ],
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
