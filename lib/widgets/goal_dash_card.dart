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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                      if (familyMode &&
                          user['name'] !=
                              userService.currentUser.value?.displayName) {
                        // Show snackbar when family member is selected
                        showTastySnackbar(
                          'Tracking Only',
                          'Food tracking is only available for ${userService.currentUser.value?.displayName}',
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
                            capitalizeFirstLetter(user['name'] ?? ''),
                            style: textTheme.displaySmall?.copyWith(
                                fontSize: getPercentageWidth(6, context)),
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
            // Calorie badge
            if ((user['foodGoal'] ?? '').isNotEmpty && showCaloriesAndGoal)
              Container(
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
                child: Text(
                  '${user['foodGoal']} kcal',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontSize: getPercentageWidth(3, context)),
                ),
              ),
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
                                capitalizeFirstLetter(meal.meal.title ?? ''),
                                style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: getPercentageWidth(3, context)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (showCaloriesAndGoal &&
                                  meal.meal.calories != null)
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
