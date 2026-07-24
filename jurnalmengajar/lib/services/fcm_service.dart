import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';

// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'jurnal_mengajar_notifications', // id
    'Notifikasi Jurnal Mengajar', // title
    description: 'Saluran notifikasi untuk pembaruan jurnal dan informasi penting.',
    importance: Importance.high,
  );

  /// Initialize FCM, Local Notifications, and Event Listeners
  Future<void> initialize({AuthProvider? authProvider, Function(String route)? onNavigate}) async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Set background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request Notification Permissions
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('User FCM Notification Permission status: ${settings.authorizationStatus}');
    }

    // 3. Initialize Local Notifications for Foreground Display
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data = jsonDecode(response.payload!);
              if (data is Map && data.containsKey('route') && onNavigate != null) {
                onNavigate(data['route']);
              }
            } catch (e) {
              if (kDebugMode) print('Error parsing notification payload: $e');
            }
          }
        },
      );
    } catch (e) {
      if (kDebugMode) print('Error initializing local notifications: $e');
    }

    // Create Android Notification Channel
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    } catch (e) {
      if (kDebugMode) print('Error creating notification channel: $e');
    }

    // 4. Set Foreground Presentation Options for iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Received Foreground FCM Message: ${message.notification?.title}');
      }
      _showForegroundNotification(message);
    });

    // 6. Handle Background Notification Click (App opened from background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('FCM Message Opened App: ${message.data}');
      }
      final route = message.data['route'];
      if (route != null && onNavigate != null) {
        onNavigate(route);
      }
    });

    // 7. Handle Terminated App Notification Click
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      final route = initialMessage.data['route'];
      if (route != null && onNavigate != null) {
        onNavigate(route);
      }
    }

    // 8. Register Device Token & Listen to Token Refresh
    await syncToken(authProvider);

    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('================================================');
      debugPrint('🔥 [FCM TOKEN REFRESHED]: $newToken');
      debugPrint('================================================');
      if (authProvider != null && authProvider.isAuthenticated) {
        await authProvider.updateFcmToken(newToken);
      }
    });
  }

  /// Synchronize FCM Device Token with Supabase user profile
  Future<void> syncToken(AuthProvider? authProvider) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('================================================');
        debugPrint('🔥 [FCM REGISTRATION TOKEN FOR TESTING]:');
        debugPrint(token);
        debugPrint('================================================');

        final userId = authProvider?.currentUser?.id ?? Supabase.instance.client.auth.currentUser?.id;
        if (userId != null && userId.isNotEmpty) {
          await Supabase.instance.client
              .from('users')
              .update({'fcm_token': token})
              .eq('id', userId);
          debugPrint('✅ FCM Token successfully synced to Supabase users table for user: $userId');
        }
      }
    } catch (e) {
      debugPrint('Error fetching or syncing FCM Token: $e');
    }
  }

  /// Show Local Heads-Up Notification when app is in Foreground
  void _showForegroundNotification(RemoteMessage message) {
    try {
      final notification = message.notification;

      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: '@mipmap/launcher_icon',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error displaying foreground notification: $e');
      }
    }
  }
}
