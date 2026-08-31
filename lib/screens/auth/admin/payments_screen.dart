import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import '../../../constants/colors.dart';
import '../../../models/payment_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/payment_service.dart';
import '../../../services/booking_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../services/file_download_helper.dart'
    if (dart.library.html) '../../../services/file_download_web.dart'
    as download_helper;
import '../../../services/company_settings_provider.dart';
import '../../../l10n/app_translations.dart';

class BookingPaymentLedgerItem {
  final BookingModel booking;
  final String customerName;
  final String vehicleName;
  final double totalRentalAmount;
  final double rentalPaid;
  final double rentalRemaining;
  final double deliveryFee;
  final double deliveryPaid;
  final double deliveryRemaining;
  final double discount;
  final double remainingBalance;
  final String status;
  final DateTime lastPaymentDate;
  final List<PaymentModel> payments;

  BookingPaymentLedgerItem({
    required this.booking,
    required this.customerName,
    required this.vehicleName,
    required this.totalRentalAmount,
    required this.rentalPaid,
    required this.rentalRemaining,
    required this.deliveryFee,
    required this.deliveryPaid,
    required this.deliveryRemaining,
    required this.discount,
    required this.remainingBalance,
    required this.status,
    required this.lastPaymentDate,
    required this.payments,
  });
}

class PaymentsView extends StatefulWidget {
  const PaymentsView({super.key});

