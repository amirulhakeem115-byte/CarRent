import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../constants/colors.dart';
import '../../models/vehicle_model.dart';
import '../../screens/auth/customer/vehicle_details_screen.dart';
import '../../screens/auth/customer/booking_screen.dart';
import '../models/ai_message.dart';
import '../services/ai_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/reward_points_slider.dart';

class AIMessageBubble extends StatelessWidget {
  final AIMessage message;

  const AIMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicleMaps = message.metadata?['vehicles'];
    final List<VehicleModel> vehicles = _parseVehicles(vehicleMaps);
    
    // Custom metadata renderers
    final summary = message.metadata?['summary'];
    final report = message.metadata?['report'];
    final comparison = message.metadata?['comparison'];
    final action = message.metadata?['action'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                _buildAvatar(context),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppColors.primaryOrange
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMessageText(context, isUser, isDark),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(message.timestamp),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isUser
                                      ? Colors.white70
                                      : (isDark ? Colors.white30 : Colors.black38),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Copy & Share utilities (for AI messages only)
                    if (!isUser) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => context.read<AIService>().copyToClipboard(context, message.message),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 10, color: Colors.grey),
                                  SizedBox(width: 3),
                                  Text('Copy', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => context.read<AIService>().shareMessage(context, message.message),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.share_rounded, size: 10, color: Colors.grey),
                                  SizedBox(width: 3),
                                  Text('Share', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                _buildAvatar(context),
              ],
            ],
          ),

          // Dynamic Generic MCQ Choice Chips
          if (!isUser && message.metadata?['options'] != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (message.metadata?['options'] as List).map<Widget>((optionName) {
                  return ActionChip(
                    elevation: 1,
                    shadowColor: Colors.black.withValues(alpha: 0.1),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    label: Text(
                      optionName.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white : AppColors.secondaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      context.read<AIService>().sendMessage(optionName.toString());
                    },
                  );
                }).toList(),
              ),
            ),
          ],

          // Dynamic Date Picker Trigger Button
          if (!isUser && message.metadata?['request_date'] != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white),
                label: Text(
                  message.metadata?['request_date'] == 'pickup' 
                      ? 'Select Pick-up Date' 
                      : 'Select Return Date',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: isDark
                              ? const ColorScheme.dark(
                                  primary: AppColors.primaryOrange,
                                  onPrimary: Colors.white,
                                  surface: Color(0xFF1E293B),
                                  onSurface: Color(0xFFF8FAFC),
                                )
                              : const ColorScheme.light(
                                  primary: AppColors.primaryOrange,
                                  onPrimary: Colors.white,
                                  onSurface: AppColors.secondaryBlue,
                                ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
                    final label = message.metadata?['request_date'] == 'pickup' ? 'pickup' : 'return';
                    if (context.mounted) {
                      context.read<AIService>().sendMessage('Selected $label date: $formattedDate');
                    }
                  }
                },
              ),
            ),
          ],

          // Dynamic Reward Points Slider Card (Customer)
          if (!isUser && action == 'redeem_rewards_slider') ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _buildRewardPointsSliderCard(context, isDark),
            ),
          ],

          // Booking Summary Checkout Card (Premium design)
          if (!isUser && summary != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _buildSummaryCard(context, Map<String, dynamic>.from(summary), isDark),
            ),
          ],

          // Admin Report Summary Card (Premium KPI Metrics design)
          if (!isUser && report != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _buildReportCard(context, Map<String, dynamic>.from(report), isDark),
            ),
          ],

          // Vehicle Comparison Side-by-Side Card
          if (!isUser && comparison != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _buildComparisonCard(context, Map<String, dynamic>.from(comparison), isDark),
            ),
          ],

          // Profile & Receipt Image Upload Widgets
          if (!isUser && (action == 'upload_license' || action == 'upload_id' || action == 'upload_receipt')) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: _buildFileUploadCard(context, action!, isDark),
            ),
          ],

          // Vehicle Cards List (guided list search results)
          if (!isUser && vehicles.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 36, right: 4),
                itemCount: vehicles.length,
                separatorBuilder: (context, idx) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildVehicleCard(context, vehicles[index], isDark);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<VehicleModel> _parseVehicles(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) return [];
    final result = <VehicleModel>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          final map = Map<dynamic, dynamic>.from(item);
          final id = map['id']?.toString() ?? '';
          result.add(VehicleModel.fromMap(id, map));
        } catch (_) {}
      }
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Document & Payment Receipt File Upload Panel Widget
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFileUploadCard(BuildContext context, String action, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final isReceipt = action == 'upload_receipt';
    final title = isReceipt ? 'Submit Payment Proof' : 'Upload Profile Document';

    final referenceController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setCardState) {
        String? base64String;
        String? fileName;

        return Container(
          width: 320,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.secondaryBlue),
              ),
              const SizedBox(height: 10),
              if (isReceipt) ...[
                TextField(
                  controller: referenceController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Transaction Reference ID *',
                    labelStyle: TextStyle(fontSize: 11),
                    hintText: 'e.g. Ref: 12345678',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.file_upload, size: 16),
                label: Text(fileName ?? 'Pick File / Capture Image', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    base64String = base64Encode(bytes);
                    setCardState(() {
                      fileName = image.name;
                    });
                  }
                },
              ),
              if (fileName != null) ...[
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    if (isReceipt) {
                      final ref = referenceController.text.trim();
                      if (ref.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter transaction reference ID')),
                        );
                        return;
                      }
                      context.read<AIService>().sendMessage("Uploaded receipt: [Ref: $ref] [base64:$base64String]");
                    } else {
                      final docType = action == 'upload_license' ? 'license' : 'id';
                      context.read<AIService>().sendMessage("Uploaded document: $docType [base64:$base64String]");
                    }
                  },
                  child: const Text('Submit Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Vehicle Side-by-Side Comparison Card Widget
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildComparisonCard(BuildContext context, Map<String, dynamic> data, bool isDark) {
    final titleCol = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textCol = isDark ? const Color(0xFFCBD5E1) : Colors.black87;

    final c1 = data['car1'];
    final c2 = data['car2'];

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: borderCol)),
            ),
            child: Row(
              children: [
                const Icon(Icons.compare_arrows_rounded, color: Colors.indigo, size: 16),
                const SizedBox(width: 8),
                Text('VEHICLE COMPARISON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: titleCol)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.0),
                2: FlexColumnWidth(1.0),
              },
              children: [
                TableRow(children: [
                  const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('Spec', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(c1['model'] ?? 'Car 1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: titleCol))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(c2['model'] ?? 'Car 2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: titleCol))),
                ]),
                _compRow('Price/Day', 'RM ${c1['pricePerDay']}', 'RM ${c2['pricePerDay']}', textCol),
                _compRow('Category', c1['category'], c2['category'], textCol),
                _compRow('Seats', '${c1['seats']}', '${c2['seats']}', textCol),
                _compRow('Transmission', c1['transmission'], c2['transmission'], textCol),
                _compRow('Fuel', c1['fuelType'], c2['fuelType'], textCol),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () {
                      context.read<AIService>().sendMessage("Book ${c1['brand']} ${c1['model']} [${c1['id']}]");
                    },
                    child: Text('Book ${c1['model']}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () {
                      context.read<AIService>().sendMessage("Book ${c2['brand']} ${c2['model']} [${c2['id']}]");
                    },
                    child: Text('Book ${c2['model']}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _compRow(String spec, String v1, String v2, Color color) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(spec, style: const TextStyle(fontSize: 9, color: Colors.grey))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(v1, style: TextStyle(fontSize: 9, color: color))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(v2, style: TextStyle(fontSize: 9, color: color))),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Premium Guided Checkout Summary Card Widget
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> data, bool isDark) {
    final titleCol = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textCol = isDark ? const Color(0xFFCBD5E1) : Colors.black87;

    final days = data['days'] ?? 1;
    final pricePerDay = data['pricePerDay'] ?? 180.0;
    final totalPrice = data['totalPrice'] ?? (days * pricePerDay);
    final discount = data['discount'] ?? 0.0;
    final total = data['total'] ?? (totalPrice - discount);
    final deposit = data['deposit'] ?? (total * 0.3);
    final balance = data['balance'] ?? (total - deposit);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: borderCol)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.primaryOrange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'RESERVATION SUMMARY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: titleCol,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['vehicleName'] ?? 'Vehicle',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleCol),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      data['branch'] ?? 'Branch',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${data['pickupDate']} @ ${data['pickupTime'] ?? "09:00 AM"} - ${data['returnDate']} ($days Days)',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _priceDetailRow('Daily Rental', 'RM ${pricePerDay.toStringAsFixed(0)}', textCol),
                _priceDetailRow('Base Price ($days days)', 'RM ${totalPrice.toStringAsFixed(2)}', textCol),
                if (discount > 0)
                  _priceDetailRow('Loyalty Discount', '- RM ${discount.toStringAsFixed(2)}', Colors.green, isBold: true),
                _priceDetailRow('Tax (6% SST)', 'RM 0.00', textCol),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleCol)),
                    Text('RM ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryOrange)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Deposit due now (30%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                    Text('RM ${deposit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primaryOrange)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Remaining balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('RM ${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    context.read<AIService>().sendMessage('Confirm Booking');
                  },
                  child: const Text('Confirm Booking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryOrange),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () {
                          context.read<AIService>().sendMessage('Edit Details');
                        },
                        child: const Text('Edit', style: TextStyle(fontSize: 11, color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          context.read<AIService>().sendMessage('Cancel Checkout');
                        },
                        child: const Text('Cancel', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceDetailRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Premium Guided Admin Report Card Widget
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> data, bool isDark) {
    final titleCol = isDark ? const Color(0xFFF8FAFC) : AppColors.secondaryBlue;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final rev = data['revenue'] ?? 0.0;
    final bookings = data['bookingsCount'] ?? 0;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: borderCol)),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics_rounded, color: Colors.teal, size: 16),
                const SizedBox(width: 8),
                Text(
                  'SYSTEM REPORT SUMMARY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: titleCol,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timeframe: ${data['timeframe']}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: titleCol),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _kpiTile('Total Revenue', 'RM ${rev.toStringAsFixed(0)}', Colors.green, isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _kpiTile('Bookings', '$bookings Count', Colors.orange, isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _kpiTile('Utilization', data['utilizationRate'] ?? '0%', Colors.blue, isDark)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 12),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          context.read<AIService>().sendMessage('Export PDF');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.table_view_rounded, size: 12),
                        label: const Text('Export Excel', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          context.read<AIService>().sendMessage('Export Excel');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {
                      context.read<AIService>().sendMessage('View Details');
                    },
                    child: const Text('View Details', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiTile(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Standard Vehicle Card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildVehicleCard(BuildContext context, VehicleModel vehicle, bool isDark) {
    final isAvailable = vehicle.status.toLowerCase() == 'available';
    final isSelectionMode = message.metadata?['isSelectionMode'] == true;

    return Container(
      width: 185,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: AppImage(
                  imageSrc: vehicle.mainImage,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    height: 100,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    child: const Icon(Icons.directions_car, color: Colors.grey),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vehicle.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vehicle.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle.brand} ${vehicle.model}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.secondaryBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.settings_input_component_outlined,
                      size: 9,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      vehicle.transmission,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.airline_seat_recline_normal_rounded,
                      size: 9,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${vehicle.seats} Seats',
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Fuel: ${vehicle.fuelType}',
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'RM ${vehicle.pricePerDay.toStringAsFixed(0)}/day',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 26),
                          side: const BorderSide(color: AppColors.primaryOrange, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VehicleDetailsScreen(vehicle: vehicle),
                            ),
                          );
                        },
                        child: const Text('View', style: TextStyle(fontSize: 9, color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAvailable ? AppColors.primaryOrange : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 26),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: isAvailable ? () {
                          if (isSelectionMode) {
                            context.read<AIService>().sendMessage("Select Vehicle: ${vehicle.brand} ${vehicle.model} [${vehicle.id}]");
                          } else {
                            final pickupStr = message.metadata?['prefilledPickupDate']?.toString();
                            final returnStr = message.metadata?['prefilledReturnDate']?.toString();
                            final pickupDate = pickupStr != null ? DateTime.tryParse(pickupStr) : null;
                            final returnDate = returnStr != null ? DateTime.tryParse(returnStr) : null;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookingScreen(
                                  vehicle: vehicle,
                                  prefilledPickupDate: pickupDate,
                                  prefilledReturnDate: returnDate,
                                ),
                              ),
                            );
                          }
                        } : null,
                        child: Text(isSelectionMode ? 'Select' : 'Book Now', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final isUser = message.role == 'user';
    if (isUser) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.secondaryBlue,
        child: const Icon(Icons.person_rounded, size: 14, color: Colors.white),
      );
    } else {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.smart_toy_rounded,
            size: 14,
            color: AppColors.primaryOrange,
          ),
        ),
      );
    }
  }

  Widget _buildMessageText(BuildContext context, bool isUser, bool isDark) {
    final textStyle = TextStyle(
      fontSize: 12.5,
      height: 1.4,
      color: isUser
          ? Colors.white
          : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
    );

    final text = message.message;
    final List<InlineSpan> spans = [];

    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('•')) {
        spans.add(const TextSpan(text: '  • ', style: TextStyle(fontWeight: FontWeight.bold)));
        _parseInlineText(line.trim().substring(1).trim(), spans, isUser, isDark);
      } else {
        _parseInlineText(line, spans, isUser, isDark);
      }
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return Text.rich(
      TextSpan(
        style: textStyle,
        children: spans,
      ),
    );
  }

  void _parseInlineText(String text, List<InlineSpan> spans, bool isUser, bool isDark) {
    final regExp = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*');
    int start = 0;

    for (final match in regExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final matchText = match.group(1) ?? match.group(2) ?? '';
      spans.add(TextSpan(
        text: matchText,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildRewardPointsSliderCard(BuildContext context, bool isDark) {
    final available = message.metadata?['availablePoints'] as int? ?? 0;
    final limit = message.metadata?['maxPointsLimit'] as int? ?? 1000;

    return SizedBox(
      width: 320,
      child: RewardPointsSlider(
        initialValue: 0,
        availablePoints: available,
        maxPointsLimit: limit,
        isAdmin: false,
        showConfirmButton: true,
        confirmButtonLabel: 'Apply Discount',
        onConfirmed: (val) {
          context.read<AIService>().sendMessage('Redeem $val points');
        },
      ),
    );
  }
}
