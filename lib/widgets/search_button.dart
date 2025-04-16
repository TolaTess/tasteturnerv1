import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../screens/recipes_list_category_screen.dart';

class SearchButton extends StatelessWidget {
  const SearchButton({super.key, required this.press, required this.kText});

  final VoidCallback press;
  final String kText;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 4,
              ),
              child: Icon(
                Icons.search,
                color: kBlack,
              ),
            ),
            Expanded(
              child: Text(
                kText,
                style: const TextStyle(
                  color: kDarkGrey,
                  fontSize: 14,
                ),
              ),
            ),
            // const Padding(
            //   padding: EdgeInsets.symmetric(horizontal: 10),
            //   child: Icon(
            //     Icons.tune_outlined,
            //     color: kPrimaryColor,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

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
    return SafeTextField(
      style: TextStyle(color: isDarkMode ? kBlack : kWhite),
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: kText,
        hintStyle: TextStyle(color: isDarkMode ? kBlack : kWhite),
        prefixIcon: Icon(Icons.search, color: isDarkMode ? kBlack : kWhite),
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
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode
              ? kDarkModeAccent.withOpacity(0.08)
              : kAccent.withOpacity(0.60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSaved
                  ? Icons.save
                  : widget.icon, // Show save icon if on spin screen
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isSaved
                  ? "Save"
                  : widget.text, // Show "Save" text if on spin screen
              style: const TextStyle(),
            ),
          ],
        ),
      ),
    );
  }
}
