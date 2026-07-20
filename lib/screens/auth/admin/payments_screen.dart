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

  Future<void> _loadPayments() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final paymentsFuture = _paymentService.getPayments();
      final bookingsFuture = _bookingService.getBookings();
      final usersSnap = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .get()
          .timeout(const Duration(seconds: 5));

      final results = await Future.wait([paymentsFuture, bookingsFuture]);
      _payments = results[0] as List<PaymentModel>;
      _bookings = results[1] as List<BookingModel>;

      _userNames.clear();
      _usersMap.clear();
      if (usersSnap.exists) {
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

      _payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    } catch (e) {
      debugPrint('Error loading payments: $e');
      setState(() {
        _error = 'Failed to load transaction records. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
      TextCellValue('Transaction ID'),
      TextCellValue('Booking ID'),
      TextCellValue('User ID'),
      TextCellValue('Amount (RM)'),
      TextCellValue('Deposit (RM)'),
      TextCellValue('Method'),
      TextCellValue('Status'),
      TextCellValue('Date'),
    ]);

    for (var payment in _payments) {
      sheet.appendRow([
        TextCellValue(payment.id),
        TextCellValue(payment.bookingId),
        TextCellValue(payment.userId),
        DoubleCellValue(payment.amount),
        DoubleCellValue(payment.depositAmount),
        TextCellValue(payment.paymentMethod),
        TextCellValue(payment.status),
        TextCellValue(
          DateFormat('yyyy-MM-dd HH:mm').format(payment.paymentDate),
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
        '${companyName}_Payments_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payments report downloaded in Excel format!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    List<List<String>> tableData = _payments
        .map(
          (p) => [
            p.id.substring(0, p.id.length > 8 ? 8 : p.id.length),
            p.bookingId.substring(
              0,
              p.bookingId.length > 8 ? 8 : p.bookingId.length,
            ),
            'RM ${p.amount.toStringAsFixed(2)}',
            p.paymentMethod,
            p.status.toUpperCase(),
            DateFormat('yyyy-MM-dd').format(p.paymentDate),
          ],
        )
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pdf_lib.PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${CompanySettingsProvider().companyName.toUpperCase()} PAYMENTS LEDGER',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 20,
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
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Tx Ref',
                'Booking Ref',
                'Amount',
                'Method',
                'Status',
                'Date',
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
      '${companyName}_Payments_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Payments report downloaded in PDF format!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showPaymentDetails(PaymentModel payment) {
    showDialog(
      context: context,
      builder: (context) {
        Color statusColor = Colors.orange;
        if (payment.paymentStatus == 'Approved' || payment.status == 'paid') {
          statusColor = Colors.green;
        }
        if (payment.paymentStatus == 'Rejected' || payment.status == 'failed') {
          statusColor = Colors.redAccent;
        }
        if (payment.status == 'refunded') {
          statusColor = Colors.purple;
        }

        final bookingMap = {for (var b in _bookings) b.id: b};
        final booking = bookingMap[payment.bookingId];
        final user = _usersMap[payment.userId];
        final vehicleName = booking?.vehicleName ?? 'Unknown';
        final media = MediaQuery.of(context);
        final isPhone = media.size.width < 420;
        final maxDialogHeight = media.size.height * (isPhone ? 0.82 : 0.78);

        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isPhone ? 12 : 16,
            vertical: isPhone ? 14 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Transaction Receipt Spec',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: _rf(20, min: 16),
              color: AppColors.secondaryBlue,
            ),
          ),
          titlePadding: EdgeInsets.fromLTRB(
            isPhone ? 16 : 24,
            isPhone ? 16 : 20,
            isPhone ? 16 : 24,
            8,
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxDialogHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CUSTOMER INFORMATION',
                    style: TextStyle(
                      fontSize: _rf(12, min: 10),
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: isPhone ? 4 : 6),
                  _buildDetailRow(
                    'Full Name',
                    user?.fullName ?? booking?.userName ?? 'Unknown',
                  ),
                  _buildDetailRow('Email', user?.email ?? 'N/A'),
                  _buildDetailRow(
                    'Phone',
                    user?.phone ?? booking?.userPhone ?? 'N/A',
                  ),
                  const Divider(height: 18),
                  Text(
                    'BOOKING INFORMATION',
                    style: TextStyle(
                      fontSize: _rf(12, min: 10),
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: isPhone ? 4 : 6),
                  _buildDetailRow('Vehicle Name', vehicleName),
                  _buildDetailRow('Booking Reference', payment.bookingId),
                  if (booking != null) ...[
                    _buildDetailRow(
                      'Pick-up Date',
                      DateFormat('dd MMM yyyy').format(booking.pickUpDate),
                    ),
                    _buildDetailRow(
                      'Return Date',
                      booking.isOpenRental
                          ? 'Open Rental'
                          : (booking.returnDate != null
                                ? DateFormat(
                                    'dd MMM yyyy',
                                  ).format(booking.returnDate!)
                                : ""),
                    ),
                    _buildDetailRow(
                      'Booking Total',
                      'RM ${booking.totalPrice.toStringAsFixed(2)}',
                    ),
                  ],
                  const Divider(height: 18),
                  Text(
                    'PAYMENT DETAILS',
                    style: TextStyle(
                      fontSize: _rf(12, min: 10),
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: isPhone ? 4 : 6),
                  _buildDetailRow('Transaction ID', payment.id),
                  _buildDetailRow(
                    'Amount Settled',
                    'RM ${payment.amount.toStringAsFixed(2)}',
                  ),
                  _buildDetailRow('Payment Mode', payment.paymentMethod),
                  _buildDetailRow(
                    'Payment Date',
                    DateFormat('dd MMM yyyy').format(payment.paymentDate),
                  ),
                  if (payment.paymentTime != null &&
                      payment.paymentTime!.isNotEmpty)
                    _buildDetailRow('Payment Time', payment.paymentTime!),
                  if (payment.transactionId != null &&
                      payment.transactionId!.isNotEmpty)
                    _buildDetailRow('Reference ID', payment.transactionId!),
                  if (payment.rejectionReason != null &&
                      payment.rejectionReason!.isNotEmpty)
                    _buildDetailRow(
                      'Rejection Reason',
                      payment.rejectionReason!,
                    ),
                  SizedBox(height: isPhone ? 10 : 12),
                  Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        'Receipt Status: ',
                        style: TextStyle(
                          fontSize: _rf(12, min: 10),
                          color: Colors.grey,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (payment.paymentStatus ?? payment.status)
                              .toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: _rf(10, min: 9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (payment.status == 'paid' ||
                      payment.paymentStatus == 'Approved') ...[
                    const Divider(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, isPhone ? 40 : 44),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _refundTransaction(payment);
                      },
                      child: Text(
                        'Issue Full Refund',
                        style: TextStyle(
                          fontSize: _rf(13, min: 11),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (payment.paymentStatus == 'Pending Verification' ||
                      payment.status == 'Pending Verification' ||
                      payment.paymentStatus == 'pending' ||
                      payment.status == 'pending') ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 44),
                            ),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(context);
                              setState(() => _loading = true);
                              try {
                                await _paymentService.updatePaymentStatus(
                                  payment.id,
                                  'Approved',
                                  payment.userId,
                                );
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Payment approved successfully.',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to approve payment: $e',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _loading = false);
                                }
                              }
                            },
                            child: const Text(
                              'Approve',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 44),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _promptRejectionReason(payment);
                            },
                            child: const Text(
                              'Reject',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          contentPadding: EdgeInsets.fromLTRB(
            isPhone ? 16 : 24,
            8,
            isPhone ? 16 : 24,
            6,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(fontSize: _rf(13, min: 11)),
              ),
            ),
          ],
          actionsPadding: EdgeInsets.fromLTRB(
            isPhone ? 8 : 12,
            0,
            isPhone ? 8 : 12,
            isPhone ? 10 : 14,
          ),
        );
      },
    );
  }

  Future<void> _promptRejectionReason(PaymentModel payment) async {
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.secondaryBlue;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reject Payment',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        content: TextField(
          controller: reasonController,
          style: TextStyle(color: textColor),
          decoration: const InputDecoration(
            labelText: 'Reason for Rejection',
            hintText: 'e.g. Receipt image blurry or incorrect reference ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await _paymentService.updatePaymentStatus(
          payment.id,
          'Rejected',
          payment.userId,
          reason: reasonController.text.trim(),
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Payment rejected successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to reject payment: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }
  Widget _buildDetailRow(String label, String value) {
    final isCompact = _isPhoneLayout();
    final labelSize = _rf(12, min: 10);
    final valueSize = _rf(12, min: 10);

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(fontSize: labelSize, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
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
      return const Center(
        child: LoadingWidget(message: 'Syncing ledger payments...'),
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
              _error!,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.secondaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPayments,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    double totalRevenue = 0.0;
    int pendingCount = 0;
    int successCount = 0;
    int failedCount = 0;

    for (var p in _payments) {
      if (p.paymentStatus == 'Approved' || p.status == 'paid') {
        totalRevenue += p.amount;
        successCount++;
      } else if (p.paymentStatus == 'Pending Verification' ||
          p.status == 'pending') {
        pendingCount++;
      } else if (p.paymentStatus == 'Rejected' ||
          p.status == 'failed' ||
          p.status == 'refunded') {
        failedCount++;
      }
    }

    final bookingMap = {for (var b in _bookings) b.id: b};

    final filteredPayments = _payments.where((p) {
      final booking = bookingMap[p.bookingId];
      final customerName =
          _userNames[p.userId] ?? booking?.userName ?? 'Unknown';
      final vehicleName = booking?.vehicleName ?? 'Unknown';

      final matchesSearch =
          p.id.toLowerCase().contains(_searchQuery) ||
          p.bookingId.toLowerCase().contains(_searchQuery) ||
          customerName.toLowerCase().contains(_searchQuery) ||
          vehicleName.toLowerCase().contains(_searchQuery) ||
          (p.transactionId ?? '').toLowerCase().contains(_searchQuery);
      return matchesSearch;
    }).toList();

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
                          'Payments Ledger',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Verify customer deposits, issue refunds, and audit revenue streams.',
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
                          label: const Text(
                            'Export Excel',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                          label: const Text(
                            'Export PDF',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                      'Payments Ledger',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Verify customer deposits, issue refunds, and audit revenue streams.',
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
                'Total Revenue',
                'RM ${totalRevenue.toStringAsFixed(2)}',
                Icons.monetization_on,
                Colors.green,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Pending Verification',
                pendingCount.toString(),
                Icons.hourglass_top,
                Colors.orange,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Cleared Payments',
                successCount.toString(),
                Icons.check_circle,
                Colors.teal,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              _buildStatCard(
                'Failed / Refunded',
                failedCount.toString(),
                Icons.cancel_outlined,
                Colors.redAccent,
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
                          'Search ledger by customer, vehicle, payment ID, or reference...',
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

          filteredPayments.isEmpty
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
                          'No transactions found matching reference.',
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
                      ? _buildDesktopTable(
                          filteredPayments,
                          bookingMap,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          borderColor: borderColor,
                          surfaceColor: surfaceColor,
                        )
                      : _buildMobileList(
                          filteredPayments,
                          bookingMap,
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
                  label,
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

  Widget _buildDesktopTable(
    List<PaymentModel> payments,
    Map<String, BookingModel> bookingMap, {
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    required Color surfaceColor,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        ),
        dividerThickness: 1,
        columns: [
          DataColumn(
            label: Text(
              'Customer Name',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Vehicle',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Amount (RM)',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Payment Date',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Receipt Preview',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Status',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          DataColumn(
            label: Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
        ],
        rows: payments.map((p) {
          Color statusColor = Colors.orange;
          String statusText = 'Pending Verification';
          if (p.paymentStatus == 'Approved' || p.status == 'paid') {
            statusColor = Colors.green;
            statusText = 'Approved';
          } else if (p.paymentStatus == 'Rejected' || p.status == 'failed') {
            statusColor = Colors.redAccent;
            statusText = 'Rejected';
          } else if (p.status == 'refunded') {
            statusColor = Colors.purple;
            statusText = 'Refunded';
          }

          final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
          final booking = bookingMap[p.bookingId];
          final customerName =
              _userNames[p.userId] ?? booking?.userName ?? 'Unknown';
          final vehicleName = booking?.vehicleName ?? 'Unknown';

          return DataRow(
            cells: [
              DataCell(
                Text(
                  customerName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              DataCell(Text(vehicleName, style: TextStyle(color: textPrimary))),
              DataCell(
                Text(
                  'RM ${p.amount.toStringAsFixed(2)}',
                  style: TextStyle(color: textPrimary),
                ),
              ),
              DataCell(
                Text(
                  dateFormat.format(p.paymentDate),
                  style: TextStyle(color: textSecondary),
                ),
              ),
              DataCell(
                Center(
                  child: GestureDetector(
                    onTap: () => _openReceiptLightbox(p),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(6),
                        color: surfaceColor,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: p.receiptImage == null
                            ? const Icon(
                                Icons.no_photography_outlined,
                                size: 18,
                                color: Colors.grey,
                              )
                            : (p.receiptImage!.toLowerCase().contains('.pdf') ||
                                      p.receiptImage!.startsWith(
                                        'data:application/pdf',
                                      )
                                  ? const Icon(
                                      Icons.picture_as_pdf,
                                      size: 20,
                                      color: Colors.redAccent,
                                    )
                                  : Image.memory(
                                      base64Decode(
                                        p.receiptImage!.split(',').last,
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.receipt_long,
                                                size: 20,
                                              ),
                                    )),
                      ),
                    ),
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.secondaryBlue,
                        size: 18,
                      ),
                      tooltip: 'Details',
                      onPressed: () => _showPaymentDetails(p),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileList(
    List<PaymentModel> payments,
    Map<String, BookingModel> bookingMap, {
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final p = payments[index];
        Color statusColor = Colors.orange;
        String statusText = 'Pending Verification';
        if (p.paymentStatus == 'Approved' || p.status == 'paid') {
          statusColor = Colors.green;
          statusText = 'Approved';
        } else if (p.paymentStatus == 'Rejected' || p.status == 'failed') {
          statusColor = Colors.redAccent;
          statusText = 'Rejected';
        } else if (p.status == 'refunded') {
          statusColor = Colors.purple;
          statusText = 'Refunded';
        }

        final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
        final booking = bookingMap[p.bookingId];
        final customerName =
            _userNames[p.userId] ?? booking?.userName ?? 'Unknown';
        final vehicleName = booking?.vehicleName ?? 'Unknown';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
          elevation: 0,
          child: ListTile(
            leading: GestureDetector(
              onTap: () => _openReceiptLightbox(p),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: p.receiptImage == null
                      ? const Icon(
                          Icons.no_photography_outlined,
                          size: 18,
                          color: Colors.grey,
                        )
                      : (p.receiptImage!.toLowerCase().contains('.pdf') ||
                                p.receiptImage!.startsWith(
                                  'data:application/pdf',
                                )
                            ? const Icon(
                                Icons.picture_as_pdf,
                                size: 24,
                                color: Colors.redAccent,
                              )
                            : Image.memory(
                                base64Decode(p.receiptImage!.split(',').last),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.receipt_long, size: 20),
                              )),
                ),
              ),
            ),
            title: Text(
              customerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle: $vehicleName',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Amount: RM ${p.amount.toStringAsFixed(2)} | Mode: ${p.paymentMethod}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Date: ${dateFormat.format(p.paymentDate)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () => _showPaymentDetails(p),
          ),
        );
      },
    );
  }
}
