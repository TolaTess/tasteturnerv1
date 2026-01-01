import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import 'utils.dart';

String calculateRecommendedCaloriesFromGoal(String goal, [String? gender]) {
  final userCalories =
      userService.currentUser.value?.settings['foodGoals'] ?? 2000;

  // Base calorie adjustments based on gender
  double genderMultiplier = 1.0;
  if (gender == 'male') {
    genderMultiplier = 1.1; // Men typically need 10% more calories
  } else if (gender == 'female') {
    genderMultiplier = 0.9; // Women typically need 10% less calories
  }

  int baseCalories = userCalories;

  if (goal == 'Healthy Eating') {
    baseCalories = (userCalories * genderMultiplier).round();
  } else if (goal == 'Lose Weight') {
    baseCalories = (1500 * genderMultiplier).round();
    if (baseCalories > userCalories) {
      baseCalories = userCalories;
    }
  } else if (goal == 'Gain Muscle') {
    baseCalories = (2500 * genderMultiplier).round();
    if (baseCalories < userCalories) {
      baseCalories = userCalories;
    }
  } else {
    baseCalories = (userCalories * genderMultiplier).round();
  }

  return baseCalories.toString();
}

Map<String, int> calculateRecommendedMacrosGoals(String goal,
    [String? gender]) {
  final calories =
      int.parse(calculateRecommendedCaloriesFromGoal(goal, gender));

  // Gender-specific macro adjustments
  double proteinMultiplier = 1.0;
  double carbsMultiplier = 1.0;
  double fatMultiplier = 1.0;

  if (gender == 'male') {
    // Men typically need more protein for muscle building
    proteinMultiplier = 1.15;
    carbsMultiplier = 1.05;
    fatMultiplier = 0.95;
  } else if (gender == 'female') {
    // Women may need slightly different macro ratios
    proteinMultiplier = 1.05;
    carbsMultiplier = 0.98;
    fatMultiplier = 1.02;
  }

  switch (goal) {
    case 'Healthy Eating':
      // Balanced macros: 30% protein, 40% carbs, 30% fat
      return {
        'protein': ((calories * 0.30 / 4) * proteinMultiplier)
            .round(), // 4 cal per gram protein
        'carbs': ((calories * 0.40 / 4) * carbsMultiplier)
            .round(), // 4 cal per gram carb
        'fat': ((calories * 0.30 / 9) * fatMultiplier)
            .round(), // 9 cal per gram fat
        'calories': calories,
      };

    case 'Lose Weight':
      // Higher protein, moderate fat, lower carb
      return {
        'protein':
            ((calories * 0.40 / 4) * proteinMultiplier).round(), // 40% protein
        'carbs': ((calories * 0.30 / 4) * carbsMultiplier).round(), // 30% carbs
        'fat': ((calories * 0.30 / 9) * fatMultiplier).round(), // 30% fat
        'calories': calories,
      };

    case 'Gain Muscle':
      // High protein, high carb, moderate fat
      return {
        'protein':
            ((calories * 0.35 / 4) * proteinMultiplier).round(), // 35% protein
        'carbs': ((calories * 0.45 / 4) * carbsMultiplier).round(), // 45% carbs
        'fat': ((calories * 0.20 / 9) * fatMultiplier).round(), // 20% fat
        'calories': calories,
      };

    default:
      // Default balanced macros
      return {
        'protein': ((calories * 0.30 / 4) * proteinMultiplier).round(),
        'carbs': ((calories * 0.40 / 4) * carbsMultiplier).round(),
        'fat': ((calories * 0.30 / 9) * fatMultiplier).round(),
        'calories': calories,
      };
  }
}

