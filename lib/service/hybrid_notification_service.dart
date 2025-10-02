import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

/// Hybrid notification service that uses:
/// - FCM (Cloud Functions) for Android
/// - Local notifications for iOS
class HybridNotificationService extends GetxService {
  static HybridNotificationService get instance =>
      Get.find<HybridNotificationService>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _fcmToken;
  bool _isInitialized = false;
  NotificationService? _localNotificationService;

  // Notification preferences
  final RxMap<String, dynamic> notificationPreferences =
      <String, dynamic>{}.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await initializeHybridNotifications();
  }

  /// Initialize hybrid notifications
  Future<void> initializeHybridNotifications() async {
    if (_isInitialized) return;

    try {
      if (Platform.isAndroid) {
        // For Android: Use FCM (Cloud Functions)
        await _initializeAndroidNotifications();
      } else if (Platform.isIOS) {
        // For iOS: Use local notifications
        await _initializeIOSNotifications();
      }

      _isInitialized = true;
      debugPrint('Hybrid Notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing hybrid notifications: $e');
    }
  }

  /// Initialize Android notifications (FCM)
  Future<void> _initializeAndroidNotifications() async {
    try {
      // Request permission for notifications
      await _requestNotificationPermission();

      // Get FCM token
      await _getFCMToken();

      // Set up message handlers
      _setupMessageHandlers();

      // Load user notification preferences
      await _loadNotificationPreferences();

      debugPrint('Android FCM notifications initialized');
    } catch (e) {
      debugPrint('Error initializing Android notifications: $e');
    }
  }

  /// Initialize iOS notifications (Local)
  Future<void> _initializeIOSNotifications() async {
    try {
      // Initialize local notification service
      _localNotificationService = NotificationService();

      // Set up iOS notification preferences
      await _setupIOSNotificationPreferences();

      debugPrint('iOS local notifications initialized');
    } catch (e) {
      debugPrint('Error initializing iOS notifications: $e');
    }
  }

  /// Request notification permission
  Future<void> _requestNotificationPermission() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
          'Notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Get FCM token (Android only)
  Future<void> _getFCMToken() async {
    if (!Platform.isAndroid) return;

    try {
      _fcmToken = await _messaging.getToken();

      if (_fcmToken != null) {
        debugPrint('FCM Token: $_fcmToken');
        await _updateFCMTokenInCloud();
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        await _updateFCMTokenInCloud();
      });
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Update FCM token in Cloud Functions (Android only)
  Future<void> _updateFCMTokenInCloud() async {
    if (_fcmToken == null || _auth.currentUser == null || !Platform.isAndroid)
      return;

    try {
      final callable = _functions.httpsCallable('updateFCMToken');
      await callable.call({
        'fcmToken': _fcmToken,
        'platform': 'android',
      });

      debugPrint('FCM token updated in Cloud Functions');
    } catch (e) {
      debugPrint('Error updating FCM token in Cloud Functions: $e');
    }
  }

  /// Set up message handlers (Android only)
  void _setupMessageHandlers() {
    if (!Platform.isAndroid) return;

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.notification?.title}');
      // Handle foreground message if needed
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Set up iOS notification preferences
  Future<void> _setupIOSNotificationPreferences() async {
    if (!Platform.isIOS || _localNotificationService == null) return;

    try {
      // Set up meal plan reminder (9 PM daily)
      await _localNotificationService!.scheduleDailyReminder(
        id: 1,
        title: 'Meal Plan Reminder',
        body: 'Don\'t forget to plan your meals for tomorrow!',
        hour: 21, // 9 PM
        minute: 0,
        payload: {'type': 'meal_plan_reminder'},
      );

      // Set up water reminder (11 AM daily)
      await _localNotificationService!.scheduleDailyReminder(
        id: 2,
        title: 'Water Reminder',
        body: 'Stay hydrated! Remember to drink water throughout the day.',
        hour: 11, // 11 AM
        minute: 0,
        payload: {'type': 'water_reminder'},
      );

      // Set up evening review (9 PM daily)
      await _localNotificationService!.scheduleDailyReminder(
        id: 3,
        title: 'Evening Review',
        body:
            'How did your day go? Review your progress and plan for tomorrow.',
        hour: 21, // 9 PM
        minute: 15,
        payload: {'type': 'evening_review'},
      );

      debugPrint('iOS notification preferences set up with proper scheduling');
    } catch (e) {
      debugPrint('Error setting up iOS notification preferences: $e');
    }
  }

  /// Load notification preferences (Android only)
  Future<void> _loadNotificationPreferences() async {
    if (!Platform.isAndroid || _auth.currentUser == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['notificationPreferences'] != null) {
          notificationPreferences.value =
              Map<String, dynamic>.from(data['notificationPreferences']);
        }
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences(
      Map<String, dynamic> preferences) async {
    if (_auth.currentUser == null) return;

    try {
      if (Platform.isAndroid) {
        // For Android: Update in Cloud Functions
        final callable =
            _functions.httpsCallable('updateNotificationPreferences');
        await callable.call({
          'preferences': preferences,
        });
        debugPrint(
            'Android notification preferences updated in Cloud Functions');
      } else if (Platform.isIOS) {
        // For iOS: Update local notification service
        await _setupIOSNotificationPreferences();
        debugPrint('iOS notification preferences updated locally');
      }

      notificationPreferences.value = preferences;
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
    }
  }

  /// Send test notification
  Future<void> sendTestNotification() async {
    try {
      if (Platform.isAndroid) {
        // For Android: Use Cloud Functions
        final callable = _functions.httpsCallable('sendTestNotification');
        await callable.call();
        debugPrint('Test notification sent via Cloud Functions (Android)');
      } else if (Platform.isIOS) {
        // For iOS: Use local notifications
        if (_localNotificationService != null) {
          await _localNotificationService!.scheduleDelayedNotification(
            id: 999,
            title: 'Test Notification 🧪',
            body: 'This is a test notification from iOS local notifications!',
            delay: const Duration(seconds: 2),
            payload: {'type': 'test_notification'},
          );
          debugPrint('Test notification sent via local notifications (iOS)');
        }
      }
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      rethrow;
    }
  }

  /// Get notification history
  Future<List<Map<String, dynamic>>> getNotificationHistory({
    int limit = 20,
    String? lastNotificationId,
  }) async {
    if (_auth.currentUser == null) return [];

    try {
      if (Platform.isAndroid) {
        // For Android: Get from Cloud Functions
        final callable = _functions.httpsCallable('getNotificationHistory');
        final result = await callable.call({
          'limit': limit,
          'lastNotificationId': lastNotificationId,
        });

        final data = result.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
        }
      } else if (Platform.isIOS) {
        // For iOS: Return empty list (local notifications don't have history)
        return [];
      }

      return [];
    } catch (e) {
      debugPrint('Error getting notification history: $e');
      return [];
    }
  }

  /// Check if notifications are enabled
  bool areNotificationsEnabled() {
    if (Platform.isAndroid) {
      return _fcmToken != null && _isInitialized;
    } else if (Platform.isIOS) {
      return _localNotificationService != null && _isInitialized;
    }
    return false;
  }

  /// Get current FCM token (Android only)
  String? getFCMToken() {
    return Platform.isAndroid ? _fcmToken : null;
  }

  /// Get platform info
  String get platform => Platform.isAndroid ? 'Android (FCM)' : 'iOS (Local)';

  /// Force FCM token generation (Android only)
  Future<void> forceFCMTokenGeneration() async {
    if (!Platform.isAndroid) {
      debugPrint('FCM token generation is only available on Android');
      return;
    }

    try {
      debugPrint('Force generating FCM token...');
      await _getFCMToken();
    } catch (e) {
      debugPrint('Error in force FCM token generation: $e');
    }
  }
}

/// Background message handler (Android only)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.notification?.title}');
}
