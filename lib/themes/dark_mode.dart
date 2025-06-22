import 'package:flutter/material.dart';

import '../constants.dart';

class ThemeDarkManager {
  ThemeDarkManager._();

  static final ThemeDarkManager _instance = ThemeDarkManager._();

  factory ThemeDarkManager() => _instance;

  ThemeData mainTheme() {
    return ThemeData(
      scaffoldBackgroundColor: kBackgroundDarkColor,
      fontFamily: "Poppins",
      appBarTheme: appBarTheme(),
      textTheme: textTheme(),
      iconTheme: iconTheme(),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: false,
    );
  }

  IconThemeData iconTheme() => const IconThemeData(
        color: kWhite,
        size: kIconSizeMedium,
      );

  TextTheme textTheme() {
    return const TextTheme(
      displayLarge:
          TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold, color: kWhite),
      displayMedium:
          TextStyle(fontSize: 45.0, fontWeight: FontWeight.bold, color: kWhite),
      displaySmall:
          TextStyle(fontSize: 36.0, fontWeight: FontWeight.bold, color: kWhite),
      headlineLarge:
          TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: kWhite),
      headlineMedium:
          TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: kWhite),
      headlineSmall:
          TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: kWhite),
      titleLarge:
          TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600, color: kWhite),
      titleMedium:
          TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: kWhite),
      titleSmall:
          TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500, color: kWhite),
      bodyLarge: TextStyle(fontSize: 16.0, color: kWhite),
      bodyMedium: TextStyle(fontSize: 14.0, color: kWhite),
      bodySmall: TextStyle(fontSize: 12.0, color: kWhite),
      labelLarge:
          TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: kWhite),
      labelMedium:
          TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, color: kWhite),
      labelSmall:
          TextStyle(fontSize: 11.0, fontWeight: FontWeight.w400, color: kWhite),
    );
  }

  AppBarTheme appBarTheme() {
    return const AppBarTheme(
      color: kDarkGrey,
      elevation: 0,
      iconTheme: IconThemeData(color: kWhite),
      titleTextStyle: TextStyle(
        color: kWhite,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  DividerThemeData dividerThemeDarkData() {
    return const DividerThemeData(color: kBackgroundColor, thickness: 0.7);
  }
}
