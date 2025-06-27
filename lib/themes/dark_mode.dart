import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';

class ThemeDarkManager {
  ThemeDarkManager._();

  static final ThemeDarkManager _instance = ThemeDarkManager._();

  factory ThemeDarkManager() => _instance;

  ThemeData mainTheme() {
    return ThemeData(
      scaffoldBackgroundColor: kBackgroundDarkColor,
      fontFamily: GoogleFonts.chivo().fontFamily,
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
    final baseTextTheme = GoogleFonts.chivoTextTheme();
    final accentFont = GoogleFonts.caveat();
    final headingFont = GoogleFonts.blackOpsOne();

    return TextTheme(
      // Display styles - using Caveat for artistic accent
      displayLarge: accentFont.copyWith(
        fontSize: 57.0,
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),
      displayMedium: headingFont.copyWith(
        fontSize: 25.0,
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),
      displaySmall: accentFont.copyWith(
        fontSize: 36.0,
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),
      // Headline styles - using Chivo for main text
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 28.0,
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),

      // Title styles - using Chivo
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 22.0,
        fontWeight: FontWeight.w600,
        color: kWhite,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: kWhite,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        color: kWhite,
      ),

      // Body styles - using Chivo
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16.0,
        color: kWhite,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14.0,
        color: kWhite,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12.0,
        color: kWhite,
      ),

      // Label styles - using Chivo
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: kWhite,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: kWhite,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11.0,
        fontWeight: FontWeight.w400,
        color: kWhite,
      ),
    );
  }

  AppBarTheme appBarTheme() {
    return AppBarTheme(
      color: kDarkGrey,
      elevation: 0,
      iconTheme: const IconThemeData(color: kWhite),
      titleTextStyle: GoogleFonts.chivo(
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
