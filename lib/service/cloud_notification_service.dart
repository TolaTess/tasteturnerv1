import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudNotificationService extends GetxService {
  static CloudNotificationService get instance =>
      Get.find<CloudNotificationService>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _fcmToken;
  bool _isInitialized = false;

  // Notification preferences
  final RxMap<String, dynamic> notificationPreferences =
      <String, dynamic>{}.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await initializeCloudNotifications();
  }

  /// Initialize Cloud Functions notifications
  Future<void> initializeCloudNotifications() async {
    if (_isInitialized) return;

    try {
      // Request permission for notifications
      await _requestNotificationPermission();

      // Get FCM token
      await _getFCMToken();

      // Set up message handlers
      _setupMessageHandlers();

      // Load user notification preferences
      await _loadNotificationPreferences();

      _isInitialized = true;
      debugPrint('Cloud Notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing cloud notifications: $e');
    }
  }

  /// Request notification permission
  Future<void> _requestNotificationPermission() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
          'Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('User denied notification permission');
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Get FCM token and update it in Cloud Functions
  Future<void> _getFCMToken() async {
    try {
      // For iOS, try multiple approaches to get the token
      if (Platform.isIOS) {
        await _getFCMTokenForIOS();
      } else {
        _fcmToken = await _messaging.getToken();
        if (_fcmToken != null) {
          debugPrint('FCM Token: $_fcmToken');
          await _updateFCMTokenInCloud();
        }
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

  /// Get FCM token specifically for iOS with multiple retry strategies
  Future<void> _getFCMTokenForIOS() async {
    // Strategy 1: Wait for APNS token first
    await _waitForAPNSToken();

    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        debugPrint('FCM Token (iOS): $_fcmToken');
        await _updateFCMTokenInCloud();
        return;
      }
    } catch (e) {
      debugPrint('FCM token attempt 1 failed: $e');
    }

    // Strategy 2: Wait a bit more and try again
    await Future.delayed(const Duration(seconds: 2));
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        debugPrint('FCM Token (iOS retry): $_fcmToken');
        await _updateFCMTokenInCloud();
        return;
      }
    } catch (e) {
      debugPrint('FCM token attempt 2 failed: $e');
    }

    // Strategy 3: Schedule a delayed retry
    _scheduleFCMTokenRetry();
  }

  /// Schedule a retry for FCM token on iOS
  void _scheduleFCMTokenRetry() {
    if (!Platform.isIOS) return;

    // Multiple retry attempts with increasing delays
    _retryFCMToken(1);
  }

  /// Retry FCM token generation with attempt number
  void _retryFCMToken(int attempt) {
    if (!Platform.isIOS || attempt > 5) return; // Max 5 attempts

    final delay = Duration(seconds: attempt * 2); // 2, 4, 6, 8, 10 seconds

    Future.delayed(delay, () async {
      try {
        debugPrint('Retrying FCM token generation (attempt $attempt)...');
        _fcmToken = await _messaging.getToken();

        if (_fcmToken != null) {
          debugPrint('FCM Token (retry $attempt): $_fcmToken');
          await _updateFCMTokenInCloud();
        } else {
          debugPrint('FCM Token still null after retry $attempt');
          _retryFCMToken(attempt + 1);
        }
      } catch (e) {
        debugPrint('Error in FCM token retry $attempt: $e');
        _retryFCMToken(attempt + 1);
      }
    });
  }

  /// Wait for APNS token on iOS
  Future<void> _waitForAPNSToken() async {
    if (!Platform.isIOS) return;

    try {
      // Wait for APNS token with longer timeout and more attempts
      int attempts = 0;
      const maxAttempts = 20; // Increased from 10
      const delay = Duration(milliseconds: 1000); // Increased from 500ms

      debugPrint('Waiting for APNS token...');

      while (attempts < maxAttempts) {
        try {
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) {
            debugPrint('APNS Token received: $apnsToken');
            return;
          }
        } catch (e) {
          debugPrint('APNS token check attempt ${attempts + 1} failed: $e');
        }

        await Future.delayed(delay);
        attempts++;
      }

      debugPrint(
          'APNS token timeout after ${maxAttempts} attempts - proceeding anyway');
    } catch (e) {
      debugPrint('Error waiting for APNS token: $e');
    }
  }

  /// Update FCM token in Cloud Functions
  Future<void> _updateFCMTokenInCloud() async {
    if (_fcmToken == null || _auth.currentUser == null) return;

    try {
      final callable = functions.httpsCallable('updateFCMToken');
      await callable.call({
        'fcmToken': _fcmToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });

      debugPrint('FCM token updated in Cloud Functions');
    } catch (e) {
      debugPrint('Error updating FCM token in Cloud Functions: $e');
    }
  }

  /// Set up message handlers for different notification types
  void _setupMessageHandlers() {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.notification?.title}');
      _handleForegroundMessage(message);
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
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    // You can show a local notification or update UI here
    debugPrint('Handling foreground message: ${message.data}');

    // For now, just log the message
    // In the future, you could show a snackbar or update UI
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
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
      // Use GetX navigation to go to meal planning
      Get.toNamed('/meal-planning');
    } catch (e) {
      debugPrint('Error navigating to meal planning: $e');
    }
  }

  /// Navigate to water tracking screen
  void _navigateToWaterTracking(Map<String, dynamic> data) {
    try {
      // Use GetX navigation to go to water tracking
      Get.toNamed('/water-tracking');
    } catch (e) {
      debugPrint('Error navigating to water tracking: $e');
    }
  }

  /// Navigate to evening review screen
  void _navigateToEveningReview(Map<String, dynamic> data) {
    try {
      // Use GetX navigation to go to evening review
      Get.toNamed('/evening-review');
    } catch (e) {
      debugPrint('Error navigating to evening review: $e');
    }
  }

  /// Load user notification preferences
  Future<void> _loadNotificationPreferences() async {
    if (_auth.currentUser == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final prefs = data['notificationPreferences'] as Map<String, dynamic>?;

        if (prefs != null) {
          notificationPreferences.value = prefs;
        } else {
          // Set default preferences
          await _setDefaultNotificationPreferences();
        }
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
      await _setDefaultNotificationPreferences();
    }
  }

  /// Set default notification preferences
  Future<void> _setDefaultNotificationPreferences() async {
    final defaultPrefs = {
      'mealPlanReminder': {
        'enabled': true,
        'time': {'hour': 21, 'minute': 0},
        'timezone': 'UTC'
      },
      'waterReminder': {
        'enabled': true,
        'time': {'hour': 11, 'minute': 0},
        'timezone': 'UTC'
      },
      'eveningReview': {
        'enabled': true,
        'time': {'hour': 21, 'minute': 0},
        'timezone': 'UTC'
      }
    };

    notificationPreferences.value = defaultPrefs;
    await _updateNotificationPreferencesInCloud(defaultPrefs);
  }

  /// Update notification preferences in Cloud Functions
  Future<void> _updateNotificationPreferencesInCloud(
      Map<String, dynamic> preferences) async {
    if (_auth.currentUser == null) return;

    try {
      final callable = functions.httpsCallable('updateNotificationPreferences');
      await callable.call({
        'preferences': preferences,
      });

      debugPrint('Notification preferences updated in Cloud Functions');
    } catch (e) {
      debugPrint(
          'Error updating notification preferences in Cloud Functions: $e');
    }
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences(
      Map<String, dynamic> preferences) async {
    notificationPreferences.value = preferences;
    await _updateNotificationPreferencesInCloud(preferences);
  }

  /// Get notification history
  Future<List<Map<String, dynamic>>> getNotificationHistory({
    int limit = 20,
    String? lastNotificationId,
  }) async {
    if (_auth.currentUser == null) return [];

    try {
      final callable = functions.httpsCallable('getNotificationHistory');
      final result = await callable.call({
        'limit': limit,
        'lastNotificationId': lastNotificationId,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
      }

      return [];
    } catch (e) {
      debugPrint('Error getting notification history: $e');
      return [];
    }
  }

  /// Check if notifications are enabled
  bool areNotificationsEnabled() {
    return _fcmToken != null && _isInitialized;
  }

  /// Get current FCM token
  String? getFCMToken() {
    return _fcmToken;
  }

  /// Manually trigger FCM token generation (for testing)
  Future<void> forceFCMTokenGeneration() async {
    try {
      debugPrint('Force generating FCM token...');

      if (Platform.isIOS) {
        // For iOS, try multiple approaches
        await _getFCMTokenForIOS();
      } else {
        // For Android, get token directly
        _fcmToken = await _messaging.getToken();
        if (_fcmToken != null) {
          debugPrint('FCM Token (forced): $_fcmToken');
          await _updateFCMTokenInCloud();
        }
      }
    } catch (e) {
      debugPrint('Error in force FCM token generation: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.notification?.title}');

  // You can perform background tasks here
  // Note: This function runs in a separate isolate
}
