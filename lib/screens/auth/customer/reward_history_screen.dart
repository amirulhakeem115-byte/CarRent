import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/reward_service.dart';

class RewardHistoryScreen extends StatefulWidget {
  const RewardHistoryScreen({super.key});

  @override
  State<RewardHistoryScreen> createState() => _RewardHistoryScreenState();
}

class _RewardHistoryScreenState extends State<RewardHistoryScreen> {
  final RewardPointsService _rewardService = RewardPointsService();
  final AuthService _authService = AuthService();

  int _currentPoints = 0;
  bool _loadingBalance = true;
  StreamSubscription<DatabaseEvent>? _pointsSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToPoints();
  }

  void _subscribeToPoints() {
    final user = _authService.currentUser;
    if (user != null) {
      _pointsSubscription?.cancel();
      _pointsSubscription = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('rewardPoints')
          .onValue
          .listen((event) {
        if (mounted) {
          int points = 0;
          if (event.snapshot.exists && event.snapshot.value != null) {
            points = int.tryParse(event.snapshot.value.toString()) ?? 0;
          }
          setState(() {
            _currentPoints = points;
            _loadingBalance = false;
          });
        }
      }, onError: (err) {
        debugPrint('Error streaming user points balance: $err');
        if (mounted) {
          setState(() {
            _loadingBalance = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pointsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1B2436) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Loyalty Rewards History',
          style: TextStyle(
            color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue),
            onPressed: () {
              setState(() => _loadingBalance = true);
              _subscribeToPoints();
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Balance Banner Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL REWARD BALANCE',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _loadingBalance
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryOrange,
                                ),
                              )
                            : Text(
                                '$_currentPoints Points',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stars_rounded,
                        color: AppColors.primaryOrange,
                        size: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white60, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Earn 1 point for every RM 10 spent. Redeem points for discount at checkout (10 points = RM 1.00 discount).',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'TRANSACTION LEDGER',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : AppColors.secondaryBlue,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // 2. Transactions List View Stream
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _rewardService.getUserTransactionsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
                }

                if (snapshot.hasError) {
                  debugPrint('Error loading history: ${snapshot.error}');
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Unable to load reward history.\nPlease try again later.',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final txs = snapshot.data ?? [];
                if (txs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stars_rounded, size: 64, color: Colors.grey[200]),
                          const SizedBox(height: 16),
                          const Text(
                            'No reward transactions yet.',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Complete your first booking to start earning points.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: txs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tx = txs[index];
                    final String type = tx['type'] ?? 'Earn';
                    final int points = tx['points'] ?? 0;
                    final int balanceAfter = tx['balanceAfter'] ?? 0;
                    final String createdAtStr = tx['createdAt'] ?? '';
                    final String bookingId = tx['bookingId'] ?? '';
                    final String reason = tx['reason'] ?? '';

                    DateTime createdAt = DateTime.now();
                    if (createdAtStr.isNotEmpty) {
                      try {
                        createdAt = DateTime.parse(createdAtStr);
                      } catch (_) {}
                    }

                    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);

                    IconData itemIcon = Icons.stars_rounded;
                    Color itemColor = AppColors.primaryOrange;
                    String labelText = 'Points Earned';

                    if (type == 'Redeem') {
                      itemIcon = Icons.shopping_bag_outlined;
                      itemColor = Colors.green;
                      labelText = 'Redeemed Discount';
                    } else if (type == 'Adjustment') {
                      itemIcon = points >= 0 ? Icons.card_giftcard_rounded : Icons.exposure_minus_1_rounded;
                      itemColor = points >= 0 ? Colors.blue : Colors.redAccent;
                      labelText = points >= 0 ? 'Admin Credit' : 'Admin Debit';
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : Colors.grey[100]!,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.015),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: itemColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(itemIcon, color: itemColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  labelText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (bookingId.isNotEmpty)
                                  Text(
                                    'Booking: #${bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length).toUpperCase()}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (reason.isNotEmpty)
                                  Text(
                                    reason,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                points >= 0 ? '+$points pts' : '$points pts',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: points >= 0 ? AppColors.primaryOrange : Colors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bal: $balanceAfter',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
