import 'package:flutter/foundation.dart';
import '../models/ai_intent.dart';

class IntentEngine {
  AIIntent detectIntent(String text) {
    final cleaned = text.toLowerCase().trim();
    if (cleaned.isEmpty) {
      return const UnknownIntent(confidence: 0.0);
    }

    final intents = <AIIntent>[
      _matchVehicleSearch(cleaned),
      _matchBooking(cleaned),
      _matchReceipt(cleaned),
      _matchReward(cleaned),
      _matchProfile(cleaned),
      _matchSupport(cleaned),
      _matchBranch(cleaned),
      _matchNotification(cleaned),
      _matchHistory(cleaned),
      _matchDashboard(cleaned),
      _matchPayment(cleaned),
      _matchMaintenance(cleaned),
      _matchReport(cleaned),
      _matchCustomer(cleaned),
      _matchNavigation(cleaned),
    ];

    intents.sort((a, b) => b.confidence.compareTo(a.confidence));
    final bestMatch = intents.first;

    debugPrint('[AI IntentEngine] Text: "$text" -> Cleaned: "$cleaned" -> Best Match: $bestMatch with confidence ${bestMatch.confidence}');

    if (bestMatch.confidence >= 0.5) {
      return bestMatch;
    }

    return const UnknownIntent(confidence: 0.0);
  }

  // 1. Vehicle Search Intent Matcher
  AIIntent _matchVehicleSearch(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    if (text.contains('recommend') || text.contains('suggestion') || text.contains('what should i') || text.contains('best car')) {
      confidence = 0.95;
      params['action'] = 'recommend_vehicles';
    }

    // Check Categories
    if (text.contains('suv') || text.contains('suvs') || text.contains('sports utility') || text.contains('sport utility')) {
      confidence = 0.95;
      params['category'] = 'SUV';
    } else if (text.contains('sedan') || text.contains('sedans')) {
      confidence = 0.95;
      params['category'] = 'Sedan';
    } else if (text.contains('luxury') || text.contains('premium')) {
      confidence = 0.90;
      params['category'] = 'Luxury';
    }

    // Check Transmission
    if (text.contains('automatic') || text.contains('auto')) {
      confidence = confidence > 0 ? confidence : 0.90;
      params['transmission'] = 'Automatic';
    } else if (text.contains('manual')) {
      confidence = confidence > 0 ? confidence : 0.90;
      params['transmission'] = 'Manual';
    }

    // Check Sorting & Price
    if (text.contains('cheap') || text.contains('cheapest') || text.contains('affordable') || text.contains('budget')) {
      confidence = confidence > 0 ? confidence : 0.90;
      params['sort'] = 'price_asc';
    }

    // Check Status & Availability
    if (text.contains('available') || text.contains('free')) {
      confidence = confidence > 0 ? confidence : 0.85;
      params['status'] = 'Available';
    }

    // Check Dates
    if (text.contains('tomorrow') || text.contains('next day')) {
      confidence = confidence > 0 ? confidence : 0.85;
      params['date'] = 'tomorrow';
    }

    // Check Specific Price Limit (e.g. under RM200, under 200, rm 200)
    final priceRegex = RegExp(r'(?:under|below|max|rm)\s*(\d+)');
    final match = priceRegex.firstMatch(text);
    if (match != null) {
      final priceVal = double.tryParse(match.group(1) ?? '');
      if (priceVal != null) {
        confidence = 0.95;
        params['max_price'] = priceVal;
      }
    }

    // General vehicle search trigger words
    if (confidence == 0.0) {
      final searchKeywords = ['car', 'cars', 'vehicle', 'vehicles', 'fleet', 'find', 'show', 'search'];
      int matchCount = 0;
      for (final keyword in searchKeywords) {
        if (text.contains(keyword)) {
          matchCount++;
        }
      }
      if (matchCount >= 2) {
        confidence = 0.80;
      } else if (matchCount == 1 && (text.contains('find') || text.contains('show') || text.contains('search'))) {
        confidence = 0.50; // weak match
      }
    }

    return VehicleSearchIntent(confidence: confidence, parameters: params);
  }

