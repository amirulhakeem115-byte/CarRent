import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/models/payment_model.dart';
import 'package:carrent_system/models/maintenance_job_model.dart';
import 'package:carrent_system/models/notification_model.dart';
import 'package:carrent_system/models/branch_model.dart';

void main() {
  group('PaymentModel Tests', () {
    test('fromMap and toMap mapping should correctly store and retrieve all required fields', () {
      final now = DateTime.now();
      final mockData = {
        'bookingId': 'b123',
        'userId': 'u456',
        'customerUid': 'u456',
        'amount': 250.0,
        'depositAmount': 50.0,
        'balanceAmount': 200.0,
        'paymentMethod': 'DuitNow QR',
        'status': 'Pending Verification',
        'paymentStatus': 'Pending Verification',
        'transactionId': 'TXN998877',
        'paymentDate': now.toIso8601String(),
        'receiptImage': 'data:image/png;base64,mockbase64',
        'receiptFile': 'data:image/png;base64,mockbase64',
        'uploadedAt': now.toIso8601String(),
        'rejectionReason': 'Incorrect amount',
      };

      // Test fromMap
      final payment = PaymentModel.fromMap('pay_id_1', mockData);

      expect(payment.id, 'pay_id_1');
      expect(payment.bookingId, 'b123');
      expect(payment.userId, 'u456');
      expect(payment.amount, 250.0);
      expect(payment.depositAmount, 50.0);
      expect(payment.balanceAmount, 200.0);
      expect(payment.paymentMethod, 'DuitNow QR');
      expect(payment.status, 'Pending Verification');
      expect(payment.paymentStatus, 'Pending Verification');
      expect(payment.transactionId, 'TXN998877');
      expect(payment.paymentDate.day, now.day);
      expect(payment.receiptImage, 'data:image/png;base64,mockbase64');
      expect(payment.uploadedAt, now.toIso8601String());
      expect(payment.rejectionReason, 'Incorrect amount');

      // Test toMap
      final mapped = payment.toMap();
      expect(mapped['bookingId'], 'b123');
      expect(mapped['userId'], 'u456');
      expect(mapped['customerUid'], 'u456');
      expect(mapped['amount'], 250.0);
      expect(mapped['depositAmount'], 50.0);
      expect(mapped['balanceAmount'], 200.0);
      expect(mapped['paymentMethod'], 'DuitNow QR');
      expect(mapped['status'], 'Pending Verification');
      expect(mapped['paymentStatus'], 'Pending Verification');
      expect(mapped['transactionId'], 'TXN998877');
      expect(mapped['receiptImage'], 'data:image/png;base64,mockbase64');
      expect(mapped['uploadedAt'], now.toIso8601String());
      expect(mapped['rejectionReason'], 'Incorrect amount');
    });

    test('paymentStatus and customerUid should fallback correctly to status and userId respectively', () {
      final mockDataMin = {
        'bookingId': 'b789',
        'userId': 'u999',
        'amount': 150.0,
        'depositAmount': 0.0,
        'balanceAmount': 150.0,
        'paymentMethod': 'Cash',
        'status': 'Approved',
        'paymentDate': DateTime.now().toIso8601String(),
      };

      final payment = PaymentModel.fromMap('pay_id_2', mockDataMin);
      expect(payment.paymentStatus, 'Approved');
      expect(payment.customerUid, 'u999');
      expect(payment.userId, 'u999');
      expect(payment.receiptImage, isNull);
    });
  });

  group('MaintenanceJobModel Tests', () {
    test('fromMap and toMap mapping should correctly store and retrieve all required fields', () {
      final mockData = {
        'maintenanceId': 'm123',
        'vehicleId': 'v456',
        'vehicleName': 'Perodua Axia',
        'title': 'Oil Change',
        'description': 'Routine oil change and filter replacement',
        'cost': 150.0,
        'startDate': '2026-06-25',
        'endDate': '2026-06-25',
        'status': 'Scheduled',
        'showToCustomer': true,
        'createdAt': '2026-06-25T12:00:00Z',
        'updatedAt': '2026-06-25T12:00:00Z',
      };

      // Test fromMap
      final job = MaintenanceJobModel.fromMap('m123', mockData);

      expect(job.id, 'm123');
      expect(job.vehicleId, 'v456');
      expect(job.vehicleName, 'Perodua Axia');
      expect(job.title, 'Oil Change');
      expect(job.description, 'Routine oil change and filter replacement');
      expect(job.cost, 150.0);
      expect(job.startDate, '2026-06-25');
      expect(job.endDate, '2026-06-25');
      expect(job.status, 'Scheduled');
      expect(job.showToCustomer, true);
      expect(job.createdAt, '2026-06-25T12:00:00Z');
      expect(job.updatedAt, '2026-06-25T12:00:00Z');

      // Test toMap
      final mapped = job.toMap();
      expect(mapped['maintenanceId'], 'm123');
      expect(mapped['vehicleId'], 'v456');
      expect(mapped['vehicleName'], 'Perodua Axia');
      expect(mapped['title'], 'Oil Change');
      expect(mapped['description'], 'Routine oil change and filter replacement');
      expect(mapped['cost'], 150.0);
      expect(mapped['startDate'], '2026-06-25');
      expect(mapped['endDate'], '2026-06-25');
      expect(mapped['status'], 'Scheduled');
      expect(mapped['showToCustomer'], true);
      expect(mapped['createdAt'], '2026-06-25T12:00:00Z');
      expect(mapped['updatedAt'], '2026-06-25T12:00:00Z');
    });

    test('fromMap should fallback correctly for old schemas (serviceType and notes)', () {
      final mockDataOld = {
        'vehicleId': 'v999',
        'vehicleName': 'Proton Saga',
        'serviceType': 'Tyre Replacement',
        'notes': 'Replaced all front tyres',
        'cost': 300.0,
        'date': '2026-05-10',
        'status': 'In Progress',
        'showToCustomer': false,
      };

      final job = MaintenanceJobModel.fromMap('m999', mockDataOld);
      expect(job.title, 'Tyre Replacement');
      expect(job.description, 'Replaced all front tyres');
      expect(job.startDate, '2026-05-10');
      expect(job.endDate, '2026-05-10');
      expect(job.status, 'In Progress');
    });
  });

  group('NotificationModel Tests', () {
    test('fromMap and toMap mapping should correctly store and retrieve all required fields', () {
      final now = DateTime.now();
      final mockData = {
        'userId': 'user123',
        'title': 'Test Notification',
        'message': 'This is a test notification message.',
        'type': 'booking',
        'isRead': false,
        'createdAt': now.toIso8601String(),
      };

      // Test fromMap
      final notification = NotificationModel.fromMap('notif_1', mockData);

      expect(notification.id, 'notif_1');
      expect(notification.userId, 'user123');
      expect(notification.title, 'Test Notification');
      expect(notification.message, 'This is a test notification message.');
      expect(notification.type, 'booking');
      expect(notification.isRead, false);
      expect(notification.createdAt.day, now.day);

      // Test toMap
      final mapped = notification.toMap();
      expect(mapped['userId'], 'user123');
      expect(mapped['title'], 'Test Notification');
      expect(mapped['message'], 'This is a test notification message.');
      expect(mapped['type'], 'booking');
      expect(mapped['isRead'], false);
      expect(mapped['createdAt'], now.toIso8601String());
    });
  });

  group('BranchModel Tests', () {
    test('fromMap and toMap mapping should correctly store and retrieve all required fields', () {
      final mockData = {
        'branchName': 'Cheras Hub',
        'address': 'Cheras Leisure Mall, Kuala Lumpur',
        'phone': '+603-91301122',
        'latitude': 3.0892,
        'longitude': 101.7410,
        'operatingHours': '08:00 AM - 10:00 PM',
        'status': 'Active',
      };

      // Test fromMap
      final branch = BranchModel.fromMap('branch_1', mockData);

      expect(branch.id, 'branch_1');
      expect(branch.branchName, 'Cheras Hub');
      expect(branch.name, 'Cheras Hub');
      expect(branch.address, 'Cheras Leisure Mall, Kuala Lumpur');
      expect(branch.phone, '+603-91301122');
      expect(branch.latitude, 3.0892);
      expect(branch.longitude, 101.7410);
      expect(branch.operatingHours, '08:00 AM - 10:00 PM');
      expect(branch.status, 'Active');

      // Test toMap
      final mapped = branch.toMap();
      expect(mapped['branchName'], 'Cheras Hub');
      expect(mapped['name'], 'Cheras Hub');
      expect(mapped['address'], 'Cheras Leisure Mall, Kuala Lumpur');
      expect(mapped['phone'], '+603-91301122');
      expect(mapped['latitude'], 3.0892);
      expect(mapped['longitude'], 101.7410);
      expect(mapped['operatingHours'], '08:00 AM - 10:00 PM');
      expect(mapped['status'], 'Active');
    });

    test('fromMap fallback behavior should populate default values for missing keys', () {
      final mockDataMin = {
        'name': 'Gombak Hub',
        'address': 'Gombak LRT Station, Selangor',
      };

      // Test fromMap fallbacks
      final branch = BranchModel.fromMap('branch_2', mockDataMin);

      expect(branch.id, 'branch_2');
      expect(branch.branchName, 'Gombak Hub');
      expect(branch.name, 'Gombak Hub');
      expect(branch.address, 'Gombak LRT Station, Selangor');
      expect(branch.phone, '');
      expect(branch.latitude, 3.0166);
      expect(branch.longitude, 101.7916);
      expect(branch.operatingHours, '09:00 AM - 09:00 PM');
      expect(branch.status, 'Active');
    });
  });
}