  @override
  State<PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends State<PaymentsView> {
  final PaymentService _paymentService = PaymentService();
  final BookingService _bookingService = BookingService();

  List<PaymentModel> _payments = [];
  List<BookingModel> _bookings = [];
  final Map<String, String> _userNames = {}; // uid -> fullName
  final Map<String, UserModel> _usersMap = {}; // uid -> UserModel
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isPhoneLayout() => MediaQuery.of(context).size.width < 420;

  double _rf(double base, {double min = 9, double max = 26}) {
    final width = MediaQuery.of(context).size.width;
    final factor = (width / 390).clamp(0.86, 1.0);
    final size = base * factor;
    if (size < min) return min;
    if (size > max) return max;
    return size;
  }

  @override
  void initState() {
    super.initState();
    _loadPayments();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_payments.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final paymentsFuture = _paymentService.getPayments(forceRefresh: forceRefresh);
      final bookingsFuture = _bookingService.getBookings(forceRefresh: forceRefresh);
      final usersSnap = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .get()
          .timeout(const Duration(seconds: 10));

      final results = await Future.wait([paymentsFuture, bookingsFuture]);
      _payments = results[0] as List<PaymentModel>;
      _bookings = results[1] as List<BookingModel>;

      _userNames.clear();
      _usersMap.clear();
      if (usersSnap.exists && usersSnap.value is Map) {
        final Map<dynamic, dynamic> usersData =
            usersSnap.value as Map<dynamic, dynamic>;
        usersData.forEach((key, value) {
          if (value is Map) {
            _userNames[key.toString()] =
                value['fullName'] ?? value['name'] ?? 'User';
            _usersMap[key.toString()] = UserModel.fromMap(
              key.toString(),
              value,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading payments ledger: $e');
      if (_payments.isEmpty) {
        setState(() {
          _error = 'Failed to load booking payment ledger. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int _getElapsedDays(BookingModel booking) {
    final pickup = booking.actualPickupTimestamp ?? booking.pickUpDate;
    final diff = DateTime.now().difference(pickup);
    final days = (diff.inHours / 24.0).ceil();
    return days <= 0 ? 1 : days;
  }

  double _getDynamicPrice(BookingModel booking) {
    if (!booking.isOpenRental || booking.status.toLowerCase() != 'active') {
      return booking.totalPrice;
    }
    final days = _getElapsedDays(booking);
    return days * booking.totalPrice;
  }

  List<BookingPaymentLedgerItem> _buildLedgerItems() {
    List<BookingPaymentLedgerItem> items = [];

    for (var booking in _bookings) {
      final customerName = _userNames[booking.userId] ??
          (booking.userName.isNotEmpty ? booking.userName : 'Customer');
      final vehicleName =
          booking.vehicleName.isNotEmpty ? booking.vehicleName : 'Vehicle';

      final bookingPayments =
          _payments.where((p) => p.bookingId == booking.id).toList();

      final approvedPayments = bookingPayments.where((p) {
        final status = p.status.toLowerCase();
        final pStatus = (p.paymentStatus ?? '').toLowerCase();
        return status == 'approved' ||
            status == 'paid' ||
            pStatus == 'approved' ||
            pStatus == 'paid';
      }).toList();

      final approvedRentalPayments = approvedPayments
          .where((p) => p.paymentPurpose.toLowerCase() != 'delivery')
          .toList();
      final approvedDeliveryPayments = approvedPayments
          .where((p) => p.paymentPurpose.toLowerCase() == 'delivery')
          .toList();

      double rentalPaid = approvedRentalPayments.fold(
        0.0,
        (sum, p) => sum + p.amount,
      );
      final bStat = booking.status.toLowerCase();
      if (approvedRentalPayments.isEmpty &&
          (bStat == 'approved' ||
              bStat == 'confirmed' ||
              bStat == 'active' ||
              bStat == 'ongoing' ||
              bStat == 'completed')) {
        rentalPaid = booking.depositAmount;
      }

      double deliveryPaid = approvedDeliveryPayments.fold(
        0.0,
        (sum, p) => sum + p.amount,
      );

      final double totalRentalAmount = _getDynamicPrice(booking);
      final double discount =
          booking.discountAmount + booking.promotionDiscountAmount;
      final double rentalRemaining = math.max(
        0.0,
        totalRentalAmount - rentalPaid - discount,
      );

      final double deliveryFee = booking.deliveryFee;
      final double deliveryRemaining = math.max(
        0.0,
        deliveryFee - deliveryPaid,
      );

      final double remainingBalance = rentalRemaining + deliveryRemaining;

      DateTime lastPaymentDate = booking.createdAt;
      if (bookingPayments.isNotEmpty) {
        bookingPayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
        lastPaymentDate = bookingPayments.first.paymentDate;
      }

      items.add(
        BookingPaymentLedgerItem(
          booking: booking,
          customerName: customerName,
          vehicleName: vehicleName,
          totalRentalAmount: totalRentalAmount,
          rentalPaid: rentalPaid,
          rentalRemaining: rentalRemaining,
          deliveryFee: deliveryFee,
          deliveryPaid: deliveryPaid,
          deliveryRemaining: deliveryRemaining,
          discount: discount,
          remainingBalance: remainingBalance,
          status: booking.status,
          lastPaymentDate: lastPaymentDate,
          payments: bookingPayments,
        ),
      );
    }

    items.sort((a, b) => b.lastPaymentDate.compareTo(a.lastPaymentDate));
    return items;
  }

  Future<void> _refundTransaction(PaymentModel payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Confirm Refund',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.secondaryBlue,
          ),
        ),
        content: Text(
          'Are you sure you want to issue a full refund of RM ${payment.amount.toStringAsFixed(2)} for this transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Refund'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _paymentService.refundPayment(
        payment.id,
        payment.userId,
        payment.amount,
      );
      _loadPayments();
    }
  }

  Future<void> _showApplyDiscountDialog(BookingModel booking) async {
    final controller = TextEditingController(
      text: booking.discountAmount > 0
          ? booking.discountAmount.toStringAsFixed(2)
          : '',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Apply Discount'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${"Original Rental Amount:".tr(context)} RM ${booking.totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.secondaryBlue,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Discount Amount (RM)'.tr(context),
                hintText: 'e.g. 30.00',
                border: const OutlineInputBorder(),
                prefixText: 'RM ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr(context))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save Discount'.tr(context)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final discountVal = double.tryParse(controller.text.trim()) ?? 0.0;
      final safeDiscount = discountVal < 0 ? 0.0 : math.min(discountVal, booking.totalPrice);
      await FirebaseDatabase.instance
          .ref()
          .child('bookings')
          .child(booking.id)
          .update({'discountAmount': safeDiscount});
      _loadPayments();
    }
  }

  void _openReceiptLightbox(PaymentModel payment) {
    if (payment.receiptImage == null || payment.receiptImage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No receipt file uploaded for this transaction.'),
        ),
      );
      return;
    }

    final isPdf =
        payment.receiptImage!.toLowerCase().contains('.pdf') ||
        payment.receiptImage!.startsWith('data:application/pdf');

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.black54,
                elevation: 0,
                title: Text(
                  isPdf ? 'PDF Receipt document' : 'Receipt Image Lightbox',
                  style: const TextStyle(color: Colors.white),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: () {
                      try {
                        final rawBase64 = payment.receiptImage!.split(',').last;
                        final bytes = base64Decode(rawBase64);
                        final ext = isPdf ? 'pdf' : 'png';
                        download_helper.downloadFile(
                          bytes,
                          'receipt_${payment.id}.$ext',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'File download initiated successfully.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Download failed: $e'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  color: Colors.black87,
                  alignment: Alignment.center,
                  child: isPdf
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.redAccent,
                              size: 100,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'PDF Receipt Document Uploaded',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                try {
                                  final rawBase64 = payment.receiptImage!
                                      .split(',')
                                      .last;
                                  final bytes = base64Decode(rawBase64);
                                  download_helper.downloadFile(
                                    bytes,
                                    'receipt_${payment.id}.pdf',
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Download failed: $e'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Download PDF file to view'),
                            ),
                          ],
                        )
                      : InteractiveViewer(
                          panEnabled: true,
                          boundaryMargin: const EdgeInsets.all(20),
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(
                            base64Decode(payment.receiptImage!.split(',').last),
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _exportExcel() {
    var excelObj = Excel.createExcel();
    var sheet = excelObj[excelObj.getDefaultSheet() ?? 'Sheet1'];

    sheet.appendRow([
      TextCellValue('Booking Ref ID'),
      TextCellValue('Customer Name'),
      TextCellValue('Vehicle'),
      TextCellValue('Total Rental Amount (RM)'),
      TextCellValue('Rental Paid (RM)'),
      TextCellValue('Delivery Paid (RM)'),
      TextCellValue('Discount (RM)'),
      TextCellValue('Remaining (RM)'),
      TextCellValue('Status'),
      TextCellValue('Last Activity Date'),
    ]);

    final ledgerItems = _buildLedgerItems();
    for (var item in ledgerItems) {
      sheet.appendRow([
        TextCellValue(item.booking.id),
        TextCellValue(item.customerName),
        TextCellValue(item.vehicleName),
        DoubleCellValue(item.totalRentalAmount),
        DoubleCellValue(item.rentalPaid),
        DoubleCellValue(item.deliveryPaid),
        DoubleCellValue(item.discount),
        DoubleCellValue(item.remainingBalance),
        TextCellValue(item.status.toUpperCase()),
        TextCellValue(
          DateFormat('yyyy-MM-dd HH:mm').format(item.lastPaymentDate),
        ),
      ]);
    }

    final fileBytes = excelObj.save();
    if (fileBytes != null) {
      final companyName = CompanySettingsProvider().companyName.replaceAll(
        ' ',
        '_',
      );
      download_helper.downloadFile(
        Uint8List.fromList(fileBytes),
        '${companyName}_Booking_Payments_Ledger_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking ledger downloaded in Excel format!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final ledgerItems = _buildLedgerItems();

    List<List<String>> tableData = ledgerItems
        .map(
          (item) => [
            item.booking.id.substring(
              0,
              item.booking.id.length > 8 ? 8 : item.booking.id.length,
            ),
            item.customerName,
            item.vehicleName,
            'RM ${item.totalRentalAmount.toStringAsFixed(2)}',
            'RM ${item.rentalPaid.toStringAsFixed(2)}',
            'RM ${item.deliveryPaid.toStringAsFixed(2)}',
            'RM ${item.discount.toStringAsFixed(2)}',
            'RM ${item.remainingBalance.toStringAsFixed(2)}',
            item.status.toUpperCase(),
          ],
        )
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pdf_lib.PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${CompanySettingsProvider().companyName.toUpperCase()} BOOKING PAYMENTS LEDGER',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                      color: pdf_lib.PdfColor.fromInt(0xFF1A237E),
                    ),
                  ),
                  pw.Text(
                    'Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: [
                'Booking Ref',
                'Customer',
                'Vehicle',
                'Rental Total',
                'Rental Paid',
                'Delivery Paid',
                'Discount',
                'Remaining',
                'Status',
              ],
              data: tableData,
              border: pw.TableBorder.all(
                width: 0.5,
                color: pdf_lib.PdfColor.fromInt(0xFFE0E0E0),
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: pdf_lib.PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: pdf_lib.PdfColor.fromInt(0xFF1A237E),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
          ];
        },
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    final fileBytes = await pdf.save();
    final companyName = CompanySettingsProvider().companyName.replaceAll(
      ' ',
      '_',
    );
    download_helper.downloadFile(
      fileBytes,
      '${companyName}_Booking_Payments_Ledger_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Booking ledger downloaded in PDF format!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showBookingPaymentDetailsDialog(BookingPaymentLedgerItem item) {
    final media = MediaQuery.of(context);
    final isPhone = media.size.width < 420;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.secondaryBlue;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isPhone ? 12 : 24,
            vertical: isPhone ? 14 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Booking Payment Ledger'.tr(context),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isPhone ? 16 : 18,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: media.size.height * (isPhone ? 0.85 : 0.78),
              maxWidth: 580,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Booking Ref ID', item.booking.id),
                        _buildDetailRow('Customer Name', item.customerName),
                        _buildDetailRow('Vehicle', item.vehicleName),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FINANCIAL SUMMARY'.tr(context),
                        style: TextStyle(
                          fontSize: _rf(11, min: 10),
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: const BorderSide(color: AppColors.primaryOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showApplyDiscountDialog(item.booking);
                        },
                        icon: const Icon(Icons.discount_outlined, size: 14),
                        label: Text('Apply Discount'.tr(context), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          'Total Rental Amount'.tr(context),
                          'RM ${item.totalRentalAmount.toStringAsFixed(2)}',
                        ),
                        _buildDetailRow(
                          'Rental Paid (Approved)'.tr(context),
                          'RM ${item.rentalPaid.toStringAsFixed(2)}',
                        ),
                        _buildDetailRow(
                          'Rental Remaining'.tr(context),
                          'RM ${item.rentalRemaining.toStringAsFixed(2)}',
                        ),
                        const Divider(height: 12),
                        _buildDetailRow(
                          'Delivery Fee'.tr(context),
                          'RM ${item.deliveryFee.toStringAsFixed(2)}',
                        ),
                        _buildDetailRow(
                          'Delivery Paid (Approved)'.tr(context),
                          'RM ${item.deliveryPaid.toStringAsFixed(2)}',
                        ),
                        _buildDetailRow(
                          'Delivery Remaining'.tr(context),
                          'RM ${item.deliveryRemaining.toStringAsFixed(2)}',
                        ),
                        const Divider(height: 12),
                        _buildDetailRow(
                          'Discount Applied'.tr(context),
                          'RM ${item.discount.toStringAsFixed(2)}',
                        ),
                        const Divider(height: 16),
                        _buildDetailRow(
                          'Total Remaining Balance'.tr(context),
                          'RM ${item.remainingBalance.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${"PAYMENT HISTORY FOR THIS BOOKING".tr(context)} (${item.payments.length})',
                    style: TextStyle(
                      fontSize: _rf(11, min: 10),
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (item.payments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No individual payment transactions recorded yet for this booking.'.tr(context),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: item.payments.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final p = entry.value;
                        final isApproved = p.paymentStatus == 'Approved' || p.status == 'paid';
                        final isRejected = p.paymentStatus == 'Rejected' || p.status == 'failed';
                        final pColor = isApproved ? Colors.green : (isRejected ? Colors.redAccent : Colors.orange);
                        final purposeText = p.paymentPurpose == 'delivery' ? 'Delivery Fee' : 'Rental Payment';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${"Payment #".tr(context)}$idx',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (p.paymentPurpose == 'delivery' ? Colors.purple : Colors.blue).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          purposeText.tr(context),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: p.paymentPurpose == 'delivery' ? Colors.purple : Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: pColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      (p.paymentStatus ?? p.status).toUpperCase().tr(context),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: pColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _buildDetailRow('Purpose'.tr(context), purposeText.tr(context)),
                              _buildDetailRow('Amount'.tr(context), 'RM ${p.amount.toStringAsFixed(2)}'),
                              _buildDetailRow('Method'.tr(context), p.paymentMethod.tr(context)),
                              _buildDetailRow(
                                'Date & Time'.tr(context),
                                DateFormat('dd MMM yyyy hh:mm a').format(p.paymentDate),
                              ),
                              if (p.verifiedBy != null && p.verifiedBy!.isNotEmpty)
                                _buildDetailRow('Verified By'.tr(context), p.verifiedBy!),
                              if (p.receiptImage != null && p.receiptImage!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _openReceiptLightbox(p),
                                  icon: const Icon(Icons.receipt_long, size: 16),
                                  label: Text('View Uploaded Receipt File'.tr(context), style: const TextStyle(fontSize: 12)),
                                ),
                              ],
                              if (isApproved) ...[
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    minimumSize: const Size(double.infinity, 34),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _refundTransaction(p);
                                  },
                                  child: Text('Issue Refund'.tr(context), style: const TextStyle(fontSize: 12)),
                                ),
                              ],
                              if (p.paymentStatus == 'Pending Verification' ||
                                  p.status == 'pending') ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(0, 34),
                                        ),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          setState(() => _loading = true);
                                          await _paymentService.updatePaymentStatus(
                                            p.id,
                                            'Approved',
                                            p.userId,
                                          );
                                          _loadPayments();
                                        },
                                        child: const Text('Approve', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(color: Colors.redAccent),
                                          minimumSize: const Size(0, 34),
                                        ),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          setState(() => _loading = true);
                                          await _paymentService.updatePaymentStatus(
                                            p.id,
                                            'Rejected',
                                            p.userId,
                                          );
                                          _loadPayments();
                                        },
                                        child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'.tr(context)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isCompact = _isPhoneLayout();
    final labelSize = _rf(12, min: 10);
    final valueSize = _rf(12, min: 10);

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: labelSize, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              softWrap: true,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryBlue,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(fontSize: labelSize, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.bold,
                color: AppColors.secondaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: LoadingWidget(message: 'Syncing booking payments ledger...'.tr(context)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!.tr(context),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.secondaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPayments,
              child: Text('Retry'.tr(context)),
            ),
          ],
        ),
      );
    }

    final allLedgerItems = _buildLedgerItems();

    final filteredLedgerItems = allLedgerItems.where((item) {
      final matchesSearch =
          item.booking.id.toLowerCase().contains(_searchQuery) ||
          item.customerName.toLowerCase().contains(_searchQuery) ||
          item.vehicleName.toLowerCase().contains(_searchQuery) ||
          item.status.toLowerCase().contains(_searchQuery);
      return matchesSearch;
    }).toList();

    double totalRevenuePaid = 0.0;
    int settledCount = 0;
    int outstandingCount = 0;

    for (var item in allLedgerItems) {
      totalRevenuePaid += (item.rentalPaid + item.deliveryPaid);
      if (item.remainingBalance <= 0) {
        settledCount++;
      } else {
        outstandingCount++;
      }
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1100;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor = isDark
        ? const Color(0xFF111827)
        : const Color(0xFFF1F5F9);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.secondaryBlue;
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : Colors.grey;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking Payment Ledger'.tr(context),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Track booking payments, remaining balances, delivery fees, and issue refunds.'.tr(context),
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.secondaryBlue,
                            ),
                            foregroundColor: AppColors.secondaryBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _exportExcel,
                          icon: const Icon(Icons.table_view_outlined, size: 18),
                          label: Text(
                            'Export Excel'.tr(context),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _exportPdf,
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          label: Text(
                            'Export PDF'.tr(context),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking Payment Ledger'.tr(context),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Track booking payments, remaining balances, delivery fees, and issue refunds.'.tr(context),
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.secondaryBlue,
                              ),
                              foregroundColor: AppColors.secondaryBlue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _exportExcel,
                            icon: const Icon(
                              Icons.table_view_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Excel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _exportPdf,
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'PDF',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          const SizedBox(height: 24),

          GridView.count(
            crossAxisCount: isDesktop ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: isDesktop ? 2.2 : 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(
                'Total Revenue Paid',
                'RM ${totalRevenuePaid.toStringAsFixed(2)}',
                Icons.monetization_on,
                Colors.green,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Settled Bookings',
                settledCount.toString(),
                Icons.check_circle_outline,
                Colors.teal,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Outstanding Balances',
                outstandingCount.toString(),
                Icons.warning_amber_rounded,
                Colors.orange,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Total Bookings',
                allLedgerItems.length.toString(),
                Icons.collections_bookmark_outlined,
                Colors.indigo,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      hintText:
                          'Search booking ledger by customer, vehicle, or booking ref...'.tr(context),
                      hintStyle: TextStyle(color: textSecondary),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: textSecondary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          filteredLedgerItems.isEmpty
              ? Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payment_outlined,
                          size: 64,
                          color: textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No booking records found in payment ledger.'.tr(context),
                          style: TextStyle(color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: isDesktop
                      ? _buildDesktopLedgerTable(
                          filteredLedgerItems,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderColor: borderColor,
                          surfaceColor: surfaceColor,
                        )
                      : _buildMobileLedgerList(
                          filteredLedgerItems,
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
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.tr(context),
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLedgerTable(
    List<BookingPaymentLedgerItem> items, {
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    required Color surfaceColor,
  }) {
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Column(
      children: [
        // Responsive Header Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: headerBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 11,
                child: Text(
                  'Booking Ref'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  'Customer Name'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  'Vehicle'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 11,
                child: Text(
                  'Total Rental'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  'Rental Paid'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  'Delivery Paid'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 9,
                child: Text(
                  'Discount'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  'Remaining'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              Expanded(
                flex: 9,
                child: Text(
                  'Status'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  'Actions'.tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                ),
              ),
            ],
          ),
        ),

        // Responsive Item Rows (Zero Horizontal Scroll)
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (ctx, i) => Divider(height: 1, color: borderColor),
          itemBuilder: (ctx, i) {
            final item = items[i];
            final isSettled = item.remainingBalance <= 0;
            final statusColor = isSettled ? Colors.teal : Colors.orange;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // 1. Booking Ref
                  Expanded(
                    flex: 11,
                    child: Tooltip(
                      message: item.booking.id,
                      child: Text(
                        '#${item.booking.id.toUpperCase()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // 2. Customer Name
                  Expanded(
                    flex: 14,
                    child: Text(
                      item.customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: textPrimary,
                      ),
                      softWrap: true,
                    ),
                  ),
                  // 3. Vehicle
                  Expanded(
                    flex: 12,
                    child: Text(
                      item.vehicleName,
                      style: TextStyle(fontSize: 12, color: textPrimary),
                      softWrap: true,
                    ),
                  ),
                  // 4. Total Rental Amount
                  Expanded(
                    flex: 11,
                    child: Text(
                      'RM ${item.totalRentalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  // 5. Rental Paid
                  Expanded(
                    flex: 10,
                    child: Text(
                      'RM ${item.rentalPaid.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  // 6. Delivery Paid
                  Expanded(
                    flex: 10,
                    child: Text(
                      'RM ${item.deliveryPaid.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                  // 7. Discount
                  Expanded(
                    flex: 9,
                    child: Text(
                      'RM ${item.discount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  // 8. Remaining
                  Expanded(
                    flex: 10,
                    child: Text(
                      'RM ${item.remainingBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: item.remainingBalance > 0
                            ? Colors.orange
                            : Colors.green,
                      ),
                    ),
                  ),
                  // 9. Status
                  Expanded(
                    flex: 9,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  // 10. Actions
                  SizedBox(
                    width: 50,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.primaryOrange,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'View Payment Breakdown',
                        onPressed: () => _showBookingPaymentDetailsDialog(item),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileLedgerList(
    List<BookingPaymentLedgerItem> items, {
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSettled = item.remainingBalance <= 0;
        final statusColor = isSettled ? Colors.teal : Colors.orange;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor),
          ),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showBookingPaymentDetailsDialog(item),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '#${item.booking.id.toUpperCase()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Customer: ${item.customerName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Vehicle: ${item.vehicleName}',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rental Total'.tr(context),
                            style: TextStyle(fontSize: 10, color: textSecondary),
                          ),
                          Text(
                            'RM ${item.totalRentalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rental Paid'.tr(context),
                            style: TextStyle(fontSize: 10, color: textSecondary),
                          ),
                          Text(
                            'RM ${item.rentalPaid.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Paid'.tr(context),
                            style: TextStyle(fontSize: 10, color: textSecondary),
                          ),
                          Text(
                            'RM ${item.deliveryPaid.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Remaining'.tr(context),
                            style: TextStyle(fontSize: 10, color: textSecondary),
                          ),
                          Text(
                            'RM ${item.remainingBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: item.remainingBalance > 0
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
