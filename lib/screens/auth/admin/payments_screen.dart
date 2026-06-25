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
import '../../../services/payment_service.dart';
import '../../../services/booking_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../services/file_download_helper.dart' if (dart.library.html) '../../../services/file_download_web.dart' as download_helper;

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
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
      final usersSnap = await FirebaseDatabase.instance.ref().child('users').get().timeout(const Duration(seconds: 5));
      
      final results = await Future.wait([paymentsFuture, bookingsFuture]);
      _payments = results[0] as List<PaymentModel>;
      _bookings = results[1] as List<BookingModel>;
      
      _userNames.clear();
      if (usersSnap.exists) {
        final Map<dynamic, dynamic> usersData = usersSnap.value as Map<dynamic, dynamic>;
        usersData.forEach((key, value) {
          if (value is Map) {
            _userNames[key.toString()] = value['fullName'] ?? value['name'] ?? 'User';
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

  Future<void> _verifyPayment(PaymentModel payment, bool approve) async {
    final status = approve ? 'paid' : 'failed';
    final action = approve ? 'Approve' : 'Reject';

    String reason = '';
    if (!approve) {
      final reasonController = TextEditingController();
      final reasonSubmitted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rejection Reason Required'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: 'Enter the reason for rejection...',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason.')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      
      if (reasonSubmitted != true) return;
      reason = reasonController.text.trim();
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirm Payment $action'),
          content: Text('Are you sure you want to $action this payment of RM ${payment.amount.toStringAsFixed(2)}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: approve ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _loading = true);
    try {
      await _paymentService.updatePaymentStatus(payment.id, status, payment.userId, reason: reason);
      _loadPayments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _refundTransaction(PaymentModel payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Refund', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
        content: Text('Are you sure you want to issue a full refund of RM ${payment.amount.toStringAsFixed(2)} for this transaction?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Refund'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _paymentService.refundPayment(payment.id, payment.userId, payment.amount);
      _loadPayments();
    }
  }

  void _openReceiptLightbox(PaymentModel payment) {
    if (payment.receiptImage == null || payment.receiptImage!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No receipt file uploaded for this transaction.')),
      );
      return;
    }

    final isPdf = payment.receiptImage!.toLowerCase().contains('.pdf') ||
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
                title: Text(isPdf ? 'PDF Receipt document' : 'Receipt Image Lightbox', style: const TextStyle(color: Colors.white)),
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
                        download_helper.downloadFile(bytes, 'receipt_${payment.id}.$ext');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('File download initiated successfully.'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.redAccent),
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
                            const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 100),
                            const SizedBox(height: 16),
                            const Text('PDF Receipt Document Uploaded', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                try {
                                  final rawBase64 = payment.receiptImage!.split(',').last;
                                  final bytes = base64Decode(rawBase64);
                                  download_helper.downloadFile(bytes, 'receipt_${payment.id}.pdf');
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Download failed: $e')),
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
      TextCellValue('Date')
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
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(payment.paymentDate))
      ]);
    }

    final fileBytes = excelObj.save();
    if (fileBytes != null) {
      download_helper.downloadFile(Uint8List.fromList(fileBytes), 'CARRENT_Payments_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payments report downloaded in Excel format!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    
    List<List<String>> tableData = _payments.map((p) => [
      p.id.substring(0, p.id.length > 8 ? 8 : p.id.length),
      p.bookingId.substring(0, p.bookingId.length > 8 ? 8 : p.bookingId.length),
      'RM ${p.amount.toStringAsFixed(2)}',
      p.paymentMethod,
      p.status.toUpperCase(),
      DateFormat('yyyy-MM-dd').format(p.paymentDate)
    ]).toList();

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
                  pw.Text('CARRENT PAYMENTS LEDGER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: pdf_lib.PdfColor.fromInt(0xFF1A237E))),
                  pw.Text('Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Tx Ref', 'Booking Ref', 'Amount', 'Method', 'Status', 'Date'],
              data: tableData,
              border: pw.TableBorder.all(width: 0.5, color: pdf_lib.PdfColor.fromInt(0xFFE0E0E0)),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdf_lib.PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: pdf_lib.PdfColor.fromInt(0xFF1A237E)),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
          ];
        },
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    final fileBytes = await pdf.save();
    download_helper.downloadFile(fileBytes, 'CARRENT_Payments_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    messenger.showSnackBar(
      const SnackBar(content: Text('Payments report downloaded in PDF format!'), backgroundColor: Colors.green),
    );
  }

  void _showPaymentDetails(PaymentModel payment) {
    showDialog(
      context: context,
      builder: (context) {
        Color statusColor = Colors.orange;
        if (payment.paymentStatus == 'Approved' || payment.status == 'paid') statusColor = Colors.green;
        if (payment.paymentStatus == 'Rejected' || payment.status == 'failed') statusColor = Colors.redAccent;
        if (payment.status == 'refunded') statusColor = Colors.purple;

        final bookingMap = {for (var b in _bookings) b.id: b};
        final booking = bookingMap[payment.bookingId];
        final customerName = _userNames[payment.userId] ?? booking?.userName ?? 'Unknown';
        final vehicleName = booking?.vehicleName ?? 'Unknown';

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Transaction Receipt Spec', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Customer Name', customerName),
              _buildDetailRow('Vehicle Name', vehicleName),
              _buildDetailRow('Transaction ID', payment.id),
              _buildDetailRow('Booking Reference', payment.bookingId),
              _buildDetailRow('Amount Settled', 'RM ${payment.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Payment Mode', payment.paymentMethod),
              _buildDetailRow('Timestamp', DateFormat('dd MMM yyyy, hh:mm a').format(payment.paymentDate)),
              if (payment.transactionId != null && payment.transactionId!.isNotEmpty)
                _buildDetailRow('Ref Reference Key', payment.transactionId!),
              if (payment.rejectionReason != null && payment.rejectionReason!.isNotEmpty)
                _buildDetailRow('Rejection Reason', payment.rejectionReason!),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Receipt Status: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (payment.paymentStatus ?? payment.status).toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (payment.paymentStatus == 'Pending Verification' || payment.status == 'pending') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                      onPressed: () {
                        Navigator.pop(context);
                        _verifyPayment(payment, false);
                      },
                      child: const Text('Reject Paid'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        _verifyPayment(payment, true);
                      },
                      child: const Text('Approve Paid'),
                    ),
                  ],
                ),
              ] else if (payment.status == 'paid' || payment.paymentStatus == 'Approved') ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
                  onPressed: () {
                    Navigator.pop(context);
                    _refundTransaction(payment);
                  },
                  child: const Text('Issue Full Refund'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: LoadingWidget(message: 'Syncing ledger payments...'));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16, color: AppColors.secondaryBlue, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadPayments, child: const Text('Retry')),
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
      } else if (p.paymentStatus == 'Pending Verification' || p.status == 'pending') {
        pendingCount++;
      } else if (p.paymentStatus == 'Rejected' || p.status == 'failed' || p.status == 'refunded') {
        failedCount++;
      }
    }

    final bookingMap = {for (var b in _bookings) b.id: b};

    final filteredPayments = _payments.where((p) {
      final booking = bookingMap[p.bookingId];
      final customerName = _userNames[p.userId] ?? booking?.userName ?? 'Unknown';
      final vehicleName = booking?.vehicleName ?? 'Unknown';

      final matchesSearch = p.id.toLowerCase().contains(_searchQuery) ||
          p.bookingId.toLowerCase().contains(_searchQuery) ||
          customerName.toLowerCase().contains(_searchQuery) ||
          vehicleName.toLowerCase().contains(_searchQuery) ||
          (p.transactionId ?? '').toLowerCase().contains(_searchQuery);
      return matchesSearch;
    }).toList();

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 1100;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payments Ledger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue)),
                  Text('Verify customer deposits, issue refunds, and audit revenue streams.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.secondaryBlue),
                      foregroundColor: AppColors.secondaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _exportExcel,
                    icon: const Icon(Icons.table_view_outlined, size: 18),
                    label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold)),
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
              _buildStatCard('Total Revenue', 'RM ${totalRevenue.toStringAsFixed(2)}', Icons.monetization_on, Colors.green),
              _buildStatCard('Pending Verification', pendingCount.toString(), Icons.hourglass_top, Colors.orange),
              _buildStatCard('Cleared Payments', successCount.toString(), Icons.check_circle, Colors.teal),
              _buildStatCard('Failed / Refunded', failedCount.toString(), Icons.cancel_outlined, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 24),

          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search ledger by customer, vehicle, payment ID, booking ID, or reference...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: filteredPayments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No transactions found matching reference.', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: isDesktop ? _buildDesktopTable(filteredPayments, bookingMap) : _buildMobileList(filteredPayments, bookingMap),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondaryBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<PaymentModel> payments, Map<String, BookingModel> bookingMap) {
    return ListView(
      children: [
        DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Amount (RM)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Payment Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Receipt Preview', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
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
            final customerName = _userNames[p.userId] ?? booking?.userName ?? 'Unknown';
            final vehicleName = booking?.vehicleName ?? 'Unknown';

            return DataRow(
              cells: [
                DataCell(Text(customerName, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(vehicleName)),
                DataCell(Text('RM ${p.amount.toStringAsFixed(2)}')),
                DataCell(Text(dateFormat.format(p.paymentDate))),
                DataCell(
                  Center(
                    child: GestureDetector(
                      onTap: () => _openReceiptLightbox(p),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.grey[50],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: p.receiptImage == null
                              ? const Icon(Icons.no_photography_outlined, size: 18, color: Colors.grey)
                              : (p.receiptImage!.toLowerCase().contains('.pdf') || p.receiptImage!.startsWith('data:application/pdf')
                                  ? const Icon(Icons.picture_as_pdf, size: 20, color: Colors.redAccent)
                                  : Image.memory(
                                      base64Decode(p.receiptImage!.split(',').last),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.receipt_long, size: 20),
                                    )),
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.receipt_long_outlined, color: AppColors.secondaryBlue, size: 18),
                        tooltip: 'Details',
                        onPressed: () => _showPaymentDetails(p),
                      ),
                      if (p.paymentStatus == 'Pending Verification' || p.status == 'pending') ...[
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                          tooltip: 'Approve',
                          onPressed: () => _verifyPayment(p, true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                          tooltip: 'Reject',
                          onPressed: () => _verifyPayment(p, false),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMobileList(List<PaymentModel> payments, Map<String, BookingModel> bookingMap) {
    return ListView.builder(
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
        final customerName = _userNames[p.userId] ?? booking?.userName ?? 'Unknown';
        final vehicleName = booking?.vehicleName ?? 'Unknown';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
          elevation: 0,
          child: ListTile(
            leading: GestureDetector(
              onTap: () => _openReceiptLightbox(p),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[350]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: p.receiptImage == null
                      ? const Icon(Icons.no_photography_outlined, size: 18, color: Colors.grey)
                      : (p.receiptImage!.toLowerCase().contains('.pdf') || p.receiptImage!.startsWith('data:application/pdf')
                          ? const Icon(Icons.picture_as_pdf, size: 24, color: Colors.redAccent)
                          : Image.memory(
                              base64Decode(p.receiptImage!.split(',').last),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.receipt_long, size: 20),
                            )),
                ),
              ),
            ),
            title: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vehicle: $vehicleName', style: const TextStyle(fontSize: 12)),
                Text('Amount: RM ${p.amount.toStringAsFixed(2)} | Mode: ${p.paymentMethod}', style: const TextStyle(fontSize: 12)),
                Text('Date: ${dateFormat.format(p.paymentDate)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (p.paymentStatus == 'Pending Verification' || p.status == 'pending') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(60, 26), padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: () => _verifyPayment(p, true),
                        icon: const Icon(Icons.check, size: 12),
                        label: const Text('Approve', style: TextStyle(fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), minimumSize: const Size(60, 26), padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: () => _verifyPayment(p, false),
                        icon: const Icon(Icons.close, size: 12),
                        label: const Text('Reject', style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                ],
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
                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
            onTap: () => _showPaymentDetails(p),
          ),
        );
      },
    );
  }
}
