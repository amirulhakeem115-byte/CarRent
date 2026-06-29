import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../models/user_model.dart';
import '../../../services/reward_service.dart';
import '../../../services/database_service.dart';
import '../../../widgets/loading_widget.dart';

class RewardPointsView extends StatefulWidget {
  const RewardPointsView({super.key});

  @override
  State<RewardPointsView> createState() => _RewardPointsViewState();
}

class _RewardPointsViewState extends State<RewardPointsView> with SingleTickerProviderStateMixin {
  final RewardPointsService _rewardService = RewardPointsService();
  final DatabaseService _databaseService = DatabaseService();

  late TabController _tabController;
  List<UserModel> _customers = [];
  bool _loadingCustomers = true;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    if (!mounted) return;
    setState(() => _loadingCustomers = true);
    try {
      final allUsers = await _databaseService.getUsers().timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _customers = allUsers.where((u) => u.role == 'customer').toList();
          _loadingCustomers = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading customers: $e');
      if (mounted) {
        setState(() => _loadingCustomers = false);
      }
    }
  }

  void _showAdjustmentDialog(UserModel customer) {
    final pointsController = TextEditingController();
    final reasonController = TextEditingController();
    bool isAdding = true;
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Adjust Points: ${customer.fullName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Current Balance: ${customer.rewardPoints} Points',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Add Points')),
                            selected: isAdding,
                            selectedColor: Colors.blue.withValues(alpha: 0.15),
                            backgroundColor: Colors.grey[100],
                            labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isAdding ? Colors.blue : AppColors.secondaryBlue),
                            onSelected: (_) => setDialogState(() => isAdding = true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Deduct Points')),
                            selected: !isAdding,
                            selectedColor: Colors.redAccent.withValues(alpha: 0.15),
                            backgroundColor: Colors.grey[100],
                            labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !isAdding ? Colors.redAccent : AppColors.secondaryBlue),
                            onSelected: (_) => setDialogState(() => isAdding = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Points Count',
                        errorText: errorText,
                      ),
                      onChanged: (val) {
                        final amt = int.tryParse(val) ?? 0;
                        setDialogState(() {
                          if (amt < 0) {
                            errorText = 'Points must be positive';
                          } else if (!isAdding && amt > customer.rewardPoints) {
                            errorText = 'Cannot deduct more than balance';
                          } else {
                            errorText = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason for Adjustment',
                        hintText: 'e.g. Loyalty program bonus, correction...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAdding ? Colors.blue : Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final points = int.tryParse(pointsController.text.trim()) ?? 0;
                    final reason = reasonController.text.trim();

                    if (points <= 0) {
                      setDialogState(() => errorText = 'Enter a valid points amount');
                      return;
                    }
                    if (!isAdding && points > customer.rewardPoints) {
                      setDialogState(() => errorText = 'Exceeds current balance');
                      return;
                    }
                    if (reason.isEmpty) {
                      setDialogState(() => errorText = 'Reason is required');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please specify a reason for adjustment')),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    // Show progress bar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Processing adjustment...')),
                    );

                    try {
                      final change = isAdding ? points : -points;
                      await _rewardService.adjustPoints(customer.id, change, reason);
                      await _loadCustomers();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Adjustment saved successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Adjustment failed: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  child: const Text('Apply Adjust'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _rewardService.getAllTransactionsStream(),
        builder: (context, ledgerSnapshot) {
          final txs = ledgerSnapshot.data ?? [];

          // Compute system rewards aggregates
          int totalIssued = 0;
          int totalRedeemed = 0;

          for (var tx in txs) {
            final int points = tx['points'] ?? 0;
            final String type = tx['type'] ?? '';
            if (type == 'Earn' || (type == 'Adjustment' && points > 0)) {
              totalIssued += points;
            } else if (type == 'Redeem' || (type == 'Adjustment' && points < 0)) {
              totalRedeemed += points.abs();
            }
          }

          return Column(
            children: [
              // 1. Stats Overview Panel
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Total Points Issued',
                              value: '$totalIssued',
                              icon: Icons.stars_rounded,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Total Points Redeemed',
                              value: '$totalRedeemed',
                              icon: Icons.shopping_bag_outlined,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Total Customers',
                              value: '${_customers.length}',
                              icon: Icons.people_outline_rounded,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        childAspectRatio: 1.6,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildMetricCard(
                            title: 'Points Issued',
                            value: '$totalIssued',
                            icon: Icons.stars_rounded,
                            color: AppColors.primaryOrange,
                          ),
                          _buildMetricCard(
                            title: 'Points Redeemed',
                            value: '$totalRedeemed',
                            icon: Icons.shopping_bag_outlined,
                            color: Colors.green,
                          ),
                          _buildMetricCard(
                            title: 'Total Customers',
                            value: '${_customers.length}',
                            icon: Icons.people_outline_rounded,
                            color: const Color(0xFF3B82F6),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),

              // Tab Menu Header
              Container(
                margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryOrange,
                  unselectedLabelColor: AppColors.lightText,
                  indicatorColor: AppColors.primaryOrange,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Customer Balances'),
                    Tab(text: 'Global Activity Ledger'),
                  ],
                ),
              ),

              // Tab Body View
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCustomerTab(),
                      _buildLedgerTab(txs),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomerTab() {
    if (_loadingCustomers) {
      return const Center(child: LoadingWidget(message: 'Loading customer loyalty list...'));
    }

    final filtered = _customers.where((u) {
      if (_searchQuery == null || _searchQuery!.isEmpty) return true;
      final q = _searchQuery!.toLowerCase();
      return u.fullName.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Search Bar Row
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Search customer by name or email...',
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.secondaryBlue),
                onPressed: _loadCustomers,
                tooltip: 'Refresh Customers',
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No customers found matching search filter.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.05),
                        child: const Icon(Icons.person_rounded, color: AppColors.secondaryBlue),
                      ),
                      title: Text(customer.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
                      subtitle: Text(customer.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stars_rounded, color: AppColors.primaryOrange, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  '${customer.rewardPoints} Points',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryOrange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.secondaryBlue),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.edit_note, size: 14, color: AppColors.secondaryBlue),
                            label: const Text('Adjust', style: TextStyle(fontSize: 11, color: AppColors.secondaryBlue, fontWeight: FontWeight.bold)),
                            onPressed: () => _showAdjustmentDialog(customer),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLedgerTab(List<Map<String, dynamic>> txs) {
    if (txs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_rounded, size: 56, color: Colors.grey[200]),
            const SizedBox(height: 12),
            const Text('No transactions recorded in system', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: txs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tx = txs[index];
        final String userId = tx['userId'] ?? '';
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

        // Try mapping userId to customer name for clean display
        String userDisplay = 'User: $userId';
        try {
          final matched = _customers.firstWhere((c) => c.id == userId);
          userDisplay = '${matched.fullName} (${matched.email})';
        } catch (_) {}

        IconData itemIcon = Icons.stars_rounded;
        Color itemColor = AppColors.primaryOrange;
        String labelText = 'Points Earned';

        if (type == 'Redeem') {
          itemIcon = Icons.shopping_bag_outlined;
          itemColor = Colors.green;
          labelText = 'Points Redeemed';
        } else if (type == 'Adjustment') {
          itemIcon = points >= 0 ? Icons.card_giftcard_rounded : Icons.exposure_minus_1_rounded;
          itemColor = points >= 0 ? Colors.blue : Colors.redAccent;
          labelText = points >= 0 ? 'Admin Credit adjustment' : 'Admin Debit adjustment';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: itemColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(itemIcon, color: itemColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelText,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryBlue),
                    ),
                    const SizedBox(height: 2),
                    Text(userDisplay, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold)),
                    if (bookingId.isNotEmpty)
                      Text('Booking ID: #${bookingId.toUpperCase()}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    if (reason.isNotEmpty)
                      Text('Reason: $reason', style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    Text(formattedDate, style: TextStyle(color: Colors.grey[400], fontSize: 9)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    points >= 0 ? '+$points' : '$points',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: points >= 0 ? AppColors.primaryOrange : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Balance: $balanceAfter', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ],
      ),
    );
  }
}
