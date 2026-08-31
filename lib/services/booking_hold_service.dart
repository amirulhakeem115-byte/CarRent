import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingHoldService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  static const String defaultBlockedMessage =
      'This vehicle is temporarily reserved by our staff. Please wait until the hold expires and try again.';
  static const String defaultBlockedMessageEn =
      'This vehicle is temporarily reserved by our staff. Please wait until the hold expires and try again.';
  static const String defaultBlockedMessageAr =
      'هذه السيارة محجوزة مؤقتًا من قبل موظفي الشركة. يرجى الانتظار حتى تنتهي مدة الحجز المؤقت ثم المحاولة مرة أخرى.';

  static String getHoldMessage(String timeFormatted, {bool isArabic = false}) {
    if (isArabic) {
      return 'هذه السيارة محجوزة مؤقتًا من قبل موظفي الشركة. يرجى الانتظار حتى تنتهي مدة الحجز المؤقت ثم المحاولة مرة أخرى. (الوقت المتبقي: $timeFormatted)';
    }
    return 'This vehicle is temporarily reserved by our staff. Please wait until the hold expires and try again. (Time remaining: $timeFormatted)';
  }

  /// Activate a 5-minute hold for a specific vehicle in Firebase Realtime Database
  Future<void> activateVehicleHold(
    String vehicleId, {
    Duration duration = const Duration(minutes: 5),
  }) async {
    final cleanVId = vehicleId.trim();
    if (cleanVId.isEmpty) return;

    try {
      final now = DateTime.now();
      final expiresAt = now.add(duration);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'staff';

      final payload = {
        'vehicleId': cleanVId,
        'heldBy': uid,
        'heldAt': now.toIso8601String(),
        'holdStartedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'holdExpiresAt': expiresAt.toIso8601String(),
        'status': 'active',
      };

      debugPrint(
        '[BookingHoldService] Creating 5-min vehicle hold for $cleanVId at /vehicleHolds/$cleanVId until ${expiresAt.toIso8601String()}',
      );
      await _db.child('vehicleHolds').child(cleanVId).set(payload);
    } catch (e, stack) {
      debugPrint('[BookingHoldService] Error activating vehicle hold: $e\n$stack');
      rethrow;
    }
  }

  /// Remove or deactivate active hold for a vehicle
  Future<void> clearVehicleHold(String vehicleId) async {
    final cleanVId = vehicleId.trim();
    if (cleanVId.isEmpty) return;

    try {
      debugPrint('[BookingHoldService] Clearing vehicle hold at /vehicleHolds/$cleanVId');
      await _db.child('vehicleHolds').child(cleanVId).remove();
    } catch (e) {
      debugPrint('[BookingHoldService] Error clearing vehicle hold for $cleanVId: $e');
    }
  }

  /// Activate global booking hold for all vehicles
  Future<void> activateHold({
    Duration duration = const Duration(minutes: 5),
  }) async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(duration);
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

      final payload = {
        'isActive': true,
        'startedAt': now.toIso8601String(),
        'holdStartedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'holdExpiresAt': expiresAt.toIso8601String(),
        'activatedBy': adminUid,
        'status': 'active',
      };

      debugPrint(
        '[BookingHoldService] Activating global booking hold until ${expiresAt.toIso8601String()}',
      );
      await _db.child('bookingHold').set(payload);
    } catch (e, stack) {
      debugPrint('[BookingHoldService] Error activating global booking hold: $e\n$stack');
      rethrow;
    }
  }

  /// Release global booking hold
  Future<void> releaseHold() async {
    try {
      debugPrint('[BookingHoldService] Releasing global booking hold');
      await _db.child('bookingHold').child('isActive').set(false);
      await _db.child('bookingHold').child('status').set('inactive');
    } catch (e) {
      debugPrint('[BookingHoldService] Error releasing global booking hold: $e');
      rethrow;
    }
  }

  /// Perform a direct live database check for an active hold on a vehicle
  Future<Map<String, dynamic>> checkVehicleHold(
    String vehicleId, {
    bool isArabic = false,
  }) async {
    final cleanVId = vehicleId.trim();

    // 1. Check specific vehicle hold at /vehicleHolds/$cleanVId
    if (cleanVId.isNotEmpty) {
      try {
        final snap = await _db.child('vehicleHolds').child(cleanVId).get();
        if (snap.exists && snap.value != null) {
          final data = Map<String, dynamic>.from(snap.value as Map);
          final String status = (data['status'] ?? '').toString().toLowerCase();
          final String expiresStr =
              (data['holdExpiresAt'] ?? data['expiresAt'] ?? '').toString();

          if (status == 'active' && expiresStr.isNotEmpty) {
            final expiresAt = DateTime.tryParse(expiresStr);
            if (expiresAt != null) {
              final now = DateTime.now();
              if (now.isBefore(expiresAt)) {
                final diff = expiresAt.difference(now).inSeconds;
                final mins = (diff ~/ 60).toString().padLeft(2, '0');
                final secs = (diff % 60).toString().padLeft(2, '0');
                final String timeRemainingFormatted = '$mins:$secs';

                return {
                  'isHoldActive': true,
                  'remainingSeconds': diff,
                  'formattedRemainingTime': timeRemainingFormatted,
                  'heldBy': data['heldBy'] ?? '',
                  'message': getHoldMessage(
                    timeRemainingFormatted,
                    isArabic: isArabic,
                  ),
                };
              } else {
                // Hold has expired: automatically delete from Firebase Realtime Database
                debugPrint(
                  '[BookingHoldService] Hold expired for vehicle $cleanVId. Removing node from Firebase.',
                );
                unawaited(_db.child('vehicleHolds').child(cleanVId).remove());
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[BookingHoldService] Error checking vehicle hold for $cleanVId: $e');
      }
    }

    // 2. Check global hold at /bookingHold
    final globalCheck = await checkBookingHold(isArabic: isArabic);
    if (globalCheck['isHoldActive'] == true) {
      return globalCheck;
    }

    return {
      'isHoldActive': false,
      'remainingSeconds': 0,
      'formattedRemainingTime': '00:00',
      'message': '',
    };
  }

  /// Check global booking hold status from Firebase
  Future<Map<String, dynamic>> checkBookingHold({bool isArabic = false}) async {
    try {
      final snapshot = await _db.child('bookingHold').get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final bool rawActive =
            data['isActive'] == true || data['status'] == 'active';
        final String? expiresStr =
            (data['holdExpiresAt'] ?? data['expiresAt'])?.toString();

        if (rawActive && expiresStr != null && expiresStr.isNotEmpty) {
          final expiresAt = DateTime.tryParse(expiresStr);
          if (expiresAt != null) {
            final now = DateTime.now();
            final difference = expiresAt.difference(now);

            if (difference.inSeconds > 0) {
              final remainingSeconds = difference.inSeconds;
              final minutes =
                  (remainingSeconds ~/ 60).toString().padLeft(2, '0');
              final seconds =
                  (remainingSeconds % 60).toString().padLeft(2, '0');
              final formattedTime = '$minutes:$seconds';

              return {
                'isHoldActive': true,
                'remainingSeconds': remainingSeconds,
                'formattedRemainingTime': formattedTime,
                'message': getHoldMessage(formattedTime, isArabic: isArabic),
              };
            } else {
              unawaited(_db.child('bookingHold').child('isActive').set(false));
              unawaited(_db.child('bookingHold').child('status').set('inactive'));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[BookingHoldService] Error checking global booking hold: $e');
    }

    return {
      'isHoldActive': false,
      'remainingSeconds': 0,
      'formattedRemainingTime': '00:00',
      'message': '',
    };
  }

  /// Realtime stream for global booking hold
  Stream<Map<String, dynamic>> getBookingHoldStream() {
    return _db.child('bookingHold').onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        try {
          return Map<String, dynamic>.from(event.snapshot.value as Map);
        } catch (_) {}
      }
      return {'isActive': false};
    });
  }

  /// Realtime stream for a specific vehicle hold
  Stream<Map<String, dynamic>> getVehicleHoldStream(String vehicleId) {
    final cleanVId = vehicleId.trim();
    if (cleanVId.isEmpty) return Stream.value({'isHoldActive': false});

    return _db.child('vehicleHolds').child(cleanVId).onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        try {
          final map = Map<String, dynamic>.from(event.snapshot.value as Map);
          return evaluateVehicleHoldData(map);
        } catch (_) {}
      }
      return {'isHoldActive': false};
    });
  }

  /// Synchronous evaluation for raw vehicle hold data
  static Map<String, dynamic> evaluateVehicleHoldData(
    Map<String, dynamic>? data,
  ) {
    if (data == null) {
      return {
        'isHoldActive': false,
        'remainingSeconds': 0,
        'formattedRemainingTime': '00:00',
      };
    }

    final String status = (data['status'] ?? '').toString().toLowerCase();
    final String expiresStr =
        (data['holdExpiresAt'] ?? data['expiresAt'] ?? '').toString();

    if (status == 'active' && expiresStr.isNotEmpty) {
      final expiresAt = DateTime.tryParse(expiresStr);
      if (expiresAt != null) {
        final now = DateTime.now();
        if (now.isBefore(expiresAt)) {
          final diff = expiresAt.difference(now).inSeconds;
          final mins = (diff ~/ 60).toString().padLeft(2, '0');
          final secs = (diff % 60).toString().padLeft(2, '0');

          return {
            'isHoldActive': true,
            'remainingSeconds': diff,
            'formattedRemainingTime': '$mins:$secs',
          };
        }
      }
    }

    return {
      'isHoldActive': false,
      'remainingSeconds': 0,
      'formattedRemainingTime': '00:00',
    };
  }

  /// Synchronous evaluation for raw global hold data
  static Map<String, dynamic> evaluateHoldData(Map<String, dynamic>? data) {
    if (data == null) {
      return {
        'isHoldActive': false,
        'remainingSeconds': 0,
        'formattedRemainingTime': '00:00',
      };
    }

    final bool rawActive =
        data['isActive'] == true || data['status'] == 'active';
    final String? expiresStr =
        (data['holdExpiresAt'] ?? data['expiresAt'])?.toString();

    if (rawActive && expiresStr != null && expiresStr.isNotEmpty) {
      final expiresAt = DateTime.tryParse(expiresStr);
      if (expiresAt != null) {
        final now = DateTime.now();
        final difference = expiresAt.difference(now);

        if (difference.inSeconds > 0) {
          final remainingSeconds = difference.inSeconds;
          final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
          final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

          return {
            'isHoldActive': true,
            'remainingSeconds': remainingSeconds,
            'formattedRemainingTime': '$minutes:$seconds',
          };
        }
      }
    }

    return {
      'isHoldActive': false,
      'remainingSeconds': 0,
      'formattedRemainingTime': '00:00',
    };
  }
}
