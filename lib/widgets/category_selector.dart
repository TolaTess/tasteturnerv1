import 'package:flutter/material.dart';

class CategorySelector extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String selectedCategoryId;
  final Function(String id, String name) onCategorySelected;
  final bool isDarkMode;
  final Color accentColor;
  final Color darkModeAccentColor;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.isDarkMode,
    required this.accentColor,
    required this.darkModeAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        itemCount: categories.length,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 24, right: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          return GestureDetector(
            onTap: () => onCategorySelected(category['id'], category['name']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              margin: const EdgeInsets.only(right: 12),
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
                      : category['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
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
