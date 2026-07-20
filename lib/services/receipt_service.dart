import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, showDialog, Navigator, Center, CircularProgressIndicator, ScaffoldMessenger, SnackBar, Text, Colors;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import './file_download_helper.dart' if (dart.library.html) './file_download_web.dart' as download_helper;
import '../models/booking_model.dart';
import 'company_settings_provider.dart';

class ReceiptService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Triggered automatically when a booking is completed or payment is approved.
  /// If booking status = Completed and payment is Paid (Approved), generates and stores
  /// receipt metadata in Firebase database.
  Future<void> triggerAutomaticReceiptCheck(String bookingId) async {
    try {
      debugPrint('[ReceiptService] Running automatic receipt check for: $bookingId');
      
      // 1. Fetch booking
      final bookingSnap = await _db.child('bookings').child(bookingId).get().timeout(const Duration(seconds: 4));
      if (!bookingSnap.exists || bookingSnap.value == null) {
        debugPrint('[ReceiptService] Booking $bookingId not found.');
        return;
      }
      final booking = BookingModel.fromMap(bookingId, bookingSnap.value as Map<dynamic, dynamic>);

      // Check booking status
      if (booking.status.toLowerCase() != 'completed') {
        debugPrint('[ReceiptService] Booking status is ${booking.status}, not Completed. Skipping receipt generation.');
        return;
      }

      // 2. Fetch payments (Query by userId to comply with Firebase security rules)
      Map? approvedPayment;
      try {
        final paymentsSnap = await _db.child('payments').orderByChild('userId').equalTo(booking.userId).get().timeout(const Duration(seconds: 4));
        if (paymentsSnap.exists && paymentsSnap.value != null) {
          final paymentsMap = paymentsSnap.value as Map;
          for (var pValue in paymentsMap.values) {
            if (pValue is Map && pValue['bookingId'] == bookingId) {
              final pStatus = (pValue['paymentStatus'] ?? pValue['status'] ?? '').toString().toLowerCase();
              if (pStatus == 'approved' || pStatus == 'paid') {
                approvedPayment = pValue;
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ReceiptService] Error fetching payments in check: $e');
      }

      if (approvedPayment == null) {
        debugPrint('[ReceiptService] No approved/paid payment found for booking $bookingId.');
        return;
      }

      // 3. Check if receipt already exists
      final receiptSnap = await _db.child('receipts').child(bookingId).get().timeout(const Duration(seconds: 4));
      if (receiptSnap.exists) {
        debugPrint('[ReceiptService] Receipt already exists in Firebase for booking $bookingId.');
        return;
      }

      // 4. Gather remaining data & save receipt
      final String formattedDate = DateFormat('yyyyMMdd').format(booking.createdAt);
      final String shortId = bookingId.substring(0, bookingId.length > 5 ? 5 : bookingId.length).toUpperCase();
      final String receiptNumber = 'REC-$formattedDate-$shortId';
      final String invoiceNumber = 'INV-$formattedDate-$shortId';

      // Load user reward points balance
      int currentPoints = 0;
      final userSnap = await _db.child('users').child(booking.userId).child('rewardPoints').get().timeout(const Duration(seconds: 4));
      if (userSnap.exists && userSnap.value != null) {
        currentPoints = int.tryParse(userSnap.value.toString()) ?? 0;
      }

      final int earnedPoints = (booking.totalPrice / 10).floor();
      final int previousPoints = currentPoints - earnedPoints + booking.pointsRedeemed;

      final receiptData = {
        'receiptNumber': receiptNumber,
        'invoiceNumber': invoiceNumber,
        'bookingId': bookingId,
        'paymentId': approvedPayment['id'] ?? '',
        'dateIssued': DateTime.now().toIso8601String(),
        'paymentDate': approvedPayment['paymentDate'] ?? booking.createdAt.toIso8601String(),
        'paymentMethod': approvedPayment['paymentMethod'] ?? 'cash',
        'transactionId': approvedPayment['transactionId'] ?? approvedPayment['id'] ?? 'N/A',
        'totalPaid': booking.isOpenRental
            ? booking.finalAmount
            : booking.totalPrice +
                booking.lateFees +
                ((booking.returnInspection?['damageFee'] ?? 0.0) as num).toDouble() +
                ((booking.returnInspection?['cleaningFee'] ?? 0.0) as num).toDouble() +
                ((booking.returnInspection?['extraCharges'] ?? 0.0) as num).toDouble(),
        'rentalFee': booking.totalPrice + booking.discountAmount,
        'discountAmount': booking.discountAmount,
        'pointsRedeemed': booking.pointsRedeemed,
        'rewardPointsEarned': earnedPoints,
        'previousRewardBalance': previousPoints >= 0 ? previousPoints : 0,
        'currentRewardBalance': currentPoints,
        'status': 'Generated',
      };

      await _db.child('receipts').child(bookingId).set(receiptData);
      debugPrint('[ReceiptService] Automatically generated & stored receipt metadata for $bookingId.');
    } catch (e) {
      debugPrint('[ReceiptService] Error in triggerAutomaticReceiptCheck: $e');
    }
  }

  /// Generates the raw PDF bytes for a booking receipt.
  Future<Uint8List> generateReceiptPdf(String bookingId) async {
    // 1. Load all data from Firebase with strict timeouts and try-catch blocks to prevent hangs
    final BookingModel booking;
    try {
      final bookingSnap = await _db.child('bookings').child(bookingId).get().timeout(const Duration(seconds: 4));
      if (bookingSnap.exists && bookingSnap.value != null) {
        booking = BookingModel.fromMap(bookingId, bookingSnap.value as Map<dynamic, dynamic>);
      } else {
        throw Exception('Booking record not found.');
      }
    } catch (e) {
      debugPrint('[ReceiptService] Error loading booking: $e');
      rethrow;
    }

    // Fetch payments (Query by userId to comply with Firebase security rules)
    Map paymentMap = {};
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final targetUid = currentUid ?? booking.userId;
      final paymentsSnap = await _db.child('payments').orderByChild('userId').equalTo(targetUid).get().timeout(const Duration(seconds: 4));
      if (paymentsSnap.exists && paymentsSnap.value != null) {
        final paymentsMap = paymentsSnap.value as Map;
        for (var pValue in paymentsMap.values) {
          if (pValue is Map && pValue['bookingId'] == bookingId) {
            paymentMap = pValue;
            final pStatus = (pValue['paymentStatus'] ?? pValue['status'] ?? '').toString().toLowerCase();
            if (pStatus == 'approved' || pStatus == 'paid') {
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ReceiptService] Error loading payments: $e');
    }

    // Fetch user details
    Map userMap = {};
    try {
      final userSnap = await _db.child('users').child(booking.userId).get().timeout(const Duration(seconds: 4));
      if (userSnap.exists && userSnap.value != null) {
        userMap = userSnap.value as Map;
      }
    } catch (e) {
      debugPrint('[ReceiptService] Error loading user details: $e');
    }

    // Fetch vehicle details
    Map vehicleMap = {};
    try {
      final vehicleSnap = await _db.child('vehicles').child(booking.vehicleId).get().timeout(const Duration(seconds: 4));
      if (vehicleSnap.exists && vehicleSnap.value != null) {
        vehicleMap = vehicleSnap.value as Map;
      }
    } catch (e) {
      debugPrint('[ReceiptService] Error loading vehicle details: $e');
    }

    // Fetch receipt metadata (if already generated in storage, otherwise fallback dynamically)
    Map receiptMap = {};
    try {
      final receiptSnap = await _db.child('receipts').child(bookingId).get().timeout(const Duration(seconds: 4));
      if (receiptSnap.exists && receiptSnap.value != null) {
        receiptMap = receiptSnap.value as Map;
      }
    } catch (e) {
      debugPrint('[ReceiptService] Error loading receipt metadata: $e');
    }

    // 2. Parse details from company settings provider
    final companySettings = CompanySettingsProvider();
    final String companyName = companySettings.companyName;
    final String supportPhone = companySettings.companyPhone;
    final String supportEmail = companySettings.companyEmail;
    final String headquartersAddress = companySettings.companyAddress;
    final String website = companySettings.companyWebsite;
    final String companyRegNo = companySettings.companyRegistrationNumber;
    final String logoBase64 = companySettings.companyLogo;

    final String formattedDate = DateFormat('yyyyMMdd').format(booking.createdAt);
    final String shortId = bookingId.substring(0, bookingId.length > 5 ? 5 : bookingId.length).toUpperCase();

    final String receiptNumber = receiptMap['receiptNumber'] ?? 'REC-$formattedDate-$shortId';
    final String invoiceNumber = receiptMap['invoiceNumber'] ?? 'INV-$formattedDate-$shortId';
    final String dateIssuedStr = receiptMap['dateIssued'] ?? DateTime.now().toIso8601String();
    final DateTime dateIssued = DateTime.tryParse(dateIssuedStr) ?? DateTime.now();

    final String customerName = booking.userName;
    final String customerEmail = userMap['email'] ?? '';
    final String customerPhone = booking.userPhone.isNotEmpty ? booking.userPhone : (userMap['phone'] ?? '');
    final String drivingLicense = userMap['licenseNumber'] ?? 'N/A';

    final String vehicleName = booking.vehicleName;
    final String plateNumber = vehicleMap['plateNumber'] ?? 'N/A';
    final String category = vehicleMap['category'] ?? 'Premium';
    final String fuelType = vehicleMap['fuelType'] ?? 'Petrol';

    final String pickupBranch = vehicleMap['branchName'] ?? 'Main Corporate Hub';
    final String returnBranch = vehicleMap['branchName'] ?? 'Main Corporate Hub';

    final String paymentMethod = paymentMap['paymentMethod'] ?? 'Online Bank Transfer';
    final String transactionId = paymentMap['transactionId'] ?? paymentMap['id'] ?? 'N/A';
    final String paymentDateStr = paymentMap['paymentDate'] ?? booking.createdAt.toIso8601String();
    final DateTime paymentDate = DateTime.tryParse(paymentDateStr) ?? booking.createdAt;

    final int actualDaysCount;
    if (booking.isOpenRental) {
      if (booking.actualReturnTimestamp != null && booking.actualPickupTimestamp != null) {
        final diff = booking.actualReturnTimestamp!.difference(booking.actualPickupTimestamp!);
        final days = (diff.inHours / 24.0).ceil();
        actualDaysCount = days <= 0 ? 1 : days;
      } else {
        actualDaysCount = 1;
      }
    } else {
      actualDaysCount = booking.rentalDays <= 0 ? 1 : booking.rentalDays;
    }

    // Cost calculations
    final double rentalFee = booking.totalPrice + booking.discountAmount;
    final double discount = booking.discountAmount;
    final double totalPaid = booking.isOpenRental
        ? booking.finalAmount
        : booking.totalPrice +
            booking.lateFees +
            ((booking.returnInspection?['damageFee'] ?? 0.0) as num).toDouble() +
            ((booking.returnInspection?['cleaningFee'] ?? 0.0) as num).toDouble() +
            ((booking.returnInspection?['extraCharges'] ?? 0.0) as num).toDouble();

    // Reward points calculations
    int earnedPoints = receiptMap['rewardPointsEarned'] ?? (booking.totalPrice / 10).floor();
    int currentPoints = 0;
    if (receiptMap.containsKey('currentRewardBalance')) {
      currentPoints = receiptMap['currentRewardBalance'];
    } else {
      currentPoints = int.tryParse(userMap['rewardPoints']?.toString() ?? '0') ?? 0;
    }
    int previousPoints = receiptMap['previousRewardBalance'] ?? (currentPoints - earnedPoints + booking.pointsRedeemed);
    if (previousPoints < 0) previousPoints = 0;

    // Do NOT download any external images while generating the PDF (Timeout Protection & CORS safety)

    // 3. Build the PDF Document
    final pdf = pw.Document();

    // Define colors matching AppColors
    final navyColor = PdfColor.fromInt(0xFF1E293B);
    final orangeColor = PdfColor.fromInt(0xFFF97316);
    final greyColor = PdfColor.fromInt(0xFF64748B);
    final lightGreyColor = PdfColor.fromInt(0xFFF8FAFC);
    final borderGreyColor = PdfColor.fromInt(0xFFE2E8F0);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          pw.Widget logoWidget;
          if (logoBase64.isNotEmpty) {
            try {
              final rawBase64 = logoBase64.split(',').last;
              final bytes = base64Decode(rawBase64);
              final image = pw.MemoryImage(bytes);
              logoWidget = pw.Container(
                width: 32,
                height: 32,
                child: pw.Image(image, fit: pw.BoxFit.contain),
              );
            } catch (e) {
              debugPrint('[ReceiptService] Error decoding base64 logo in PDF: $e');
              logoWidget = pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: orangeColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'CR',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              );
            }
          } else {
            logoWidget = pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: orangeColor,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'CR',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            );
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER SECTION (Logo & Branding)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          logoWidget,
                          pw.SizedBox(width: 8),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                companyName,
                                style: pw.TextStyle(
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                  color: navyColor,
                                ),
                              ),
                              pw.Text(
                                'Car Rental Management',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: greyColor,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        headquartersAddress,
                        style: pw.TextStyle(fontSize: 8, color: greyColor, height: 1.3),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Reg No: $companyRegNo', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: orangeColor,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Receipt No: $receiptNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor)),
                      pw.Text('Invoice No: $invoiceNumber', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                      pw.Text('Date Issued: ${DateFormat('dd MMM yyyy, hh:mm a').format(dateIssued)}', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                      pw.Text('Booking Ref: #${booking.id.toUpperCase()}', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: borderGreyColor),
              pw.SizedBox(height: 12),

              // CUSTOMER & PAYMENT OVERVIEW
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CUSTOMER DETAILS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor)),
                        pw.SizedBox(height: 6),
                        pw.Text(customerName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navyColor)),
                        pw.Text('Customer ID: ${booking.userId.substring(0, booking.userId.length > 8 ? 8 : booking.userId.length).toUpperCase()}', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                        pw.Text('Email: $customerEmail', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                        pw.Text('Phone: $customerPhone', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                        pw.Text('Driving License: $drivingLicense', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PAYMENT INFORMATION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor)),
                        pw.SizedBox(height: 6),
                        pw.Text('Method: $paymentMethod', style: pw.TextStyle(fontSize: 8, color: navyColor, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Transaction Ref ID: $transactionId', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                        pw.Text('Payment Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(paymentDate)}', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                        pw.Row(
                          children: [
                            pw.Text('Payment Status: ', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                            pw.Text(
                              'PAID',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF10B981)),
                            ),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Text('Rental Status: ', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                            pw.Text(
                              booking.status.toUpperCase(),
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: booking.status.toLowerCase() == 'completed' ? PdfColor.fromInt(0xFF10B981) : orangeColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // RENTAL VEHICLE & JOURNEY CARD
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: lightGreyColor,
                  border: pw.Border.all(color: borderGreyColor, width: 1),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 80,
                      height: 55,
                      margin: const pw.EdgeInsets.only(right: 12),
                      decoration: pw.BoxDecoration(
                        color: lightGreyColor,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: orangeColor, width: 1.5),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            'VEHICLE',
                            style: pw.TextStyle(
                              color: orangeColor,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Rental Unit',
                            style: pw.TextStyle(
                              color: navyColor,
                              fontSize: 7,
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            vehicleName.toUpperCase(),
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: navyColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text('Plate: $plateNumber | Class: $category | Fuel: $fuelType', style: pw.TextStyle(fontSize: 8, color: greyColor)),
                          pw.SizedBox(height: 6),
                          pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('PICKUP BRANCH', style: pw.TextStyle(fontSize: 7, color: greyColor, fontWeight: pw.FontWeight.bold)),
                                    pw.Text(pickupBranch, style: pw.TextStyle(fontSize: 8, color: navyColor, fontWeight: pw.FontWeight.bold)),
                                    pw.Text(DateFormat('dd MMM yyyy, hh:mm a').format(booking.pickUpDate), style: pw.TextStyle(fontSize: 7, color: greyColor)),
                                  ],
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('RETURN BRANCH', style: pw.TextStyle(fontSize: 7, color: greyColor, fontWeight: pw.FontWeight.bold)),
                                    pw.Text(returnBranch, style: pw.TextStyle(fontSize: 8, color: navyColor, fontWeight: pw.FontWeight.bold)),
                                    pw.Text(
                                      booking.isOpenRental
                                          ? 'OPEN RENTAL'
                                          : (booking.returnDate != null ? DateFormat('dd MMM yyyy, hh:mm a').format(booking.returnDate!) : ""),
                                      style: pw.TextStyle(fontSize: 7, color: greyColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: navyColor,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            '$actualDaysCount',
                            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 16),
                          ),
                          pw.Text(
                            actualDaysCount == 1 ? 'DAY' : 'DAYS',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 6, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // COST BREAKDOWN TABLE
              pw.Text('COST BREAKDOWN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor)),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder(
                  bottom: pw.BorderSide(color: borderGreyColor, width: 0.5),
                  horizontalInside: pw.BorderSide(color: borderGreyColor, width: 0.5),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1),
                },
                children: [
                  // Headers
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: navyColor),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Text('Item Description', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Text('Amount', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Rental Fee row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Text('Rental Fee ($actualDaysCount days @ RM ${vehicleMap['pricePerDay'] ?? booking.totalPrice / actualDaysCount}/day)', style: pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Text('RM ${rentalFee.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Insurance row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Text('Comprehensive Collision Damage Waiver (Insurance)', style: pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Text('RM 0.00', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Additional Services row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Text('Additional Services & Add-ons', style: pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Text('RM 0.00', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Tax row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Text('Service Tax (0% SST)', style: pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: pw.Text('RM 0.00', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Promotional Discount row
                  if (booking.promotionDiscountAmount > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('Promotional Discount (${booking.promotionCode ?? booking.promotionName ?? 'Applied'})', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF10B981))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('-RM ${booking.promotionDiscountAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF10B981), fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  // Loyalty Points Discount row
                  if (discount > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('Loyalty Points Redemption (${booking.pointsRedeemed} pts Redeemed)', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF10B981))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('-RM ${discount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF10B981), fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  // Late fees row
                  if (booking.lateFees > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('Late Return Fees', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFEF4444))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('RM ${booking.lateFees.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFEF4444)), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  // Damage fee row
                  if (booking.returnInspection != null && (booking.returnInspection!['damageFee'] ?? 0.0) > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('Vehicle Damage Repair Charges', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFEF4444))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('RM ${(booking.returnInspection!['damageFee'] ?? 0.0).toDouble().toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFEF4444)), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  // Cleaning fee row
                  if (booking.returnInspection != null && (booking.returnInspection!['cleaningFee'] ?? 0.0) > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('Special Cleaning Fees', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFEF4444))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('RM ${(booking.returnInspection!['cleaningFee'] ?? 0.0).toDouble().toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFEF4444)), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  // Extra charges row
                  if (booking.returnInspection != null && (booking.returnInspection!['extraCharges'] ?? 0.0) > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('Additional Charges (${booking.returnInspection!['additionalNotes'] ?? 'Inspection Fees'})', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFEF4444))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('RM ${(booking.returnInspection!['extraCharges'] ?? 0.0).toDouble().toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFEF4444)), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  // Total Paid row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightGreyColor),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: pw.Text('TOTAL AMOUNT PAID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: navyColor)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: pw.Text('RM ${totalPaid.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: orangeColor), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // REWARDS & QR VERIFICATION FOOTER
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderGreyColor, width: 0.5),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('MEMBERSHIP LOYALTY STARS', style: pw.TextStyle(fontSize: 7, color: greyColor, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Previous Reward Balance:', style: pw.TextStyle(fontSize: 8, color: navyColor)),
                              pw.Text('$previousPoints pts', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyColor)),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Points Earned from this Booking:', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF10B981))),
                              pw.Text('+$earnedPoints pts', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF10B981))),
                            ],
                          ),
                          if (booking.pointsRedeemed > 0)
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Points Redeemed for Discount:', style: pw.TextStyle(fontSize: 8, color: orangeColor)),
                                pw.Text('-${booking.pointsRedeemed} pts', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: orangeColor)),
                              ],
                            ),
                          pw.Divider(thickness: 0.5, color: borderGreyColor),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Current Reward Balance:', style: pw.TextStyle(fontSize: 8, color: navyColor, fontWeight: pw.FontWeight.bold)),
                              pw.Text('$currentPoints pts', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: orangeColor)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // QR verification widget
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 70,
                        height: 70,
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderGreyColor),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: 'BookingID: $bookingId\nReceiptNo: $receiptNumber\nCustomerID: ${booking.userId}',
                          width: 60,
                          height: 60,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Scan to Verify', style: pw.TextStyle(fontSize: 6, color: greyColor, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // BOTTOM FOOTER
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Thank you for choosing ${companyName.toUpperCase()}. We appreciate your business.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'For Customer Support:  Phone: $supportPhone   |   Email: $supportEmail   |   Website: $website',
                      style: pw.TextStyle(fontSize: 7, color: greyColor),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Open full-screen PDF view dialog layout with print option
  Future<void> viewReceipt(BuildContext context, String bookingId) async {
    BuildContext? dialogContext;
    bool dialogShown = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        dialogShown = true;
        return const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        );
      },
    );

    try {
      final bytes = await generateReceiptPdf(bookingId);
      
      // Yield to let the dialog route completely push
      await Future.delayed(Duration.zero);
      
      if (dialogShown && dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      if (kIsWeb) {
        download_helper.viewPdfInNewTab(bytes, 'receipt_$bookingId.pdf');
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: 'receipt_$bookingId.pdf',
        );
      }
    } catch (e) {
      await Future.delayed(Duration.zero);
      if (dialogShown && dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
      if (context.mounted) {
        _showError(context, e.toString());
      }
    }
  }

  /// Download the PDF invoice receipt directly to the device storage
  Future<void> downloadReceipt(BuildContext context, String bookingId) async {
    BuildContext? dialogContext;
    bool dialogShown = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        dialogShown = true;
        return const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        );
      },
    );

    try {
      final bytes = await generateReceiptPdf(bookingId);
      
      // Yield to let the dialog route completely push
      await Future.delayed(Duration.zero);
      
      if (dialogShown && dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      if (kIsWeb) {
        download_helper.downloadFile(bytes, 'receipt_$bookingId.pdf');
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: 'receipt_$bookingId.pdf',
        );
      }
    } catch (e) {
      await Future.delayed(Duration.zero);
      if (dialogShown && dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
      if (context.mounted) {
        _showError(context, e.toString());
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed: $message'), backgroundColor: Colors.redAccent),
    );
  }
}
