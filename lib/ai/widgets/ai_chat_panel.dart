import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../constants/colors.dart';
import '../../services/receipt_service.dart';
import '../../models/booking_model.dart';
import '../../models/vehicle_model.dart';
import '../../screens/auth/customer/booking_screen.dart';
import '../services/ai_service.dart';
import 'ai_message_bubble.dart';
import 'typing_indicator.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  showAIChatModal  –  entry point (modal route overlay)
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the unified AI Chat panel as a modal overlay.
Future<dynamic> showAIChatModal(
  BuildContext context, {
  String? initialMessage,
}) async {
  final double width = MediaQuery.of(context).size.width;
  final bool isDesktop = width > 900;

  if (isDesktop) {
    return await showGeneralDialog<dynamic>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close AI Chat',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        final size = MediaQuery.of(ctx).size;
        final dialogWidth = (size.width * 0.88).clamp(900.0, 1320.0);
        final dialogHeight = (size.height * 0.9).clamp(620.0, 960.0);

        return Center(
          child: Material(
            color: Colors.transparent,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.08),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
                  ),
              child: SizedBox(
                width: dialogWidth,
                height: dialogHeight,
                child: AIChatPanel(
                  onClose: () => Navigator.of(ctx).pop(),
                  initialMessage: initialMessage,
                ),
              ),
            ),
          ),
        );
      },
    );
  } else {
    return await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (ctx) {
        final double screenHeight = MediaQuery.of(ctx).size.height;
        return SizedBox(
          height: screenHeight * 0.9,
          child: AIChatPanel(
            onClose: () => Navigator.of(ctx).pop(),
            initialMessage: initialMessage,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AIChatPanel  –  unified premium guided AI operator chat panel
// ─────────────────────────────────────────────────────────────────────────────

class AIChatPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final String? initialMessage;

  const AIChatPanel({super.key, this.onClose, this.initialMessage});

  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ReceiptService _receiptService = ReceiptService();
  late final AnimationController _fadeController;

  bool _showSidebar = false; // toggles history sidebar drawer on mobile

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialMessage!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    super.dispose();
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
    final response = await aiService.sendMessage(text);
    _scrollToBottom();

    // Auto-download receipt triggers
    final action = response.action;
    final bookingId = response.parameters['bookingId']?.toString();
    if (bookingId != null && bookingId.isNotEmpty && mounted) {
      if (action == 'view_receipts' || action == 'view_receipt') {
        await _receiptService.viewReceipt(context, bookingId);
      } else if (action == 'download_receipt') {
        await _receiptService.downloadReceipt(context, bookingId);
      } else if (action == 'select_payment_method') {
        if (mounted) {
          Navigator.of(context).pop({
            'action': 'pay',
            'bookingId': bookingId,
            'method':
                response.parameters['method']?.toString() ??
                'FPX Online Banking',
          });
          return;
        }
      }

      if (action == 'search_vehicles' ||
          action == 'view_bookings' ||
          action == 'view_history' ||
          action == 'open_profile' ||
          action == 'contact_support' ||
          action == 'show_branches' ||
          action == 'show_rewards' ||
          action == 'open_pending_bookings') {
        if (mounted) {
          Navigator.of(context).pop(action);
          return;
        }
      } else if (action == 'open_payment_page') {
        try {
          final bookingSnap = await FirebaseDatabase.instance
              .ref()
              .child('bookings')
              .child(bookingId)
              .get();
          if (bookingSnap.exists) {
            final bData = Map<dynamic, dynamic>.from(bookingSnap.value as Map);
            final booking = BookingModel.fromMap(bookingId, bData);

            final vId = bData['vehicleId'] as String;
            final vehicleSnap = await FirebaseDatabase.instance
                .ref()
                .child('vehicles')
                .child(vId)
                .get();
            if (vehicleSnap.exists) {
              final vData = Map<dynamic, dynamic>.from(
                vehicleSnap.value as Map,
              );
              final vehicle = VehicleModel.fromMap(vId, vData);

              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingScreen(
                      vehicle: vehicle,
                      existingBooking: booking,
                    ),
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Error navigating to payment screen from AI: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double width = MediaQuery.of(context).size.width;
    final bool showPermanentSidebar =
        width > 600; // side-by-side on wide screens
    final bool showSidebarOverlay = !showPermanentSidebar && _showSidebar;
    final double mobileSidebarWidth = width * 0.82;

    final bool isDesktopModal = widget.onClose != null && width > 900;
    final radius = widget.onClose != null
        ? (isDesktopModal
              ? BorderRadius.circular(24)
              : const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ))
        : BorderRadius.zero;

    return FadeTransition(
      opacity: _fadeController,
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: radius,
            boxShadow: widget.onClose != null
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, -6),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  // 1. Pinned Chats & History sidebar (desktop/tablet split mode)
                  if (showPermanentSidebar)
                    Container(
                      width: 220,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC),
                        border: Border(
                          right: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: _buildSidebar(isDark),
                    ),

                  // 2. Chat Pane
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        _buildHeader(isDark, showPermanentSidebar),
                        Expanded(child: _buildBody(isDark)),
                        _buildQuickChips(isDark),
                        _buildInputBar(isDark),
                      ],
                    ),
                  ),
                ],
              ),

              // 3. Mobile overlay sidebar (prevents width squeezing overflow)
              if (showSidebarOverlay) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSidebar = false;
                      });
                    },
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: mobileSidebarWidth.clamp(240.0, 320.0),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          border: Border(
                            right: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(2, 0),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: _buildSidebar(isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Sidebar drawer details (pinned, search, chat list, new chat button)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSidebar(bool isDark) {
    final textCol = isDark ? Colors.white : AppColors.secondaryBlue;
    return Column(
      children: [
        // New Chat Button
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              minimumSize: const Size(double.infinity, 44),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'New Chat',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () {
              context.read<AIService>().createNewSession();
              setState(() {
                _showSidebar = false; // close overlay on click (mobile)
              });
            },
          ),
        ),
        // Search Input
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ).copyWith(bottom: 10),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: TextField(
              onChanged: (val) {
                context.read<AIService>().setSearchQuery(val);
              },
              style: TextStyle(fontSize: 12, color: textCol),
              decoration: const InputDecoration(
                hintText: 'Search chats...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 10),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        // Sessions list
        Expanded(
          child: Consumer<AIService>(
            builder: (context, ai, _) {
              final sessions = ai.filteredSessions;
              if (sessions.isEmpty) {
                return const Center(
                  child: Text(
                    'No chats found',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                itemCount: sessions.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final s = sessions[index];
                  final isActive = s.id == ai.activeSessionId;
                  return _buildSessionItem(s, isActive, isDark);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSessionItem(
    ConversationSession session,
    bool isActive,
    bool isDark,
  ) {
    final textCol = isDark ? Colors.white : AppColors.secondaryBlue;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: textCol,
          ),
        ),
        leading: Icon(
          session.isPinned
              ? Icons.push_pin_rounded
              : Icons.chat_bubble_outline_rounded,
          size: 14,
          color: session.isPinned ? AppColors.primaryOrange : Colors.grey,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                session.isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                size: 12,
                color: Colors.grey,
              ),
              onPressed: () =>
                  context.read<AIService>().togglePinSession(session.id),
              splashRadius: 12,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 12,
                color: Colors.grey,
              ),
              onPressed: () =>
                  context.read<AIService>().deleteSession(session.id),
              splashRadius: 12,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        onTap: () {
          context.read<AIService>().selectSession(session.id);
          setState(() {
            _showSidebar = false; // close on mobile tap
          });
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HEADER  (role-aware title & status badge + sidebar toggler)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark, bool showPermanentSidebar) {
    return Consumer<AIService>(
      builder: (context, ai, _) {
        final isAdmin = ai.isAdmin;
        final headerBg = isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF8FAFC);
        final borderCol = isDark
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0);
        final textPrimary = isDark ? Colors.white : AppColors.secondaryBlue;
        final textSecondary = isDark
            ? const Color(0xFF64748B)
            : AppColors.lightText;
        final isNarrowMobile =
            !showPermanentSidebar && MediaQuery.of(context).size.width < 390;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(bottom: BorderSide(color: borderCol)),
          ),
          child: Row(
            children: [
              // Sidebar toggler (shown on mobile or when side menu is collapsed)
              if (!showPermanentSidebar) ...[
                IconButton(
                  icon: Icon(Icons.menu_open_rounded, color: textPrimary),
                  onPressed: () {
                    setState(() {
                      _showSidebar = !_showSidebar;
                    });
                  },
                  splashRadius: 20,
                  tooltip: 'Chat History',
                ),
                const SizedBox(width: 6),
              ],

              // AI avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryOrange, Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isAdmin ? Icons.psychology_rounded : Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'CARENT AI Operator',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isNarrowMobile ? 12.5 : 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.1,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryOrange.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Admin Mode',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isNarrowMobile
                              ? 'Connected'
                              : 'Connected · Live Data Feed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Clear button
              Tooltip(
                message: 'Clear conversation',
                child: IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: textSecondary,
                  ),
                  onPressed: () => context.read<AIService>().clearHistory(),
                  splashRadius: 18,
                ),
              ),
              // Close button (only when used as a modal)
              if (widget.onClose != null)
                Tooltip(
                  message: 'Close',
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: textSecondary,
                    ),
                    onPressed: widget.onClose,
                    splashRadius: 18,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BODY  (Welcome grid onboarding  |  message list when chatting)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody(bool isDark) {
    return Consumer<AIService>(
      builder: (context, ai, _) {
        final messages = ai.messages;
        final isLoading = ai.isLoading;
        final count = messages.length + (isLoading ? 1 : 0);

        _scrollToBottom();

        // Onboarding Welcome page when chat has only the initial welcome message
        if (messages.length <= 1 && !isLoading) {
          return _buildWelcomeGrid(isDark, ai);
        }

        return ListView.builder(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: count,
          itemBuilder: (context, index) {
            if (index == messages.length) {
              return _buildTypingRow();
            }
            return AIMessageBubble(message: messages[index]);
          },
        );
      },
    );
  }

  // Welcome Screen with popular action cards in a Grid
  Widget _buildWelcomeGrid(bool isDark, AIService ai) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isDarkMobile = isDark && isMobile;
    final borderCol = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textSecondary = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF475569);
    final labelCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final welcome = ai.messages.isNotEmpty ? ai.messages.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Onboarding Welcome Bubble
          if (welcome != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF172033)]
                      : [const Color(0xFFFFF7ED), const Color(0xFFFFF3E0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryOrange, Color(0xFFEA580C)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      ai.isAdmin
                          ? Icons.psychology_rounded
                          : Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      welcome.message,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Suggested actions title
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: labelCol),
              const SizedBox(width: 4),
              Text(
                'POPULAR ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: labelCol,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: isDarkMobile ? 74 : 68,
            ),
            itemCount: ai.quickCommands.length,
            itemBuilder: (context, index) {
              final cmd = ai.quickCommands[index];
              return _buildGridCard(
                cmd,
                cardBg,
                borderCol,
                isDark,
                isDarkMobile: isDarkMobile,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(
    AIQuickCommand cmd,
    Color cardBg,
    Color borderCol,
    bool isDark, {
    required bool isDarkMobile,
  }) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _sendMessage(cmd.query),
        borderRadius: BorderRadius.circular(14),
        hoverColor: cmd.color.withValues(alpha: 0.08),
        splashColor: cmd.color.withValues(alpha: 0.15),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDarkMobile ? 10 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            children: [
              Container(
                width: isDarkMobile ? 30 : 32,
                height: isDarkMobile ? 30 : 32,
                decoration: BoxDecoration(
                  color: cmd.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  cmd.icon,
                  color: cmd.color,
                  size: isDarkMobile ? 15 : 16,
                ),
              ),
              SizedBox(width: isDarkMobile ? 8 : 10),
              Expanded(
                child: Text(
                  cmd.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isDarkMobile ? 10.8 : 11.5,
                    height: isDarkMobile ? 1.2 : 1.15,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : AppColors.secondaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 14,
              color: AppColors.primaryOrange,
            ),
          ),
          const SizedBox(width: 8),
          const TypingIndicator(dotSize: 5.0),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PINNED QUICK CHIPS STRIP (horizontal row at bottom of chat screen)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQuickChips(bool isDark) {
    final borderCol = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final chipBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final stripBg = isDark ? const Color(0xFF172033) : const Color(0xFFF1F5F9);

    return Consumer<AIService>(
      builder: (context, ai, _) {
        // Only show bottom chips when conversation has started (not on welcome screen)
        if (ai.messages.length <= 1) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: stripBg,
            border: Border(top: BorderSide(color: borderCol)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: ai.quickCommands.map((cmd) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _sendMessage(cmd.query),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cmd.icon, color: cmd.color, size: 11),
                          const SizedBox(width: 5),
                          Text(
                            cmd.label.substring(
                              2,
                            ), // Strip the icon emoji prefix
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : AppColors.secondaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  INPUT BAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildInputBar(bool isDark) {
    final borderCol = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final barBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textCol = isDark ? Colors.white : AppColors.secondaryBlue;
    final hintCol = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: barBg,
          border: Border(top: BorderSide(color: borderCol)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
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
                      height: 1.45,
                      color: textCol,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      hintStyle: TextStyle(fontSize: 13, color: hintCol),
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
            const SizedBox(width: 8),
            // Send button
            Consumer<AIService>(
              builder: (context, ai, _) {
                final canSend = !ai.isLoading;
                return GestureDetector(
                  onTap: canSend ? () => _sendMessage(_controller.text) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
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
                                  alpha: 0.35,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
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
                      size: 18,
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
