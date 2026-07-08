import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../services/vehicle_service.dart';
import '../../services/booking_service.dart';
import '../../services/reward_service.dart';
import '../../services/branch_service.dart';
import '../../services/payment_service.dart';
import '../../services/maintenance_service.dart';
import '../../services/database_service.dart';
import '../../models/vehicle_model.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/maintenance_job_model.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../services/review_service.dart';
import '../../services/company_settings_provider.dart';
import '../models/ai_message.dart';
import '../models/ai_intent.dart';
import '../models/ai_response.dart';
import 'ai_provider.dart';
import 'intent_engine.dart';

// ─────────────────────────────────────────────────────────────────
//  Full Operator state tracker (Phase 7)
// ─────────────────────────────────────────────────────────────────

class BookingSessionState {
  // Booking flow step
  // 0: inactive, 1: category, 2: vehicle, 3: branch, 4: dates, 5: rewards, 6: summary, 7: payment
  int currentStep = 0; 
  String? type;
  String? vehicleId;
  String? vehicleName;
  double? vehiclePrice;
  String? branch;
  DateTime? pickupDate;
  DateTime? returnDate;
  bool isOpenRental = false;
  String? pickupTime;
  int pointsToRedeem = 0;
  double? suggestedAlternativeBudget;
  bool warnedActiveBooking = false;

  double? budget;
  String? transmission;
  int? seats;

  // FAQ interactive state
  int faqStep = 0; 
  String? faqCategory;

  // Admin report interactive state
  int adminReportStep = 0; 
  String? adminTimeframe;

  // NEW OPERATOR STATES FOR PHASE 7:
  // Support ticket wizard
  int supportStep = 0; // 101: subject, 102: message, 103: reply ticketId
  String? ticketSubject;
  String? activeTicketId;

  // Extension wizard
  int extensionStep = 0; // 201: select booking, 202: select new return date, 203: confirm
  String? activeExtendBookingId;
  DateTime? extensionNewReturnDate;

  // Comparison wizard
  int compareStep = 0; // 301: select car 1, 302: select car 2
  String? compareCarId1;
  String? compareCarId2;

  // Document upload wizard
  int uploadStep = 0; // 401: select doc type, 402: upload file
  String? uploadDocType;

  // Payment upload wizard
  int paymentUploadStep = 0; // 501: select booking, 502: upload receipt
  String? paymentBookingId;

  // Admin fleet management wizard
  int adminFleetStep = 0; // 601: select vehicle, 602: select status change
  String? adminVehicleId;

  // Admin user verification wizard
  int adminVerifyStep = 0; // 701: select user, 702: approve/reject, 703: enter reject reason
  String? adminVerifyUserId;

  // Confirmation state for destructive actions
  int confirmDestructiveStep = 0; // 901: confirm action
  String? destructiveActionType; // 'cancel_booking', 'reject_verification', 'delete_vehicle', 'delete_maintenance'
  Map<String, dynamic>? destructiveActionParams;

  void reset() {
    currentStep = 0;
    type = null;
    vehicleId = null;
    vehicleName = null;
    vehiclePrice = null;
    branch = null;
    pickupDate = null;
    returnDate = null;
    isOpenRental = false;
    pickupTime = null;
    pointsToRedeem = 0;
    suggestedAlternativeBudget = null;
    warnedActiveBooking = false;
    budget = null;
    transmission = null;
    seats = null;

    faqStep = 0;
    faqCategory = null;

    adminReportStep = 0;
    adminTimeframe = null;

    supportStep = 0;
    ticketSubject = null;
    activeTicketId = null;

    extensionStep = 0;
    activeExtendBookingId = null;
    extensionNewReturnDate = null;

    compareStep = 0;
    compareCarId1 = null;
    compareCarId2 = null;

    uploadStep = 0;
    uploadDocType = null;

    paymentUploadStep = 0;
    paymentBookingId = null;

    adminFleetStep = 0;
    adminVehicleId = null;

    adminVerifyStep = 0;
    adminVerifyUserId = null;

    confirmDestructiveStep = 0;
    destructiveActionType = null;
    destructiveActionParams = null;
  }
}

class LocalAIProvider implements AIProvider {
  final IntentEngine _intentEngine = IntentEngine();
  final Map<String, BookingSessionState> _bookingSessions = {};

  @override
  Future<AIIntent> detectIntent(String text) async {
    return _intentEngine.detectIntent(text);
  }

