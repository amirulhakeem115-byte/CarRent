import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
import 'notification_service.dart';
import 'vehicle_service.dart';
import 'reward_service.dart';
import 'receipt_service.dart';
import 'company_settings_provider.dart';
import 'user_role_cache.dart';

class BookingService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('bookings');
  final VehicleService _vehicleService = VehicleService();
  final NotificationService _notificationService = NotificationService();

  static double calculateOverdueCharges(BookingModel booking, double pricePerDay, {DateTime? now}) {
    if (booking.isOpenRental || booking.returnDate == null) return 0.0;
    
    final statusLower = booking.status.toLowerCase();
    
    // Freeze and stop calculations immediately when Completed, Cancelled or Rejected, returning saved lateFees
    if (statusLower == 'completed' || statusLower == 'cancelled' || statusLower == 'rejected') {
      return booking.lateFees;
    }
    
    // Freeze and stop calculations immediately if the booking is marked as returned (e.g. Awaiting Final Payment / Inspection Completed)
    if (booking.isReturned) {
      return booking.lateFees;
    }
    
    // Only calculate overdue if booking status is Active, Ongoing, Return Requested, Awaiting Return, or Awaiting Final Payment
    final bool isStatusValid = statusLower == 'active' || 
                               statusLower == 'ongoing' || 
                               statusLower == 'return requested' || 
                               statusLower == 'awaiting return' ||
                               statusLower == 'awaiting final payment';
    if (!isStatusValid) return 0.0;
    
    final referenceTime = now ?? DateTime.now();
    if (referenceTime.isBefore(booking.returnDate!)) return 0.0;
    
    final diff = referenceTime.difference(booking.returnDate!);
    final totalHours = diff.inHours;
    if (totalHours <= 0) return 0.0;
    
    final days = totalHours ~/ 24;
    final remainingHours = totalHours % 24;
    
    return (days * pricePerDay) + (remainingHours * 20.0);
  }

  static Map<String, dynamic> getOverdueDetails(BookingModel booking, double pricePerDay, {DateTime? now}) {
    if (booking.isOpenRental || booking.returnDate == null) {
      return {
        'isOverdue': false,
        'days': 0,
        'hours': 0,
        'charges': 0.0,
      };
    }
    
    final statusLower = booking.status.toLowerCase();
    
    // If Completed, Cancelled, or Rejected, return frozen values
    if (statusLower == 'completed' || statusLower == 'cancelled' || statusLower == 'rejected') {
      return {
        'isOverdue': false,
        'days': 0,
        'hours': 0,
        'charges': booking.lateFees,
      };
    }
    
    // If returned but awaiting final payment, return frozen values
    if (booking.isReturned) {
      final returnTime = booking.actualReturnTimestamp ?? booking.updatedAt ?? DateTime.now();
      final isPast = returnTime.isAfter(booking.returnDate!);
      if (!isPast) {
        return {
          'isOverdue': false,
          'days': 0,
          'hours': 0,
          'charges': 0.0,
        };
      }
      final diff = returnTime.difference(booking.returnDate!);
      final totalHours = diff.inHours;
      final days = totalHours ~/ 24;
      final remainingHours = totalHours % 24;
      return {
        'isOverdue': false,
        'days': days,
        'hours': remainingHours,
        'charges': booking.lateFees,
      };
    }
    
    // Only calculate overdue if booking status is Active, Ongoing, Return Requested, Awaiting Return, or Awaiting Final Payment
    final bool isStatusValid = statusLower == 'active' || 
                               statusLower == 'ongoing' || 
                               statusLower == 'return requested' || 
                               statusLower == 'awaiting return' ||
                               statusLower == 'awaiting final payment';
    if (!isStatusValid) {
      return {
        'isOverdue': false,
        'days': 0,
        'hours': 0,
        'charges': 0.0,
      };
    }
    
    final referenceTime = now ?? DateTime.now();
    if (referenceTime.isBefore(booking.returnDate!)) {
      return {
        'isOverdue': false,
        'days': 0,
        'hours': 0,
        'charges': 0.0,
      };
    }
    
    final diff = referenceTime.difference(booking.returnDate!);
    final totalHours = diff.inHours;
    if (totalHours <= 0) {
      return {
        'isOverdue': false,
        'days': 0,
        'hours': 0,
        'charges': 0.0,
      };
    }
    
    final days = totalHours ~/ 24;
    final remainingHours = totalHours % 24;
    final charges = (days * pricePerDay) + (remainingHours * 20.0);
    
    return {
      'isOverdue': true,
      'days': days,
      'hours': remainingHours,
      'charges': charges,
    };
  }

  Future<void> createBooking(BookingModel booking) async {
    try {
      await _db.child(booking.id).set(booking.toMap()).timeout(const Duration(seconds: 10));
      
      final bool isConfirmed = booking.status == 'Confirmed' || booking.status == 'Confirmed';

      if (isConfirmed) {
        try {
          await _vehicleService.updateVehicleStatus(booking.vehicleId, 'Booked');
        } catch (vErr) {
          debugPrint('Error auto-marking vehicle as booked: $vErr');
        }
      }

      // Create booking notification for user
      await _notificationService.createNotification(
        userId: booking.userId,
        title: isConfirmed ? 'Booking Confirmed' : 'Booking Created',
        message: isConfirmed
            ? 'Your booking for ${booking.vehicleName} is confirmed! Get ready for your rental.'
            : 'Your booking for ${booking.vehicleName} has been submitted and is pending approval.',
        type: 'booking',
        icon: '📅',
        color: isConfirmed ? '0xFF10B981' : '0xFFF59E0B',
        relatedId: booking.id,
        actionRoute: 'Dashboard',
      );

      // Create new booking notification for admins
      await _notificationService.notifyAllAdmins(
        title: isConfirmed ? 'New Confirmed Booking' : 'New Booking Received',
        message: isConfirmed
            ? '${booking.userName} booked and confirmed ${booking.vehicleName}.'
            : '${booking.userName} booked ${booking.vehicleName}.',
        type: 'booking',
        icon: '📅',
        color: isConfirmed ? '0xFF10B981' : '0xFFF59E0B',
        relatedId: booking.id,
        actionRoute: 'Bookings',
      );
    } catch (e) {
      debugPrint('Error creating booking in Realtime Database: $e');
      rethrow;
    }
  }

  Future<List<BookingModel>> getBookings() async {
    List<BookingModel> bookings = [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return bookings;

    final currentRole = await UserRoleCache.getRole(currentUid);
    debugPrint('[BookingService] [getBookings] Accessing path: bookings');
    debugPrint('[BookingService] [getBookings] Current UID: $currentUid, Current Role: $currentRole');

    try {
      final DataSnapshot snapshot;
      if (currentRole == 'admin') {
        snapshot = await _db.get().timeout(const Duration(seconds: 10));
      } else {
        snapshot = await _db.orderByChild('userId').equalTo(currentUid).get().timeout(const Duration(seconds: 10));
      }

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          bookings.add(BookingModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }

      debugPrint('[BookingService] [getBookings] Bookings count loaded: ${bookings.length}');
    } catch (e) {
      debugPrint('[BookingService] [getBookings] Error getting bookings: $e');
      rethrow;
    }
    return bookings;
  }

  Stream<List<BookingModel>> getBookingsStream() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return Stream.value([]);
    }

    final controller = StreamController<List<BookingModel>>.broadcast();
    StreamSubscription? sub;

    UserRoleCache.getRole(currentUid).then((currentRole) {
      if (controller.isClosed) return;
      debugPrint('[BookingService] getBookingsStream — uid: $currentUid, role: $currentRole');

      final Query query =
          currentRole == 'admin' ? _db : _db.orderByChild('userId').equalTo(currentUid);

      sub = query.onValue.listen((event) {
        if (controller.isClosed) return;
        List<BookingModel> bookings = [];
        if (event.snapshot.exists) {
          final Map<dynamic, dynamic> data =
              event.snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            bookings.add(
                BookingModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
          });
        }
        controller.add(bookings);
      }, onError: (e) {
        debugPrint('[BookingService] getBookingsStream error: $e');
        if (!controller.isClosed) controller.add([]);
      });
    }).catchError((e) {
      debugPrint('[BookingService] getBookingsStream role fetch error: $e');
      if (!controller.isClosed) controller.add([]);
    });

    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }

  Future<List<BookingModel>> getUserBookings(String userId) async {
    List<BookingModel> bookings = [];
    try {
      final snapshot = await _db.orderByChild('userId').equalTo(userId).get().timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          bookings.add(BookingModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting user bookings: $e');
      rethrow;
    }

    // Sort bookings by date descending
    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings;
  }

  Future<void> updateBookingStatus(
    String bookingId,
    String status,
    String userId,
    String vehicleId,
    String vehicleName, {
    bool isAutomatic = false,
  }) async {
    try {
      final String statusLower = status.toLowerCase();

      final Map<String, dynamic> updates = {
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (statusLower == 'active') {
        updates['actualPickupTime'] = DateFormat('hh:mm a').format(DateTime.now());
        updates['actualPickupDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
        updates['actualPickupTimestamp'] = DateTime.now().toIso8601String();
      }

      if (statusLower == 'completed') {
        updates['isReturned'] = true;
        updates['actualReturnTime'] = DateFormat('hh:mm a').format(DateTime.now());
        updates['actualReturnDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
        updates['actualReturnTimestamp'] = DateTime.now().toIso8601String();
      }

      await _db.child(bookingId).update(updates).timeout(const Duration(seconds: 10));

      // Update vehicle status
      try {
        if (statusLower == 'ongoing' || statusLower == 'active' || statusLower == 'approved' || statusLower == 'confirmed' || statusLower == 'overdue') {
          if (statusLower == 'active') {
            await _vehicleService.updateVehicleStatus(vehicleId, 'Rented');
          } else {
            await _vehicleService.updateVehicleStatus(vehicleId, 'Booked');
          }
        } else if (statusLower == 'completed' || statusLower == 'cancelled' || statusLower == 'rejected' || statusLower == 'pending payment') {
          await _vehicleService.updateVehicleStatus(vehicleId, 'Available');
        }
      } catch (vehicleErr) {
        debugPrint('[BookingService] Warning: vehicle status update failed: $vehicleErr');
      }

      // Create notification
      String title = 'Booking Status Updated';
      String message = 'Your booking for $vehicleName is now $status.';
      String icon = '📅';
      String color = '0xFFF59E0B'; // default orange

      if (statusLower == 'pending') {
        title = 'Booking Pending';
        message = 'Your booking for $vehicleName is pending approval.';
        color = '0xFFF59E0B'; // orange
      } else if (statusLower == 'approved' || statusLower == 'confirmed') {
        title = 'Booking Confirmed!';
        message = 'Your booking for $vehicleName is confirmed. Get ready for your rental!';
        color = '0xFF10B981'; // green
      } else if (statusLower == 'rejected') {
        title = 'Booking Rejected';
        message = 'Your booking for $vehicleName has been rejected.';
        color = '0xFFEF4444'; // red
        try {
          await RewardPointsService().refundOrCancelPointsForBooking(bookingId, userId);
        } catch (rewardErr) {
          debugPrint('[BookingService] Warning: reward points reversion failed: $rewardErr');
        }
      } else if (statusLower == 'pending payment') {
        title = 'Booking Pending Payment';
        message = 'Your booking for $vehicleName requires payment upload.';
        color = '0xFFF59E0B'; // orange
      } else if (statusLower == 'ongoing' || statusLower == 'active') {
        title = 'Rental Started';
        message = 'Your rental for $vehicleName is now active. Drive safely!';
        color = '0xFF3B82F6'; // blue
      } else if (statusLower == 'completed') {
        title = 'Rental Completed';
        message = 'Your booking has been completed successfully.';
        color = '0xFF10B981'; // green
        
        // Also notify admins!
        await _notificationService.notifyAllAdmins(
          title: 'Booking Completed',
          message: 'Booking $bookingId has been marked as completed.',
          type: 'booking',
          icon: '📅',
          color: '0xFF10B981',
          relatedId: bookingId,
          actionRoute: 'Bookings',
        );

        // Award reward points automatically if Rewards System is enabled
        final rewardsEnabled = CompanySettingsProvider().getField('rewardsEnabled', defaultValue: true) as bool;
        if (rewardsEnabled) {
          try {
            await RewardPointsService().awardPointsForBooking(bookingId);
          } catch (rewardErr) {
            debugPrint('[BookingService] Warning: reward points award failed: $rewardErr');
          }
        }

        // Trigger automatic receipt check & storage creation
        try {
          await ReceiptService().triggerAutomaticReceiptCheck(bookingId);
        } catch (receiptErr) {
          debugPrint('[BookingService] Warning: receipt check failed: $receiptErr');
        }
      } else if (statusLower == 'cancelled') {
        title = 'Booking Cancelled';
        message = 'Your booking for $vehicleName has been cancelled.';
        color = '0xFFEF4444'; // red
        
        try {
          await RewardPointsService().refundOrCancelPointsForBooking(bookingId, userId);
        } catch (rewardErr) {
          debugPrint('[BookingService] Warning: reward points reversion failed: $rewardErr');
        }
        
        // Also notify admins!
        String customerName = 'Customer';
        try {
          final uSnap = await FirebaseDatabase.instance.ref().child('users').child(userId).child('fullName').get();
          if (uSnap.exists) {
            customerName = uSnap.value.toString();
          }
        } catch (_) {}
        
        await _notificationService.notifyAllAdmins(
          title: 'Booking Cancelled',
          message: '$customerName cancelled booking $bookingId for $vehicleName.',
          type: 'booking',
          icon: '📅',
          color: '0xFFEF4444',
          relatedId: bookingId,
          actionRoute: 'Bookings',
        );
      } else if (statusLower == 'overdue') {
        title = 'Rental Overdue ⚠️';
        message = 'Your rental has passed its return date. Please contact support or return the vehicle immediately.';
        color = '0xFFEF4444'; // red
        icon = '⚠️';

        // Notify admins!
        await _notificationService.notifyAllAdmins(
          title: 'Booking Overdue ⚠️',
          message: 'Booking $bookingId has become overdue.',
          type: 'booking',
          icon: '⚠️',
          color: '0xFFEF4444',
          relatedId: bookingId,
          actionRoute: 'Bookings',
        );
      }

      await _notificationService.createNotification(
        userId: userId,
        title: title,
        message: message,
        type: 'booking',
        icon: icon,
        color: color,
        relatedId: bookingId,
        actionRoute: 'Dashboard',
      );
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      rethrow;
    }
  }

  Future<bool> isVehicleAvailableForExtension(
    String vehicleId,
    DateTime currentReturn,
    DateTime newReturn,
    String excludeBookingId,
  ) async {
    try {
      final snapshot = await _db.get();
      if (!snapshot.exists || snapshot.value == null) return true;
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      for (final entry in data.entries) {
        final bId = entry.key.toString();
        if (bId == excludeBookingId) continue;
        final val = entry.value as Map;
        final status = (val['status'] ?? '').toString().toLowerCase();
        if (status == 'cancelled' || status == 'rejected' || status == 'completed') continue;
        final vId = (val['vehicleId'] ?? '').toString();
        if (vId != vehicleId) continue;
        final bStart = DateTime.parse(val['pickUpDate']);
        final returnDateStr = val['returnDate'];
        final bEnd = returnDateStr != null
            ? DateTime.parse(returnDateStr)
            : DateTime.now().add(const Duration(days: 365));
        if (currentReturn.isBefore(bEnd) && newReturn.isAfter(bStart)) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error checking vehicle availability for extension: $e');
      return false;
    }
  }

  Future<void> requestExtension(
    String bookingId,
    DateTime newReturn,
    double cost, {
    String status = 'pending',
    String paymentStatus = 'unpaid',
  }) async {
    try {
      final updates = {
        'extensionRequest': {
          'newReturnDate': newReturn.toIso8601String(),
          'additionalCost': cost,
          'status': status,
          'paymentStatus': paymentStatus,
          'requestedAt': DateTime.now().toIso8601String(),
        }
      };
      await _db.child(bookingId).update(updates).timeout(const Duration(seconds: 10));

      // Notify Admin
      await _notificationService.notifyAllAdmins(
        title: "Extension Request ⚠️",
        message: "Customer requested extension for Booking #$bookingId.",
        type: 'extension_request',
        icon: '⚠️',
        color: '0xFFF59E0B',
        relatedId: bookingId,
        actionRoute: 'Bookings',
      );
    } catch (e) {
      debugPrint('Error requesting extension: $e');
      rethrow;
    }
  }

  Future<void> approveExtension(String bookingId) async {
    try {
      final snap = await _db.child(bookingId).get();
      if (!snap.exists || snap.value == null) throw 'Booking not found';
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final booking = BookingModel.fromMap(bookingId, data);
      
      final ext = booking.extensionRequest;
      if (ext == null) throw 'No extension request found';

      final newReturn = DateTime.parse(ext['newReturnDate']);
      final addCost = (ext['additionalCost'] ?? 0.0).toDouble();

      final Map<String, dynamic> updates = {
        'returnDate': newReturn.toIso8601String(),
        'totalPrice': booking.totalPrice + addCost,
        'extensionRequest/status': 'approved',
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _db.child(bookingId).update(updates).timeout(const Duration(seconds: 10));

      // Notify Customer
      await _notificationService.createNotification(
        userId: booking.userId,
        title: "Extension Approved 🎉",
        message: "Extension approved until ${DateFormat('dd MMM yyyy hh:mm a').format(newReturn)}.",
        type: 'extension_approved',
        icon: '🎉',
        color: '0xFF10B981',
        relatedId: bookingId,
        actionRoute: 'Dashboard',
      );
    } catch (e) {
      debugPrint('Error approving extension: $e');
      rethrow;
    }
  }

  Future<void> rejectExtension(String bookingId) async {
    try {
      final snap = await _db.child(bookingId).get();
      if (!snap.exists || snap.value == null) throw 'Booking not found';
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final booking = BookingModel.fromMap(bookingId, data);

      await _db.child(bookingId).update({
        'extensionRequest/status': 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));

      // Notify Customer
      await _notificationService.createNotification(
        userId: booking.userId,
        title: "Extension Rejected ❌",
        message: "Your extension request for ${booking.vehicleName} was rejected.",
        type: 'extension_rejected',
        icon: '❌',
        color: '0xFFEF4444',
        relatedId: bookingId,
        actionRoute: 'Dashboard',
      );
    } catch (e) {
      debugPrint('Error rejecting extension: $e');
      rethrow;
    }
  }

  Future<void> requestReturn(String bookingId) async {
    try {
      final snap = await _db.child(bookingId).get();
      if (!snap.exists || snap.value == null) throw 'Booking not found';
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final booking = BookingModel.fromMap(bookingId, data);

      await _db.child(bookingId).update({
        'status': 'Return Requested',
        'updatedAt': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));

      // Notify Admin
      await _notificationService.notifyAllAdmins(
        title: "Return Request 🔔",
        message: "${booking.userName} wants to return vehicle ${booking.vehicleName}.",
        type: 'return_request',
        icon: '🔔',
        color: '0xFF3B82F6',
        relatedId: bookingId,
        actionRoute: 'Bookings',
      );
    } catch (e) {
      debugPrint('Error requesting return: $e');
      rethrow;
    }
  }

  Future<void> completeReturn(String bookingId, Map<String, dynamic> inspection) async {
    try {
      final snap = await _db.child(bookingId).get();
      if (!snap.exists || snap.value == null) throw 'Booking not found';
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final booking = BookingModel.fromMap(bookingId, data);

      // Fetch vehicle price per day
      double pricePerDay = 100.0;
      try {
        final vSnap = await FirebaseDatabase.instance.ref().child('vehicles').child(booking.vehicleId).get();
        if (vSnap.exists) {
          pricePerDay = ((vSnap.value as Map)['pricePerDay'] ?? 100.0).toDouble();
        }
      } catch (_) {}

      // Calculate base cost and overdue charges
      double baseCost = booking.totalPrice;
      final now = DateTime.now();

      if (booking.isOpenRental) {
        final pickup = booking.actualPickupTimestamp ?? booking.pickUpDate;
        final diff = now.difference(pickup);
        final hours = diff.inHours;
        final d = (hours / 24.0).ceil();
        final days = d <= 0 ? 1 : d;
        baseCost = days * pricePerDay;
      }

      // Calculate overdue charges using the precise rules
      final lateFees = BookingService.calculateOverdueCharges(booking, pricePerDay, now: now);

      final cleaningFee = (inspection['cleaningFee'] ?? 0.0).toDouble();
      final damageFee = (inspection['damageFee'] ?? 0.0).toDouble();
      final extraCharges = (inspection['extraCharges'] ?? 0.0).toDouble();
      final finalAmount = baseCost - booking.discountAmount + lateFees + cleaningFee + damageFee + extraCharges;

      final Map<String, dynamic> updates = {
        'status': 'Awaiting Final Payment',
        'isReturned': true,
        'actualReturnTime': DateFormat('hh:mm a').format(now),
        'actualReturnDate': DateFormat('yyyy-MM-dd').format(now),
        'actualReturnTimestamp': now.toIso8601String(),
        'totalPrice': baseCost - booking.discountAmount,
        'lateFees': lateFees,
        'finalAmount': finalAmount,
        'returnInspection': inspection,
        'updatedAt': now.toIso8601String(),
      };

      await _db.child(bookingId).update(updates).timeout(const Duration(seconds: 10));

      // Update vehicle status to 'Inspection Completed'
      try {
        await _vehicleService.updateVehicleStatus(booking.vehicleId, 'Inspection Completed');
      } catch (e) {
        debugPrint('Error updating vehicle status to Inspection Completed: $e');
      }

      // Create a pending final payment record
      final Map<String, dynamic> paymentData = {
        'bookingId': bookingId,
        'userId': booking.userId,
        'customerUid': booking.userId,
        'amount': finalAmount,
        'depositAmount': 0.0,
        'balanceAmount': finalAmount,
        'paymentMethod': 'FPX',
        'status': 'Pending Verification',
        'paymentStatus': 'Pending Verification',
        'paymentDate': now.toIso8601String(),
        'rewardPointsAwarded': false,
      };
      
      final newPaymentRef = FirebaseDatabase.instance.ref().child('payments').push();
      paymentData['id'] = newPaymentRef.key!;
      await newPaymentRef.set(paymentData).timeout(const Duration(seconds: 10));

      // -------------------------------------------------------------
      // CUSTOMER NOTIFICATIONS
      // -------------------------------------------------------------
      // 1. Vehicle Returned
      await _notificationService.createNotification(
        userId: booking.userId,
        title: "Vehicle Returned 🚗",
        message: "Your returned vehicle ${booking.vehicleName} has been received and inspected.",
        type: 'booking',
        icon: '🚗',
        color: '0xFF3B82F6',
        relatedId: bookingId,
        actionRoute: 'Dashboard',
      );

      // 2. Final Invoice Ready
      await _notificationService.createNotification(
        userId: booking.userId,
        title: "Final Invoice Ready 📄",
        message: "The final invoice for booking #${bookingId.substring(0, 5).toUpperCase()} is ready.",
        type: 'payment',
        icon: '📄',
        color: '0xFF10B981',
        relatedId: newPaymentRef.key!,
        actionRoute: 'Dashboard',
      );

      // 3. Overdue Charges Updated
      if (lateFees > 0) {
        await _notificationService.createNotification(
          userId: booking.userId,
          title: "Overdue Charges Updated ⚠️",
          message: "An overdue fee of RM ${lateFees.toStringAsFixed(2)} has been charged.",
          type: 'booking',
          icon: '⚠️',
          color: '0xFFEF4444',
          relatedId: bookingId,
          actionRoute: 'Dashboard',
        );
      }

      // 4. Payment Required
      await _notificationService.createNotification(
        userId: booking.userId,
        title: "Payment Required 💳",
        message: "An outstanding balance of RM ${finalAmount.toStringAsFixed(2)} requires payment clearance.",
        type: 'payment',
        icon: '💳',
        color: '0xFFEF4444',
        relatedId: newPaymentRef.key!,
        actionRoute: 'Dashboard',
      );

      // -------------------------------------------------------------
      // ADMIN NOTIFICATIONS
      // -------------------------------------------------------------
      // 1. Customer Returned Vehicle
      await _notificationService.notifyAllAdmins(
        title: "Vehicle Returned 🚗",
        message: "Customer ${booking.userName} has returned vehicle ${booking.vehicleName}.",
        type: 'return_request',
        icon: '🚗',
        color: '0xFF3B82F6',
        relatedId: bookingId,
        actionRoute: 'Bookings',
      );

      // 2. Invoice Generated
      await _notificationService.notifyAllAdmins(
        title: "Invoice Generated 📄",
        message: "Invoice generated for #${bookingId.substring(0, 5).toUpperCase()}. Amount: RM ${finalAmount.toStringAsFixed(2)}.",
        type: 'payment',
        icon: '📄',
        color: '0xFF10B981',
        relatedId: newPaymentRef.key!,
        actionRoute: 'Payments',
      );

      // 3. Payment Pending
      await _notificationService.notifyAllAdmins(
        title: "Final Payment Pending 🕐",
        message: "Final payment clearance pending for booking #${bookingId.substring(0, 5).toUpperCase()}.",
        type: 'payment',
        icon: '🕐',
        color: '0xFFF59E0B',
        relatedId: newPaymentRef.key!,
        actionRoute: 'Payments',
      );

    } catch (e) {
      debugPrint('Error completing return: $e');
      rethrow;
    }
  }

  Future<void> cancelBooking(String bookingId, String userId, String vehicleId, String vehicleName) async {
    await updateBookingStatus(bookingId, 'cancelled', userId, vehicleId, vehicleName);
  }
}

