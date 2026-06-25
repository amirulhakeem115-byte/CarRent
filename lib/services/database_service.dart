import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class DatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> submitSupportMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
    String? userId,
  }) async {
    try {
      final ref = _db.child('support_messages').push();
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      await ref.set({
        'userId': currentUid ?? userId ?? '',
        'name': name,
        'email': email,
        'subject': subject,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'Pending',
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error saving support message to Realtime DB: $e');
      rethrow;
    }
  }

  Future<String> _getCurrentUserRole(String? uid) async {
    if (uid == null) return 'unauthenticated';
    try {
      final snap = await _db.child('users').child(uid).child('role').get().timeout(const Duration(seconds: 3));
      if (snap.exists) return snap.value.toString();
    } catch (_) {}
    return 'unknown';
  }

  Future<List<Map<String, dynamic>>> getSupportMessages() async {
    List<Map<String, dynamic>> messages = [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final currentRole = await _getCurrentUserRole(currentUid);
    debugPrint('[DatabaseService] [getSupportMessages] Accessing path: support_messages');
    debugPrint('[DatabaseService] [getSupportMessages] Current UID: $currentUid, Current Role: $currentRole');

    try {
      final snapshot = await _db.child('support_messages').get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final Map<String, dynamic> msg = Map<String, dynamic>.from(value as Map);
          msg['id'] = key.toString();
          messages.add(msg);
        });
      }
      debugPrint('[DatabaseService] [getSupportMessages] Support messages count loaded: ${messages.length}');
    } catch (e) {
      debugPrint('[DatabaseService] [getSupportMessages] Error getting support messages: $e');
      rethrow;
    }
    messages.sort((a, b) {
      final aTime = a['timestamp'] ?? '';
      final bTime = b['timestamp'] ?? '';
      return bTime.compareTo(aTime);
    });
    return messages;
  }

  Future<void> updateSupportMessageStatus(String messageId, String status) async {
    try {
      await _db.child('support_messages').child(messageId).update({
        'status': status,
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error updating support message status: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getTicketsStream({String? customerId}) {
    return _db.child('support_tickets').onValue.map((event) {
      List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final ticket = Map<String, dynamic>.from(value as Map);
          ticket['id'] = key.toString();
          list.add(ticket);
        });
      }
      // Sort: latest reply/created date first
      list.sort((a, b) {
        final String aTime = a['lastReplyAt'] ?? a['createdAt'] ?? '';
        final String bTime = b['lastReplyAt'] ?? b['createdAt'] ?? '';
        return bTime.compareTo(aTime);
      });
      if (customerId != null) {
        list = list.where((ticket) => ticket['customerId'] == customerId).toList();
      }
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> getTicketMessagesStream(String ticketId) {
    return _db.child('support_messages').child(ticketId).onValue.map((event) {
      final List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final msg = Map<String, dynamic>.from(value as Map);
          msg['id'] = key.toString();
          list.add(msg);
        });
      }
      list.sort((a, b) {
        final String aTime = a['timestamp'] ?? '';
        final String bTime = b['timestamp'] ?? '';
        return aTime.compareTo(bTime);
      });
      return list;
    });
  }

  Future<void> createTicket(String subject, String initialMessage) async {
    try {
      final customerId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now().toIso8601String();
      
      final ticketRef = _db.child('support_tickets').push();
      final ticketId = ticketRef.key!;
      
      await ticketRef.set({
        'customerId': customerId,
        'subject': subject,
        'status': 'Open',
        'createdAt': now,
        'lastReplyAt': now,
      });

      final messageRef = _db.child('support_messages').child(ticketId).push();
      await messageRef.set({
        'senderId': customerId,
        'senderRole': 'customer',
        'message': initialMessage,
        'timestamp': now,
      });
    } catch (e) {
      debugPrint('Error creating support ticket: $e');
      rethrow;
    }
  }

  Future<void> sendTicketMessage(String ticketId, String message, String senderRole) async {
    try {
      final senderId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now().toIso8601String();
      
      final messageRef = _db.child('support_messages').child(ticketId).push();
      await messageRef.set({
        'senderId': senderId,
        'senderRole': senderRole,
        'message': message,
        'timestamp': now,
      });

      // Update lastReplyAt and status on the ticket
      await _db.child('support_tickets').child(ticketId).update({
        'lastReplyAt': now,
        'status': senderRole == 'customer' ? 'Open' : 'Pending',
      });
    } catch (e) {
      debugPrint('Error sending support ticket message: $e');
      rethrow;
    }
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    try {
      await _db.child('support_tickets').child(ticketId).update({
        'status': status,
      });
    } catch (e) {
      debugPrint('Error updating support ticket status: $e');
      rethrow;
    }
  }


  Future<void> saveUser({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
    required String role,
    String licenseNumber = '',
  }) async {
    debugPrint('SAVE USER STARTED');

    try {
      String finalRole = role;
      if (email.trim().toLowerCase() == 'admin@gmail.com') {
        finalRole = 'admin';
      }
      await _db.child('users').child(uid).set({
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': finalRole,
        'isVerified': false,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
        'profileImage': '',
        'licenseImage': '',
        'licenseNumber': licenseNumber,
        'licenseStatus': 'unprovided',
        'licenseRejectionReason': '',
      }).timeout(const Duration(seconds: 5));

      debugPrint('USER SAVED SUCCESSFULLY');
    } catch (e, stack) {
      debugPrint('DATABASE ERROR');
      debugPrint(e.toString());
      debugPrint(stack.toString());
    }
  }

  Future<void> saveGoogleUser({
    required String uid,
    required String name,
    required String email,
    required String profilePhoto,
  }) async {
    debugPrint('SAVE GOOGLE USER STARTED');
    try {
      await _db.child('users').child(uid).set({
        'uid': uid,
        'name': name,
        'fullName': name,
        'email': email,
        'profilePhoto': profilePhoto,
        'profileImage': profilePhoto,
        'role': 'customer',
        'createdAt': DateTime.now().toIso8601String(),
        'phone': '',
        'isVerified': false,
        'isActive': true,
        'licenseImage': '',
        'licenseNumber': '',
        'licenseStatus': 'unprovided',
        'licenseRejectionReason': '',
        'address': '4521 Oakwood Avenue, Suite 300, Los Angeles, CA 90024',
        'licenseClass': 'Class DA',
        'licenseExpiry': '12 / 2028',
      }).timeout(const Duration(seconds: 5));
      debugPrint('GOOGLE USER SAVED SUCCESSFULLY');
    } catch (e, stack) {
      debugPrint('DATABASE ERROR saving Google user: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final path = 'users/$uid';
      debugPrint('[DatabaseService] Reading Firebase path: $path');
      final snapshot = await _db.child('users').child(uid).get().timeout(const Duration(seconds: 5));
      debugPrint('[DatabaseService] Raw snapshot value for $path: ${snapshot.value}');
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final user = UserModel.fromMap(uid, data);
        if (user.email.trim().toLowerCase() == 'admin@gmail.com' && user.role != 'admin') {
          await updateUser(uid, {'role': 'admin'});
          return UserModel(
            id: user.id,
            fullName: user.fullName,
            email: user.email,
            phone: user.phone,
            role: 'admin',
            profileImage: user.profileImage,
            createdAt: user.createdAt,
            licenseNumber: user.licenseNumber,
            licenseImage: user.licenseImage,
            isVerified: user.isVerified,
            address: user.address,
            licenseClass: user.licenseClass,
            licenseExpiry: user.licenseExpiry,
          );
        }
        return user;
      } else {
        debugPrint('[DatabaseService] No snapshot exists for path: $path');
      }
    } catch (e) {
      debugPrint('Error getting user: $e');
    }
    return null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _db.child('users').child(uid).update(data).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> getUsers() async {
    List<UserModel> users = [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final currentRole = await _getCurrentUserRole(currentUid);
    debugPrint('[DatabaseService] [getUsers] Accessing path: users');
    debugPrint('[DatabaseService] [getUsers] Current UID: $currentUid, Current Role: $currentRole');

    try {
      final snapshot = await _db.child('users').get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          users.add(UserModel.fromMap(key.toString(), value as Map<dynamic, dynamic>));
        });
      }
      debugPrint('[DatabaseService] [getUsers] Users count loaded: ${users.length}');
    } catch (e) {
      debugPrint('[DatabaseService] [getUsers] Error listing users: $e');
      rethrow;
    }
    return users;
  }

  Future<void> verifyLicense(String uid, bool isVerified, {String reason = ''}) async {
    try {
      await _db.child('users').child(uid).update({
        'isVerified': isVerified,
        'licenseStatus': isVerified ? 'approved' : 'rejected',
        'licenseRejectionReason': isVerified ? '' : reason,
      }).timeout(const Duration(seconds: 5));
      
      // Seed a record in license_verifications/
      await _db.child('license_verifications').child(uid).set({
        'userId': uid,
        'status': isVerified ? 'approved' : 'rejected',
        'rejectionReason': isVerified ? '' : reason,
        'updatedAt': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 5));

      // Trigger automatic notification creation
      try {
        final notificationService = NotificationService();
        await notificationService.createNotification(
          userId: uid,
          title: isVerified ? 'License Approved' : 'License Rejected',
          message: isVerified
              ? 'Your driving license has been approved. You are now authorized to book rentals!'
              : 'Your driving license was rejected. Reason: $reason. Please re-upload a clear card photo.',
          type: 'license',
        );
      } catch (notifErr) {
        debugPrint('Failed to send automatic license verification notification: $notifErr');
      }
    } catch (e) {
      debugPrint('Error verifying license: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getQrPaymentSettings() async {
    try {
      final snapshot = await _db.child('qr_payment_settings').get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
    } catch (e) {
      debugPrint('Error getting QR settings: $e');
    }
    return null;
  }

  Future<void> updateQrPaymentSettings(Map<String, dynamic> settings) async {
    try {
      await _db.child('qr_payment_settings').set(settings).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error updating QR settings: $e');
      rethrow;
    }
  }

  Future<String> uploadSettingsImage(Uint8List bytes, String filename) async {
    try {
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('Error converting settings image to base64: $e');
      rethrow;
    }
  }
}
