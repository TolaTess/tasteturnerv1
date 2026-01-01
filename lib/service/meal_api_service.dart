import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import '../data_models/meal_model.dart';


class MealApiService {
  static const String baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  /// Fetch meals from TheMealDB API
  /// Uses cloud function proxy for server-side control
  Future<List<Meal>> fetchMeals(
      {int limit = 10, String? searchQuery, String? screen}) async {
    try {
      // Use cloud function proxy
      final callable = FirebaseFunctions.instance.httpsCallable('fetchMealsFromTheMealDB');
      final result = await callable.call({
        'limit': limit,
        'searchQuery': searchQuery,
        'screen': screen,
      }).timeout(const Duration(seconds: 60));

      // Safely convert result.data to Map<String, dynamic>
      final resultData = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : result.data as Map<String, dynamic>? ?? {};

      if (resultData['success'] == true && resultData['data'] != null) {
        // Safely convert nested data map
        final dataRaw = resultData['data'];
        if (dataRaw is! Map) {
          throw Exception('Invalid data format: expected Map');
        }
        final data = Map<String, dynamic>.from(dataRaw);
        final meals = data['meals'] as List<dynamic>?;

        if (meals == null) return [];

        // Convert API meals to Meal objects
        return meals
            .map((meal) {
              // Safely convert meal map
              if (meal is! Map) {
                throw Exception('Invalid meal format: expected Map');
              }
              final mealMap = Map<String, dynamic>.from(meal);
              return convertToMeal(mealMap);
            })
            .where((meal) => meal.title != 'Unknown')
            .toList();
      } else {
        throw Exception('Failed to fetch meals: Invalid response');
      }
    } catch (e) {
      debugPrint('Error fetching meals via cloud function: $e');
      // Fallback to direct API call if cloud function fails
      try {
        if (searchQuery != null && searchQuery.isNotEmpty) {
          // Remove 'api_' prefix if present in the search query
          final cleanQuery = searchQuery.startsWith('api_')
              ? searchQuery.substring(4)
              : searchQuery;

          final response = await http.get(
            Uri.parse(screen == 'categories'
                ? '$baseUrl/filter.php?c=${Uri.encodeComponent(cleanQuery)}'
                : screen == 'ingredient'
                    ? '$baseUrl/filter.php?i=${Uri.encodeComponent(cleanQuery)}'
                    : '$baseUrl/search.php?s=${Uri.encodeComponent(cleanQuery)}'),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final meals = data['meals'] as List<dynamic>?;

            if (meals == null) return [];

            // For both category and ingredient searches, we need to fetch full meal details
            if (screen == 'categories' || screen == 'ingredient') {
              final List<Meal> fullMeals = [];
              for (var meal in meals.take(limit)) {
                final mealId = meal['idMeal'] as String;
                // Remove 'api_' prefix if present
                final cleanMealId =
                    mealId.startsWith('api_') ? mealId.substring(4) : mealId;
                final detailResponse = await http.get(
                  Uri.parse('$baseUrl/lookup.php?i=$cleanMealId'),
                );

                if (detailResponse.statusCode == 200) {
                  final detailData = json.decode(detailResponse.body);
                  final mealDetails = detailData['meals'] as List<dynamic>?;
                  if (mealDetails != null && mealDetails.isNotEmpty) {
                    final mealObj =
                        convertToMeal(mealDetails[0] as Map<String, dynamic>);
                    if (mealObj.title != 'Unknown') {
                      fullMeals.add(mealObj);
                    }
                  }
                }
                await Future.delayed(const Duration(milliseconds: 100));
              }
              return fullMeals;
            } else {
              // For regular search, we already have full meal details
              return meals
                  .take(limit)
                  .map((meal) => convertToMeal(meal as Map<String, dynamic>))
                  .where((meal) => meal.title != 'Unknown')
                  .toList();
            }
          }
        }

        // Fetch random meals if no search query
        final List<Meal> allMeals = [];
        for (int i = 0; i < limit; i++) {
          final response = await http.get(Uri.parse('$baseUrl/random.php'));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final meals = data['meals'] as List<dynamic>?;
            if (meals != null && meals.isNotEmpty) {
              final mealObj = convertToMeal(meals[0] as Map<String, dynamic>);
              if (mealObj.title != 'Unknown') {
                allMeals.add(mealObj);
              }
            }
          }
          // Add a small delay to prevent rate limiting
          await Future.delayed(const Duration(milliseconds: 100));
        }
        return allMeals;
      } catch (fallbackError, stackTrace) {
        debugPrint('Fallback API call also failed: $fallbackError');
        debugPrint('Stack trace: $stackTrace');
        return [];
      }
    }
  }

  // Generates a random calorie value between 250 and 400
  int generateRandomCalories() {
    final random = Random();
    return random.nextInt(101) + 250; // 250 + (0 to 100) = 250 to 350
  }

  Meal convertToMeal(Map<String, dynamic> apiMeal) {
    try {
      // Convert ingredients and measures into a map
      final ingredients = <String, String>{};
      for (var i = 1; i <= 10; i++) {
        final ingredient = apiMeal['strIngredient$i'];
        final measure = apiMeal['strMeasure$i'];
        if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
          ingredients[ingredient.toString()] = measure?.toString().trim() ?? '';
        }
      }

      // Convert steps from string to list
      final instructions = apiMeal['strInstructions']?.toString() ?? '';
      final steps = instructions
          .split(RegExp(r'\r\n|\r|\n'))
          .where((step) => step.trim().isNotEmpty)
          .toList();

      // Ensure mealId is properly formatted
      final rawMealId = apiMeal['idMeal']?.toString() ?? '';
      final mealId =
          rawMealId.startsWith('api_') ? rawMealId : 'api_$rawMealId';

      return Meal(
        userId: mealId, // Use the same formatted ID for consistency
        mealId: mealId,
        title: apiMeal['strMeal']?.toString() ?? 'Unknown',
        mediaPaths: [apiMeal['strMealThumb']?.toString() ?? ''],
        ingredients: ingredients,
        instructions: steps,
        categories: [apiMeal['strTags']?.toString() ?? ''],
        mediaType: apiMeal['strYoutube']?.toString() ?? '',
        serveQty: 2,
        calories: generateRandomCalories(),
        createdAt: DateTime.now(),
        category: apiMeal['strCategory']?.toString() ?? '',
      );
    } catch (e, stackTrace) {
      debugPrint('Error converting meal: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
