import 'package:flutter/material.dart';

import '../constants.dart';

class ThemeManager {
  ThemeManager._();

  static final ThemeManager _instance = ThemeManager._();

  factory ThemeManager() => _instance;

  ThemeData mainTheme() {
    return ThemeData(
      scaffoldBackgroundColor: kBackgroundColor,
      fontFamily: "Poppins",
      appBarTheme: appBarTheme(),
      textTheme: textTheme(),
      iconTheme: iconTheme(),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: false,
    );
  }

  IconThemeData iconTheme() => const IconThemeData(
        color: kBlack,
        size: 24,
      );

  TextTheme textTheme() {
    return const TextTheme(
      bodyLarge: TextStyle(
        color: kBlack,
        fontWeight: FontWeight.w100,
        fontSize: 12,
      ),
      bodyMedium: TextStyle(
        color: kBlack,
        fontSize: 12,
      ),
    );
  }

  AppBarTheme appBarTheme() {
    return const AppBarTheme(
      color: kBackgroundColor,
      elevation: 0,
      iconTheme: IconThemeData(color: kBlack, size: 28),
      titleTextStyle: TextStyle(
        color: kBlack,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  DividerThemeData dividerThemeData() {
    return const DividerThemeData(color: kBlack, thickness: 0.7);
  }
}
