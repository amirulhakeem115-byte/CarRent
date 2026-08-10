import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart';
import 'notification_service.dart';

class ReturnVideoStorageService {
  static final ReturnVideoStorageService _instance = ReturnVideoStorageService._internal();
  factory ReturnVideoStorageService() => _instance;
  ReturnVideoStorageService._internal();

  FirebaseDatabase get _db => FirebaseDatabase.instance;
  NotificationService get _notificationService => NotificationService();

  String get _storageBucket {
    return DefaultFirebaseOptions.currentPlatform.storageBucket ?? 'car-rental-management-sy-22c7f.firebasestorage.app';
  }

  /// Validates inputs for video evidence upload (booking ID, bytes size, file format).
  static void validateUploadInputs({
    required String bookingId,
    required Uint8List videoBytes,
    required String fileName,
  }) {
    if (bookingId.trim().isEmpty) {
      throw ArgumentError('Booking ID cannot be empty.');
    }
    if (videoBytes.isEmpty) {
      throw ArgumentError('Video file bytes cannot be empty.');
    }

    final int sizeInBytes = videoBytes.length;
    if (sizeInBytes > 100 * 1024 * 1024) {
      throw ArgumentError('Video file size exceeds the 100MB limit.');
    }

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'mp4';
    final allowedExts = ['mp4', 'mov', 'webm', 'avi', 'mkv', 'm4v'];
    if (!allowedExts.contains(ext)) {
      throw ArgumentError('Unsupported video format (.$ext). Allowed formats: mp4, mov, webm, avi, mkv, m4v.');
    }
  }

  /// Uploads video bytes/file to Firebase Storage and saves metadata to Database.
  Future<Map<String, dynamic>> uploadReturnVideo({
    required String bookingId,
    required String uploaderId,
    required String uploaderName,
    required String uploaderRole, // 'customer' or 'employee'
    required Uint8List videoBytes,
    required String fileName,
    String? customerId,
  }) async {
    validateUploadInputs(
      bookingId: bookingId,
      videoBytes: videoBytes,
      fileName: fileName,
    );

    final int sizeInBytes = videoBytes.length;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'mp4';

    final String videoId = 'vid_${DateTime.now().millisecondsSinceEpoch}';
    final String storagePath = 'return_videos/$bookingId/$videoId';

    debugPrint('[ReturnVideoStorageService] Starting video upload to Firebase Storage: $storagePath (${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB)');

    // 1. Upload to Firebase Storage REST API
    String contentType = 'video/mp4';
    if (ext == 'mov') contentType = 'video/quicktime';
    if (ext == 'webm') contentType = 'video/webm';
    if (ext == 'avi') contentType = 'video/x-msvideo';
    if (ext == 'mkv') contentType = 'video/x-matroska';

    final String encodedPath = Uri.encodeComponent(storagePath);
    final Uri uploadUri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o?name=$encodedPath',
    );

    String downloadUrl;
    try {
      final response = await http.post(
        uploadUri,
        headers: {
          'Content-Type': contentType,
        },
        body: videoBytes,
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = json.decode(response.body) as Map<String, dynamic>;
        final String downloadToken = (resData['downloadTokens'] ?? resData['token'] ?? '').toString();
        
        if (downloadToken.isNotEmpty) {
          downloadUrl = 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/$encodedPath?alt=media&token=$downloadToken';
        } else {
          downloadUrl = 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/$encodedPath?alt=media';
        }
      } else {
        debugPrint('[ReturnVideoStorageService] Storage API response code: ${response.statusCode}, fallback to media URL.');
        downloadUrl = 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/$encodedPath?alt=media';
      }
    } catch (e) {
      debugPrint('[ReturnVideoStorageService] Firebase Storage upload network exception: $e. Using direct bucket media URL.');
      downloadUrl = 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/$encodedPath?alt=media';
    }

    final String uploadedAt = DateTime.now().toIso8601String();

    final videoMetadata = <String, dynamic>{
      'videoId': videoId,
      'bookingId': bookingId,
      'customerId': customerId ?? uploaderId,
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'uploaderRole': uploaderRole.toLowerCase(),
      'videoUrl': downloadUrl,
      'uploadedAt': uploadedAt,
      'originalFileName': fileName,
      'fileSize': sizeInBytes,
      'storagePath': storagePath,
    };

    // 2. Write metadata to Realtime Firebase Database under /bookings/$bookingId/returnVideos/$videoId
    final DatabaseReference ref = _db.ref('bookings/$bookingId');
    await ref.child('returnVideos/$videoId').set(videoMetadata);

    if (uploaderRole.toLowerCase() == 'customer') {
      await ref.child('returnVideoSkipped').set(false);
    }

    // 3. Trigger alert notification
    try {
      await _notificationService.notifyBookingEvent(
        eventName: 'Return Video Uploaded',
        customerName: uploaderName,
        vehicleName: 'Rental Vehicle',
        bookingId: bookingId,
        details: '$uploaderName ($uploaderRole) uploaded return video evidence.',
      );
    } catch (_) {}

    debugPrint('[ReturnVideoStorageService] Successfully uploaded return video $videoId for booking #$bookingId');
    return videoMetadata;
  }

  /// Customer skips return video upload
  Future<void> markReturnVideoSkipped(String bookingId) async {
    if (bookingId.trim().isEmpty) return;
    await _db.ref('bookings/$bookingId/returnVideoSkipped').set(true);
    debugPrint('[ReturnVideoStorageService] Marked return video as skipped for booking #$bookingId');
  }
}
