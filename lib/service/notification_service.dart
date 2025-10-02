import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'notification_handler_service.dart';
import 'package:flutter/material.dart' show debugPrint;

class NotificationService {
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  String? _userTimeZone;
  bool _isInitialized = false;
  static const String _unreadNotificationKey = 'has_shown_unread_notification';

  bool get isInitialized => _isInitialized;
  String? get userTimeZone => _userTimeZone;

  // Getter for hasShownUnreadNotification
  Future<bool> get hasShownUnreadNotification async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_unreadNotificationKey) ?? false;
  }

  // Setter for hasShownUnreadNotification
  Future<void> setHasShownUnreadNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unreadNotificationKey, value);
  }

  // Reset unread notification state
  Future<void> resetUnreadNotificationState() async {
    await setHasShownUnreadNotification(false);
  }

  /// Convert payload to JSON-safe format by handling Firestore Timestamps and other non-serializable objects
  Map<String, dynamic> _convertPayloadToJsonSafe(Map<String, dynamic> payload) {
    final jsonSafePayload = <String, dynamic>{};

    for (final entry in payload.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) {
        jsonSafePayload[key] = null;
      } else if (value is DateTime) {
        jsonSafePayload[key] = value.toIso8601String();
      } else if (value is Map<String, dynamic>) {
        jsonSafePayload[key] = _convertPayloadToJsonSafe(value);
      } else if (value is List) {
        jsonSafePayload[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _convertPayloadToJsonSafe(item);
          } else if (item is DateTime) {
            return item.toIso8601String();
          } else {
            return item;
          }
        }).toList();
      } else if (value is String ||
          value is int ||
          value is double ||
          value is bool) {
        jsonSafePayload[key] = value;
      } else {
        // For any other type, convert to string to ensure JSON safety
        jsonSafePayload[key] = value.toString();
      }
    }

    return jsonSafePayload;
  }

  //initialize
  Future<void> initNotification(
      {Function(String?)? onNotificationTapped}) async {
    if (_isInitialized) return;

    try {
      // Initialize timezone data safely
      tz.initializeTimeZones();

      // Get user's timezone with error handling
      _userTimeZone = await _getUserTimeZone();
    } catch (e) {
      debugPrint('Error initializing timezone data: $e');
      // Fallback to local timezone
      _userTimeZone = 'UTC';
    }

    const initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettingiOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingiOS,
    );

    await notificationPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (onNotificationTapped != null) {
          onNotificationTapped(response.payload);
        }

        // The notification payload will be handled by the callback
        // The notification handler service will process it when the app is ready
      },
    );

    _isInitialized = true;
  }

  // Get user's timezone
  Future<String> _getUserTimeZone() async {
    if (kIsWeb) {
      // For web, we'll use the browser's timezone
      return DateTime.now().timeZoneName;
    }

    // For mobile platforms, we'll use the local timezone
    return tz.local.name;
  }

  //notifications detail set up
  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Notifications',
        channelDescription: 'Daily Notification Channel',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        autoCancel: false,
        ongoing: false,
        channelShowBadge: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  //show notification

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    return notificationPlugin.show(
      id,
      title,
      body,
      notificationDetails(),
    );
  }

  // Schedule daily reminder at specific time
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? timeZoneName,
    Map<String, dynamic>? payload,
  }) async {
    if (Platform.isAndroid) {
      final androidPlugin =
          notificationPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final hasPermission =
          await androidPlugin?.areNotificationsEnabled() ?? false;

      if (!hasPermission) {
        // Request notification permissions
        final granted = await notificationPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();

        if (granted != true) {
          return; // Exit if notification permissions not granted
        }
      }
    }
    // Use provided timezone or fall back to user's timezone
    final targetTimeZone = timeZoneName ?? _userTimeZone ?? tz.local.name;

    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Convert the scheduled date to the specified timezone
    final location = tz.getLocation(targetTimeZone);
    final scheduledTime = tz.TZDateTime.from(scheduledDate, location);

    try {
      // Calculate delay from now to scheduled time
      final delay = scheduledTime.difference(tz.TZDateTime.now(tz.local));

      // Use smart scheduling approach
      if (Platform.isAndroid && delay.inMinutes <= 60) {
        // For Android with delays ≤ 1 hour, ALWAYS use Timer-based approach for reliability

        Timer(delay, () async {
          try {
            // For Timer-based notifications with payload, we need to handle navigation manually
            if (payload != null) {
              // Use the notification handler service to process the payload
              try {
                final handler = Get.find<NotificationHandlerService>();
                await handler.handleNotificationPayload(
                    json.encode(_convertPayloadToJsonSafe(payload)));
              } catch (e) {
                debugPrint('Error processing timer notification payload: $e');
              }
            }

            await showNotification(
              title: title,
              body: body,
            );
          } catch (e) {
            debugPrint('Error sending timer-based notification: $e');
          }
        });

        return;
      } else {
        // Use standard notification scheduling for longer delays or iOS

        await notificationPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledTime,
          notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload != null
              ? json.encode(_convertPayloadToJsonSafe(payload))
              : null,
        );
      }
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      rethrow;
    }
  }

  // Schedule multiple daily reminders
  Future<void> scheduleMultipleDailyReminders({
    required List<DailyReminder> reminders,
    String? timeZoneName,
  }) async {
    for (var reminder in reminders) {
      await scheduleDailyReminder(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        hour: reminder.hour,
        minute: reminder.minute,
        timeZoneName: timeZoneName,
      );
    }
  }

  // Cancel a scheduled notification
  Future<void> cancelScheduledNotification(int id) async {
    await notificationPlugin.cancel(id);
  }

  // Cancel all scheduled notifications
  Future<void> cancelAllScheduledNotifications() async {
    await notificationPlugin.cancelAll();
  }

  // Smart notification scheduling using the most reliable method for all platforms
  Future<void> scheduleSmartNotification({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    Map<String, dynamic>? payload,
  }) async {
    // Use alarmClock for all delays - it's the most reliable on Android 14+
    await scheduleDelayedNotification(
      id: id,
      title: title,
      body: body,
      delay: delay,
      payload: payload,
    );
  }

  // Schedule delayed notification with platform-optimized approach
  Future<void> scheduleDelayedNotification({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    Map<String, dynamic>? payload,
  }) async {
    if (Platform.isAndroid) {
      final androidPlugin =
          notificationPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final hasPermission =
          await androidPlugin?.areNotificationsEnabled() ?? false;

      if (!hasPermission) {
        final granted = await androidPlugin?.requestNotificationsPermission();
        if (granted != true) {
          return;
        }
      }
    }

    try {
      final scheduledTime = tz.TZDateTime.now(tz.local).add(delay);

      // Use alarmClock for Android 14+ compatibility, works for all delays
      await notificationPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload != null
            ? json.encode(_convertPayloadToJsonSafe(payload))
            : null,
      );
    } catch (e) {
      debugPrint('Error scheduling delayed notification: $e');
      rethrow;
    }
  }

  // Parse notification payload and return structured data
  Map<String, dynamic>? parseNotificationPayload(String? payload) {
    if (payload == null) return null;

    try {
      // Remove the curly braces and split by comma
      final cleanPayload = payload.replaceAll('{', '').replaceAll('}', '');
      final pairs = cleanPayload.split(',');

      final Map<String, dynamic> result = {};
      for (final pair in pairs) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim();
          final value = keyValue[1].trim();

          // Parse the value based on its content
          if (value == 'true') {
            result[key] = true;
          } else if (value == 'false') {
            result[key] = false;
          } else if (value.startsWith('"') && value.endsWith('"')) {
            result[key] = value.substring(1, value.length - 1);
          } else {
            // Try to parse as number
            final numValue = double.tryParse(value);
            result[key] = numValue ?? value;
          }
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
      return null;
    }
  }

  // Schedule weekly reminder at specific weekday and time
  Future<void> scheduleWeeklyReminder({
    required int id,
    required String title,
    required String body,
    required int weekday, // Monday=1, ..., Sunday=7
    required int hour,
    required int minute,
    String? timeZoneName,
  }) async {
    if (Platform.isAndroid) {
      final androidPlugin =
          notificationPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final hasPermission =
          await androidPlugin?.areNotificationsEnabled() ?? false;

      if (!hasPermission) {
        // Request notification permissions
        final granted = await notificationPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();

        if (granted != true) {
          return; // Exit if notification permissions not granted
        }
      }

      // For exact alarms, we need to direct users to system settings
      await notificationPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    }
    // Use provided timezone or fall back to user's timezone
    final targetTimeZone = timeZoneName ?? _userTimeZone ?? tz.local.name;

    final now = DateTime.now();
    // Find the next occurrence of the selected weekday
    int daysUntil = (weekday - now.weekday + 7) % 7;
    final nextDay = now.add(Duration(days: daysUntil));
    final scheduledDate = DateTime(
      nextDay.year,
      nextDay.month,
      nextDay.day,
      hour,
      minute,
    );

    final location = tz.getLocation(targetTimeZone);
    final scheduledTime = tz.TZDateTime.from(scheduledDate, location);

    await notificationPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}

// Helper class for multiple daily reminders
class DailyReminder {
  final int id;
  final String title;
  final String body;
  final int hour;
  final int minute;

  DailyReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
  });
}
