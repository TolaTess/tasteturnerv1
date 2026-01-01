import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/helper_files.dart';
import '../helper/utils.dart';
import '../helper/notifications_helper.dart';
import '../pages/edit_goal.dart';
import '../pages/profile_edit_screen.dart';
import '../screens/add_food_screen.dart';
import '../service/cycle_adjustment_service.dart';
import '../service/goal_adjustment_service.dart';
import '../data_models/cycle_tracking_model.dart';
import 'bottom_nav.dart';

class UserDetailsSection extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isDarkMode;
  final bool showCaloriesAndGoal;
  final bool familyMode;
  final int selectedUserIndex;
  final List<Map<String, dynamic>> displayList;
  final VoidCallback onToggleShowCalories;
  final Function(Map<String, dynamic>, bool) onEdit;

  const UserDetailsSection({
    super.key,
    required this.user,
    required this.isDarkMode,
    required this.showCaloriesAndGoal,
    required this.familyMode,
    required this.selectedUserIndex,
    required this.displayList,
    required this.onToggleShowCalories,
    required this.onEdit,
  });

  // Helper function to calculate adjusted target calories
  double _getAdjustedTargetCalories() {
    // For current user, use dailyDataController which already has adjusted calories
    if (user['name'] == userService.currentUser.value?.displayName) {
      return dailyDataController.targetCalories.value;
    }

    // For family members, calculate adjusted calories manually
    final foodGoalValue = user['foodGoal'];
    final baseCalories = (parseToNumber(foodGoalValue) ?? 2000).toDouble();
    final fitnessGoal = (user['fitnessGoal'] as String? ?? '').toLowerCase();

    double adjustedCalories = baseCalories;
    switch (fitnessGoal) {
      case 'lose weight':
      case 'weight loss':
        adjustedCalories = baseCalories * 0.8; // 80% for weight loss
        break;
      case 'gain muscle':
      case 'muscle gain':
      case 'build muscle':
        adjustedCalories = baseCalories * 1.0; // 100% for muscle gain
        break;
      default:
        adjustedCalories = baseCalories; // 100% for maintenance
        break;
    }

    return adjustedCalories;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = user['name'] ?? '';
    final firstName = name.split(' ').first;
    final nameCapitalized = capitalizeFirstLetter(firstName);
    final mainUserName = userService.currentUser.value?.displayName ?? '';
    final adjustedTargetCalories = _getAdjustedTargetCalories();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: Avatar, Name, Calorie Badge, Edit Button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      // Only navigate to AddFoodScreen if selected user is current user
                      if (familyMode && user['name'] != mainUserName) {
                        // Show snackbar when family member is selected
                        showTastySnackbar(
                          'Tracking Only1',
                          'Food tracking is only available for Chef ${capitalizeFirstLetter(mainUserName)}',
                          context,
                          backgroundColor: kAccentLight,
                        );
                        return; // Do nothing
                      }
                      Get.to(() => const AddFoodScreen(isShowSummary: true));
                    },
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            user['name'] ==
                                    userService.currentUser.value?.displayName
                                ? 'Chef $nameCapitalized'
                                : capitalizeFirstLetter(user['name'] ?? ''),
                            style: textTheme.displaySmall?.copyWith(
                                fontSize: getPercentageWidth(
                                    user['name'].length > 10 ? 5.2 : 6,
                                    context)),
                          ),
                        ),
                        if (user['name'] ==
                            userService.currentUser.value?.displayName)
                          SizedBox(
                              width: user['name'].length > 10
                                  ? getPercentageWidth(0.5, context)
                                  : getPercentageWidth(1, context)),
                      ],
                    ),
                  ),
                  if ((user['fitnessGoal'] ?? '').isNotEmpty &&
                      showCaloriesAndGoal)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        user['fitnessGoal'],
                        style: textTheme.bodyMedium?.copyWith(
                            fontSize: getPercentageWidth(3, context)),
                      ),
                    ),
                ],
              ),
            ),
            // Calorie badge - show adjusted calories (clickable for main user)
            if ((user['foodGoal'] ?? '').isNotEmpty && showCaloriesAndGoal)
              Obx(() {
                // Use Obx to reactively update when dailyDataController changes (for current user)
                final displayCalories =
                    user['name'] == userService.currentUser.value?.displayName
                        ? dailyDataController.targetCalories.value
                        : adjustedTargetCalories;
                final isMainUser =
                    user['name'] == userService.currentUser.value?.displayName;
                return GestureDetector(
                  onTap: isMainUser
                      ? () => _showCalorieBreakdown(context, isDarkMode)
                      : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(3, context),
                        vertical: getPercentageHeight(0.8, context)),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${displayCalories.round()} kcal',
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: getPercentageWidth(3, context),
                          ),
                        ),
                        if (isMainUser) ...[
                          SizedBox(width: getPercentageWidth(1, context)),
                          Icon(
                            Icons.info_outline,
                            size: getIconScale(4, context),
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            // Edit button as floating action
            SizedBox(width: getPercentageWidth(1, context)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (familyMode) {
                    if (user['name'] ==
                        userService.currentUser.value?.displayName) {
                      Get.to(() => const ProfileEditScreen());
                    } else {
                      onEdit(user, isDarkMode);
                    }
                  } else {
                    Get.to(() => const NutritionSettingsPage());
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.settings,
                      color: isDarkMode ? kAccent : kWhite,
                      size: getIconScale(7, context)),
                ),
              ),
            ),
            SizedBox(width: getPercentageWidth(1, context)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onToggleShowCalories,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      showCaloriesAndGoal
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: isDarkMode ? kAccent : kWhite,
                      size: getIconScale(7, context)),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(2, context)),
        // Sleek horizontal progress bar
        Obx(() {
          if (user['name'] != userService.currentUser.value?.displayName) {
            return const SizedBox.shrink();
          }

          double eatenCalories =
              dailyDataController.eatenCalories.value.toDouble();
          double targetCalories = dailyDataController.targetCalories.value;
          double progress = targetCalories > 0
              ? (eatenCalories / targetCalories).clamp(0.0, 1.0)
              : 0.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: getProportionalHeight(18, context),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDarkMode
                          ? kDarkGrey.withValues(alpha: 0.18)
                          : kWhite.withValues(alpha: 0.18),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    height: getProportionalHeight(12, context),
                    width: getPercentageWidth(100 * progress, context),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [kAccent, kAccentLight],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: getPercentageHeight(0.5, context)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${eatenCalories.toStringAsFixed(0)} kcal',
                    style: textTheme.bodyMedium
                        ?.copyWith(fontSize: getPercentageWidth(3, context)),
                  ),
                  if (targetCalories > 0 && showCaloriesAndGoal)
                    Text(
                      '${(targetCalories - eatenCalories).abs().toStringAsFixed(0)} kcal',
                      style: textTheme.bodyMedium
                          ?.copyWith(fontSize: getPercentageWidth(3, context)),
                    ),
                ],
              ),
            ],
          );
        }),
      ],
    );
  }

  void _showCalorieBreakdown(BuildContext context, bool isDarkMode) {
    final textTheme = Theme.of(context).textTheme;
    final currentUser = userService.currentUser.value;
    if (currentUser == null) return;

    final settings = currentUser.settings;
    final baseCalories =
        (parseToNumber(settings['foodGoal']) ?? 2000).toDouble();

    // Check if fitness goal adjustments are enabled (separate from cycle adjustments)
    final enableAdjustmentsRaw = settings['enableGoalAdjustments'];
    final enableGoalAdjustments = enableAdjustmentsRaw is bool
        ? enableAdjustmentsRaw
        : (enableAdjustmentsRaw is String
            ? enableAdjustmentsRaw.toLowerCase() == 'true'
            : true); // Default to true if null or unexpected type

    // Use GoalAdjustmentService to get adjusted goals
    final goalService = GoalAdjustmentService.instance;
    final adjustedGoals =
        goalService.getAdjustedGoals(settings, DateTime.now());
    final finalCalories = adjustedGoals['calories'] ?? baseCalories;

    // Calculate fitness goal adjustment (only if enabled)
    double fitnessAdjustedCalories = baseCalories;
    String fitnessAdjustmentText = 'No adjustment';
    double fitnessAdjustment = 0.0;

    if (enableGoalAdjustments) {
      final fitnessGoal =
          (settings['fitnessGoal'] as String? ?? '').toLowerCase();

      // Calculate fitness goal adjustment
      switch (fitnessGoal) {
        case 'lose weight':
        case 'weight loss':
          fitnessAdjustedCalories = baseCalories * 0.8;
          fitnessAdjustment = -baseCalories * 0.2;
          fitnessAdjustmentText = 'Weight loss (-20%)';
          break;
        case 'gain muscle':
        case 'muscle gain':
        case 'build muscle':
          fitnessAdjustedCalories = baseCalories * 1.1;
          fitnessAdjustment = baseCalories * 0.1;
          fitnessAdjustmentText = 'Muscle gain (+10%)';
          break;
        default:
          fitnessAdjustedCalories = baseCalories;
          fitnessAdjustment = 0.0;
          fitnessAdjustmentText = 'Maintenance (100%)';
          break;
      }
    }

    // Calculate cycle adjustments (INDEPENDENT of goal adjustments)
    // Cycle syncing is controlled separately by cycleTracking.isEnabled
    double cycleAdjustment = 0.0;
    String cycleAdjustmentText = 'Not enabled';
    String cyclePhaseText = '';

    final cycleDataRaw = settings['cycleTracking'];
    if (cycleDataRaw != null && cycleDataRaw is Map) {
      final cycleData = Map<String, dynamic>.from(cycleDataRaw);
      if (cycleData['isEnabled'] as bool? ?? false) {
        final lastPeriodStartStr = cycleData['lastPeriodStart'] as String?;
        if (lastPeriodStartStr != null) {
          final lastPeriodStart = DateTime.tryParse(lastPeriodStartStr);
          if (lastPeriodStart != null) {
            final cycleLength =
                (cycleData['cycleLength'] as num?)?.toInt() ?? 28;
            final cycleService = CycleAdjustmentService.instance;
            final phase =
                cycleService.getCurrentPhase(lastPeriodStart, cycleLength);

            // Calculate cycle adjustment from the calories after fitness goal adjustment
            final caloriesAfterFitness =
                enableGoalAdjustments ? fitnessAdjustedCalories : baseCalories;
            cycleAdjustment = finalCalories - caloriesAfterFitness;

            // Get phase name
            switch (phase) {
              case CyclePhase.luteal:
                cyclePhaseText = 'Luteal Phase';
                cycleAdjustmentText = '+200 kcal';
                break;
              case CyclePhase.menstrual:
                cyclePhaseText = 'Menstrual Phase';
                cycleAdjustmentText = '+100 kcal';
                break;
              case CyclePhase.follicular:
                cyclePhaseText = 'Follicular Phase';
                cycleAdjustmentText = 'No adjustment';
                break;
              case CyclePhase.ovulation:
                cyclePhaseText = 'Ovulation Phase';
                cycleAdjustmentText = 'No adjustment';
                break;
            }
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: getPercentageWidth(90, context),
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? kDarkGrey : kWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(getPercentageWidth(5, context)),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calculate,
                      color: kAccent,
                      size: getIconScale(7, context),
                    ),
                    SizedBox(width: getPercentageWidth(3, context)),
                    Expanded(
                      child: Text(
                        'Calorie Breakdown',
                        style: textTheme.displayMedium?.copyWith(
                          fontSize: getTextScale(5, context),
                          color: kAccent,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(getPercentageWidth(2, context)),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? kDarkGrey.withValues(alpha: 0.5)
                              : kWhite,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.close,
                          color: kAccent,
                          size: getIconScale(5, context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(getPercentageWidth(5, context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Base Calories
                    _buildBreakdownRow(
                      context,
                      'Base Calories',
                      baseCalories.round(),
                      null,
                      isDarkMode,
                      textTheme,
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),

                    // Show fitness goal adjustment only if enabled
                    if (enableGoalAdjustments) ...[
                      // Fitness Goal Adjustment
                      _buildBreakdownRow(
                        context,
                        'Fitness Goal',
                        fitnessAdjustedCalories.round(),
                        fitnessAdjustment != 0.0
                            ? '${fitnessAdjustment > 0 ? '+' : ''}${fitnessAdjustment.round()} kcal'
                            : null,
                        isDarkMode,
                        textTheme,
                        subtitle: fitnessAdjustmentText,
                      ),
                      SizedBox(height: getPercentageHeight(2, context)),
                    ] else ...[
                      // Goal adjustments disabled - show disabled state
                      Container(
                        padding: EdgeInsets.all(getPercentageWidth(4, context)),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? kDarkGrey.withValues(alpha: 0.3)
                              : kLightGrey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? kLightGrey.withValues(alpha: 0.3)
                                : kDarkGrey.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: isDarkMode ? kLightGrey : kDarkGrey,
                              size: getIconScale(5, context),
                            ),
                            SizedBox(width: getPercentageWidth(3, context)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fitness Goal Adjustments Disabled',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode
                                          ? kLightGrey
                                          : kDarkGrey.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          getPercentageHeight(0.5, context)),
                                  Text(
                                    'Using exact entered values',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isDarkMode
                                          ? kLightGrey.withValues(alpha: 0.7)
                                          : kDarkGrey.withValues(alpha: 0.5),
                                      fontSize:
                                          getPercentageWidth(2.5, context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(2, context)),
                    ],

                    // Cycle Adjustment (shown independently if cycle syncing is enabled)
                    if (cycleAdjustment != 0.0 || cyclePhaseText.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBreakdownRow(
                            context,
                            'Cycle Syncing',
                            finalCalories.round(),
                            cycleAdjustment != 0.0
                                ? '${cycleAdjustment > 0 ? '+' : ''}${cycleAdjustment.round()} kcal'
                                : null,
                            isDarkMode,
                            textTheme,
                            subtitle: cyclePhaseText.isNotEmpty
                                ? '$cyclePhaseText ($cycleAdjustmentText)'
                                : cycleAdjustmentText,
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),
                        ],
                      ),

                    // Show update link only if goal adjustments are disabled
                    if (!enableGoalAdjustments) ...[
                      // Link to update settings
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Close dialog first
                          Get.to(() => const NutritionSettingsPage());
                        },
                        child: Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(4, context)),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kAccent.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.settings,
                                color: kAccent,
                                size: getIconScale(5, context),
                              ),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Text(
                                'Update Settings',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: kAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: getPercentageWidth(1, context)),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: kAccent,
                                size: getIconScale(4, context),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(2, context)),
                    ],

                    // Divider
                    Divider(
                      color: isDarkMode
                          ? kLightGrey.withValues(alpha: 0.3)
                          : kDarkGrey.withValues(alpha: 0.3),
                      thickness: 1,
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),

                    // Final Adjusted Calories
                    Container(
                      padding: EdgeInsets.all(getPercentageWidth(4, context)),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Daily Target',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: kAccent,
                            ),
                          ),
                          Text(
                            '${finalCalories.round()} kcal',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: kAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    int calories,
    String? adjustment,
    bool isDarkMode,
    TextTheme textTheme, {
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                          fontSize: getPercentageWidth(2.5, context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  '$calories kcal',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
                if (adjustment != null) ...[
                  SizedBox(width: getPercentageWidth(2, context)),
                  Text(
                    adjustment,
                    style: textTheme.bodySmall?.copyWith(
                      color: adjustment.startsWith('+')
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class MealPlanSection extends StatelessWidget {
  final List<MealWithType> meals;
  final Map<String, dynamic> mealPlan;
  final bool isDarkMode;
  final bool showCaloriesAndGoal;
  final Map<String, dynamic> user;
  final Color color;

  const MealPlanSection({
    super.key,
    required this.meals,
    required this.mealPlan,
    required this.isDarkMode,
    required this.showCaloriesAndGoal,
    required this.user,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        SizedBox(height: getPercentageHeight(1, context)),
        // Meal ListView (unchanged, but with glassy card effect)
        if (meals.isEmpty)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BottomNavSec(selectedIndex: 4),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(1, context),
                    vertical: getPercentageHeight(1, context)),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: getPercentageHeight(1, context)),
                    child: Text(
                      user['name'] == userService.currentUser.value?.displayName
                          ? 'Add a meal plan'
                          : 'Add a meal plan for ${capitalizeFirstLetter(user['name'] ?? '')}',
                      style: textTheme.bodyMedium
                          ?.copyWith(fontSize: getPercentageWidth(3, context)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (meals.isNotEmpty)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BottomNavSec(selectedIndex: 4),
                ),
              );
            },
            child: SizedBox(
              height: getProportionalHeight(125, context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meals.length,
                separatorBuilder: (context, i) =>
                    SizedBox(width: getPercentageWidth(2, context)),
                itemBuilder: (context, index) {
                  final meal = meals[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RecipeDetailScreen(mealData: meal.meal),
                        ),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: getPercentageWidth(32, context),
                          padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(2, context),
                            vertical: getPercentageHeight(1.5, context),
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: color.withValues(alpha: 0.18),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                capitalizeFirstLetter(meal.meal.title),
                                style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: getPercentageWidth(3, context)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (showCaloriesAndGoal)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '${meal.meal.calories} kcal',
                                    style: textTheme.bodyMedium?.copyWith(
                                        fontSize:
                                            getPercentageWidth(3, context)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Meal type icon as a top-level overlay
                        Positioned(
                          top: getPercentageWidth(0, context),
                          left: getPercentageWidth(0, context),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDarkMode ? kDarkGrey : kWhite,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: kAccent.withValues(alpha: 0.5),
                                  blurRadius: getPercentageWidth(1, context),
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding:
                                EdgeInsets.all(getPercentageWidth(2, context)),
                            child: Text(
                              getMealTypeSubtitle(meal.mealType),
                              style: textTheme.displaySmall?.copyWith(
                                  fontSize: getPercentageWidth(5, context),
                                  color: kAccent),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: getPercentageWidth(2, context),
                          right: getPercentageWidth(2, context),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const BottomNavSec(selectedIndex: 4),
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(
                                  getPercentageWidth(1, context)),
                              decoration: BoxDecoration(
                                color: getDayTypeColor(
                                        (mealPlan['dayType'] ?? '')
                                            .replaceAll('_', ' '),
                                        isDarkMode)
                                    .withValues(alpha: 0.13),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit,
                                size: getIconScale(5.5, context),
                                color: getDayTypeColor(
                                    (mealPlan['dayType'] ?? '')
                                        .replaceAll('_', ' '),
                                    isDarkMode),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class FamilySelectorSection extends StatelessWidget {
  final bool familyMode;
  final int selectedUserIndex;
  final List<Map<String, dynamic>> displayList;
  final Function(int) onSelectUser;
  final bool isDarkMode;

  const FamilySelectorSection({
    super.key,
    required this.familyMode,
    required this.selectedUserIndex,
    required this.displayList,
    required this.onSelectUser,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    if (!familyMode) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: getPercentageHeight(7, context),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: displayList.length,
        separatorBuilder: (context, i) =>
            SizedBox(width: getPercentageWidth(1, context)),
        itemBuilder: (context, i) {
          final fam = displayList[i];
          return GestureDetector(
            onTap: () => onSelectUser(i),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: i == selectedUserIndex ? kAccent : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  if (i == selectedUserIndex)
                    BoxShadow(
                      color: kAccent.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: CircleAvatar(
                radius: getResponsiveBoxSize(context, 20, 20),
                backgroundColor: i == selectedUserIndex
                    ? kAccent
                    : isDarkMode
                        ? kDarkGrey.withValues(alpha: 0.18)
                        : kWhite.withValues(alpha: 0.25),
                child: fam['avatar'] == null
                    ? getAvatar(fam['ageGroup'], context, isDarkMode)
                    : ClipOval(
                        child: Image.asset(
                          fam['avatar'],
                          width: getResponsiveBoxSize(context, 18, 18),
                          height: getResponsiveBoxSize(context, 18, 18),
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
