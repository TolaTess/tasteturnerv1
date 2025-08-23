import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../screens/tomorrow_action_items_screen.dart';
import 'user_service.dart';

class NotificationHandlerService extends GetxService {
  static NotificationHandlerService get instance =>
      Get.find<NotificationHandlerService>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = Get.find<UserService>();

  // Handle notification payload and show appropriate screen
  Future<void> handleNotificationPayload(String? payload) async {
    if (payload == null) return;

    try {
      // Parse the payload
      final parsedPayload = _parsePayload(payload);
      if (parsedPayload == null) return;

      final type = parsedPayload['type'] as String?;
      final date = parsedPayload['date'] as String?;
      final hasMealPlan = parsedPayload['hasMealPlan'] as bool?;

      if (type == null || date == null || hasMealPlan == null) return;

      // Get today's summary data
      final todaySummary = await _getTodaySummary();

      // Show the action items screen
      await _showActionItemsScreen(
        todaySummary: todaySummary,
        tomorrowDate: date,
        hasMealPlan: hasMealPlan,
        notificationType: type,
      );
    } catch (e) {
      print('Error handling notification payload: $e');
    }
  }

  // Parse notification payload string with better Android compatibility
  Map<String, dynamic>? _parsePayload(String payload) {
    try {
      print('Raw payload received: $payload');

      // Try JSON parsing first (more reliable)
      try {
        final jsonPayload = json.decode(payload);
        print('JSON parsing successful: $jsonPayload');
        return Map<String, dynamic>.from(jsonPayload);
      } catch (jsonError) {
        print('JSON parsing failed, trying manual parsing: $jsonError');
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

      print('Manual parsing result: $result');
      return result;
    } catch (e) {
      print('Error parsing notification payload: $e');
      print('Payload that caused error: $payload');
      return null;
    }
  }

  // Get today's summary data
  Future<Map<String, dynamic>> _getTodaySummary() async {
    try {
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      final userId = _userService.userId;

      if (userId == null) return {};

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
      print('Error loading today\'s summary: $e');
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
      // Use Get.to to navigate to the action items screen
      await Get.to(() => TomorrowActionItemsScreen(
            todaySummary: todaySummary,
            tomorrowDate: tomorrowDate,
            hasMealPlan: hasMealPlan,
            notificationType: notificationType,
          ));
    } catch (e) {
      print('Error showing action items screen: $e');
    }
  }

  // Method to manually show action items (for testing or direct access)
  Future<void> showTomorrowActionItems(BuildContext context) async {
    try {
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
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
      print('Error showing action items: $e');
    }
  }

  // Check if tomorrow has meal plan
  Future<bool> _checkTomorrowMealPlan(String tomorrowStr) async {
    try {
      final userId = _userService.userId;
      if (userId == null) return false;

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
      print('Error checking meal plan: $e');
    }

    return false;
  }
}