  // 2. Booking Intent Matcher
  AIIntent _matchBooking(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final bookingKeywords = ['booking', 'bookings', 'rentals', 'rental', 'reservation', 'reservations', 'book', 'rent', 'need a vehicle', 'rent a car', 'need a car', 'renew', 'extend', 'return', 'status', 'way', 'complete', 'finish', 'ongoing'];
    bool hasBookingKeyword = false;
    for (final kw in bookingKeywords) {
      if (text.contains(kw)) {
        hasBookingKeyword = true;
        break;
      }
    }

    if (hasBookingKeyword) {
      confidence = 0.70;

      // Classify Actions
      if (text.contains('cancel') || text.contains('cancellation') || text.contains('terminate')) {
        confidence = 0.95;
        params['action'] = 'cancel_booking';
      } else if (text.contains('renew') || text.contains('extend') || text.contains('extension')) {
        confidence = 0.95;
        params['action'] = 'renew_booking';
      } else if (text.contains('return') || text.contains('give back') || text.contains('way') || text.contains('complete') || text.contains('finish')) {
        confidence = 0.95;
        params['action'] = 'return_vehicle';
      } else if (text.contains('status') || text.contains('check')) {
        confidence = 0.95;
        params['action'] = 'check_booking_status';
      } else if (text.contains('overdue')) {
        confidence = 0.95;
        params['action'] = 'admin_overdue_bookings';
      } else if (text.contains('today') || text.contains('current')) {
        confidence = 0.95;
        params['action'] = 'admin_today_bookings';
      } else if (text.contains('list') || text.contains('my') || text.contains('show') || text.contains('open') || text.endsWith('s')) {
        confidence = 0.90;
        params['action'] = 'view_bookings';
      } else if (text.contains('make') || text.contains('new') || text.contains('create') || text.contains('book a') || text.contains('rent a') || text == 'book' || text == 'rent' || text.contains('need a vehicle')) {
        confidence = 0.95;
        params['action'] = 'book_vehicle';
      } else {
        confidence = 0.85;
        params['action'] = 'book_vehicle';
      }
    } else {
      // Direct action matching without standard keywords
      if (text.contains('cancel') && (text.contains('my car') || text.contains('my ride'))) {
        confidence = 0.80;
        params['action'] = 'cancel_booking';
      } else if (text.contains('renew') || text.contains('extend')) {
        confidence = 0.85;
        params['action'] = 'renew_booking';
      } else if ((text.contains('return') || text.contains('way') || text.contains('complete') || text.contains('finish')) && (text.contains('car') || text.contains('vehicle') || text.contains('my') || text.contains('rental') || text.contains('vios') || text.contains('civic') || text.contains('saga') || text.contains('alza') || text.contains('myvi') || text.contains('city'))) {
        confidence = 0.85;
        params['action'] = 'return_vehicle';
      } else if (text.contains('status') && (text.contains('booking') || text.contains('reservation') || text.contains('my'))) {
        confidence = 0.85;
        params['action'] = 'check_booking_status';
      } else if (text.contains('overdue')) {
        confidence = 0.90;
        params['action'] = 'admin_overdue_bookings';
      }
    }

    return BookingIntent(confidence: confidence, parameters: params);
  }

  // 3. Receipt Intent Matcher
  AIIntent _matchReceipt(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final receiptKeywords = ['receipt', 'receipts', 'invoice', 'invoices', 'bill', 'bills', 'tax invoice'];
    bool hasReceiptKeyword = false;
    for (final kw in receiptKeywords) {
      if (text.contains(kw)) {
        hasReceiptKeyword = true;
        break;
      }
    }

    if (hasReceiptKeyword) {
      confidence = 0.80;
      if (text.contains('download') || text.contains('export') || text.contains('get')) {
        confidence = 0.95;
        params['action'] = 'download_receipt';
      } else {
        confidence = 0.90;
        params['action'] = 'open_receipt';
      }
    }

    return ReceiptIntent(confidence: confidence, parameters: params);
  }

  // 4. Reward Intent Matcher
  AIIntent _matchReward(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final rewardKeywords = ['reward', 'rewards', 'point', 'points', 'loyalty', 'loyalty points', 'member level', 'membership', 'benefits'];
    int matches = 0;
    for (final kw in rewardKeywords) {
      if (text.contains(kw)) {
        matches++;
      }
    }

    if (matches >= 1) {
      confidence = 0.90;
    }

    return RewardIntent(confidence: confidence, parameters: params);
  }

  // 5. Profile Intent Matcher
  AIIntent _matchProfile(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    // Lower profile confidence if it relates to customer lists (admin CustomerIntent)
    if (text.contains('customer') || text.contains('client') || text.contains('user list')) {
      return const ProfileIntent(confidence: 0.0);
    }

    final profileKeywords = ['profile', 'account', 'user info', 'my details', 'personal details', 'settings'];
    for (final kw in profileKeywords) {
      if (text.contains(kw)) {
        confidence = 0.90;
        break;
      }
    }

    return ProfileIntent(confidence: confidence, parameters: params);
  }

