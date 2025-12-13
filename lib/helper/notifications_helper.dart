// Check if we've already sent a notification today for steps goal
// and send one if we haven't
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../widgets/premium_widget.dart';
import 'utils.dart';

Future<void> deleteImagesFromStorage(List<String> imageUrls,
    {String? folder}) async {
  for (var url in imageUrls) {
    if (url.startsWith('http')) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        final imageName = segments.isNotEmpty ? segments.last : null;
        if (imageName != null) {
          final storagePath = extractStoragePathFromUrl(url);
          if (storagePath != null) {
            final ref = firebaseStorage.ref().child(storagePath);
            await ref.delete();
          }
        }
      } catch (e) {
        final context = Get.context;
        if (context != null) {
          showTastySnackbar(
              'Something went wrong', 'Please try again later', context,
              backgroundColor: kRed);
        }
      }
    }
  }
}

String? extractStoragePathFromUrl(String url) {
  final uri = Uri.parse(url);
  final path = uri.path; // e.g. /v0/b/<bucket>/o/post_images%2Fabc123.jpg
  final oIndex = path.indexOf('/o/');
  if (oIndex == -1) return null;
  final encodedFullPath = path.substring(oIndex + 3); // after '/o/'
  // Remove any trailing segments after the file path (e.g., before '?')
  final questionMarkIndex = encodedFullPath.indexOf('?');
  final encodedPath = questionMarkIndex == -1
      ? encodedFullPath
      : encodedFullPath.substring(0, questionMarkIndex);
  return Uri.decodeFull(encodedPath);
}

Widget getAdsWidget(bool isPremium, {bool isDiv = false}) {
  return Container(
    child: isPremium
        ? const SizedBox.shrink()
        : PremiumSection(
            isPremium: isPremium,
            titleOne: joinChallenges,
            titleTwo: premium,
            isDiv: isDiv,
          ),
  );
}

