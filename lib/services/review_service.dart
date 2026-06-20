import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/review_model.dart';

class ReviewService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref().child('reviews');

  Future<void> submitReview(ReviewModel review) async {
    try {
      final newRef = _db.push();
      await newRef.set(review.toMap());
    } catch (e) {
      debugPrint('Error submitting review: $e');
      rethrow;
    }
  }

  Future<List<ReviewModel>> getVehicleReviews(String vehicleId) async {
    List<ReviewModel> reviews = [];
    try {
      final snapshot = await _db.orderByChild('vehicleId').equalTo(vehicleId).get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          reviews.add(ReviewModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
    } catch (e) {
      debugPrint('Error getting vehicle reviews: $e');
    }
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reviews;
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
      final snapshot = await _db.get();
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
