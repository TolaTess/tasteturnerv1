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
      debugPrint('DEBUG: Error saving adjustment to SharedPreferences: $e');
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
      debugPrint('DEBUG: Error loading adjustments from SharedPreferences: $e');
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
      debugPrint(
          'DEBUG: Error clearing adjustments from SharedPreferences: $e');
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
          notAllowedMealType,
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
              adjustmentMealType =
                  notAllowedMealType == 'snack' ? 'Fruits' : 'Snacks';
              break;
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

  // Remove adjustment for a specific meal type
  Future<void> removeAdjustmentForMeal(String mealType) async {
    // Check if it's a new day and clear adjustments if needed
    await _checkAndClearForNewDay();

    final key = mealType.toLowerCase();
    if (mealAdjustments.containsKey(key)) {
      mealAdjustments.remove(key);
      update(); // Trigger GetBuilder rebuilds

      // Remove from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final prefKey = '${key}_adjustment_$today';
        await prefs.remove(prefKey);
      } catch (e) {
        debugPrint('DEBUG: Error removing adjustment from SharedPreferences: $e');
      }
    }
  }

  // Determine which meal type was adjusted based on the meal type that went over
  // Returns a list because Dinner can adjust either Snacks or Fruits
  List<String> _getAdjustedMealTypes(String mealType, String? notAllowedMealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return ['Lunch'];
      case 'lunch':
        return ['Dinner'];
      case 'dinner':
        // Dinner can adjust either Snacks or Fruits depending on notAllowedMealType
        // If notAllowedMealType is not provided, check both
        if (notAllowedMealType == 'snack') {
          return ['Fruits'];
        } else if (notAllowedMealType == 'fruit') {
          return ['Snacks'];
        } else {
          // Check both if we don't know which one was adjusted
          return ['Snacks', 'Fruits'];
        }
      default:
        return [];
    }
  }

  // Check if adjustment should be removed and remove it if needed
  Future<void> checkAndRemoveAdjustmentIfNeeded(
    String mealType,
    int currentCalories, {
    String? notAllowedMealType,
    Map<String, dynamic>? selectedUser,
    BuildContext? context,
  }) async {
    try {
      // Get recommended calorie range for the meal type
      final recommendation = getRecommendedCalories(mealType, 'addFood',
          notAllowedMealType: notAllowedMealType, selectedUser: selectedUser);
      final range = extractCalorieRange(recommendation);

      if (range['min']! > 0 && range['max']! > 0) {
        // Check if current calories are now under the max recommended
        if (currentCalories <= range['max']!) {
          // Determine which meal types could have been adjusted (next in sequence)
          final adjustedMealTypes =
              _getAdjustedMealTypes(mealType, notAllowedMealType);

          // Check each possible adjusted meal type and remove adjustment if found
          for (final adjustedMealType in adjustedMealTypes) {
            if (hasAdjustment(adjustedMealType)) {
              // Remove the adjustment
              await removeAdjustmentForMeal(adjustedMealType);

              // Show confirmation snackbar if context is provided
              if (context != null && context.mounted) {
                showTastySnackbar(
                  'Adjustment Removed',
                  '$adjustedMealType calories restored to original recommendation',
                  context,
                  backgroundColor: kAccentLight,
                );
              }
              // Only remove one adjustment (the first one found)
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Error checking and removing adjustment: $e');
    }
  }
}
