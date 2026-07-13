import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'user_role_cache.dart';

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
      await ref
          .set({
            'userId': currentUid ?? userId ?? '',
            'name': name,
            'email': email,
            'subject': subject,
            'message': message,
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'Pending',
          })
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error saving support message to Realtime DB: $e');
      rethrow;
    }
  }

  Future<String> _getCurrentUserRole(String? uid) async {
    if (uid == null) return 'unauthenticated';
    return UserRoleCache.getRole(uid);
  }

  Future<List<Map<String, dynamic>>> getSupportMessages() async {
    List<Map<String, dynamic>> messages = [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final currentRole = await _getCurrentUserRole(currentUid);
    debugPrint(
      '[DatabaseService] [getSupportMessages] Accessing path: support_messages',
    );
    debugPrint(
      '[DatabaseService] [getSupportMessages] Current UID: $currentUid, Current Role: $currentRole',
    );

    try {
      final snapshot = await _db
          .child('support_messages')
          .get()
          .timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final Map<String, dynamic> msg = Map<String, dynamic>.from(
            value as Map,
          );
          msg['id'] = key.toString();
          messages.add(msg);
        });
      }
      debugPrint(
        '[DatabaseService] [getSupportMessages] Support messages count loaded: ${messages.length}',
      );
    } catch (e) {
      debugPrint(
        '[DatabaseService] [getSupportMessages] Error getting support messages: $e',
      );
      rethrow;
    }
    messages.sort((a, b) {
      final aTime = a['timestamp'] ?? '';
      final bTime = b['timestamp'] ?? '';
      return bTime.compareTo(aTime);
    });
    return messages;
  }

  Future<void> updateSupportMessageStatus(
    String messageId,
    String status,
  ) async {
    try {
      await _db
          .child('support_messages')
          .child(messageId)
          .update({'status': status})
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error updating support message status: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getTicketsStream({String? customerId}) {
    Query query = _db.child('support_tickets');
    if (customerId != null && customerId.isNotEmpty) {
      query = query.orderByChild('customerId').equalTo(customerId);
    }

    return query.onValue.map((event) {
      List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
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
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> getTicketMessagesStream(String ticketId) {
    return _db.child('support_messages').child(ticketId).onValue.map((event) {
      final List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
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

      // Send notification to all admins
      try {
        final notificationService = NotificationService();
        await notificationService.notifyAllAdmins(
          title: 'New Support Ticket: $subject',
          message: 'A new ticket has been submitted: "$initialMessage"',
          type: 'support',
        );
      } catch (e) {
        debugPrint('Failed to send new ticket notification: $e');
      }
    } catch (e) {
      debugPrint('Error creating support ticket: $e');
      rethrow;
    }
  }

  Future<void> sendTicketMessage(
    String ticketId,
    String message,
    String senderRole,
  ) async {
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
        'status': senderRole == 'customer' ? 'Open' : 'In Progress',
      });

      // Send reply notifications
      try {
        final ticketSnap = await _db
            .child('support_tickets')
            .child(ticketId)
            .get()
            .timeout(const Duration(seconds: 5));
        if (ticketSnap.exists) {
          final ticketData = Map<String, dynamic>.from(ticketSnap.value as Map);
          final customerId = ticketData['customerId'] ?? '';
          final subject = ticketData['subject'] ?? 'Support Ticket';

          final notificationService = NotificationService();
          if (senderRole == 'admin') {
            await notificationService.createNotification(
              userId: customerId,
              title: 'Support Reply Received: $subject',
              message: 'An administrator replied to your ticket: "$message"',
              type: 'support',
            );
          } else if (senderRole == 'customer') {
            await notificationService.notifyAllAdmins(
              title: 'New Support Reply: $subject',
              message: 'Customer has replied to ticket: "$message"',
              type: 'support',
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to send support reply notification: $e');
      }
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
      await _db
          .child('users')
          .child(uid)
          .set({
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
          })
          .timeout(const Duration(seconds: 5));

      if (finalRole == 'customer') {
        final notificationService = NotificationService();
        await notificationService.notifyAllAdmins(
          title: 'New Customer Registered',
          message: '$fullName has created a new account.',
          type: 'customer',
          icon: '👤',
          color: '0xFF14B8A6',
          relatedId: uid,
          actionRoute: 'Customers',
        );
      }

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
      await _db
          .child('users')
          .child(uid)
          .set({
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
          })
          .timeout(const Duration(seconds: 5));

      final notificationService = NotificationService();
      await notificationService.notifyAllAdmins(
        title: 'New Customer Registered',
        message: '$name has registered via Google.',
        type: 'customer',
        icon: '👤',
        color: '0xFF14B8A6',
        relatedId: uid,
        actionRoute: 'Customers',
      );

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
      final snapshot = await _db
          .child('users')
          .child(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      debugPrint(
        '[DatabaseService] Raw snapshot value for $path: ${snapshot.value}',
      );
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final user = UserModel.fromMap(uid, data);
        UserRoleCache.set(uid, user.role);
        if (user.email.trim().toLowerCase() == 'admin@gmail.com' &&
            user.role != 'admin') {
          await updateUser(uid, {'role': 'admin'});
          UserRoleCache.set(uid, 'admin');
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
      await _db
          .child('users')
          .child(uid)
          .update(data)
          .timeout(const Duration(seconds: 5));
      if (data.containsKey('licenseImage') &&
          data['licenseStatus'] == 'pending') {
        final notificationService = NotificationService();
        String customerName = 'Customer';
        try {
          final uSnap = await _db
              .child('users')
              .child(uid)
              .child('fullName')
              .get();
          if (uSnap.exists) {
            customerName = uSnap.value.toString();
          }
        } catch (_) {}

        await notificationService.notifyAllAdmins(
          title: 'Customer Uploaded Driving License',
          message:
              '$customerName uploaded their driving license for verification.',
          type: 'customer',
          icon: '👤',
          color: '0xFF14B8A6',
          relatedId: uid,
          actionRoute: 'Customers',
        );
      }
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
    debugPrint(
      '[DatabaseService] [getUsers] Current UID: $currentUid, Current Role: $currentRole',
    );

    try {
      final snapshot = await _db
          .child('users')
          .get()
          .timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          users.add(
            UserModel.fromMap(key.toString(), value as Map<dynamic, dynamic>),
          );
        });
      }
      debugPrint(
        '[DatabaseService] [getUsers] Users count loaded: ${users.length}',
      );
    } catch (e) {
      debugPrint('[DatabaseService] [getUsers] Error listing users: $e');
      rethrow;
    }
    return users;
  }

  Future<void> verifyDocument(
    String uid,
    String docType,
    bool isApproved, {
    String reason = '',
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final reviewer = FirebaseAuth.instance.currentUser?.email ?? 'Admin';

      final userSnap = await _db
          .child('users')
          .child(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (!userSnap.exists) return;
      final data = userSnap.value as Map<dynamic, dynamic>;

      String newLicenseStatus = data['licenseStatus'] ?? 'unprovided';
      String newIdStatus = data['idStatus'] ?? 'unprovided';

      final Map<String, dynamic> updates = {};

      if (docType == 'license') {
        newLicenseStatus = isApproved ? 'approved' : 'rejected';
        updates['licenseStatus'] = newLicenseStatus;
        updates['licenseRejectionReason'] = isApproved ? '' : reason;
        updates['licenseReviewedBy'] = reviewer;
        updates['licenseReviewedDate'] = now;
      } else if (docType == 'id') {
        newIdStatus = isApproved ? 'approved' : 'rejected';
        updates['idStatus'] = newIdStatus;
        updates['idRejectionReason'] = isApproved ? '' : reason;
        updates['idReviewedBy'] = reviewer;
        updates['idReviewedDate'] = now;
      }

      final finalIsVerified =
          (newLicenseStatus == 'approved' && newIdStatus == 'approved');
      updates['isVerified'] = finalIsVerified;

      await _db
          .child('users')
          .child(uid)
          .update(updates)
          .timeout(const Duration(seconds: 5));

      await _db
          .child('verifications')
          .child(uid)
          .child(docType)
          .set({
            'userId': uid,
            'docType': docType,
            'status': isApproved ? 'approved' : 'rejected',
            'rejectionReason': isApproved ? '' : reason,
            'reviewedBy': reviewer,
            'updatedAt': now,
          })
          .timeout(const Duration(seconds: 5));

      try {
        final notificationService = NotificationService();
        final docName = docType == 'license'
            ? 'Driving License'
            : 'Identity Document';
        await notificationService.createNotification(
          userId: uid,
          title: isApproved ? '$docName Approved' : '$docName Rejected',
          message: isApproved
              ? 'Your $docName has been approved.'
              : 'Your $docName was rejected. Reason: $reason. Please re-upload.',
          type: 'customer',
          icon: '👤',
          color: isApproved ? '0xFF10B981' : '0xFFEF4444',
          relatedId: uid,
          actionRoute: 'Dashboard',
        );
      } catch (notifErr) {
        debugPrint(
          'Failed to send automatic verification notification: $notifErr',
        );
      }
    } catch (e) {
      debugPrint('Error verifying document: $e');
      rethrow;
    }
  }

  Future<void> verifyLicense(
    String uid,
    bool isVerified, {
    String reason = '',
  }) async {
    await verifyDocument(uid, 'license', isVerified, reason: reason);
  }

  Future<Map<String, dynamic>?> getQrPaymentSettings() async {
    try {
      final snapshot = await _db
          .child('qr_payment_settings')
          .get()
          .timeout(const Duration(seconds: 5));
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
      await _db
          .child('qr_payment_settings')
          .set(settings)
          .timeout(const Duration(seconds: 5));
      final notificationService = NotificationService();
      await notificationService.notifyAllAdmins(
        title: 'QR Payment Settings Changed',
        message: 'The system QR payment settings have been modified.',
        type: 'system',
        icon: '⚙️',
        color: '0xFF64748B',
        relatedId: 'qr_settings',
        actionRoute: 'QR Payment Settings',
      );
    } catch (e) {
      debugPrint('Error updating QR settings: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getContactSettings() async {
    try {
      final snapshot = await _db
          .child('company_settings')
          .get()
          .timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
    } catch (e) {
      debugPrint('Error getting company settings: $e');
    }
    return null;
  }

  Stream<Map<String, dynamic>> getContactSettingsStream() {
    return _db.child('company_settings').onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return {};
    });
  }

  Future<void> updateContactSettings(Map<String, dynamic> settings) async {
    try {
      await _db
          .child('company_settings')
          .set(settings)
          .timeout(const Duration(seconds: 5));
      final notificationService = NotificationService();
      await notificationService.notifyAllAdmins(
        title: 'Company Settings Updated',
        message: 'The company configurations have been modified.',
        type: 'system',
        icon: '⚙️',
        color: '0xFF64748B',
        relatedId: 'company_settings',
        actionRoute: 'Company Settings',
      );
    } catch (e) {
      debugPrint('Error updating company settings: $e');
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

  Stream<List<UserModel>> getUsersStream() {
    return _db.child('users').onValue.map((event) {
      List<UserModel> users = [];
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          users.add(
            UserModel.fromMap(key.toString(), value as Map<dynamic, dynamic>),
          );
        });
      }
      return users;
    });
  }
}
