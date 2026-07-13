import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';
import '../../../models/user_model.dart';
import '../../../services/reward_service.dart';
import '../../../services/database_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/reward_points_slider.dart';
import '../../../services/company_settings_provider.dart';

class RewardPointsView extends StatefulWidget {
  const RewardPointsView({super.key});

  @override
  State<RewardPointsView> createState() => _RewardPointsViewState();
}

class _RewardPointsViewState extends State<RewardPointsView>
    with SingleTickerProviderStateMixin {
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
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
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
      final allUsers = await _databaseService.getUsers().timeout(
        const Duration(seconds: 10),
      );
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
    final pointsController = TextEditingController()..text = '0';
    final reasonController = TextEditingController();
    int selectedPoints = 0;
    bool isAdding = true;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textPrimary = isDark
            ? const Color(0xFFF8FAFC)
            : AppColors.secondaryBlue;
        final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
        final chipBg = isDark ? const Color(0xFF334155) : Colors.grey[100];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dialogWidth = MediaQuery.of(context).size.width < 420
                ? MediaQuery.of(context).size.width * 0.86
                : 420.0;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Adjust Points: ${customer.fullName}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: dialogWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Current Balance: ${customer.rewardPoints} Points',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool isNarrow = constraints.maxWidth < 360;

                          final addChip = ChoiceChip(
                            label: const Center(child: Text('Add Points')),
                            selected: isAdding,
                            selectedColor: Colors.blue.withValues(alpha: 0.15),
                            backgroundColor: chipBg,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isAdding ? Colors.blue : textPrimary,
                            ),
                            onSelected: (_) {
                              setDialogState(() {
                                isAdding = true;
                                selectedPoints = 0;
                                pointsController.text = '0';
                              });
                            },
                          );

                          final deductChip = ChoiceChip(
                            label: const Center(child: Text('Deduct Points')),
                            selected: !isAdding,
                            selectedColor: Colors.redAccent.withValues(
                              alpha: 0.15,
                            ),
                            backgroundColor: chipBg,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !isAdding ? Colors.redAccent : textPrimary,
                            ),
                            onSelected: (_) {
                              setDialogState(() {
                                isAdding = false;
                                selectedPoints = 0;
                                pointsController.text = '0';
                              });
                            },
                          );

                          final double chipWidth = isNarrow
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              SizedBox(width: chipWidth, child: addChip),
                              SizedBox(width: chipWidth, child: deductChip),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      RewardPointsSlider(
                        initialValue: selectedPoints,
                        availablePoints: customer.rewardPoints,
                        maxPointsLimit: CompanySettingsProvider().getField(
                          'maxRewardPointsLimit',
                          defaultValue: 1000,
                        ),
                        isAdmin: true,
                        isDeductMode: !isAdding,
                        showConfirmButton: false,
                        onChanged: (val) {
                          setDialogState(() {
                            selectedPoints = val;
                            pointsController.text = val.toString();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Reason for Adjustment',
                          labelStyle: TextStyle(color: textSecondary),
                          hintText: 'e.g. Loyalty program bonus, correction...',
                          hintStyle: TextStyle(
                            color: textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAdding ? Colors.blue : Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final points =
                        int.tryParse(pointsController.text.trim()) ?? 0;
                    final reason = reasonController.text.trim();

                    if (points <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a valid points amount'),
                        ),
                      );
                      return;
                    }
                    if (!isAdding && points > customer.rewardPoints) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Exceeds current balance'),
                        ),
                      );
                      return;
                    }
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please specify a reason for adjustment',
                          ),
                        ),
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
                      await _rewardService.adjustPoints(
                        customer.id,
                        change,
                        reason,
                      );
                      await _loadCustomers();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Adjustment saved successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Adjustment failed: $e'),
                            backgroundColor: Colors.redAccent,
                          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return StreamBuilder<List<Map<String, dynamic>>>(
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Reward Points Manager',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              Text(
                'Monitor customer reward points balance, adjustments, and global transaction logs.',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 24),

              // 1. Stats Overview Panel
              LayoutBuilder(
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
                            isDark: isDark,
                            cardColor: cardColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Total Points Redeemed',
                            value: '$totalRedeemed',
                            icon: Icons.shopping_bag_outlined,
                            color: Colors.green,
                            isDark: isDark,
                            cardColor: cardColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Total Customers',
                            value: '${_customers.length}',
                            icon: Icons.people_outline_rounded,
                            color: const Color(0xFF3B82F6),
                            isDark: isDark,
                            cardColor: cardColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
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
                      childAspectRatio: 1.32,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildMetricCard(
                          title: 'Points Issued',
                          value: '$totalIssued',
                          icon: Icons.stars_rounded,
                          color: AppColors.primaryOrange,
                          isDark: isDark,
                          cardColor: cardColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderColor: borderColor,
                        ),
                        _buildMetricCard(
                          title: 'Points Redeemed',
                          value: '$totalRedeemed',
                          icon: Icons.shopping_bag_outlined,
                          color: Colors.green,
                          isDark: isDark,
                          cardColor: cardColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderColor: borderColor,
                        ),
                        _buildMetricCard(
                          title: 'Total Customers',
                          value: '${_customers.length}',
                          icon: Icons.people_outline_rounded,
                          color: const Color(0xFF3B82F6),
                          isDark: isDark,
                          cardColor: cardColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderColor: borderColor,
                        ),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 24),

              // Tab Menu Header
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border.all(color: borderColor),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryOrange,
                  unselectedLabelColor: textSecondary,
                  indicatorColor: AppColors.primaryOrange,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Customer Balances'),
                    Tab(text: 'Global Activity Ledger'),
                  ],
                ),
              ),

              // Tab Body View (rendered directly instead of TabBarView for natural height and scrolling)
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border.all(color: borderColor),
                ),
                child: _tabController.index == 0
                    ? _buildCustomerTab(
                        isDark: isDark,
                        cardColor: cardColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                      )
                    : _buildLedgerTab(
                        txs,
                        isDark: isDark,
                        cardColor: cardColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        borderColor: borderColor,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerTab({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    if (_loadingCustomers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: LoadingWidget(message: 'Loading customer loyalty list...'),
        ),
      );
    }

    final filtered = _customers.where((u) {
      if (_searchQuery == null || _searchQuery!.isEmpty) return true;
      final q = _searchQuery!.toLowerCase();
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
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
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: textSecondary,
                    ),
                    hintText: 'Search customer by name or email...',
                    hintStyle: TextStyle(
                      color: textSecondary.withValues(alpha: 0.7),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
                icon: Icon(Icons.refresh, color: textPrimary),
                onPressed: _loadCustomers,
                tooltip: 'Refresh Customers',
              ),
            ],
          ),
        ),

        // List
        filtered.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No customers found matching search filter.',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filtered.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: borderColor),
                itemBuilder: (context, index) {
                  final customer = filtered[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isCompactMobile = constraints.maxWidth < 420;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: isCompactMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.secondaryBlue
                                            .withValues(
                                              alpha: isDark ? 0.2 : 0.05,
                                            ),
                                        child: Icon(
                                          Icons.person_rounded,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer.fullName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              customer.email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryOrange
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.stars_rounded,
                                              color: AppColors.primaryOrange,
                                              size: 14,
                                            ),
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
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildMembershipBadge(
                                            CompanySettingsProvider()
                                                .determineLevel(
                                                  customer.rewardPoints,
                                                ),
                                            isDark,
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: textSecondary,
                                              ),
                                              foregroundColor: textPrimary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: Icon(
                                              Icons.edit_note,
                                              size: 14,
                                              color: textPrimary,
                                            ),
                                            label: Text(
                                              'Adjust',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: textPrimary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _showAdjustmentDialog(customer),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.secondaryBlue
                                        .withValues(alpha: isDark ? 0.2 : 0.05),
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customer.fullName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                            fontSize: 15,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          customer.email,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 12,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryOrange
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.stars_rounded,
                                                  color:
                                                      AppColors.primaryOrange,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${customer.rewardPoints} Points',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.primaryOrange,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildMembershipBadge(
                                            CompanySettingsProvider()
                                                .determineLevel(
                                                  customer.rewardPoints,
                                                ),
                                            isDark,
                                          ),
                                        ],
                                      ),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: textSecondary,
                                          ),
                                          foregroundColor: textPrimary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.edit_note,
                                          size: 14,
                                          color: textPrimary,
                                        ),
                                        label: Text(
                                          'Adjust',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _showAdjustmentDialog(customer),
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
      ],
    );
  }

  Widget _buildMembershipBadge(String level, bool isDark) {
    Color badgeColor;
    Color textColor;
    IconData icon;

    switch (level) {
      case 'Premium':
        badgeColor = const Color(0xFF7C3AED);
        textColor = Colors.white;
        icon = Icons.military_tech_rounded;
        break;
      case 'Gold':
        badgeColor = const Color(0xFFD97706);
        textColor = Colors.white;
        icon = Icons.stars_rounded;
        break;
      case 'Silver':
        badgeColor = const Color(0xFF475569);
        textColor = Colors.white;
        icon = Icons.verified_user_rounded;
        break;
      default:
        badgeColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;
        textColor = isDark ? const Color(0xFFCBD5E1) : Colors.grey[700]!;
        icon = Icons.emoji_events_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 12),
          const SizedBox(width: 4),
          Text(
            level,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTab(
    List<Map<String, dynamic>> txs, {
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    if (txs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.stars_rounded,
                size: 56,
                color: textSecondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No transactions recorded in system',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: txs.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: borderColor),
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
        final formattedDate = DateFormat(
          'dd MMM yyyy, hh:mm a',
        ).format(createdAt);

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
          itemIcon = points >= 0
              ? Icons.card_giftcard_rounded
              : Icons.exposure_minus_1_rounded;
          itemColor = points >= 0 ? Colors.blue : Colors.redAccent;
          labelText = points >= 0
              ? 'Admin Credit adjustment'
              : 'Admin Debit adjustment';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: itemColor.withValues(alpha: 0.15),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userDisplay,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (bookingId.isNotEmpty)
                      Text(
                        'Booking ID: #${bookingId.toUpperCase()}',
                        style: TextStyle(color: textSecondary, fontSize: 10),
                      ),
                    if (reason.isNotEmpty)
                      Text(
                        'Reason: $reason',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.7),
                        fontSize: 9,
                      ),
                    ),
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
                      color: points >= 0
                          ? AppColors.primaryOrange
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Balance: $balanceAfter',
                    style: TextStyle(color: textSecondary, fontSize: 10),
                  ),
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
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final bool isCompactMobile = MediaQuery.of(context).size.width <= 600;

    return Container(
      padding: EdgeInsets.all(isCompactMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: isCompactMobile ? 9 : 10,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                    letterSpacing: 0.5,
                  ),
                  maxLines: isCompactMobile ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isCompactMobile ? 6 : 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isCompactMobile ? 18 : 22,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(isCompactMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isCompactMobile ? 22 : 24),
          ),
        ],
      ),
    );
  }
}
