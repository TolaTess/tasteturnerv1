import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../themes/theme_provider.dart';

// Secondary button with padding, width depend on the text length.

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.text,
    required this.press,
  });

  final String text;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: themeProvider.isDarkMode
            ? kDarkModeAccent.withOpacity(0.50)
            : kAccentLight.withOpacity(0.50),
        padding: const EdgeInsets.symmetric(
          horizontal: 30,
          vertical: 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: press,
      child: Text(
        text,
        style: TextStyle(
          color: themeProvider.isDarkMode
              ? kWhite
              : kBlack,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
