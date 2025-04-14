import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dark_mode.dart';
import 'light_mode.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = ThemeManager().mainTheme();
  ThemeData get themeData => _themeData;

  bool get isDarkMode => _themeData == ThemeDarkManager().mainTheme();

  ThemeProvider() {
    _loadThemePreference();
  }

  void toggleTheme() {
    _themeData = isDarkMode
        ? ThemeManager().mainTheme()
        : ThemeDarkManager().mainTheme();
    notifyListeners();
    _saveThemePreference();
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    _themeData =
        isDark ? ThemeDarkManager().mainTheme() : ThemeManager().mainTheme();
    notifyListeners();
  }
}
