import 'package:get/get.dart';
import '../service/cycle_adjustment_service.dart';
import '../helper/notifications_helper.dart';

/// Centralized service for calculating adjusted nutrition goals
/// based on fitness goals and cycle tracking
class GoalAdjustmentService extends GetxController {
  static GoalAdjustmentService get instance {
    try {
      return Get.find<GoalAdjustmentService>();
    } catch (e) {
      return Get.put(GoalAdjustmentService());
    }
  }

  /// Calculate fully adjusted goals (calories + macros) for a specific date
  /// 
  /// Order of operations:
  /// 1. Check if adjustments are enabled - if not, return base values
  /// 2. Apply fitness goal adjustment to calories (Base → Target)
  /// 3. Calculate macros from TARGET calories using fitness-specific ratios
  /// 4. Apply cycle adjustments to calories and macros
  /// 5. Return complete adjusted goals
  Map<String, double> getAdjustedGoals(
    Map<String, dynamic> settings,
    DateTime date,
  ) {
    // Step 1: Get base calories and macros from settings
    final baseCalories = (parseToNumber(settings['foodGoal']) ?? 2000).toDouble();
    final baseProtein = (parseToNumber(settings['proteinGoal']) ?? 0).toDouble();
    final baseCarbs = (parseToNumber(settings['carbsGoal']) ?? 0).toDouble();
    final baseFat = (parseToNumber(settings['fatGoal']) ?? 0).toDouble();

    // Step 2: Check if fitness goal adjustments are enabled
    // This only controls fitness goal adjustments, NOT cycle adjustments
    // Default to true for backward compatibility (existing users)
    // Handle both bool and String types (Firestore may store as String)
    final enableAdjustmentsRaw = settings['enableGoalAdjustments'];
    final enableGoalAdjustments = enableAdjustmentsRaw is bool
        ? enableAdjustmentsRaw
        : (enableAdjustmentsRaw is String
            ? enableAdjustmentsRaw.toLowerCase() == 'true'
            : true); // Default to true if null or unexpected type

    double targetCalories = baseCalories;
    Map<String, double> macros;

    // Step 3: Apply fitness goal adjustment ONLY if enabled
    if (enableGoalAdjustments) {
      final fitnessGoal = (settings['fitnessGoal'] as String? ?? '').toLowerCase();

      switch (fitnessGoal) {
        case 'lose weight':
        case 'weight loss':
          targetCalories = baseCalories * 0.8; // -20%
          break;
        case 'gain muscle':
        case 'muscle gain':
        case 'build muscle':
          targetCalories = baseCalories * 1.1; // +10% surplus
          break;
        default:
          targetCalories = baseCalories; // Maintenance
      }

      // Step 4: Calculate macros from TARGET calories (not base!)
      // Use fitness goal-specific ratios
      final gender = settings['gender'] as String?;
      macros = _calculateMacrosFromTarget(
        targetCalories,
        fitnessGoal,
        gender,
      );
    } else {
      // Use base macros as-is when goal adjustments are disabled
      macros = {
        'protein': baseProtein,
        'carbs': baseCarbs,
        'fat': baseFat,
      };
    }

    // Step 5: Apply cycle adjustments if enabled (INDEPENDENT of goal adjustments)
    // Cycle syncing is controlled separately by cycleTracking.isEnabled
    final cycleDataRaw = settings['cycleTracking'];
    Map<String, dynamic>? cycleData;
    if (cycleDataRaw != null && cycleDataRaw is Map) {
      cycleData = Map<String, dynamic>.from(cycleDataRaw);
    }

    if (cycleData != null && (cycleData['isEnabled'] as bool? ?? false)) {
      final lastPeriodStartStr = cycleData['lastPeriodStart'] as String?;
      if (lastPeriodStartStr != null) {
        final lastPeriodStart = DateTime.tryParse(lastPeriodStartStr);
        if (lastPeriodStart != null) {
          final cycleLength = (cycleData['cycleLength'] as num?)?.toInt() ?? 28;
          final cycleService = CycleAdjustmentService.instance;
          final phase = cycleService.getCurrentPhase(lastPeriodStart, cycleLength, date);

          final baseGoals = {
            'calories': targetCalories,
            'protein': macros['protein']!,
            'carbs': macros['carbs']!,
            'fat': macros['fat']!,
          };

          final adjustedGoals = cycleService.getAdjustedGoals(baseGoals, phase);
          targetCalories = adjustedGoals['calories'] ?? targetCalories;
          macros = {
            'protein': adjustedGoals['protein'] ?? macros['protein']!,
            'carbs': adjustedGoals['carbs'] ?? macros['carbs']!,
            'fat': adjustedGoals['fat'] ?? macros['fat']!,
          };
        }
      }
    }

    // Step 6: Return complete adjusted goals
    return {
      'calories': targetCalories,
      'protein': macros['protein']!,
      'carbs': macros['carbs']!,
      'fat': macros['fat']!,
    };
  }

  /// Calculate macros from target calories using fitness-specific ratios
  /// 
  /// CRITICAL: This calculates from TARGET calories, NOT base macros.
  /// Never reduce macros proportionally - always recalculate from new calorie budget.
  Map<String, double> _calculateMacrosFromTarget(
    double targetCalories,
    String fitnessGoal,
    String? gender,
  ) {
    // Gender multipliers (if needed)
    double proteinMultiplier = gender == 'male' ? 1.15 : (gender == 'female' ? 1.05 : 1.0);
    double carbsMultiplier = gender == 'male' ? 1.05 : (gender == 'female' ? 0.98 : 1.0);
    double fatMultiplier = gender == 'male' ? 0.95 : (gender == 'female' ? 1.02 : 1.0);

    double proteinPercent, carbsPercent, fatPercent;

    switch (fitnessGoal) {
      case 'lose weight':
      case 'weight loss':
        // High protein for satiety and muscle retention during cut
        proteinPercent = 0.40; // 40%
        carbsPercent = 0.30; // 30%
        fatPercent = 0.30; // 30%
        break;
      case 'gain muscle':
      case 'muscle gain':
      case 'build muscle':
        // Higher carbs to fuel lifting and recovery
        proteinPercent = 0.30; // 30%
        carbsPercent = 0.40; // 40%
        fatPercent = 0.30; // 30%
        break;
      default: // Maintenance/Healthy Eating
        // Balanced distribution
        proteinPercent = 0.30; // 30%
        carbsPercent = 0.35; // 35%
        fatPercent = 0.35; // 35%
    }

    return {
      'protein': ((targetCalories * proteinPercent / 4) * proteinMultiplier),
      'carbs': ((targetCalories * carbsPercent / 4) * carbsMultiplier),
      'fat': ((targetCalories * fatPercent / 9) * fatMultiplier),
    };
  }
}

