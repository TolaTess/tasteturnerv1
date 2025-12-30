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
            'Dark Chocolate (70%+ cocoa): Satisfies chocolate cravings while providing magnesium',
            'Soups & Broths: Addresses salty cravings, provides hydration and comfort',
            'Iron-rich foods: Spinach, kale, lentils, red meat, eggs - replenish iron stores',
            'Vitamin C foods: Oranges, bell peppers, strawberries - aid iron absorption',
            'Healthy fats: Avocados, walnuts, chia seeds - support mood and hormones',
            'Herbal teas: Ginger or chamomile - help ease cramps and provide comfort',
          ],
        };
      case CyclePhase.follicular:
        return {
          'title': 'Follicular Phase (Days 6–13)',
          'description':
              'Fuel your body\'s natural renewal with fresh, vibrant ingredients, Chef.',
          'foods': [
            'Leafy greens: Spinach, arugula, Swiss chard - boost energy and hormone production',
            'Proteins: Salmon, chicken, eggs, chickpeas - support cell renewal',
            'Complex carbs: Quinoa, oats, sweet potatoes - provide sustained energy',
            'Healthy fats: Olive oil, flaxseeds, pumpkin seeds - support hormone balance',
            'B vitamins: Bananas, almonds, sunflower seeds - boost energy levels',
            'Antioxidants: Blueberries, raspberries, dark chocolate (70%+) - support cell renewal',
          ],
        };
      case CyclePhase.ovulation:
        return {
          'title': 'Ovulation Phase (Days 14–17)',
          'description':
              'Keep your energy at peak with light, hydrating, and energizing dishes, Chef.',
          'foods': [
            'Cruciferous vegetables: Broccoli, Brussels sprouts, cauliflower - support egg release',
            'Zinc-rich foods: Pumpkin seeds, chickpeas, oysters - boost energy and fertility',
            'Fruits: Grapes, watermelon, grapefruit - provide hydration and antioxidants',
            'Proteins: Turkey, eggs, lentils - support peak energy needs',
            'Omega-3 fats: Salmon, chia seeds, walnuts - support hormone balance',
            'Cooling foods: Cucumbers, leafy greens, smoothies - keep you refreshed',
          ],
        };
      case CyclePhase.luteal:
        return {
          'title': 'Luteal Phase (Days 18–28)',
          'description':
              'Support your body\'s recovery and balance with nutrient-dense, satisfying meals, Chef.',
          'foods': [
            'Dark Chocolate (70%+): Satisfies chocolate cravings while providing magnesium',
            'Magnesium-rich foods: Almonds, spinach, pumpkin seeds - ease PMS symptoms',
            'Complex carbs: Brown rice, sweet potatoes, whole-grain bread - maintain stable blood sugar',
            'Calcium-rich foods: Yogurt, cheese, fortified plant milk - support bone health',
            'Hormone-balancing foods: Avocados, sesame seeds, sunflower seeds - support mood stability',
            'Anti-inflammatory foods: Turmeric, ginger tea, fatty fish - reduce bloating and discomfort',
            'Herbal teas: Peppermint (for bloating) or chamomile (for relaxation)',
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
        return const Color.fromARGB(255, 245, 164, 191);
      case CyclePhase.luteal:
        return const Color.fromARGB(255, 240, 222, 59);
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

  /// Get common cravings for a cycle phase
  List<Map<String, String>> getExpectedCravings(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.luteal:
        return [
          {'craving': 'Chocolate', 'emoji': '🍫'},
          {'craving': 'Salty Foods', 'emoji': '🧂'},
          {'craving': 'Carbs', 'emoji': '🍞'},
          {'craving': 'Sweet Treats', 'emoji': '🍰'},
          {'craving': 'Comfort Foods', 'emoji': '🍝'},
        ];
      case CyclePhase.menstrual:
        return [
          {'craving': 'Chocolate', 'emoji': '🍫'},
          {'craving': 'Sweet Things', 'emoji': '🍬'},
          {'craving': 'Salty Foods', 'emoji': '🧂'},
          {'craving': 'Comfort Foods', 'emoji': '🍲'},
          {'craving': 'Warm Beverages', 'emoji': '☕'},
        ];
      case CyclePhase.follicular:
        return [
          {'craving': 'Fresh Fruits', 'emoji': '🍎'},
          {'craving': 'Light Meals', 'emoji': '🥗'},
          {'craving': 'Hydrating Foods', 'emoji': '💧'},
          {'craving': 'Energy Foods', 'emoji': '⚡'},
        ];
      case CyclePhase.ovulation:
        return [
          {'craving': 'Fresh Foods', 'emoji': '🥬'},
          {'craving': 'Light Proteins', 'emoji': '🥩'},
          {'craving': 'Hydrating Fruits', 'emoji': '🍉'},
          {'craving': 'Energizing Snacks', 'emoji': '🥜'},
        ];
    }
  }

  /// Get enhanced recommendations including tips and macro adjustments
  Map<String, dynamic> getEnhancedRecommendations(CyclePhase phase) {
    final baseRecommendations = getPhaseRecommendations(phase);

    List<String> tips = [];
    String? macroInfo;

    switch (phase) {
      case CyclePhase.luteal:
        tips = [
          'Hydration: Increase water intake to help with bloating',
          'Exercise: Moderate intensity activities can help with mood',
          'Sleep: Prioritize 7-9 hours of quality sleep',
          'Self-care: Practice stress-reducing activities like meditation',
        ];
        macroInfo =
            'Your goals are adjusted: +200 calories, +20g carbs to support your body\'s needs';
        break;
      case CyclePhase.menstrual:
        tips = [
          'Hydration: Stay well-hydrated, especially with warm beverages',
          'Exercise: Gentle movement like walking or meditation',
          'Rest: Listen to your body and prioritize rest',
          'Self-care: Warm baths and comfort can help ease discomfort',
        ];
        macroInfo =
            'Your goals are adjusted: +100 calories to support recovery';
        break;
      case CyclePhase.follicular:
        tips = [
          'Hydration: Maintain regular water intake',
          'Exercise: This is a great time for higher intensity workouts',
          'Energy: Your energy levels are naturally higher',
          'Nutrition: Focus on fresh, nutrient-dense foods',
        ];
        macroInfo =
            'Your goals are at baseline - perfect time for balanced nutrition';
        break;
      case CyclePhase.ovulation:
        tips = [
          'Hydration: Extra hydration supports peak energy',
          'Exercise: Take advantage of peak energy for challenging workouts',
          'Energy: You\'re at your peak - fuel accordingly',
          'Nutrition: Light, energizing meals work best',
        ];
        macroInfo = 'Your goals are at baseline - maintain balanced nutrition';
        break;
    }

    return {
      ...baseRecommendations,
      'tips': tips,
      'macroInfo': macroInfo,
    };
  }
}
