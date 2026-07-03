import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/colors.dart';
import '../models/ai_message.dart';
import '../models/ai_intent.dart';
import '../models/ai_response.dart';
import 'ai_provider.dart';
import 'local_ai_provider.dart';

// ─────────────────────────────────────────────────────────────────
//  ConversationSession model
// ─────────────────────────────────────────────────────────────────

class ConversationSession {
  final String id;
  String title;
  final DateTime createdAt;
  final List<AIMessage> messages;
  bool isPinned;

  ConversationSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
    this.isPinned = false,
  });
}

// ─────────────────────────────────────────────────────────────────
//  Quick command definition
// ─────────────────────────────────────────────────────────────────

class AIQuickCommand {
  final String label;
  final String query;
  final IconData icon;
  final Color color;
  const AIQuickCommand(this.label, this.query, this.icon, this.color);
}

// ─────────────────────────────────────────────────────────────────
//  Role-aware quick command sets (gorgeous styled options)
// ─────────────────────────────────────────────────────────────────

const List<AIQuickCommand> _customerCommands = [
  AIQuickCommand('🚗 Book a Car', 'book a car', Icons.directions_car_rounded, Colors.orange),
  AIQuickCommand('📅 My Bookings', 'show my bookings', Icons.calendar_month_rounded, Colors.blue),
  AIQuickCommand('💳 Payment', 'show my payments', Icons.payment_rounded, Colors.green),
  AIQuickCommand('🎁 Rewards', 'show my reward points', Icons.stars_rounded, Colors.amber),
  AIQuickCommand('🚙 Available Vehicles', 'show available cars', Icons.garage_rounded, Colors.teal),
  AIQuickCommand('📍 Branches', 'show rental branches', Icons.location_on_rounded, Colors.red),
  AIQuickCommand('🛠 Vehicle Issue', 'contact support regarding vehicle issue', Icons.build_rounded, Colors.purple),
  AIQuickCommand('💬 Contact Support', 'contact support', Icons.support_agent_rounded, Colors.indigo),
  AIQuickCommand('❓ FAQs', 'faqs', Icons.help_center_rounded, Colors.blueGrey),
  AIQuickCommand('📄 Rental Policy', 'show rental policy', Icons.description_rounded, Colors.brown),
];

const List<AIQuickCommand> _adminCommands = [
  AIQuickCommand('📊 Dashboard Summary', 'show dashboard summary', Icons.dashboard_rounded, Colors.blue),
  AIQuickCommand('🚗 Fleet Status', 'show available cars', Icons.directions_car_rounded, Colors.teal),
  AIQuickCommand('📅 Active Bookings', 'show active bookings', Icons.calendar_today_rounded, Colors.orange),
  AIQuickCommand('💰 Revenue', 'what is today\'s revenue?', Icons.monetization_on_rounded, Colors.green),
  AIQuickCommand('👥 Customers', 'show customer list', Icons.people_rounded, Colors.purple),
  AIQuickCommand('🛠 Maintenance', 'show maintenance schedule', Icons.build_rounded, Colors.red),
  AIQuickCommand('📨 Support Inbox', 'open support inbox', Icons.mail_rounded, Colors.indigo),
  AIQuickCommand('📈 Reports', 'generate reports', Icons.analytics_rounded, Colors.pink),
  AIQuickCommand('🤖 Business Insights', 'show business insights', Icons.insights_rounded, Colors.amber),
];

// ─────────────────────────────────────────────────────────────────
//  Unified AIService (role-aware, multiple-session enabled)
// ─────────────────────────────────────────────────────────────────

class AIService with ChangeNotifier {
  final AIProvider _provider = LocalAIProvider();
  final List<ConversationSession> _sessions = [];
  String? _activeSessionId;
  String _searchQuery = '';
  bool _isLoading = false;
  AIIntent? _lastIntent;

  /// Detected role: 'customer' | 'admin' | 'unknown'
  String _userRole = 'customer';
  bool _roleLoaded = false;

