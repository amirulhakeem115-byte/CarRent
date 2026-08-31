import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'user_role_cache.dart';
import '../screens/auth/admin/dashboard_screen.dart';
import '../screens/auth/customer/customer_responsive_shell.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Handling background message: ${message.messageId}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  FirebaseMessaging? _fcmInstance;
  FirebaseMessaging get _fcm => _fcmInstance ??= FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  bool _initialized = false;
  final Set<String> _processedMessageIds = {};
  StreamSubscription<DatabaseEvent>? _realtimeNotifSubscription;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    debugPrint('[FCMService] Initializing FCM & Local Notifications...');

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions
    await _requestPermissions();

    // Setup Local Notifications for Native Platforms
    if (!kIsWeb) {
      await _setupLocalNotifications();
    }

    // Foreground Presentation Options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Setup Listeners
    _setupMessageListeners();
    _setupRealtimeNotificationListener();

    // Check if launched from terminated state via notification click
    _checkInitialMessage();

    // Save token if user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await syncUserFCMToken(currentUser.uid);
    }

    // Listen to Auth State changes to manage FCM tokens
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        syncUserFCMToken(user.uid);
        _setupRealtimeNotificationListener();
      }
    });
  }

  void _setupRealtimeNotificationListener() {
    _realtimeNotifSubscription?.cancel();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final notifRef = FirebaseDatabase.instance.ref().child('notifications');
    _realtimeNotifSubscription = notifRef.limitToLast(5).onChildAdded.listen((event) async {
      if (event.snapshot.value == null) return;
      try {
        final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final String targetUserId = (data['userId'] ?? '').toString();
        final String createdAtStr = (data['createdAt'] ?? '').toString();
        final DateTime? createdAt = DateTime.tryParse(createdAtStr);

        if (createdAt != null && DateTime.now().difference(createdAt).inSeconds < 15) {
          final currentRole = await UserRoleCache.getRole(currentUser.uid);
          final bool isCurrentTarget = currentUser.uid == targetUserId ||
              (targetUserId == 'admin' && (currentRole == 'admin' || currentRole == 'super_admin'));
          if (isCurrentTarget) {
            _showForegroundNotificationFromParams(
              title: data['title']?.toString() ?? 'CarRent Alert',
              body: data['message']?.toString() ?? '',
              actionRoute: data['actionRoute']?.toString() ?? 'Dashboard',
              relatedId: data['relatedId']?.toString() ?? '',
            );
          }
        }
      } catch (e) {
        debugPrint('[FCMService] Error in realtime notification listener: $e');
      }
    });
  }

  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        '[FCMService] User granted permission status: ${settings.authorizationStatus}',
      );

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('[FCMService] Error requesting notification permissions: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          debugPrint(
            '[FCMService] Local notification tapped payload: ${response.payload}',
          );
          final parts = response.payload!.split('|');
          final route = parts[0];
          final relatedId = parts.length > 1 ? parts[1] : '';
          handleDeepLink({'actionRoute': route, 'relatedId': relatedId});
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important system alerts.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _setupMessageListeners() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCMService] Received Foreground Message: ${message.notification?.title}');
      if (message.messageId != null) {
        if (_processedMessageIds.contains(message.messageId)) return;
        _processedMessageIds.add(message.messageId!);
        if (_processedMessageIds.length > 100) {
          _processedMessageIds.remove(_processedMessageIds.first);
        }
      }

      _showForegroundNotification(message);
    });

    // Background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCMService] App opened from notification click: ${message.data}');
      handleDeepLink(message.data);
    });
  }

  Future<void> _checkInitialMessage() async {
    try {
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCMService] Initial message found: ${initialMessage.data}');
        Future.delayed(const Duration(milliseconds: 800), () {
          handleDeepLink(initialMessage.data);
        });
      }
    } catch (e) {
      debugPrint('[FCMService] Error checking initial message: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? 'CarRent Alert';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final route = message.data['actionRoute'] ?? 'Dashboard';
    final relatedId = message.data['relatedId'] ?? '';

    await _showForegroundNotificationFromParams(
      title: title,
      body: body,
      actionRoute: route,
      relatedId: relatedId,
    );
  }

  Future<void> _showForegroundNotificationFromParams({
    required String title,
    required String body,
    required String actionRoute,
    required String relatedId,
  }) async {
    if (kIsWeb) {
      debugPrint('[FCMService Web Foreground] $title: $body');
      return;
    }

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'Important notifications for CarRent system.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotifications.show(
        id,
        title,
        body,
        platformDetails,
        payload: '$actionRoute|$relatedId',
      );
    } catch (e) {
      debugPrint('[FCMService] Error displaying foreground banner: $e');
    }
  }

  String sanitizeTokenKey(String token) {
    return token
        .replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll('\$', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_');
  }

  Future<void> cleanUpStaleTokens(String userId, String currentToken) async {
    try {
      final ref = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(userId)
          .child('fcmTokens');
      final snapshot = await ref.get().timeout(const Duration(seconds: 5));
      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> tokensMap =
            snapshot.value as Map<dynamic, dynamic>;
        final currentSanitized = sanitizeTokenKey(currentToken);
        final now = DateTime.now();

        Map<String, dynamic> updates = {};
        tokensMap.forEach((key, val) {
          if (val is Map) {
            final t = val['token'] as String?;
            final updatedAtStr = val['updatedAt'] as String?;
            final updatedAt =
                updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null;

            final bool isStale =
                updatedAt != null && now.difference(updatedAt).inDays > 60;
            final bool isDuplicateKey =
                t == currentToken && key.toString() != currentSanitized;

            if (isStale || isDuplicateKey) {
              updates[key.toString()] = null;
            }
          }
        });

        if (updates.isNotEmpty) {
          await ref.update(updates);
          debugPrint(
            '[FCMService] Cleaned up ${updates.length} stale/duplicate FCM tokens for user $userId',
          );
        }
      }
    } catch (e) {
      debugPrint('[FCMService] Token cleanup notice: $e');
    }
  }

  Future<void> syncUserFCMToken(String userId) async {
    try {
      String? token;
      if (kIsWeb) {
        token = await _fcm.getToken();
      } else {
        token = await _fcm.getToken();
      }

      if (token != null && token.isNotEmpty) {
        debugPrint('[FCMService] Synced FCM Token for user $userId');
        final sanitizedToken = sanitizeTokenKey(token);
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(userId)
            .child('fcmTokens')
            .child(sanitizedToken)
            .set({
          'token': token,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // Non-blocking cleanup of stale/duplicate tokens
        cleanUpStaleTokens(userId, token).catchError((e) {
          debugPrint('[FCMService] Error cleaning tokens: $e');
        });
      }

      // If user is admin, subscribe to admin topic
      final role = await UserRoleCache.getRole(userId);
      final roleLower = role.toLowerCase();
      if ((roleLower == 'admin' || roleLower == 'super_admin') && !kIsWeb) {
        await _fcm.subscribeToTopic('admin');
        debugPrint('[FCMService] Subscribed admin user to topic: admin');
      }

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) async {
        final sToken = sanitizeTokenKey(newToken);
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(userId)
            .child('fcmTokens')
            .child(sToken)
            .set({
          'token': newToken,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      });
    } catch (e) {
      debugPrint('[FCMService] Error syncing FCM token: $e');
    }
  }

  Future<void> sendPushNotification({
    required String targetUserId,
    required String title,
    required String message,
    required String type,
    String actionRoute = 'Dashboard',
    String relatedId = '',
  }) async {
    try {
      final List<String> targetTokens = [];
      if (targetUserId == 'admin') {
        final usersSnap = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .get()
            .timeout(const Duration(seconds: 5));
        if (usersSnap.exists && usersSnap.value is Map) {
          final Map<dynamic, dynamic> users =
              usersSnap.value as Map<dynamic, dynamic>;
          for (var entry in users.entries) {
            final userData = entry.value as Map<dynamic, dynamic>;
            final role = (userData['role'] ?? '').toString().toLowerCase();
            final email = (userData['email'] ?? '').toString().toLowerCase();
            final bool isAdmin = role == 'admin' ||
                role == 'super_admin' ||
                email == 'admin@gmail.com';

            if (isAdmin && userData['fcmTokens'] is Map) {
              final Map<dynamic, dynamic> tokens =
                  userData['fcmTokens'] as Map<dynamic, dynamic>;
              tokens.forEach((_, tVal) {
                if (tVal is Map && tVal['token'] is String) {
                  targetTokens.add(tVal['token'] as String);
                }
              });
            }
          }
        }
      } else {
        final tokenSnap = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(targetUserId)
            .child('fcmTokens')
            .get()
            .timeout(const Duration(seconds: 5));
        if (tokenSnap.exists && tokenSnap.value is Map) {
          final Map<dynamic, dynamic> tokens =
              tokenSnap.value as Map<dynamic, dynamic>;
          tokens.forEach((_, tVal) {
            if (tVal is Map && tVal['token'] is String) {
              targetTokens.add(tVal['token'] as String);
            }
          });
        }
      }

      // Dispatch HTTP POST requests to FCM API endpoint for each target token & topic (Mobile platforms only; Web uses Realtime Database listener)
      if (kIsWeb) {
        debugPrint(
          '[FCMService Web] Direct HTTP FCM POST skipped on web (CORS protection). Realtime database listener delivers notifications.',
        );
      } else {
        final List<String> recipients = List.from(targetTokens);
        if (targetUserId == 'admin') {
          recipients.add('/topics/admin');
        }

        for (final recipient in recipients) {
          try {
            final bodyMap = {
              'to': recipient,
              'priority': 'high',
              'notification': {
                'title': title,
                'body': message,
                'sound': 'default',
                'android_channel_id': 'high_importance_channel',
              },
              'data': {
                'title': title,
                'body': message,
                'type': type,
                'actionRoute': actionRoute,
                'relatedId': relatedId,
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            };

            final response = await http
                .post(
                  Uri.parse('https://fcm.googleapis.com/fcm/send'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization':
                        'key=AIzaSyBWCi7fvcfuZIEWeZfqOSVFvQncgXzf0kc',
                  },
                  body: jsonEncode(bodyMap),
                )
                .timeout(const Duration(seconds: 5));

            debugPrint(
              '[FCM Push Request] Sent to "$recipient", HTTP Status: ${response.statusCode}',
            );
          } catch (e) {
            debugPrint('[FCM Push Request Error] Failed for $recipient: $e');
          }
        }
      }

      // Dispatch local notification banner if active user is target recipient
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final currentRole = await UserRoleCache.getRole(currentUser.uid);
        final bool isCurrentTarget = currentUser.uid == targetUserId ||
            (targetUserId == 'admin' && (currentRole == 'admin' || currentRole == 'super_admin'));
        if (isCurrentTarget) {
          await _showForegroundNotificationFromParams(
            title: title,
            body: message,
            actionRoute: actionRoute,
            relatedId: relatedId,
          );
        }
      }
    } catch (e) {
      debugPrint('[FCMService] Error dispatching push notification payload: $e');
    }
  }

  void handleDeepLink(Map<String, dynamic> data) async {
    final actionRoute = data['actionRoute']?.toString() ?? 'Dashboard';
    final relatedId = data['relatedId']?.toString() ?? '';

    debugPrint('[FCMService DeepLink] Route: $actionRoute, RelatedId: $relatedId');

    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[FCMService DeepLink] Navigator context not ready.');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final role = await UserRoleCache.getRole(currentUser.uid);

    if (role == 'admin') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const AdminDashboardScreen(),
        ),
      );
    } else {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const CustomerResponsiveShell(),
        ),
      );
    }
  }
}
