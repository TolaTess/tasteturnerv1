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
                onCategorySelected(category['id'], category['name']);
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context)),
              margin: EdgeInsets.only(right: getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color: selectedCategoryId == category['id']
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
                  category['name'].toLowerCase() == 'all'
                      ? 'General'
                      : category['name'].toLowerCase() == 'balanced'
                          ? 'Balanced'
                          : capitalizeFirstLetter(category['name']),
                  style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? kWhite : kBlack, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
