import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../helper/notifications_helper.dart';
import 'package:intl/intl.dart';
import '../helper/utils.dart';

class CalorieAdjustmentService extends GetxController {
  static CalorieAdjustmentService get to => Get.find();

  // Store adjustments for each meal type
  final RxMap<String, int> mealAdjustments = <String, int>{}.obs;

  // Store the current date for adjustments
  String? _currentAdjustmentDate;

  // Check if it's a new day and clear adjustments if needed
  Future<void> _checkAndClearForNewDay() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (_currentAdjustmentDate != null && _currentAdjustmentDate != today) {
      // It's a new day, clear all adjustments
      await clearAdjustments();
    }

    _currentAdjustmentDate = today;
  }

  // Get current adjustment date (for debugging)
  String? get currentAdjustmentDate => _currentAdjustmentDate;

  // Get the adjustment for a specific meal type
  int getAdjustmentForMeal(String mealType) {
    // Convert to lowercase to match the keys used in SharedPreferences
    final key = mealType.toLowerCase();
    final adjustment = mealAdjustments[key] ?? 0;
    return adjustment;
  }

  // Set adjustment for a meal type and save to SharedPreferences
  Future<void> setAdjustmentForMeal(String mealType, int adjustment) async {
    // Check if it's a new day and clear adjustments if needed
    await _checkAndClearForNewDay();

    mealAdjustments[mealType] = adjustment;
    update(); // Trigger GetBuilder rebuilds

    // Save to SharedPreferences
    await _saveAdjustmentToSharedPrefs(mealType, adjustment);
  }

  // Save adjustment to SharedPreferences
  Future<void> _saveAdjustmentToSharedPrefs(
      String mealType, int adjustment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final key = '${mealType.toLowerCase()}_adjustment_$today';
      await prefs.setInt(key, adjustment);

      // Also save the current date
      await prefs.setString('adjustment_date', today);
    } catch (e) {
      print('DEBUG: Error saving adjustment to SharedPreferences: $e');
    }
  }

  // Load adjustments from SharedPreferences
  Future<void> loadAdjustmentsFromSharedPrefs() async {
    try {
      // Check if it's a new day and clear adjustments if needed
      await _checkAndClearForNewDay();

      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final mealTypes = ['breakfast', 'lunch', 'dinner', 'snacks', 'fruits'];

      mealAdjustments.clear();

      for (final mealType in mealTypes) {
        final key = '${mealType}_adjustment_$today';
        final adjustment = prefs.getInt(key);
        if (adjustment != null && adjustment > 0) {
          mealAdjustments[mealType] = adjustment;
        }
      }

      update();
    } catch (e) {
      print('DEBUG: Error loading adjustments from SharedPreferences: $e');
    }
  }

  // Clear all adjustments from memory and SharedPreferences
  Future<void> clearAdjustments() async {
    mealAdjustments.clear();
    update(); // Trigger GetBuilder rebuilds

    // Clear from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final mealTypes = ['breakfast', 'lunch', 'dinner', 'snacks', 'fruits'];

      for (final mealType in mealTypes) {
        final key = '${mealType}_adjustment_$today';
        await prefs.remove(key);
      }

      // Clear the adjustment date
      await prefs.remove('adjustment_date');
    } catch (e) {
      print('DEBUG: Error clearing adjustments from SharedPreferences: $e');
    }
  }

  // Check if user exceeds recommended calories and show adjustment dialog
  Future<void> checkAndShowAdjustmentDialog(
      BuildContext context, String mealType, int currentCalories,
      {String? notAllowedMealType, Map<String, dynamic>? selectedUser}) async {
    final recommendation = getRecommendedCalories(mealType, 'addFood',
        notAllowedMealType: notAllowedMealType, selectedUser: selectedUser);
    final range = extractCalorieRange(recommendation);

    if (range['min']! > 0 && range['max']! > 0) {
      final overage = currentCalories - range['max']!;

      if (overage > 0) {
        final shouldAdjust = await showCalorieAdjustmentDialog(
          context,
          mealType,
          currentCalories,
          range['min']!,
          range['max']!,
        );

        if (shouldAdjust) {
          // Determine which meal to adjust
          String adjustmentMealType = '';
          switch (mealType.toLowerCase()) {
            case 'breakfast':
              adjustmentMealType = 'Lunch';
              break;
            case 'lunch':
              adjustmentMealType = 'Dinner';
              break;
            case 'dinner':
              adjustmentMealType = 'Snacks';
              break;
            case 'snacks':
              adjustmentMealType = 'Fruits';
              break;
            case 'fruits':
              adjustmentMealType = 'Breakfast';
              break;
            default:
              adjustmentMealType = 'Lunch';
          }

          // Set the adjustment
          await setAdjustmentForMeal(adjustmentMealType, overage);

          // Show confirmation
          if (context.mounted) {
            showTastySnackbar(
              'Adjustment Applied',
              '$adjustmentMealType calories reduced by $overage kcal',
              context,
              backgroundColor: kAccentLight,
            );
          }
        }
      }
    }
  }

  // Get adjusted recommendation for a meal type
  String getAdjustedRecommendation(String mealType, String screen,
      {String? notAllowedMealType, Map<String, dynamic>? selectedUser}) {
    final adjustment = getAdjustmentForMeal(mealType);

    if (adjustment > 0) {
      return getAdjustedRecommendedCalories(
        mealType,
        screen,
        adjustment,
        notAllowedMealType: notAllowedMealType,
        selectedUser: selectedUser,
      );
    }

    return getRecommendedCalories(mealType, screen,
        notAllowedMealType: notAllowedMealType, selectedUser: selectedUser);
  }

  // Check if a meal type has an adjustment
  bool hasAdjustment(String mealType) {
    // Convert to lowercase to match the keys used in SharedPreferences
    final key = mealType.toLowerCase();
    final hasAdjustment =
        mealAdjustments.containsKey(key) && mealAdjustments[key]! > 0;
    return hasAdjustment;
  }

  // Get all adjustments
  Map<String, int> getAllAdjustments() {
    return Map.from(mealAdjustments);
  }
}