  // 6. Support Intent Matcher
  AIIntent _matchSupport(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final supportKeywords = ['support', 'help', 'contact', 'ticket', 'inbox', 'messages', 'talk to support', 'customer care', 'complaint', 'complaints', 'faq', 'faqs'];
    bool hasKeyword = false;
    for (final kw in supportKeywords) {
      if (text.contains(kw)) {
        hasKeyword = true;
        break;
      }
    }

    if (hasKeyword) {
      confidence = 0.80;
      if (text.contains('inbox') || text.contains('admin') || text.contains('all tickets')) {
        confidence = 0.95;
        params['action'] = 'admin_support_inbox';
      } else {
        confidence = 0.90;
        params['action'] = 'contact_support';
      }
    }

    return SupportIntent(confidence: confidence, parameters: params);
  }

  // 7. Branch Intent Matcher
  AIIntent _matchBranch(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final branchKeywords = ['branch', 'branches', 'location', 'locations', 'hubs', 'where are you', 'map', 'rental hubs', 'office', 'offices', 'policy', 'policies', 'rules', 'rule', 'open rental'];
    for (final kw in branchKeywords) {
      if (text.contains(kw)) {
        confidence = 0.90;
        if (kw.contains('policy') || kw.contains('policies') || kw.contains('rules') || kw.contains('rule') || kw.contains('open rental')) {
          params['action'] = 'explain_policy';
        }
        break;
      }
    }

    return BranchIntent(confidence: confidence, parameters: params);
  }

  // 8. Notification Intent Matcher
  AIIntent _matchNotification(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final notificationKeywords = ['notification', 'notifications', 'alerts', 'alert', 'announcements'];
    for (final kw in notificationKeywords) {
      if (text.contains(kw)) {
        confidence = 0.90;
        break;
      }
    }

    if (confidence > 0) {
      params['action'] = 'admin_notifications';
    }

    return NotificationIntent(confidence: confidence, parameters: params);
  }

  // 9. History Intent Matcher
  AIIntent _matchHistory(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    // Lower general history confidence if it belongs to transaction/payment ledger history
    if (text.contains('payment') || text.contains('ledger') || text.contains('transaction')) {
      return const HistoryIntent(confidence: 0.0);
    }

    final historyKeywords = ['history', 'past rentals', 'previous rentals', 'completed bookings', 'past bookings', 'history list'];
    for (final kw in historyKeywords) {
      if (text.contains(kw)) {
        confidence = 0.90;
        break;
      }
    }

    return HistoryIntent(confidence: confidence, parameters: params);
  }

  // 10. Dashboard Intent Matcher
  AIIntent _matchDashboard(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final dashboardKeywords = ['dashboard', 'home', 'main screen', 'overview', 'panel', 'summary', 'system stats', 'statistics'];
    for (final kw in dashboardKeywords) {
      if (text.contains(kw)) {
        confidence = 0.85;
        break;
      }
    }

    if (confidence > 0) {
      if (text.contains('stat') || text.contains('summary')) {
        params['action'] = 'admin_dashboard_stats';
      }
    }

    return DashboardIntent(confidence: confidence, parameters: params);
  }

  // 11. Payment Intent Matcher
  AIIntent _matchPayment(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final paymentKeywords = ['payment', 'payments', 'revenue', 'sales', 'ledger', 'pay', 'transaction', 'transactions', 'earnings', 'statement', 'owe', 'due', 'outstanding', 'how much do i', 'invoice', 'invoices', 'bill', 'bills'];
    bool hasKeyword = false;
    for (final kw in paymentKeywords) {
      if (text.contains(kw)) {
        hasKeyword = true;
        break;
      }
    }

    if (hasKeyword) {
      confidence = 0.70;
      if (text.contains('owe') || text.contains('due') || text.contains('outstanding') || text.contains('how much') || text.contains('invoice') || text.contains('invoices') || text.contains('bill') || text.contains('bills')) {
        confidence = 0.95;
        if (text.contains('pay') || text.contains('clear') || text.contains('settle')) {
          params['action'] = 'pay_outstanding_invoice';
        } else {
          params['action'] = 'check_debts';
        }
      } else if (text.contains('pay') && (text.contains('booking') || text.contains('invoice') || text.contains('bill'))) {
        confidence = 0.95;
        params['action'] = 'pay_outstanding_invoice';
      } else if (text.contains('revenue') || text.contains('sales') || text.contains('earnings')) {
        confidence = 0.95;
        params['action'] = 'admin_revenue_today';
      } else if (text.contains('statistics') || text.contains('stats') || text.contains('summary')) {
        confidence = 0.95;
        params['action'] = 'admin_payment_stats';
      } else {
        confidence = 0.90;
        params['action'] = 'view_payments';
      }
    }

    return PaymentIntent(confidence: confidence, parameters: params);
  }

