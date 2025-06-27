import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';

class ThemeManager {
  ThemeManager._();

  static final ThemeManager _instance = ThemeManager._();

  factory ThemeManager() => _instance;

  ThemeData mainTheme() {
    return ThemeData(
      scaffoldBackgroundColor: kBackgroundColor,
      fontFamily: GoogleFonts.chivo().fontFamily,
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
    final baseTextTheme = GoogleFonts.chivoTextTheme();
    final accentFont = GoogleFonts.caveat();
    final headingFont = GoogleFonts.blackOpsOne();

    return TextTheme(
      // Display styles - using Caveat for artistic accent
      displayLarge: accentFont.copyWith(
        fontSize: 57.0,
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),
      displayMedium: headingFont.copyWith(
        fontSize: 25.0,
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),
      displaySmall: accentFont.copyWith(
        fontSize: 36.0,
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),
      // Headline styles - using Chivo for main text
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 28.0,
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),

      // Title styles - using Chivo
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 22.0,
        fontWeight: FontWeight.w600,
        color: kBlack,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: kBlack,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        color: kBlack,
      ),

      // Body styles - using Chivo
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16.0,
        color: kBlack,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14.0,
        color: kBlack,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12.0,
        color: kBlack,
      ),

      // Label styles - using Chivo
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: kBlack,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: kBlack,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11.0,
        fontWeight: FontWeight.w400,
        color: kBlack,
      ),
    );
  }

  AppBarTheme appBarTheme() {
    return AppBarTheme(
      color: kBackgroundColor,
      elevation: 0,
      iconTheme: const IconThemeData(color: kBlack, size: 28),
      titleTextStyle: GoogleFonts.chivo(
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
