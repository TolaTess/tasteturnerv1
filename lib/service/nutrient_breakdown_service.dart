import 'package:flutter/material.dart' show debugPrint;
import '../data_models/meal_model.dart';
import '../data_models/macro_data.dart';
import '../constants.dart';
import 'package:intl/intl.dart';

/// Service to analyze nutrient contributors in recipes
class NutrientBreakdownService {
  static final NutrientBreakdownService instance = NutrientBreakdownService._();
  NutrientBreakdownService._();

  /// Analyze nutrient contributors for a specific nutrient in a recipe
  /// Returns sorted list of contributors with percentages
  Future<List<Map<String, dynamic>>> analyzeNutrientContributors(
    Meal recipe,
    String targetNutrient,
  ) async {
    try {
      final contributors = <Map<String, dynamic>>[];
      final totalNutrient = _getNutrientValue(recipe, targetNutrient);

      if (totalNutrient == 0) {
        return contributors;
      }

      // Analyze each ingredient's contribution
      for (final ingredientEntry in recipe.ingredients.entries) {
        final ingredientName = ingredientEntry.key;
        final quantity = ingredientEntry.value;

        // Get nutrient value for this ingredient
        final ingredientNutrient = await _getIngredientNutrientValue(
          ingredientName,
          quantity,
          targetNutrient,
        );

        if (ingredientNutrient > 0) {
          final contribution = (ingredientNutrient / totalNutrient) * 100;
          contributors.add({
            'ingredient': ingredientName,
            'contribution': contribution,
            'nutrient': targetNutrient,
            'value': ingredientNutrient,
          });
        }
      }

      // Sort by contribution (highest first)
      contributors.sort((a, b) =>
          (b['contribution'] as double).compareTo(a['contribution'] as double));

      return contributors;
    } catch (e) {
      debugPrint('Error analyzing nutrient contributors: $e');
      return [];
    }
  }

  /// Get nutrient value from recipe's nutritional info
  double _getNutrientValue(Meal recipe, String nutrient) {
    try {
      // Normalize nutrient name
      final normalizedNutrient = nutrient.toLowerCase();

      // Check nutritionalInfo map
      if (recipe.nutritionalInfo.containsKey(normalizedNutrient)) {
        final value = recipe.nutritionalInfo[normalizedNutrient];
        if (value != null) {
          return double.tryParse(value) ?? 0.0;
        }
      }

      // Check nutrition map (alternative field)
      final nutritionValue = recipe.nutrition[normalizedNutrient];
      if (nutritionValue != null) {
        if (nutritionValue is num) {
          return (nutritionValue as num).toDouble();
        }
        if (nutritionValue is String) {
          return double.tryParse(nutritionValue) ?? 0.0;
        }
      }

      // Check macros map for protein, carbs, fat
      if (recipe.macros.containsKey(normalizedNutrient)) {
        final value = recipe.macros[normalizedNutrient];
        if (value != null) {
          return double.tryParse(value) ?? 0.0;
        }
      }

      return 0.0;
    } catch (e) {
      debugPrint('Error getting nutrient value: $e');
      return 0.0;
    }
  }

