import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/booking_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/payment_service.dart';
import '../services/ai_service.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/typing_indicator.dart';

/// Phase 5 – Admin AI Assistant full-page panel embedded inside the Admin Dashboard.
class AdminAIAssistantView extends StatefulWidget {
  const AdminAIAssistantView({super.key});

  @override
  State<AdminAIAssistantView> createState() => _AdminAIAssistantViewState();
}

class _AdminAIAssistantViewState extends State<AdminAIAssistantView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _pulseController;

  // Live stats – loaded asynchronously
  int _totalBookings = 0;
  int _totalVehicles = 0;
  double _totalRevenue = 0.0;
  bool _statsLoaded = false;

  bool _isNarrowScreen(BuildContext context) =>
      MediaQuery.of(context).size.width < 420;

  /// Quick command chips shown above the input bar for the admin
  static const List<_QuickCommand> _quickCommands = [
    _QuickCommand("📊 Dashboard", "Show dashboard summary"),
    _QuickCommand("📅 Today's Bookings", "Show today's bookings"),
    _QuickCommand("💰 Revenue Today", "What is today's revenue?"),
    _QuickCommand("🚗 Available Cars", "Show available cars"),
    _QuickCommand("🔧 Maintenance", "Show maintenance schedule"),
    _QuickCommand("👥 Customers", "Show customer list"),
    _QuickCommand("📋 Reports", "Generate reports"),
    _QuickCommand("🗺️ Tracking", "Open vehicle tracking"),
    _QuickCommand("📥 Support Inbox", "Open support inbox"),
    _QuickCommand("💳 Payments", "Show pending payments"),
    _QuickCommand("📍 Branches", "Show branch locations"),
    _QuickCommand("🔔 Notifications", "Show notifications"),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadStats();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final results = await Future.wait([
        BookingService().getBookings(),
        VehicleService().getVehicles(),
        PaymentService().getPayments(),
      ]).timeout(const Duration(seconds: 10));

      final bookings = results[0] as dynamic;
      final vehicles = results[1] as dynamic;
      final payments = results[2] as dynamic;

      double rev = 0.0;
      for (final p in payments) {
        final status = (p.status ?? '').toLowerCase();
        final pStatus = (p.paymentStatus ?? '').toLowerCase();
        if (status == 'approved' || status == 'paid' || pStatus == 'approved') {
          rev += (p.amount as num).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _totalBookings = bookings.length;
          _totalVehicles = vehicles.length;
          _totalRevenue = rev;
          _statsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();
    _focusNode.requestFocus();
    _scrollToBottom();
    final aiService = context.read<AIService>();
    await aiService.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Container(
      color: bg,
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          _buildHeader(isDark, cardBg, borderCol, textPrimary, textSecondary),

          // ── Stats strip ─────────────────────────────────────────────────────
          _buildStatsStrip(
            isDark,
            cardBg,
            borderCol,
            textPrimary,
            textSecondary,
          ),

          // ── Chat Messages ───────────────────────────────────────────────────
          Expanded(child: _buildMessageList(isDark, bg)),

          // ── Quick command chips ─────────────────────────────────────────────
          _buildQuickChips(isDark, cardBg, borderCol),

          // ── Input bar ───────────────────────────────────────────────────────
          _buildInputBar(isDark, cardBg, borderCol, textPrimary, textSecondary),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    bool isDark,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isNarrow = _isNarrowScreen(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 16 : 24,
        20,
        isNarrow ? 16 : 24,
        20,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: Row(
        children: [
          // Animated AI avatar
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryOrange, Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(
                        alpha: 0.25 + 0.2 * _pulseController.value,
                      ),
                      blurRadius: 16 + 8 * _pulseController.value,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin AI Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Live System Access · Local AI Engine',
                        style: TextStyle(
                          fontSize: isNarrow ? 10 : 11,
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Clear history button
          Consumer<AIService>(
            builder: (context, ai, _) => Tooltip(
              message: 'Clear conversation',
              child: IconButton(
                onPressed: ai.clearHistory,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: textSecondary,
                  size: 20,
                ),
                splashRadius: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STATS STRIP
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildStatsStrip(
    bool isDark,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isNarrow = _isNarrowScreen(context);

    final statsChildren = [
      _buildStatChip(
        Icons.calendar_today_rounded,
        _statsLoaded ? '$_totalBookings' : '...',
        'Bookings',
        const Color(0xFF3B82F6),
        isDark,
      ),
      const SizedBox(width: 10),
      _buildStatChip(
        Icons.directions_car_filled_rounded,
        _statsLoaded ? '$_totalVehicles' : '...',
        'Vehicles',
        const Color(0xFF22C55E),
        isDark,
      ),
      const SizedBox(width: 10),
      _buildStatChip(
        Icons.attach_money_rounded,
        _statsLoaded
            ? 'RM ${(_totalRevenue / 1000).toStringAsFixed(1)}k'
            : '...',
        'Revenue',
        AppColors.primaryOrange,
        isDark,
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryOrange.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.security_rounded,
              size: 12,
              color: AppColors.primaryOrange,
            ),
            const SizedBox(width: 4),
            Text(
              'Admin Mode',
              style: TextStyle(
                fontSize: isNarrow ? 9 : 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryOrange,
              ),
            ),
          ],
        ),
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 24,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172033) : const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: isNarrow
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: statsChildren),
            )
          : Row(
              children: [
                ...statsChildren.take(5),
                const Spacer(),
                statsChildren.last,
              ],
            ),
    );
  }

  Widget _buildStatChip(
    IconData icon,
    String value,
    String label,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: color.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MESSAGE LIST
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildMessageList(bool isDark, Color bg) {
    return Consumer<AIService>(
      builder: (context, ai, _) {
        final messages = ai.messages;
        final isLoading = ai.isLoading;
        final count = messages.length + (isLoading ? 1 : 0);
        _scrollToBottom();

        if (messages.length <= 1) {
          // Show welcome / suggested actions
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFFFFF7ED), const Color(0xFFFFF3E0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.waving_hand_rounded,
                              color: AppColors.primaryOrange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Welcome, Administrator',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'I\'m your Admin AI Assistant with live access to your CARENT system. Ask me about bookings, revenue, fleet status, customers, maintenance, reports, and more.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Suggested actions
                Text(
                  'Suggested Actions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickCommands.map((cmd) {
                    return InkWell(
                      onTap: () => _sendMessage(cmd.query),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.15 : 0.05,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          cmd.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppColors.secondaryBlue,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: count,
          itemBuilder: (context, index) {
            if (index == messages.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 20,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        size: 15,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const TypingIndicator(dotSize: 5.5),
                  ],
                ),
              );
            }
            return AIMessageBubble(message: messages[index]);
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // QUICK CHIPS STRIP
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildQuickChips(bool isDark, Color cardBg, Color borderCol) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172033) : const Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: borderCol)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: _quickCommands.take(8).map((cmd) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => _sendMessage(cmd.query),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    cmd.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : AppColors.secondaryBlue,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // INPUT BAR
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildInputBar(
    bool isDark,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textSecondary,
  ) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: borderCol)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 130),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderCol),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      _sendMessage(_controller.text);
                    }
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Ask about bookings, revenue, fleet, reports...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (val) => _sendMessage(val),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Consumer<AIService>(
              builder: (context, ai, _) {
                final canSend = !ai.isLoading;
                return GestureDetector(
                  onTap: canSend ? () => _sendMessage(_controller.text) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: canSend
                          ? const LinearGradient(
                              colors: [
                                AppColors.primaryOrange,
                                Color(0xFFEA580C),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: canSend
                          ? null
                          : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      shape: BoxShape.circle,
                      boxShadow: canSend
                          ? [
                              BoxShadow(
                                color: AppColors.primaryOrange.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      ai.isLoading
                          ? Icons.hourglass_empty_rounded
                          : Icons.arrow_upward_rounded,
                      color: canSend
                          ? Colors.white
                          : (isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1)),
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Simple data class for quick commands
class _QuickCommand {
  final String label;
  final String query;
  const _QuickCommand(this.label, this.query);
}
