import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show debugPrint;
import '../constants.dart';
import 'package:intl/intl.dart';

/// Service for reverse pantry search - finding foods that fit remaining macros
class ReversePantrySearchService {
  static final ReversePantrySearchService instance =
      ReversePantrySearchService._();
  ReversePantrySearchService._();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Search for foods that match remaining macros
  /// Returns list of foods sorted by macro fit score
  Future<List<Map<String, dynamic>>> searchByRemainingMacros({
    required int remainingCalories,
    required double remainingProtein,
    required double remainingCarbs,
    required double remainingFat,
    String? userId,
  }) async {
    try {
      final searchUserId = userId ?? userService.userId;
      if (searchUserId == null || searchUserId.isEmpty) {
        debugPrint('Cannot search: userId is empty');
        return [];
      }

      final List<Map<String, dynamic>> matches = [];

      // 1. Search user's meal history (last 30-90 days)
      await _searchMealHistory(searchUserId, remainingCalories,
          remainingProtein, remainingCarbs, remainingFat, matches);

      // 2. Search pantry/fridge ingredients
      await _searchPantryIngredients(searchUserId, remainingCalories,
          remainingProtein, remainingCarbs, remainingFat, matches);

      // 3. Sort by macro fit score (how well it matches remaining macros)
      matches.sort((a, b) {
        final scoreA = _calculateFitScore(
            a, remainingCalories, remainingProtein, remainingCarbs, remainingFat);
        final scoreB = _calculateFitScore(
            b, remainingCalories, remainingProtein, remainingCarbs, remainingFat);
        return scoreB.compareTo(scoreA); // Higher score = better fit
      });

      // Return top 10 matches
      return matches.take(10).toList();
    } catch (e) {
      debugPrint('Error in reverse pantry search: $e');
      return [];
    }
  }

  /// Search user's meal history from last 30-90 days
  Future<void> _searchMealHistory(
      String userId,
      int remainingCalories,
      double remainingProtein,
      double remainingCarbs,
      double remainingFat,
      List<Map<String, dynamic>> matches) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 90));
      final endDate = now;

      // Fetch meal documents from last 90 days
      final dateFormat = DateFormat('yyyy-MM-dd');
      final startDateStr = dateFormat.format(startDate);
      final endDateStr = dateFormat.format(endDate);

      final mealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDateStr)
          .limit(100); // Limit to avoid too many reads

      final snapshot = await mealsRef.get();

      final Set<String> seenMealIds = {}; // Avoid duplicates

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final mealsMap = data['meals'] as Map<String, dynamic>? ?? {};

        // Iterate through all meal types
        for (var mealType in mealsMap.keys) {
          final mealList = mealsMap[mealType] as List<dynamic>? ?? [];
          for (var mealData in mealList) {
            if (mealData is Map<String, dynamic>) {
              final mealId = mealData['mealId'] as String? ?? '';
              if (mealId.isEmpty || seenMealIds.contains(mealId)) continue;
              seenMealIds.add(mealId);

              // Get meal details from meals collection
              final mealDoc =
                  await firestore.collection('meals').doc(mealId).get();
              if (!mealDoc.exists) continue;

              final mealData_full = mealDoc.data()!;
              final calories = mealData_full['calories'] as int? ?? 0;
              final macros = mealData_full['macros'] as Map<String, dynamic>? ??
                  mealData_full['nutritionalInfo'] as Map<String, dynamic>? ??
                  {};

              final protein = _parseMacro(macros['protein']) ?? 0.0;
              final carbs = _parseMacro(macros['carbs']) ?? 0.0;
              final fat = _parseMacro(macros['fat']) ?? 0.0;

              // Check if meal fits remaining macros
              if (calories <= remainingCalories &&
                  protein <= remainingProtein &&
                  carbs <= remainingCarbs &&
                  fat <= remainingFat) {
                matches.add({
                  'name': mealData_full['title'] ?? mealData['name'] ?? 'Unknown',
                  'calories': calories,
                  'protein': protein,
                  'carbs': carbs,
                  'fat': fat,
                  'mealId': mealId,
                  'type': 'meal',
                  'source': 'history',
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching meal history: $e');
    }
  }

  /// Search pantry/fridge ingredients
  Future<void> _searchPantryIngredients(
      String userId,
      int remainingCalories,
      double remainingProtein,
      double remainingCarbs,
      double remainingFat,
      List<Map<String, dynamic>> matches) async {
    try {
      final pantryRef = firestore
          .collection('users')
          .doc(userId)
          .collection('pantry');

      final snapshot = await pantryRef.limit(50).get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final calories = data['calories'] as int? ?? 0;
        final protein = _parseMacro(data['protein']) ?? 0.0;
        final carbs = _parseMacro(data['carbs']) ?? 0.0;
        final fat = _parseMacro(data['fat']) ?? 0.0;

        // Check if ingredient fits remaining macros
        if (calories <= remainingCalories &&
            protein <= remainingProtein &&
            carbs <= remainingCarbs &&
            fat <= remainingFat) {
          matches.add({
            'name': data['name'] ?? 'Unknown',
            'calories': calories,
            'protein': protein,
            'carbs': carbs,
            'fat': fat,
            'ingredientId': doc.id,
            'type': 'ingredient',
            'source': 'pantry',
          });
        }
      }
    } catch (e) {
      debugPrint('Error searching pantry ingredients: $e');
    }
  }

  /// Calculate how well a food fits the remaining macros
  /// Higher score = better fit
  double _calculateFitScore(
      Map<String, dynamic> food,
      int remainingCalories,
      double remainingProtein,
      double remainingCarbs,
      double remainingFat) {
    final calories = food['calories'] as int? ?? 0;
    final protein = food['protein'] as double? ?? 0.0;
    final carbs = food['carbs'] as double? ?? 0.0;
    final fat = food['fat'] as double? ?? 0.0;

    // Calculate percentage of remaining macros used
    final caloriesRatio = remainingCalories > 0 ? calories / remainingCalories : 0.0;
    final proteinRatio = remainingProtein > 0 ? protein / remainingProtein : 0.0;
    final carbsRatio = remainingCarbs > 0 ? carbs / remainingCarbs : 0.0;
    final fatRatio = remainingFat > 0 ? fat / remainingFat : 0.0;

    // Average ratio (closer to 1.0 = better fit, uses more of remaining macros)
    final avgRatio = (caloriesRatio + proteinRatio + carbsRatio + fatRatio) / 4.0;

    // Bonus for using more of remaining macros (but not exceeding)
    return avgRatio;
  }

  /// Parse macro value from dynamic type
  double? _parseMacro(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