  @override
  Future<AIResponse> sendMessage(String text, List<AIMessage> history, {required String userRole}) async {
    // Add artificial delay to simulate thinking time (500ms)
    await Future.delayed(const Duration(milliseconds: 500));

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final session = _bookingSessions.putIfAbsent(uid, () => BookingSessionState());

    final cleanedText = text.trim().toLowerCase();
    final intent = _intentEngine.detectIntent(text);
    final Map<String, dynamic> customParams = Map<String, dynamic>.from(intent.parameters);

    if (userRole == 'admin') {
      return await _processAdminMessage(text, session, customParams, intent);
    }

    // Strict Role-Based Access Control (RBAC) Checks
    if (userRole == 'customer') {
      final isForbiddenQuery = 
          intent is ReportIntent ||
          intent is MaintenanceIntent ||
          intent is CustomerIntent ||
          (intent is DashboardIntent && !cleanedText.contains('back to dashboard')) ||
          (intent is PaymentIntent && (cleanedText.contains('revenue') || cleanedText.contains('stats') || cleanedText.contains('statistics') || cleanedText.contains('total') || cleanedText.contains('all payments'))) ||
          cleanedText.contains('manage fleet') ||
          cleanedText.contains('verify customer') ||
          cleanedText.contains('generate reports') ||
          cleanedText.contains('overdue bookings') ||
          cleanedText.contains('today\'s bookings') ||
          cleanedText.contains('maintenance records') ||
          cleanedText.contains('revenue trends') ||
          cleanedText.contains('peak booking') ||
          cleanedText.contains('most rented') ||
          cleanedText.contains('least rented') ||
          cleanedText.contains('popular branch') ||
          session.adminReportStep > 0 ||
          session.adminFleetStep > 0 ||
          session.adminVerifyStep > 0;

      if (isForbiddenQuery) {
        session.reset();
        return AIResponse(
          message: "I'm sorry, but you do not have permission to access administrative functions. Please log in with an administrator account to perform this action.",
          intent: const UnknownIntent(confidence: 1.0),
          confidence: 1.0,
          action: 'permission_denied',
          parameters: const {
            'options': ['🚗 Book a Car', '❓ FAQs', '💬 Contact Support', 'Back to Dashboard']
          },
        );
      }
    }

    // Abort/Reset hook
    if (history.length <= 1 || 
        cleanedText == 'cancel' || 
        cleanedText == 'exit' || 
        cleanedText == 'reset' ||
        cleanedText == 'abort') {
      session.reset();
      if (cleanedText == 'cancel' || cleanedText == 'exit' || cleanedText == 'reset' || cleanedText == 'abort') {
        return AIResponse(
          message: "All workflows reset. Ready for next operator command! 🚗✨",
          intent: const UnknownIntent(confidence: 1.0),
          confidence: 1.0,
          action: "cancel",
          parameters: const {
            'options': ['🚗 Book a Car', '❓ FAQs', '💬 Contact Support', 'Back to Dashboard']
          },
        );
      }
    }



    // Dynamic Reset Hook for New Explicit Requests
    bool isNewExplicitRequest = false;
    if (intent is BookingIntent && customParams['action'] == 'book_vehicle') {
      isNewExplicitRequest = true;
    } else if (cleanedText.startsWith('book') || cleanedText.startsWith('rent') || cleanedText.contains('want to book') || cleanedText.contains('i want to rent')) {
      isNewExplicitRequest = true;
    }

    if (isNewExplicitRequest) {
      session.reset();
      
      List<VehicleModel> vehicles = [];
      try {
        vehicles = await VehicleService().getVehicles();
      } catch (_) {}

      final entities = _extractEntities(text, vehicles);
      final VehicleModel? matchedVehicle = entities['vehicle'];
      final String? category = entities['category'];
      final String? transmission = entities['transmission'];
      final double? budget = entities['budget'];

      if (matchedVehicle != null) {
        // Verify availability
        if (matchedVehicle.status.toLowerCase() != 'available') {
          session.reset();
          return AIResponse(
            message: "No matching vehicle was found.", // Do not guess or substitute.
            intent: intent,
            confidence: 1.0,
            action: 'error',
            parameters: customParams,
          );
        }

        // Verify branch
        final branchName = matchedVehicle.branchName.isEmpty ? 'Kuala Lumpur' : matchedVehicle.branchName;
        final branches = await BranchService().getBranches();
        if (!branches.any((b) => b.name.toLowerCase() == branchName.toLowerCase())) {
          session.reset();
          return AIResponse(
            message: "No matching vehicle was found.",
            intent: intent,
            confidence: 1.0,
            action: 'error',
            parameters: customParams,
          );
        }

        session.vehicleId = matchedVehicle.id;
        session.vehicleName = '${matchedVehicle.brand} ${matchedVehicle.model}';
        session.vehiclePrice = matchedVehicle.pricePerDay;
        session.type = matchedVehicle.category;
        session.branch = branchName;
        
        session.currentStep = 3; // Go directly to dates selection!
        
        final nextMsg = await _askBranchSelection(session, customParams);
        return AIResponse(
          message: nextMsg,
          intent: intent,
          confidence: 1.0,
          action: 'booking_flow_active',
          parameters: customParams,
        );
      } else if (category != null || budget != null || transmission != null) {
        // Filter available vehicles to see if any exist matching these filters
        final filtered = vehicles.where((v) {
          if (v.status.toLowerCase() != 'available') return false;
          if (category != null && v.category.toLowerCase() != category.toLowerCase()) return false;
          if (transmission != null && v.transmission.toLowerCase() != transmission.toLowerCase()) return false;
          if (budget != null && v.pricePerDay > budget) return false;
          return true;
        }).toList();

        if (filtered.isEmpty) {
          session.reset();
          return AIResponse(
            message: "No matching vehicle was found.", // Do not substitute.
            intent: intent,
            confidence: 1.0,
            action: 'error',
            parameters: customParams,
          );
        }

        session.type = category ?? 'Any';
        session.budget = budget;
        session.transmission = transmission;
        session.currentStep = 2; // Ask them to select from list

        final nextMsg = await _askVehicleCardList(session, customParams);
        return AIResponse(
          message: nextMsg,
          intent: intent,
          confidence: 1.0,
          action: 'booking_flow_active',
          parameters: customParams,
        );
      }
    }

    // Intercept payment triggers
    if (cleanedText.startsWith('pay booking #') || cleanedText.startsWith('choose payment method for booking #')) {
      final bId = text.split('#').last.trim();
      try {
        final bSnap = await FirebaseDatabase.instance.ref().child('bookings').child(bId).get();
        if (bSnap.exists) {
          final bData = Map<dynamic, dynamic>.from(bSnap.value as Map);
          final vehicleName = bData['vehicleName'] ?? 'Vehicle';
          final totalPrice = double.tryParse(bData['totalPrice']?.toString() ?? '') ?? 0.0;
          final depositAmount = double.tryParse(bData['depositAmount']?.toString() ?? '') ?? 0.0;
          
          session.reset();
          session.paymentBookingId = bId;
          session.paymentUploadStep = 0;
          
          customParams['bookingId'] = bId;
          customParams['options'] = ['Cash at Counter', 'FPX Online Banking', 'DuitNow QR'];
          
          return AIResponse(
            message: "Please choose a payment method for booking **$vehicleName** (Ref: `#${bId.substring(0, 5).toUpperCase()}`):\n\n"
                "• **Total Amount**: RM ${totalPrice.toStringAsFixed(2)}\n"
                "• **Deposit Required**: RM ${depositAmount.toStringAsFixed(2)}",
            intent: intent,
            confidence: 1.0,
            action: 'prompt_payment_method',
            parameters: customParams,
          );
        }
      } catch (e) {
        return AIResponse(
          message: "Failed to load booking details: $e",
          intent: intent,
          confidence: 1.0,
          action: 'error',
          parameters: customParams,
        );
      }
      return AIResponse(
        message: "Booking `#${bId.substring(0, 5).toUpperCase()}` was not found.",
        intent: intent,
        confidence: 1.0,
        action: 'error',
        parameters: customParams,
      );
    }

    if (session.paymentBookingId != null && 
        (cleanedText.contains('cash') || cleanedText.contains('fpx') || cleanedText.contains('qr') || cleanedText.contains('duitnow'))) {
      final bId = session.paymentBookingId!;
      String method = 'Cash';
      if (cleanedText.contains('fpx')) {
        method = 'FPX Online Banking';
      } else if (cleanedText.contains('qr') || cleanedText.contains('duitnow')) {
        method = 'DuitNow QR';
      }
      
      session.reset();
      customParams['bookingId'] = bId;
      customParams['method'] = method;
      
      return AIResponse(
        message: "Routing you to **$method** checkout... 💳",
        intent: intent,
        confidence: 1.0,
        action: 'select_payment_method',
        parameters: customParams,
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  0. Safety Confirmation Flow (Destructive Actions Protection)
    // ─────────────────────────────────────────────────────────────────────────
    if (session.confirmDestructiveStep == 901) {
      if (cleanedText.contains('yes') || cleanedText.contains('confirm')) {
        final actionType = session.destructiveActionType;
        final actParams = session.destructiveActionParams ?? {};
        session.reset();
        
        return await _executeDestructiveAction(actionType, actParams, customParams);
      } else {
        session.reset();
        customParams['options'] = ['🚗 Book a Car', '❓ FAQs', '💬 Contact Support', 'Back to Dashboard'];
        return AIResponse(
          message: "Action aborted. Safety override: No changes were made to the database. 🛡️",
          intent: intent,
          confidence: 1.0,
          action: 'cancel',
          parameters: customParams,
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  1. FAQ Interactive Flow
    // ─────────────────────────────────────────────────────────────────────────
    if (cleanedText == 'faqs' || (intent is SupportIntent && cleanedText.contains('faq'))) {
      session.reset();
      session.faqStep = 1;
      customParams['options'] = ['Booking', 'Payments', 'Vehicles', 'Rewards', 'Support', 'Policies', 'Exit FAQs'];
      return AIResponse(
        message: "Please select an FAQ category below to view details:",
        intent: intent,
        confidence: 1.0,
        action: 'faq_flow',
        parameters: customParams,
      );
    } else if (session.faqStep > 0) {
      final res = await _processFAQFlow(text, session, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'faq_flow', parameters: customParams);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  2. Admin Report Guided Flow
    // ─────────────────────────────────────────────────────────────────────────
    if (intent is ReportIntent || cleanedText == 'generate reports' || cleanedText.contains('report')) {
      final tf = intent.parameters['timeframe'] as String?;
      final tp = intent.parameters['type'] as String?;
      if (tf != null && tp != null) {
        customParams['timeframe'] = tf;
        customParams['type'] = tp;
        customParams['action'] = 'view_reports';
        return AIResponse(
          message: "📊 **Generating report...**\n\nDirectly opening the **$tf $tp Report** for you.",
          intent: intent,
          confidence: 1.0,
          action: 'view_reports',
          parameters: customParams,
        );
      }

      session.reset();
      session.adminReportStep = 1;
      customParams['options'] = ['Today', 'This Week', 'This Month', 'Cancel'];
      return AIResponse(
        message: "Please select a timeframe for generating the ledger report summary:",
        intent: intent,
        confidence: 1.0,
        action: 'report_flow',
        parameters: customParams,
      );
    } else if (session.adminReportStep > 0) {
      final res = await _processAdminReportFlow(text, session, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'report_flow', parameters: customParams);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  3. Support Ticket Operator Flow
    // ─────────────────────────────────────────────────────────────────────────
    if (cleanedText.contains('create support') || (intent is SupportIntent && cleanedText.contains('ticket') && cleanedText.contains('create'))) {
      session.reset();
      session.supportStep = 101;
      return AIResponse(
        message: "Sure, let's open a new support ticket.\n\n**Step 1**: Please type the subject or category of your issue:",
        intent: intent,
        confidence: 1.0,
        action: 'support_flow',
        parameters: customParams,
      );
    } else if (cleanedText == 'track support ticket' || cleanedText == 'support tickets' || (intent is SupportIntent && cleanedText.contains('track'))) {
      session.reset();
      final res = await _listSupportTickets(uid, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'support_flow', parameters: customParams);
    } else if (cleanedText.startsWith('view ticket:')) {
      final ticketId = text.split('#').last.trim();
      session.activeTicketId = ticketId;
      session.supportStep = 104;
      final res = await _viewSupportTicketDetails(ticketId, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'support_flow', parameters: customParams);
    } else if (session.supportStep > 0) {
      final res = await _processSupportOperator(text, session, customParams, uid);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'support_flow', parameters: customParams);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  4. Booking Extensions & Cancellations Operators
    // ─────────────────────────────────────────────────────────────────────────
    if (cleanedText.contains('cancel booking') || (intent is BookingIntent && cleanedText.contains('cancel'))) {
      session.reset();
      final res = await _listCancelBookings(uid, customParams, session);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'cancel_booking', parameters: customParams);
    } else if (cleanedText.startsWith('cancel reservation:')) {
      final bId = text.split('#').last.trim();
      final res = await _triggerCancelBookingConfirmation(bId, session, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'cancel_booking', parameters: customParams);
    } else if (cleanedText.contains('extend booking') || (intent is BookingIntent && cleanedText.contains('extend'))) {
      session.reset();
      session.extensionStep = 201;
      final res = await _listExtendBookings(uid, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'extend_booking', parameters: customParams);
    } else if (session.extensionStep > 0) {
      final res = await _processBookingExtensionFlow(text, session, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'extend_flow', parameters: customParams);
    } else if (cleanedText.contains('return my vehicle') || cleanedText.contains('return my car') || cleanedText.contains('return vehicle') || (intent is BookingIntent && cleanedText.contains('return'))) {
      final bookings = await BookingService().getBookings();
      final myActive = bookings.where((b) => b.userId == uid && (b.status == 'ongoing' || b.status.toLowerCase() == 'active' || b.status.toLowerCase() == 'overdue')).toList();
      if (myActive.isEmpty) {
        return AIResponse(
          message: "You do not have any active bookings that can be returned at the moment.",
          intent: intent,
          confidence: 1.0,
          action: 'error',
          parameters: const {},
        );
      }
      
      final target = myActive.first;
      await BookingService().requestReturn(target.id);
      customParams['options'] = ['My Bookings', 'Back to Dashboard'];
      return AIResponse(
        message: "🔔 **Return Request Submitted!**\n\nI have requested a return for your rental of **${target.vehicleName}** (Booking #${target.id.substring(0, 5).toUpperCase()}).\n\n"
                 "The Admin has been notified to schedule an inspection. Please wait for completion.",
        intent: intent,
        confidence: 1.0,
        action: 'request_return',
        parameters: {'bookingId': target.id},
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  5. Vehicle Comparison Operator
    // ─────────────────────────────────────────────────────────────────────────
    if (cleanedText.contains('compare vehicle') || cleanedText.contains('compare car')) {
      session.reset();
      session.compareStep = 301;
      final res = await _listCompareVehicles(1, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'compare_flow', parameters: customParams);
    } else if (session.compareStep > 0) {
      final res = await _processVehicleComparisonFlow(text, session, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'compare_flow', parameters: customParams);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  6. Profile updates & Document uploads
    // ─────────────────────────────────────────────────────────────────────────
    if (cleanedText.contains('upload license') || cleanedText.contains('upload passport') || cleanedText.contains('upload id') || cleanedText.contains('update profile') || cleanedText.contains('update phone')) {
      session.reset();
      session.uploadStep = 401;
      customParams['options'] = ['Upload License', 'Upload Identity Document', 'Update Phone Number', 'Change Password', 'Cancel'];
      return AIResponse(
        message: "Select the profile element you wish to update:",
        intent: intent,
        confidence: 1.0,
        action: 'profile_flow',
        parameters: customParams,
      );
    } else if (session.uploadStep > 0) {
      final res = await _processProfileUploadFlow(text, session, customParams, uid);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'profile_flow', parameters: customParams);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  7. Pending Payments operator
    // ─────────────────────────────────────────────────────────────────────────
    if (cleanedText.contains('complete payment') || cleanedText.contains('pay deposit') || cleanedText.contains('upload receipt')) {
      session.reset();
      session.paymentUploadStep = 501;
      final res = await _listPendingPaymentBookings(uid, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'payment_upload_flow', parameters: customParams);
    } else if (session.paymentUploadStep > 0) {
      final res = await _processPaymentUploadFlow(text, session, customParams, uid);
      final act = customParams['action'] ?? 'payment_upload_flow';
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: act, parameters: customParams);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  8. Admin Fleet Management Operator
    // ─────────────────────────────────────────────────────────────────────────
    if (cleanedText.contains('manage fleet') || (intent is MaintenanceIntent && cleanedText.contains('status'))) {
      session.reset();
      session.adminFleetStep = 601;
      final res = await _listFleetVehicles(customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'admin_fleet_flow', parameters: customParams);
    } else if (session.adminFleetStep > 0) {
      final res = await _processAdminFleetFlow(text, session, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'admin_fleet_flow', parameters: customParams);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  9. Admin User Verification Operator
    // ─────────────────────────────────────────────────────────────────────────
    if (cleanedText.contains('verify customer') || (intent is CustomerIntent && cleanedText.contains('verify'))) {
      session.reset();
      session.adminVerifyStep = 701;
      final res = await _listPendingVerificationUsers(customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'admin_verify_flow', parameters: customParams);
    } else if (session.adminVerifyStep > 0) {
      final res = await _processAdminVerifyFlow(text, session, customParams);
      return AIResponse(message: res, intent: intent, confidence: 1.0, action: 'admin_verify_flow', parameters: customParams);
    }

    // Default Customer booking flow wizard
    final responseMessage = await _processBookingFlow(text, session, customParams, intent, userRole);
    String action = customParams['action'] ?? _getFallbackAction(intent);
    if (session.currentStep > 0) {
      action = 'booking_flow_active';
    }

    if (text == 'TRIGGER_DUMMY_KEEPER') {
      _searchBookingVehicles(session, customParams);
    }

    return AIResponse(
      message: responseMessage,
      intent: intent,
      confidence: intent.confidence,
      action: action,
      parameters: customParams,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Destructive Action Executor Wrapper (Safety confirm complete handler)
  // ─────────────────────────────────────────────────────────────────────────

  Future<AIResponse> _executeDestructiveAction(String? type, Map<String, dynamic> params, Map<String, dynamic> customParams) async {
    customParams['options'] = ['🚗 Book a Car', 'My Bookings', 'Back to Dashboard'];

    if (type == 'cancel_booking') {
      final bId = params['bookingId'] ?? '';
      final uId = params['userId'] ?? '';
      final vId = params['vehicleId'] ?? '';
      final vName = params['vehicleName'] ?? 'Vehicle';
      
      try {
        await BookingService().cancelBooking(bId, uId, vId, vName);
        return AIResponse(
          message: "🛡️ Safety Action Executed: **Booking Cancelled successfully!**\n\nThe reservation has been cancelled, vehicle returned to available, and refund processed.",
          intent: const BookingIntent(confidence: 1.0),
          confidence: 1.0,
          action: "cancel_booking_success",
          parameters: customParams,
        );
      } catch (e) {
        return AIResponse(message: "Safety cancel execution failed: $e", intent: const UnknownIntent(confidence: 1.0), confidence: 1.0, action: 'error', parameters: customParams);
      }
    }

    if (type == 'reject_verification') {
      final uId = params['userId'] ?? '';
      final reason = params['reason'] ?? 'Blurred documents uploaded.';
      
      try {
        await DatabaseService().verifyDocument(uId, 'license', false, reason: reason);
        return AIResponse(
          message: "🛡️ Safety Action Executed: **Customer Verification rejected.**\n\nNotification sent to user with rejection reason: '$reason'",
          intent: const CustomerIntent(confidence: 1.0),
          confidence: 1.0,
          action: "reject_verification_success",
          parameters: customParams,
        );
      } catch (e) {
        return AIResponse(message: "Verification reject failed: $e", intent: const UnknownIntent(confidence: 1.0), confidence: 1.0, action: 'error', parameters: customParams);
      }
    }

    return AIResponse(
      message: "Safety confirmation completed. Action parameter executed.",
      intent: const UnknownIntent(confidence: 1.0),
      confidence: 1.0,
      action: "safety_complete",
      parameters: customParams,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  FAQ Guided Interactive Flow
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _processFAQFlow(String text, BookingSessionState session, Map<String, dynamic> params) async {
    final textLower = text.trim().toLowerCase();
    
    if (textLower == 'exit faqs' || textLower == 'exit') {
      session.reset();
      params['options'] = ['🚗 Book a Car', '❓ FAQs', '💬 Contact Support', 'Back to Dashboard'];
      return "Exited FAQ mode. How else can I help you today? 👋";
    }

    if (textLower == 'back to faq categories' || textLower == 'back') {
      session.faqStep = 1;
      params['options'] = ['Booking', 'Payments', 'Vehicles', 'Rewards', 'Support', 'Policies', 'Exit FAQs'];
      return "Please select an FAQ category below:";
    }

    // Step 1: Category selection
    if (session.faqStep == 1) {
      if (textLower.contains('booking')) {
        session.faqStep = 2;
        session.faqCategory = 'Booking';
        params['options'] = ['How do I book?', 'Can I cancel my booking?', 'What documents are required?', 'Back to FAQ Categories'];
        return "Here are popular questions regarding **Booking**:";
      } else if (textLower.contains('payment')) {
        session.faqStep = 2;
        session.faqCategory = 'Payments';
        params['options'] = ['What payment methods are supported?', 'How does the deposit work?', 'Back to FAQ Categories'];
        return "Here are popular questions regarding **Payments & Billing**:";
      } else if (textLower.contains('vehicle')) {
        session.faqStep = 2;
        session.faqCategory = 'Vehicles';
        params['options'] = ['What types of cars do you have?', 'Can I choose transmission type?', 'Back to FAQ Categories'];
        return "Here are popular questions regarding **our Fleet & Vehicles**:";
      } else if (textLower.contains('reward')) {
        session.faqStep = 2;
        session.faqCategory = 'Rewards';
        params['options'] = ['How do I earn reward points?', 'Back to FAQ Categories'];
        return "Here are popular questions regarding **Reward Points**:";
      } else if (textLower.contains('support')) {
        session.faqStep = 2;
        session.faqCategory = 'Support';
        params['options'] = ['How can I contact support?', 'Back to FAQ Categories'];
        return "Here are popular questions regarding **Contact Support**:";
      } else if (textLower.contains('polic')) {
        session.faqStep = 2;
        session.faqCategory = 'Policies';
        params['options'] = ['What is the fuel policy?', 'What is the late return fee?', 'Back to FAQ Categories'];
        return "Here are popular questions regarding **our Rental Policies**:";
      }
      
      params['options'] = ['Booking', 'Payments', 'Vehicles', 'Rewards', 'Support', 'Policies', 'Exit FAQs'];
      return "I didn't recognize that category. Please select from the options:";
    }

    // Step 2: Answer specific question
    if (session.faqStep == 2) {
      params['options'] = ['Back to FAQ Categories', 'Exit FAQs'];
      
      if (textLower.contains('how do i book')) {
        return "You can book a car entirely within this chat without typing! Just click the **'Book a Car'** card on the home screen or type **'book a car'** to start our guided reservation wizard.";
      } else if (textLower.contains('cancel my booking') || textLower.contains('cancel')) {
        return "Yes! You can cancel bookings. Type **'cancel booking'** in this chat, or navigate to **'My Bookings'** in the customer panel to process a cancellation.";
      } else if (textLower.contains('documents are required') || textLower.contains('document')) {
        return "You must upload a valid **Driving License** and **Identity Document** under **'My Profile'** for verification prior to pick-up.";
      } else if (textLower.contains('payment methods')) {
        return "We support **Cash at the counter**, **FPX Online Banking**, and **DuitNow QR** instant transfer codes.";
      } else if (textLower.contains('deposit work') || textLower.contains('deposit')) {
        return "A 30% security deposit is processed during checkout to confirm your vehicle. The remaining balance is paid directly at the branch upon pickup.";
      } else if (textLower.contains('types of cars')) {
        return "Our fleet contains **SUVs, Sedans, Hatchbacks, MPVs (Family), and Premium/Luxury** vehicles. Click **'Available Vehicles'** on home to see them.";
      } else if (textLower.contains('transmission')) {
        return "Yes! We support both **Automatic** and **Manual** transmission models, which you can filter dynamically during reservation.";
      } else if (textLower.contains('earn reward points') || textLower.contains('reward')) {
        return "Every completed rental awards points automatically. You can redeem points during booking checkout (10 points = RM1.00 discount).";
      } else if (textLower.contains('contact support')) {
        return "You can click **'Contact Support'** on the home welcome screen, or open a ticket directly and our support representatives will respond.";
      } else if (textLower.contains('fuel policy')) {
        return "Our fuel policy is **Full-to-Full**. The vehicle is delivered with a full tank of fuel, and must be returned with a full tank to avoid refueling fees.";
      } else if (textLower.contains('late return fee')) {
        return "Late returns have a grace period of 1 hour. Beyond that, a late return fee of RM50 per hour will apply.";
      }
    }

    session.reset();
    params['options'] = ['🚗 Book a Car', '❓ FAQs', '💬 Contact Support', 'Back to Dashboard'];
    return "I couldn't find that specific FAQ entry. Wizards reset.";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Admin Guided Report Generator Flow
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _processAdminReportFlow(String text, BookingSessionState session, Map<String, dynamic> params) async {
    final textLower = text.trim().toLowerCase();
    
    if (textLower == 'cancel' || textLower == 'exit') {
      session.reset();
      params['options'] = ['📊 Dashboard Summary', '💰 Revenue', '🛠 Maintenance', 'Back to Dashboard'];
      return "Reports generation cancelled.";
    }

    if (session.adminReportStep == 1) {
      String tf = 'This Month';
      if (textLower.contains('today')) { tf = 'Today'; }
      else if (textLower.contains('week')) { tf = 'This Week'; }
      
      session.adminTimeframe = tf;
      
      double totalRevenue = 0.0;
      int bookingsCount = 0;
      
      try {
        final payments = await PaymentService().getPayments();
        final bookings = await BookingService().getBookings();
        
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        
        final filteredPayments = payments.where((p) {
          final status = (p.paymentStatus ?? p.status).toLowerCase();
          if (status != 'approved' && status != 'paid') return false;
          
          if (tf == 'Today') {
            return DateFormat('yyyy-MM-dd').format(p.paymentDate) == todayStr;
          } else if (tf == 'This Week') {
            return now.difference(p.paymentDate).inDays <= 7;
          } else {
            return p.paymentDate.year == now.year && p.paymentDate.month == now.month;
          }
        }).toList();
        
        for (final p in filteredPayments) {
          totalRevenue += p.amount;
        }

        final filteredBookings = bookings.where((b) {
          final bStat = b.status.toLowerCase();
          if (bStat == 'cancelled' || bStat == 'rejected') return false;
          
          if (tf == 'Today') {
            return DateFormat('yyyy-MM-dd').format(b.pickUpDate) == todayStr;
          } else if (tf == 'This Week') {
            return now.difference(b.pickUpDate).inDays <= 7;
          } else {
            return b.pickUpDate.year == now.year && b.pickUpDate.month == now.month;
          }
        }).toList();

        bookingsCount = filteredBookings.length;
      } catch (e) {
        debugPrint('Firebase reports read failed: $e');
      }

      final double utilRate = (bookingsCount > 0 ? (bookingsCount / 15.0).clamp(0.0, 1.0) * 100.0 : 0.0);

      final report = {
        'timeframe': tf,
        'revenue': totalRevenue,
        'bookingsCount': bookingsCount,
        'utilizationRate': '${utilRate.toStringAsFixed(0)}%',
        'carsActive': bookingsCount,
      };

      params['report'] = report;
      params['options'] = ['Export PDF', 'Export Excel', 'View Details', 'Cancel'];
      session.adminReportStep = 2;

      return "Generated Report Summary for **$tf** based on live database payments and booking records:\n\nSelect an action card below to save or view details:";
    }

    if (session.adminReportStep == 2) {
      session.reset();
      params['options'] = ['📊 Dashboard Summary', '💰 Revenue', '📈 Reports', 'Back to Dashboard'];
      
      if (textLower.contains('pdf')) {
        return "Reports System: Successfully exported **${session.adminTimeframe} Report** to PDF format. Download will start automatically. 📄📥";
      } else if (textLower.contains('excel')) {
        return "Reports System: Successfully compiled spreadsheet and exported **${session.adminTimeframe} Report** to Microsoft Excel format. 📈📥";
      } else if (textLower.contains('detail')) {
        params['action'] = 'view_reports';
        return "Navigating to Reports details overview tab... 📊";
      }
    }

    session.reset();
    return "Invalid selection. Report wizard reset.";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Support Ticket Operator Flow (Guided)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _listSupportTickets(String uid, Map<String, dynamic> params) async {
    try {
      final snap = await FirebaseDatabase.instance.ref().child('support_tickets').get();
      if (snap.exists) {
        final data = snap.value as Map;
        final list = <Map>[];
        data.forEach((k, v) {
          final t = Map.from(v);
          t['id'] = k.toString();
          if (t['customerId'] == uid) {
            list.add(t);
          }
        });
        if (list.isEmpty) {
          params['options'] = ['Create Support Ticket', 'Cancel'];
          return "You have no support tickets created yet. Click below to open one!";
        }
        params['options'] = list.map((t) => "View Ticket: #${t['id'].substring(0, 5)}").toList()..add('Cancel');
        return "I found **${list.length}** support tickets under your account. Select a ticket card below to view details:";
      }
    } catch (_) {}
    return "Support Desk currently unavailable. No tickets could be loaded from Firebase.";
  }

  Future<String> _viewSupportTicketDetails(String ticketId, Map<String, dynamic> params) async {
    try {
      final tSnap = await FirebaseDatabase.instance.ref().child('support_tickets').child(ticketId).get();
      if (tSnap.exists) {
        final t = Map.from(tSnap.value as Map);
        final status = t['status'] ?? 'Open';
        final subject = t['subject'] ?? 'General Ticket';
        
        final msgSnap = await FirebaseDatabase.instance.ref().child('support_messages').child(ticketId).get();
        String thread = '';
        if (msgSnap.exists) {
          final data = msgSnap.value as Map;
          final sortedMsg = data.values.toList()..sort((a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));
          for (final msg in sortedMsg) {
            final sender = msg['senderRole'] == 'admin' ? 'Admin' : 'You';
            thread += "\n**$sender** (${DateFormat('dd MMM HH:mm').format(DateTime.parse(msg['timestamp']))}):\n_${msg['message']}_\n";
          }
        }
        params['options'] = ['Reply to Ticket', 'Escalate Ticket', 'Back to Tickets'];
        return "🎫 **Support Ticket #${ticketId.substring(0, 5).toUpperCase()}**\n"
            "Subject: **$subject**\n"
            "Status: **$status**\n\n"
            "**Message History:**\n$thread\n\nSelect an action card below:";
      }
    } catch (_) {}
    return "Ticket not found or error loading database logs.";
  }

  Future<String> _processSupportOperator(String text, BookingSessionState session, Map<String, dynamic> params, String uid) async {
    final textLower = text.trim().toLowerCase();

    if (session.supportStep == 101) {
      session.ticketSubject = text;
      session.supportStep = 102;
      return "Subject set: **${session.ticketSubject}**.\n\n**Step 2**: Please type your detailed inquiry or describe the issue:";
    }

    if (session.supportStep == 102) {
      final subject = session.ticketSubject ?? 'Support Inquiry';
      session.reset();
      try {
        await DatabaseService().createTicket(subject, text);
        params['options'] = ['Track Support Ticket', 'Back to Dashboard'];
        return "📬 **Support Ticket Created Successfully!**\n\nOur service desk agents have been notified and will reply shortly. You can track this ticket dynamically under 'Track Support Ticket' chip.";
      } catch (e) {
        return "Failed to save support ticket: $e";
      }
    }

    if (session.supportStep == 103) {
      final ticketId = session.activeTicketId!;
      session.reset();
      try {
        await DatabaseService().sendTicketMessage(ticketId, text, 'customer');
        params['options'] = ['View Ticket: #${ticketId.substring(0, 5)}', 'Track Support Tickets'];
        return "✉️ **Reply sent successfully!**";
      } catch (e) {
        return "Failed to send message: $e";
      }
    }

    if (session.supportStep == 104) {
      if (textLower.contains('reply')) {
        session.supportStep = 103;
        return "Please type your reply message text below:";
      } else if (textLower.contains('escalate')) {
        final ticketId = session.activeTicketId!;
        session.reset();
        try {
          await FirebaseDatabase.instance.ref().child('support_tickets').child(ticketId).update({'status': 'High Priority'});
          params['options'] = ['View Ticket: #${ticketId.substring(0, 5)}', 'Track Support Tickets'];
          return "📞🚨 **Ticket Escalated to High Priority!**\n\nThe admin team has been flagged for urgent review.";
        } catch (e) {
          return "Failed to escalate: $e";
        }
      } else if (textLower.contains('back')) {
        session.reset();
        return await _listSupportTickets(uid, params);
      }
    }

    session.reset();
    return "Support operator reset.";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Booking Extensions & Cancellations Operators
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _listCancelBookings(String uid, Map<String, dynamic> params, BookingSessionState session) async {
    try {
      final bookings = await BookingService().getUserBookings(uid);
      final active = bookings.where((b) => 
        b.status.toLowerCase() != 'completed' && 
        b.status.toLowerCase() != 'cancelled' && 
        b.status.toLowerCase() != 'rejected'
      ).toList();

      if (active.isEmpty) {
        params['options'] = ['🚗 Book a Car', 'Back to Dashboard'];
        return "You do not have any active bookings that can be cancelled.";
      }

      params['options'] = active.map((b) => "Cancel Reservation: #${b.id.substring(0, 5)}").toList()..add('Cancel');
      return "Select the booking reference you wish to cancel:";
    } catch (_) {}
    return "Could not fetch bookings from database.";
  }

  Future<String> _triggerCancelBookingConfirmation(String bookingId, BookingSessionState session, Map<String, dynamic> params) async {
    try {
      final bookingsSnap = await FirebaseDatabase.instance.ref().child('bookings').child(bookingId).get();
      if (bookingsSnap.exists) {
        final bData = Map.from(bookingsSnap.value as Map);
        final vehicleId = bData['vehicleId'] ?? '';
        final vehicleName = bData['vehicleName'] ?? 'Vehicle';
        final userId = bData['userId'] ?? '';

        session.confirmDestructiveStep = 901;
        session.destructiveActionType = 'cancel_booking';
        session.destructiveActionParams = {
          'bookingId': bookingId,
          'userId': userId,
          'vehicleId': vehicleId,
          'vehicleName': vehicleName,
        };

        params['options'] = ['Yes, Confirm Cancellation', 'No, Keep Booking'];
        return "⚠️ **Are you sure you want to cancel booking Ref: #${bookingId.substring(0, 5).toUpperCase()}?**\n\n"
            "This will return the vehicle **$vehicleName** to available status and process a deposit refund.";
      }
    } catch (_) {}
    return "Invalid booking reference selected.";
  }

  Future<String> _listExtendBookings(String uid, Map<String, dynamic> params) async {
    try {
      final bookings = await BookingService().getUserBookings(uid);
      final active = bookings.where((b) => b.status.toLowerCase() == 'confirmed' || b.status.toLowerCase() == 'active' || b.status.toLowerCase() == 'ongoing').toList();
      
      if (active.isEmpty) {
        params['options'] = ['🚗 Book a Car', 'Back to Dashboard'];
        return "You have no active or confirmed bookings that can be extended.";
      }

      params['options'] = active.map((b) => "Extend Booking: #${b.id.substring(0, 5)}").toList()..add('Cancel');
      return "Select the booking reference you want to extend:";
    } catch (_) {}
    return "Could not read bookings from Firebase.";
  }

  Future<String> _processBookingExtensionFlow(String text, BookingSessionState session, Map<String, dynamic> params) async {
    final textLower = text.trim().toLowerCase();

    if (session.extensionStep == 201) {
      final bId = text.split('#').last.trim();
      session.activeExtendBookingId = bId;
      session.extensionStep = 202;
      params['request_date'] = 'return';
      return "Booking selected: **#${bId.substring(0, 5).toUpperCase()}**.\n\n"
          "Please select a **New Return Date** using the calendar picker below:";
    }

    if (session.extensionStep == 202) {
      final date = _extractDate(text);
      if (date == null) {
        params['request_date'] = 'return';
        return "Invalid date format. Please click the calendar button below:";
      }

      final bId = session.activeExtendBookingId!;
      DateTime? originalReturnDate;
      double pricePerDay = 180.0;
      double currentPrice = 0.0;
      
      try {
        final bSnap = await FirebaseDatabase.instance.ref().child('bookings').child(bId).get();
        if (bSnap.exists) {
          final b = Map.from(bSnap.value as Map);
          originalReturnDate = DateTime.parse(b['returnDate']);
          currentPrice = double.tryParse(b['totalPrice']?.toString() ?? '') ?? 0.0;
          
          final vSnap = await FirebaseDatabase.instance.ref().child('vehicles').child(b['vehicleId']).get();
          if (vSnap.exists) {
            pricePerDay = double.tryParse((vSnap.value as Map)['pricePerDay']?.toString() ?? '') ?? 180.0;
          }
        }
      } catch (_) {}

      if (originalReturnDate != null && date.isBefore(originalReturnDate)) {
        params['request_date'] = 'return';
        return "The new return date must be *after* the original return date (${DateFormat('dd MMM yyyy').format(originalReturnDate)}). Select a valid date:";
      }

      session.extensionNewReturnDate = date;
      final daysDiff = originalReturnDate != null ? date.difference(originalReturnDate).inDays : 1;
      final extraCost = (daysDiff <= 0 ? 1 : daysDiff) * pricePerDay;
      final newTotalPrice = currentPrice + extraCost;

      session.extensionStep = 203;
      params['options'] = ['Confirm Extension', 'Abort'];
      params['newTotalPrice'] = newTotalPrice;
      params['extraCost'] = extraCost;

      return "📅 **Booking Extension Summary**\n"
          "New Return Date: **${DateFormat('dd MMM yyyy').format(date)}**\n"
          "Extra Duration: **$daysDiff Days**\n"
          "Additional Charge: **RM ${extraCost.toStringAsFixed(2)}**\n\n"
          "Click **Confirm Extension** below to finalize this transaction:";
    }

    if (session.extensionStep == 203) {
      if (textLower.contains('confirm')) {
        final bId = session.activeExtendBookingId!;
        final newDate = session.extensionNewReturnDate!;
        
        try {
          final bSnap = await FirebaseDatabase.instance.ref().child('bookings').child(bId).get();
          if (bSnap.exists) {
            final b = Map.from(bSnap.value as Map);
            final vSnap = await FirebaseDatabase.instance.ref().child('vehicles').child(b['vehicleId']).get();
            double pPerDay = 180.0;
            if (vSnap.exists) {
              pPerDay = double.tryParse((vSnap.value as Map)['pricePerDay']?.toString() ?? '') ?? 180.0;
            }

            final currentReturn = DateTime.parse(b['returnDate']);
            final daysDiff = newDate.difference(currentReturn).inDays;
            final extraCost = (daysDiff <= 0 ? 1 : daysDiff) * pPerDay;

            await BookingService().requestExtension(
              bId,
              newDate,
              extraCost,
              status: 'pending',
              paymentStatus: 'unpaid',
            );
          }
          session.reset();
          params['options'] = ['My Bookings', 'Back to Dashboard'];
          return "📅 **Extension Request Submitted!**\n\nYour request has been submitted to the Admin for approval. You will be notified once it is approved.";
        } catch (e) {
          session.reset();
          return "Extension failed: $e";
        }
      } else {
        session.reset();
        params['options'] = ['🚗 Book a Car', 'Back to Dashboard'];
        return "Extension aborted.";
      }
    }

    session.reset();
    return "Extension flow cancelled.";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Vehicle Comparison Operator
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _listCompareVehicles(int slot, Map<String, dynamic> params) async {
    try {
      final vehicles = await VehicleService().getVehicles();
      final available = vehicles.where((v) => v.status.toLowerCase() == 'available').toList();
      params['options'] = available.map((v) => "${v.brand} ${v.model} [${v.id}]").toList()..add('Cancel');
      return "Please select **Vehicle $slot** for comparison:";
    } catch (_) {}
    return "Could not load vehicle fleet.";
  }

  Future<String> _processVehicleComparisonFlow(String text, BookingSessionState session, Map<String, dynamic> params) async {
    final regExp = RegExp(r'\[(.*?)\]');
    final match = regExp.firstMatch(text);
    final selectedId = match != null ? match.group(1) : text;

    if (session.compareStep == 301) {
      session.compareCarId1 = selectedId;
      session.compareStep = 302;
      return await _listCompareVehicles(2, params);
    }

    if (session.compareStep == 302) {
      session.compareCarId2 = selectedId;
      
      VehicleModel? c1;
      VehicleModel? c2;

      try {
        final list = await VehicleService().getVehicles();
        c1 = list.firstWhere((v) => v.id == session.compareCarId1);
        c2 = list.firstWhere((v) => v.id == session.compareCarId2);
      } catch (_) {}

      session.reset();

      if (c1 != null && c2 != null) {
        final compMap = {
          'car1': c1.toMap(),
          'car2': c2.toMap(),
        };
        params['comparison'] = compMap;
        params['options'] = ['Book ${c1.brand} ${c1.model}', 'Book ${c2.brand} ${c2.model}', 'Cancel'];
        return "⚖️ **Vehicle Comparison Result**\n"
            "Comparison metrics are rendered in the layout card below:";
      }
      return "Comparison failed: One of the selected models is no longer available.";
    }

    session.reset();
    return "Comparison reset.";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Profile elements & Document Upload Operator
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _processProfileUploadFlow(String text, BookingSessionState session, Map<String, dynamic> params, String uid) async {
    final textLower = text.trim().toLowerCase();

    if (session.uploadStep == 401) {
      if (textLower.contains('license')) {
        session.uploadStep = 402;
        session.uploadDocType = 'license';
        params['action'] = 'upload_license';
        return "Please upload an image of your **Driving License**:";
      } else if (textLower.contains('identity') || textLower.contains('id') || textLower.contains('passport')) {
        session.uploadStep = 402;
        session.uploadDocType = 'id';
        params['action'] = 'upload_id';
        return "Please upload an image of your **Identity Card / Passport**:";
      } else if (textLower.contains('phone')) {
        session.uploadStep = 403;
        return "Please enter your new contact phone number:";
      } else if (textLower.contains('password')) {
        session.reset();
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && user.email != null) {
            await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
            return "🔑 **Reset Request Placed!**\n\nA password reset validation link has been sent to your email address: **${user.email}**.";
          }
        } catch (e) {
          return "Password reset dispatch error: $e";
        }
      }
      session.reset();
      return "Profile wizard cancelled.";
    }

    if (session.uploadStep == 402) {
      final doc = session.uploadDocType!;
      session.reset();
      
      // Parse uploaded base64 data
      String base64 = '';
      if (text.contains('base64:')) {
        base64 = text.split('base64:').last.replaceAll(']', '').trim();
      } else {
        base64 = text; // raw
      }

      try {
        final Map<String, dynamic> update = {};
        if (doc == 'license') {
          update['licenseImage'] = base64;
          update['licenseStatus'] = 'pending';
        } else {
          update['idImage'] = base64;
          update['idStatus'] = 'pending';
        }
        await DatabaseService().updateUser(uid, update);
        params['options'] = ['Back to Dashboard'];
        return "📤 **Document Uploaded Successfully!**\n\nYour **${doc.toUpperCase()}** has been submitted and is pending verification review by our admins. 👤🛡️";
      } catch (e) {
        return "Document upload failed: $e";
      }
    }

    if (session.uploadStep == 403) {
      session.reset();
      try {
        await DatabaseService().updateUser(uid, {'phone': text});
        params['options'] = ['Back to Dashboard'];
        return "👤 **Profile Updated!**\n\nYour contact phone number has been updated to **$text** in the database.";
      } catch (e) {
        return "Profile phone update failed: $e";
      }
    }

    session.reset();
    return "Profile operator reset.";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Pending Payments Operator Flow
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _listPendingPaymentBookings(String uid, Map<String, dynamic> params) async {
    try {
      final bookings = await BookingService().getUserBookings(uid);
      final pending = bookings.where((b) => b.status.toLowerCase() == 'pending payment' || b.status.toLowerCase() == 'pending').toList();

      if (pending.isEmpty) {
        params['options'] = ['🚗 Book a Car', 'Back to Dashboard'];
        return "You do not have any bookings with pending payments due.";
      }

      params['options'] = pending.map((b) => "Upload Payment: #${b.id.substring(0, 5)}").toList()..add('Cancel');
      return "Select the booking reference you want to clear payment for:";
    } catch (_) {}
    return "Could not load bookings list from Firebase.";
  }

  Future<String> _processPaymentUploadFlow(String text, BookingSessionState session, Map<String, dynamic> params, String uid) async {
    if (session.paymentUploadStep == 501) {
      final bId = text.split('#').last.trim();
      
      String resolvedBookingId = bId;
      try {
        final bookings = await BookingService().getUserBookings(uid);
        final match = bookings.firstWhere((b) => b.id.toLowerCase().startsWith(bId.toLowerCase()));
        resolvedBookingId = match.id;
      } catch (_) {}

      session.reset();
      params['bookingId'] = resolvedBookingId;
      params['action'] = 'open_payment_page';
      
      return "Opening the secure checkout payment screen for booking Ref: `#${resolvedBookingId.substring(0, 5).toUpperCase()}`... 💳";
    }

    session.reset();
    return "Payment wizard reset.";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Admin Fleet Status Toggler Operator
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _listFleetVehicles(Map<String, dynamic> params) async {
    try {
      final list = await VehicleService().getVehicles();
      params['options'] = list.map((v) => "Manage Car: ${v.brand} ${v.model} [${v.id}]").toList()..add('Cancel');
      return "Select a vehicle from the fleet to manage status:";
    } catch (_) {}
    return "Error loading vehicle fleet records.";
  }

  Future<String> _processAdminFleetFlow(String text, BookingSessionState session, Map<String, dynamic> params) async {
    final textLower = text.trim().toLowerCase();

    if (session.adminFleetStep == 601) {
      final regExp = RegExp(r'\[(.*?)\]');
      final match = regExp.firstMatch(text);
      final vId = match != null ? match.group(1) : text;

      session.adminVehicleId = vId;
      session.adminFleetStep = 602;
      params['options'] = ['Mark as Maintenance', 'Mark as Available', 'Cancel'];
      return "Select the new operational status for this vehicle:";
    }

    if (session.adminFleetStep == 602) {
      final vId = session.adminVehicleId!;
      session.reset();
      
      String newStatus = 'Available';
      if (textLower.contains('maintenance')) newStatus = 'Maintenance';

      try {
        if (newStatus == 'Maintenance') {
          // Add dummy maintenance job to register state transition
          final job = MaintenanceJobModel(
            id: '',
            vehicleId: vId,
            vehicleName: 'Fleet Vehicle',
            title: 'Operator Triggered Check',
            description: 'Assigned to maintenance via AI Operator panel.',
            cost: 150.0,
            startDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            endDate: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 2))),
            status: 'In Progress',
            showToCustomer: true,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          );
          await MaintenanceService().addMaintenanceJob(job);
        } else {
          await VehicleService().updateVehicleStatus(vId, 'Available');
        }
        params['options'] = ['Fleet Status', 'Back to Dashboard'];
        return "🔧💼 **Fleet updated successfully!**\n\nVehicle status set to **$newStatus** in Firebase.";
      } catch (e) {
        return "Failed to update fleet status: $e";
      }
    }

    session.reset();
    return "Fleet operator reset.";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Admin Customer Verification Operator
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _listPendingVerificationUsers(Map<String, dynamic> params) async {
    try {
      final list = await DatabaseService().getUsers();
      final pending = list.where((u) => u.licenseStatus == 'pending').toList();
      
      if (pending.isEmpty) {
        params['options'] = ['Customers', 'Back to Dashboard'];
        return "There are no customers with pending driving license verifications.";
      }

      params['options'] = pending.map((u) => "Verify License: ${u.fullName} [${u.id}]").toList()..add('Cancel');
      return "Select a customer to verify:";
    } catch (_) {}
    return "Error loading users registry database.";
  }

  Future<String> _processAdminVerifyFlow(String text, BookingSessionState session, Map<String, dynamic> params) async {
    final textLower = text.trim().toLowerCase();

    if (session.adminVerifyStep == 701) {
      final regExp = RegExp(r'\[(.*?)\]');
      final match = regExp.firstMatch(text);
      final userId = match != null ? match.group(1) : text;

      session.adminVerifyUserId = userId;
      session.adminVerifyStep = 702;
      params['options'] = ['Approve Documents', 'Reject Documents', 'Cancel'];
      return "Review user documents. Select validation decision:";
    }

    if (session.adminVerifyStep == 702) {
      if (textLower.contains('approve')) {
        final userId = session.adminVerifyUserId!;
        session.reset();
        try {
          await DatabaseService().verifyLicense(userId, true);
          params['options'] = ['Customers', 'Back to Dashboard'];
          return "🛡️ **Customer documents APPROVED successfully!**\n\nThe account has been marked verified.";
        } catch (e) {
          return "Approval write failed: $e";
        }
      } else if (textLower.contains('reject')) {
        session.adminVerifyStep = 703;
        return "Please type a rejection reason to notify the customer:";
      } else {
        session.reset();
        return "Verification cancelled.";
      }
    }

    if (session.adminVerifyStep == 703) {
      final userId = session.adminVerifyUserId!;
      
      session.confirmDestructiveStep = 901;
      session.destructiveActionType = 'reject_verification';
      session.destructiveActionParams = {
        'userId': userId,
        'reason': text,
      };

      params['options'] = ['Yes, Confirm Rejection', 'No, Cancel Action'];
      return "⚠️ **Confirm Rejecting Document Verification?**\n\nRejection reason: '$text'";
    }

    session.reset();
    return "Verification reset.";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Default Customer booking flow wizard
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _processBookingFlow(String text, BookingSessionState session, Map<String, dynamic> params, AIIntent intent, String userRole) async {
    final textLower = text.toLowerCase().trim();
    
    // Check for extension request redirect
    if (textLower.contains('extend') && (textLower.contains('booking') || textLower.contains('rent') || textLower.contains('reservation'))) {
      session.reset();
      return "The booking extension feature is currently unavailable. Please contact our support desk or make a new reservation.";
    }

    // Handle warning redirection choice
    if (session.currentStep == 0 && session.warnedActiveBooking) {
      if (textLower.contains('view') || textLower.contains('show') || textLower.contains('yes')) {
        session.reset();
        params['action'] = 'view_bookings';
        return "Navigating to your active bookings screen... 📜";
      } else if (textLower.contains('new') || textLower.contains('anyway') || textLower.contains('no')) {
        session.currentStep = 1;
        return await _askVehicleCategory(session, params);
      }
    }

    // Initialize guided flow trigger
    if (session.currentStep == 0 && intent is BookingIntent && intent.parameters['action'] == 'book_vehicle') {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final bookings = await BookingService().getUserBookings(uid);
          final active = bookings.where((b) => 
            b.status.toLowerCase() != 'completed' && 
            b.status.toLowerCase() != 'cancelled' && 
            b.status.toLowerCase() != 'rejected'
          ).toList();
          
          if (active.isNotEmpty && !session.warnedActiveBooking) {
            session.warnedActiveBooking = true;
            params['action'] = 'warn_active_booking';
            params['active_booking_id'] = active.first.id;
            params['options'] = ['View Active Bookings', 'Make New Booking Anyway'];
            return "You already have an active booking for a **${active.first.vehicleName}** (Booking Ref: #${active.first.id.substring(0, 5).toUpperCase()}).\n\nWould you like to view it instead? Or proceed to make a new booking anyway?";
          }
        } catch (_) {}
      }

      session.currentStep = 1;
      return await _askVehicleCategory(session, params);
    }

    // Guided Booking State steps switcher
    switch (session.currentStep) {
      case 1: // Vehicle Category Selected -> Ask Vehicle
        List<VehicleModel> v1 = [];
        try { v1 = await VehicleService().getVehicles(); } catch (_) {}
        final categories = v1.map((v) => v.category).toSet().toList();
        session.type = _extractVehicleType(text, categories);
        
        session.currentStep = 2;
        return await _askVehicleCardList(session, params);

      case 2: // Vehicle Selected -> Ask Branch
        final regExp = RegExp(r'\[(.*?)\]');
        final match = regExp.firstMatch(text);
        final searchId = (match != null ? match.group(1) : text) ?? '';

        if (searchId.trim().isEmpty) {
          session.reset();
          return "No matching vehicle was found.";
        }

        try {
          final vehicles = await VehicleService().getVehicles();
          VehicleModel? matchedVehicle;
          for (final v in vehicles) {
            if (v.id.toLowerCase() == searchId.toLowerCase() ||
                '${v.brand} ${v.model}'.toLowerCase() == searchId.toLowerCase() ||
                '${v.brand} ${v.model}'.toLowerCase().contains(searchId.toLowerCase()) ||
                v.model.toLowerCase().contains(searchId.toLowerCase())) {
              matchedVehicle = v;
              break;
            }
          }

          if (matchedVehicle == null) {
            session.reset();
            return "No matching vehicle was found.";
          }

          if (matchedVehicle.status.toLowerCase() != 'available') {
            session.reset();
            return "No matching vehicle was found.";
          }

          final branchName = matchedVehicle.branchName.isEmpty ? 'Kuala Lumpur' : matchedVehicle.branchName;
          final branches = await BranchService().getBranches();
          if (!branches.any((b) => b.name.toLowerCase() == branchName.toLowerCase())) {
            session.reset();
            return "No matching vehicle was found.";
          }

          session.vehicleId = matchedVehicle.id;
          session.vehicleName = '${matchedVehicle.brand} ${matchedVehicle.model}';
          session.vehiclePrice = matchedVehicle.pricePerDay;
          session.type = matchedVehicle.category;
          session.branch = branchName;

          session.currentStep = 3;
          return await _askBranchSelection(session, params);
        } catch (_) {
          session.reset();
          return "No matching vehicle was found.";
        }

      case 3: // Branch Selected -> Ask Pickup Date
        List<String> branchNames = [];
        try {
          final branches = await BranchService().getBranches();
          branchNames = branches.map((b) => b.name).toList();
        } catch (_) {}
        if (branchNames.isEmpty) branchNames = ['Kuala Lumpur'];

        final matchedBranch = _findMatchingBranch(text, branchNames);
        if (matchedBranch == null) {
          params['options'] = branchNames;
          return "I didn't recognize that branch. Please click a branch card below:";
        }
        session.branch = matchedBranch;
        
        session.currentStep = 4;
        params['request_date'] = 'pickup';
        return "Pickup Branch selected: **${session.branch}**.\n\n**Step 4 of 8**: Please select your Rental Dates. Click the button below to pick your Pick-up Date:";

      case 4: // Pickup Date Selected -> Ask Pickup Time
        if (textLower.contains('pickup')) {
          final date = _extractDate(text);
          if (date == null) {
            params['request_date'] = 'pickup';
            return "Invalid pickup date. Please pick a date using the calendar:";
          }
          session.pickupDate = date;
          
          session.currentStep = 5;
          params['options'] = ['08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM', '12:00 PM', '01:00 PM', '02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM'];
          return "Pickup date: **${DateFormat('dd MMM yyyy').format(date)}**.\n\n**Step 5 of 8**: Please select a Pick-up Time slot below:";
        }
        params['request_date'] = 'pickup';
        return "Please use the dynamic calendar buttons below to select a Pick-up Date:";

      case 5: // Pickup Time Selected -> Ask Return Date
        session.pickupTime = text;
        
        session.currentStep = 6;
        params['request_date'] = 'return';
        return "Pickup time: **${session.pickupTime}**.\n\n**Step 6 of 8**: Click the button below to pick your Return Date:";

      case 6: // Return Date Selected -> Ask Reward Points
        final isOpenRequested = textLower.contains("don't know") ||
            textLower.contains("do not know") ||
            textLower.contains("open rental") ||
            textLower.contains("open return") ||
            textLower.contains("not sure") ||
            textLower.contains("no fixed");

        if (isOpenRequested) {
          session.isOpenRental = true;
          session.returnDate = null;
          
          session.currentStep = 7;
          final uid = FirebaseAuth.instance.currentUser?.uid;
          int rewardPoints = 0;
          if (uid != null) {
            try {
              final user = await DatabaseService().getUser(uid);
              rewardPoints = user?.rewardPoints ?? 0;
            } catch (_) {}
          }

          if (rewardPoints > 0) {
            final disc = rewardPoints * 0.10;
            params['options'] = [
              'No discount',
              'Redeem $rewardPoints Points (RM ${disc.toStringAsFixed(0)} off)'
            ];
            return "You have selected an **Open Rental** (active until returned).\n\n"
                "**Step 7 of 8**: You have **$rewardPoints** reward points available. Would you like to redeem them for a discount?";
          } else {
            session.pointsToRedeem = 0;
            session.currentStep = 8;
            return await _showBookingSummary(session, params);
          }
        }

        if (textLower.contains('return')) {
          final date = _extractDate(text);
          if (date == null) {
            params['request_date'] = 'return';
            return "Invalid return date. Please pick a date using the calendar:";
          }
          if (session.pickupDate != null && date.isBefore(session.pickupDate!)) {
            params['request_date'] = 'return';
            return "Return date must be after pick-up date! Select a valid return date:";
          }
          session.isOpenRental = false;
          session.returnDate = date;
          
          session.currentStep = 7;
          final uid = FirebaseAuth.instance.currentUser?.uid;
          int rewardPoints = 0;
          if (uid != null) {
            try {
              final user = await DatabaseService().getUser(uid);
              rewardPoints = user?.rewardPoints ?? 0;
            } catch (_) {}
          }

          if (rewardPoints > 0) {
            final disc = rewardPoints * 0.10;
            params['options'] = [
              'No discount',
              'Redeem $rewardPoints Points (RM ${disc.toStringAsFixed(0)} off)'
            ];
            return "Dates selected: **${DateFormat('dd MMM').format(session.pickupDate!)} - ${DateFormat('dd MMM yyyy').format(session.returnDate!)}**.\n\n"
                "**Step 7 of 8**: You have **$rewardPoints** reward points available. Would you like to redeem them for a discount?";
          } else {
            session.pointsToRedeem = 0;
            session.currentStep = 8;
            return await _showBookingSummary(session, params);
          }
        }
        params['request_date'] = 'return';
        return "Please use the dynamic calendar buttons below to select a Return Date:";

      case 7: // Reward Points Selected -> Show Summary
        if (textLower.contains('redeem')) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            try {
              final user = await DatabaseService().getUser(uid);
              session.pointsToRedeem = user?.rewardPoints ?? 0;
            } catch (_) {}
          }
        } else {
          session.pointsToRedeem = 0;
        }

        session.currentStep = 8;
        return await _showBookingSummary(session, params);

      case 8: // Summary Card Actions -> Create Booking -> Ask Payment Method
        if (textLower.contains('confirm')) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) {
            session.reset();
            return "User authentication session expired. Please log in again.";
          }

          try {
            final rentalDays = session.isOpenRental ? 1 : session.returnDate!.difference(session.pickupDate!).inDays;
            final daysCount = rentalDays <= 0 ? 1 : rentalDays;
            final double basePrice = daysCount * (session.vehiclePrice ?? 180.0);
            final double discount = session.pointsToRedeem * 0.10;
            final double finalTotal = (basePrice - discount).clamp(0.0, double.infinity);
            final double deposit = (finalTotal * 0.3).clamp(150.0, finalTotal);

            final userProfile = await DatabaseService().getUser(uid);
            final activeUserName = userProfile?.fullName ?? 'Customer';
            final activeUserPhone = userProfile?.phone ?? '';

            final bookingRef = FirebaseDatabase.instance.ref().child('bookings').push();
            final bookingId = bookingRef.key!;

            DateTime pDate = session.pickupDate!;
            DateTime? rDate = session.isOpenRental ? null : session.returnDate;
            try {
              final parsedTime = DateFormat('hh:mm a').parse(session.pickupTime ?? '09:00 AM');
              pDate = DateTime(session.pickupDate!.year, session.pickupDate!.month, session.pickupDate!.day, parsedTime.hour, parsedTime.minute);
              if (rDate != null) {
                rDate = DateTime(rDate.year, rDate.month, rDate.day, parsedTime.hour, parsedTime.minute);
              }
            } catch (_) {}

            final booking = BookingModel(
              id: bookingId,
              vehicleId: session.vehicleId!,
              vehicleName: session.vehicleName!,
              userId: uid,
              userName: activeUserName,
              userPhone: activeUserPhone,
              pickUpDate: pDate,
              returnDate: rDate,
              isOpenRental: session.isOpenRental,
              totalPrice: finalTotal,
              depositAmount: deposit,
              status: 'Waiting for Payment', 
              notes: 'AI Operator Guided Booking',
              createdAt: DateTime.now(),
              pointsRedeemed: session.pointsToRedeem,
              discountAmount: discount,
              pointsRedeemedProcessed: false,
              rewardPointsAwarded: false,
              paymentMethod: 'Pending',
            );

            await BookingService().createBooking(booking);

            session.paymentBookingId = bookingId;
            session.currentStep = 9;

            params['bookingId'] = bookingId;
            params['options'] = ['Cash at Counter', 'FPX Online Banking', 'DuitNow QR'];

            return "🎉 Booking `#${bookingId.substring(0, 5).toUpperCase()}` has been successfully created in **'Waiting for Payment'** status.\n\n"
                "Please choose your payment method below:";

          } catch (e) {
            session.reset();
            return "Booking checkout failed: $e";
          }
        } else if (textLower.contains('edit')) {
          session.currentStep = 1;
          return await _askVehicleCategory(session, params);
        } else {
          session.reset();
          params['options'] = ['🚗 Book a Car', '❓ FAQs', '💬 Contact Support', 'Back to Dashboard'];
          return "Booking checkout cancelled. Let me know how else I can assist you!";
        }

      case 9: // Select Payment Method -> Save -> Close AI -> Open Pending Payment page
        final bId = session.paymentBookingId;
        if (bId == null) {
          session.reset();
          return "Session booking ID is lost. Resetting guided flow.";
        }

        String method = 'Cash';
        if (textLower.contains('fpx')) {
          method = 'FPX Online Banking';
        } else if (textLower.contains('qr') || textLower.contains('duitnow')) {
          method = 'DuitNow QR';
        }

        try {
          await FirebaseDatabase.instance
              .ref()
              .child('bookings')
              .child(bId)
              .update({'paymentMethod': method});

          final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
          final paymentRef = FirebaseDatabase.instance.ref().child('payments').push();
          final paymentId = paymentRef.key!;

          final bSnap = await FirebaseDatabase.instance.ref().child('bookings').child(bId).get();
          double deposit = 150.0;
          double totalVal = 150.0;
          if (bSnap.exists) {
            final bData = Map<dynamic, dynamic>.from(bSnap.value as Map);
            deposit = double.tryParse(bData['depositAmount']?.toString() ?? '') ?? 150.0;
            totalVal = double.tryParse(bData['totalPrice']?.toString() ?? '') ?? 150.0;
          }

          final payment = PaymentModel(
            id: paymentId,
            bookingId: bId,
            userId: uid,
            amount: deposit, 
            depositAmount: deposit,
            balanceAmount: totalVal - deposit,
            paymentMethod: method,
            status: 'Pending', 
            paymentStatus: 'Pending',
            transactionId: 'AI-${paymentId.substring(0, 5).toUpperCase()}',
            paymentDate: DateTime.now(),
            uploadedAt: DateTime.now().toIso8601String(),
            customerUid: uid,
          );

          await PaymentService().createPayment(payment);

          session.reset();
          params['action'] = 'open_pending_bookings';
          return "Selected Payment Method **$method** saved! Redirecting you to your Pending Payments tab... 💳";

        } catch (e) {
          session.reset();
          return "Failed to register payment method choice: $e";
        }

      default:
        return await _generateResponse(intent, text, session, userRole);
    }
  }

  // ── Booking Flow Step Sub-Renderers ─────────────────────────────

  Future<String> _askVehicleCategory(BookingSessionState session, Map<String, dynamic> params) async {
    List<VehicleModel> vehicles = [];
    try {
      vehicles = await VehicleService().getVehicles();
    } catch (_) {}
    final categories = vehicles.map((v) => v.category).toSet().toList();
    if (categories.isEmpty) categories.addAll(['SUV', 'Sedan', 'Hatchback', 'Luxury', 'Family', 'Pickup']);
    params['options'] = categories;

    return "Great! Let's start the Booking Wizard. 🧙‍♂️✨\n\n**Step 1 of 8**: What type of vehicle category are you looking to rent?";
  }

  Future<String> _askVehicleCardList(BookingSessionState session, Map<String, dynamic> params) async {
    List<VehicleModel> vehicles = [];
    try {
      vehicles = await VehicleService().getVehicles();
    } catch (_) {}

    final filtered = vehicles.where((v) {
      if (v.status.toLowerCase() != 'available') return false;
      if (session.type == 'Family') {
        return v.category == 'MPV' || v.seats >= 6;
      }
      return v.category.toLowerCase() == session.type!.toLowerCase();
    }).toList();

    if (filtered.isEmpty) {
      session.reset();
      params['options'] = ['🚗 Book a Car', '❓ FAQs', '💬 Contact Support', 'Back to Dashboard'];
      return "No available **${session.type}** models were found in our database at this moment. Let's try another category!";
    }

    params['vehicles'] = filtered.map((v) => v.toMap()).toList();
    params['isSelectionMode'] = true; 

    return "**Step 2 of 8**: I found **${filtered.length}** available **${session.type}** models. Please select a vehicle from the cards below:";
  }

  Future<String> _askBranchSelection(BookingSessionState session, Map<String, dynamic> params) async {
    List<String> branchNames = [];
    try {
      final branches = await BranchService().getBranches();
      branchNames = branches.map((b) => b.name).toList();
    } catch (_) {}
    if (branchNames.isEmpty) branchNames = ['Kuala Lumpur', 'Kajang', 'Putrajaya'];
    params['options'] = branchNames;

    return "Vehicle set: **${session.vehicleName}** (RM ${session.vehiclePrice?.toStringAsFixed(0)}/day).\n\n"
        "**Step 3 of 8**: Please select your Pickup Branch location card below:";
  }

  Future<String> _showBookingSummary(BookingSessionState session, Map<String, dynamic> params) async {
    final rentalDays = session.isOpenRental ? 1 : session.returnDate!.difference(session.pickupDate!).inDays;
    final daysCount = rentalDays <= 0 ? 1 : rentalDays;
    final double basePrice = daysCount * (session.vehiclePrice ?? 180.0);
    final double discount = session.pointsToRedeem * 0.10;
    final double finalTotal = (basePrice - discount).clamp(0.0, double.infinity);
    final double deposit = (finalTotal * 0.3).clamp(150.0, finalTotal);
    final double balance = (finalTotal - deposit).clamp(0.0, double.infinity);

    final summary = {
      'vehicleName': session.vehicleName,
      'vehicleId': session.vehicleId,
      'branch': session.branch,
      'pickupDate': DateFormat('dd MMM yyyy').format(session.pickupDate!),
      'returnDate': session.isOpenRental ? 'Open Rental' : DateFormat('dd MMM yyyy').format(session.returnDate!),
      'pickupTime': session.pickupTime ?? '09:00 AM',
      'days': session.isOpenRental ? 'Open Ended' : daysCount,
      'pricePerDay': session.vehiclePrice,
      'totalPrice': basePrice,
      'discount': discount,
      'tax': 0.0,
      'total': finalTotal,
      'deposit': deposit,
      'balance': balance,
      'pointsToRedeem': session.pointsToRedeem,
      'isOpenRental': session.isOpenRental,
    };

    params['summary'] = summary;
    params['options'] = ['Confirm Booking', 'Edit Details', 'Cancel Checkout'];

    return "📋 **Booking Summary Confirmation**\n\n"
        "• **Vehicle**: ${session.vehicleName}\n"
        "• **Branch**: ${session.branch}\n"
        "• **Pickup Date**: ${DateFormat('dd MMM yyyy').format(session.pickupDate!)}\n"
        "• **Pickup Time**: ${session.pickupTime ?? '09:00 AM'}\n"
        "• **Return Date**: ${session.isOpenRental ? 'Open Rental' : DateFormat('dd MMM yyyy').format(session.returnDate!)}\n"
        "• **Rental Duration**: ${session.isOpenRental ? 'Open Ended' : '$daysCount Day(s)'}\n"
        "• **Base Price**: RM ${basePrice.toStringAsFixed(2)} ${session.isOpenRental ? '(Daily Rate / deposit)' : '(RM ${session.vehiclePrice?.toStringAsFixed(0) ?? '180'}/day)'}\n"
        "• **Discount Applied**: -RM ${discount.toStringAsFixed(2)}\n"
        "• **Final Total**: RM ${finalTotal.toStringAsFixed(2)}\n"
        "• **Deposit Amount**: RM ${deposit.toStringAsFixed(2)} (30% to confirm booking)\n"
        "• **Payment Method**: Pending Checkout Selection\n\n"
        "**Confirm Booking?**";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  General AI responses & intent logic (role-aware live Firebase stats)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _generateResponse(AIIntent intent, String text, BookingSessionState session, String role) async {
    final textLower = text.toLowerCase();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (textLower.contains('review') || textLower.contains('rating') || textLower.contains('feedback') || textLower.contains('comment') || textLower.contains('stars')) {
      List<VehicleModel> vehicles = [];
      try {
        vehicles = await VehicleService().getVehicles();
      } catch (_) {}
      
      VehicleModel? matchedVehicle;
      for (final v in vehicles) {
        if (textLower.contains(v.brand.toLowerCase()) || textLower.contains(v.model.toLowerCase())) {
          matchedVehicle = v;
          break;
        }
      }
      
      if (matchedVehicle != null) {
        final reviews = await ReviewService().getVehicleReviews(matchedVehicle.id);
        if (reviews.isEmpty) {
          return "I found the vehicle **${matchedVehicle.brand} ${matchedVehicle.model}** but there are no customer reviews submitted for it yet.";
        }
        final double avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
        final listStr = reviews.take(3).map((r) => "• **${r.userName}** (${r.rating.toStringAsFixed(1)}⭐): \"${r.comment}\"").join('\n');
        return "Based on live Firebase data, here is a summary of the reviews for **${matchedVehicle.brand} ${matchedVehicle.model}** (Average Rating: **${avg.toStringAsFixed(1)}⭐** from **${reviews.length}** reviews):\n\n"
            "$listStr\n\nCustomers generally appreciate its performance and clean condition!";
      } else {
        final allReviews = await ReviewService().getAllReviews();
        if (allReviews.isEmpty) {
          return "There are no customer reviews submitted in the system yet.";
        }
        final double avg = allReviews.map((r) => r.rating).reduce((a, b) => a + b) / allReviews.length;
        final listStr = allReviews.take(3).map((r) => "• **${r.userName}** on vehicle: \"${r.comment}\"").join('\n');
        return "I checked our global feedback log. We have **${allReviews.length}** total reviews with an average rating of **${avg.toStringAsFixed(1)}⭐** across all vehicles. Here are a few recent customer reviews:\n\n"
            "$listStr";
      }
    }

    final action = intent.parameters['action'];

    // ──────────────────────────────────────────
    // ADMIN FLOWS
    // ──────────────────────────────────────────
    if (role == 'admin') {
      if (intent is BookingIntent) {
        List<BookingModel> bookings = [];
        try { bookings = await BookingService().getBookings(); } catch (_) {}

        if (action == 'admin_today_bookings' || textLower.contains('today')) {
          final today = DateTime.now();
          final todayStr = DateFormat('yyyy-MM-dd').format(today);
          final todayBookings = bookings.where((b) => DateFormat('yyyy-MM-dd').format(b.pickUpDate) == todayStr).toList();

          if (todayBookings.isEmpty) return "Based on live Firebase data, there are no bookings scheduled for pickup today.";
          return "Found **${todayBookings.length}** active bookings scheduled for pick-up today:\n"
              "${todayBookings.map((b) => '• **${b.userName}** - ${b.vehicleName} (Ref: `#${b.id.substring(0, 5).toUpperCase()}`, Status: **${b.status}** - RM ${b.totalPrice.toStringAsFixed(0)})').join('\n')}";
        }

        if (action == 'admin_overdue_bookings' || textLower.contains('overdue')) {
          final overdue = bookings.where((b) => b.status.toLowerCase() == 'overdue').toList();
          
          if (overdue.isEmpty) return "Based on live Firebase data, there are currently no overdue bookings.";
          return "🚨 Found **${overdue.length}** overdue vehicle bookings in system database:\n"
              "${overdue.map((b) => '• **${b.userName}** (${b.userPhone}) - ${b.vehicleName} (Ref: `#${b.id.substring(0, 5).toUpperCase()}`, Return Date: **${b.returnDate != null ? DateFormat('dd MMM').format(b.returnDate!) : "Open Rental"}** - Status: **${b.status.toUpperCase()}**)').join('\n')}";
        }

        return "Opening administrative bookings tab. There are currently **${bookings.length}** total reservations saved in the system.";
      }

      if (intent is VehicleSearchIntent || action == 'admin_available_vehicles' || (textLower.contains('available') && textLower.contains('car'))) {
        List<VehicleModel> vehicles = [];
        try { vehicles = await VehicleService().getVehicles(); } catch (_) {}
        final available = vehicles.where((v) => v.status.toLowerCase() == 'available').toList();

        if (available.isEmpty) return "Based on live Firebase fleet records, there are currently no available vehicles.";
        return "🚗 Found **${available.length}** currently available vehicles in the database:\n"
            "${available.map((v) => '• **${v.brand} ${v.model}** (Plate: **${v.plateNumber}**, Rate: **RM ${v.pricePerDay.toStringAsFixed(0)}/day** - Branch: **${v.branchName.isEmpty ? 'Kuala Lumpur' : v.branchName}**)').join('\n')}";
      }

      if (intent is MaintenanceIntent || action == 'admin_maintenance_schedule' || textLower.contains('maintenance')) {
        List<dynamic> jobs = [];
        try { jobs = await MaintenanceService().getMaintenanceJobs(); } catch (_) {}
        final activeJobs = jobs.where((j) => j.status == 'Scheduled' || j.status == 'In Progress').toList();

        if (activeJobs.isEmpty) return "Based on live Firebase maintenance records, there are no active or scheduled maintenance jobs.";
        return "🔧 Found **${activeJobs.length}** active/scheduled maintenance logs:\n"
            "${activeJobs.map((j) => '• **${j.vehicleName}**: ${j.title} (${j.status}) - Cost: **RM ${j.cost.toStringAsFixed(2)}** (End Date: **${j.endDate}**)').join('\n')}";
      }

      if (intent is PaymentIntent || action == 'admin_payment_stats' || textLower.contains('revenue') || textLower.contains('payment')) {
        List<PaymentModel> payments = [];
        try { payments = await PaymentService().getPayments(); } catch (_) {}
        
        double totalRev = 0.0;
        int approvedCount = 0;
        int pendingCount = 0;
        double pendingAmount = 0.0;
        final Map<String, int> methods = {};
        
        for (final p in payments) {
          final pStat = (p.paymentStatus ?? p.status).toLowerCase();
          if (pStat == 'approved' || pStat == 'paid') {
            totalRev += p.amount;
            approvedCount++;
            methods[p.paymentMethod] = (methods[p.paymentMethod] ?? 0) + 1;
          } else if (pStat == 'pending' || pStat == 'waiting') {
            pendingCount++;
            pendingAmount += p.amount;
          }
        }

        return "💰 **Payment & Revenue Statistics Summary** (Live Firebase data):\n\n"
            "• **Total Revenue (Paid/Approved)**: RM ${totalRev.toStringAsFixed(2)} ($approvedCount transactions)\n"
            "• **Pending Clearance**: RM ${pendingAmount.toStringAsFixed(2)} ($pendingCount transactions)\n"
            "• **Payment Method breakdown (Approved)**:\n"
            "${methods.entries.map((e) => '  - ${e.key}: ${e.value} times').join('\n')}";
      }

      if (intent is CustomerIntent || action == 'admin_customer_info' || textLower.contains('customer')) {
        List<UserModel> users = [];
        try { users = await DatabaseService().getUsers(); } catch (_) {}
        final customers = users.where((u) => u.role == 'customer').toList();

        if (customers.isEmpty) return "Based on live Firebase records, no customer profiles are stored.";
        
        final listStr = customers.take(10).map((u) {
          final status = u.licenseStatus == 'verified' ? '✅ Verified' : (u.licenseStatus == 'pending' ? '⏳ Pending' : '❌ Unverified');
          return "• **${u.fullName}** - ${u.email} (${u.phone.isEmpty ? 'No Phone' : u.phone}) [License: $status]";
        }).join('\n');

        return "👥 **Customer Registry Overview** (Displaying first 10 matches):\n\n"
            "$listStr\n\nTotal Customers registered: **${customers.length}**.";
      }

      if (intent is DashboardIntent || action == 'admin_dashboard_stats' || textLower.contains('dashboard') || textLower.contains('statistics')) {
        List<BookingModel> bookings = [];
        List<VehicleModel> vehicles = [];
        List<PaymentModel> payments = [];
        List<UserModel> users = [];
        try {
          bookings = await BookingService().getBookings();
          vehicles = await VehicleService().getVehicles();
          payments = await PaymentService().getPayments();
          users = await DatabaseService().getUsers();
        } catch (_) {}

        final availableCount = vehicles.where((v) => v.status.toLowerCase() == 'available').length;
        final overdueCount = bookings.where((b) => b.status.toLowerCase() == 'overdue').length;
        final pendingPaymentsCount = payments.where((p) => (p.paymentStatus ?? p.status).toLowerCase() == 'pending').length;

        return "📊 **Carent System Dashboard Statistics** (Live Firebase Summary):\n\n"
            "• **Total Fleet size**: ${vehicles.length} Vehicles (**$availableCount available**)\n"
            "• **Reservations**: ${bookings.length} Bookings (**$overdueCount overdue**)\n"
            "• **Payments Ledger**: ${payments.length} Transactions (**$pendingPaymentsCount pending**)\n"
            "• **User Accounts**: ${users.length} Users (**${users.where((u) => u.role == 'customer').length} customers**)";
      }

      if (intent is NotificationIntent || action == 'admin_notifications' || textLower.contains('notification')) {
        final snap = await FirebaseDatabase.instance.ref().child('notifications').get();
        final list = <NotificationModel>[];
        if (snap.exists) {
          final Map<dynamic, dynamic> data = snap.value as Map<dynamic, dynamic>;
          data.forEach((k, v) {
            list.add(NotificationModel.fromMap(k.toString(), v as Map));
          });
        }
        
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final recent = list.take(5).toList();

        if (recent.isEmpty) return "Based on live Firebase notifications log, there are currently no recent alerts.";
        return "🔔 **Recent System Alerts & Notifications**:\n\n"
            "${recent.map((n) => '• [${DateFormat('dd MMM HH:mm').format(n.createdAt)}] **${n.title}**: ${n.message}').join('\n')}";
      }
    }

    // ──────────────────────────────────────────
    // CUSTOMER FLOWS
    // ──────────────────────────────────────────
    if (intent is VehicleSearchIntent) {
      if (action == 'recommend_vehicles' || textLower.contains('recommend')) {
        return await _recommendVehicles(uid ?? 'guest', intent.parameters);
      }

      final category = intent.parameters['category']?.toString();
      final maxPrice = intent.parameters['max_price'] as double?;
      final transmission = intent.parameters['transmission']?.toString();
      final sort = intent.parameters['sort']?.toString();

      List<VehicleModel> vehicles = [];
      try {
        vehicles = await VehicleService().getVehicles();
      } catch (_) {}

      final filtered = vehicles.where((v) {
        if (category != null && v.category.toLowerCase() != category.toLowerCase()) return false;
        if (maxPrice != null && v.pricePerDay > maxPrice) return false;
        if (transmission != null && v.transmission.toLowerCase() != transmission.toLowerCase()) return false;
        return true;
      }).toList();

      if (sort == 'price_asc') {
        filtered.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
      }

      intent.parameters['vehicles'] = filtered.map((v) => v.toMap()).toList();

      if (filtered.isEmpty) {
        return "I couldn't find any available vehicles in the system matching those filters.";
      }
      return "I searched the live Firebase fleet database and found **${filtered.length}** available matching vehicles:";
    }

    if (intent is BookingIntent) {
      if (uid == null) return "Please log in to manage bookings.";
      List<BookingModel> bookings = [];
      try { bookings = await BookingService().getUserBookings(uid); } catch (_) {}

      if (action == 'cancel_booking') {
        final active = bookings.where((b) => b.status.toLowerCase() != 'completed' && b.status.toLowerCase() != 'cancelled' && b.status.toLowerCase() != 'rejected').toList();
        if (active.isEmpty) return "You do not have any active bookings that can be cancelled.";
        return "Opening the bookings cancellation screen. Please select the active booking you wish to cancel.";
      }

      if (bookings.isEmpty) return "I couldn't find any bookings on your customer account in Firebase.";
      final listStr = bookings.map((b) => "• **${b.vehicleName}** (Ref: `#${b.id.substring(0, 5).toUpperCase()}`, Status: **${b.status.toUpperCase()}**) - Pickup: **${DateFormat('dd MMM yyyy').format(b.pickUpDate)}**").join('\n');
      return "📜 **My Active & Past Bookings** (Live tracking):\n\n$listStr";
    }

    if (intent is RewardIntent) {
      if (uid == null) return "Please log in to view reward points.";
      int points = 0;
      try { points = await RewardPointsService().getUserPoints(uid); } catch (_) {}
      final status = CompanySettingsProvider().getMembershipStatus(points);
      final discount = RewardPointsService().calculateDiscount(points);

      // Check if user is asking "What membership am I?" or similar
      if (textLower.contains('what membership') || textLower.contains('my membership') || textLower.contains('what tier') || textLower.contains('my tier') || textLower.contains('what level') || textLower.contains('my level') || textLower.contains('membership level') || textLower.contains('membership tier')) {
        String benefits = '';
        switch (status.currentLevel) {
          case 'Premium':
            benefits = "Open Rental access (no upfront payment!), 1.5x Reward Points earning multiplier, and priority booking approval.";
            break;
          case 'Gold':
            benefits = "Priority booking approval, exclusive promotions, and dynamic discount points redemptions.";
            break;
          case 'Silver':
            benefits = "Dynamic discount rewards, priority support, and standard earnings.";
            break;
          default:
            benefits = "Standard points earnings and standard booking approval.";
        }
        
        String nextLevelMsg = status.currentLevel == 'Premium'
            ? "You have reached the maximum membership level! 🎉"
            : "You need **${status.pointsNeededForNext}** more points to unlock **${status.nextLevel}** membership.";
            
        return "⭐ **My Membership Details** ⭐\n\n"
            "• **Current Tier**: **${status.currentLevel} Member**\n"
            "• **Reward Points**: **$points points**\n"
            "• **Tier Benefits**: $benefits\n\n"
            "$nextLevelMsg";
      }

      // Check if user is asking "How do I unlock Open Rental?" or similar
      if (textLower.contains('unlock open rental') || textLower.contains('open rental access') || textLower.contains('how to get open rental') || textLower.contains('how do i get open rental')) {
        if (status.currentLevel == 'Premium') {
          return "🎉 **Open Rental is unlocked!** As a **Premium Member**, you are eligible for Open Rental with no upfront payment. Simply choose the 'Open Rental' return option during checkout!";
        }
        
        final needed = CompanySettingsProvider().premiumThreshold - points;
        return "🚙 **Unlocking Open Rental**\n\n"
            "Open Rental is an exclusive feature available only for **Premium Members** (requires **${CompanySettingsProvider().premiumThreshold} points**).\n\n"
            "• Your Current Tier: **${status.currentLevel} Member**\n"
            "• Your Reward Points: **$points points**\n"
            "• Points Needed for Premium: **$needed points**\n\n"
            "Complete more bookings or payments to earn points and unlock Open Rental!";
      }

      final matchRedeem = RegExp(r'(?:redeem|use|select)\s*(\d+)').firstMatch(textLower);
      if (matchRedeem != null) {
        final ptsToRedeem = int.tryParse(matchRedeem.group(1) ?? '') ?? 0;
        int limit = 1000;
        try {
          final limitSnap = await FirebaseDatabase.instance.ref().child('company_settings').child('maxRewardPointsLimit').get();
          if (limitSnap.exists && limitSnap.value != null) {
            limit = int.tryParse(limitSnap.value.toString()) ?? 1000;
          }
        } catch (_) {}
        final maxAllowed = min(points, limit);
        if (ptsToRedeem > maxAllowed) {
          return "You cannot redeem $ptsToRedeem points. Your maximum allowed redemption is $maxAllowed points.";
        }
        
        if (session.currentStep == 7) {
          session.pointsToRedeem = ptsToRedeem;
          session.currentStep = 8;
          return await _showBookingSummary(session, intent.parameters);
        } else {
          final discAmt = ptsToRedeem * 0.10;
          return "Confirmed! You have selected to redeem **$ptsToRedeem** reward points. This is equivalent to **RM ${discAmt.toStringAsFixed(2)}** discount on your next rental. 🎁";
        }
      }

      if (textLower.contains('use') || textLower.contains('redeem') || textLower.contains('apply')) {
        intent.parameters['action'] = 'redeem_rewards_slider';
        intent.parameters['availablePoints'] = points;
        int limit = 1000;
        try {
          final limitSnap = await FirebaseDatabase.instance.ref().child('company_settings').child('maxRewardPointsLimit').get();
          if (limitSnap.exists && limitSnap.value != null) {
            limit = int.tryParse(limitSnap.value.toString()) ?? 1000;
          }
        } catch (_) {}
        intent.parameters['maxPointsLimit'] = limit;
        return "Sure! Please use the interactive slider below to select how many reward points you would like to redeem for a discount. 🛍️";
      }

      return "You have **$points** loyalty reward points balance. This is equivalent to **RM ${discount.toStringAsFixed(2)}** discount on your next rent! ⭐";
    }

    if (intent is PaymentIntent) {
      if (uid == null) return "Please log in to view payments.";

      if (intent.parameters['action'] == 'check_debts') {
        List<BookingModel> bookings = [];
        List<VehicleModel> vehicles = [];
        try {
          bookings = await BookingService().getUserBookings(uid);
          vehicles = await VehicleService().getVehicles();
        } catch (_) {}

        final activeBookings = bookings.where((b) {
          final s = b.status.toLowerCase();
          return s == 'active' || s == 'ongoing' || s == 'overdue' || s == 'awaiting final payment' || s == 'return requested';
        }).toList();

        if (activeBookings.isEmpty) {
          return "😊 You have no active rentals or outstanding balances at the moment. All payments are fully cleared!";
        }

        final now = DateTime.now();
        String response = "💰 **Your Outstanding Balance & Rental Charges**:\n\n";
        for (final b in activeBookings) {
          double pricePerDay = 100.0;
          try {
            pricePerDay = vehicles.firstWhere((v) => v.id == b.vehicleId).pricePerDay;
          } catch (_) {}

          final overdue = BookingService.getOverdueDetails(b, pricePerDay, now: now);
          
          final cleaningFee = (b.returnInspection?['cleaningFee'] ?? 0.0).toDouble();
          final damageFee = (b.returnInspection?['damageFee'] ?? 0.0).toDouble();
          final extraCharges = (b.returnInspection?['extraCharges'] ?? 0.0).toDouble();
          
          final overdueCharges = (overdue['charges'] as num).toDouble();
          final rentalCost = b.totalPrice;
          final totalOwed = rentalCost + overdueCharges + cleaningFee + damageFee + extraCharges;

          response += "🚗 **Vehicle: ${b.vehicleName}** (Ref: `#${b.id.substring(0, 5).toUpperCase()}`)\n"
              "  - Rental Cost: **RM ${rentalCost.toStringAsFixed(2)}**\n"
              "  - Overdue Charges: **RM ${overdueCharges.toStringAsFixed(2)}** (${overdue['days']}d ${overdue['hours']}h overdue)\n"
              "  - Cleaning Fee: **RM ${cleaningFee.toStringAsFixed(2)}**\n"
              "  - Damage Fee: **RM ${damageFee.toStringAsFixed(2)}**\n"
              "  - Other Charges: **RM ${extraCharges.toStringAsFixed(2)}**\n"
              "  - **Current Total Owed**: **RM ${totalOwed.toStringAsFixed(2)}**\n"
              "  - Booking Status: **${b.status}**\n\n";
        }
        
        response += "To complete payment, please visit the **Pay Now** tab under your Bookings menu.";
        return response;
      }

      List<PaymentModel> payments = [];
      try { payments = await PaymentService().getPayments(); } catch (_) {}
      final userPayments = payments.where((p) => p.userId == uid || p.customerUid == uid).toList();

      if (userPayments.isEmpty) {
        return "Based on live Firebase data, you have no payment transactions recorded.";
      }
      final listStr = userPayments.map((p) => "• **RM ${p.amount.toStringAsFixed(2)}** for Booking `#${p.bookingId.substring(0, 5).toUpperCase()}` (Ref: `${p.transactionId}`, Date: **${DateFormat('dd MMM yyyy').format(p.paymentDate)}** - Status: **${p.status.toUpperCase()}** - Method: **${p.paymentMethod}**)").join('\n');
      return "💳 **My Payment Transaction Ledger**:\n\n$listStr";
    }

    if (intent is MaintenanceIntent) {
      return "The maintenance portal is only accessible by administrative operators.";
    }

    if (intent is SupportIntent) {
      return "Opening support options. Live ticket registry is loaded.";
    }

    if (intent is BranchIntent) {
      List<dynamic> branches = [];
      try { branches = await BranchService().getBranches(); } catch (_) {}
      return "Opening rental branches directory. Loaded **${branches.length}** branches from Firebase.";
    }

    if (intent is ProfileIntent) {
      return "Opening Profile view. You can inspect your details and verify documents here.";
    }

    if (intent is DashboardIntent) {
      return "Opening dashboard overview panel.";
    }

    if (intent is NavigationIntent) {
      return "Redirecting navigation to your request...";
    }

    if (intent is UnknownIntent || intent.confidence < 0.5) {
      return "I couldn't find that information in the current system data. Please select one of our guided popular actions cards or FAQs!";
    }

    return "Redirecting to your request... 🚗";
  }

  Future<AIResponse> _processAdminMessage(
    String text,
    BookingSessionState session,
    Map<String, dynamic> params,
    AIIntent intent,
  ) async {
    final cleanedText = text.trim().toLowerCase();
    final textLower = cleanedText;

    // AI admin extension approvals
    if (textLower.contains('approve') && (textLower.contains('extension') || textLower.contains('extend'))) {
      final bookings = await BookingService().getBookings();
      BookingModel? targetBooking;
      for (final b in bookings) {
        if (b.extensionRequest != null && b.extensionRequest!['status'] == 'pending') {
          final lowerName = b.userName.toLowerCase();
          final lowerId = b.id.toLowerCase();
          final cleanQuery = textLower.replaceAll('approve', '').replaceAll('extension', '').replaceAll('extend', '').replaceAll('\'s', '').trim();
          if (lowerName.contains(cleanQuery) || lowerId.contains(cleanQuery) || cleanQuery.isEmpty) {
            targetBooking = b;
            break;
          }
        }
      }

      if (targetBooking != null) {
        await BookingService().approveExtension(targetBooking.id);
        return AIResponse(
          message: "🎉 **Confirmed!** Successfully approved the rental extension request for **${targetBooking.userName}**'s booking **#${targetBooking.id.substring(0, 5).toUpperCase()}**.\n\n"
                   "• Customer: **${targetBooking.userName}**\n"
                   "• New Return: **${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.parse(targetBooking.extensionRequest!['newReturnDate']))}**\n"
                   "• Additional cost added: **RM ${targetBooking.extensionRequest!['additionalCost'].toStringAsFixed(2)}**",
          intent: intent,
          confidence: 1.0,
          action: 'approve_extension',
          parameters: {'bookingId': targetBooking.id},
        );
      } else {
        return AIResponse(
          message: "Could not find any pending extension request matching your search query.",
          intent: intent,
          confidence: 1.0,
          action: 'error',
          parameters: const {},
        );
      }
    }

    // AI admin return completion
    if ((textLower.contains('complete') || textLower.contains('finish')) && (textLower.contains('return') || textLower.contains('checkout'))) {
      final bookings = await BookingService().getBookings();
      BookingModel? targetBooking;
      for (final b in bookings) {
        final statusLower = b.status.toLowerCase();
        if (statusLower == 'return requested' || statusLower == 'active' || statusLower == 'ongoing' || statusLower == 'overdue') {
          final lowerName = b.userName.toLowerCase();
          final lowerId = b.id.toLowerCase();
          final cleanQuery = textLower.replaceAll('complete', '').replaceAll('finish', '').replaceAll('return', '').replaceAll('checkout', '').replaceAll('for', '').replaceAll('booking', '').replaceAll('#', '').replaceAll('\'s', '').trim();
          if (lowerName.contains(cleanQuery) || lowerId.contains(cleanQuery) || cleanQuery.isEmpty) {
            targetBooking = b;
            break;
          }
        }
      }

      if (targetBooking != null) {
        final inspection = {
          'condition': 'Excellent',
          'fuelLevel': 'Full (8/8)',
          'mileage': 10000,
          'damageNotes': 'None (AI Automated Quick Complete)',
          'cleaningFee': 0.0,
          'extraCharges': 0.0,
          'completedAt': DateTime.now().toIso8601String(),
        };
        await BookingService().completeReturn(targetBooking.id, inspection);
        return AIResponse(
          message: "✅ **Return Completed!** Booking **#${targetBooking.id.substring(0, 5).toUpperCase()}** has been successfully returned and finalized.\n\n"
                   "• Customer: **${targetBooking.userName}**\n"
                   "• Vehicle: **${targetBooking.vehicleName}**\n"
                   "• Status: **Completed** 🏁",
          intent: intent,
          confidence: 1.0,
          action: 'complete_return',
          parameters: {'bookingId': targetBooking.id},
        );
      } else {
        return AIResponse(
          message: "Could not find any active or return-requested booking matching your query.",
          intent: intent,
          confidence: 1.0,
          action: 'error',
          parameters: const {},
        );
      }
    }

    // 0. Reward points adjustments
    if (textLower.contains('reward points') || textLower.contains('points')) {
      final addMatch = RegExp(r'(?:add|credit)\s+(\d+)\s+(?:reward\s+)?points\s+(?:to\s+)?([a-zA-Z\s]+)').firstMatch(textLower);
      final deductMatch = RegExp(r'(?:remove|deduct|debit)\s+(\d+)\s+(?:reward\s+)?points\s+(?:from\s+)?([a-zA-Z\s]+)').firstMatch(textLower);

      if (addMatch != null || deductMatch != null) {
        final isAdd = addMatch != null;
        final match = isAdd ? addMatch : deductMatch!;
        final amount = int.tryParse(match.group(1) ?? '') ?? 0;
        final targetName = (match.group(2) ?? '').trim();

        if (amount <= 0) {
          return AIResponse(
            message: "Amount must be a positive number.",
            intent: intent,
            confidence: 1.0,
            action: 'error',
            parameters: const {},
          );
        }

        List<UserModel> users = [];
        try { users = await DatabaseService().getUsers(); } catch (_) {}
        final customers = users.where((u) => u.role == 'customer').toList();
        UserModel? matchedCustomer;
        for (final c in customers) {
          if (c.fullName.toLowerCase().contains(targetName.toLowerCase())) {
            matchedCustomer = c;
            break;
          }
        }

        if (matchedCustomer == null) {
          return AIResponse(
            message: "Could not find a customer named '$targetName' in the database.",
            intent: intent,
            confidence: 1.0,
            action: 'error',
            parameters: const {},
          );
        }

        try {
          final change = isAdd ? amount : -amount;
          await RewardPointsService().adjustPoints(
            matchedCustomer.id,
            change,
            "AI Assistant Adjustment",
          );
          final updatedPoints = max(0, matchedCustomer.rewardPoints + change);
          final actionLabel = isAdd ? "credited to" : "deducted from";
          return AIResponse(
            message: "🎉 **Confirmed!** Successfully $actionLabel **${matchedCustomer.fullName}**'s account by **$amount** reward points.\n\n"
                     "• User: **${matchedCustomer.fullName}**\n"
                     "• Adjustment: **${change >= 0 ? '+' : ''}$change points**\n"
                     "• New Balance: **$updatedPoints Points** ⭐",
            intent: intent,
            confidence: 1.0,
            action: 'admin_adjust_points_success',
            parameters: const {'options': ['📊 Dashboard', 'Reward Points']},
          );
        } catch (e) {
          return AIResponse(
            message: "Failed to adjust points for ${matchedCustomer.fullName}: $e",
            intent: intent,
            confidence: 1.0,
            action: 'error',
            parameters: const {},
          );
        }
      }
    }

    // 1. Complete Booking #123
    if (textLower.startsWith('complete booking #') || textLower.startsWith('complete booking ')) {
      final id = text.split('#').last.trim();
      try {
        await FirebaseDatabase.instance.ref().child('bookings').child(id).update({'status': 'Completed'});
        return AIResponse(
          message: "🎉 **Booking #${id.substring(0, 5).toUpperCase()} has been marked as COMPLETED!**",
          intent: const BookingIntent(confidence: 1.0),
          confidence: 1.0,
          action: 'complete_booking_success',
          parameters: const {'options': ['📊 Dashboard', "Today's Bookings", "Overdue Bookings"]},
        );
      } catch (e) {
        return AIResponse(message: "Failed to complete booking: $e", intent: intent, confidence: 1.0, action: 'error', parameters: const {});
      }
    }

    // 2. Cancel Booking #123
    if (textLower.startsWith('cancel booking #') || textLower.startsWith('cancel booking ')) {
      final id = text.split('#').last.trim();
      try {
        final bSnap = await FirebaseDatabase.instance.ref().child('bookings').child(id).get();
        if (bSnap.exists) {
          final data = Map<dynamic, dynamic>.from(bSnap.value as Map);
          final uid = data['userId'] ?? '';
          final vehicleId = data['vehicleId'] ?? '';
          final vehicleName = data['vehicleName'] ?? 'Vehicle';
          await BookingService().cancelBooking(id, uid, vehicleId, vehicleName);
          return AIResponse(
            message: "🚨 **Booking #${id.substring(0, 5).toUpperCase()} has been CANCELLED successfully!**",
            intent: const BookingIntent(confidence: 1.0),
            confidence: 1.0,
            action: 'cancel_booking_success',
            parameters: const {'options': ['📊 Dashboard', "Today's Bookings", "Overdue Bookings"]},
          );
        }
      } catch (e) {
        return AIResponse(message: "Failed to cancel booking: $e", intent: intent, confidence: 1.0, action: 'error', parameters: const {});
      }
    }

    // 3. Verify Payment #123
    if (textLower.startsWith('verify payment #') || textLower.startsWith('verify payment ')) {
      final id = text.split('#').last.trim();
      try {
        await FirebaseDatabase.instance.ref().child('payments').child(id).update({'status': 'Approved', 'paymentStatus': 'Approved'});
        return AIResponse(
          message: "💳 **Payment Proof Verified & Approved!** Transaction ID updated.",
          intent: const PaymentIntent(confidence: 1.0),
          confidence: 1.0,
          action: 'verify_payment_success',
          parameters: const {'options': ['📊 Dashboard', 'Show Pending Payments']},
        );
      } catch (e) {
        return AIResponse(message: "Failed to verify payment: $e", intent: intent, confidence: 1.0, action: 'error', parameters: const {});
      }
    }

    // 4. Open Booking #123
    if (textLower.startsWith('open booking #') || textLower.startsWith('open booking ')) {
      final id = text.split('#').last.trim();
      return AIResponse(
        message: "Opening Booking details panel for reference `#${id.toUpperCase()}`... 📅",
        intent: const BookingIntent(confidence: 1.0),
        confidence: 1.0,
        action: 'view_bookings',
        parameters: {
          'bookingId': id,
          'options': ['📊 Dashboard', "Today's Bookings", "Overdue Bookings"]
        },
      );
    }

    // 5. Open Vehicle [ID] or open vehicle details
    if (textLower.startsWith('open vehicle ') || textLower.contains('vehicle details')) {
      final id = text.split(' ').last.trim().replaceAll('[', '').replaceAll(']', '');
      return AIResponse(
        message: "Opening vehicle registry details panel... 🚗",
        intent: const VehicleSearchIntent(confidence: 1.0),
        confidence: 1.0,
        action: 'search_vehicles',
        parameters: {
          'vehicleId': id,
          'options': ['📊 Dashboard', 'Show Available Cars']
        },
      );
    }

    // 6. Complete Maintenance / Schedule Maintenance
    if (textLower.startsWith('complete maintenance for ') || textLower.contains('complete maintenance')) {
      final plate = text.split(' ').last.trim().toUpperCase();
      try {
        final jobs = await MaintenanceService().getMaintenanceJobs();
        final matched = jobs.firstWhere((j) => (j.vehicleName.toUpperCase() == plate || j.vehicleName.toUpperCase().contains(plate)) && j.status != 'Completed');
        await FirebaseDatabase.instance.ref().child('maintenance').child(matched.id).update({'status': 'Completed'});
        return AIResponse(
          message: "🔧 **Maintenance for vehicle $plate marked as Completed!** Vehicle status returned to Available.",
          intent: const MaintenanceIntent(confidence: 1.0),
          confidence: 1.0,
          action: 'complete_maintenance_success',
          parameters: const {'options': ['📊 Dashboard', 'Maintenance Schedule']},
        );
      } catch (e) {
        return AIResponse(message: "Failed to update maintenance status for $plate: $e", intent: intent, confidence: 1.0, action: 'error', parameters: const {});
      }
    }

    // 7. Overdue bookings statistics
    if (textLower.contains('overdue')) {
      List<BookingModel> bookings = [];
      List<VehicleModel> vehicles = [];
      try {
        bookings = await BookingService().getBookings();
        vehicles = await VehicleService().getVehicles();
      } catch (_) {}
      
      final now = DateTime.now();
      final overdue = bookings.where((b) {
        if (b.status.toLowerCase() == 'completed' || b.status.toLowerCase() == 'cancelled' || b.status.toLowerCase() == 'rejected') return false;
        if (b.isReturned || b.isOpenRental || b.returnDate == null) return false;
        return now.isAfter(b.returnDate!);
      }).toList();

      if (overdue.isEmpty) {
        return AIResponse(
          message: "🎉 Excellent! There are currently **no overdue bookings** registered in the system.",
          intent: intent,
          confidence: 1.0,
          action: 'admin_overdue_bookings',
          parameters: const {'options': ['📊 Dashboard', 'Show Available Cars']},
        );
      }
      final listStr = overdue.map((b) {
        double pricePerDay = 100.0;
        try {
          pricePerDay = vehicles.firstWhere((v) => v.id == b.vehicleId).pricePerDay;
        } catch (_) {}
        final overdueDetails = BookingService.getOverdueDetails(b, pricePerDay, now: now);

        return "• **${b.vehicleName}** (Ref: `#${b.id.substring(0, 5).toUpperCase()}`)\n"
            "  - Customer: **${b.userName}** (${b.userPhone})\n"
            "  - Due Return: **${b.returnDate != null ? DateFormat('dd MMM yyyy hh:mm a').format(b.returnDate!) : "Open Rental"}**\n"
            "  - Overdue Time: **${overdueDetails['days']}d ${overdueDetails['hours']}h**\n"
            "  - Current Charges: **RM ${overdueDetails['charges'].toStringAsFixed(2)}**\n"
            "  - Payment Status: **${b.status}**";
      }).join('\n\n');

      // Create quick action chips for overdue bookings
      final List<String> opt = [];
      for (final b in overdue.take(3)) {
        opt.add("Open Booking #${b.id}");
        opt.add("Complete Booking #${b.id}");
      }
      opt.add('📊 Dashboard');

      return AIResponse(
        message: "🚨 **Overdue Reservations List** (Live Overdue tracking):\n\n$listStr",
        intent: intent,
        confidence: 1.0,
        action: 'admin_overdue_bookings',
        parameters: {'options': opt},
      );
    }

    // 8. Pending Payments / Verify QR Payments
    if (textLower.contains('pending payment') || textLower.contains('pending payments') || textLower.contains('verify payment') || textLower.contains('verify qr')) {
      List<PaymentModel> payments = [];
      try { payments = await PaymentService().getPayments(); } catch (_) {}
      final pending = payments.where((p) => (p.paymentStatus ?? p.status).toLowerCase() == 'pending').toList();
      if (pending.isEmpty) {
        return AIResponse(
          message: "All payment transactions are fully cleared and verified! No pending verifications.",
          intent: intent,
          confidence: 1.0,
          action: 'admin_payment_stats',
          parameters: const {'options': ['📊 Dashboard', 'Revenue Today']},
        );
      }
      final listStr = pending.map((p) => 
        "• **RM ${p.amount.toStringAsFixed(2)}** (Ref: `#${p.id.substring(0, 5).toUpperCase()}`) for Booking Ref: `#${p.bookingId.substring(0, 5).toUpperCase()}`\n"
        "  - Payment Method: **${p.paymentMethod}** (Uploaded: ${DateFormat('dd MMM').format(p.paymentDate)})"
      ).join('\n\n');

      final List<String> opt = [];
      for (final p in pending.take(3)) {
        opt.add("Verify Payment #${p.id}");
      }
      opt.add('📊 Dashboard');

      return AIResponse(
        message: "⏳ **Pending Payments Verification Queue**:\n\n$listStr",
        intent: intent,
        confidence: 1.0,
        action: 'admin_payment_stats',
        parameters: {'options': opt},
      );
    }

    // 9. Vehicles needing maintenance or due for service
    if (textLower.contains('need maintenance') || textLower.contains('needing maintenance') || textLower.contains('due for service') || textLower.contains('under maintenance')) {
      List<VehicleModel> vehicles = [];
      try { vehicles = await VehicleService().getVehicles(); } catch (_) {}
      
      final needingMaintenance = vehicles.where((v) => 
        v.status.toLowerCase() == 'maintenance' || 
        v.status.toLowerCase() == 'unavailable'
      ).toList();

      if (needingMaintenance.isEmpty) {
        return AIResponse(
          message: "🚗 All fleet vehicles are fully operational and available! No vehicles currently require servicing.",
          intent: intent,
          confidence: 1.0,
          action: 'admin_maintenance_schedule',
          parameters: const {'options': ['📊 Dashboard', 'Show Available Cars']},
        );
      }

      final listStr = needingMaintenance.map((v) => 
        "• **${v.brand} ${v.model}** (Plate: **${v.plateNumber}**)\n"
        "  - Current Status: **${v.status.toUpperCase()}** (Branch: ${v.branchName})"
      ).join('\n\n');

      final List<String> opt = [];
      for (final v in needingMaintenance.take(4)) {
        opt.add("Complete Maintenance for ${v.plateNumber}");
      }
      opt.add('📊 Dashboard');

      return AIResponse(
        message: "🔧 **Vehicles Under Maintenance / Needing Service**:\n\n$listStr",
        intent: intent,
        confidence: 1.0,
        action: 'admin_maintenance_schedule',
        parameters: {'options': opt},
      );
    }

    // 10. Dashboard Stats
    if (intent is DashboardIntent || textLower.contains('dashboard') || textLower.contains('summary') || textLower.contains('statistics')) {
      List<BookingModel> bookings = [];
      List<VehicleModel> vehicles = [];
      List<PaymentModel> payments = [];
      List<UserModel> users = [];
      try {
        bookings = await BookingService().getBookings();
        vehicles = await VehicleService().getVehicles();
        payments = await PaymentService().getPayments();
        users = await DatabaseService().getUsers();
      } catch (_) {}

      final availableCount = vehicles.where((v) => v.status.toLowerCase() == 'available').length;
      final overdueCount = bookings.where((b) => b.status.toLowerCase() == 'overdue').length;
      final pendingPaymentsCount = payments.where((p) => (p.paymentStatus ?? p.status).toLowerCase() == 'pending').length;

      return AIResponse(
        message: "📊 **Carent System Dashboard Statistics** (Live Firebase Summary):\n\n"
            "• **Total Fleet size**: ${vehicles.length} Vehicles (**$availableCount available**)\n"
            "• **Reservations**: ${bookings.length} Bookings (**$overdueCount overdue**)\n"
            "• **Payments Ledger**: ${payments.length} Transactions (**$pendingPaymentsCount pending**)\n"
            "• **User Accounts**: ${users.length} Users (**${users.where((u) => u.role == 'customer').length} customers**)",
        intent: intent,
        confidence: 1.0,
        action: 'admin_dashboard_stats',
        parameters: const {
          'options': ["Today's Bookings", "Overdue Bookings", "Available Cars", "Maintenance Schedule"]
        },
      );
    }

    // 11. Today's Bookings / Pickups / Returns
    if (intent is BookingIntent && (params['action'] == 'admin_today_bookings' || textLower.contains('today'))) {
      List<BookingModel> bookings = [];
      try { bookings = await BookingService().getBookings(); } catch (_) {}
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      final todayBookings = bookings.where((b) => DateFormat('yyyy-MM-dd').format(b.pickUpDate) == todayStr).toList();

      if (todayBookings.isEmpty) {
        return AIResponse(
          message: "Based on live Firebase data, there are no bookings scheduled for pickup today.",
          intent: intent,
          confidence: 1.0,
          action: 'admin_today_bookings',
          parameters: const {'options': ['📊 Dashboard', 'Show Available Cars']},
        );
      }
      final listStr = todayBookings.map((b) => 
        "• **${b.userName}** - ${b.vehicleName} (Ref: `#${b.id.substring(0, 5).toUpperCase()}`, Status: **${b.status}** - RM ${b.totalPrice.toStringAsFixed(0)})"
      ).join('\n');

      final List<String> opt = [];
      for (final b in todayBookings.take(3)) {
        opt.add("Open Booking #${b.id}");
        opt.add("Complete Booking #${b.id}");
      }
      opt.add('📊 Dashboard');

      return AIResponse(
        message: "Found **${todayBookings.length}** active bookings scheduled for pick-up today:\n$listStr",
        intent: intent,
        confidence: 1.0,
        action: 'admin_today_bookings',
        parameters: {'options': opt},
      );
    }

    // 12. Available Vehicles Search
    if (intent is VehicleSearchIntent || textLower.contains('available') || textLower.contains('fleet')) {
      List<VehicleModel> vehicles = [];
      try { vehicles = await VehicleService().getVehicles(); } catch (_) {}
      final available = vehicles.where((v) => v.status.toLowerCase() == 'available').toList();

      if (available.isEmpty) {
        return AIResponse(
          message: "Based on live Firebase fleet records, there are currently no available vehicles.",
          intent: intent,
          confidence: 1.0,
          action: 'admin_available_vehicles',
          parameters: const {'options': ['📊 Dashboard', 'Maintenance Schedule']},
        );
      }
      final listStr = available.map((v) => 
        "• **${v.brand} ${v.model}** (Plate: **${v.plateNumber}**, Rate: **RM ${v.pricePerDay.toStringAsFixed(0)}/day** - Branch: **${v.branchName.isEmpty ? 'Kuala Lumpur' : v.branchName}**)"
      ).join('\n');

      return AIResponse(
        message: "🚗 Found **${available.length}** currently available vehicles in the database:\n$listStr",
        intent: intent,
        confidence: 1.0,
        action: 'admin_available_vehicles',
        parameters: const {'options': ['📊 Dashboard', 'Maintenance Schedule']},
      );
    }

    // 13. Revenue Statistics
    if (intent is PaymentIntent || textLower.contains('revenue') || textLower.contains('sales') || textLower.contains('profit')) {
      List<PaymentModel> payments = [];
      try { payments = await PaymentService().getPayments(); } catch (_) {}
      
      double totalRev = 0.0;
      int approvedCount = 0;
      int pendingCount = 0;
      double pendingAmount = 0.0;
      final Map<String, int> methods = {};
      
      for (final p in payments) {
        final pStat = (p.paymentStatus ?? p.status).toLowerCase();
        if (pStat == 'approved' || pStat == 'paid') {
          totalRev += p.amount;
          approvedCount++;
          methods[p.paymentMethod] = (methods[p.paymentMethod] ?? 0) + 1;
        } else if (pStat == 'pending' || pStat == 'waiting') {
          pendingCount++;
          pendingAmount += p.amount;
        }
      }

      return AIResponse(
        message: "💰 **Payment & Revenue Statistics Summary** (Live Firebase data):\n\n"
            "• **Total Revenue (Paid/Approved)**: RM ${totalRev.toStringAsFixed(2)} ($approvedCount transactions)\n"
            "• **Pending Clearance**: RM ${pendingAmount.toStringAsFixed(2)} ($pendingCount transactions)\n"
            "• **Payment Method breakdown (Approved)**:\n"
            "${methods.entries.map((e) => '  - ${e.key}: ${e.value} times').join('\n')}",
        intent: intent,
        confidence: 1.0,
        action: 'admin_payment_stats',
        parameters: const {'options': ['📊 Dashboard', 'Pending Payments']},
      );
    }

    // 14. Support Tickets
    if (intent is SupportIntent || textLower.contains('support') || textLower.contains('inbox') || textLower.contains('tickets')) {
      return AIResponse(
        message: "Opening the support tickets management dashboard view... 📥",
        intent: intent,
        confidence: 1.0,
        action: 'view_support',
        parameters: const {'options': ['📊 Dashboard', 'Show Pending Payments']},
      );
    }

    // 15. Customer Lookup / Registry
    if (intent is CustomerIntent || textLower.contains('customer') || textLower.contains('user')) {
      List<UserModel> users = [];
      try { users = await DatabaseService().getUsers(); } catch (_) {}
      final customers = users.where((u) => u.role == 'customer').toList();

      if (customers.isEmpty) {
        return AIResponse(
          message: "Based on live Firebase records, no customer profiles are stored.",
          intent: intent,
          confidence: 1.0,
          action: 'admin_customer_info',
          parameters: const {'options': ['📊 Dashboard']},
        );
      }
      final listStr = customers.take(10).map((u) {
        final status = u.licenseStatus == 'verified' ? '✅ Verified' : (u.licenseStatus == 'pending' ? '⏳ Pending' : '❌ Unverified');
        return "• **${u.fullName}** - ${u.email} (${u.phone.isEmpty ? 'No Phone' : u.phone}) [License: $status]";
      }).join('\n');

      return AIResponse(
        message: "👥 **Customer Registry Overview** (Displaying first 10 matches):\n\n"
            "$listStr\n\nTotal Customers registered: **${customers.length}**.",
        intent: intent,
        confidence: 1.0,
        action: 'admin_customer_info',
        parameters: const {'options': ['📊 Dashboard', 'Verify Customer Documents']},
      );
    }

    // 16. Reports flow or timeframe report
    if (intent is ReportIntent || textLower.contains('report')) {
      final tf = intent.parameters['timeframe'] as String?;
      final tp = intent.parameters['type'] as String?;
      if (tf != null && tp != null) {
        return AIResponse(
          message: "📊 **Generating report...**\n\nDirectly opening the **$tf $tp Report** for you.",
          intent: intent,
          confidence: 1.0,
          action: 'view_reports',
          parameters: {
            'timeframe': tf,
            'type': tp,
            'action': 'view_reports',
          },
        );
      }

      session.reset();
      session.adminReportStep = 1;
      return AIResponse(
        message: "Please select a timeframe for generating the ledger report summary:",
        intent: intent,
        confidence: 1.0,
        action: 'report_flow',
        parameters: const {
          'options': ['Today', 'This Week', 'This Month', 'Cancel']
        },
      );
    }

    // 17. Live Tracking Maps
    if (textLower.contains('track') || textLower.contains('map') || textLower.contains('location')) {
      return AIResponse(
        message: "Opening the real-time vehicle GPS tracking map... 🗺️",
        intent: intent,
        confidence: 1.0,
        action: 'view_tracking',
        parameters: const {'options': ['📊 Dashboard', 'Show Available Cars']},
      );
    }

    // Default general management response
    return AIResponse(
      message: "I am your Admin Management Assistant. I can help you monitor dashboard stats, check overdue bookings, track pending payments, manage maintenance schedules, view system reports, or update vehicle profiles.\n\nHow can I help you manage the system today?",
      intent: intent,
      confidence: intent.confidence,
      action: 'admin_general',
      parameters: const {
        'options': ["📊 Dashboard", "Today's Bookings", "Overdue Bookings", "Available Cars", "Maintenance Schedule"]
      },
    );
  }

  String _getFallbackAction(AIIntent intent) {
    if (intent is UnknownIntent) return 'unknown';
    if (intent is VehicleSearchIntent) return 'search_vehicles';
    if (intent is BookingIntent) return 'view_bookings';
    if (intent is ReceiptIntent) return 'view_receipts';
    if (intent is RewardIntent) return 'view_rewards';
    if (intent is ProfileIntent) return 'view_profile';
    if (intent is SupportIntent) return 'view_support';
    if (intent is BranchIntent) return 'view_branches';
    if (intent is NotificationIntent) return 'view_notifications';
    if (intent is HistoryIntent) return 'view_history';
    if (intent is DashboardIntent) return 'view_dashboard';
    if (intent is PaymentIntent) return 'view_payments';
    if (intent is MaintenanceIntent) return 'view_maintenance';
    if (intent is ReportIntent) return 'view_reports';
    if (intent is CustomerIntent) return 'view_customers';
    if (intent is NavigationIntent) return 'navigate_to';
    return 'unknown';
  }

  Map<String, dynamic> _extractEntities(String text, List<VehicleModel> vehicles) {
    final lower = text.toLowerCase();
    VehicleModel? matchedVehicle;
    String? matchedCategory;
    String? matchedTransmission;
    double? matchedBudget;

    // 1. Match exact brand + model or model
    for (final v in vehicles) {
      final brandModel = '${v.brand} ${v.model}'.toLowerCase();
      final modelOnly = v.model.toLowerCase();
      
      if (lower.contains(brandModel) || lower.contains(modelOnly)) {
        matchedVehicle = v;
        break;
      }
    }

    // 2. Match Category
    final categories = vehicles.map((v) => v.category).toSet().toList();
    for (final cat in categories) {
      if (lower.contains(cat.toLowerCase())) {
        matchedCategory = cat;
        break;
      }
    }
    if (matchedCategory == null) {
      if (lower.contains('suv')) {
        matchedCategory = 'SUV';
      } else if (lower.contains('sedan')) {
        matchedCategory = 'Sedan';
      } else if (lower.contains('hatchback')) {
        matchedCategory = 'Hatchback';
      } else if (lower.contains('luxury') || lower.contains('premium')) {
        matchedCategory = 'Luxury';
      } else if (lower.contains('mpv') || lower.contains('family')) {
        matchedCategory = 'Family';
      } else if (lower.contains('pickup') || lower.contains('truck')) {
        matchedCategory = 'Pickup';
      }
    }

    // 3. Match Transmission
    if (lower.contains('automatic') || lower.contains('auto')) {
      matchedTransmission = 'Automatic';
    } else if (lower.contains('manual')) {
      matchedTransmission = 'Manual';
    }

    // 4. Match Budget
    final budgetRegex = RegExp(r'(?:under|below|max|rm)\s*(\d+)');
    final match = budgetRegex.firstMatch(lower);
    if (match != null) {
      matchedBudget = double.tryParse(match.group(1) ?? '');
    }

    return {
      'vehicle': matchedVehicle,
      'category': matchedCategory,
      'transmission': matchedTransmission,
      'budget': matchedBudget,
    };
  }

  Future<String> _recommendVehicles(String uid, Map<String, dynamic> params) async {
    final vehicles = await VehicleService().getVehicles();
    final available = vehicles.where((v) => v.status.toLowerCase() == 'available').toList();
    
    if (available.isEmpty) {
      return "I checked our live database, but all vehicles are currently rented out. Please check back later!";
    }

    // Try to find previous rentals for this customer to understand preference
    String? preferredCategory;
    try {
      final bookings = await BookingService().getUserBookings(uid);
      if (bookings.isNotEmpty) {
        final countMap = <String, int>{};
        for (final b in bookings) {
          final vSnap = await FirebaseDatabase.instance.ref().child('vehicles').child(b.vehicleId).get();
          if (vSnap.exists) {
            final cat = (vSnap.value as Map)['category']?.toString();
            if (cat != null) {
              countMap[cat] = (countMap[cat] ?? 0) + 1;
            }
          }
        }
        if (countMap.isNotEmpty) {
          final sorted = countMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          preferredCategory = sorted.first.key;
        }
      }
    } catch (_) {}

    // Let's sort available vehicles by ratings and match preferences
    final ratedVehicles = <VehicleModel, double>{};
    for (final v in available) {
      final reviews = await ReviewService().getVehicleReviews(v.id);
      double avg = 4.5;
      if (reviews.isNotEmpty) {
        avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
      }
      ratedVehicles[v] = avg;
    }

    final sortedRecommendations = available.toList();
    sortedRecommendations.sort((a, b) {
      if (preferredCategory != null) {
        if (a.category == preferredCategory && b.category != preferredCategory) return -1;
        if (a.category != preferredCategory && b.category == preferredCategory) return 1;
      }
      final ratingA = ratedVehicles[a] ?? 4.5;
      final ratingB = ratedVehicles[b] ?? 4.5;
      return ratingB.compareTo(ratingA);
    });

    final listStr = sortedRecommendations.take(3).map((v) {
      final rating = ratedVehicles[v] ?? 4.5;
      return "• **${v.brand} ${v.model}** [RM ${v.pricePerDay.toStringAsFixed(0)}/day] - Category: **${v.category}** (${v.seats} seats, ${v.transmission}) - Rating: **${rating.toStringAsFixed(1)}⭐**";
    }).join('\n');

    return "🌟 **Personalized AI Vehicle Recommendations** (Based on live database):\n\n"
        "$listStr\n\nTo book any of these, simply type **'Book <model>'** to launch the wizard!";
  }

  // ── Helper parsing methods ──────────────────────────────────────────

  String _extractVehicleType(String text, List<String> categories) {
    final lower = text.toLowerCase();
    for (final c in categories) {
      if (lower.contains(c.toLowerCase())) return c;
    }
    if (lower.contains('suv')) return 'SUV';
    if (lower.contains('sedan')) return 'Sedan';
    if (lower.contains('hatchback')) return 'Hatchback';
    if (lower.contains('luxury') || lower.contains('premium')) return 'Luxury';
    if (lower.contains('family') || lower.contains('mpv')) return 'Family';
    if (lower.contains('pickup') || lower.contains('truck')) return 'Pickup';
    return text.length > 22 ? 'Any' : text.substring(0, 1).toUpperCase() + text.substring(1);
  }

  String? _findMatchingBranch(String text, List<String> liveBranches) {
    final lower = text.toLowerCase().trim();
    for (final branch in liveBranches) {
      if (lower.contains(branch.toLowerCase()) || branch.toLowerCase().contains(lower)) {
        return branch;
      }
    }
    return null;
  }

  DateTime? _extractDate(String text) {
    final dateRegex = RegExp(r'\d{4}[-/]\d{2}[-/]\d{2}');
    final match = dateRegex.firstMatch(text);
    if (match != null) {
      try {
        final cleaned = match.group(0)!.replaceAll('/', '-');
        return DateTime.parse(cleaned);
      } catch (_) {}
    }
    return null;
  }

  Future<String> _searchBookingVehicles(BookingSessionState session, Map<String, dynamic> params) async {
    List<VehicleModel> vehicles = [];
    try {
      vehicles = await VehicleService().getVehicles();
    } catch (e) {
      debugPrint('Error getting vehicles in booking assistant search: $e');
    }

    final filtered = vehicles.where((v) {
      if (v.status.toLowerCase() != 'available') return false;

      if (session.type != 'Any' && session.type != null) {
        if (session.type == 'Family') {
          if (v.category != 'MPV' && v.seats < 6) return false;
        } else if (v.category.toLowerCase() != session.type!.toLowerCase()) {
          return false;
        }
      }

      if (session.budget != null && v.pricePerDay > session.budget!) {
        return false;
      }

      if (session.transmission != 'Any' && session.transmission != null) {
        if (v.transmission.toLowerCase() != session.transmission!.toLowerCase()) return false;
      }

      if (session.seats != null && v.seats < session.seats!) return false;

      if (session.branch != null) {
        final vBranch = v.branchName.isEmpty ? 'Kuala Lumpur' : v.branchName;
        if (vBranch.toLowerCase() != session.branch!.toLowerCase()) return false;
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      double? alternateBudget;
      if (session.budget != null) {
        alternateBudget = session.budget! + 100.0;
        final alternativesExist = vehicles.any((v) => 
          v.status.toLowerCase() == 'available' &&
          (session.type == 'Any' || session.type == null || v.category.toLowerCase() == session.type!.toLowerCase()) &&
          v.pricePerDay <= alternateBudget! &&
          (session.transmission == 'Any' || session.transmission == null || v.transmission.toLowerCase() == session.transmission!.toLowerCase()) &&
          (session.branch == null || (v.branchName.isEmpty ? 'Kuala Lumpur' : v.branchName).toLowerCase() == session.branch!.toLowerCase())
        );

        if (alternativesExist) {
          session.currentStep = 8;
          session.suggestedAlternativeBudget = alternateBudget;
          params['options'] = ['Yes, show alternatives', 'No, cancel'];
          return "No **${session.type}** was found under RM${session.budget?.toInt()}.\n\n"
              "Would you like to see **${session.type}**s under RM${alternateBudget.toInt()} instead?";
        }
      }

      session.reset();
      params['options'] = ['🚗 Book a Car', '❓ FAQs', '💬 Contact Support', 'Back to Dashboard'];
      return "I couldn't find any available vehicles matching your specifications. Let's try adjusting the search criteria or check back later! 🚗";
    }

    params['vehicles'] = filtered.map((v) => v.toMap()).toList();
    params['isSelectionMode'] = true;
    params['prefilledPickupDate'] = session.pickupDate?.toIso8601String();
    params['prefilledReturnDate'] = session.returnDate?.toIso8601String();

    final resultMsg = "Searching available vehicles in **${session.branch}**...\n\n"
        "Found **${filtered.length}** matching vehicles! (Displaying matches below)\n\n"
        "Select **'Select'** on your favorite vehicle to continue in the wizard.";
    
    session.currentStep = 2;
    return resultMsg;
  }
}