  AIService() {
    _initRole();
  }

  // ── Getters ───────────────────────────────────────────────────

  AIProvider get provider => _provider;
  List<ConversationSession> get sessions => _sessions;
  String? get activeSessionId => _activeSessionId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  AIIntent? get lastIntent => _lastIntent;
  String get userRole => _userRole;
  bool get isAdmin => _userRole == 'admin';
  bool get roleLoaded => _roleLoaded;

  /// Returns the messages of the currently active session
  List<AIMessage> get messages {
    final session = activeSession;
    return session != null ? session.messages : [];
  }

  ConversationSession? get activeSession {
    if (_activeSessionId == null && _sessions.isNotEmpty) {
      _activeSessionId = _sessions.first.id;
    }
    if (_activeSessionId == null) return null;
    try {
      return _sessions.firstWhere((s) => s.id == _activeSessionId);
    } catch (_) {
      return null;
    }
  }

  /// Returns the filtered and sorted list of sessions (pinned first)
  List<ConversationSession> get filteredSessions {
    final list = _sessions.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      return s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.messages.any((m) => m.message.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();

    // Sort: Pinned first, then by date descending
    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Returns the appropriate quick commands for the current role
  List<AIQuickCommand> get quickCommands =>
      _userRole == 'admin' ? _adminCommands : _customerCommands;

  // ── Role detection ────────────────────────────────────────────

  Future<void> _initRole() async {
    await _loadUserRole();
    _sessions.clear();
    _activeSessionId = null;
    createNewSession();
    notifyListeners();
  }

  Future<void> _loadUserRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _userRole = 'customer';
        _roleLoaded = true;
        return;
      }
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(uid)
          .child('role')
          .get()
          .timeout(const Duration(seconds: 5));

      if (snap.exists && snap.value != null) {
        _userRole = snap.value.toString().toLowerCase();
      } else {
        _userRole = 'customer';
      }
    } catch (_) {
      _userRole = 'customer';
    }
    _roleLoaded = true;
  }

  /// Call this when user logs out / switches account so the role is re-detected
  Future<void> reloadRole() async {
    _userRole = 'customer';
    _roleLoaded = false;
    notifyListeners();
    await _initRole();
  }

  // ── Session Management ────────────────────────────────────────

  void createNewSession() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final welcomeText = _userRole == 'admin'
        ? 'Hello, Administrator! 👋 I\'m your CARENT Admin AI Assistant. I can help you monitor live fleet status, check active bookings, review revenue, generate reports, track vehicles, and manage maintenance.\n\nChoose an option from the popular actions below to start!'
        : 'Hello! I\'m your CARENT Guided AI Operator. 🚗✨ I can help you search the fleet, make a booking, check rewards, review receipts, or contact support.\n\nSelect a popular action card below to get started!';

    final welcomeMessage = AIMessage(
      id: 'welcome_$id',
      role: 'assistant',
      message: welcomeText,
      timestamp: DateTime.now(),
    );

    final session = ConversationSession(
      id: id,
      title: 'New Assistant Chat',
      createdAt: DateTime.now(),
      messages: [welcomeMessage],
    );

    _sessions.add(session);
    _activeSessionId = id;
    notifyListeners();
  }

  void selectSession(String id) {
    _activeSessionId = id;
    notifyListeners();
  }

  void deleteSession(String id) {
    _sessions.removeWhere((s) => s.id == id);
    if (_activeSessionId == id) {
      _activeSessionId = _sessions.isNotEmpty ? _sessions.first.id : null;
      if (_activeSessionId == null) {
        createNewSession();
      }
    }
    notifyListeners();
  }

  void togglePinSession(String id) {
    try {
      final s = _sessions.firstWhere((sess) => sess.id == id);
      s.isPinned = !s.isPinned;
      notifyListeners();
    } catch (_) {}
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearLastIntent() {
    _lastIntent = null;
  }

  void clearHistory() {
    final session = activeSession;
    if (session != null) {
      session.messages.clear();
      final id = session.id;
      final welcomeText = _userRole == 'admin'
          ? 'Hello, Administrator! 👋 I\'m your CARENT Admin AI Assistant. I can help you monitor live fleet status, check active bookings, review revenue, generate reports, track vehicles, and manage maintenance.\n\nChoose an option from the popular actions below to start!'
          : 'Hello! I\'m your CARENT Guided AI Operator. 🚗✨ I can help you search the fleet, make a booking, check rewards, review receipts, or contact support.\n\nSelect a popular action card below to get started!';

      session.messages.add(AIMessage(
        id: 'welcome_$id',
        role: 'assistant',
        message: welcomeText,
        timestamp: DateTime.now(),
      ));
      session.title = 'New Assistant Chat';
    }
    _lastIntent = null;
    notifyListeners();
  }

  // ── Send message ──────────────────────────────────────────────

  Future<AIResponse> sendMessage(String text) async {
    if (text.trim().isEmpty) {
      const unknown = UnknownIntent(confidence: 0.0);
      return AIResponse(
        message: '',
        intent: unknown,
        confidence: 0.0,
        action: 'unknown',
        parameters: const {},
      );
    }

    final session = activeSession;
    if (session == null) {
      createNewSession();
    }

    final userMessage = AIMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      message: text,
      timestamp: DateTime.now(),
    );

    activeSession?.messages.add(userMessage);

    // Dynamic Title Generation: Update title of session if it is still default
    if (activeSession != null && activeSession!.title == 'New Assistant Chat') {
      String title = text.trim();
      if (title.length > 22) {
        title = '${title.substring(0, 20)}...';
      }
      activeSession!.title = title;
    }

    _isLoading = true;
    _lastIntent = null;
    notifyListeners();

    try {
      // 1. Detect Intent
      final intent = await _provider.detectIntent(text);
      if (intent.confidence >= 0.5) {
        _lastIntent = intent;
      }

      // 2. Get response from provider (pass full session messages history)
      final response = await _provider.sendMessage(text, activeSession!.messages);

      // 3. Build metadata for UI (vehicles, options, branches, action, summary, report)
      final Map<String, dynamic> msgMetadata = {};
      if (response.parameters.containsKey('vehicles')) {
        msgMetadata['vehicles'] = response.parameters['vehicles'];
      }
      if (response.parameters.containsKey('options')) {
        msgMetadata['options'] = response.parameters['options'];
      }
      if (response.parameters.containsKey('summary')) {
        msgMetadata['summary'] = response.parameters['summary'];
      }
      if (response.parameters.containsKey('report')) {
        msgMetadata['report'] = response.parameters['report'];
      }
      if (response.parameters.containsKey('bookingId')) {
        msgMetadata['bookingId'] = response.parameters['bookingId'];
      }
      if (response.parameters.containsKey('isSelectionMode')) {
        msgMetadata['isSelectionMode'] = response.parameters['isSelectionMode'];
      }
      if (response.parameters.containsKey('request_date')) {
        msgMetadata['request_date'] = response.parameters['request_date'];
      }
      if (response.action.isNotEmpty) {
        msgMetadata['action'] = response.action;
      }

      activeSession?.messages.add(AIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        message: response.message,
        timestamp: DateTime.now(),
        metadata: msgMetadata.isNotEmpty ? msgMetadata : null,
      ));

      return response;
    } catch (e) {
      final errorResponse = AIResponse(
        message: "I couldn't find that information in the current system data. Live data cannot currently be loaded. (Error: $e)",
        intent: const UnknownIntent(confidence: 0.0),
        confidence: 0.0,
        action: 'error',
        parameters: const {},
      );

      activeSession?.messages.add(AIMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        message: errorResponse.message,
        timestamp: DateTime.now(),
      ));

      return errorResponse;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Clipboard & Share Actions ──────────────────────────────────

  void copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Copied to clipboard!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void shareMessage(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.share, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Shared! Link copied to clipboard.', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
