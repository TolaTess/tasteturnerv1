import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data_models/cycle_tracking_model.dart';

class CycleAdjustmentService extends GetxController {
  static CycleAdjustmentService get instance {
    try {
      return Get.find<CycleAdjustmentService>();
    } catch (e) {
      return Get.put(CycleAdjustmentService());
    }
  }

  /// Get current cycle phase based on last period start and cycle length
  /// [targetDate] defaults to now if not provided
  CyclePhase getCurrentPhase(DateTime? lastPeriodStart, int cycleLength,
      [DateTime? targetDate]) {
    if (lastPeriodStart == null) {
      return CyclePhase.follicular; // Default if not set
    }

    final dateToCheck = targetDate ?? DateTime.now();
    // Normalize both dates to midnight for accurate day calculation
    final lastPeriodStartNormalized = DateTime(
        lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);
    final targetDateNormalized =
        DateTime(dateToCheck.year, dateToCheck.month, dateToCheck.day);

    final daysSincePeriod =
        targetDateNormalized.difference(lastPeriodStartNormalized).inDays;

    // Handle negative days (if target date is before last period start)
    if (daysSincePeriod < 0) {
      // Calculate from previous cycle
      final daysInPreviousCycle = daysSincePeriod % cycleLength;
      final dayInCycle = daysInPreviousCycle + cycleLength + 1;
      return _getPhaseForDay(dayInCycle, cycleLength);
    }

    final dayInCycle = (daysSincePeriod % cycleLength) + 1;
    return _getPhaseForDay(dayInCycle, cycleLength);
  }

  /// Helper method to get phase for a specific day in cycle
  CyclePhase _getPhaseForDay(int dayInCycle, int cycleLength) {
    if (dayInCycle >= 1 && dayInCycle <= 5) {
      return CyclePhase.menstrual;
    } else if (dayInCycle >= 6 && dayInCycle <= 13) {
      return CyclePhase.follicular;
    } else if (dayInCycle >= 14 && dayInCycle <= 16) {
      return CyclePhase.ovulation;
    } else {
      // Days 17 to cycleLength
      return CyclePhase.luteal;
    }
  }

  /// Get adjusted goals based on cycle phase
  Map<String, double> getAdjustedGoals(
    Map<String, double> baseGoals,
    CyclePhase phase,
  ) {
    final adjusted = Map<String, double>.from(baseGoals);

    switch (phase) {
      case CyclePhase.luteal:
        // Week before period: +200 calories, +20g carbs
        adjusted['calories'] = (adjusted['calories'] ?? 0) + 200;
        adjusted['carbs'] = (adjusted['carbs'] ?? 0) + 20;
        break;
      case CyclePhase.menstrual:
        // During period: +100 calories
        adjusted['calories'] = (adjusted['calories'] ?? 0) + 100;
        break;
      case CyclePhase.follicular:
      case CyclePhase.ovulation:
        // Use base goals
        break;
    }

    return adjusted;
  }

