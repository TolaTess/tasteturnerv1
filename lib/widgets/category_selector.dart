import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';

class CategorySelector extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String selectedCategoryId;
  final Function(String id, String name) onCategorySelected;
  final bool isDarkMode;
  final Color accentColor;
  final Color darkModeAccentColor;
  final bool isFunMode;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.isDarkMode,
    required this.accentColor,
    required this.darkModeAccentColor,
    this.isFunMode = false,
  });

  String _getCategoryDisplayName(dynamic categoryName) {
    // Handle case where categoryName might be a Map or null
    if (categoryName == null) return 'Unknown';

    String name;
    if (categoryName is String) {
      name = categoryName;
    } else if (categoryName is Map<String, dynamic>) {
      // If it's a map, try to extract the name from it
      name = categoryName['name']?.toString() ?? 'Unknown';
    } else {
      name = categoryName.toString();
    }

    // Now safely apply the logic
    if (name.toLowerCase() == 'all') {
      return 'General';
    } else if (name.toLowerCase() == 'balanced') {
      return 'Balanced';
    } else {
      return capitalizeFirstLetter(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return SizedBox(
      height: getPercentageHeight(5, context),
      child: ListView.builder(
        itemCount: categories.length,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(
            left: getPercentageWidth(3, context),
            right: getPercentageWidth(3, context)),
        itemBuilder: (context, index) {
          final category = categories[index];
          return GestureDetector(
            onTap: () {
              if (category['id'] != null && category['name'] != null) {
                // Safely extract the name
                String name;
                if (category['name'] is String) {
                  name = category['name'];
                } else if (category['name'] is Map<String, dynamic>) {
                  name = category['name']['name']?.toString() ?? 'Unknown';
                } else {
                  name = category['name'].toString();
                }
                onCategorySelected(category['id'], name);
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context)),
              margin: EdgeInsets.only(right: getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color: selectedCategoryId == (category['id']?.toString() ?? '')
                    ? isDarkMode
                        ? darkModeAccentColor.withOpacity(0.50)
                        : accentColor.withOpacity(0.60)
                    : isDarkMode
                        ? darkModeAccentColor.withOpacity(0.08)
                        : accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Text(
                  _getCategoryDisplayName(category['name']),
                  style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? kWhite : kBlack,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
