import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  String? _userTimeZone;
  final bool _isInitialized = false;
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

//initialize
  Future<void> initNotification() async {
    if (_isInitialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Get user's timezone
    _userTimeZone = await _getUserTimeZone();

    const initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher_foreground');

    const initSettingiOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingiOS,
    );

    await notificationPlugin.initialize(initSettings);
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
      ),
      iOS: DarwinNotificationDetails(),
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

    await notificationPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
