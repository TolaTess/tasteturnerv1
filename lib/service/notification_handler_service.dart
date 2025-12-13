import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../constants.dart';
import '../helper/utils.dart';
import '../screens/tomorrow_action_items_screen.dart';
import '../screens/daily_summary_screen.dart';
import '../screens/rainbow_tracker_detail_screen.dart';
import 'user_service.dart';

class NotificationHandlerService extends GetxService {
  static NotificationHandlerService get instance {
    return Get.find<
        NotificationHandlerService>(); // Always registered in main.dart
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late UserService _userService;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<UserService>()) {
      _userService = Get.find<UserService>();
    } else {
      debugPrint('⚠️ UserService not registered yet');
      // Will be initialized when needed
    }
  }

  // Handle notification payload and show appropriate screen
  Future<void> handleNotificationPayload(String? payload) async {
    debugPrint(
        '🔔 [NotificationHandlerService] handleNotificationPayload called');
    if (payload == null) {
      debugPrint(
          '⚠️ [NotificationHandlerService] Notification payload is null');
      return;
    }

    debugPrint(
        '📱 [NotificationHandlerService] Received notification payload: $payload');

    try {
      // Parse the payload
      final parsedPayload = _parsePayload(payload);
      if (parsedPayload == null) {
        debugPrint(
            '⚠️ [NotificationHandlerService] Failed to parse notification payload');
        return;
      }

      debugPrint(
          '📱 [NotificationHandlerService] Parsed payload: $parsedPayload');

      final type = parsedPayload['type'] as String?;
      final date = parsedPayload['date'] as String?;
      final hasMealPlan = parsedPayload['hasMealPlan'] as bool?;

      debugPrint('📋 [NotificationHandlerService] Payload details:');
      debugPrint('   Type: $type');
      debugPrint('   Date: $date');
      debugPrint('   HasMealPlan: $hasMealPlan');

      if (type == null) {
        debugPrint(
            '⚠️ [NotificationHandlerService] Notification type is null, returning');
        return;
      }

      // Handle water reminder notifications
      if (type == 'water_reminder') {
        debugPrint('💧 [NotificationHandlerService] Handling water_reminder');
        await _handleWaterReminder();
        return;
      }

      // Handle meal symptom check notifications
      if (type == 'meal_symptom_check') {
        debugPrint(
            '🍽️ [NotificationHandlerService] Handling meal_symptom_check');
        await _handleMealSymptomCheck(parsedPayload);
        return;
      }

      // Handle plant milestone notifications
      if (type == 'plant_milestone') {
        debugPrint('🌱 [NotificationHandlerService] Handling plant_milestone');
        await _handlePlantMilestone(parsedPayload);
        return;
      }

      // For meal plan and evening review, date and hasMealPlan are required
      if (date == null || hasMealPlan == null) {
        debugPrint(
            '⚠️ [NotificationHandlerService] Missing required fields for type $type');
        debugPrint('   Date: $date, HasMealPlan: $hasMealPlan');
        return;
      }

      debugPrint(
          '📅 [NotificationHandlerService] Handling $type with date: $date, hasMealPlan: $hasMealPlan');

      // Get today's summary data
      final todaySummary = await _getTodaySummary();

      // Show the action items screen
      debugPrint('🎯 [NotificationHandlerService] Showing action items screen');
      await _showActionItemsScreen(
        todaySummary: todaySummary,
        tomorrowDate: date,
        hasMealPlan: hasMealPlan,
        notificationType: type,
      );
      debugPrint(
          '✅ [NotificationHandlerService] Action items screen shown successfully');
    } catch (e, stackTrace) {
      debugPrint(
          '❌ [NotificationHandlerService] Error handling notification payload: $e');
      debugPrint('   Stack trace: $stackTrace');
      // Only show snackbar if context is available
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  // Parse notification payload string with better Android compatibility
  Map<String, dynamic>? _parsePayload(String payload) {
    try {
      // Try JSON parsing first (more reliable)
      try {
        final jsonPayload = json.decode(payload);
        return Map<String, dynamic>.from(jsonPayload);
      } catch (jsonError) {
        debugPrint('Error parsing JSON payload: $jsonError');
      }

      // Fallback to manual parsing for backward compatibility
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

  // Get today's summary data
  Future<Map<String, dynamic>> _getTodaySummary() async {
    try {
      // Ensure UserService is initialized
      if (!Get.isRegistered<UserService>()) {
        debugPrint('⚠️ UserService not registered in _getTodaySummary');
        return {};
      }

      // Re-fetch UserService if userId is not available
      if (_userService.userId == null) {
        _userService = Get.find<UserService>();
      }

      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      final userId = _userService.userId;

      if (userId == null || userId.isEmpty) return {};

      final summaryDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summary')
          .doc(todayStr)
          .get();

      if (summaryDoc.exists) {
        return summaryDoc.data() ?? {};
      }
    } catch (e) {
      debugPrint('Error getting today summary: $e');
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }

    return {};
  }

  // Show the action items screen
  Future<void> _showActionItemsScreen({
    required Map<String, dynamic> todaySummary,
    required String tomorrowDate,
    required bool hasMealPlan,
    required String notificationType,
  }) async {
    try {
      debugPrint(
          '🎯 [NotificationHandlerService] _showActionItemsScreen called');
      final context = Get.context;
      if (context == null) {
        debugPrint(
            '⚠️ [NotificationHandlerService] No context available for navigation');
        return;
      }
      debugPrint(
          '✅ [NotificationHandlerService] Navigating to TomorrowActionItemsScreen');
      // Use Get.to to navigate to the action items screen
      await Get.to(() => TomorrowActionItemsScreen(
            todaySummary: todaySummary,
            tomorrowDate: tomorrowDate,
            hasMealPlan: hasMealPlan,
            notificationType: notificationType,
          ));
      debugPrint('✅ [NotificationHandlerService] Navigation completed');
    } catch (e) {
      debugPrint(
          '❌ [NotificationHandlerService] Error showing action items screen: $e');
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  // Method to manually show action items (for testing or direct access)
  Future<void> showTomorrowActionItems(BuildContext context) async {
    try {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);

      // Get today's summary data
      final todaySummary = await _getTodaySummary();

      // Check if tomorrow has meal plan
      final hasMealPlan = await _checkTomorrowMealPlan(tomorrowStr);

      // Show the action items screen
      await _showActionItemsScreen(
        todaySummary: todaySummary,
        tomorrowDate: tomorrowStr,
        hasMealPlan: hasMealPlan,
        notificationType: 'manual',
      );
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  // Check if tomorrow has meal plan
  Future<bool> _checkTomorrowMealPlan(String tomorrowStr) async {
    try {
      // Ensure UserService is initialized
      if (!Get.isRegistered<UserService>()) {
        debugPrint('⚠️ UserService not registered in _checkTomorrowMealPlan');
        return false;
      }

      // Re-fetch UserService if userId is not available
      if (_userService.userId == null) {
        _userService = Get.find<UserService>();
      }

      final userId = _userService.userId;
      if (userId == null || userId.isEmpty) return false;

      final mealPlanDoc = await _firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('date')
          .doc(tomorrowStr)
          .get();

      if (mealPlanDoc.exists) {
        final data = mealPlanDoc.data();
        final mealsList = data?['meals'] as List<dynamic>? ?? [];
        return mealsList.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Error checking tomorrow meal plan: $e');
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }

    return false;
  }

  // Handle water reminder notification
  Future<void> _handleWaterReminder() async {
    try {
      // Navigate to water tracking or show a simple message
      // For now, we'll just show a snackbar
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
          'Water Reminder 💧',
          'Time to track your water intake!',
          context,
          backgroundColor: Colors.blue,
        );
      }

      // You can add navigation to water tracking screen here if you have one
      // Get.to(() => WaterTrackingScreen());
    } catch (e) {
      debugPrint('Error handling water reminder: $e');
    }
  }

  // Handle meal symptom check notification
  Future<void> _handleMealSymptomCheck(Map<String, dynamic> payload) async {
    try {
      final mealId = payload['mealId'] as String?;
      final instanceId = payload['instanceId'] as String?;
      final mealName = payload['mealName'] as String?;
      final mealType = payload['mealType'] as String?;
      final dateStr = payload['date'] as String?;

      debugPrint('🍽️ Handling meal symptom check notification:');
      debugPrint('   mealId: $mealId');
      debugPrint('   instanceId: $instanceId');
      debugPrint('   mealName: $mealName');
      debugPrint('   mealType: $mealType');
      debugPrint('   date: $dateStr');

      if (dateStr == null) {
        debugPrint('Error: date is required for meal symptom check');
        return;
      }

      // Parse the date
      final date = DateTime.tryParse(dateStr);
      if (date == null) {
        debugPrint('Error: invalid date format: $dateStr');
        return;
      }

      // Navigate to daily summary screen with meal context
      final context = Get.context;
      if (context != null) {
        debugPrint('🍽️ Navigating to DailySummaryScreen with meal context');
        try {
          await Get.to(() => DailySummaryScreen(
                date: date,
                mealId: mealId,
                instanceId: instanceId,
                mealName: mealName,
                mealType: mealType,
              ));
          debugPrint('🍽️ Navigation completed');
        } catch (navError) {
          debugPrint('Error during navigation: $navError');
          showTastySnackbar(
            'Error',
            'Failed to open symptom check. Please try again.',
            context,
            backgroundColor: kRed,
          );
        }
      } else {
        debugPrint('Error: No context available for navigation');
      }
    } catch (e) {
      debugPrint('Error handling meal symptom check: $e');
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
          'Error',
          'Failed to open symptom check. Please try again.',
          context,
          backgroundColor: kRed,
        );
      }
    }
  }

  // Handle plant milestone notification
  Future<void> _handlePlantMilestone(Map<String, dynamic> payload) async {
    try {
      final weekStartStr = payload['weekStart'] as String?;
      final level = payload['level'] as int?;
      final levelName = payload['levelName'] as String?;
      final plantCount = payload['plantCount'] as int?;

      if (weekStartStr == null) {
        debugPrint('Error: weekStart is required for plant milestone');
        return;
      }

      // Parse the weekStart date
      final weekStart = DateTime.tryParse(weekStartStr);
      if (weekStart == null) {
        debugPrint('Error: invalid weekStart format: $weekStartStr');
        return;
      }

      // Navigate to Rainbow Tracker detail screen
      final context = Get.context;
      if (context != null) {
        try {
          await Get.to(() => RainbowTrackerDetailScreen(
                weekStart: weekStart,
              ));
          debugPrint(
              '🌱 Navigated to Rainbow Tracker for level $level ($levelName) with $plantCount plants');
        } catch (navError) {
          debugPrint('Error during navigation: $navError');
          showTastySnackbar(
            'Error',
            'Failed to open Rainbow Tracker. Please try again.',
            context,
            backgroundColor: kRed,
          );
        }
      } else {
        debugPrint('Error: No context available for navigation');
      }
    } catch (e) {
      debugPrint('Error handling plant milestone: $e');
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
          'Error',
          'Failed to open Rainbow Tracker. Please try again.',
          context,
          backgroundColor: kRed,
        );
      }
    }
  }
}
