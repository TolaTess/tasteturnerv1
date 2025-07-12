import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../screens/recipes_list_category_screen.dart';

class SearchButton2 extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final String kText;

  const SearchButton2({
    Key? key,
    required this.controller,
    required this.onChanged,
    required this.kText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return SafeTextField(
      style: textTheme.bodyMedium?.copyWith(
          color: isDarkMode ? kBlack : kWhite,
          fontSize: getTextScale(4, context)),
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: kText,
        hintStyle: textTheme.bodyMedium?.copyWith(
            color: isDarkMode ? kBlack : kWhite,
            fontSize: getTextScale(4, context)),
        prefixIcon: Icon(Icons.search,
            color: isDarkMode ? kBlack : kWhite,
            size: getIconScale(6, context)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDarkMode ? kWhite : kDarkGrey,
      ),
    );
  }
}

class ThirdButton extends StatefulWidget {
  final IconData icon;
  final String text, screen;
  final VoidCallback onToggleEdit;
  final String? date;

  const ThirdButton({
    super.key,
    required this.icon,
    required this.text,
    required this.screen,
    required this.onToggleEdit,
    this.date,
  });

  @override
  State<ThirdButton> createState() => _ThirdButtonState();
}

class _ThirdButtonState extends State<ThirdButton> {
  bool isEdit = true;
  bool isSaved = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      child: ElevatedButton(
        onPressed: () {
          if (widget.screen == spin) {
            setState(() {
              // Toggle between isEdit and isSaved
              isEdit = !isEdit;
              isSaved = !isEdit;
            });
            widget.onToggleEdit(); // Call the onToggleEdit callback
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RecipeListCategory(
                  index: 4,
                  searchIngredient: '',
                  isMealplan: true,
                  mealPlanDate: widget.date,
                  isNoTechnique: true,
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode
              ? kDarkModeAccent.withValues(alpha: 0.08)
              : kAccent.withValues(alpha: 0.60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSaved
                  ? Icons.save_alt
                  : widget.icon, // Show save icon if on spin screen
              size: getPercentageWidth(2, context),
            ),
            SizedBox(width: getPercentageWidth(0.8, context)),
            Text(
              isSaved
                  ? "Save"
                  : widget.text, // Show "Save" text if on spin screen
              style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? kBlack : kWhite,
                  fontSize: getTextScale(4, context)),
            ),
          ],
        ),
      ),
    );
  }
}
