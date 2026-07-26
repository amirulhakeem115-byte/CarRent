import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'user_role_cache.dart';
import 'user_session.dart';


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
      debugPrint('[DatabaseService] [submitSupportMessage] Delegating to createTicket for subject: $subject');
      await createTicket(subject, message, senderName: name, senderEmail: email);
    } catch (e) {
      debugPrint('Error saving support message to Realtime DB: $e');
      rethrow;
    }
  }

  Future<String> _getCurrentUserRole(String? uid) async {
    if (uid == null) return 'unauthenticated';
    return UserRoleCache.getRole(uid);
  }

  Future<List<Map<String, dynamic>>> getSupportMessages({String? ticketId}) async {
    List<Map<String, dynamic>> messages = [];
    if (ticketId == null || ticketId.isEmpty) return messages;
    final path = 'support_messages/$ticketId';
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final currentRole = await _getCurrentUserRole(currentUid);
    debugPrint(
      '[DatabaseService] [getSupportMessages] Accessing path: $path, Current UID: $currentUid, Role: $currentRole',
    );

    try {
      final snapshot = await _db
          .child('support_messages')
          .child(ticketId)
          .get()
          .timeout(const Duration(seconds: 5));
      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> msg = Map<String, dynamic>.from(value);
            msg['id'] = key.toString();
            messages.add(msg);
          }
        });
      }
      debugPrint(
        '[DatabaseService] [getSupportMessages] Support messages loaded for ticket $ticketId: count=${messages.length}',
      );
    } catch (e) {
      debugPrint(
        '[DatabaseService] [getSupportMessages] Error getting support messages for $path: $e',
      );
      rethrow;
    }
    messages.sort((a, b) {
      final aTime = a['timestamp'] ?? '';
      final bTime = b['timestamp'] ?? '';
      return aTime.compareTo(bTime);
    });
    return messages;
  }

  Future<void> updateSupportMessageStatus(
    String ticketId,
    String status,
  ) async {
    try {
      await updateTicketStatus(ticketId, status);
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

    debugPrint(
      '[DatabaseService] [getTicketsStream] Listening on path: support_tickets (customerId: ${customerId ?? "ALL"})',
    );

    return query.onValue.map((event) {
      List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final ticket = Map<String, dynamic>.from(value);
            ticket['id'] = key.toString();
            list.add(ticket);
          }
        });
      }
      // Sort: latest reply/created date first
      list.sort((a, b) {
        final String aTime = a['lastReplyAt'] ?? a['createdAt'] ?? '';
        final String bTime = b['lastReplyAt'] ?? b['createdAt'] ?? '';
        return bTime.compareTo(aTime);
      });
      debugPrint(
        '[DatabaseService] [getTicketsStream] Firebase read success. Stream update received with ${list.length} tickets.',
      );
      return list;
    });
  }

  Future<void> diagnoseTicketPermission(String ticketId) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final uid = authUser?.uid ?? 'NOT_AUTHENTICATED';
    final path = 'support_messages/$ticketId';

    debugPrint('================= DIAGNOSTIC TRACE START =================');
    debugPrint('STEP 1: Firebase Reference: FirebaseDatabase.instance.ref("$path")');
    debugPrint('STEP 2: Authenticated User (auth.uid): $uid');

    String role = 'NOT_FOUND';
    try {
      final userSnap = await _db.child('users').child(uid).get();
      if (userSnap.exists && userSnap.value is Map) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        role = userData['role']?.toString() ?? 'ROLE_FIELD_MISSING';
      } else {
        role = 'USER_NODE_MISSING';
      }
    } catch (e) {
      role = 'ERROR: $e';
    }
    debugPrint('STEP 3: Read users/$uid/role: "$role"');

    Map<String, dynamic> ticketObj = {};
    String customerIdInDB = 'NOT_FOUND';
    String ticketStatus = 'NOT_FOUND';
    bool ticketExists = false;
    try {
      final ticketSnap = await _db.child('support_tickets').child(ticketId).get();
      if (ticketSnap.exists && ticketSnap.value is Map) {
        ticketExists = true;
        ticketObj = Map<String, dynamic>.from(ticketSnap.value as Map);
        customerIdInDB = ticketObj['customerId']?.toString() ?? 'MISSING_CUSTOMERID_FIELD';
        ticketStatus = ticketObj['status']?.toString() ?? 'MISSING_STATUS_FIELD';
      }
    } catch (e) {
      debugPrint('Error reading ticket object: $e');
    }

    debugPrint('STEP 4: Entire Ticket Object (support_tickets/$ticketId): ${ticketExists ? ticketObj : "TICKET_NODE_DOES_NOT_EXIST"}');
    debugPrint('        customerId: "$customerIdInDB"');
    debugPrint('        status: "$ticketStatus"');

    final bool isOwnerMatch = (customerIdInDB == uid);
    debugPrint('STEP 5: Rule Evaluation: root.child("support_tickets").child("$ticketId").child("customerId").val()');
    debugPrint('        Value: "$customerIdInDB"');
    debugPrint('        Compare (customerId == auth.uid): "$customerIdInDB" == "$uid" ? ${isOwnerMatch ? "TRUE" : "FALSE"}');

    final bool isAdminRole = (role == 'admin' || role == 'Admin');
    debugPrint('STEP 6: Admin Role Check: users/$uid/role = "$role"');
    debugPrint('        Equals "admin"? ${role == "admin"}');
    debugPrint('        Equals "Admin"? ${role == "Admin"}');

    debugPrint('STEP 7: Root Cause Evaluation Summary:');
    debugPrint('        Current auth.uid: $uid');
    debugPrint('        Current role: $role');
    debugPrint('        Current customerId in DB: $customerIdInDB');
    debugPrint('        Current Firebase path: $path');
    debugPrint('        Evaluated Rule: root.child("support_tickets").child("$ticketId").child("customerId").val() == auth.uid');
    if (!ticketExists) {
      debugPrint('        EXACT FAILING VALUE: Ticket node "support_tickets/$ticketId" DOES NOT EXIST in Realtime DB! Rule evaluation returned null.');
    } else if (customerIdInDB != uid && !isAdminRole) {
      debugPrint('        EXACT FAILING VALUE: Ticket customerId ("$customerIdInDB") does not equal auth.uid ("$uid") AND user role ("$role") is not admin/Admin.');
    } else {
      debugPrint('        Evaluation passes locally! If client still receives permission-denied, the cloud-deployed rules on Firebase Console have not been updated.');
    }
    debugPrint('================= DIAGNOSTIC TRACE END ===================');
  }

  Stream<List<Map<String, dynamic>>> getTicketMessagesStream(String ticketId) {
    final path = 'support_messages/$ticketId';
    debugPrint('[DatabaseService] [getTicketMessagesStream] Listening on path: $path');
    diagnoseTicketPermission(ticketId);

    return _db.child('support_messages').child(ticketId).onValue.map((event) {
      final List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final msg = Map<String, dynamic>.from(value);
            msg['id'] = key.toString();
            list.add(msg);
          }
        });
      }
      list.sort((a, b) {
        final String aTime = a['timestamp'] ?? '';
        final String bTime = b['timestamp'] ?? '';
        return aTime.compareTo(bTime);
      });
      debugPrint(
        '[DatabaseService] [getTicketMessagesStream] Listener update for Ticket ID: $ticketId on path: $path. Read success (${list.length} messages).',
      );
      return list;
    });
  }

  Future<void> createTicket(
    String subject,
    String initialMessage, {
    String? senderName,
    String? senderEmail,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final customerId = user?.uid ?? '';

      // Requirement 3 & 4: Validation before saving. Verify customerId is never null or empty.
      if (customerId.trim().isEmpty) {
        debugPrint('[DatabaseService] [createTicket] ERROR: customerId is missing/null! Aborting ticket creation.');
        throw Exception('Support ticket creation failed: User must be authenticated with a valid customer ID.');
      }

      final now = DateTime.now().toIso8601String();
      final name = senderName ?? UserSession().currentUserModel?.fullName ?? user?.displayName ?? user?.email ?? 'Customer';
      final email = senderEmail ?? UserSession().currentUserModel?.email ?? user?.email ?? '';

      final ticketRef = _db.child('support_tickets').push();
      final ticketId = ticketRef.key!;

      debugPrint('[DatabaseService] [createTicket] Path: support_tickets/$ticketId, Customer ID: $customerId, Name: $name, Email: $email');

      // Requirement 1: Every newly created support ticket MUST save customerId, customerName, customerEmail
      await ticketRef.set({
        'customerId': customerId,
        'userId': customerId,
        'customerUid': customerId,
        'customerName': name,
        'customerEmail': email,
        'subject': subject,
        'status': 'Open',
        'createdAt': now,
        'lastReplyAt': now,
      });

      final messageRef = _db.child('support_messages').child(ticketId).push();
      final messageId = messageRef.key!;
      final messagePath = 'support_messages/$ticketId/$messageId';

      await messageRef.set({
        'senderId': customerId,
        'senderName': name,
        'senderRole': 'customer',
        'message': initialMessage,
        'timestamp': now,
      });

      debugPrint(
        '[DatabaseService] [createTicket] Firebase write success! Ticket ID: $ticketId, Message ID: $messageId, Path: $messagePath, Sender ID: $customerId, Role: customer, Text: "$initialMessage"',
      );

      // Send notification to all admins
      try {
        final notificationService = NotificationService();
        await notificationService.notifyAllAdmins(
          title: 'New Support Ticket: $subject',
          message: 'A new ticket has been submitted by $name ($email): "$initialMessage"',
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
    String senderRole, {
    String? senderName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final senderId = user?.uid ?? '';
      final now = DateTime.now().toIso8601String();

      final String name = senderName ??
          (senderRole == 'admin'
              ? (UserSession().currentUserModel?.fullName ?? user?.displayName ?? 'Support Admin')
              : (UserSession().currentUserModel?.fullName ?? user?.displayName ?? user?.email ?? 'Customer'));

      final messageRef = _db.child('support_messages').child(ticketId).push();
      final messageId = messageRef.key!;
      final messagePath = 'support_messages/$ticketId/$messageId';

      await messageRef.set({
        'senderId': senderId,
        'senderName': name,
        'senderRole': senderRole,
        'message': message,
        'timestamp': now,
      });

      // Update lastReplyAt and status on the ticket
      await _db.child('support_tickets').child(ticketId).update({
        'lastReplyAt': now,
        'status': senderRole == 'customer' ? 'Open' : 'In Progress',
      });

      debugPrint(
        '[DatabaseService] [sendTicketMessage] Firebase write success! Ticket ID: $ticketId, Message ID: $messageId, Path: $messagePath, Sender ID: $senderId, Sender Role: $senderRole, Sender Name: $name, Text: "$message"',
      );

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
              message: '$name (Admin) replied: "$message"',
              type: 'support',
            );
          } else if (senderRole == 'customer') {
            await notificationService.notifyAllAdmins(
              title: 'New Support Reply: $subject',
              message: '$name (Customer) replied to ticket: "$message"',
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
          .timeout(const Duration(seconds: 15));
      debugPrint(
        '[DatabaseService] Raw snapshot value for $path: ${snapshot.value}',
      );
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final user = UserModel.fromMap(uid, data);
        UserSession().forceSetUser(user);
        if (user.email.trim().toLowerCase() == 'admin@gmail.com' &&
            user.role != 'admin') {
          await updateUser(uid, {'role': 'admin'});
          final updatedAdmin = UserModel(
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
          UserSession().forceSetUser(updatedAdmin);
          return updatedAdmin;
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

      final notificationService = NotificationService();
      String customerName = 'Customer';
      try {
        final uSnap = await _db
            .child('users')
            .child(uid)
            .child('fullName')
            .get();
        if (uSnap.exists && uSnap.value != null) {
          customerName = uSnap.value.toString();
        }
      } catch (_) {}

      if (data.containsKey('licenseImage') &&
          data['licenseStatus'] == 'pending') {
        await notificationService.notifyCustomerEvent(
          eventName: 'Customer Uploaded License',
          customerName: customerName,
          customerUid: uid,
          details: 'uploaded driving license for verification.',
          priority: 'high',
          icon: '👤',
          color: '0xFF14B8A6',
        );
      } else {
        await notificationService.notifyCustomerEvent(
          eventName: 'Customer Profile Updated',
          customerName: customerName,
          customerUid: uid,
          details: 'updated profile details.',
          priority: 'normal',
          icon: '👤',
          color: '0xFF3B82F6',
        );
      }
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      String customerName = 'Customer';
      try {
        final uSnap = await _db.child('users').child(uid).child('fullName').get();
        if (uSnap.exists && uSnap.value != null) {
          customerName = uSnap.value.toString();
        }
      } catch (_) {}

      await _db.child('users').child(uid).remove().timeout(const Duration(seconds: 5));

      final notificationService = NotificationService();
      await notificationService.notifyCustomerEvent(
        eventName: 'Customer Account Deleted',
        customerName: customerName,
        customerUid: uid,
        details: 'account was deleted.',
        priority: 'high',
        icon: '👤',
        color: '0xFFEF4444',
      );
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  List<UserModel>? _cachedUsers;
  DateTime? _usersCacheTime;
  static const Duration _cacheTtl = Duration(seconds: 30);

  void invalidateUsersCache() {
    _cachedUsers = null;
    _usersCacheTime = null;
  }

  Future<List<UserModel>> getUsers({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedUsers != null &&
        _usersCacheTime != null &&
        DateTime.now().difference(_usersCacheTime!) < _cacheTtl) {
      debugPrint('[DatabaseService] Returning warm cached users (${_cachedUsers!.length} items)');
      return _cachedUsers!;
    }

    List<UserModel> users = [];

    try {
      final snapshot = await _db
          .child('users')
          .get()
          .timeout(const Duration(seconds: 15));
      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          users.add(
            UserModel.fromMap(key.toString(), value as Map<dynamic, dynamic>),
          );
        });
      }
      _cachedUsers = users;
      _usersCacheTime = DateTime.now();
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

        final customerName = data['fullName'] ?? data['name'] ?? 'Customer';
        await notificationService.notifyAllAdmins(
          title: isApproved ? 'Customer $docName Approved' : 'Customer $docName Rejected',
          message: isApproved
              ? 'Customer $customerName\'s $docName has been approved.'
              : 'Customer $customerName\'s $docName was rejected. Reason: $reason',
          type: 'customer',
          icon: '👤',
          color: isApproved ? '0xFF10B981' : '0xFFEF4444',
          relatedId: uid,
          actionRoute: 'Customers',
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
