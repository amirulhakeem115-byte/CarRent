import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/review_model.dart';

class ReviewService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('reviews');

  Future<void> submitReview(ReviewModel review) async {
    try {
      if (review.bookingId.isNotEmpty) {
        final duplicate = await hasSubmittedReview(review.bookingId);
        if (duplicate) {
          throw Exception('A review has already been submitted for this booking.');
        }
      }
      final newRef = _db.push();
      await newRef.set(review.toMap()).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error submitting review: $e');
      rethrow;
    }
  }

  Future<bool> hasSubmittedReview(String bookingId) async {
    if (bookingId.isEmpty) return false;
    try {
      final snapshot = await _db.orderByChild('bookingId').equalTo(bookingId).get().timeout(const Duration(seconds: 5));
      return snapshot.exists && snapshot.value != null;
    } catch (e) {
      debugPrint('Error checking duplicate review: $e');
      return false;
    }
  }

  Future<List<ReviewModel>> getVehicleReviews(String vehicleId) async {
    List<ReviewModel> reviews = [];
    try {
      final snapshot = await _db.orderByChild('vehicleId').equalTo(vehicleId).get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          reviews.add(ReviewModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      } else {
        // Dynamically seed reviews for this vehicle using its brand & model
        try {
          final vehSnapshot = await FirebaseDatabase.instance.ref().child('vehicles').child(vehicleId).get().timeout(const Duration(seconds: 4));
          if (vehSnapshot.exists) {
            final vehData = vehSnapshot.value as Map<dynamic, dynamic>;
            final brand = (vehData['brand'] ?? '').toString();
            final model = (vehData['model'] ?? '').toString();
            final defaults = _generateDefaultReviews(vehicleId, brand, model);
            for (var r in defaults) {
              await submitReview(r);
              reviews.add(r);
            }
          }
        } catch (e) {
          debugPrint('Failed to dynamically seed reviews for $vehicleId: $e');
        }
      }
    } catch (e) {
      debugPrint('Error getting vehicle reviews: $e');
    }
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reviews;
  }

  List<ReviewModel> _generateDefaultReviews(String vehicleId, String brand, String model) {
    final now = DateTime.now();
    final lowerModel = model.toLowerCase();
    
    if (lowerModel.contains('axia') || lowerModel.contains('saga') || lowerModel.contains('bezza')) {
      return [
        ReviewModel(
          id: '',
          bookingId: 'seed_booking_1',
          vehicleId: vehicleId,
          userId: 'seed_u1',
          userName: 'Muhammad Firdaus',
          rating: 5.0,
          comment: 'Outstanding fuel efficiency! I drove the $brand $model around KL for 4 days and only used half a tank. Very clean and easy to drive.',
          createdAt: now.subtract(const Duration(days: 5)),
        ),
        ReviewModel(
          id: '',
          bookingId: 'seed_booking_2',
          vehicleId: vehicleId,
          userId: 'seed_u2',
          userName: 'Siti Aminah',
          rating: 4.5,
          comment: 'Very practical car and affordable rental rate. The pickup at Kajang was smooth. Ideal for budget city travel.',
          createdAt: now.subtract(const Duration(days: 12)),
        ),
      ];
    } else if (lowerModel.contains('city') || lowerModel.contains('vios') || lowerModel.contains('civic')) {
      return [
        ReviewModel(
          id: '',
          bookingId: 'seed_booking_3',
          vehicleId: vehicleId,
          userId: 'seed_u3',
          userName: 'Chong Wei Ming',
          rating: 5.0,
          comment: 'Perfect sedan experience. The $brand $model was spotless and drove like a dream. Aircond was freezing cold, and Apple CarPlay worked perfectly.',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        ReviewModel(
          id: '',
          bookingId: 'seed_booking_4',
          vehicleId: vehicleId,
          userId: 'seed_u4',
          userName: 'Kavitha Rajan',
          rating: 4.5,
          comment: 'Comfortable cabin and massive boot space. Smooth drive on the highway to Penang. Highly recommended.',
          createdAt: now.subtract(const Duration(days: 18)),
        ),
      ];
    } else if (lowerModel.contains('x50') || lowerModel.contains('x70') || lowerModel.contains('hr-v') || lowerModel.contains('cross')) {
      return [
        ReviewModel(
          id: '',
          bookingId: 'seed_booking_5',
          vehicleId: vehicleId,
          userId: 'seed_u5',
          userName: 'Ahmad Faiz',
          rating: 5.0,
          comment: 'This $brand $model is incredibly premium. The active safety suite is very reassuring on highways. High driving position is fantastic.',
          createdAt: now.subtract(const Duration(days: 4)),
        ),
        ReviewModel(
          id: '',
          bookingId: 'seed_booking_6',
          vehicleId: vehicleId,
          userId: 'seed_u6',
          userName: 'Wong Siew Ling',
          rating: 4.5,
          comment: 'Very smooth ride, lots of space for the kids, and excellent phone connectivity. Definitely renting this SUV again.',
          createdAt: now.subtract(const Duration(days: 10)),
        ),
      ];
    } else if (lowerModel.contains('alza') || lowerModel.contains('innova')) {
      return [
        ReviewModel(
          id: '',
          bookingId: 'seed_booking_7',
          vehicleId: vehicleId,
          userId: 'seed_u7',
          userName: 'Ridhuan Yusof',
          rating: 5.0,
          comment: 'Rented this $brand $model for a family holiday. Fits 7 of us comfortably with luggage space. Dual aircond blowers are a lifesaver!',
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        ReviewModel(
          id: '',
          bookingId: 'seed_booking_8',
          vehicleId: vehicleId,
          userId: 'seed_u8',
          userName: 'Grace Choong',
          rating: 4.5,
          comment: 'Excellent family transport. Clean, robust, and handles very well even when fully loaded. Smooth booking.',
          createdAt: now.subtract(const Duration(days: 15)),
        ),
      ];
    } else {
      return [
        ReviewModel(
          id: '',
          bookingId: 'seed_booking_9',
          vehicleId: vehicleId,
          userId: 'seed_u9',
          userName: 'Azlan Shah',
          rating: 4.8,
          comment: 'Excellent condition $brand $model. Prompt service and very seamless transaction.',
          createdAt: now.subtract(const Duration(days: 7)),
        ),
      ];
    }
  }

  Future<double> getAverageRating(String vehicleId) async {
    final reviews = await getVehicleReviews(vehicleId);
    if (reviews.isEmpty) return 0.0;
    double sum = 0.0;
    for (var r in reviews) {
      sum += r.rating;
    }
    return sum / reviews.length;
  }

  Future<List<ReviewModel>> getAllReviews() async {
    List<ReviewModel> reviews = [];
    try {
      final snapshot = await _db.get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          reviews.add(ReviewModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting all reviews: $e');
    }
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reviews;
  }
}