Widget buildSuggestionCard(BuildContext context, String title,
    List<dynamic> items, IconData icon, Color color) {
  final isDarkMode = getThemeProvider(context).isDarkMode;

  return GestureDetector(
    onTap: () => _showSuggestionDialog(context, title, items, icon, color),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: getIconScale(6, context),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: getTextScale(3, context),
              fontWeight: FontWeight.w600,
              color: isDarkMode ? kWhite : kDarkGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${items.length} ${items.length == 1 ? 'item' : 'items'}',
            style: TextStyle(
              fontSize: getTextScale(2.5, context),
              color: isDarkMode
                  ? kWhite.withValues(alpha: 0.7)
                  : kDarkGrey.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showSuggestionDialog(BuildContext context, String title,
    List<dynamic> items, IconData icon, Color color) {
  showDialog(
    context: context,
    builder: (context) {
      final isDarkMode = getThemeProvider(context).isDarkMode;
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Row(
          children: [
            Icon(icon, color: color, size: getIconScale(5, context)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: kAccent,
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 6, right: 8),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.toString(),
                              style: TextStyle(
                                fontSize: getTextScale(3.5, context),
                                color: isDarkMode ? kWhite : kDarkGrey,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(
                color: kAccent,
                fontSize: getTextScale(4, context),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget buildSuggestionsSection(BuildContext context,
    Map<String, dynamic> _editableAnalysis, bool isRecipe) {
  final isDarkMode = getThemeProvider(context).isDarkMode;
  final suggestionsRaw = _editableAnalysis['suggestions'];
  final suggestions =
      suggestionsRaw is Map ? Map<String, dynamic>.from(suggestionsRaw) : null;

  if (suggestions == null) return const SizedBox.shrink();

  final additions = suggestions['additions'] as List<dynamic>? ?? [];
  final alternatives = suggestions['alternatives'] as List<dynamic>? ?? [];
  final improvements = suggestions['improvements'] as List<dynamic>? ?? [];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Sous Chef Suggestions',
        style: isRecipe
            ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: getTextScale(4, context),
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? kWhite : kDarkGrey,
                )
            : Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: getTextScale(5, context),
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? kWhite : kDarkGrey,
                ),
      ),
      SizedBox(height: getPercentageHeight(isRecipe ? 2 : 1, context)),
      Row(
        children: [
          if (additions.isNotEmpty)
            Expanded(
              child: buildSuggestionCard(
                context,
                'Additions',
                additions,
                Icons.add_circle_outline,
                Colors.green,
              ),
            ),
          if (additions.isNotEmpty && alternatives.isNotEmpty)
            const SizedBox(width: 8),
          if (alternatives.isNotEmpty)
            Expanded(
              child: buildSuggestionCard(
                context,
                'Alternatives',
                alternatives,
                Icons.swap_horiz,
                Colors.blue,
              ),
            ),
          if ((additions.isNotEmpty || alternatives.isNotEmpty) &&
              improvements.isNotEmpty)
            const SizedBox(width: 8),
          if (improvements.isNotEmpty)
            Expanded(
              child: buildSuggestionCard(
                context,
                'Improvements',
                improvements,
                Icons.trending_up,
                Colors.orange,
              ),
            ),
        ],
      ),
    ],
  );
}

num? parseToNumber(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    return value;
  }
  if (value is String) {
    // Handle percentage strings by removing % and converting to decimal
    if (value.contains('%')) {
      final percentageString = value.replaceAll('%', '').trim();
      final percentageNumber = num.tryParse(percentageString);
      if (percentageNumber != null) {
        // Convert percentage to decimal (e.g., 45% -> 0.45)
        return percentageNumber / 100;
      }
    }
    return num.tryParse(value);
  }
  return null;
}

String getRecommendedCalories(String mealType, String screen,
    {String? notAllowedMealType, Map<String, dynamic>? selectedUser}) {
  // Use selected user's data if provided, otherwise fall back to current user
  Map<String, dynamic>? settings;
  if (selectedUser != null) {
    if (selectedUser['settings'] != null) {
      // If settings exist (current user), use them
      settings = selectedUser['settings'];
    } else {
      // For family members, create settings from their direct properties
      settings = {
        'foodGoal': selectedUser['foodGoal'],
        'fitnessGoal': selectedUser['fitnessGoal'],
        'ageGroup': selectedUser['ageGroup'],
      };
    }
  } else {
    settings = userService.currentUser.value?.settings;
  }

  final foodGoalValue = settings?['foodGoal'];
  final baseTargetCalories = (parseToNumber(foodGoalValue) ?? 2000).toDouble();

  // Calculate adjusted total target based on fitness goal ranges
  final minTotalTarget = baseTargetCalories * 0.8; // Weight loss range
  final maxTotalTarget = baseTargetCalories * 1.0; // Muscle gain range

  // Updated calorie distribution based on notAllowedMealType
  double percentage = 0.0;

  // Check if both snacks and fruits are not allowed
  bool isSnacksNotAllowed = notAllowedMealType == 'snack' ||
      notAllowedMealType == 'snack,fruit' ||
      notAllowedMealType == 'fruit,snack';
  bool isFruitsNotAllowed = notAllowedMealType == 'fruit' ||
      notAllowedMealType == 'snack,fruit' ||
      notAllowedMealType == 'fruit,snack';

  switch (mealType) {
    case 'Breakfast':
      percentage = 0.25; // 25% - always the same
      break;
    case 'Lunch':
      if (isSnacksNotAllowed || isFruitsNotAllowed) {
        // If snacks or fruits are not allowed, redistribute their calories to main meals
        percentage = 0.35; // Increased from 32.5% to 35%
      } else {
        percentage = 0.325; // 32.5% - normal distribution
      }
      break;
    case 'Dinner':
      if (isSnacksNotAllowed || isFruitsNotAllowed) {
        // If snacks or fruits are not allowed, redistribute their calories to main meals
        percentage = 0.35; // Increased from 32.5% to 35%
      } else {
        percentage = 0.325; // 32.5% - normal distribution
      }
      break;
    case 'Snacks':
      if (isSnacksNotAllowed) {
        percentage = 0.0; // Not allowed
      } else if (isFruitsNotAllowed) {
        // If only fruits are not allowed, snacks get more calories
        percentage = 0.10; // decreased from 10% to 5%
      } else {
        percentage = 0.05; // 10% - normal distribution
      }
      break;
    case 'Fruits':
      if (isFruitsNotAllowed) {
        percentage = 0.0; // Not allowed
      } else if (isSnacksNotAllowed) {
        // If only snacks are not allowed, fruits get more calories
        percentage = 0.10; // decreased from 10% to 5%
      } else {
        percentage = 0.05; // 10% - normal distribution
      }
      break;
  }

  // Apply percentage to the adjusted totals
  final minMealCalories = minTotalTarget * percentage;
  final maxMealCalories = maxTotalTarget * percentage;

  final result = screen == 'addFood'
      ? 'Recommended ${minMealCalories.round()} - ${maxMealCalories.round()} kcal'
      : '${minMealCalories.round()}-${maxMealCalories.round()} kcal';

  return result;
}

/// Shows a dialog when user exceeds recommended calories for a meal type
/// and offers to adjust subsequent meals to compensate
Future<bool> showCalorieAdjustmentDialog(
  BuildContext context,
  String mealType,
  int currentCalories,
  int minRecommended,
  int maxRecommended,
  String? notAllowedMealType,
) async {
  final isDarkMode = getThemeProvider(context).isDarkMode;
  final textTheme = Theme.of(context).textTheme;

  // Calculate overage
  final overage = currentCalories - maxRecommended;

  if (overage <= 0) return false; // No overage, no need to show dialog

  // Determine which meal to adjust based on current meal type
  String adjustmentMealType = '';
  switch (mealType.toLowerCase()) {
    case 'breakfast':
      adjustmentMealType = 'Lunch';
      break;
    case 'lunch':
      adjustmentMealType = 'Dinner';
      break;
    case 'dinner':
      adjustmentMealType = notAllowedMealType == 'snack' ? 'Fruits' : 'Snacks';
      break;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: getIconScale(6, context),
          ),
          SizedBox(width: getPercentageWidth(2, context)),
          Expanded(
            child: Text(
              'Calorie Adjustment',
              style: textTheme.titleLarge?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You\'ve exceeded your $mealType target by $overage calories.',
            style: textTheme.bodyLarge?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Container(
            padding: EdgeInsets.all(getPercentageWidth(3, context)),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: $currentCalories kcal',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Recommended: $minRecommended - $maxRecommended kcal',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Overage: $overage kcal',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Text(
            'Would you like to adjust your $adjustmentMealType by reducing it by $overage calories to compensate?',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode
                  ? kWhite.withValues(alpha: 0.8)
                  : kBlack.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'No, Keep Current',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: kWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Yes, Adjust $adjustmentMealType',
            style: textTheme.bodyMedium?.copyWith(
              color: kWhite,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Extracts min and max calories from a recommendation string
Map<String, int> extractCalorieRange(String recommendation) {
  // Handle both formats: "Recommended 360 - 450 kcal" and "360-450 kcal"
  final regex = RegExp(r'(\d+)\s*-\s*(\d+)');
  final match = regex.firstMatch(recommendation);

  if (match != null) {
    return {
      'min': int.parse(match.group(1)!),
      'max': int.parse(match.group(2)!),
    };
  }

  return {'min': 0, 'max': 0};
}

/// Adjusts the recommended calories for a meal type to compensate for overage
String getAdjustedRecommendedCalories(
    String mealType, String screen, int overageCalories,
    {String? notAllowedMealType, Map<String, dynamic>? selectedUser}) {
  final originalRecommendation = getRecommendedCalories(mealType, screen,
      notAllowedMealType: notAllowedMealType, selectedUser: selectedUser);
  final range = extractCalorieRange(originalRecommendation);

  if (range['min']! > 0 && range['max']! > 0) {
    // Reduce both min and max by the overage
    final adjustedMin =
        (range['min']! - overageCalories).clamp(0, range['min']!);
    final adjustedMax =
        (range['max']! - overageCalories).clamp(0, range['max']!);

    if (screen == 'addFood') {
      return 'Adjusted: ${adjustedMin.round()} - ${adjustedMax.round()} kcal';
    } else {
      return '${adjustedMin.round()}-${adjustedMax.round()} kcal';
    }
  }

  return originalRecommendation;
}
