import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/user_meal.dart';
import '../helper/utils.dart';
import '../service/nutrition_controller.dart';

class MealDetailWidget extends StatefulWidget {
  final String mealType;
  final List<UserMeal> meals;
  final int currentCalories;
  final String recommendedCalories;
  final IconData icon;
  final VoidCallback onAddMeal;

  const MealDetailWidget({
    super.key,
    required this.mealType,
    required this.meals,
    required this.currentCalories,
    required this.recommendedCalories,
    required this.icon,
    required this.onAddMeal,
  });

  @override
  State<MealDetailWidget> createState() => _MealDetailWidgetState();
}

class _MealDetailWidgetState extends State<MealDetailWidget> {
  final nutritionController = Get.find<NutritionController>();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: getPercentageHeight(85, context),
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
            // Header with meal type and close button
            _buildHeader(context, textTheme, isDarkMode),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(getPercentageWidth(5, context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calories Section
                    _buildCaloriesSection(context, textTheme, isDarkMode),

                    SizedBox(height: getPercentageHeight(2, context)),

                    // Meals List Section
                    _buildMealsSection(context, textTheme, isDarkMode),

                    SizedBox(height: getPercentageHeight(1.5, context)),
                  ],
                ),
              ),
            ),

            // Action buttons
            _buildActionButtons(context, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return Container(
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
            widget.icon,
            color: kAccent,
            size: getIconScale(7, context),
          ),
          SizedBox(width: getPercentageWidth(3, context)),
          Expanded(
            child: Text(
              widget.mealType,
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
                color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
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
    );
  }

  Widget _buildCaloriesSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department,
              color: Colors.orange,
              size: getIconScale(4.5, context),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              'Calories',
              style: textTheme.titleMedium?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(getPercentageWidth(4, context)),
          decoration: BoxDecoration(
            color: isDarkMode
                ? kLightGrey.withValues(alpha: 0.1)
                : kLightGrey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current: ${widget.currentCalories} kcal',
                style: textTheme.bodyMedium?.copyWith(
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: getTextScale(4, context),
                ),
              ),
              SizedBox(height: getPercentageHeight(0.5, context)),
              Text(
                widget.recommendedCalories,
                style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMealsSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.restaurant_menu,
              color: kAccent,
              size: getIconScale(4.5, context),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              'Added Meals (${widget.meals.length})',
              style: textTheme.titleMedium?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        if (widget.meals.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(getPercentageWidth(4, context)),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? kLightGrey.withValues(alpha: 0.1)
                  : kLightGrey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No meals added yet.\nTap "Add Meal" to get started!',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? kLightGrey.withValues(alpha: 0.1)
                  : kLightGrey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: widget.meals.asMap().entries.map((entry) {
                final int index = entry.key;
                final UserMeal meal = entry.value;
                final bool isLast = index == widget.meals.length - 1;

                return Container(
                  decoration: BoxDecoration(
                    border: !isLast
                        ? Border(
                            bottom: BorderSide(
                              color: isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                              width: 0.5,
                            ),
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(getPercentageWidth(3, context)),
                    child: Row(
                      children: [
                        // Meal info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                capitalizeFirstLetter(meal.name),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode ? kWhite : kDarkGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.3, context)),
                              Text(
                                '${meal.quantity} ${meal.servings} • ${meal.calories} kcal',
                                style: textTheme.bodySmall?.copyWith(
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Delete button
                        GestureDetector(
                          onTap: () => _deleteMeal(meal),
                          child: Container(
                            padding:
                                EdgeInsets.all(getPercentageWidth(2, context)),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: getIconScale(4, context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(getPercentageWidth(5, context)),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: getPercentageHeight(1.5, context),
                ),
              ),
              child: Text(
                'Close',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: getPercentageWidth(3, context)),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onAddMeal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: kWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: getPercentageHeight(1.5, context),
                ),
              ),
              child: Text(
                'Add Meal',
                style: textTheme.bodyMedium?.copyWith(
                  color: kWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteMeal(UserMeal meal) {
    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = getThemeProvider(context).isDarkMode;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            'Delete Meal',
            style: textTheme.titleMedium?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to remove "${capitalizeFirstLetter(meal.name)}" from ${widget.mealType}?',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await nutritionController.removeMeal(
                    userService.userId ?? '',
                    widget.mealType,
                    meal,
                    DateTime.now(),
                  );

                  if (mounted) {
                    Navigator.pop(context); // Close confirmation dialog
                    Navigator.pop(context); // Close meal detail modal
                    showTastySnackbar(
                      'Success',
                      'Removed "${capitalizeFirstLetter(meal.name)}" from ${widget.mealType}',
                      context,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    showTastySnackbar(
                      'Error',
                      'Failed to remove meal: $e',
                      context,
                      backgroundColor: kRed,
                    );
                  }
                }
              },
              child: Text(
                'Delete',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
