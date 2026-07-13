import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

class RewardPointsSlider extends StatefulWidget {
  final int initialValue;
  final int availablePoints;
  final int maxPointsLimit;
  final bool isAdmin;
  final bool isDeductMode; // For Admin: Credit (add) vs Debit (deduct)
  final bool showConfirmButton;
  final String confirmButtonLabel;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onConfirmed;

  const RewardPointsSlider({
    super.key,
    required this.initialValue,
    required this.availablePoints,
    required this.maxPointsLimit,
    this.isAdmin = false,
    this.isDeductMode = false,
    this.showConfirmButton = false,
    this.confirmButtonLabel = 'Confirm Points',
    this.onChanged,
    this.onConfirmed,
  });

  @override
  State<RewardPointsSlider> createState() => _RewardPointsSliderState();
}

class _RewardPointsSliderState extends State<RewardPointsSlider> {
  late int _selectedValue;
  late int _maxVal;

  @override
  void initState() {
    super.initState();
    _computeMaxVal();
    _selectedValue = widget.initialValue.clamp(0, _maxVal);
  }

  @override
  void didUpdateWidget(covariant RewardPointsSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _computeMaxVal();
    if (oldWidget.initialValue != widget.initialValue ||
        oldWidget.availablePoints != widget.availablePoints ||
        oldWidget.maxPointsLimit != widget.maxPointsLimit ||
        oldWidget.isAdmin != widget.isAdmin ||
        oldWidget.isDeductMode != widget.isDeductMode) {
      setState(() {
        _selectedValue = widget.initialValue.clamp(0, _maxVal);
      });
    }
  }

  void _computeMaxVal() {
    if (widget.isAdmin) {
      if (widget.isDeductMode) {
        // Admin removing points: can only remove up to the customer's balance or system limit
        _maxVal = min(widget.availablePoints, widget.maxPointsLimit);
      } else {
        // Admin adding points: up to the global limit
        _maxVal = widget.maxPointsLimit;
      }
    } else {
      // Customer: can redeem up to their balance or system limit
      _maxVal = min(widget.availablePoints, widget.maxPointsLimit);
    }
    // Safeguard to prevent _maxVal < 0
    if (_maxVal < 0) {
      _maxVal = 0;
    }
  }

  void _updateValue(int newValue) {
    final clamped = newValue.clamp(0, _maxVal);
    if (_selectedValue != clamped) {
      setState(() {
        _selectedValue = clamped;
      });
      widget.onChanged?.call(clamped);
    }
  }

  void _adjustBy(int amount) {
    _updateValue(_selectedValue + amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.lightText;

    final discount = _selectedValue * 0.10;

    // Remaining / New balance calculation
    int targetBalance = widget.availablePoints;
    if (widget.isAdmin) {
      if (widget.isDeductMode) {
        targetBalance = widget.availablePoints - _selectedValue;
      } else {
        targetBalance = widget.availablePoints + _selectedValue;
      }
    } else {
      targetBalance = widget.availablePoints - _selectedValue;
    }
    if (targetBalance < 0) targetBalance = 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header showing Available Balance / Limit
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 340;

              final leftInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isAdmin
                        ? (widget.isDeductMode
                              ? 'Deduct Points'
                              : 'Credit Points')
                        : 'Redeem Points',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.isDeductMode
                          ? Colors.redAccent
                          : AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.isAdmin
                        ? 'Current Balance: ${widget.availablePoints} pts'
                        : 'Available Balance: ${widget.availablePoints} pts',
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );

              final limitBadge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'Limit: ${widget.maxPointsLimit}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [leftInfo, const SizedBox(height: 8), limitBadge],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: leftInfo),
                  const SizedBox(width: 8),
                  limitBadge,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Slider & Step Buttons Row
          Row(
            children: [
              // Minus Step Button
              IconButton(
                onPressed: _maxVal > 0 && _selectedValue > 0
                    ? () => _adjustBy(-1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.primaryOrange,
                disabledColor: textSecondary.withValues(alpha: 0.3),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
              // Slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: widget.isDeductMode
                        ? Colors.redAccent
                        : AppColors.primaryOrange,
                    inactiveTrackColor: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    thumbColor: widget.isDeductMode
                        ? Colors.redAccent
                        : AppColors.primaryOrange,
                    overlayColor:
                        (widget.isDeductMode
                                ? Colors.redAccent
                                : AppColors.primaryOrange)
                            .withValues(alpha: 0.15),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: _maxVal > 0 ? _maxVal.toDouble() : 1.0,
                    value: _selectedValue.toDouble(),
                    divisions: _maxVal > 0 ? _maxVal : 1,
                    onChanged: _maxVal > 0
                        ? (val) {
                            _updateValue(val.round());
                          }
                        : null,
                  ),
                ),
              ),
              // Plus Step Button
              IconButton(
                onPressed: _maxVal > 0 && _selectedValue < _maxVal
                    ? () => _adjustBy(1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primaryOrange,
                disabledColor: textSecondary.withValues(alpha: 0.3),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
            ],
          ),

          // Live Preview Stats
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPreviewItem(
                  'Points Selected',
                  '$_selectedValue',
                  widget.isDeductMode
                      ? Colors.redAccent
                      : AppColors.primaryOrange,
                  isDark,
                ),
                if (!widget.isAdmin)
                  _buildPreviewItem(
                    'Equivalent Discount',
                    'RM ${discount.toStringAsFixed(2)}',
                    Colors.green,
                    isDark,
                  ),
                _buildPreviewItem(
                  widget.isAdmin ? 'New Balance' : 'Remaining Balance',
                  '$targetBalance pts',
                  textPrimary,
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Selection Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip('+10', () => _adjustBy(10), isDark),
                _buildQuickChip('+25', () => _adjustBy(25), isDark),
                _buildQuickChip('+50', () => _adjustBy(50), isDark),
                _buildQuickChip('+100', () => _adjustBy(100), isDark),
                _buildQuickChip('+250', () => _adjustBy(250), isDark),
                _buildQuickChip(
                  'Max',
                  () => _updateValue(_maxVal),
                  isDark,
                  highlight: true,
                ),
                _buildQuickChip(
                  'Reset',
                  () => _updateValue(0),
                  isDark,
                  isReset: true,
                ),
              ],
            ),
          ),

          // Optional Confirmation Button
          if (widget.showConfirmButton && widget.onConfirmed != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isDeductMode
                    ? Colors.redAccent
                    : AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 1,
              ),
              onPressed: () {
                widget.onConfirmed?.call(_selectedValue);
              },
              child: Text(
                widget.confirmButtonLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewItem(
    String label,
    String value,
    Color valueColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF64748B) : Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickChip(
    String label,
    VoidCallback onTap,
    bool isDark, {
    bool highlight = false,
    bool isReset = false,
  }) {
    Color labelColor = isDark ? Colors.white70 : Colors.black87;
    Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.grey[200]!;

    if (highlight) {
      labelColor = Colors.white;
      bgColor = widget.isDeductMode
          ? Colors.redAccent
          : AppColors.primaryOrange;
    } else if (isReset) {
      labelColor = isDark ? const Color(0xFFEF4444) : Colors.red;
      bgColor = isDark
          ? const Color(0xFFEF4444).withValues(alpha: 0.1)
          : Colors.red.withValues(alpha: 0.1);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _maxVal > 0 || isReset ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _maxVal > 0 || isReset
                    ? labelColor
                    : labelColor.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
