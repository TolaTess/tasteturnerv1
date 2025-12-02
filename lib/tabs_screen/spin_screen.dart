import 'package:flutter/material.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../pages/spinwheelpop.dart';

class SpinScreen extends StatefulWidget {
  SpinScreen({
    super.key,
  });

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> {
  List<MacroData> ingredientList = [];
  List<Meal> mealList = [];
  String selectedCategory = 'all';

  // Constants for ingredient filtering
  static const int _ingredientCount = 120;
  static const List<String> _excludedTypes = [
    'sweetener',
    'condiment',
    'pastry',
    'dairy',
    'oil',
    'herb',
    'spice',
    'liquid',
    'seed',
    'nut'
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /// Parse excluded ingredients from general data with validation
  List<String> _parseExcludedIngredients() {
    try {
      final generalData = firebaseService.generalData;
      if (generalData.isEmpty) {
        debugPrint('Warning: generalData is empty');
        return [];
      }

      final excludeIngredientsData = generalData['excludeIngredients'];
      if (excludeIngredientsData == null) {
        debugPrint('Warning: excludeIngredients is null');
        return [];
      }

      // Handle both string and list types
      if (excludeIngredientsData is String) {
        if (excludeIngredientsData.isEmpty) {
          return [];
        }
        return excludeIngredientsData
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } else if (excludeIngredientsData is List) {
        return excludeIngredientsData
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } else {
        debugPrint(
            'Warning: excludeIngredients is not a string or list: ${excludeIngredientsData.runtimeType}');
        return [];
      }
    } catch (e) {
      debugPrint('Error parsing excluded ingredients: $e');
      return [];
    }
  }

  /// Filter ingredients based on excluded ingredients and types
  List<MacroData> _filterIngredients(
      List<MacroData> ingredients, List<String> excludedIngredients) {
    return ingredients.where((ingredient) {
      final type = ingredient.type.toLowerCase();

      // Check if type is in excluded types
      if (_excludedTypes.contains(type)) {
        return false;
      }

      // Check if type matches any excluded ingredient
      for (final excluded in excludedIngredients) {
        final excludedLower = excluded.toLowerCase();
        if (type == excludedLower || type.contains(excludedLower)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Handle errors with consistent state reset
  void _handleError(dynamic error) {
    debugPrint('Error fetching spin screen data: $error');
    if (mounted) {
      setState(() {
        ingredientList = [];
        mealList = [];
      });
    }
  }

  Future<void> _fetchData() async {
    try {
      // Fetch data in parallel for better performance
      final results = await Future.wait([
        macroManager.getFirstNIngredients(_ingredientCount),
        mealManager.fetchMealsByCategory('all'),
        firebaseService.fetchGeneralData(),
      ]);

      final ingredients = results[0] as List<MacroData>;
      final mealListData = results[1] as List<Meal>;
      // results[2] is the general data fetch (void)

      // Parse excluded ingredients with validation
      final excludedIngredients = _parseExcludedIngredients();

      // Filter ingredients
      final filteredIngredients =
          _filterIngredients(ingredients, excludedIngredients);

      if (mounted) {
        setState(() {
          ingredientList = filteredIngredients;
          mealList = mealListData;
        });
      }
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SpinWheelPop(
      ingredientList: ingredientList,
      mealList: mealList,
      selectedCategory: selectedCategory,
    );
  }
}
