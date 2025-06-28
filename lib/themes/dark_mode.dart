import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';
import '../helper/utils.dart';

class ThemeDarkManager {
  ThemeDarkManager._();

  static final ThemeDarkManager _instance = ThemeDarkManager._();

  factory ThemeDarkManager() => _instance;

  ThemeData mainTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: kBackgroundDarkColor,
      fontFamily: GoogleFonts.chivo().fontFamily,
      appBarTheme: appBarTheme(),
      textTheme: textTheme(context),
      iconTheme: iconTheme(),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: false,
    );
  }

  IconThemeData iconTheme() => const IconThemeData(
        color: kWhite,
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
        color: kWhite,
      ),
      displayMedium: headingFont.copyWith(
        fontSize: getTextScale(6, context),
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),
      displaySmall: accentFont.copyWith(
        fontSize: getTextScale(8, context),
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),
      // Headline styles - using Chivo for main text
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: getTextScale(7, context),
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: getTextScale(6, context),
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: getTextScale(5, context),
        fontWeight: FontWeight.bold,
        color: kWhite,
      ),

      // Title styles - using Chivo
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: getTextScale(4.5, context),
        fontWeight: FontWeight.w600,
        color: kWhite,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: getTextScale(4, context),
        fontWeight: FontWeight.w600,
        color: kWhite,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: getTextScale(3.5, context),
        fontWeight: FontWeight.w500,
        color: kWhite,
      ),

      // Body styles - using Chivo
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: getTextScale(4, context),
        color: kWhite,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: getTextScale(3.5, context),
        color: kWhite,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: getTextScale(3, context),
        color: kWhite,
      ),

      // Label styles - using Chivo
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: getTextScale(3.5, context),
        fontWeight: FontWeight.w600,
        color: kWhite,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: getTextScale(3, context),
        fontWeight: FontWeight.w500,
        color: kWhite,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: getTextScale(2.5, context),
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