  /// Get cycle-aware food suggestions based on phase
  List<String> getPhaseFoodSuggestions(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.luteal:
        // Suggest magnesium-rich foods
        return [
          'Dark Chocolate',
          'Nuts',
          'Seeds',
          'Leafy Greens',
          'Whole Grains',
          'Legumes',
        ];
      case CyclePhase.menstrual:
        // Suggest iron-rich foods
        return [
          'Lean Meat',
          'Leafy Greens',
          'Legumes',
          'Fortified Cereals',
          'Beans',
          'Tofu',
        ];
      case CyclePhase.follicular:
      case CyclePhase.ovulation:
        // General healthy foods
        return [
          'Fresh Fruits',
          'Vegetables',
          'Lean Proteins',
          'Whole Grains',
        ];
    }
  }

  /// Get detailed food recommendations for each phase
  Map<String, dynamic> getPhaseRecommendations(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return {
          'title': 'Menstrual Phase (Days 1–5)',
          'description':
              'Nourish your body with comforting, restorative dishes during this time, Chef.',
          'foods': [
            'Iron-Rich Plates: Replenish your body\'s stores with hearty, warming dishes',
            'Dark Chocolate: A little sweetness to ease tension and lift your spirits',
            'Warm, Cooked Meals: Gentle on your system and soothing for digestion',
            'Avocado: Creamy, healthy fats to keep your mood steady and hormones balanced',
            'Hydrating Broths & Teas: Keep your body well-hydrated while you rest',
            'Simple, Clean Ingredients: Avoid heavy, processed foods that can cause discomfort',
          ],
        };
      case CyclePhase.follicular:
        return {
          'title': 'Follicular Phase (Days 6–13)',
          'description':
              'Fuel your body\'s natural renewal with fresh, vibrant ingredients, Chef.',
          'foods': [
            'Avocado: Rich, creamy texture that supports your body\'s natural processes',
            'Fresh Berries: Bright, antioxidant-packed gems for cell renewal',
            'Lemon: Bright, zesty flavor that supports your body\'s natural detox',
            'Green Tea: A gentle, warming brew that energizes without overwhelming',
            'Flaxseeds: Nutty, grounding seeds that help balance your system',
            'Wild Salmon: Rich, omega-packed fish that fuels your brain and energy',
          ],
        };
      case CyclePhase.ovulation:
        return {
          'title': 'Ovulation Phase (Days 14–17)',
          'description':
              'Keep your energy at peak with light, hydrating, and energizing dishes, Chef.',
          'foods': [
            'Fresh Spinach: Light, leafy greens that support your body without weighing you down',
            'Avocado: Creamy, satisfying fats that keep your mood elevated',
            'Cooling Cucumber: Refreshing, hydrating, and gentle on your system',
            'Citrus Fruits: Bright, zesty flavors that boost your natural defenses',
            'Watermelon: Ultra-hydrating, refreshing, and perfect for peak energy',
            'Papaya: Tropical, digestive-friendly fruit that supports your glow',
          ],
        };
      case CyclePhase.luteal:
        return {
          'title': 'Luteal Phase (Days 18–28)',
          'description':
              'Support your body\'s recovery and balance with nutrient-dense, satisfying meals, Chef.',
          'foods': [
            'Broccoli: Earthy, cruciferous greens that help your body process naturally',
            'Avocado: Rich, satisfying fats that keep your mood stable and hormones balanced',
            'Spinach: Iron-rich greens that restore your body\'s natural stores',
            'Eggs: Protein-packed, versatile ingredients that fuel your recovery',
            'Salmon: Rich, omega-packed fish that supports mood and natural balance',
            'Berries: Antioxidant-rich fruits that help your body process and recover',
          ],
        };
    }
  }

  /// Get cycle phase name for display
  String getPhaseName(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.follicular:
        return 'Follicular';
      case CyclePhase.ovulation:
        return 'Ovulation';
      case CyclePhase.luteal:
        return 'Luteal';
      case CyclePhase.menstrual:
        return 'Menstrual';
    }
  }

  /// Get cycle phase emoji for display
  String getPhaseEmoji(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.follicular:
        return '🌱';
      case CyclePhase.ovulation:
        return '🌸';
      case CyclePhase.luteal:
        return '🌙';
      case CyclePhase.menstrual:
        return '🩸';
    }
  }

  /// Get cycle phase color for display
  Color getPhaseColor(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.follicular:
        return Colors.green;
      case CyclePhase.ovulation:
        return Colors.pink;
      case CyclePhase.luteal:
        return Colors.purple;
      case CyclePhase.menstrual:
        return Colors.red;
    }
  }

  /// Calculate days until next period
  int? getDaysUntilNextPeriod(DateTime? lastPeriodStart, int cycleLength) {
    if (lastPeriodStart == null) return null;

    final now = DateTime.now();
    final daysSincePeriod = now.difference(lastPeriodStart).inDays;
    final dayInCycle = (daysSincePeriod % cycleLength) + 1;
    final daysUntilNext = cycleLength - dayInCycle + 1;

    return daysUntilNext;
  }
}
