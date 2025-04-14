import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';

class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.press,
    this.title = follow,
    this.h = 40,
    this.w = 100,
  });

  final VoidCallback press; // Action when the button is pressed
  final String title;
  final double h, w;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
      return SizedBox(
      width: w, // Set the desired width
      height: h, // Set the desired height
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero, // Remove extra padding
          backgroundColor: isDarkMode
              ? kLightGrey.withOpacity(0.35)
              : kAccent.withOpacity(kOpacity),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Adjust as needed
          ),
        ),
        onPressed: press, // Use the passed-in `press` callback here
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14, // Adjust font size for smaller button
          ),
        ),
      ),
    );
  }
}
