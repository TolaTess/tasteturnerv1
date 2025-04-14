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
        size: 24,
      );

  TextTheme textTheme() {
    return const TextTheme(
      bodyLarge: TextStyle(
        color: kWhite,
        fontWeight: FontWeight.w100,
        fontSize: 12,
      ),
      bodyMedium: TextStyle(
        color: kWhite,
        fontSize: 12,
      ),
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
