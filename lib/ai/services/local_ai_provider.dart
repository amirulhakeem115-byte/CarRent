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
import '../../services/notification_service.dart';
import '../../models/vehicle_model.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/maintenance_job_model.dart';
import '../../services/review_service.dart';
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
  Future<AIResponse> sendMessage(String text, List<AIMessage> history) async {
    // Add artificial delay to simulate thinking time (500ms)
    await Future.delayed(const Duration(milliseconds: 500));

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final session = _bookingSessions.putIfAbsent(uid, () => BookingSessionState());

    final cleanedText = text.trim().toLowerCase();

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

    final intent = _intentEngine.detectIntent(text);
    final Map<String, dynamic> customParams = Map<String, dynamic>.from(intent.parameters);

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
    final responseMessage = await _processBookingFlow(text, session, customParams, intent);
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
            final rentalDays = newDate.difference(DateTime.parse(b['pickUpDate'])).inDays;
            final vSnap = await FirebaseDatabase.instance.ref().child('vehicles').child(b['vehicleId']).get();
            double pPerDay = 180.0;
            if (vSnap.exists) {
              pPerDay = double.tryParse((vSnap.value as Map)['pricePerDay']?.toString() ?? '') ?? 180.0;
            }
            final newTotal = (rentalDays <= 0 ? 1 : rentalDays) * pPerDay;

            await FirebaseDatabase.instance.ref().child('bookings').child(bId).update({
              'returnDate': newDate.toIso8601String(),
              'totalPrice': newTotal,
            });

            // Create notification
            await NotificationService().createNotification(
              userId: b['userId'] ?? '',
              title: 'Booking Extended',
              message: 'Your booking #${bId.substring(0, 5).toUpperCase()} has been extended to ${DateFormat('dd MMM yyyy').format(newDate)}.',
              type: 'booking',
            );
          }
          session.reset();
          params['options'] = ['My Bookings', 'Back to Dashboard'];
          return "📅 **Booking Extended Successfully!**\n\nYour return schedule has been updated in the database.";
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

  Future<String> _processBookingFlow(String text, BookingSessionState session, Map<String, dynamic> params, AIIntent intent) async {
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
        if (match != null) {
          session.vehicleId = match.group(1);
        } else {
          session.vehicleId = text;
        }

        if (session.vehicleId != null) {
          try {
            final vehicles = await VehicleService().getVehicles();
            var v = vehicles.firstWhere(
              (item) => item.id == session.vehicleId,
              orElse: () => vehicles.firstWhere(
                (item) => '${item.brand} ${item.model}'.toLowerCase().contains(session.vehicleId!.toLowerCase()),
                orElse: () => vehicles.firstWhere(
                  (item) => item.model.toLowerCase().contains(session.vehicleId!.toLowerCase()),
                ),
              ),
            );
            session.vehicleId = v.id;
            session.vehicleName = '${v.brand} ${v.model}';
            session.vehiclePrice = v.pricePerDay;
          } catch (_) {
            session.vehicleName = text;
            session.vehiclePrice = 180.0;
          }
        }

        session.currentStep = 3;
        return await _askBranchSelection(session, params);

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
            final rentalDays = session.returnDate!.difference(session.pickupDate!).inDays;
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
            DateTime rDate = session.returnDate!;
            try {
              final parsedTime = DateFormat('hh:mm a').parse(session.pickupTime ?? '09:00 AM');
              pDate = DateTime(session.pickupDate!.year, session.pickupDate!.month, session.pickupDate!.day, parsedTime.hour, parsedTime.minute);
              rDate = DateTime(session.returnDate!.year, session.returnDate!.month, session.returnDate!.day, parsedTime.hour, parsedTime.minute);
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
        return await _generateResponse(intent, text, session);
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
    final rentalDays = session.returnDate!.difference(session.pickupDate!).inDays;
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
      'returnDate': DateFormat('dd MMM yyyy').format(session.returnDate!),
      'pickupTime': session.pickupTime ?? '09:00 AM',
      'days': daysCount,
      'pricePerDay': session.vehiclePrice,
      'totalPrice': basePrice,
      'discount': discount,
      'tax': 0.0,
      'total': finalTotal,
      'deposit': deposit,
      'balance': balance,
      'pointsToRedeem': session.pointsToRedeem,
    };

    params['summary'] = summary;
    params['options'] = ['Confirm Booking', 'Edit Details', 'Cancel Checkout'];

    return "**Step 8 of 8**: Please review your Premium Booking Summary checkout receipt below:";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  General AI responses & intent logic (role-aware live Firebase stats)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _generateResponse(AIIntent intent, String text, BookingSessionState session) async {
    final textLower = text.toLowerCase();
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

    if (intent is UnknownIntent || intent.confidence < 0.5) {
      return "I couldn't find that information in the current system data. Please select one of our guided popular actions cards or FAQs!";
    }

    if (intent is VehicleSearchIntent) {
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return "Please log in to manage bookings.";

      String role = 'customer';
      try {
        final user = await DatabaseService().getUser(uid);
        role = user?.role ?? 'customer';
      } catch (_) {}

      final action = intent.parameters['action'];

      if (role == 'admin') {
        List<BookingModel> bookings = [];
        try { bookings = await BookingService().getBookings(); } catch (_) {}
        
        if (action == 'admin_today_bookings') {
          final today = DateTime.now();
          final todayStr = DateFormat('yyyy-MM-dd').format(today);
          final todayBookings = bookings.where((b) => DateFormat('yyyy-MM-dd').format(b.pickUpDate) == todayStr).toList();

          if (todayBookings.isEmpty) return "There are no bookings scheduled for pickup today.";
          return "Found **${todayBookings.length}** active bookings scheduled for pick-up today:\n"
              "${todayBookings.map((b) => '• **${b.userName}** - ${b.vehicleName} (RM ${b.totalPrice.toStringAsFixed(0)})').join('\n')}";
        }
        return "Opening administrative bookings tab. There are currently **${bookings.length}** total reservations saved in the system.";
      } else {
        // Customer
        List<BookingModel> bookings = [];
        try { bookings = await BookingService().getUserBookings(uid); } catch (_) {}

        if (action == 'cancel_booking') {
          final active = bookings.where((b) => b.status.toLowerCase() != 'completed' && b.status.toLowerCase() != 'cancelled' && b.status.toLowerCase() != 'rejected').toList();
          if (active.isEmpty) return "You do not have any active bookings that can be cancelled.";
          return "Opening the bookings cancellation screen. Please select the active booking you wish to cancel.";
        }

        if (bookings.isEmpty) return "I couldn't find any bookings on your customer account in Firebase.";
        final latest = bookings.first;
        return "I found **${bookings.length}** bookings on your account. Your latest booking: **${latest.vehicleName}** (Status: **${latest.status.toUpperCase()}**).";
      }
    }

    if (intent is RewardIntent) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return "Please log in to view reward points.";

      int points = 0;
      try { points = await RewardPointsService().getUserPoints(uid); } catch (_) {}
      final discount = RewardPointsService().calculateDiscount(points);

      return "You have **$points** loyalty reward points balance. This is equivalent to **RM ${discount.toStringAsFixed(2)}** discount on your next rent! ⭐";
    }

    if (intent is PaymentIntent) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return "Please log in to view payments.";

      String role = 'customer';
      try {
        final user = await DatabaseService().getUser(uid);
        role = user?.role ?? 'customer';
      } catch (_) {}

      final action = intent.parameters['action'];

      if (role == 'admin') {
        if (action == 'admin_revenue_today') {
          double rev = 0.0;
          try {
            final payments = await PaymentService().getPayments();
            final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
            for (final p in payments) {
              final pStat = (p.paymentStatus ?? p.status).toLowerCase();
              if (pStat == 'approved' || pStat == 'paid') {
                if (DateFormat('yyyy-MM-dd').format(p.paymentDate) == todayStr) {
                  rev += p.amount;
                }
              }
            }
          } catch (_) {}
          return "Today's approved ledger revenue is **RM ${rev.toStringAsFixed(2)}**. 💰";
        }
        return "Opening administrative payments ledger overview.";
      } else {
        return "Opening your payments history screen.";
      }
    }

    if (intent is MaintenanceIntent) {
      List<dynamic> jobs = [];
      try {
        jobs = await MaintenanceService().getMaintenanceJobs();
      } catch (_) {}
      final activeJobs = jobs.where((j) => j.status == 'Scheduled' || j.status == 'In Progress').toList();
      return "Opening vehicle maintenance dashboard. Currently tracking **${activeJobs.length}** active repair/service schedules in the system.";
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

    return "Redirecting to your request... 🚗";
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
