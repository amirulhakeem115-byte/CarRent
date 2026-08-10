import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/models/booking_model.dart';
import 'package:carrent_system/services/return_video_storage_service.dart';

void main() {
  group('Return Video Evidence Unit Tests', () {
    test('BookingModel fromMap and toMap correctly parse returnVideos metadata', () {
      final rawMap = {
        'vehicleId': 'v101',
        'vehicleName': 'Honda Civic',
        'userId': 'cust_123',
        'userName': 'Customer Ahmad',
        'userPhone': '+60123456789',
        'pickUpDate': '2026-08-20T10:00:00.000Z',
        'totalPrice': 300.0,
        'depositAmount': 100.0,
        'status': 'active',
        'createdAt': '2026-08-10T10:00:00.000Z',
        'returnVideoSkipped': false,
        'returnVideos': {
          'vid_1': {
            'videoId': 'vid_1',
            'bookingId': 'booking_999',
            'customerId': 'cust_123',
            'uploaderId': 'cust_123',
            'uploaderName': 'Customer Ahmad',
            'uploaderRole': 'customer',
            'videoUrl': 'https://firebasestorage.googleapis.com/v0/b/test/o/return_videos%2Fbooking_999%2Fvid_1?alt=media',
            'uploadedAt': '2026-08-20T14:32:00.000Z',
            'originalFileName': 'cust_evidence.mp4',
            'fileSize': 12500000,
          },
          'vid_2': {
            'videoId': 'vid_2',
            'bookingId': 'booking_999',
            'customerId': 'cust_123',
            'uploaderId': 'emp_456',
            'uploaderName': 'Staff Employee',
            'uploaderRole': 'employee',
            'videoUrl': 'https://firebasestorage.googleapis.com/v0/b/test/o/return_videos%2Fbooking_999%2Fvid_2?alt=media',
            'uploadedAt': '2026-08-20T15:05:00.000Z',
            'originalFileName': 'emp_evidence.mp4',
            'fileSize': 18900000,
          },
        },
      };

      final booking = BookingModel.fromMap('booking_999', rawMap);

      expect(booking.id, equals('booking_999'));
      expect(booking.returnVideoSkipped, isFalse);
      expect(booking.hasAnyReturnVideo, isTrue);
      expect(booking.returnVideosList.length, equals(2));

      expect(booking.hasCustomerReturnVideo, isTrue);
      expect(booking.customerReturnVideo?['uploaderName'], equals('Customer Ahmad'));
      expect(booking.customerReturnVideo?['uploaderRole'], equals('customer'));

      expect(booking.hasEmployeeReturnVideo, isTrue);
      expect(booking.employeeReturnVideo?['uploaderName'], equals('Staff Employee'));
      expect(booking.employeeReturnVideo?['uploaderRole'], equals('employee'));

      // Verify chronological sorting (vid_1 uploaded at 14:32, vid_2 at 15:05)
      final sortedList = booking.returnVideosList;
      expect(sortedList.first['videoId'], equals('vid_1'));
      expect(sortedList.last['videoId'], equals('vid_2'));

      // Test toMap serialization
      final map = booking.toMap();
      expect(map['returnVideos'], isNotNull);
      expect(map['returnVideos']['vid_1']['uploaderRole'], equals('customer'));
      expect(map['returnVideos']['vid_2']['uploaderRole'], equals('employee'));
    });

    test('ReturnVideoStorageService validates empty booking ID', () {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      expect(
        () => ReturnVideoStorageService.validateUploadInputs(
          bookingId: '',
          videoBytes: dummyBytes,
          fileName: 'test.mp4',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ReturnVideoStorageService validates empty file bytes', () {
      expect(
        () => ReturnVideoStorageService.validateUploadInputs(
          bookingId: 'b123',
          videoBytes: Uint8List(0),
          fileName: 'test.mp4',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ReturnVideoStorageService validates unsupported file formats', () {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      expect(
        () => ReturnVideoStorageService.validateUploadInputs(
          bookingId: 'b123',
          videoBytes: dummyBytes,
          fileName: 'test.exe',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