  // 12. Maintenance Intent Matcher
  AIIntent _matchMaintenance(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final maintenanceKeywords = ['maintenance', 'repair', 'repairs', 'service', 'servicing', 'mechanic', 'fix car', 'inspection', 'inspect'];
    for (final kw in maintenanceKeywords) {
      if (text.contains(kw)) {
        confidence = 0.90;
        break;
      }
    }

    if (confidence > 0) {
      if (text.contains('schedule') || text.contains('list') || text.contains('show') || text.contains('all')) {
        params['action'] = 'admin_maintenance_schedule';
      }
    }

    return MaintenanceIntent(confidence: confidence, parameters: params);
  }

  // 13. Report Intent Matcher
  AIIntent _matchReport(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    // Match reports, stats, analytics. Prevent 'stat' matching 'statement' or 'status'
    final reportKeywords = ['report', 'reports', 'generate report', 'analytics', 'statistics', 'stats', 'charts', 'chart'];
    for (final kw in reportKeywords) {
      if (text.contains(kw)) {
        confidence = 0.90;
        break;
      }
    }

    // Explicitly check for 'stat' as whole word
    final words = text.split(RegExp(r'\s+'));
    if (words.contains('stat')) {
      confidence = 0.90;
    }

    // Parse timeframe
    String? timeframe;
    if (text.contains('today')) {
      timeframe = 'Today';
    } else if (text.contains('yesterday')) {
      timeframe = 'Yesterday';
    } else if (text.contains('last 7 days') || text.contains('7 days')) {
      timeframe = 'Last 7 Days';
    } else if (text.contains('last week')) {
      timeframe = 'Last Week';
    } else if (text.contains('this week')) {
      timeframe = 'This Week';
    } else if (text.contains('last month')) {
      timeframe = 'Last Month';
    } else if (text.contains('this month')) {
      timeframe = 'This Month';
    } else if (text.contains('last 3 months') || text.contains('3 months')) {
      timeframe = 'Last 3 Months';
    } else if (text.contains('last 6 months') || text.contains('6 months')) {
      timeframe = 'Last 6 Months';
    } else if (text.contains('last year')) {
      timeframe = 'Last Year';
    } else if (text.contains('this year')) {
      timeframe = 'This Year';
    }
    if (timeframe != null) {
      params['timeframe'] = timeframe;
    }

    // Parse report type
    String? type;
    if (text.contains('payment') || text.contains('payments')) {
      type = 'Payments';
    } else if (text.contains('revenue') || text.contains('earnings') || text.contains('sales') || text.contains('income')) {
      type = 'Revenue';
    } else if (text.contains('booking') || text.contains('bookings') || text.contains('rentals') || text.contains('rental')) {
      if (text.contains('overdue')) {
        type = 'Overdue Rentals';
      } else if (text.contains('open')) {
        type = 'Open Rentals';
      } else {
        type = 'Bookings';
      }
    } else if (text.contains('vehicle') || text.contains('vehicles') || text.contains('car') || text.contains('cars') || text.contains('fleet')) {
      type = 'Vehicles';
    } else if (text.contains('maintenance') || text.contains('repair') || text.contains('repairs') || text.contains('service')) {
      type = 'Maintenance';
    } else if (text.contains('customer') || text.contains('customers') || text.contains('user') || text.contains('users') || text.contains('client') || text.contains('clients')) {
      type = 'Customers';
    } else if (text.contains('reward') || text.contains('rewards') || text.contains('point') || text.contains('points')) {
      type = 'Reward Points';
    } else if (text.contains('review') || text.contains('reviews') || text.contains('rating') || text.contains('ratings') || text.contains('feedback')) {
      type = 'Reviews';
    } else if (text.contains('overdue')) {
      type = 'Overdue Rentals';
    } else if (text.contains('open')) {
      type = 'Open Rentals';
    }
    if (type != null) {
      params['type'] = type;
    }

    return ReportIntent(confidence: confidence, parameters: params);
  }

  // 14. Customer Intent Matcher
  AIIntent _matchCustomer(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final customerKeywords = ['customer', 'customers', 'users', 'clients', 'customer list', 'client list', 'members', 'info', 'lookup'];
    for (final kw in customerKeywords) {
      if (text.contains(kw)) {
        confidence = 0.90;
        break;
      }
    }

    if (confidence > 0) {
      params['action'] = 'admin_customer_info';
    }

    return CustomerIntent(confidence: confidence, parameters: params);
  }

  // 15. Navigation Intent Matcher
  AIIntent _matchNavigation(String text) {
    double confidence = 0.0;
    final Map<String, dynamic> params = {};

    final navKeywords = ['tracking', 'track', 'gps', 'vehicle tracking', 'live location', 'where is the car', 'live tracking', 'car tracking'];
    for (final kw in navKeywords) {
      if (text.contains(kw)) {
        confidence = 0.95;
        params['action'] = 'admin_vehicle_tracking';
        break;
      }
    }

    return NavigationIntent(confidence: confidence, parameters: params);
  }
}
