import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

import '../../../constants/colors.dart';
import '../../../models/user_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/maintenance_job_model.dart';
import '../../../services/file_download_helper.dart' if (dart.library.html) '../../../services/file_download_web.dart' as download_helper;

class ReportsView extends StatelessWidget {
  final List<BookingModel> bookings;
  final List<PaymentModel> payments;
  final List<VehicleModel> vehicles;
  final List<UserModel> users;
  final List<MaintenanceJobModel> maintenanceJobs;

  const ReportsView({
    super.key,
    required this.bookings,
    required this.payments,
    required this.vehicles,
    required this.users,
    required this.maintenanceJobs,
  });

  void _exportExcel(BuildContext context, String type) {
    var excelObj = Excel.createExcel();
    var sheet = excelObj[excelObj.getDefaultSheet() ?? 'Sheet1'];
    
    if (type == 'Bookings') {
      sheet.appendRow([
        TextCellValue('Booking ID'),
        TextCellValue('Vehicle'),
        TextCellValue('Customer'),
        TextCellValue('Phone'),
        TextCellValue('Pick Up Date'),
        TextCellValue('Return Date'),
        TextCellValue('Total Price (RM)'),
        TextCellValue('Status'),
        TextCellValue('Created At')
      ]);
      for (var booking in bookings) {
        sheet.appendRow([
          TextCellValue(booking.id),
          TextCellValue(booking.vehicleName),
          TextCellValue(booking.userName),
          TextCellValue(booking.userPhone),
          TextCellValue(booking.pickUpDate.toIso8601String()),
          TextCellValue(booking.returnDate.toIso8601String()),
          DoubleCellValue(booking.totalPrice),
          TextCellValue(booking.status),
          TextCellValue(booking.createdAt.toIso8601String()),
        ]);
      }
    } else if (type == 'Payments' || type == 'Revenue') {
      sheet.appendRow([
        TextCellValue('Payment ID'),
        TextCellValue('Customer Name'),
        TextCellValue('Booking ID'),
        TextCellValue('Amount (RM)'),
        TextCellValue('Method'),
        TextCellValue('Status'),
        TextCellValue('Transaction ID'),
        TextCellValue('Date')
      ]);
      double sum = 0.0;
      for (var payment in payments) {
        String customerName = 'Unknown';
        try {
          final matchedUser = users.firstWhere((u) => u.id == payment.userId);
          customerName = matchedUser.fullName;
        } catch (_) {}
        sheet.appendRow([
          TextCellValue(payment.id),
          TextCellValue(customerName),
          TextCellValue(payment.bookingId),
          DoubleCellValue(payment.amount),
          TextCellValue(payment.paymentMethod),
          TextCellValue(payment.status),
          TextCellValue(payment.transactionId ?? 'N/A'),
          TextCellValue(payment.paymentDate.toIso8601String()),
        ]);
        final status = payment.status.toLowerCase();
        if (status == 'paid' || status == 'approved') {
          sum += payment.amount;
        }
      }
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('Total Successful Revenue (RM):'),
        DoubleCellValue(sum)
      ]);
    } else if (type == 'Customers') {
      sheet.appendRow([
        TextCellValue('Customer ID'),
        TextCellValue('Full Name'),
        TextCellValue('Email'),
        TextCellValue('Phone'),
        TextCellValue('Address'),
        TextCellValue('Verified'),
        TextCellValue('Active')
      ]);
      for (var user in users) {
        if (user.role == 'customer') {
          sheet.appendRow([
            TextCellValue(user.id),
            TextCellValue(user.fullName),
            TextCellValue(user.email),
            TextCellValue(user.phone),
            TextCellValue(user.address),
            TextCellValue(user.isVerified ? 'Yes' : 'No'),
            TextCellValue(user.isActive ? 'Yes' : 'No'),
          ]);
        }
      }
    } else if (type == 'Vehicles') {
      sheet.appendRow([
        TextCellValue('Vehicle ID'),
        TextCellValue('Brand'),
        TextCellValue('Model'),
        TextCellValue('Category'),
        TextCellValue('Plate Number'),
        TextCellValue('Color'),
        TextCellValue('Transmission'),
        TextCellValue('Fuel Type'),
        TextCellValue('Price/Day (RM)'),
        TextCellValue('Availability'),
      ]);
      for (var vehicle in vehicles) {
        sheet.appendRow([
          TextCellValue(vehicle.id),
          TextCellValue(vehicle.brand),
          TextCellValue(vehicle.model),
          TextCellValue(vehicle.category),
          TextCellValue(vehicle.plateNumber),
          TextCellValue(vehicle.color),
          TextCellValue(vehicle.transmission),
          TextCellValue(vehicle.fuelType),
          DoubleCellValue(vehicle.pricePerDay),
          TextCellValue(vehicle.status),
        ]);
      }
    } else if (type == 'Maintenance') {
      sheet.appendRow([
        TextCellValue('Job ID'),
        TextCellValue('Vehicle Unit'),
        TextCellValue('Title'),
        TextCellValue('Cost (RM)'),
        TextCellValue('Start Date'),
        TextCellValue('End Date'),
        TextCellValue('Description'),
        TextCellValue('Status')
      ]);
      double sumCost = 0.0;
      for (var job in maintenanceJobs) {
        sheet.appendRow([
          TextCellValue(job.id),
          TextCellValue(job.vehicleName),
          TextCellValue(job.title),
          DoubleCellValue(job.cost),
          TextCellValue(job.startDate),
          TextCellValue(job.endDate),
          TextCellValue(job.description),
          TextCellValue(job.status),
        ]);
        sumCost += job.cost;
      }
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('Total Maintenance Cost (RM):'),
        DoubleCellValue(sumCost)
      ]);
    }

    final fileBytes = excelObj.save();
    if (fileBytes != null) {
      download_helper.downloadFile(Uint8List.fromList(fileBytes), 'CARRENT_${type}_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type report downloaded in Excel format!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _exportPdf(BuildContext context, String type) async {
    final pdf = pw.Document();
    
    List<List<String>> tableData = [];
    List<String> headers = [];

    if (type == 'Bookings') {
      headers = ['Vehicle', 'Customer', 'Period', 'Price', 'Status'];
      tableData = bookings.map((b) => [
        b.vehicleName,
        b.userName,
        '${DateFormat('dd/MM').format(b.pickUpDate)} - ${DateFormat('dd/MM').format(b.returnDate)}',
        'RM ${b.totalPrice.toStringAsFixed(0)}',
        b.status.toUpperCase()
      ]).toList();
    } else if (type == 'Payments' || type == 'Revenue') {
      headers = ['Date', 'Customer', 'Booking Ref', 'Amount', 'Status'];
      double sum = 0.0;
      tableData = payments.map((p) {
        String customerName = 'Unknown';
        try {
          final matchedUser = users.firstWhere((u) => u.id == p.userId);
          customerName = matchedUser.fullName;
        } catch (_) {}
        if (p.status == 'paid' || p.status == 'approved') {
          sum += p.amount;
        }
        return [
          DateFormat('dd/MM/yyyy').format(p.paymentDate),
          customerName,
          p.bookingId.substring(0, p.bookingId.length > 8 ? 8 : p.bookingId.length),
          'RM ${p.amount.toStringAsFixed(2)}',
          p.status.toUpperCase()
        ];
      }).toList();
      tableData.add(['', 'TOTAL REVENUE:', '', 'RM ${sum.toStringAsFixed(2)}', '']);
    } else if (type == 'Customers') {
      headers = ['Name', 'Email', 'Phone', 'Verified', 'Active'];
      tableData = users.where((u) => u.role == 'customer').map((u) => [
        u.fullName,
        u.email,
        u.phone,
        u.isVerified ? 'YES' : 'NO',
        u.isActive ? 'YES' : 'NO'
      ]).toList();
    } else if (type == 'Vehicles') {
      headers = ['Vehicle Unit', 'Category', 'Plate', 'Daily Rate', 'Status'];
      tableData = vehicles.map((v) => [
        '${v.brand} ${v.model}',
        v.category,
        v.plateNumber,
        'RM ${v.pricePerDay.toStringAsFixed(0)}',
        v.status.toUpperCase()
      ]).toList();
    } else if (type == 'Maintenance') {
      headers = ['Vehicle Unit', 'Title', 'Start Date', 'End Date', 'Cost', 'Status'];
      double sumCost = 0.0;
      tableData = maintenanceJobs.map((j) {
        sumCost += j.cost;
        return [
          j.vehicleName,
          j.title,
          j.startDate,
          j.endDate,
          'RM ${j.cost.toStringAsFixed(2)}',
          j.status.toUpperCase()
        ];
      }).toList();
      tableData.add(['', 'TOTAL COST:', '', '', 'RM ${sumCost.toStringAsFixed(2)}', '']);
    }

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
                  pw.Text('CARRENT PLATFORM REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22, color: pdf_lib.PdfColor.fromInt(0xFF1A237E))),
                  pw.Text('Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10, color: pdf_lib.PdfColor.fromInt(0xFF757575))),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('$type Analytics Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: pdf_lib.PdfColor.fromInt(0xFF757575))),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: tableData,
              border: pw.TableBorder.all(width: 0.5, color: pdf_lib.PdfColor.fromInt(0xFFE0E0E0)),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdf_lib.PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: pdf_lib.PdfColor.fromInt(0xFF1A237E)),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Page 1 of 1 | Confidential Business Record', style: pw.TextStyle(fontSize: 8, color: pdf_lib.PdfColor.fromInt(0xFF9E9E9E))),
            ),
          ];
        },
      ),
    );

    final fileBytes = await pdf.save();
    download_helper.downloadFile(fileBytes, 'CARRENT_${type}_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type report downloaded in PDF format!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operations Reports Center',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
          ),
          const Text(
            'Download and export operational ledgers of the CARRENT system in Excel and PDF format.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Cards Row
          GridView.count(
            crossAxisCount: isDesktop ? 5 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDesktop ? 1.5 : 1.3,
            children: [
              _buildMetricCard('Total Vehicles', '${vehicles.length}', Icons.directions_car, Colors.blue),
              _buildMetricCard('Total Bookings', '${bookings.length}', Icons.book_online, Colors.purple),
              _buildMetricCard('Registered Customers', '${users.where((u) => u.role == 'customer').length}', Icons.people, Colors.teal),
              _buildMetricCard('Completed Jobs', '${maintenanceJobs.where((j) => j.status == 'Completed').length}', Icons.build_circle_outlined, Colors.redAccent),
              _buildMetricCard('Approved Payments', '${payments.where((p) => p.status == 'paid' || p.status == 'approved').length}', Icons.monetization_on, Colors.green),
            ],
          ),
          const SizedBox(height: 32),

          const Text(
            'Available Report Modules',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue),
          ),
          const SizedBox(height: 16),

          // Modules Grid
          GridView.count(
            crossAxisCount: isDesktop ? 2 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: isDesktop ? 2.4 : 2.0,
            children: [
              _buildReportModule(
                context,
                'Revenue & Earnings Ledger',
                'Aggregated record of all verified payment history, billing methods, and transactional reports.',
                'Revenue',
                '${payments.length} Records',
                Colors.green,
              ),
              _buildReportModule(
                context,
                'Bookings & Rental Contracts',
                'Comprehensive list of all rentals, user contacts, vehicle information, and approval statuses.',
                'Bookings',
                '${bookings.length} Records',
                Colors.purple,
              ),
              _buildReportModule(
                context,
                'Fleet Directory Index',
                'List of all vehicle properties, plate numbers, categories, daily rates, and availability statuses.',
                'Vehicles',
                '${vehicles.length} Records',
                Colors.blue,
              ),
              _buildReportModule(
                context,
                'Customer Verification Ledger',
                'Summary index of all registered customer profiles, emails, phone numbers, and driving license verification states.',
                'Customers',
                '${users.where((u) => u.role == 'customer').length} Records',
                Colors.teal,
              ),
              _buildReportModule(
                context,
                'Vehicle Maintenance Logs',
                'Work orders, schedules, mechanical repair listings, statuses, and accumulated costs.',
                'Maintenance',
                '${maintenanceJobs.length} Records',
                Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.secondaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildReportModule(
    BuildContext context,
    String name,
    String description,
    String type,
    String count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.secondaryBlue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  count,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => _exportExcel(context, type),
                  icon: const Icon(Icons.table_view, size: 14),
                  label: const Text('Excel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => _exportPdf(context, type),
                  icon: const Icon(Icons.picture_as_pdf, size: 14),
                  label: const Text('PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
