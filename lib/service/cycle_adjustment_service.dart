import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
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
  CyclePhase getCurrentPhase(DateTime? lastPeriodStart, int cycleLength) {
    if (lastPeriodStart == null) {
      return CyclePhase.follicular; // Default if not set
    }

    final now = DateTime.now();
    final daysSincePeriod = now.difference(lastPeriodStart).inDays;
    final dayInCycle = (daysSincePeriod % cycleLength) + 1;

    if (dayInCycle >= 1 && dayInCycle <= 5) {
      return CyclePhase.menstrual;
    } else if (dayInCycle >= 6 && dayInCycle <= 13) {
      return CyclePhase.follicular;
    } else if (dayInCycle >= 14 && dayInCycle <= 16) {
      return CyclePhase.ovulation;
    } else {
      // Days 17-28
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
        return '🌺';
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

