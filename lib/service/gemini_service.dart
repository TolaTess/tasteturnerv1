import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../widgets/loading_screen.dart';

/// Enhanced GeminiService with comprehensive user context integration
///
/// This service provides AI-powered functionality with intelligent context awareness:
///
/// **Context Features:**
/// - Automatic program enrollment detection and details
/// - User preferences (diet, family mode) integration
/// - Program progress tracking and goal alignment
/// - Intelligent program encouragement for non-enrolled users
/// - Efficient context caching (30-minute cache validity)
///
/// **Usage Examples:**
/// ```dart
/// // Generate contextual meal plan
/// final mealPlan = await geminiService.generateMealPlan("healthy meals for weight loss");
///
/// // Check if user has a program
/// final hasProgram = await geminiService.isUserEnrolledInProgram();
///
/// // Refresh context after program changes
/// await geminiService.refreshUserContext();
/// ```
///
/// **Cache Management:**
/// - Context is cached for 30 minutes or until user changes
/// - Call `refreshUserContext()` after program enrollment/changes
/// - Call `clearContextCache()` to force fresh data on next request
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  static GeminiService get instance => _instance;

  final String _baseUrl = 'https://generativelanguage.googleapis.com/v1';
  String? _activeModel; // Cache the working model name and full path

  // Get current family mode dynamically
  bool get familyMode => userService.currentUser.value?.familyMode ?? false;

  // Cache user program context for efficiency
  Map<String, dynamic>? _cachedUserContext;
  String? _lastUserId;
  DateTime? _lastContextFetch;

  // Enhanced error handling for production
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _backoffMultiplier = Duration(seconds: 1);

  // Track API health
  static bool _isApiHealthy = true;
  static DateTime? _lastApiError;
  static int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;
  static const Duration _apiRecoveryTime = Duration(minutes: 10);

  /// Check if API is currently healthy
  bool get isApiHealthy {
    if (!_isApiHealthy && _lastApiError != null) {
      final timeSinceLastError = DateTime.now().difference(_lastApiError!);
      if (timeSinceLastError > _apiRecoveryTime) {
        _isApiHealthy = true;
        _consecutiveErrors = 0;
      }
    }
    return _isApiHealthy;
  }

  /// Enhanced API call with retry logic and fallback
  Future<Map<String, dynamic>> _makeApiCallWithRetry({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    // Check if API is healthy
    if (!isApiHealthy) {
      throw Exception('API temporarily unavailable. Please try again later.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$endpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30)); // Add timeout

      if (response.statusCode == 200) {
        // Reset error tracking on success
        _consecutiveErrors = 0;
        _isApiHealthy = true;

        final decoded = jsonDecode(response.body);
        return decoded;
      } else {
        // Handle specific error codes
        final errorResponse = jsonDecode(response.body);
        final errorCode = response.statusCode;
        final errorMessage =
            errorResponse['error']?['message'] ?? 'Unknown error';

        // Log error for monitoring
        print('AI API Error: $errorCode - $errorMessage');

        // Handle specific error types
        switch (errorCode) {
          case 503:
            // Service overloaded - retry with exponential backoff
            if (retryCount < _maxRetries) {
              final delay = _retryDelay + (_backoffMultiplier * retryCount);
              await Future.delayed(delay);
              return _makeApiCallWithRetry(
                endpoint: endpoint,
                body: body,
                operation: operation,
                retryCount: retryCount + 1,
              );
            }
            _handleApiError(
                'Service temporarily overloaded. Please try again in a few minutes.');
            break;

          case 429:
            // Rate limited - retry with longer delay
            if (retryCount < _maxRetries) {
              await Future.delayed(Duration(seconds: 5 * (retryCount + 1)));
              return _makeApiCallWithRetry(
                endpoint: endpoint,
                body: body,
                operation: operation,
                retryCount: retryCount + 1,
              );
            }
            _handleApiError('Rate limit exceeded. Please try again later.');
            break;

          case 401:
            // Authentication error
            _handleApiError(
                'Authentication failed. Please check your API configuration.');
            break;

          case 400:
            // Bad request - don't retry
            throw Exception('Invalid request: $errorMessage');

          default:
            // Other errors - retry if appropriate
            if (retryCount < _maxRetries && errorCode >= 500) {
              await Future.delayed(_retryDelay);
              return _makeApiCallWithRetry(
                endpoint: endpoint,
                body: body,
                operation: operation,
                retryCount: retryCount + 1,
              );
            }
            _handleApiError('Service error: $errorMessage');
        }

        throw Exception('Failed to $operation: $errorCode - $errorMessage');
      }
    } catch (e) {
      _handleApiError('Connection error: ${e.toString()}');
      throw Exception('Failed to $operation: ${e.toString()}');
    }
  }

  /// Handle API errors and update health status
  void _handleApiError(String message) {
    _consecutiveErrors++;
    _lastApiError = DateTime.now();

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _isApiHealthy = false;
      print(
          'API marked as unhealthy after $_consecutiveErrors consecutive errors');
    }

    print('API Error: $message');
  }

  /// Get fallback meal suggestions when AI is unavailable
  Future<Map<String, dynamic>> _getFallbackMeals(String prompt) async {
    // Simple keyword-based fallback
    final keywords = prompt.toLowerCase().split(' ');

    // Pre-defined meal templates based on common keywords
    final fallbackMeals = [
      {
        'title': 'Quick Pasta Primavera',
        'ingredients': {
          'pasta': '200g',
          'vegetables': 'mixed',
          'olive oil': '2 tbsp'
        },
        'instructions': ['Boil pasta', 'Sauté vegetables', 'Combine and serve'],
        'nutritionalInfo': {
          'calories': 350,
          'protein': 12,
          'carbs': 45,
          'fat': 8
        },
        'categories': ['quick', 'vegetarian'],
        'cookingTime': '15 minutes',
        'cookingMethod': 'stovetop'
      },
      {
        'title': 'Simple Grilled Chicken Salad',
        'ingredients': {
          'chicken breast': '150g',
          'lettuce': '1 head',
          'tomatoes': '2'
        },
        'instructions': ['Grill chicken', 'Chop vegetables', 'Assemble salad'],
        'nutritionalInfo': {
          'calories': 280,
          'protein': 35,
          'carbs': 8,
          'fat': 12
        },
        'categories': ['healthy', 'protein-rich'],
        'cookingTime': '20 minutes',
        'cookingMethod': 'grill'
      },
      {
        'title': 'Easy Vegetable Stir Fry',
        'ingredients': {
          'vegetables': 'mixed',
          'soy sauce': '2 tbsp',
          'oil': '1 tbsp'
        },
        'instructions': ['Heat oil', 'Stir fry vegetables', 'Add sauce'],
        'nutritionalInfo': {
          'calories': 200,
          'protein': 6,
          'carbs': 25,
          'fat': 10
        },
        'categories': ['vegetarian', 'quick'],
        'cookingTime': '10 minutes',
        'cookingMethod': 'stir fry'
      }
    ];

    // Filter meals based on keywords
    List<Map<String, dynamic>> filteredMeals = fallbackMeals;

    if (keywords.contains('quick') || keywords.contains('fast')) {
      filteredMeals = filteredMeals
          .where((meal) =>
              meal['cookingTime'].toString().contains('10') ||
              meal['cookingTime'].toString().contains('15'))
          .toList();
    }

    if (keywords.contains('vegetarian') || keywords.contains('vegan')) {
      filteredMeals = filteredMeals
          .where((meal) => meal['categories'].contains('vegetarian'))
          .toList();
    }

    if (keywords.contains('protein') || keywords.contains('meat')) {
      filteredMeals = filteredMeals
          .where((meal) => meal['categories'].contains('protein-rich'))
          .toList();
    }

    return {
      'meals': filteredMeals.isNotEmpty ? filteredMeals : fallbackMeals,
      'source': 'fallback',
      'message':
          'AI service temporarily unavailable. Here are some suggested meals:'
    };
  }

  /// Normalize and deduplicate ingredients to prevent variations like "sesameseed" vs "sesame seed"
  Map<String, String> _normalizeAndDeduplicateIngredients(
      Map<String, dynamic> ingredients) {
    final Map<String, String> normalizedIngredients = {};
    final Map<String, List<MapEntry<String, String>>> groupedIngredients = {};

    // Convert all ingredients to Map<String, String> and normalize keys
    final stringIngredients = <String, String>{};
    ingredients.forEach((key, value) {
      stringIngredients[key] = value.toString();
    });

    // Group ingredients by normalized name
    stringIngredients.forEach((originalName, amount) {
      final normalizedName = _normalizeIngredientName(originalName);

      if (!groupedIngredients.containsKey(normalizedName)) {
        groupedIngredients[normalizedName] = [];
      }
      groupedIngredients[normalizedName]!.add(MapEntry(originalName, amount));
    });

    // Process grouped ingredients
    groupedIngredients.forEach((normalizedName, ingredientList) {
      if (ingredientList.length == 1) {
        // Single ingredient, use as-is
        final ingredient = ingredientList.first;
        normalizedIngredients[ingredient.key] = ingredient.value;
      } else {
        // Multiple ingredients with same normalized name - combine them
        final combinedResult = _combineIngredients(ingredientList);
        normalizedIngredients[combinedResult.key] = combinedResult.value;
      }
    });

    return normalizedIngredients;
  }

  /// Normalize ingredient name for comparison (lowercase, no spaces, common substitutions)
  String _normalizeIngredientName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '') // Remove all whitespace
        .replaceAll(RegExp(r'[^\w]'), '') // Remove non-word characters
        .replaceAll('oilolive', 'oliveoil') // Handle oil variations
        .replaceAll('saltpink', 'pinksalt')
        .replaceAll('saltrock', 'rocksalt')
        .replaceAll('saltsea', 'seasalt');
  }

  /// Combine multiple ingredients with the same normalized name
  MapEntry<String, String> _combineIngredients(
      List<MapEntry<String, String>> ingredients) {
    // Use the most descriptive name (longest with spaces)
    String bestName = ingredients.first.key;
    for (final ingredient in ingredients) {
      if (ingredient.key.contains(' ') &&
          ingredient.key.length > bestName.length) {
        bestName = ingredient.key;
      }
    }

    // Try to combine quantities if they have the same unit
    final quantities = <double>[];
    String? commonUnit;
    bool canCombine = true;

    for (final ingredient in ingredients) {
      final amount = ingredient.value.toLowerCase().trim();
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z]*)').firstMatch(amount);

      if (match != null) {
        final quantity = double.tryParse(match.group(1) ?? '0') ?? 0;
        final unit = match.group(2) ?? '';

        if (commonUnit == null) {
          commonUnit = unit;
        } else if (commonUnit != unit && unit.isNotEmpty) {
          // Different units, can't combine
          canCombine = false;
          break;
        }
        quantities.add(quantity);
      } else {
        // Can't parse quantity, can't combine
        canCombine = false;
        break;
      }
    }

    if (canCombine && quantities.isNotEmpty) {
      final totalQuantity = quantities.reduce((a, b) => a + b);
      final combinedAmount = commonUnit != null && commonUnit.isNotEmpty
          ? '$totalQuantity$commonUnit'
          : totalQuantity.toString();
      return MapEntry(bestName, combinedAmount);
    } else {
      // Can't combine, use the first one and add a note
      final firstAmount = ingredients.first.value;
      final additionalCount = ingredients.length - 1;
      final combinedAmount = additionalCount > 0
          ? '$firstAmount (+$additionalCount more)'
          : firstAmount;
      return MapEntry(bestName, combinedAmount);
    }
  }

  /// Enhanced error handling wrapper for AI responses
  Map<String, dynamic> _processAIResponse(String text, String operation) {
    // Check if text is empty or contains error message
    if (text.isEmpty || text.startsWith('Error:')) {
      return _createFallbackResponse(
          operation, 'Empty or error response from API');
    }

    try {
      // Use robust validation for tasty_analysis
      if (operation == 'tasty_analysis') {
        final result = _validateAndExtractFoodAnalysis(text);
        return result;
      }

      final jsonData = _extractJsonObject(text);
      print('JSON data: $jsonData');

      // Apply ingredient deduplication if ingredients exist
      if (jsonData.containsKey('ingredients') &&
          jsonData['ingredients'] is Map) {
        jsonData['ingredients'] = _normalizeAndDeduplicateIngredients(
            jsonData['ingredients'] as Map<String, dynamic>);
      }

      // Also check for ingredients in meal objects
      if (jsonData.containsKey('meals') && jsonData['meals'] is List) {
        final meals = jsonData['meals'] as List<dynamic>;
        for (final meal in meals) {
          if (meal is Map<String, dynamic> && meal.containsKey('ingredients')) {
            meal['ingredients'] = _normalizeAndDeduplicateIngredients(
                meal['ingredients'] as Map<String, dynamic>);
          }
        }
      }

      // Validate required fields based on operation
      _validateResponseStructure(jsonData, operation);

      return jsonData;
    } catch (e) {
      // Try to extract partial JSON if possible
      try {
        final partialJson = _extractPartialJson(text, operation);
        if (partialJson.isNotEmpty) {
          return partialJson;
        }
      } catch (partialError) {
        print('Partial JSON recovery failed: $partialError');
      }

      // Return a fallback structure based on operation type
      return _createFallbackResponse(operation, e.toString());
    }
  }

  /// Validate response structure based on operation type
  void _validateResponseStructure(Map<String, dynamic> data, String operation) {
    switch (operation) {
      case 'tasty_analysis':
        if (!data.containsKey('foodItems') ||
            !data.containsKey('totalNutrition')) {
          throw Exception(
              'Missing required fields: foodItems or totalNutrition');
        }
        break;
      case 'meal_generation':
        if (!data.containsKey('meals')) {
          throw Exception('Missing required field: meals');
        }
        break;
      case 'meal_plan':
        if (!data.containsKey('meals')) {
          throw Exception('Missing required field: meals');
        }
        break;
      case 'program_generation':
        if (!data.containsKey('weeklyPlans')) {
          throw Exception('Missing required field: weeklyPlans');
        }
        break;
      case 'food_comparison':
        if (!data.containsKey('image1Analysis') ||
            !data.containsKey('image2Analysis')) {
          throw Exception(
              'Missing required fields: image1Analysis or image2Analysis');
        }
        break;
      case '54321_shopping':
        if (!data.containsKey('shoppingList')) {
          throw Exception('Missing required field: shoppingList');
        }
        break;
    }
  }

  /// Robust JSON validation and extraction for food analysis
  Map<String, dynamic> _validateAndExtractFoodAnalysis(String rawResponse) {
    try {
      // First attempt: extract JSON from markdown code blocks if present
      final cleanedResponse = _extractJsonFromMarkdown(rawResponse);
      final completedResponse = _completeTruncatedJson(cleanedResponse);
      final sanitized = _sanitizeJsonString(completedResponse);
      final data = jsonDecode(sanitized) as Map<String, dynamic>;

      // Validate and normalize the data
      final result = _validateAndNormalizeFoodAnalysisData(data);
      return result;
    } catch (e) {
      // Second attempt: use existing partial extraction method
      final partialData = _extractPartialJson(rawResponse, 'tasty_analysis');
      if (partialData.isNotEmpty &&
          _isValidPartialResponse(partialData, 'tasty_analysis')) {
        return _validateAndNormalizeFoodAnalysisData(partialData);
      }

      // Third attempt: extract food analysis data from malformed response
      final extractedData = _extractFoodAnalysisFromRawText(rawResponse);
      if (extractedData.isNotEmpty) {
        // Check if the extracted data has complete nutritional information
        if (_hasCompleteNutritionalData(extractedData)) {
          return _validateAndNormalizeFoodAnalysisData(extractedData);
        }
      }

      // Fourth attempt: try to extract partial data using regex patterns
      final regexData = _extractFoodAnalysisWithRegex(rawResponse);
      if (regexData.isNotEmpty) {
        return _validateAndNormalizeFoodAnalysisData(regexData);
      }

      // Return fallback if all extraction attempts fail
      return _createFallbackResponse(
          'tasty_analysis', 'Complete extraction failed');
    }
  }

  /// Check if extracted data has complete nutritional information
  bool _hasCompleteNutritionalData(Map<String, dynamic> data) {
    if (!data.containsKey('foodItems') || data['foodItems'] is! List) {
      return false;
    }

    final foodItems = data['foodItems'] as List;
    if (foodItems.isEmpty) {
      return false;
    }

    // Check if at least one food item has complete nutritional data
    for (final item in foodItems) {
      if (item is Map<String, dynamic> &&
          item.containsKey('nutritionalInfo') &&
          item['nutritionalInfo'] is Map<String, dynamic>) {
        final nutrition = item['nutritionalInfo'] as Map<String, dynamic>;

        // Check if we have the key nutritional values with non-zero values
        if (nutrition.containsKey('calories') &&
            nutrition['calories'] is int &&
            (nutrition['calories'] as int) > 0 &&
            nutrition.containsKey('protein') &&
            nutrition['protein'] is int &&
            nutrition.containsKey('carbs') &&
            nutrition['carbs'] is int &&
            nutrition.containsKey('fat') &&
            nutrition['fat'] is int) {
          return true;
        }
      }
    }

    return false;
  }

  /// Extract food analysis data using regex patterns when JSON parsing fails
  Map<String, dynamic> _extractFoodAnalysisWithRegex(String rawResponse) {
    final Map<String, dynamic> extractedData = {};
    final List<Map<String, dynamic>> foodItems = [];

    try {
      // Extract food items using regex patterns - more flexible approach
      // Look for food items with any order of fields
      final foodItemPattern = RegExp(
          r'"name":\s*"([^"]+)".*?"nutritionalInfo":\s*\{.*?"calories":\s*(\d+).*?"protein":\s*(\d+).*?"carbs":\s*(\d+).*?"fat":\s*(\d+).*?"fiber":\s*(\d+).*?"sugar":\s*(\d+).*?"sodium":\s*(\d+)',
          multiLine: true,
          dotAll: true);

      final matches = foodItemPattern.allMatches(rawResponse);

      // If no complete matches, try a simpler pattern for basic nutrition
      if (matches.isEmpty) {
        final simpleNutritionPattern = RegExp(
            r'"name":\s*"([^"]+)".*?"calories":\s*(\d+).*?"protein":\s*(\d+).*?"carbs":\s*(\d+).*?"fat":\s*(\d+)',
            multiLine: true,
            dotAll: true);

        final simpleMatches = simpleNutritionPattern.allMatches(rawResponse);

        for (final match in simpleMatches) {
          try {
            final foodItem = {
              'name': match.group(1) ?? 'Unknown Food',
              'estimatedWeight': '100g', // Default weight
              'confidence': 'low', // Lower confidence for partial data
              'nutritionalInfo': {
                'calories': int.tryParse(match.group(2) ?? '0') ?? 0,
                'protein': int.tryParse(match.group(3) ?? '0') ?? 0,
                'carbs': int.tryParse(match.group(4) ?? '0') ?? 0,
                'fat': int.tryParse(match.group(5) ?? '0') ?? 0,
                'fiber': 2, // Default values for missing fields
                'sugar': 5,
                'sodium': 200,
              }
            };

            foodItems.add(foodItem);
          } catch (e) {
            // Skip failed extractions
          }
        }
      }

      for (final match in matches) {
        try {
          final foodItem = {
            'name': match.group(1) ?? 'Unknown Food',
            'estimatedWeight':
                '100g', // Default since we're not extracting this
            'confidence': 'medium', // Default confidence
            'nutritionalInfo': {
              'calories': int.tryParse(match.group(2) ?? '0') ?? 0,
              'protein': int.tryParse(match.group(3) ?? '0') ?? 0,
              'carbs': int.tryParse(match.group(4) ?? '0') ?? 0,
              'fat': int.tryParse(match.group(5) ?? '0') ?? 0,
              'fiber': int.tryParse(match.group(6) ?? '0') ?? 0,
              'sugar': int.tryParse(match.group(7) ?? '0') ?? 0,
              'sodium': int.tryParse(match.group(8) ?? '0') ?? 0,
            }
          };

          foodItems.add(foodItem);
        } catch (e) {
          // Skip failed extractions
        }
      }

      if (foodItems.isNotEmpty) {
        extractedData['foodItems'] = foodItems;

        // Calculate total nutrition
        int totalCalories = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
        int totalFiber = 0, totalSugar = 0, totalSodium = 0;

        for (final item in foodItems) {
          final nutrition = item['nutritionalInfo'] as Map<String, dynamic>?;
          if (nutrition != null) {
            totalCalories += nutrition['calories'] as int? ?? 0;
            totalProtein += nutrition['protein'] as int? ?? 0;
            totalCarbs += nutrition['carbs'] as int? ?? 0;
            totalFat += nutrition['fat'] as int? ?? 0;
            totalFiber += nutrition['fiber'] as int? ?? 0;
            totalSugar += nutrition['sugar'] as int? ?? 0;
            totalSodium += nutrition['sodium'] as int? ?? 0;
          }
        }

        extractedData['totalNutrition'] = {
          'calories': totalCalories,
          'protein': totalProtein,
          'carbs': totalCarbs,
          'fat': totalFat,
          'fiber': totalFiber,
          'sugar': totalSugar,
          'sodium': totalSodium,
        };

        // Extract other fields if possible
        final healthScoreMatch =
            RegExp(r'"healthScore":\s*(\d+)').firstMatch(rawResponse);
        if (healthScoreMatch != null) {
          extractedData['healthScore'] =
              int.tryParse(healthScoreMatch.group(1) ?? '5') ?? 5;
        }

        final mealTypeMatch =
            RegExp(r'"mealType":\s*"([^"]+)"').firstMatch(rawResponse);
        if (mealTypeMatch != null) {
          extractedData['mealType'] = mealTypeMatch.group(1) ?? 'unknown';
        }

        // Extract missing fields using regex patterns
        extractedData['ingredients'] = _extractIngredientsFromText(rawResponse);
        extractedData['cookingMethod'] =
            _extractCookingMethodFromText(rawResponse);
        extractedData['instructions'] =
            _extractInstructionsFromText(rawResponse);
        extractedData['dietaryFlags'] =
            _extractDietaryFlagsFromText(rawResponse);
        extractedData['suggestions'] = _extractSuggestionsFromText(rawResponse);
        extractedData['estimatedPortionSize'] =
            _extractPortionSizeFromText(rawResponse);

        extractedData['confidence'] = 'medium'; // Since we extracted some data
        extractedData['notes'] =
            'Data extracted using regex patterns due to JSON parsing issues';

        return extractedData;
      }
    } catch (e) {
      // Regex extraction failed, continue to fallback
    }
    return {};
  }

  /// Validate and normalize food analysis data to ensure consistency
  Map<String, dynamic> _validateAndNormalizeFoodAnalysisData(
      Map<String, dynamic> data) {
    final normalizedData = <String, dynamic>{};

    // Validate and normalize food items
    if (data.containsKey('foodItems') && data['foodItems'] is List) {
      final foodItems = data['foodItems'] as List;
      final normalizedFoodItems = <Map<String, dynamic>>[];

      for (int i = 0; i < foodItems.length; i++) {
        final item = foodItems[i];
        if (item is Map<String, dynamic>) {
          final normalizedItem = _normalizeFoodItem(item, i);
          normalizedFoodItems.add(normalizedItem);
        }
      }

      normalizedData['foodItems'] = normalizedFoodItems;

      // Calculate total nutrition from normalized food items
      final totalNutrition =
          _calculateTotalNutritionFromItems(normalizedFoodItems);
      normalizedData['totalNutrition'] = totalNutrition;
    } else {
      // Create fallback food items if none exist
      normalizedData['foodItems'] = [
        {
          'name': 'Unknown Food',
          'estimatedWeight': '100g',
          'confidence': 'low',
          'nutritionalInfo': {
            'calories': 200,
            'protein': 10,
            'carbs': 20,
            'fat': 8,
            'fiber': 2,
            'sugar': 5,
            'sodium': 200,
          }
        }
      ];
      normalizedData['totalNutrition'] = {
        'calories': 200,
        'protein': 10,
        'carbs': 20,
        'fat': 8,
        'fiber': 2,
        'sugar': 5,
        'sodium': 200,
      };
    }

    // Add other required fields with defaults
    normalizedData['mealType'] = data['mealType'] ?? 'unknown';
    normalizedData['estimatedPortionSize'] =
        data['estimatedPortionSize'] ?? 'medium';
    normalizedData['confidence'] = data['confidence'] ?? 'low';
    normalizedData['healthScore'] = _extractHealthScoreFromData(data);
    normalizedData['notes'] = data['notes'] ?? 'Analysis completed';

    // Add missing fields that were being ignored
    normalizedData['ingredients'] = _normalizeIngredients(data['ingredients']);
    normalizedData['cookingMethod'] =
        data['cookingMethod']?.toString() ?? 'unknown';
    normalizedData['instructions'] =
        _normalizeInstructions(data['instructions']);
    normalizedData['dietaryFlags'] =
        _normalizeDietaryFlags(data['dietaryFlags']);
    normalizedData['suggestions'] = _normalizeSuggestions(data['suggestions']);

    return normalizedData;
  }

  /// Normalize a single food item with proper nutritional values
  Map<String, dynamic> _normalizeFoodItem(
      Map<String, dynamic> item, int index) {
    final normalizedItem = <String, dynamic>{};

    // Basic food item info
    normalizedItem['name'] = item['name'] ?? 'Food Item ${index + 1}';
    normalizedItem['estimatedWeight'] = item['estimatedWeight'] ?? '100g';
    normalizedItem['confidence'] = item['confidence'] ?? 'low';

    // Normalize nutritional info with realistic values
    final nutrition = item['nutritionalInfo'] as Map<String, dynamic>? ?? {};
    normalizedItem['nutritionalInfo'] = {
      'calories': _ensureInt(nutrition['calories'], _getDefaultCalories(index)),
      'protein': _ensureInt(nutrition['protein'], _getDefaultProtein(index)),
      'carbs': _ensureInt(nutrition['carbs'], _getDefaultCarbs(index)),
      'fat': _ensureInt(nutrition['fat'], _getDefaultFat(index)),
      'fiber': _ensureInt(nutrition['fiber'], 2),
      'sugar': _ensureInt(nutrition['sugar'], 5),
      'sodium': _ensureInt(nutrition['sodium'], 200),
    };

    return normalizedItem;
  }

  /// Ensure a value is an integer, with fallback
  int _ensureInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
      return parsed ?? fallback;
    }
    if (value is double) return value.round();
    return fallback;
  }

  /// Get default calories based on food item index (to ensure variety)
  int _getDefaultCalories(int index) {
    final defaults = [300, 250, 200, 150, 100];
    return defaults[index % defaults.length];
  }

  /// Get default protein based on food item index
  int _getDefaultProtein(int index) {
    final defaults = [25, 20, 15, 10, 5];
    return defaults[index % defaults.length];
  }

  /// Get default carbs based on food item index
  int _getDefaultCarbs(int index) {
    final defaults = [30, 25, 20, 15, 10];
    return defaults[index % defaults.length];
  }

  /// Get default fat based on food item index
  int _getDefaultFat(int index) {
    final defaults = [12, 10, 8, 6, 4];
    return defaults[index % defaults.length];
  }

  /// Calculate total nutrition from normalized food items
  Map<String, dynamic> _calculateTotalNutritionFromItems(
      List<Map<String, dynamic>> foodItems) {
    int totalCalories = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;
    int totalFiber = 0;
    int totalSugar = 0;
    int totalSodium = 0;

    for (final item in foodItems) {
      final nutrition = item['nutritionalInfo'] as Map<String, dynamic>;
      totalCalories += nutrition['calories'] as int;
      totalProtein += nutrition['protein'] as int;
      totalCarbs += nutrition['carbs'] as int;
      totalFat += nutrition['fat'] as int;
      totalFiber += nutrition['fiber'] as int;
      totalSugar += nutrition['sugar'] as int;
      totalSodium += nutrition['sodium'] as int;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
      'fiber': totalFiber,
      'sugar': totalSugar,
      'sodium': totalSodium,
    };
  }

  /// Extract health score from data with validation
  int _extractHealthScoreFromData(Map<String, dynamic> data) {
    final healthScore = data['healthScore'];
    if (healthScore is int && healthScore >= 1 && healthScore <= 10) {
      return healthScore;
    }
    if (healthScore is String) {
      final parsed =
          int.tryParse(healthScore.replaceAll(RegExp(r'[^0-9]'), ''));
      if (parsed != null && parsed >= 1 && parsed <= 10) {
        return parsed;
      }
    }
    return 5; // Default health score
  }

  /// Normalize ingredients to Map<String, String> format
  Map<String, String> _normalizeIngredients(dynamic ingredients) {
    if (ingredients == null) {
      return <String, String>{'unknown ingredient': '1 portion'};
    }

    if (ingredients is Map<String, dynamic>) {
      final normalizedIngredients = <String, String>{};
      ingredients.forEach((key, value) {
        normalizedIngredients[key.toString()] = value.toString();
      });
      return _normalizeAndDeduplicateIngredients(ingredients);
    }

    if (ingredients is List) {
      final normalizedIngredients = <String, String>{};
      for (int i = 0; i < ingredients.length; i++) {
        normalizedIngredients['ingredient${i + 1}'] = ingredients[i].toString();
      }
      return normalizedIngredients;
    }

    return <String, String>{'unknown ingredient': '1 portion'};
  }

  /// Normalize instructions to List<String> format
  List<String> _normalizeInstructions(dynamic instructions) {
    if (instructions == null) {
      return [
        'Food analyzed by AI',
        'Nutrition and ingredients estimated from image analysis'
      ];
    }

    if (instructions is List) {
      return instructions
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (instructions is String) {
      final trimmed = instructions.trim();
      return trimmed.isNotEmpty ? [trimmed] : ['Food analyzed by AI'];
    }

    return ['Food analyzed by AI'];
  }

  /// Normalize dietary flags to Map<String, bool> format
  Map<String, bool> _normalizeDietaryFlags(dynamic dietaryFlags) {
    final defaultFlags = <String, bool>{
      'vegetarian': false,
      'vegan': false,
      'glutenFree': false,
      'dairyFree': false,
      'keto': false,
      'lowCarb': false,
    };

    if (dietaryFlags == null || dietaryFlags is! Map) {
      return defaultFlags;
    }

    final normalizedFlags = <String, bool>{};
    dietaryFlags.forEach((key, value) {
      final keyStr = key.toString();
      if (defaultFlags.containsKey(keyStr)) {
        if (value is bool) {
          normalizedFlags[keyStr] = value;
        } else if (value is String) {
          normalizedFlags[keyStr] = value.toLowerCase() == 'true';
        } else {
          normalizedFlags[keyStr] = false;
        }
      }
    });

    // Fill in missing flags with defaults
    defaultFlags.forEach((key, defaultValue) {
      normalizedFlags[key] ??= defaultValue;
    });

    return normalizedFlags;
  }

  /// Normalize suggestions to proper format
  Map<String, List<String>> _normalizeSuggestions(dynamic suggestions) {
    final defaultSuggestions = <String, List<String>>{
      'improvements': <String>[],
      'alternatives': <String>[],
      'additions': <String>[],
    };

    if (suggestions == null || suggestions is! Map) {
      return defaultSuggestions;
    }

    final normalizedSuggestions = <String, List<String>>{};
    suggestions.forEach((key, value) {
      final keyStr = key.toString();
      if (defaultSuggestions.containsKey(keyStr)) {
        if (value is List) {
          normalizedSuggestions[keyStr] = value
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
        } else if (value is String) {
          final trimmed = value.trim();
          normalizedSuggestions[keyStr] =
              trimmed.isNotEmpty ? [trimmed] : <String>[];
        } else {
          normalizedSuggestions[keyStr] = <String>[];
        }
      }
    });

    // Fill in missing categories with defaults
    defaultSuggestions.forEach((key, defaultValue) {
      normalizedSuggestions[key] ??= defaultValue;
    });

    return normalizedSuggestions;
  }

  /// Extract JSON from markdown code blocks
  String _extractJsonFromMarkdown(String text) {
    // Remove markdown code block markers
    String cleaned =
        text.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
    return cleaned.trim();
  }

  /// Attempt to complete truncated JSON responses
  String _completeTruncatedJson(String text) {
    // Check if the JSON appears to be truncated
    if (!text.trim().endsWith('}')) {
      // Count opening and closing braces
      final openBraces = '{'.allMatches(text).length;
      final closeBraces = '}'.allMatches(text).length;

      // If we have more opening braces than closing braces, try to complete
      if (openBraces > closeBraces) {
        final missingBraces = openBraces - closeBraces;
        text += '}' * missingBraces;

        // Also check for incomplete arrays
        final openBrackets = '['.allMatches(text).length;
        final closeBrackets = ']'.allMatches(text).length;
        if (openBrackets > closeBrackets) {
          final missingBrackets = openBrackets - closeBrackets;
          text += ']' * missingBrackets;
        }

        print(
            'Attempted to complete truncated JSON by adding $missingBraces closing braces');
      }
    }

    return text;
  }

  /// Extract food analysis data from raw text using regex patterns
  Map<String, dynamic> _extractFoodAnalysisFromRawText(String rawResponse) {
    final extractedData = <String, dynamic>{};

    try {
      // Extract food items using regex patterns
      final foodItems = _extractFoodItemsFromText(rawResponse);

      if (foodItems.isNotEmpty) {
        extractedData['foodItems'] = foodItems;

        // Calculate total nutrition from extracted food items
        final totalNutrition = _calculateTotalNutrition(foodItems);
        extractedData['totalNutrition'] = totalNutrition;

        // Extract additional fields
        extractedData['healthScore'] = _extractHealthScore(rawResponse);
        extractedData['mealType'] = _extractMealType(rawResponse);

        // Extract missing fields using regex patterns
        extractedData['ingredients'] = _extractIngredientsFromText(rawResponse);
        extractedData['cookingMethod'] =
            _extractCookingMethodFromText(rawResponse);
        extractedData['instructions'] =
            _extractInstructionsFromText(rawResponse);
        extractedData['dietaryFlags'] =
            _extractDietaryFlagsFromText(rawResponse);
        extractedData['suggestions'] = _extractSuggestionsFromText(rawResponse);
        extractedData['estimatedPortionSize'] =
            _extractPortionSizeFromText(rawResponse);

        extractedData['confidence'] = 'extracted';
        extractedData['notes'] =
            'Data extracted from raw text using regex patterns';

        return extractedData;
      }
    } catch (e) {
      print('Food analysis extraction failed: $e');
    }

    return {};
  }

  /// Extract food items from raw text
  List<Map<String, dynamic>> _extractFoodItemsFromText(String text) {
    final foodItems = <Map<String, dynamic>>[];

    // Pattern to match food item blocks
    final foodItemPattern = RegExp(
        r'"name":\s*"([^"]+)".*?"estimatedWeight":\s*"([^"]+)".*?"confidence":\s*"([^"]+)"',
        multiLine: true,
        dotAll: true);

    final matches = foodItemPattern.allMatches(text);

    for (final match in matches) {
      final name = match.group(1) ?? 'Unknown Food';
      final weight = match.group(2) ?? '100g';
      final confidence = match.group(3) ?? 'low';

      // Extract nutritional info for this specific food item
      final nutrition = _extractNutritionalInfoForFood(text, name);

      foodItems.add({
        'name': name,
        'estimatedWeight': weight,
        'confidence': confidence,
        'nutritionalInfo': nutrition,
      });
    }

    return foodItems;
  }

  /// Extract nutritional info for a specific food item
  Map<String, dynamic> _extractNutritionalInfoForFood(
      String text, String foodName) {
    // Use a more flexible pattern to find the food item with its nutrition
    // Handle both quoted and unquoted numeric values
    final escapedFoodName = RegExp.escape(foodName);
    final pattern =
        '"name":\\s*"$escapedFoodName".*?"nutritionalInfo":\\s*\\{.*?"calories":\\s*"?(\\d+)"?.*?"protein":\\s*"?(\\d+)"?.*?"carbs":\\s*"?(\\d+)"?.*?"fat":\\s*"?(\\d+)"?.*?"fiber":\\s*"?(\\d+)"?.*?"sugar":\\s*"?(\\d+)"?.*?"sodium":\\s*"?(\\d+)"?';

    final foodSectionPattern = RegExp(pattern, multiLine: true, dotAll: true);

    final match = foodSectionPattern.firstMatch(text);
    if (match != null) {
      // Extract individual nutritional values
      final calories = int.tryParse(match.group(1) ?? '0') ?? 0;
      final protein = int.tryParse(match.group(2) ?? '0') ?? 0;
      final carbs = int.tryParse(match.group(3) ?? '0') ?? 0;
      final fat = int.tryParse(match.group(4) ?? '0') ?? 0;
      final fiber = int.tryParse(match.group(5) ?? '0') ?? 0;
      final sugar = int.tryParse(match.group(6) ?? '0') ?? 0;
      final sodium = int.tryParse(match.group(7) ?? '0') ?? 0;

      return {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
        'sodium': sodium,
      };
    }

    // Fallback nutritional info
    return {
      'calories': 200,
      'protein': 10,
      'carbs': 20,
      'fat': 8,
      'fiber': 2,
      'sugar': 5,
      'sodium': 200,
    };
  }

  /// Calculate total nutrition from food items
  Map<String, dynamic> _calculateTotalNutrition(
      List<Map<String, dynamic>> foodItems) {
    int totalCalories = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;
    int totalFiber = 0;
    int totalSugar = 0;
    int totalSodium = 0;

    for (final item in foodItems) {
      final nutrition = item['nutritionalInfo'] as Map<String, dynamic>;
      totalCalories += nutrition['calories'] as int;
      totalProtein += nutrition['protein'] as int;
      totalCarbs += nutrition['carbs'] as int;
      totalFat += nutrition['fat'] as int;
      totalFiber += nutrition['fiber'] as int;
      totalSugar += nutrition['sugar'] as int;
      totalSodium += nutrition['sodium'] as int;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
      'fiber': totalFiber,
      'sugar': totalSugar,
      'sodium': totalSodium,
    };
  }

  /// Extract health score from text
  int _extractHealthScore(String text) {
    // Look for healthScore with or without trailing quotes
    final healthScorePatterns = [
      RegExp(r'"healthScore":\s*(\d+)(?=\s*[,}\]])'), // Without trailing quote
      RegExp(r'"healthScore":\s*(\d+)"(?=\s*[,}\]])'), // With trailing quote
    ];

    for (final pattern in healthScorePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '5') ?? 5;
      }
    }

    return 5; // Default health score
  }

  /// Extract meal type from text
  String _extractMealType(String text) {
    final mealTypeMatch = RegExp(r'"mealType":\s*"([^"]+)"').firstMatch(text);
    return mealTypeMatch?.group(1) ?? 'unknown';
  }

  /// Extract ingredients from text using regex patterns
  Map<String, String> _extractIngredientsFromText(String text) {
    final ingredients = <String, String>{};

    // Look for ingredients section
    final ingredientsMatch = RegExp(
      r'"ingredients":\s*\{([^}]+)\}',
      multiLine: true,
      dotAll: true,
    ).firstMatch(text);

    if (ingredientsMatch != null) {
      final ingredientsText = ingredientsMatch.group(1) ?? '';

      // Extract individual ingredients
      final ingredientMatches = RegExp(
        r'"([^"]+)":\s*"([^"]+)"',
        multiLine: true,
      ).allMatches(ingredientsText);

      for (final match in ingredientMatches) {
        final key = match.group(1)?.trim();
        final value = match.group(2)?.trim();
        if (key != null && value != null) {
          ingredients[key] = value;
        }
      }
    }

    return ingredients.isNotEmpty
        ? ingredients
        : {'unknown ingredient': '1 portion'};
  }

  /// Extract cooking method from text
  String _extractCookingMethodFromText(String text) {
    final cookingMethodMatch =
        RegExp(r'"cookingMethod":\s*"([^"]+)"').firstMatch(text);
    return cookingMethodMatch?.group(1) ?? 'unknown';
  }

  /// Extract instructions from text
  List<String> _extractInstructionsFromText(String text) {
    final instructions = <String>[];

    // Look for instructions array
    final instructionsMatch = RegExp(
      r'"instructions":\s*\[([^\]]+)\]',
      multiLine: true,
      dotAll: true,
    ).firstMatch(text);

    if (instructionsMatch != null) {
      final instructionsText = instructionsMatch.group(1) ?? '';

      // Extract individual instructions
      final instructionMatches = RegExp(
        r'"([^"]+)"',
        multiLine: true,
      ).allMatches(instructionsText);

      for (final match in instructionMatches) {
        final instruction = match.group(1)?.trim();
        if (instruction != null && instruction.isNotEmpty) {
          instructions.add(instruction);
        }
      }
    }

    return instructions.isNotEmpty ? instructions : ['Food analyzed by AI'];
  }

  /// Extract dietary flags from text
  Map<String, bool> _extractDietaryFlagsFromText(String text) {
    final defaultFlags = <String, bool>{
      'vegetarian': false,
      'vegan': false,
      'glutenFree': false,
      'dairyFree': false,
      'keto': false,
      'lowCarb': false,
    };

    // Look for dietaryFlags section
    final dietaryFlagsMatch = RegExp(
      r'"dietaryFlags":\s*\{([^}]+)\}',
      multiLine: true,
      dotAll: true,
    ).firstMatch(text);

    if (dietaryFlagsMatch != null) {
      final flagsText = dietaryFlagsMatch.group(1) ?? '';

      // Extract individual flags
      final flagMatches = RegExp(
        r'"([^"]+)":\s*(true|false)',
        multiLine: true,
      ).allMatches(flagsText);

      for (final match in flagMatches) {
        final key = match.group(1)?.trim();
        final value = match.group(2)?.trim();
        if (key != null && defaultFlags.containsKey(key)) {
          defaultFlags[key] = value?.toLowerCase() == 'true';
        }
      }
    }

    return defaultFlags;
  }

  /// Extract suggestions from text
  Map<String, List<String>> _extractSuggestionsFromText(String text) {
    final defaultSuggestions = <String, List<String>>{
      'improvements': <String>[],
      'alternatives': <String>[],
      'additions': <String>[],
    };

    // Look for suggestions section
    final suggestionsMatch = RegExp(
      r'"suggestions":\s*\{([^}]+)\}',
      multiLine: true,
      dotAll: true,
    ).firstMatch(text);

    if (suggestionsMatch != null) {
      final suggestionsText = suggestionsMatch.group(1) ?? '';

      // Extract each category
      for (final category in defaultSuggestions.keys) {
        final categoryMatch = RegExp(
          '"$category":\\s*\\[([^\\]]+)\\]',
          multiLine: true,
          dotAll: true,
        ).firstMatch(suggestionsText);

        if (categoryMatch != null) {
          final categoryText = categoryMatch.group(1) ?? '';
          final itemMatches = RegExp(
            r'"([^"]+)"',
            multiLine: true,
          ).allMatches(categoryText);

          final items = <String>[];
          for (final match in itemMatches) {
            final item = match.group(1)?.trim();
            if (item != null && item.isNotEmpty) {
              items.add(item);
            }
          }

          if (items.isNotEmpty) {
            defaultSuggestions[category] = items;
          }
        }
      }
    }

    return defaultSuggestions;
  }

  /// Extract portion size from text
  String _extractPortionSizeFromText(String text) {
    final portionMatch =
        RegExp(r'"estimatedPortionSize":\s*"([^"]+)"').firstMatch(text);
    return portionMatch?.group(1) ?? 'medium';
  }

  /// Create fallback response for failed AI operations
  Map<String, dynamic> _createFallbackResponse(String operation, String error) {
    switch (operation) {
      case 'tasty_analysis':
        return {
          'foodItems': [
            {
              'name': 'Unknown Food',
              'estimatedWeight': '100g',
              'confidence': 'low',
              'nutritionalInfo': {
                'calories': 200,
                'protein': 10,
                'carbs': 20,
                'fat': 8,
                'fiber': 2,
                'sugar': 5,
                'sodium': 200
              }
            }
          ],
          'totalNutrition': {
            'calories': 200,
            'protein': 10,
            'carbs': 20,
            'fat': 8,
            'fiber': 2,
            'sugar': 5,
            'sodium': 200
          },
          'mealType': 'unknown',
          'estimatedPortionSize': 'medium',
          'ingredients': {'unknown ingredient': '1 portion'},
          'cookingMethod': 'unknown',
          'confidence': 'low',
          'healthScore': 7,
          'instructions': [
            'Analysis failed: $error',
            'Please verify nutritional information manually.'
          ],
          'dietaryFlags': {
            'vegetarian': false,
            'vegan': false,
            'glutenFree': false,
            'dairyFree': false,
            'keto': false,
            'lowCarb': false,
          },
          'suggestions': {
            'improvements': ['Manual verification recommended'],
            'alternatives': ['Consult nutrition database'],
            'additions': ['Consider professional dietary advice'],
          },
          'notes':
              'Analysis failed: $error. Please verify nutritional information manually.'
        };
      case 'meal_generation':
        return {
          'meals': [
            {
              'title': 'Simple Meal',
              'type': 'protein',
              'description': 'A basic meal when AI analysis failed',
              'cookingTime': '15 minutes',
              'cookingMethod': 'cooking',
              'ingredients': {'main ingredient': '1 portion'},
              'instructions': [
                'Analysis failed: $error',
                'Please create meal manually'
              ],
              'nutritionalInfo': {
                'calories': 300,
                'protein': 15,
                'carbs': 30,
                'fat': 10
              },
              'categories': ['error-fallback'],
              'serveQty': 1
            }
          ],
          'nutritionalSummary': {
            'totalCalories': 300,
            'totalProtein': 15,
            'totalCarbs': 30,
            'totalFat': 10
          },
          'tips': ['AI analysis failed, please verify all information manually']
        };
      case 'meal_plan':
        return {
          'meals': [
            {
              'title': 'Simple Breakfast',
              'type': 'protein',
              'mealType': 'breakfast',
              'ingredients': {'eggs': '2', 'bread': '1 slice'},
              'instructions': [
                'Analysis failed: $error',
                'Please create meal manually'
              ],
              'diet': 'general',
              'nutritionalInfo': {
                'calories': 250,
                'protein': 15,
                'carbs': 20,
                'fat': 12
              },
              'categories': ['error-fallback'],
              'serveQty': 1
            },
            {
              'title': 'Simple Lunch',
              'type': 'protein',
              'mealType': 'lunch',
              'ingredients': {'chicken': '100g', 'rice': '1/2 cup'},
              'instructions': [
                'Analysis failed: $error',
                'Please create meal manually'
              ],
              'diet': 'general',
              'nutritionalInfo': {
                'calories': 350,
                'protein': 25,
                'carbs': 30,
                'fat': 15
              },
              'categories': ['error-fallback'],
              'serveQty': 1
            },
            {
              'title': 'Simple Dinner',
              'type': 'protein',
              'mealType': 'dinner',
              'ingredients': {'fish': '150g', 'vegetables': '1 cup'},
              'instructions': [
                'Analysis failed: $error',
                'Please create meal manually'
              ],
              'diet': 'general',
              'nutritionalInfo': {
                'calories': 300,
                'protein': 30,
                'carbs': 15,
                'fat': 18
              },
              'categories': ['error-fallback'],
              'serveQty': 1
            }
          ],
          'nutritionalSummary': {
            'totalCalories': 900,
            'totalProtein': 70,
            'totalCarbs': 65,
            'totalFat': 45
          },
          'tips': ['AI analysis failed, please verify all information manually']
        };
      case 'program_generation':
        return {
          'duration': '4 weeks',
          'weeklyPlans': [
            {
              'week': 1,
              'goals': ['Basic health improvement'],
              'mealPlan': {
                'breakfast': ['Simple breakfast option'],
                'lunch': ['Simple lunch option'],
                'dinner': ['Simple dinner option'],
                'snacks': ['Healthy snack']
              },
              'nutritionGuidelines': {
                'calories': '1800-2200',
                'protein': '80-120g',
                'carbs': '200-250g',
                'fats': '60-80g'
              },
              'tips': [
                'Analysis failed: $error',
                'Please create program manually'
              ]
            }
          ],
          'requirements': ['Manual verification needed'],
          'recommendations': ['Please verify all information manually']
        };
      case 'food_comparison':
        return {
          'image1Analysis': {
            'foodItems': ['Unknown Food 1'],
            'totalNutrition': {
              'calories': 200,
              'protein': 10,
              'carbs': 20,
              'fat': 8
            },
            'healthScore': 5
          },
          'image2Analysis': {
            'foodItems': ['Unknown Food 2'],
            'totalNutrition': {
              'calories': 200,
              'protein': 10,
              'carbs': 20,
              'fat': 8
            },
            'healthScore': 5
          },
          'comparison': {
            'winner': 'tie',
            'reasons': ['Analysis failed: $error'],
            'nutritionalDifferences': {
              'calories': 'Unable to determine',
              'protein': 'Unable to determine',
              'carbs': 'Unable to determine',
              'fat': 'Unable to determine'
            }
          },
          'recommendations': ['Manual verification needed'],
          'summary': 'Comparison failed, please verify manually'
        };
      case '54321_shopping':
        return {
          'shoppingList': {
            'vegetables': [
              {
                'name': 'Spinach',
                'amount': '1 bunch',
                'category': 'vegetable',
                'notes': 'Fresh and crisp'
              },
              {
                'name': 'Carrots',
                'amount': '500g',
                'category': 'vegetable',
                'notes': 'Organic if possible'
              },
              {
                'name': 'Bell Peppers',
                'amount': '3 pieces',
                'category': 'vegetable',
                'notes': 'Mixed colors'
              },
              {
                'name': 'Broccoli',
                'amount': '1 head',
                'category': 'vegetable',
                'notes': 'Fresh green'
              },
              {
                'name': 'Tomatoes',
                'amount': '4 pieces',
                'category': 'vegetable',
                'notes': 'Ripe and firm'
              }
            ],
            'fruits': [
              {
                'name': 'Bananas',
                'amount': '1 bunch',
                'category': 'fruit',
                'notes': 'Yellow with green tips'
              },
              {
                'name': 'Apples',
                'amount': '6 pieces',
                'category': 'fruit',
                'notes': 'Crisp and sweet'
              },
              {
                'name': 'Oranges',
                'amount': '4 pieces',
                'category': 'fruit',
                'notes': 'Juicy and fresh'
              },
              {
                'name': 'Berries',
                'amount': '250g',
                'category': 'fruit',
                'notes': 'Mixed berries'
              }
            ],
            'proteins': [
              {
                'name': 'Chicken Breast',
                'amount': '500g',
                'category': 'protein',
                'notes': 'Skinless and boneless'
              },
              {
                'name': 'Eggs',
                'amount': '12 pieces',
                'category': 'protein',
                'notes': 'Fresh farm eggs'
              },
              {
                'name': 'Salmon',
                'amount': '300g',
                'category': 'protein',
                'notes': 'Wild caught if available'
              }
            ],
            'sauces': [
              {
                'name': 'Olive Oil',
                'amount': '250ml',
                'category': 'sauce',
                'notes': 'Extra virgin'
              },
              {
                'name': 'Hummus',
                'amount': '200g',
                'category': 'sauce',
                'notes': 'Classic or flavored'
              }
            ],
            'grains': [
              {
                'name': 'Brown Rice',
                'amount': '500g',
                'category': 'grain',
                'notes': 'Organic whole grain'
              }
            ],
            'treats': [
              {
                'name': 'Dark Chocolate',
                'amount': '100g',
                'category': 'treat',
                'notes': '70% cocoa or higher'
              }
            ]
          },
          'totalItems': 16,
          'estimatedCost': '\$50-70',
          'tips': [
            'Buy seasonal produce for better prices',
            'Check for sales on proteins',
            'Store vegetables properly to extend freshness'
          ],
          'mealIdeas': [
            'Grilled chicken with roasted vegetables',
            'Salmon with rice and steamed broccoli',
            'Egg scramble with fresh vegetables'
          ]
        };
      default:
        return {'error': true, 'message': 'Operation failed: $error'};
    }
  }

  // Initialize and find a working model
  Future<bool> initializeModel() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print('Error: GEMINI_API_KEY is not set in .env file');
      return false;
    }

    try {
      print('Fetching available models...');
      final response = await http.get(
        Uri.parse('$_baseUrl/models?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final models = decoded['models'] as List;

        // Look for available text models in order of preference
        final preferredModels = [
          'gemini-1.5-flash',
          'gemini-1.5-pro',
          'gemini-pro-vision',
        ];

        for (final modelName in preferredModels) {
          try {
            final model = models.firstWhere(
              (m) => m['name'].toString().endsWith(modelName),
            );

            // Store the full model path
            _activeModel = model['name'].toString();
            return true;
          } catch (e) {
            print('Model $modelName not found, trying next...');
            continue;
          }
        }

        print('Warning: No preferred models found. Available models:');
        print(JsonEncoder.withIndent('  ').convert(models));
        return false;
      } else {
        print('Error listing models: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('Exception while initializing model: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get comprehensive user context including program details
  Future<Map<String, dynamic>> _getUserContext() async {
    final currentUserId = userService.userId;
    if (currentUserId == null) {
      return {
        'hasProgram': false,
        'encourageProgram': true,
        'familyMode': false,
        'dietPreference': 'none',
        'programMessage':
            'Consider enrolling in a personalized program to get tailored meal plans and nutrition guidance.',
      };
    }

    // Check cache validity (refresh every 30 minutes or if user changed)
    final now = DateTime.now();
    if (_cachedUserContext != null &&
        _lastUserId == currentUserId &&
        _lastContextFetch != null &&
        now.difference(_lastContextFetch!).inMinutes < 30) {
      return _cachedUserContext!;
    }

    try {
      // Fetch user's current program enrollment
      final userProgramQuery = await firestore
          .collection('userProgram')
          .where('userIds', arrayContains: currentUserId)
          .limit(1)
          .get();

      Map<String, dynamic> context = {
        'userId': currentUserId,
        'familyMode': userService.currentUser.value?.familyMode ?? false,
        'dietPreference':
            userService.currentUser.value?.settings['dietPreference'] ?? 'none',
        'hasProgram': false,
        'encourageProgram': true,
      };

      if (userProgramQuery.docs.isNotEmpty) {
        final userProgramDoc = userProgramQuery.docs.first;
        final userProgramData = userProgramDoc.data();
        final programId = userProgramDoc.id; // Document ID is the program ID

        if (programId.isNotEmpty) {
          // Fetch program details
          final programDoc =
              await firestore.collection('programs').doc(programId).get();

          if (programDoc.exists) {
            final programData = programDoc.data()!;

            context.addAll({
              'hasProgram': true,
              'encourageProgram': false,
              'currentProgram': {
                'id': programId,
                'name': programData['name'] ?? 'Current Program',
                'goal': programData['goal'] ?? 'Health improvement',
                'description': programData['description'] ?? '',
                'duration': programData['duration'] ?? '4 weeks',
                'dietType':
                    programData['dietType'] ?? context['dietPreference'],
                'weeklyPlans': programData['weeklyPlans'] ?? [],
                'requirements': programData['requirements'] ?? [],
                'recommendations': programData['recommendations'] ?? [],
              },
              'programProgress': {
                'startDate': userProgramData['startDate'],
                'currentWeek': userProgramData['currentWeek'] ?? 1,
                'completedDays': userProgramData['completedDays'] ?? 0,
              },
              'programMessage':
                  'Continue following your ${programData['name']} program with goal: ${programData['goal']}. Consider these recommendations in all meal suggestions.',
            });
          }
        }
      }

      if (!context['hasProgram']) {
        context['programMessage'] =
            'Consider enrolling in a personalized program to get tailored meal plans, nutrition guidance, and achieve your health goals more effectively.';
      }

      // Cache the context
      _cachedUserContext = context;
      _lastUserId = currentUserId;
      _lastContextFetch = now;

      return context;
    } catch (e) {
      print('Error fetching user context: $e');
      // Return basic context on error
      return {
        'userId': currentUserId,
        'familyMode': userService.currentUser.value?.familyMode ?? false,
        'dietPreference':
            userService.currentUser.value?.settings['dietPreference'] ?? 'none',
        'hasProgram': false,
        'encourageProgram': true,
        'programMessage':
            'Consider enrolling in a personalized program to get tailored meal plans and nutrition guidance.',
      };
    }
  }

  /// Build comprehensive context string for AI prompts
  Future<String> _buildAIContext() async {
    final userContext = await _getUserContext();

    String context = '''
USER CONTEXT:
- Family Mode: ${userContext['familyMode'] ? 'Yes (generate family-friendly portions and options)' : 'No (individual portions)'}
- Diet Preference: ${userContext['dietPreference']}
''';

    if (userContext['hasProgram'] == true) {
      final program = userContext['currentProgram'] as Map<String, dynamic>;
      final progress = userContext['programProgress'] as Map<String, dynamic>;

      context += '''
- Current Program: ${program['name']}
- Program Goal: ${program['goal']}
- Program Duration: ${program['duration']}
- Current Week: ${progress['currentWeek']}
- Program Diet Type: ${program['dietType']}
''';

      if (program['requirements'] != null &&
          (program['requirements'] as List).isNotEmpty) {
        context +=
            '- Program Requirements: ${(program['requirements'] as List).join(', ')}\n';
      }

      if (program['recommendations'] != null &&
          (program['recommendations'] as List).isNotEmpty) {
        context +=
            '- Program Recommendations: ${(program['recommendations'] as List).join(', ')}\n';
      }

      context +=
          '\nIMPORTANT: All meal suggestions should align with the user\'s current program goals and requirements. ';
    } else {
      context +=
          '\nNOTE: User is not enrolled in a program. Gently encourage program enrollment for personalized guidance. ';
    }

    context += userContext['programMessage'] as String;

    return context;
  }

  /// Clear cached context (call when user changes programs or significant updates)
  void clearContextCache() {
    _cachedUserContext = null;
    _lastUserId = null;
    _lastContextFetch = null;
  }

  /// Get user's current program status (public method for other services)
  Future<bool> isUserEnrolledInProgram() async {
    final context = await _getUserContext();
    return context['hasProgram'] == true;
  }

  /// Get current program details (public method for other services)
  Future<Map<String, dynamic>?> getCurrentProgramDetails() async {
    final context = await _getUserContext();
    if (context['hasProgram'] == true) {
      return context['currentProgram'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// Force refresh of user context (useful after program enrollment/changes)
  Future<void> refreshUserContext() async {
    clearContextCache();
    await _getUserContext(); // This will fetch fresh data
  }

  Future<String> getResponse(String prompt, int maxTokens,
      {String? role}) async {
    // Initialize model if not already done
    if (_activeModel == null) {
      final initialized = await initializeModel();
      if (!initialized) {
        return 'Error: No suitable AI model available';
      }
    }

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return 'Error: API key not configured';
    }

    // Get comprehensive user context
    final aiContext = await _buildAIContext();

    // Add brevity instruction and context to the role/prompt
    final briefingInstruction =
        "Please provide brief, concise responses in 2-4 sentences maximum. ";
    final modifiedPrompt = role != null
        ? '$briefingInstruction\n$aiContext\n$role\nUser: $prompt'
        : '$briefingInstruction\n$aiContext\nUser: $prompt';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/${_activeModel}:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": modifiedPrompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens":
                maxTokens, // Reduced from 1024 to encourage brevity
            // Removed stopSequences as it might be causing empty responses
          },
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded.containsKey('candidates') &&
            decoded['candidates'] is List &&
            decoded['candidates'].isNotEmpty) {
          final candidate = decoded['candidates'][0];

          if (candidate.containsKey('content') && candidate['content'] is Map) {
            final content = candidate['content'];

            if (content.containsKey('parts') &&
                content['parts'] is List &&
                content['parts'].isNotEmpty) {
              final part = content['parts'][0];

              if (part.containsKey('text')) {
                final text = part['text'];

                // Clean up any remaining newlines or extra spaces
                final cleanedText = (text ?? "I couldn't understand that.")
                    .trim()
                    .replaceAll(RegExp(r'\n+'), ' ')
                    .replaceAll(RegExp(r'\s+'), ' ');

                return cleanedText;
              } else {
                return 'Error: No text content in API response';
              }
            } else {
              return 'Error: No content parts in API response';
            }
          } else {
            return 'Error: No content in API response';
          }
        } else {
          return 'Error: No candidates in API response';
        }
      } else {
        print('AI API Error: ${response.body}');
        _activeModel = null;
        return 'Error: ${response.statusCode}';
      }
    } catch (e) {
      if (e is FormatException) {}
      _activeModel = null;
      return 'Error: Failed to connect to AI service';
    }
  }

  // Utility to extract JSON object from Gemini response text
  Map<String, dynamic> _extractJsonObject(String text) {
    String jsonStr = text.trim();

    // Remove markdown code block syntax if present
    if (jsonStr.startsWith('```json')) {
      jsonStr = jsonStr.replaceFirst('```json', '').trim();
    }
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replaceFirst('```', '').trim();
    }
    if (jsonStr.endsWith('```')) {
      jsonStr = jsonStr.substring(0, jsonStr.lastIndexOf('```')).trim();
    }

    // Fix common JSON issues from AI responses
    jsonStr = _sanitizeJsonString(jsonStr);

    return jsonDecode(jsonStr);
  }

  // Sanitize JSON string to fix common AI response issues
  String _sanitizeJsonString(String jsonStr) {
    // Fix trailing quotes after ANY numeric values - more comprehensive approach
    // This catches cases like "healthScore": 6", "calories": 450", etc.
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"([^"]+)":\s*(\d+(?:\.\d+)?)"(?=\s*[,}\]])', multiLine: true),
        (match) {
      final fieldName = match.group(1) ?? '';
      final numericValue = match.group(2) ?? '';
      return '"$fieldName": $numericValue';
    });

    // Fix trailing quotes after numbers that might have spaces (e.g., "healthScore": 6 " -> "healthScore": 6)
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"([^"]+)":\s*(\d+(?:\.\d+)?)\s*"(?=\s*[,}\]])',
            multiLine: true), (match) {
      final fieldName = match.group(1) ?? '';
      final numericValue = match.group(2) ?? '';
      return '"$fieldName": $numericValue';
    });

    // Fix any remaining trailing quotes after numbers (catch-all)
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'":\s*(\d+(?:\.\d+)?)"(?=\s*[,}\]])', multiLine: true),
        (match) {
      final numericValue = match.group(1) ?? '';
      return ': $numericValue';
    });

    // Fix any other numeric fields with trailing quotes
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"([^"]+)":\s*(\d+(?:\.\d+)?)"(?=\s*[,}\]])', multiLine: true),
        (match) => '"${match.group(1)}": ${match.group(2)}');

    // Fix unquoted nutritional values like "protein": 40g to "protein": "40g"
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(
            r'"(calories|protein|carbs|fat|fiber|sugar|sodium)":\s*(\d+(?:\.\d+)?[a-zA-Z]*)',
            multiLine: true),
        (match) => '"${match.group(1)}": "${match.group(2)}"');

    // Fix unquoted numeric values followed by units like 40g, 25mg, etc.
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r':\s*(\d+(?:\.\d+)?[a-zA-Z]+)(?=[,\]\}])', multiLine: true),
        (match) => ': "${match.group(1)}"');

    // Fix missing quotes around standalone numbers that should be strings
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(
            r'"(totalCalories|totalProtein|totalCarbs|totalFat)":\s*(\d+(?:\.\d+)?)',
            multiLine: true),
        (match) =>
            '"${match.group(1)}": ${match.group(2)}' // Keep these as numbers
        );

    // Fix unterminated strings - look for strings that don't end with a quote
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"([^"]*?)(?=\s*[,}\]])', multiLine: true), (match) {
      final value = match.group(1) ?? '';
      // If the value doesn't end with a quote, add one
      if (!value.endsWith('"')) {
        return '"$value"';
      }
      return match.group(0) ?? '';
    });

    // Fix specific diet type unterminated strings
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"diet":\s*"([^"]*?)(?=\s*[,}\]])', multiLine: true), (match) {
      final dietValue = match.group(1) ?? '';
      if (!dietValue.endsWith('"')) {
        return '"diet": "$dietValue"';
      }
      return match.group(0) ?? '';
    });

    // Fix diet field with missing quotes in the middle (e.g., "diet": "low-carb", dairy-free")
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"diet":\s*"([^"]*?),\s*([^"]*?)"(?=\s*[,}\]])',
            multiLine: true), (match) {
      final firstPart = match.group(1) ?? '';
      final secondPart = match.group(2) ?? '';
      return '"diet": "$firstPart, $secondPart"';
    });

    // Fix diet field with unquoted values after comma (e.g., "diet": "low-carb", dairy-free)
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"diet":\s*"([^"]*?)",\s*([^"]*?)(?=\s*[,}\]])',
            multiLine: true), (match) {
      final firstPart = match.group(1) ?? '';
      final secondPart = match.group(2) ?? '';
      return '"diet": "$firstPart, $secondPart"';
    });

    // Fix double quotes in string values (e.g., "title": "value"")
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"([^"]*?)""(?=\s*[,}\]])', multiLine: true),
        (match) => '"${match.group(1)}"');

    // Fix broken value where comma-suffixed text is outside quotes
    // Example: "onion": "1/4 medium", chopped" -> "onion": "1/4 medium, chopped"
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"([\w\s]+)":\s*"([^"]*?)",\s*([A-Za-z][^",}\]]*)"',
            multiLine: true), (match) {
      final key = match.group(1) ?? '';
      final first = match.group(2) ?? '';
      final second = match.group(3) ?? '';
      return '"$key": "$first, $second"';
    });

    // Fix unquoted nutritional values with units (e.g., "protein": 20g -> "protein": "20g")
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(
            r'"(calories|protein|carbs|fat|fiber|sugar|sodium)":\s*(\d+[a-zA-Z]+)',
            multiLine: true),
        (match) => '"${match.group(1)}": "${match.group(2)}"');

    // Fix any remaining unquoted values with units that might be missed
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r':\s*(\d+[a-zA-Z]+)(?=[,\]\}])', multiLine: true),
        (match) => ': "${match.group(1)}"');

    return jsonStr;
  }

  // Normalize meal plan data similar to FoodAnalysis normalization
  Map<String, dynamic> _normalizeMealPlanData(Map<String, dynamic> data) {
    if (!data.containsKey('meals') || data['meals'] is! List) return data;

    final meals =
        (data['meals'] as List).whereType<Map<String, dynamic>>().toList();
    for (final meal in meals) {
      // Ensure required fields
      meal['title'] = meal['title']?.toString() ?? 'Untitled Meal';
      meal['type'] = meal['type']?.toString() ?? 'protein';
      meal['mealType'] = meal['mealType']?.toString() ?? 'breakfast';
      meal['serveQty'] = (meal['serveQty'] is num)
          ? (meal['serveQty'] as num).toInt()
          : int.tryParse(meal['serveQty']?.toString() ?? '') ?? 1;

      // Ingredients normalization to Map<String,String>
      final ing = meal['ingredients'];
      Map<String, dynamic> ingMap = {};
      if (ing is Map) {
        ing.forEach((k, v) => ingMap[k.toString()] = v.toString());
      } else if (ing is List) {
        for (int i = 0; i < ing.length; i++) {
          ingMap['ingredient${i + 1}'] = ing[i].toString();
        }
      }
      meal['ingredients'] =
          _normalizeAndDeduplicateIngredients(ingMap.cast<String, dynamic>());

      // Instructions normalization to List<String>
      final steps = meal['instructions'];
      if (steps is List) {
        meal['instructions'] = steps.map((e) => e.toString()).toList();
      } else if (steps is String) {
        meal['instructions'] = [steps];
      } else {
        meal['instructions'] = [];
      }

      // Nutritional info numbers
      final ni = (meal['nutritionalInfo'] is Map)
          ? Map<String, dynamic>.from(meal['nutritionalInfo'])
          : <String, dynamic>{};
      double _num(dynamic v) {
        if (v == null) return 0.0;
        if (v is num) return v.toDouble();
        final s = v.toString().replaceAll(RegExp(r'[^0-9.]+'), '');
        return double.tryParse(s) ?? 0.0;
      }

      meal['nutritionalInfo'] = {
        'calories': _num(ni['calories']).round(),
        'protein': _num(ni['protein']).round(),
        'carbs': _num(ni['carbs']).round(),
        'fat': _num(ni['fat']).round(),
      };

      // Categories normalization
      final cats = meal['categories'];
      if (cats is List) {
        meal['categories'] = cats.map((e) => e.toString()).toList();
      } else if (cats != null) {
        meal['categories'] = [cats.toString()];
      } else {
        meal['categories'] = <String>[];
      }
    }

    data['meals'] = meals;
    return data;
  }

  // Extract meal data from raw AI response by parsing sections
  Map<String, dynamic> _extractPartialJson(String text, String operation) {
    if (operation == 'meal_plan' || operation == 'meal_generation') {
      return _extractMealDataFromRawResponse(text);
    }

    // For other operations, try the old approach
    final jsonPattern =
        RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', multiLine: true);
    final matches = jsonPattern.allMatches(text);

    for (final match in matches) {
      try {
        final potentialJson = match.group(0) ?? '';
        final sanitized = _sanitizeJsonString(potentialJson);
        final parsed = jsonDecode(sanitized) as Map<String, dynamic>;

        if (_isValidPartialResponse(parsed, operation)) {
          return parsed;
        }
      } catch (e) {
        continue;
      }
    }

    return {};
  }

  // Extract meal data from raw AI response by parsing sections
  Map<String, dynamic> _extractMealDataFromRawResponse(String text) {
    final meals = <Map<String, dynamic>>[];

    // Find all meal objects in the response using a more specific pattern
    // This regex captures complete meal objects from opening { to closing }
    final mealMatches =
        RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', multiLine: true)
            .allMatches(text);

    for (final match in mealMatches) {
      final section = match.group(0) ?? '';
      if (section.trim().isEmpty) continue;

      try {
        // Only process sections that contain a title (actual meal objects)
        if (!section.contains('"title"')) {
          continue;
        }

        final meal = _extractSingleMeal(section);
        if (meal != null &&
            meal['title'] != null &&
            meal['title'] != 'Extracted Meal') {
          meals.add(meal);

          // Print nutritional info for debugging
          final nutrition = meal['nutritionalInfo'] as Map<String, dynamic>?;
          if (nutrition != null) {
          } else {}
        } else if (meal != null) {}
      } catch (e) {
        print('Failed to extract meal from section: $e');
        print(
            'Section: ${section.substring(0, section.length > 100 ? 100 : section.length)}...');
      }
    }

    if (meals.isEmpty) {
      return _createFallbackResponse(
          'meal_plan', 'No meals could be extracted from response');
    }

    // Calculate total nutrition from all meals
    final totalNutrition = <String, dynamic>{
      'totalCalories': 0,
      'totalProtein': 0,
      'totalCarbs': 0,
      'totalFat': 0,
    };

    for (final meal in meals) {
      final nutrition = meal['nutritionalInfo'] as Map<String, dynamic>?;
      if (nutrition != null) {
        totalNutrition['totalCalories'] += (nutrition['calories'] ?? 0);
        totalNutrition['totalProtein'] += (nutrition['protein'] ?? 0);
        totalNutrition['totalCarbs'] += (nutrition['carbs'] ?? 0);
        totalNutrition['totalFat'] += (nutrition['fat'] ?? 0);
      }
    }

    return {
      'meals': meals,
      'nutritionalSummary': totalNutrition,
      'extracted': true,
    };
  }

  // Extract a single meal from a text section
  Map<String, dynamic>? _extractSingleMeal(String section) {
    try {
      final meal = <String, dynamic>{};

      // Extract title
      final titleMatch =
          RegExp(r'"title":\s*"([^"]+)"', multiLine: true).firstMatch(section);
      if (titleMatch != null) {
        meal['title'] = titleMatch.group(1)?.trim();
      }

      // Extract type
      final typeMatch =
          RegExp(r'"type":\s*"([^"]+)"', multiLine: true).firstMatch(section);
      if (typeMatch != null) {
        meal['type'] = typeMatch.group(1)?.trim();
      }

      // Extract mealType
      final mealTypeMatch = RegExp(r'"mealType":\s*"([^"]+)"', multiLine: true)
          .firstMatch(section);
      if (mealTypeMatch != null) {
        meal['mealType'] = mealTypeMatch.group(1)?.trim();
      }

      // Extract serveQty
      final serveQtyMatch =
          RegExp(r'"serveQty":\s*(\d+)', multiLine: true).firstMatch(section);
      if (serveQtyMatch != null) {
        meal['serveQty'] = int.tryParse(serveQtyMatch.group(1) ?? '1') ?? 1;
      }

      // Extract diet
      final dietMatch =
          RegExp(r'"diet":\s*"([^"]+)"', multiLine: true).firstMatch(section);
      if (dietMatch != null) {
        meal['diet'] = dietMatch.group(1)?.trim();
      }

      // Extract ingredients
      final ingredients = _extractIngredients(section);
      if (ingredients.isNotEmpty) {
        meal['ingredients'] = ingredients;
      }

      // Extract instructions
      final instructions = _extractInstructions(section);
      if (instructions.isNotEmpty) {
        meal['instructions'] = instructions;
      }

      // Extract nutritional info
      final nutrition = _extractNutritionalInfo(section);
      if (nutrition.isNotEmpty) {
        meal['nutritionalInfo'] = nutrition;
      }

      // Extract categories
      final categories = _extractCategories(section);
      if (categories.isNotEmpty) {
        meal['categories'] = categories;
      }

      // Set defaults for missing fields
      meal['title'] = meal['title'] ?? 'Extracted Meal';
      meal['type'] = meal['type'] ?? 'protein';
      meal['mealType'] = meal['mealType'] ?? 'breakfast';
      meal['serveQty'] = meal['serveQty'] ?? 1;
      meal['ingredients'] = meal['ingredients'] ?? {'ingredient': '1 portion'};
      meal['instructions'] = meal['instructions'] ?? ['Prepare as directed'];

      // Only set nutritional defaults if no nutrition was extracted
      if (meal['nutritionalInfo'] == null ||
          (meal['nutritionalInfo'] as Map).isEmpty) {
        meal['nutritionalInfo'] = {
          'calories': 300,
          'protein': 20,
          'carbs': 15,
          'fat': 15
        };
      }

      meal['categories'] = meal['categories'] ?? ['extracted'];

      return meal;
    } catch (e) {
      print('Error extracting single meal: $e');
      return null;
    }
  }

  // Extract ingredients from a meal section
  Map<String, String> _extractIngredients(String section) {
    final ingredients = <String, String>{};

    // Look for ingredients section
    final ingredientsMatch =
        RegExp(r'"ingredients":\s*\{([^}]+)\}', multiLine: true)
            .firstMatch(section);
    if (ingredientsMatch != null) {
      final ingredientsText = ingredientsMatch.group(1) ?? '';

      // Extract individual ingredients
      final ingredientMatches =
          RegExp(r'"([^"]+)":\s*"([^"]+)"', multiLine: true)
              .allMatches(ingredientsText);
      for (final match in ingredientMatches) {
        final key = match.group(1)?.trim();
        final value = match.group(2)?.trim();
        if (key != null && value != null) {
          ingredients[key] = value;
        }
      }
    }

    return ingredients;
  }

  // Extract instructions from a meal section
  List<String> _extractInstructions(String section) {
    final instructions = <String>[];

    // Look for instructions array
    final instructionsMatch =
        RegExp(r'"instructions":\s*\[([^\]]+)\]', multiLine: true)
            .firstMatch(section);
    if (instructionsMatch != null) {
      final instructionsText = instructionsMatch.group(1) ?? '';

      // Extract individual instructions
      final instructionMatches =
          RegExp(r'"([^"]+)"', multiLine: true).allMatches(instructionsText);
      for (final match in instructionMatches) {
        final instruction = match.group(1)?.trim();
        if (instruction != null && instruction.isNotEmpty) {
          instructions.add(instruction);
        }
      }
    }

    return instructions;
  }

  // Extract nutritional info from a meal section
  Map<String, dynamic> _extractNutritionalInfo(String section) {
    final nutrition = <String, dynamic>{};

    // Look for nutritionalInfo section
    final nutritionMatch =
        RegExp(r'"nutritionalInfo":\s*\{([^}]+)\}', multiLine: true)
            .firstMatch(section);
    if (nutritionMatch != null) {
      final nutritionText = nutritionMatch.group(1) ?? '';

      // Extract individual nutrition values - handle both quoted and unquoted values with units
      final nutritionMatches =
          RegExp(r'"([^"]+)":\s*(\d+[a-zA-Z]*)', multiLine: true)
              .allMatches(nutritionText);
      for (final match in nutritionMatches) {
        final key = match.group(1)?.trim();
        final valueStr = match.group(2) ?? '0';
        // Extract just the number from values like "20g" -> 20
        final value =
            int.tryParse(valueStr.replaceAll(RegExp(r'[a-zA-Z]+'), '')) ?? 0;
        if (key != null) {
          nutrition[key] = value;
        }
      }
    }

    return nutrition;
  }

  // Extract categories from a meal section
  List<String> _extractCategories(String section) {
    final categories = <String>[];

    // Look for categories array
    final categoriesMatch =
        RegExp(r'"categories":\s*\[([^\]]+)\]', multiLine: true)
            .firstMatch(section);
    if (categoriesMatch != null) {
      final categoriesText = categoriesMatch.group(1) ?? '';

      // Extract individual categories
      final categoryMatches =
          RegExp(r'"([^"]+)"', multiLine: true).allMatches(categoriesText);
      for (final match in categoryMatches) {
        final category = match.group(1)?.trim();
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }
    }

    return categories;
  }

  // Check if a partial response is valid for the given operation
  bool _isValidPartialResponse(Map<String, dynamic> data, String operation) {
    switch (operation) {
      case 'meal_plan':
        return data.containsKey('meals') && data['meals'] is List;
      case 'meal_generation':
        return data.containsKey('meals') && data['meals'] is List;
      case 'tasty_analysis':
        return data.containsKey('foodItems') ||
            data.containsKey('totalNutrition');
      case 'program_generation':
        return data.containsKey('weeklyPlans');
      case 'food_comparison':
        return data.containsKey('image1Analysis') ||
            data.containsKey('image2Analysis');
      case '54321_shopping':
        return data.containsKey('shoppingList');
      default:
        return data.isNotEmpty;
    }
  }

  Future<Map<String, dynamic>> generateMealPlan(
      String prompt, String contextInformation) async {
    // Initialize model if not already done
    if (_activeModel == null) {
      final initialized = await initializeModel();
      if (!initialized) {
        // Try fallback if model initialization fails
        return await _getFallbackMeals(prompt);
      }
    }

    // Get comprehensive user context
    final aiContext = await _buildAIContext();

    try {
      final response = await _makeApiCallWithRetry(
        endpoint: '${_activeModel}:generateContent',
        body: {
          "contents": [
            {
              "parts": [
                {
                  "text": '''
You are a professional nutritionist and meal planner.

$aiContext

$prompt

$contextInformation

Return ONLY a raw JSON object (no markdown, no code blocks, no extra text, no trailing commas, no incomplete objects) with the following structure:
{
  "meals": [
    {
      "title": "Dish name",
      "type": "protein|grain|vegetable",
      "mealType": "breakfast | lunch | dinner | snack",
      "cookingTime": "time in minutes",
      "cookingMethod": "raw|grilled|fried|baked|boiled|steamed|other",
      "ingredients": {
        "ingredient1": "amount with unit (e.g., '1 cup', '200g')",
        "ingredient2": "amount with unit"
      },
      "instructions": ["step1", "step2", ...],
      "diet": "diet type",
      "nutritionalInfo": {
        "calories": number,
        "protein": number,
        "carbs": number,
        "fat": number
      },
      "categories": ["category1", "category2", ...],
      "serveQty": number
    }
  ],
  "nutritionalSummary": {
    "totalCalories": number,
    "totalProtein": number,
    "totalCarbs": number,
    "totalFat": number
  },
  "tips": ["tip1", "tip2", ...]
}

Important guidelines:
- Return valid, complete JSON only. Do not include markdown (e.g., ```json), code blocks, or any text outside the JSON object.
- Ensure no trailing commas, incomplete objects, or unexpected characters.
- Ensure all measurements are in metric units and nutritional values are per serving.
- Format ingredients as key-value pairs where the key is the ingredient name and the value is the amount with unit (e.g., "rice": "1 cup", "chicken breast": "200g")
- Diet type is the diet type of the meal plan (e.g., "keto", "vegan", "paleo", "gluten-free", "dairy-free" "quick prep",).
'''
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.3, // Lower temperature for consistent meal plans
            "topK": 20,
            "topP": 0.8,
            "maxOutputTokens": 4096, // Increased to prevent JSON truncation
          },
        },
        operation: 'generate meal plan',
      );

      final text = response['candidates'][0]['content']['parts'][0]['text'];
      try {
        final parsed = _processAIResponse(text, 'meal_plan');
        return _normalizeMealPlanData(parsed);
      } catch (e) {
        // Attempt sanitization + parse once more
        try {
          final sanitized = _sanitizeJsonString(text);
          final reparsed = jsonDecode(sanitized) as Map<String, dynamic>;
          return _normalizeMealPlanData(reparsed);
        } catch (_) {
          throw Exception('Failed to parse meal plan JSON: $e');
        }
      }
    } catch (e) {
      print('AI API Exception: $e');
      _activeModel = null;

      // Return fallback meals if AI fails
      return await _getFallbackMeals(prompt);
    }
  }

  Future<Map<String, dynamic>> analyzeFoodImageWithContext({
    required File imageFile,
    String? mealType,
    String? dietaryRestrictions,
    String? additionalContext,
  }) async {
    // Initialize model if not already done
    if (_activeModel == null) {
      final initialized = await initializeModel();
      if (!initialized) {
        throw Exception('No suitable AI model available');
      }
    }

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    try {
      // Read and encode the image
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Get comprehensive user context
      final aiContext = await _buildAIContext();

      String contextualPrompt =
          'Analyze this food image and provide detailed nutritional information.';

      if (mealType != null) {
        contextualPrompt += ' This is a $mealType meal.';
      }

      if (dietaryRestrictions != null && dietaryRestrictions.isNotEmpty) {
        contextualPrompt +=
            ' Consider dietary restrictions: $dietaryRestrictions.';
      }

      if (additionalContext != null && additionalContext.isNotEmpty) {
        contextualPrompt += ' Additional context: $additionalContext.';
      }

      final prompt = '''
$aiContext

$contextualPrompt

Identify all visible food items, estimate portion sizes, and calculate nutritional values. Also provide suggestions for meal improvement if applicable.

Return ONLY a raw JSON object (no markdown, no code blocks, no extra text, no trailing commas, no incomplete objects) with the following structure:

IMPORTANT: You have 4096 tokens available. Prioritize completing the JSON structure over detailed descriptions. If you need to truncate, ensure the JSON is complete and valid.

{
  "foodItems": [
    {
      "name": "food item name",
      "estimatedWeight": "weight in grams",
      "confidence": "high|medium|low",
      "nutritionalInfo": {
        "calories": 0,
        "protein": 0,
        "carbs": 0,
        "fat": 0,
        "fiber": 0,
        "sugar": 0,
        "sodium": 0
      }
    }
  ],
  "totalNutrition": {
    "calories": 0,
    "protein": 0,
    "carbs": 0,
    "fat": 0,
    "fiber": 0,
    "sugar": 0,
    "sodium": 0
  },
  "mealType": "breakfast|lunch|dinner|snack",
  "estimatedPortionSize": "small|medium|large",
  "ingredients": {
        "ingredient1": "amount with unit (e.g., '1 cup', '200g')",
        "ingredient2": "amount with unit"
    },
  "cookingMethod": "raw|grilled|fried|baked|boiled|steamed|other",
  "confidence": "high|medium|low",
  "suggestions": {
    "improvements": ["suggestion1", "suggestion2", ...],
    "alternatives": ["alternative1", "alternative2", ...],
    "additions": ["addition1", "addition2", ...]
  },
  "instructions": ["instruction1", "instruction2", ...],
  "dietaryFlags": {
    "vegetarian": boolean,
    "vegan": boolean,
    "glutenFree": boolean,
    "dairyFree": boolean,
    "keto": boolean,
    "lowCarb": boolean
  },
  "notes": "any additional observations about the food",
  "healthScore": 5
}

Important guidelines:
- Return valid, complete JSON only. Do not include markdown (e.g., ```json), code blocks, or any text outside the JSON object.
- Ensure no trailing commas, incomplete objects, or unexpected characters.
- Be as accurate as possible with portion size estimation.
- Include confidence levels for your analysis.
- Provide realistic nutritional values based on standard food databases.
- All nutritional values must be numbers (not strings).
- Health score must be a number between 1 and 10 reflecting overall nutritional quality (1=poor, 10=excellent).
- PRIORITY: Complete the JSON structure even if you need to use shorter descriptions.
- If approaching token limit, complete the JSON structure first, then add details.
''';

      final response = await http.post(
        Uri.parse('$_baseUrl/${_activeModel}:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
                {
                  "inline_data": {
                    "mime_type": "image/jpeg",
                    "data": base64Image
                  }
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.1, // Very low temperature for consistent JSON
            "topK": 20,
            "topP": 0.8,
            "maxOutputTokens": 4096, // Increased to prevent JSON truncation
            // Removed stopSequences as they might be causing empty responses
          },
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded.containsKey('candidates') &&
            decoded['candidates'] is List &&
            decoded['candidates'].isNotEmpty) {
          final candidate = decoded['candidates'][0];

          if (candidate.containsKey('content') && candidate['content'] is Map) {
            final content = candidate['content'];

            if (content.containsKey('parts') &&
                content['parts'] is List &&
                content['parts'].isNotEmpty) {
              final part = content['parts'][0];

              if (part.containsKey('text')) {
                final text = part['text'];

                try {
                  final result = _processAIResponse(text, 'tasty_analysis');
                  return result;
                } catch (e) {
                  throw Exception('Failed to parse food analysis JSON: $e');
                }
              } else {
                throw Exception('No text content in API response');
              }
            } else {
              throw Exception('No content parts in API response');
            }
          } else {
            throw Exception('No content in API response');
          }
        } else {
          throw Exception('No candidates in API response');
        }
      } else {
        _activeModel = null;
        throw Exception('Failed to analyze food image: ${response.statusCode}');
      }
    } catch (e) {
      print('AI API Exception: $e');
      _activeModel = null;
      throw Exception('Failed to analyze food image: $e');
    }
  }

  Future<Map<String, dynamic>> generateMealsFromIngredients(
      List<dynamic> displayedItems, BuildContext context, bool isDineIn) async {
    try {
      showDialog(
        context: context,
        builder: (context) => const LoadingScreen(
          loadingText: 'Generating Meals, Please Wait...',
        ),
      );

      // Prepare prompt and generate meal plan
      final mealPlan = await generateMealPlan(
        'Generate 2 meals using these ingredients: ${displayedItems.map((item) => item.title).join(', ')}',
        'Stay within the ingredients provided',
      );

      // Hide loading dialog before showing selection
      Navigator.of(context).pop();

      final meals = mealPlan['meals'] as List<dynamic>? ?? [];
      if (meals.isEmpty) throw Exception('No meals generated');

      // Show dialog to let user pick one meal
      final selectedMeal = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false, // Prevent dismissing during loading
        builder: (context) {
          final isDarkMode = getThemeProvider(context).isDarkMode;
          final textTheme = Theme.of(context).textTheme;
          return StatefulBuilder(
            builder: (context, setState) {
              bool isProcessing = false; // Global processing state

              return AlertDialog(
                backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                title: Text(
                  'Select a Meal',
                  style: textTheme.displaySmall?.copyWith(
                      fontSize: getPercentageWidth(7, context),
                      color: kAccent,
                      fontWeight: FontWeight.w500),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: meals.length,
                    itemBuilder: (context, index) {
                      final meal = meals[index];
                      final title = meal['title'] ?? 'Untitled';

                      final categories =
                          (meal['categories'] as List<dynamic>?) ?? [];

                      return Card(
                        color: colors[index % colors.length],
                        child: ListTile(
                          enabled: !isProcessing,
                          title: Text(
                            title,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? kWhite : kDarkGrey,
                            ),
                          ),
                          subtitle: categories.isNotEmpty
                              ? Text(
                                  'Categories: ${categories.join(', ')}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey,
                                  ),
                                )
                              : null,
                          onTap: isProcessing
                              ? null
                              : () async {
                                  // Set loading state and show SnackBar
                                  setState(() {
                                    isProcessing = true;
                                  });

                                  // Show SnackBar with loading message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: kWhite,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              'Saving "$title" to your calendar...',
                                              style: const TextStyle(
                                                color: kWhite,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: kAccent,
                                      duration: const Duration(seconds: 10),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );

                                  try {
                                    final userId = userService.userId;
                                    if (userId == null)
                                      throw Exception('User ID not found');
                                    final date = DateFormat('yyyy-MM-dd')
                                        .format(DateTime.now());
                                    // Save all meals first
                                    final List<String> allMealIds =
                                        await saveMealsToFirestore(
                                            userId, mealPlan, '');
                                    final int selectedIndex = meals.indexWhere(
                                        (m) => m['title'] == meal['title']);
                                    final String? selectedMealId =
                                        (selectedIndex != -1 &&
                                                selectedIndex <
                                                    allMealIds.length)
                                            ? allMealIds[selectedIndex]
                                            : null;
                                    // Get existing meals first
                                    final docRef = firestore
                                        .collection('mealPlans')
                                        .doc(userId)
                                        .collection('date')
                                        .doc(date);
                                    // Add new meal ID if not null
                                    if (selectedMealId != null) {
                                      await docRef.set({
                                        'userId': userId,
                                        'dayType': 'chef_tasty',
                                        'isSpecial': true,
                                        'date': date,
                                        'meals': FieldValue.arrayUnion(
                                            [selectedMealId]),
                                      }, SetOptions(merge: true));
                                    }

                                    if (context.mounted) {
                                      // Hide the SnackBar
                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();

                                      // Show success SnackBar
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Successfully saved "$title" to your calendar!',
                                            style: const TextStyle(
                                              color: kWhite,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          backgroundColor: kAccent,
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      );

                                      Navigator.of(context)
                                          .pop(meal); // Close selection dialog
                                    }
                                  } catch (e) {
                                    // Reset loading state on error
                                    if (context.mounted) {
                                      // Hide the loading SnackBar
                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();

                                      setState(() {
                                        isProcessing = false;
                                      });

                                      // Show error SnackBar
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to save meal. Please try again.',
                                            style: const TextStyle(
                                              color: kWhite,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          backgroundColor: kRed,
                                          duration: const Duration(seconds: 3),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      );

                                      handleError(e, context);
                                    }
                                  }
                                },
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isProcessing ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: textTheme.bodyLarge?.copyWith(
                        color: isProcessing
                            ? kLightGrey
                            : (isDarkMode ? kWhite : kBlack),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      return selectedMeal ?? {}; // Return empty map if user cancelled
    } catch (e) {
      if (context.mounted) {
        handleError(e, context);
      }
      return {};
    }
  }

  /// Save food analysis to tastyanalysis collection
  Future<void> saveAnalysisToFirestore({
    required Map<String, dynamic> analysisResult,
    required String userId,
    required String imagePath,
  }) async {
    try {
      final docId = firestore.collection('tastyanalysis').doc().id;

      final analysisData = {
        'analysis': analysisResult,
        'imagePath': imagePath,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
      };

      await firestore
          .collection('tastyanalysis')
          .doc(docId)
          .set(analysisData, SetOptions(merge: true));
    } catch (e) {
      print('Error saving analysis to Firestore: $e');
      throw Exception('Failed to save analysis: $e');
    }
  }

  /// Create and save a meal from analysis results
  Future<String> createMealFromAnalysis({
    required Map<String, dynamic> analysisResult,
    required String userId,
    required String mealType,
    required String imagePath,
    String? mealId,
  }) async {
    try {
      final docRef = mealId != null && mealId.isNotEmpty
          ? firestore.collection('meals').doc(mealId)
          : firestore.collection('meals').doc();
      final finalMealId = docRef.id;

      final totalNutrition =
          analysisResult['totalNutrition'] as Map<String, dynamic>;
      final foodItems = analysisResult['foodItems'] as List<dynamic>;

      // Handle ingredients - can be either Map or List from AI response
      Map<String, String> ingredientsMap = <String, String>{};
      final ingredientsFromAnalysis = analysisResult['ingredients'];

      if (ingredientsFromAnalysis is Map<String, dynamic>) {
        // If ingredients is a Map (expected format), use it directly
        ingredientsMap.addAll(ingredientsFromAnalysis.cast<String, String>());
      } else if (ingredientsFromAnalysis is List) {
        // If ingredients is a List (fallback), convert to Map
        final ingredientsList = List<String>.from(ingredientsFromAnalysis);
        for (int i = 0; i < ingredientsList.length; i++) {
          ingredientsMap['ingredient${i + 1}'] = ingredientsList[i];
        }
      }

      // Apply ingredient deduplication to prevent duplicates like "sesameseed" vs "sesame seed"
      ingredientsMap = _normalizeAndDeduplicateIngredients(
          ingredientsMap.cast<String, dynamic>());

      // Create meal title from primary food item
      String title = 'AI Analyzed Food';
      if (foodItems.isNotEmpty) {
        title = foodItems.first['name'] ?? 'AI Analyzed Food';
      }

      // Handle instructions properly - ensure it's a List<String>
      List<String> instructions = [
        'Food analyzed by AI \nNutrition and ingredients estimated from image analysis'
      ];

      final existingInstructions = analysisResult['instructions'];
      if (existingInstructions != null) {
        if (existingInstructions is List) {
          // Convert each item to string
          instructions
              .addAll(existingInstructions.map((item) => item.toString()));
        } else if (existingInstructions is String) {
          instructions.add(existingInstructions);
        }
      }

      analysisResult['instructions'] = instructions;

      final meal = Meal(
        mealId: finalMealId,
        userId: userId,
        title: title,
        createdAt: DateTime.now(),
        mediaPaths: [imagePath],
        serveQty: 1,
        calories: (totalNutrition['calories'] as num?)?.toInt() ?? 0,
        ingredients: ingredientsMap,
        nutritionalInfo: {
          'protein': (totalNutrition['protein'] as num?)?.toString() ?? '0',
          'carbs': (totalNutrition['carbs'] as num?)?.toString() ?? '0',
          'fat': (totalNutrition['fat'] as num?)?.toString() ?? '0',
        },
        instructions: analysisResult['instructions'],
        categories: ['ai-analyzed', mealType.toLowerCase()],
        category: 'ai-analyzed',
        suggestions: analysisResult['suggestions'],
      );

      await docRef.set(meal.toJson());
      return finalMealId;
    } catch (e) {
      print('Error creating meal from analysis: $e');
      throw Exception('Failed to create meal: $e');
    }
  }

  /// Add analyzed meal to user's daily meals
  Future<void> addAnalyzedMealToDaily({
    required String mealId,
    required String userId,
    required String mealType,
    required Map<String, dynamic> analysisResult,
    required DateTime date,
  }) async {
    try {
      final totalNutrition =
          analysisResult['totalNutrition'] as Map<String, dynamic>;
      final foodItems = analysisResult['foodItems'] as List<dynamic>;

      String mealName = 'AI Analyzed Food';
      if (foodItems.isNotEmpty) {
        mealName = foodItems.first['name'] ?? 'AI Analyzed Food';
      }

      final userMeal = UserMeal(
        name: mealName,
        quantity: analysisResult['estimatedPortionSize'] ?? 'medium',
        calories: (totalNutrition['calories'] as num?)?.toInt() ?? 0,
        mealId: mealId,
        servings: '1',
      );

      final dateId = DateFormat('yyyy-MM-dd').format(date);

      final mealRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateId);

      final docSnapshot = await mealRef.get();

      if (docSnapshot.exists) {
        await mealRef.update({
          'meals.$mealType': FieldValue.arrayUnion([userMeal.toFirestore()])
        });
      } else {
        await mealRef.set({
          'date': dateId,
          'meals': {
            mealType: [userMeal.toFirestore()],
          },
        });
      }
    } catch (e) {
      print('Error adding analyzed meal to daily: $e');
      throw Exception('Failed to add meal to daily: $e');
    }
  }

  Future<Map<String, dynamic>> generate54321ShoppingList({
    String? dietaryRestrictions,
    String? additionalContext,
  }) async {
    // Initialize model if not already done
    if (_activeModel == null) {
      final initialized = await initializeModel();
      if (!initialized) {
        throw Exception('No suitable AI model available');
      }
    }

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    // Get comprehensive user context
    final aiContext = await _buildAIContext();

    String contextualPrompt = 'Generate a 54321 shopping list with:';

    if (dietaryRestrictions != null && dietaryRestrictions.isNotEmpty) {
      contextualPrompt +=
          ' Consider dietary restrictions: $dietaryRestrictions.';
    }

    if (additionalContext != null && additionalContext.isNotEmpty) {
      contextualPrompt += ' Additional context: $additionalContext.';
    }

    final prompt = '''
$aiContext

$contextualPrompt

Generate a balanced 54321 shopping list:
- 5 vegetables (fresh, seasonal, diverse)
- 4 fruits (fresh, seasonal, variety)
- 3 protein sources (meat, fish, eggs, legumes, etc.)
- 2 sauces/spreads (condiments, dressings, spreads)
- 1 grain (rice, pasta, bread, etc.)
- 1 fun/special treat (dessert, snack, indulgence)

Return ONLY a raw JSON object (no markdown, no code blocks, no extra text, no trailing commas, no incomplete objects) with the following structure:
{
  "shoppingList": {
    "vegetables": [
      {
        "name": "vegetable name",
        "amount": "quantity with unit (e.g., '1 bunch', '500g')",
        "category": "vegetable",
        "notes": "optional preparation or selection tips"
      }
    ],
    "fruits": [
      {
        "name": "fruit name",
        "amount": "quantity with unit",
        "category": "fruit",
        "notes": "optional notes"
      }
    ],
    "proteins": [
      {
        "name": "protein name",
        "amount": "quantity with unit",
        "category": "protein",
        "notes": "optional notes"
      }
    ],
    "sauces": [
      {
        "name": "sauce/spread name",
        "amount": "quantity with unit",
        "category": "sauce",
        "notes": "optional notes"
      }
    ],
    "grains": [
      {
        "name": "grain name",
        "amount": "quantity with unit",
        "category": "grain",
        "notes": "optional notes"
      }
    ],
    "treats": [
      {
        "name": "treat name",
        "amount": "quantity with unit",
        "category": "treat",
        "notes": "optional notes"
      }
    ]
  },
  "totalItems": 16,
  "estimatedCost": "estimated cost range",
  "tips": ["tip1", "tip2", "tip3"],
  "mealIdeas": ["meal idea 1", "meal idea 2", "meal idea 3"]
}

Important guidelines:
- Return valid, complete JSON only. Do not include markdown (e.g., ```json), code blocks, or any text outside the JSON object.
- Ensure no trailing commas, incomplete objects, or unexpected characters.
- Choose seasonal and fresh ingredients when possible
- Consider the user's dietary preferences and restrictions
- Provide realistic quantities for family/individual portions
- Include variety and balance in each category
- Make the treat reasonable but enjoyable
- All items should be commonly available in grocery stores
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/${_activeModel}:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature":
                0.3, // Lower temperature for consistent shopping lists
            "topK": 20,
            "topP": 0.8,
            "maxOutputTokens": 4096, // Increased to prevent JSON truncation
            "stopSequences": [
              "```",
              "```json",
              "```\n",
              "\n\n\n"
            ], // Stop at markdown
          },
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['candidates'][0]['content']['parts'][0]['text'];
        try {
          return _processAIResponse(text, '54321_shopping');
        } catch (e) {
          print('Raw response text: $text');
          throw Exception('Failed to parse 54321 shopping list JSON: $e');
        }
      } else {
        print('AI API Error: ${response.body}');
        _activeModel = null;
        throw Exception(
            'Failed to generate 54321 shopping list: ${response.statusCode}');
      }
    } catch (e) {
      print('AI API Exception: $e');
      _activeModel = null;
      throw Exception('Failed to generate 54321 shopping list: $e');
    }
  }

  /// Get the latest 54321 shopping list from Firestore
  Future<Map<String, dynamic>?> get54321ShoppingList(String userId) async {
    try {
      final docRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList54321')
          .doc('current');

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        return data['shoppingList'] as Map<String, dynamic>?;
      }

      return null;
    } catch (e) {
      print('Error getting 54321 shopping list from Firestore: $e');
      return null;
    }
  }

  /// Generate and save 54321 shopping list
  Future<Map<String, dynamic>> generateAndSave54321ShoppingList({
    String? dietaryRestrictions,
    String? additionalContext,
  }) async {
    final userId = userService.userId;
    if (userId == null) {
      throw Exception('User ID not found');
    }

    // Generate the shopping list
    final shoppingList = await generate54321ShoppingList(
      dietaryRestrictions: dietaryRestrictions,
      additionalContext: additionalContext,
    );

    // Save to Firestore
    try {
      final docRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList54321')
          .doc('current');

      await docRef.set({
        'shoppingList': shoppingList,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving 54321 shopping list to Firestore: $e');
      throw Exception('Failed to save 54321 shopping list: $e');
    }

    return shoppingList;
  }
}

// Global instance for easy access throughout the app
final geminiService = GeminiService.instance;
