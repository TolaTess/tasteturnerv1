import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

class ThemeManager {
  ThemeManager._();

  static final ThemeManager _instance = ThemeManager._();

  factory ThemeManager() => _instance;

  ThemeData mainTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: kBackgroundColor,
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
        color: kBlack,
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
        color: kBlack,
        fontFamily: 'Caveat',
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: getTextScale(6, context),
        fontWeight: FontWeight.bold,
        color: kBlack,
        // Use BlackOpsOne for the main heading-style display
        fontFamily: 'BlackOpsOne',
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: getTextScale(8, context),
        fontWeight: FontWeight.bold,
        color: kBlack,
        fontFamily: 'Caveat',
      ),
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

      // Title styles - use Chivo (global)
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
      titleTextStyle: const TextStyle(
        color: kBlack,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'Chivo',
      ),
    );
  }

  DividerThemeData dividerThemeData() {
    return const DividerThemeData(color: kBlack, thickness: 0.7);
  }
}
