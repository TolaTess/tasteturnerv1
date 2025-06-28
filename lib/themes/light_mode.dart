import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';
import '../helper/utils.dart';

class ThemeManager {
  ThemeManager._();

  static final ThemeManager _instance = ThemeManager._();

  factory ThemeManager() => _instance;

  ThemeData mainTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: kBackgroundColor,
      fontFamily: GoogleFonts.chivo().fontFamily,
      appBarTheme: appBarTheme(),
      textTheme: textTheme(context),
      iconTheme: iconTheme(),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: false,
    );
  }

  IconThemeData iconTheme() => const IconThemeData(
        color: kBlack,
        size: kIconSizeMedium,
      );

  TextTheme textTheme(BuildContext context) {
    final baseTextTheme = GoogleFonts.chivoTextTheme();
    final accentFont = GoogleFonts.caveat();
    final headingFont = GoogleFonts.blackOpsOne();

    return TextTheme(
      // Display styles - using Caveat for artistic accent
      displayLarge: accentFont.copyWith(
        fontSize: getTextScale(10, context),
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),
      displayMedium: headingFont.copyWith(
        fontSize: getTextScale(6, context),
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),
      displaySmall: accentFont.copyWith(
        fontSize: getTextScale(8, context),
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),
      // Headline styles - using Chivo for main text
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: getTextScale(7, context),
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: getTextScale(6, context),
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: getTextScale(5, context),
        fontWeight: FontWeight.bold,
        color: kBlack,
      ),

      // Title styles - using Chivo
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: getTextScale(4.5, context),
        fontWeight: FontWeight.w600,
        color: kBlack,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: getTextScale(4, context),
        fontWeight: FontWeight.w600,
        color: kBlack,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: getTextScale(3.5, context),
        fontWeight: FontWeight.w500,
        color: kBlack,
      ),

      // Body styles - using Chivo
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: getTextScale(4, context),
        color: kBlack,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: getTextScale(3.5, context),
        color: kBlack,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: getTextScale(3, context),
        color: kBlack,
      ),

      // Label styles - using Chivo
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: getTextScale(3.5, context),
        fontWeight: FontWeight.w600,
        color: kBlack,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: getTextScale(3, context),
        fontWeight: FontWeight.w500,
        color: kBlack,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: getTextScale(2.5, context),
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
