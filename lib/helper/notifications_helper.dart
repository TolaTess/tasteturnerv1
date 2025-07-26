// Check if we've already sent a notification today for steps goal
// and send one if we haven't
import 'package:flutter/material.dart';

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
        print('Error deleting image from storage: $e');
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
  final suggestions = _editableAnalysis['suggestions'] as Map<String, dynamic>?;

  if (suggestions == null) return const SizedBox.shrink();

  final additions = suggestions['additions'] as List<dynamic>? ?? [];
  final alternatives = suggestions['alternatives'] as List<dynamic>? ?? [];
  final improvements = suggestions['improvements'] as List<dynamic>? ?? [];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'AI Suggestions',
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

String getRecommendedCalories(String mealType, String screen) {
  final settings = userService.currentUser.value?.settings;
  final foodGoalValue = settings?['foodGoal'];
  final baseTargetCalories = (parseToNumber(foodGoalValue) ?? 2000).toDouble();

  // Calculate adjusted total target based on fitness goal ranges
  final minTotalTarget = baseTargetCalories * 0.8; // Weight loss range
  final maxTotalTarget = baseTargetCalories * 1.0; // Muscle gain range

  // Updated calorie distribution for 3 main meals only (no separate snack allocation)
  double percentage = 0.0;
  switch (mealType) {
    case 'Breakfast':
      percentage = 0.25; // 25%
      break;
    case 'Lunch':
      percentage = 0.375; // 37.5%
      break;
    case 'Dinner':
      percentage = 0.375; // 37.5%
      break;
    case 'Snacks':
      // Snacks are now part of lunch/dinner, no separate allocation
      percentage = 0.0;
      break;
  }

  // Apply percentage to the adjusted totals
  final minMealCalories = minTotalTarget * percentage;
  final maxMealCalories = maxTotalTarget * percentage;

  if (screen == 'addFood') {
    return 'Recommended ${minMealCalories.round()} - ${maxMealCalories.round()} kcal';
  } else {
    return '${minMealCalories.round()}-${maxMealCalories.round()} kcal';
  }
}
