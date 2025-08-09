import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';

class CalorieAdjustmentService extends GetxController {
  static CalorieAdjustmentService get to => Get.find();

  // Store adjustments for each meal type
  final RxMap<String, int> mealAdjustments = <String, int>{}.obs;

  // Get the adjustment for a specific meal type
  int getAdjustmentForMeal(String mealType) {
    return mealAdjustments[mealType] ?? 0;
  }

  // Set adjustment for a meal type
  void setAdjustmentForMeal(String mealType, int adjustment) {
    mealAdjustments[mealType] = adjustment;
    update(); // Trigger GetBuilder rebuilds
  }

  // Clear all adjustments
  void clearAdjustments() {
    mealAdjustments.clear();
    update(); // Trigger GetBuilder rebuilds
  }

  // Check if user exceeds recommended calories and show adjustment dialog
  Future<void> checkAndShowAdjustmentDialog(
      BuildContext context, String mealType, int currentCalories,
      {String? notAllowedMealType}) async {
    final recommendation = getRecommendedCalories(mealType, 'addFood',
        notAllowedMealType: notAllowedMealType);
    final range = extractCalorieRange(recommendation);

    // Debug logging
    print('DEBUG: MealType: $mealType');
    print('DEBUG: CurrentCalories: $currentCalories');
    print('DEBUG: Recommendation: $recommendation');
    print('DEBUG: Range: $range');

    if (range['min']! > 0 && range['max']! > 0) {
      final overage = currentCalories - range['max']!;
      print('DEBUG: Overage: $overage');

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
          setAdjustmentForMeal(adjustmentMealType, overage);

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
      {String? notAllowedMealType}) {
    final adjustment = getAdjustmentForMeal(mealType);

    if (adjustment > 0) {
      return getAdjustedRecommendedCalories(
        mealType,
        screen,
        adjustment,
        notAllowedMealType: notAllowedMealType,
      );
    }

    return getRecommendedCalories(mealType, screen,
        notAllowedMealType: notAllowedMealType);
  }

  // Check if a meal type has an adjustment
  bool hasAdjustment(String mealType) {
    return mealAdjustments.containsKey(mealType) &&
        mealAdjustments[mealType]! > 0;
  }

  // Get all adjustments
  Map<String, int> getAllAdjustments() {
    return Map.from(mealAdjustments);
  }
}