Widget getAvatar(String? avatar, BuildContext context, bool isDarkMode) {
  switch (avatar?.toLowerCase()) {
    case 'infant':
    case 'baby':
      return SvgPicture.asset('assets/images/svg/baby.svg',
          height: getPercentageWidth(7, context),
          width: getPercentageWidth(7, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    case 'toddler':
      return SvgPicture.asset('assets/images/svg/toddler.svg',
          height: getPercentageWidth(7, context),
          width: getPercentageWidth(7, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    case 'child':
      return SvgPicture.asset('assets/images/svg/child.svg',
          height: getPercentageWidth(7, context),
          width: getPercentageWidth(7, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    case 'teen':
      return SvgPicture.asset('assets/images/svg/teen.svg',
          height: getPercentageWidth(6, context),
          width: getPercentageWidth(6, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    default:
      return SvgPicture.asset('assets/images/svg/adult.svg',
          height: getPercentageWidth(6, context),
          width: getPercentageWidth(6, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
  }
}

Color getMealTypeColor(String type) {
  switch (type.toLowerCase()) {
    // Meal types (breakfast, lunch, dinner, snacks)
    case 'bf':
    case 'breakfast':
    case 'b':
      return kAccent.withValues(alpha: 0.5); // Orange for breakfast (morning)
    case 'lh':
    case 'lunch':
    case 'l':
      return kBlue.withValues(alpha: 0.5); // Blue for lunch (midday)
    case 'dn':
    case 'dinner':
    case 'd':
      return kAccentLight.withValues(alpha: 0.5); // Purple for dinner (evening)
    case 'sn':
    case 'snacks':
    case 'snack':
    case 's':
      return kPink.withValues(alpha: 0.5); // Green for snacks
    // Food categories (for backward compatibility)
    case 'protein':
      return kAccent.withValues(alpha: 0.5);
    case 'grain':
      return kBlue.withValues(alpha: 0.5);
    case 'vegetable':
      return kAccentLight.withValues(alpha: 0.5);
    case 'fruit':
      return kPurple.withValues(alpha: 0.5);
    default:
      return kPink.withValues(alpha: 0.5);
  }
}

String getMealTypeImage(String type) {
  switch (type.toLowerCase()) {
    case 'protein':
      return 'assets/images/meat.jpg';
    case 'grain':
      return 'assets/images/grain.jpg';
    case 'vegetable':
      return 'assets/images/vegetable.jpg';
    default:
      return 'assets/images/placeholder.png';
  }
}

Widget buildAddMealTypeLegend(BuildContext context, String mealType,
    {bool isSelected = false, bool isColored = false}) {
  final textTheme = Theme.of(context).textTheme;
  final mealTypeColor = getMealTypeColor(mealType);

  return Container(
    decoration: BoxDecoration(
      color: isSelected
          ? mealTypeColor.withValues(alpha: 0.5)
          : mealTypeColor.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(10),
      border: isSelected ? Border.all(color: mealTypeColor, width: 2) : null,
    ),
    padding: EdgeInsets.symmetric(
      horizontal: getPercentageWidth(2, context),
      vertical: getPercentageHeight(1, context),
    ),
    child: Column(
      children: [
        Icon(Icons.square_rounded,
            color: isSelected ? mealTypeColor : mealTypeColor),
        SizedBox(width: getPercentageWidth(2, context)),
        Text(
          capitalizeFirstLetter(mealType),
          style: textTheme.bodyMedium?.copyWith(
            color: isSelected ? mealTypeColor : mealTypeColor,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

List<MacroData> updateIngredientListByType(
  List<MacroData>
      ingredientList, // Kept for backward compatibility but not used when curatedLists provided
  String selectedCategory, {
  Map<String, List<String>>? curatedLists,
}) {
  // Use time-based seed for better randomization
  final random = Random(DateTime.now().millisecondsSinceEpoch);
  final selectedCategoryLower = selectedCategory.toLowerCase();

  // If curated lists are provided, use them exclusively
  if (curatedLists != null && curatedLists.isNotEmpty) {
    List<String> curatedNames = [];

    // If 'all' or 'general', combine all curated lists with type tracking
    if (selectedCategory.isEmpty ||
        selectedCategoryLower == 'all' ||
        selectedCategoryLower == 'general') {
      // Combine all categories, tracking which category each item belongs to
      final Map<String, String> nameToType = {};
      for (final category in ['protein', 'grain', 'vegetable', 'fruit']) {
        if (curatedLists.containsKey(category) &&
            curatedLists[category]!.isNotEmpty) {
          for (final name in curatedLists[category]!) {
            curatedNames.add(name);
            nameToType[name.toLowerCase()] = category;
          }
        }
      }

      curatedNames.shuffle(random);

      // Create MacroData placeholders from curated names
      final result = curatedNames.take(20).map((name) {
        final type = nameToType[name.toLowerCase()] ?? 'vegetable';
        return MacroData(
          title: name,
          type: type,
          mediaPaths: [],
          macros: {},
          categories: [type],
          features: {},
        );
      }).toList();

      return result;
    } else if (curatedLists.containsKey(selectedCategoryLower) &&
        curatedLists[selectedCategoryLower]!.isNotEmpty) {
      // Use specific category
      curatedNames = List<String>.from(curatedLists[selectedCategoryLower]!);
      curatedNames.shuffle(random);

      // Create MacroData placeholders from curated names
      final result = curatedNames.take(20).map((name) {
        return MacroData(
          title: name,
          type: selectedCategoryLower,
          mediaPaths: [],
          macros: {},
          categories: [selectedCategoryLower],
          features: {},
        );
      }).toList();

      return result;
    }
    // If curated lists provided but category not found, return empty (shouldn't happen with proper data)
    return [];
  }

  // Fallback to original filtering logic only if curated lists are not available
  // If ingredientList is empty, try to use fallback lists from constants
  if (ingredientList.isEmpty) {
    final fallbackLists = fallbackSpinWheelIngredients;
    if (fallbackLists.isNotEmpty) {
      List<String> fallbackNames = [];

      if (selectedCategory.isEmpty ||
          selectedCategoryLower == 'all' ||
          selectedCategoryLower == 'general') {
        // Combine all fallback categories
        final Map<String, String> nameToType = {};
        for (final category in ['protein', 'grain', 'vegetable', 'fruit']) {
          if (fallbackLists.containsKey(category) &&
              fallbackLists[category]!.isNotEmpty) {
            for (final name in fallbackLists[category]!) {
              fallbackNames.add(name);
              nameToType[name.toLowerCase()] = category;
            }
          }
        }
        fallbackNames.shuffle(random);
        return fallbackNames.take(20).map((name) {
          final type = nameToType[name.toLowerCase()] ?? 'vegetable';
          return MacroData(
            title: name,
            type: type,
            mediaPaths: [],
            macros: {},
            categories: [type],
            features: {},
          );
        }).toList();
      } else if (fallbackLists.containsKey(selectedCategoryLower) &&
          fallbackLists[selectedCategoryLower]!.isNotEmpty) {
        fallbackNames =
            List<String>.from(fallbackLists[selectedCategoryLower]!);
        fallbackNames.shuffle(random);
        return fallbackNames.take(20).map((name) {
          return MacroData(
            title: name,
            type: selectedCategoryLower,
            mediaPaths: [],
            macros: {},
            categories: [selectedCategoryLower],
            features: {},
          );
        }).toList();
      }
    }
  }
  if (selectedCategory.isEmpty ||
      selectedCategory == 'all' ||
      selectedCategory == 'general') {
    final shuffledIngredients = List<MacroData>.from(ingredientList);
    shuffledIngredients.shuffle(random);
    return shuffledIngredients.take(20).toList();
  }

  final newIngredientList = ingredientList.where((ingredient) {
    final ingredientType = ingredient.type.toLowerCase();

    // Primary check: exact type match or type contains the category
    if (ingredientType == selectedCategoryLower ||
        ingredientType.contains(selectedCategoryLower)) {
      return true;
    }

    // Secondary check: only use categories for specific mappings
    // and be more strict about the matching
    switch (selectedCategoryLower) {
      case 'protein':
        // Check if type is protein or if categories contain exact "protein" match
        return ingredientType == 'protein';
      case 'grain':
        return ingredientType == 'grain';
      case 'vegetable':
        return ingredientType == 'vegetable';
      case 'fruit':
        return ingredientType == 'fruit';
      default:
        // For other categories, check if any category exactly matches
        return ingredient.categories
            .any((category) => category.toLowerCase() == selectedCategoryLower);
    }
  }).toList();

  // Shuffle the filtered list for randomization with time-based seed
  newIngredientList.shuffle(random);

  return newIngredientList.length > 20
      ? newIngredientList.take(20).toList()
      : newIngredientList.toList();
}

/// Global error dialog for meal generation failures
void showMealGenerationErrorDialog(BuildContext context, String message,
    {VoidCallback? onRetry}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Meal Generation Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text('Try Again'),
            ),
        ],
      );
    },
  );
}
