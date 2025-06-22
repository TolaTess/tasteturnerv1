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
        size: kIconSizeMedium,
      );

  TextTheme textTheme() {
    return const TextTheme(
      displayLarge:
          TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold, color: kBlack),
      displayMedium:
          TextStyle(fontSize: 45.0, fontWeight: FontWeight.bold, color: kBlack),
      displaySmall:
          TextStyle(fontSize: 36.0, fontWeight: FontWeight.bold, color: kBlack),
      headlineLarge:
          TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: kBlack),
      headlineMedium:
          TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: kBlack),
      headlineSmall:
          TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: kBlack),
      titleLarge:
          TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600, color: kBlack),
      titleMedium:
          TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: kBlack),
      titleSmall:
          TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500, color: kBlack),
      bodyLarge: TextStyle(fontSize: 16.0, color: kBlack),
      bodyMedium: TextStyle(fontSize: 14.0, color: kBlack),
      bodySmall: TextStyle(fontSize: 12.0, color: kBlack),
      labelLarge:
          TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: kBlack),
      labelMedium:
          TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, color: kBlack),
      labelSmall:
          TextStyle(fontSize: 11.0, fontWeight: FontWeight.w400, color: kBlack),
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
