import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

class ThemeDarkManager {
  ThemeDarkManager._();

  static final ThemeDarkManager _instance = ThemeDarkManager._();

  factory ThemeDarkManager() => _instance;

  ThemeData mainTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: kBackgroundDarkColor,
      // Use locally bundled Chivo font (configured in pubspec.yaml)
      fontFamily: 'Chivo',
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
    // Base on default Chivo text theme using the global fontFamily
    final baseTextTheme = Theme.of(context).textTheme;

    return TextTheme(
      // Display styles - use Caveat/BlackOpsOne as accent display fonts
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: getTextScale(10, context),
        fontWeight: FontWeight.bold,
        color: kWhite,
        fontFamily: 'Caveat',
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: getTextScale(6, context),
        fontWeight: FontWeight.bold,
        color: kWhite,
        // Use BlackOpsOne for the main heading-style display
        fontFamily: 'BlackOpsOne',
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: getTextScale(8, context),
        fontWeight: FontWeight.bold,
        color: kWhite,
        fontFamily: 'Caveat',
      ),
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

      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: getTextScale(4, context),
        fontWeight: FontWeight.w600,
        color: kWhite,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: getTextScale(3.5, context),
        fontWeight: FontWeight.w400,
        color: kWhite,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: getTextScale(3, context),
        fontWeight: FontWeight.w400,
        color: kWhite,
      ),

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
      titleTextStyle: const TextStyle(
        color: kWhite,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'Chivo',
      ),
    );
  }

  DividerThemeData dividerThemeDarkData() {
    return const DividerThemeData(color: kBackgroundColor, thickness: 0.7);
  }
}
