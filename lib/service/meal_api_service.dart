import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../data_models/meal_model.dart';

class MealApiService {
  static const String baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  Future<List<Meal>> fetchMeals(
      {int limit = 10, String? searchQuery, String? screen}) async {
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
                  fullMeals.add(
                      convertToMeal(mealDetails[0] as Map<String, dynamic>));
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
            allMeals.add(convertToMeal(meals[0] as Map<String, dynamic>));
          }
        }
        // Add a small delay to prevent rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return allMeals;
    } catch (e, stackTrace) {
      print('Stack trace: $stackTrace');
      return [];
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
        steps: steps,
        categories: [apiMeal['strTags']?.toString() ?? ''],
        mediaType: apiMeal['strYoutube']?.toString() ?? '',
        serveQty: 2,
        calories: generateRandomCalories(),
        createdAt: DateTime.now(),
        category: apiMeal['strCategory']?.toString() ?? '',
      );
    } catch (e, stackTrace) {
      print('Error converting meal: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