  /// Get nutrient value for a specific ingredient
  Future<double> _getIngredientNutrientValue(
    String ingredientName,
    String quantity,
    String nutrient,
  ) async {
    try {
      // Try to get from macroManager (ingredient database)
      MacroData? macroData;
      try {
        macroData = macroManager.ingredient.firstWhere(
          (item) => item.title.toLowerCase() == ingredientName.toLowerCase(),
        );
      } catch (e) {
        // Ingredient not found, return 0
        return 0.0;
      }

      // Get nutrient value from macroData.macros map
      final normalizedNutrient = nutrient.toLowerCase();
      double nutrientValue = 0.0;

      // Map nutrient names to macro keys
      String macroKey = normalizedNutrient;
      if (normalizedNutrient == 'saturated fat' || normalizedNutrient == 'saturatedfat') {
        macroKey = 'saturatedFat';
      } else if (normalizedNutrient == 'carbs' || normalizedNutrient == 'carbohydrates') {
        macroKey = 'carbs';
      }

      // Get value from macros map
      if (macroData.macros.containsKey(macroKey)) {
        final value = macroData.macros[macroKey];
        if (value is num) {
          nutrientValue = value.toDouble();
        } else if (value is String) {
          nutrientValue = double.tryParse(value) ?? 0.0;
        }
      }

      // Parse quantity to adjust nutrient value
      // Example: "1 cup" or "100g"
      final quantityValue = _parseQuantity(quantity);
      // Note: We don't have servingSize in MacroData, so we'll use a simple scaling
      // This is a simplified approach - in production, you'd want more sophisticated quantity parsing
      if (quantityValue > 0) {
        // Assume standard serving if quantity is provided
        // This is a rough estimate - actual implementation would need proper unit conversion
        final scaleFactor = quantityValue / 100.0; // Assume 100g as base
        nutrientValue = nutrientValue * scaleFactor;
      }

      return nutrientValue;
    } catch (e) {
      debugPrint('Error getting ingredient nutrient value: $e');
      return 0.0;
    }
  }

  /// Parse quantity string to numeric value
  /// Handles formats like "1 cup", "100g", "2 tbsp", etc.
  double _parseQuantity(String quantity) {
    try {
      // Remove common units and extract number
      final cleaned = quantity
          .toLowerCase()
          .replaceAll(RegExp(r'[a-z\s]+'), '')
          .trim();
      return double.tryParse(cleaned) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Analyze all meals logged today and get nutrient breakdowns
  Future<Map<String, List<Map<String, dynamic>>>> analyzeDailyNutrientBreakdowns(
    String userId,
    DateTime date,
  ) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final mealRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateStr);

      final docSnapshot = await mealRef.get();
      if (!docSnapshot.exists) {
        return {};
      }

      final data = docSnapshot.data();
      final mealsMap = data?['meals'] as Map<String, dynamic>? ?? {};

      final breakdowns = <String, List<Map<String, dynamic>>>{};

      // Process each meal type
      for (var mealType in mealsMap.keys) {
        final mealList = mealsMap[mealType] as List<dynamic>? ?? [];
        final mealBreakdowns = <Map<String, dynamic>>[];

        for (var mealData in mealList) {
          final mealMap = mealData as Map<String, dynamic>;
          final mealId = mealMap['mealId'] as String?;

          if (mealId == null || mealId.isEmpty) continue;

          // Fetch meal from meals collection
          final mealDoc = await firestore.collection('meals').doc(mealId).get();
          if (!mealDoc.exists) continue;

          final meal = Meal.fromJson(mealId, mealDoc.data()!);

          // Analyze top contributors for key nutrients
          final sodiumContributors =
              await analyzeNutrientContributors(meal, 'sodium');
          final sugarContributors =
              await analyzeNutrientContributors(meal, 'sugar');
          final saturatedFatContributors =
              await analyzeNutrientContributors(meal, 'saturated fat');

          if (sodiumContributors.isNotEmpty ||
              sugarContributors.isNotEmpty ||
              saturatedFatContributors.isNotEmpty) {
            mealBreakdowns.add({
              'mealName': meal.title,
              'mealId': mealId,
              'sodium': sodiumContributors.take(3).toList(),
              'sugar': sugarContributors.take(3).toList(),
              'saturatedFat': saturatedFatContributors.take(3).toList(),
            });
          }
        }

        if (mealBreakdowns.isNotEmpty) {
          breakdowns[mealType] = mealBreakdowns;
        }
      }

      return breakdowns;
    } catch (e) {
      debugPrint('Error analyzing daily nutrient breakdowns: $e');
      return {};
    }
  }
}

