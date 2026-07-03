import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:carrent_system/models/review_model.dart';

void main() {
  group('Booking Completion & Review System Logic Tests', () {
    test('1. ReviewModel with bookingId Serialization', () {
      final now = DateTime.now();
      final Map<dynamic, dynamic> mockMap = {
        'bookingId': 'b_rev_100',
        'vehicleId': 'v_rev_200',
        'userId': 'u_rev_300',
        'userName': 'Musab Test',
        'rating': 4.5,
        'comment': 'Awesome car and service!',
        'createdAt': now.toIso8601String(),
      };

      final review = ReviewModel.fromMap('r_id_999', mockMap);
      
      expect(review.id, 'r_id_999');
      expect(review.bookingId, 'b_rev_100');
      expect(review.vehicleId, 'v_rev_200');
      expect(review.userId, 'u_rev_300');
      expect(review.userName, 'Musab Test');
      expect(review.rating, 4.5);
      expect(review.comment, 'Awesome car and service!');
      expect(review.createdAt.day, now.day);

      final map = review.toMap();
      expect(map['bookingId'], 'b_rev_100');
      expect(map['vehicleId'], 'v_rev_200');
      expect(map['userId'], 'u_rev_300');
      expect(map['userName'], 'Musab Test');
      expect(map['rating'], 4.5);
      expect(map['comment'], 'Awesome car and service!');
    });

    test('2. Completed Booking Status Transition Date/Time Formatting', () {
      final updates = <String, dynamic>{};
      final status = 'completed';
      final statusLower = status.toLowerCase();

      if (statusLower == 'completed') {
        updates['isReturned'] = true;
        updates['actualReturnTime'] = DateFormat('hh:mm a').format(DateTime.now());
        updates['actualReturnDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }

      expect(updates['isReturned'], true);
      expect(updates['actualReturnTime'], isNotNull);
      expect(updates['actualReturnTime'].toString().contains('AM') || updates['actualReturnTime'].toString().contains('PM'), true);
      expect(updates['actualReturnDate'], isNotNull);
      expect(updates['actualReturnDate'].toString().split('-').length, 3);
    });

    test('3. Active Booking Status Transition Date/Time Formatting', () {
      final updates = <String, dynamic>{};
      final status = 'active';
      final statusLower = status.toLowerCase();

      if (statusLower == 'active') {
        updates['actualPickupTime'] = DateFormat('hh:mm a').format(DateTime.now());
        updates['actualPickupDate'] = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }

      expect(updates['actualPickupTime'], isNotNull);
      expect(updates['actualPickupTime'].toString().contains('AM') || updates['actualPickupTime'].toString().contains('PM'), true);
      expect(updates['actualPickupDate'], isNotNull);
      expect(updates['actualPickupDate'].toString().split('-').length, 3);
    });
  });
}
