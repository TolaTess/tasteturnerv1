import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import '../widgets/bottom_nav.dart';
import '../screens/add_food_screen.dart';

/// Hybrid notification service that uses:
/// - FCM (Cloud Functions) for Android
/// - Local notifications for iOS
class HybridNotificationService extends GetxService {
  static HybridNotificationService get instance =>
      Get.find<HybridNotificationService>();

  // Lazy getter for FirebaseMessaging to prevent iOS permission request on service instantiation
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
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
    // Do not auto-initialize - only initialize when user explicitly enables notifications
    // This prevents permission requests without user context
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
      // Only request permission if user has explicitly enabled notifications
      // Permission request should be handled by UI layer with proper context
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

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification tapped: ${message.notification?.title}');
      _handleNotificationTap(message);
    });

    // Handle notification tap when app is terminated
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App opened from terminated state via notification');
        _handleNotificationTap(message);
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Handle notification tap (Android only)
  void _handleNotificationTap(RemoteMessage message) {
    if (!Platform.isAndroid) return;

    final data = message.data;
    final type = data['type'];

    debugPrint('Handling notification tap: $type');

    switch (type) {
      case 'meal_plan_reminder':
        _navigateToMealPlanning(data);
        break;
      case 'water_reminder':
        _navigateToWaterTracking(data);
        break;
      case 'evening_review':
        _navigateToEveningReview(data);
        break;
      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  /// Navigate to meal planning screen
  void _navigateToMealPlanning(Map<String, dynamic> data) {
    try {
      // Navigate to meal design screen (tab 4 in bottom nav)
      Get.to(() => const BottomNavSec(selectedIndex: 4));
    } catch (e) {
      debugPrint('Error navigating to meal planning: $e');
    }
  }

  /// Navigate to water tracking screen
  void _navigateToWaterTracking(Map<String, dynamic> data) {
    try {
      // Navigate to home screen where water tracking is available
      Get.to(() => AddFoodScreen(date: DateTime.now()));
    } catch (e) {
      debugPrint('Error navigating to water tracking: $e');
    }
  }

  /// Navigate to evening review screen
  void _navigateToEveningReview(Map<String, dynamic> data) {
    try {
      // Navigate to home screen where evening review is available
      Get.to(() => AddFoodScreen(date: DateTime.now()));
    } catch (e) {
      debugPrint('Error navigating to evening review: $e');
    }
  }

  /// Set up iOS notification preferences
  Future<void> _setupIOSNotificationPreferences() async {
    if (!Platform.isIOS || _localNotificationService == null) return;

    try {
      // Set up meal plan reminder (9 PM daily)
      await _localNotificationService!.scheduleDailyReminder(
        id: 1,
        title: 'Mise en Place Reminder',
        body: 'Chef, we haven\'t planned tomorrow\'s menu yet. Shall I prep some suggestions?',
        hour: 21, // 9 PM
        minute: 0,
        payload: {'type': 'meal_plan_reminder'},
      );

      // Set up water reminder (11 AM daily)
      await _localNotificationService!.scheduleDailyReminder(
        id: 2,
        title: 'Hydration Check',
        body: 'Chef, let\'s keep the station hydrated. Remember to track your water intake.',
        hour: 11, // 11 AM
        minute: 0,
        payload: {'type': 'water_reminder'},
      );

      // Set up evening review (9 PM daily)
      await _localNotificationService!.scheduleDailyReminder(
        id: 3,
        title: 'Post-Service Review',
        body:
            'Service complete, Chef. Let\'s review today and prep for tomorrow.',
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
        // For iOS: Initialize service if not already initialized
        if (_localNotificationService == null) {
          _localNotificationService = NotificationService();
        }
        // Update local notification service
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

        final data = Map<String, dynamic>.from(result.data as Map);
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
