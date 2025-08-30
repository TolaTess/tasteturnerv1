import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../data_models/ingredient_data.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../widgets/loading_screen.dart';

/// Enum to track which AI provider is being used
enum AIProvider { gemini, openrouter }

/// Class to hold meal similarity scoring results
class MealSimilarityScore {
  final Meal meal;
  final double similarityScore;
  final Map<String, double> componentScores;

  MealSimilarityScore({
    required this.meal,
    required this.similarityScore,
    required this.componentScores,
  });
}

/// Enhanced GeminiService with comprehensive user context integration and OpenRouter fallback
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
/// **Fallback Features:**
/// - OpenRouter API as backup when Gemini fails
/// - Automatic provider switching on errors
/// - Seamless fallback to OpenRouter models
/// - Retry logic with multiple providers
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

  // API Configuration
  final String _geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1';
  final String _openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  String? _activeModel; // Cache the working model name and full path

  // Provider tracking
  AIProvider _currentProvider = AIProvider.gemini;
  bool _useOpenRouterFallback = true; // Enable/disable OpenRouter fallback

  // OpenRouter configuration
  static const Map<String, String> _openRouterModels = {
    'gpt-4o': 'openai/gpt-4o',
    'gpt-4o-mini': 'openai/gpt-4o-mini',
    'claude-3-5-sonnet': 'anthropic/claude-3-5-sonnet',
    'claude-3-haiku': 'anthropic/claude-3-haiku',
    'gemini-1.5-flash': 'google/gemini-1-5-flash',
    'gemini-1.5-pro': 'google/gemini-1-5-pro',
  };

  String _preferredOpenRouterModel = 'gpt-4o-mini'; // Default fallback model

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

  // Track API health for both providers
  static bool _isGeminiHealthy = true;
  static bool _isOpenRouterHealthy = true;
  static DateTime? _lastGeminiError;
  static DateTime? _lastOpenRouterError;
  static int _consecutiveGeminiErrors = 0;
  static int _consecutiveOpenRouterErrors = 0;
  static const int _maxConsecutiveErrors = 5;
  static const Duration _apiRecoveryTime = Duration(minutes: 10);

  /// Check if current provider is healthy
  bool get isCurrentProviderHealthy {
    if (_currentProvider == AIProvider.gemini) {
      return _isGeminiHealthy;
    } else {
      return _isOpenRouterHealthy;
    }
  }

  /// Check if any provider is available
  bool get isAnyProviderHealthy {
    return _isGeminiHealthy || _isOpenRouterHealthy;
  }

  /// Get current provider name
  String get currentProviderName {
    return _currentProvider == AIProvider.gemini ? 'Gemini' : 'OpenRouter';
  }

  /// Set preferred OpenRouter model
  void setPreferredOpenRouterModel(String modelName) {
    if (_openRouterModels.containsKey(modelName)) {
      _preferredOpenRouterModel = modelName;
    }
  }

  /// Enable/disable OpenRouter fallback
  void setOpenRouterFallback(bool enabled) {
    _useOpenRouterFallback = enabled;
  }

  /// Enhanced API call with retry logic and provider fallback
  Future<Map<String, dynamic>> _makeApiCallWithRetry({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
    bool useFallback = true,
  }) async {
    // Always start with Gemini for new requests
    if (_currentProvider == AIProvider.openrouter && retryCount == 0) {
      debugPrint('Resetting to Gemini provider for new request');
      _currentProvider = AIProvider.gemini;
    }

    // Try current provider first
    try {
      return await _makeApiCallToCurrentProvider(
        endpoint: endpoint,
        body: body,
        operation: operation,
        retryCount: retryCount,
      );
    } catch (e) {
      // If we're using Gemini and it fails, retry with Gemini first
      if (_currentProvider == AIProvider.gemini && retryCount < _maxRetries) {
        debugPrint(
            'Gemini failed, retrying with Gemini (attempt ${retryCount + 1}): $e');
        return await _makeApiCallWithRetry(
          endpoint: endpoint,
          body: body,
          operation: operation,
          retryCount: retryCount + 1,
          useFallback: useFallback,
        );
      }

      // If Gemini has been retried and still fails, then try OpenRouter fallback
      if (useFallback &&
          _useOpenRouterFallback &&
          _currentProvider == AIProvider.gemini &&
          retryCount >= _maxRetries) {
        debugPrint(
            'Gemini failed after ${_maxRetries} retries, switching to OpenRouter: $e');
        _currentProvider = AIProvider.openrouter;
        final result = await _makeApiCallToCurrentProvider(
          endpoint: endpoint,
          body: body,
          operation: operation,
          retryCount: 0, // Reset retry count for new provider
        );

        // Reset back to Gemini for next request after successful OpenRouter fallback
        _currentProvider = AIProvider.gemini;
        debugPrint('Reset back to Gemini provider for next request');

        return result;
      }

      // If we're already using OpenRouter or fallback is disabled, throw the error
      throw e;
    }
  }

  /// Make API call to the current provider
  Future<Map<String, dynamic>> _makeApiCallToCurrentProvider({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
  }) async {
    if (_currentProvider == AIProvider.gemini) {
      return await _makeGeminiApiCall(
        endpoint: endpoint,
        body: body,
        operation: operation,
        retryCount: retryCount,
      );
    } else {
      return await _makeOpenRouterApiCall(
        endpoint: endpoint,
        body: body,
        operation: operation,
        retryCount: retryCount,
      );
    }
  }

  /// Make API call to Gemini
  Future<Map<String, dynamic>> _makeGeminiApiCall({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key not configured');
    }

    // Check if Gemini is healthy
    if (!_isGeminiHealthy) {
      throw Exception(
          'Gemini API temporarily unavailable. Please try again later.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_geminiBaseUrl/$endpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Reset error tracking on success
        _consecutiveGeminiErrors = 0;
        _isGeminiHealthy = true;

        final decoded = jsonDecode(response.body);
        return decoded;
      } else {
        // Handle specific error codes
        final errorResponse = jsonDecode(response.body);
        final errorCode = response.statusCode;
        final errorMessage =
            errorResponse['error']?['message'] ?? 'Unknown error';

        // Handle specific error types
        switch (errorCode) {
          case 503:
            // Service overloaded - retry with exponential backoff
            if (retryCount < _maxRetries) {
              final delay = _retryDelay + (_backoffMultiplier * retryCount);
              await Future.delayed(delay);
              return _makeGeminiApiCall(
                endpoint: endpoint,
                body: body,
                operation: operation,
                retryCount: retryCount + 1,
              );
            }
            _handleGeminiError(
                'Service temporarily overloaded. Please try again in a few minutes.');
            break;

          case 429:
            // Rate limited - retry with longer delay
            if (retryCount < _maxRetries) {
              await Future.delayed(Duration(seconds: 5 * (retryCount + 1)));
              return _makeGeminiApiCall(
                endpoint: endpoint,
                body: body,
                operation: operation,
                retryCount: retryCount + 1,
              );
            }
            _handleGeminiError('Rate limit exceeded. Please try again later.');
            break;

          case 401:
            // Authentication error
            _handleGeminiError(
                'Authentication failed. Please check your API configuration.');
            break;

          case 400:
            // Bad request - don't retry
            throw Exception('Invalid request: $errorMessage');

          default:
            // Other errors - retry if appropriate
            if (retryCount < _maxRetries && errorCode >= 500) {
              await Future.delayed(_retryDelay);
              return _makeGeminiApiCall(
                endpoint: endpoint,
                body: body,
                operation: operation,
                retryCount: retryCount + 1,
              );
            }
            _handleGeminiError('Service error: $errorMessage');
        }

        throw Exception('Failed to $operation: $errorCode - $errorMessage');
      }
    } catch (e) {
      _handleGeminiError('Connection error: ${e.toString()}');
      throw Exception('Failed to $operation: ${e.toString()}');
    }
  }

  /// Make API call to OpenRouter
  Future<Map<String, dynamic>> _makeOpenRouterApiCall({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
  }) async {
    debugPrint('Making OpenRouter API call to $endpoint');

    // Smart body logging - show structure but not image data
    if (body.containsKey('contents') && body['contents'] is List) {
      final contents = body['contents'] as List;
      if (contents.isNotEmpty && contents.first is Map) {
        final firstContent = contents.first as Map;
        if (firstContent.containsKey('parts') &&
            firstContent['parts'] is List) {
          final parts = firstContent['parts'] as List;
          final hasImage = parts.any((part) =>
              part is Map &&
              (part['inline_data'] != null || part['image_url'] != null));

          if (hasImage) {
            debugPrint(
                'Body: [Image analysis request with ${parts.length} parts]');
          } else {
            debugPrint('Body: $body');
          }
        } else {
          debugPrint('Body: $body');
        }
      } else {
        debugPrint('Body: $body');
      }
    } else {
      debugPrint('Body: $body');
    }

    debugPrint('Operation: $operation');
    debugPrint('Retry count: $retryCount');
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenRouter API key not configured');
    }

    // Check if OpenRouter is healthy
    if (!_isOpenRouterHealthy) {
      throw Exception(
          'OpenRouter API temporarily unavailable. Please try again later.');
    }

    try {
      // Convert Gemini format to OpenRouter format
      final openRouterBody = _convertToOpenRouterFormat(body);

      // OpenRouter always uses chat/completions endpoint
      final url = '$_openRouterBaseUrl/chat/completions';
      debugPrint('Making OpenRouter API call to: $url');
      debugPrint('Using model: ${openRouterBody['model']}');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer':
                  'https://tasteturner.app', // Required by OpenRouter
              'X-Title': 'TasteTurner', // Optional but recommended
            },
            body: jsonEncode(openRouterBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Reset error tracking on success
        _consecutiveOpenRouterErrors = 0;
        _isOpenRouterHealthy = true;

        final decoded = jsonDecode(response.body);
        return _convertFromOpenRouterFormat(decoded);
      } else {
        // Handle specific error codes
        final errorResponse = jsonDecode(response.body);
        final errorCode = response.statusCode;
        final errorMessage =
            errorResponse['error']?['message'] ?? 'Unknown error';

        // Handle specific error types
        switch (errorCode) {
          case 503:
            // Service overloaded - retry with exponential backoff
            if (retryCount < _maxRetries) {
              final delay = _retryDelay + (_backoffMultiplier * retryCount);
              await Future.delayed(delay);
              return _makeOpenRouterApiCall(
                endpoint: endpoint,
                body: body,
                operation: operation,
                retryCount: retryCount + 1,
              );
            }
            _handleOpenRouterError(
                'Service temporarily overloaded. Please try again in a few minutes.');
            break;

          case 429:
            // Rate limited - retry with longer delay
            if (retryCount < _maxRetries) {
              await Future.delayed(Duration(seconds: 5 * (retryCount + 1)));
              return _makeOpenRouterApiCall(
                endpoint: endpoint,
                body: body,
                operation: operation,
                retryCount: retryCount + 1,
              );
            }
            _handleOpenRouterError(
                'Rate limit exceeded. Please try again later.');
            break;

          case 401:
            // Authentication error
            _handleOpenRouterError(
                'Authentication failed. Please check your API configuration.');
            break;

          case 400:
            // Bad request - don't retry
            throw Exception('Invalid request: $errorMessage');

          default:
            // Other errors - retry if appropriate
            if (retryCount < _maxRetries && errorCode >= 500) {
              await Future.delayed(_retryDelay);
              return _makeOpenRouterApiCall(
                endpoint: endpoint,
                body: body,
                operation: operation,
                retryCount: retryCount + 1,
              );
            }
            _handleOpenRouterError('Service error: $errorMessage');
        }

        throw Exception('Failed to $operation: $errorCode - $errorMessage');
      }
    } catch (e) {
      _handleOpenRouterError('Connection error: ${e.toString()}');
      throw Exception('Failed to $operation: ${e.toString()}');
    }
  }

  /// Convert Gemini request format to OpenRouter format
  Map<String, dynamic> _convertToOpenRouterFormat(
      Map<String, dynamic> geminiBody) {
    final contents = geminiBody['contents'] as List<dynamic>;
    final generationConfig =
        geminiBody['generationConfig'] as Map<String, dynamic>? ?? {};

    // Extract messages from Gemini format
    final messages = <Map<String, dynamic>>[];
    for (final content in contents) {
      final parts = content['parts'] as List<dynamic>;
      for (final part in parts) {
        if (part['text'] != null) {
          messages.add({
            'role': 'user',
            'content': part['text'],
          });
        }
      }
    }

    // Get the model name
    final modelName = _getOpenRouterModelName();

    return {
      'model': modelName,
      'messages': messages,
      'max_tokens': generationConfig['maxOutputTokens'] ?? 1024,
      'temperature': generationConfig['temperature'] ?? 0.7,
      'top_p': generationConfig['topP'] ?? 0.95,
      'stream': false,
    };
  }

  /// Convert OpenRouter response format to Gemini format
  Map<String, dynamic> _convertFromOpenRouterFormat(
      Map<String, dynamic> openRouterResponse) {
    final choices = openRouterResponse['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) {
      throw Exception('No response from OpenRouter');
    }

    final choice = choices.first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>? ?? {};
    final content = message['content'] as String? ?? '';

    // Convert to Gemini format
    return {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': content}
            ]
          }
        }
      ]
    };
  }

  /// Get the OpenRouter model name
  String _getOpenRouterModelName() {
    return _openRouterModels[_preferredOpenRouterModel] ??
        _openRouterModels['gpt-4o-mini']!;
  }

  /// Handle Gemini API errors and update health status
  void _handleGeminiError(String message) {
    _consecutiveGeminiErrors++;
    _lastGeminiError = DateTime.now();

    if (_consecutiveGeminiErrors >= _maxConsecutiveErrors) {
      _isGeminiHealthy = false;
    }
  }

  /// Handle OpenRouter API errors and update health status
  void _handleOpenRouterError(String message) {
    _consecutiveOpenRouterErrors++;
    _lastOpenRouterError = DateTime.now();

    if (_consecutiveOpenRouterErrors >= _maxConsecutiveErrors) {
      _isOpenRouterHealthy = false;
    }
  }

  /// Reset provider health status
  void _resetProviderHealth() {
    if (_lastGeminiError != null) {
      final timeSinceLastError = DateTime.now().difference(_lastGeminiError!);
      if (timeSinceLastError > _apiRecoveryTime) {
        _isGeminiHealthy = true;
        _consecutiveGeminiErrors = 0;
      }
    }

    if (_lastOpenRouterError != null) {
      final timeSinceLastError =
          DateTime.now().difference(_lastOpenRouterError!);
      if (timeSinceLastError > _apiRecoveryTime) {
        _isOpenRouterHealthy = true;
        _consecutiveOpenRouterErrors = 0;
      }
    }
  }

  /// Get provider status information
  Map<String, dynamic> getProviderStatus() {
    return {
      'currentProvider': _currentProvider.name,
      'currentProviderName': currentProviderName,
      'geminiHealthy': _isGeminiHealthy,
      'openRouterHealthy': _isOpenRouterHealthy,
      'anyProviderHealthy': isAnyProviderHealthy,
      'openRouterFallbackEnabled': _useOpenRouterFallback,
      'preferredOpenRouterModel': _preferredOpenRouterModel,
      'consecutiveGeminiErrors': _consecutiveGeminiErrors,
      'consecutiveOpenRouterErrors': _consecutiveOpenRouterErrors,
      'lastGeminiError': _lastGeminiError?.toIso8601String(),
      'lastOpenRouterError': _lastOpenRouterError?.toIso8601String(),
    };
  }

  /// Force switch to a specific provider
  void switchToProvider(AIProvider provider) {
    if (provider == AIProvider.gemini) {
      _currentProvider = AIProvider.gemini;
      debugPrint('Switched to Gemini provider');
    } else if (provider == AIProvider.openrouter) {
      _currentProvider = AIProvider.openrouter;
      debugPrint('Switched to OpenRouter provider');
    }
  }

  /// Reset provider back to Gemini (useful after testing or manual switching)
  void resetToGemini() {
    _currentProvider = AIProvider.gemini;
    debugPrint('Reset to Gemini provider');
  }

  /// Get available OpenRouter models
  List<String> getAvailableOpenRouterModels() {
    return _openRouterModels.keys.toList();
  }

  /// Test both providers and return status
  Future<Map<String, dynamic>> testProviders() async {
    final results = <String, dynamic>{};

    // Test Gemini
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('$_geminiBaseUrl/models?key=$geminiApiKey'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        results['gemini'] = {
          'available': response.statusCode == 200,
          'statusCode': response.statusCode,
        };
      } catch (e) {
        results['gemini'] = {
          'available': false,
          'error': e.toString(),
        };
      }
    } else {
      results['gemini'] = {
        'available': false,
        'error': 'API key not configured',
      };
    }

    // Test OpenRouter
    final openRouterApiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (openRouterApiKey != null && openRouterApiKey.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('$_openRouterBaseUrl/models'),
          headers: {
            'Authorization': 'Bearer $openRouterApiKey',
            'HTTP-Referer': 'https://tasteturner.app',
            'X-Title': 'TasteTurner',
          },
        ).timeout(const Duration(seconds: 10));

        results['openRouter'] = {
          'available': response.statusCode == 200,
          'statusCode': response.statusCode,
        };
      } catch (e) {
        results['openRouter'] = {
          'available': false,
          'error': e.toString(),
        };
      }
    } else {
      results['openRouter'] = {
        'available': false,
        'error': 'API key not configured',
      };
    }

    return results;
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
  Future<Map<String, dynamic>> _processAIResponse(
      String text, String operation) async {
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

      // Apply enhanced ingredient validation and deduplication if ingredients exist
      if (jsonData.containsKey('ingredients') &&
          jsonData['ingredients'] is Map) {
        jsonData['ingredients'] = await validateAndNormalizeIngredients(
            jsonData['ingredients'] as Map<String, dynamic>);
      }

      // Also check for ingredients in meal objects
      if (jsonData.containsKey('meals') && jsonData['meals'] is List) {
        final meals = jsonData['meals'] as List<dynamic>;
        for (final meal in meals) {
          if (meal is Map<String, dynamic> && meal.containsKey('ingredients')) {
            meal['ingredients'] = await validateAndNormalizeIngredients(
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
        debugPrint('Partial JSON recovery failed: $partialError');
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

        debugPrint(
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
      debugPrint('Food analysis extraction failed: $e');
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
    // Reset provider health status
    _resetProviderHealth();

    // Try Gemini first
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('$_geminiBaseUrl/models?key=$geminiApiKey'),
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
              _currentProvider = AIProvider.gemini;
              return true;
            } catch (e) {
              continue;
            }
          }
        }
      } catch (e) {
        debugPrint('Gemini initialization failed: $e');
        _isGeminiHealthy = false;
      }
    }

    // If Gemini fails, try OpenRouter
    if (_useOpenRouterFallback) {
      final openRouterApiKey = dotenv.env['OPENROUTER_API_KEY'];
      if (openRouterApiKey != null && openRouterApiKey.isNotEmpty) {
        try {
          final isOpenRouterAvailable = await _testOpenRouterConnection();
          if (isOpenRouterAvailable) {
            _currentProvider = AIProvider.openrouter;
            _activeModel = _getOpenRouterModelName();
            return true;
          }
        } catch (e) {
          debugPrint('OpenRouter initialization failed: $e');
          _isOpenRouterHealthy = false;
        }
      }
    }

    return false;
  }

  /// Test OpenRouter connection
  Future<bool> _testOpenRouterConnection() async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$_openRouterBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://tasteturner.app',
          'X-Title': 'TasteTurner',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final models = decoded['data'] as List<dynamic>? ?? [];

        // Check if our preferred model is available
        final preferredModelId = _openRouterModels[_preferredOpenRouterModel];
        if (preferredModelId != null) {
          final isAvailable = models.any((model) =>
              model['id'] == preferredModelId ||
              model['id'] == _preferredOpenRouterModel);
          return isAvailable;
        }

        // If preferred model not found, check if any model is available
        return models.isNotEmpty;
      }

      return false;
    } catch (e) {
      debugPrint('OpenRouter connection test failed: $e');
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
        'familyMode': userService.currentUser.value?.familyMode ?? false,
        'dietPreference':
            userService.currentUser.value?.settings['dietPreference'] ??
                'balanced',
        'hasProgram': false,
        'encourageProgram': true,
        'maxCalories':
            userService.currentUser.value?.settings['foodGoal'] ?? 2000,
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
      // Return basic context on error
      return {
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

    // Get comprehensive user context
    final aiContext = await _buildAIContext();

    // Add brevity instruction and context to the role/prompt
    final briefingInstruction =
        "Please provide brief, concise responses in 2-4 sentences maximum. ";
    final modifiedPrompt = role != null
        ? '$briefingInstruction\n$aiContext\n$role\nUser: $prompt'
        : '$briefingInstruction\n$aiContext\nUser: $prompt';

    try {
      final response = await _makeApiCallWithRetry(
        endpoint: '${_activeModel}:generateContent',
        body: {
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
            "maxOutputTokens": maxTokens,
          },
        },
        operation: 'get response',
      );

      if (response.containsKey('candidates') &&
          response['candidates'] is List &&
          response['candidates'].isNotEmpty) {
        final candidate = response['candidates'][0];

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
    } catch (e) {
      return 'Error: Failed to connect to AI service: $e';
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
        showTastySnackbar(
            'Something went wrong', 'Please try again later', Get.context!,
            backgroundColor: kRed);
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

  /// Generate meal titles and types based on user context and requirements
  Future<Map<String, dynamic>> generateMealTitles(
      String prompt, String contextInformation) async {
    // Initialize model if not already done
    if (_activeModel == null) {
      final initialized = await initializeModel();
      if (!initialized) {
        throw Exception('No suitable AI model available');
      }
    }

    // Get comprehensive user context
    final aiContext = await _buildAIContext();
    final userContext = await _getUserContext();

    try {
      final response = await _makeApiCallWithRetry(
        endpoint: '${_activeModel}:generateContent',
        operation: 'generate meal titles',
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

$userContext

Based on the user's request and context, generate a meal plan with titles and meal types that would be appropriate and varied. 

IMPORTANT: Return ONLY a raw JSON object. Do NOT wrap in markdown, do NOT use code blocks (```json), do NOT add any text before or after the JSON. Start directly with { and end with }.
{
  "mealPlan": [
    {
      "title": "Greek Yogurt with Berries and Nuts",
      "mealType": "breakfast"
    },
    {
      "title": "Avocado Toast with Eggs",
      "mealType": "breakfast"
    },
    {
      "title": "Grilled Chicken with Roasted Vegetables",
      "mealType": "lunch"
    },
    {
      "title": "Quinoa Buddha Bowl",
      "mealType": "lunch"
    },
    {
      "title": "Mediterranean Salad with Tuna",
      "mealType": "lunch"
    },
    {
      "title": "Salmon with Steamed Broccoli",
      "mealType": "dinner"
    },
    {
      "title": "Vegetarian Pasta Primavera",
      "mealType": "dinner"
    },
    {
      "title": "Beef Stir Fry with Brown Rice",
      "mealType": "dinner"
    },
    {
      "title": "Apple with Almond Butter",
      "mealType": "snack"
    },
    {
      "title": "Hummus with Carrot Sticks",
      "mealType": "snack"
    }
  ],
  "distribution": {
    "breakfast": 2,
    "lunch": 3,
    "dinner": 3,
    "snack": 2
  }
}

CRITICAL REQUIREMENTS:
- You MUST generate EXACTLY 10 meals total (no more, no less)
- You MUST follow this exact distribution:
  * 2 breakfast meals (mealType: "breakfast")
  * 3 lunch meals (mealType: "lunch")
  * 3 dinner meals (mealType: "dinner") 
  * 2 snack meals (mealType: "snack")
- Each meal MUST have a valid mealType field set to one of: "breakfast", "lunch", "dinner", "snack"
- Make titles descriptive but concise
- Ensure variety in ingredients and cooking methods
- Consider dietary preferences and restrictions
- For ingredient-based requests, use the specified ingredients
- For category-based requests, ensure meals fit the categories
- Make titles appetizing and clear about what the meal contains
'''
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 1024,
          },
        },
      );

      if (response['candidates'] == null || response['candidates'].isEmpty) {
        throw Exception('No response from AI model');
      }

      final content = response['candidates'][0]['content'];
      if (content == null ||
          content['parts'] == null ||
          content['parts'].isEmpty) {
        throw Exception('Invalid response structure from AI model');
      }

      final text = content['parts'][0]['text'];
      if (text == null || text.isEmpty) {
        throw Exception('Empty response from AI model');
      }

      // Parse the JSON response - handle both raw JSON and markdown-wrapped JSON
      String jsonText = text.trim();

      // Remove markdown code blocks if present
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7); // Remove ```json
      }
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3); // Remove ```
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3); // Remove ```
      }

      jsonText = jsonText.trim();

      final jsonResponse = json.decode(jsonText) as Map<String, dynamic>;
      final mealPlan = jsonResponse['mealPlan'] as List<dynamic>? ?? [];
      final mealTitles =
          mealPlan.map((meal) => meal['title'] as String).toList();

      // Return both meal titles and the full meal plan data
      return {
        'mealTitles': mealTitles,
        'mealPlan': mealPlan,
        'distribution': jsonResponse['distribution'] as Map<String, dynamic>? ??
            {'breakfast': 2, 'lunch': 2, 'dinner': 2, 'snack': 2}
      };
    } catch (e) {
      // Return fallback data with 10 meals
      return {
        'mealTitles': [
          'Greek Yogurt with Berries and Nuts',
          'Avocado Toast with Eggs',
          'Grilled Chicken with Roasted Vegetables',
          'Quinoa Buddha Bowl',
          'Mediterranean Salad with Tuna',
          'Salmon with Steamed Broccoli',
          'Vegetarian Pasta Primavera',
          'Beef Stir Fry with Brown Rice',
          'Apple with Almond Butter',
          'Hummus with Carrot Sticks',
        ],
        'mealPlan': [
          {
            'title': 'Greek Yogurt with Berries and Nuts',
            'mealType': 'breakfast'
          },
          {'title': 'Avocado Toast with Eggs', 'mealType': 'breakfast'},
          {
            'title': 'Grilled Chicken with Roasted Vegetables',
            'mealType': 'lunch'
          },
          {'title': 'Quinoa Buddha Bowl', 'mealType': 'lunch'},
          {'title': 'Mediterranean Salad with Tuna', 'mealType': 'lunch'},
          {'title': 'Salmon with Steamed Broccoli', 'mealType': 'dinner'},
          {'title': 'Vegetarian Pasta Primavera', 'mealType': 'dinner'},
          {'title': 'Beef Stir Fry with Brown Rice', 'mealType': 'dinner'},
          {'title': 'Apple with Almond Butter', 'mealType': 'snack'},
          {'title': 'Hummus with Carrot Sticks', 'mealType': 'snack'},
        ],
        'distribution': {'breakfast': 2, 'lunch': 3, 'dinner': 3, 'snack': 2}
      };
    }
  }

  /// Check which meal titles already exist in the database (fuzzy matching)
  Future<Map<String, Meal>> checkExistingMealsByTitles(
      List<String> mealTitles) async {
    final existingMeals = <String, Meal>{};

    try {
      // Get all meals from the database
      final allMeals = mealManager.meals;

      for (final title in mealTitles) {
        // Find the best matching meal for this title
        Meal? bestMatch;
        double bestScore = 0.0;

        for (final meal in allMeals) {
          final score = _calculateTitleSimilarity(
              title.toLowerCase(), meal.title.toLowerCase());
          if (score > bestScore && score > 0.6) {
            // Threshold for similarity
            bestScore = score;
            bestMatch = meal;
          }
        }

        if (bestMatch != null) {
          existingMeals[title] = bestMatch;
        } else {}
      }

      return existingMeals;
    } catch (e) {
      return {};
    }
  }

  /// Calculate similarity between two meal titles (fuzzy matching)
  double _calculateTitleSimilarity(String title1, String title2) {
    // Simple word-based similarity
    final words1 = title1.split(' ').toSet();
    final words2 = title2.split(' ').toSet();

    final intersection = words1.intersection(words2);
    final union = words1.union(words2);

    if (union.isEmpty) return 0.0;

    return intersection.length / union.length;
  }

  /// Generate meals directly with AI without checking existing meals
  Future<Map<String, dynamic>> generateMealsWithAI(
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
    final userContext = await _getUserContext();

    try {
      final response = await _makeApiCallWithRetry(
        endpoint: '${_activeModel}:generateContent',
        operation: 'generate meals with AI',
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

$userContext

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
- If specific meal titles are provided in the context, use those EXACT titles and meal types.
- Ensure each meal has the correct mealType field set to one of these four values.
'''
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 2048,
          },
        },
      );

      if (response['candidates'] == null || response['candidates'].isEmpty) {
        throw Exception('No response from AI model');
      }

      final content = response['candidates'][0]['content'];
      if (content == null ||
          content['parts'] == null ||
          content['parts'].isEmpty) {
        throw Exception('Invalid response structure from AI model');
      }

      final text = content['parts'][0]['text'];
      if (text == null || text.isEmpty) {
        throw Exception('Empty response from AI model');
      }

      // Parse the JSON response
      final jsonResponse = json.decode(text) as Map<String, dynamic>;

      // Convert AI response to proper meal format (same as generateMealPlan)
      final meals = jsonResponse['meals'] as List<dynamic>? ?? [];
      final formattedMeals = meals.map((meal) {
        final mealMap = Map<String, dynamic>.from(meal);
        // Add required fields that generateMealPlan provides
        mealMap['id'] = ''; // AI-generated meals don't have IDs initially
        mealMap['source'] = 'ai_generated';
        return mealMap;
      }).toList();

      return {
        'meals': formattedMeals,
        'source': 'ai_generated',
        'count': formattedMeals.length,
        'message': 'AI-generated meals',
      };
    } catch (e) {
      // Return fallback meals if AI generation fails
      return await _getFallbackMeals(prompt);
    }
  }

  /// Generate meals using the new intelligent approach: titles first, then check existing, then generate missing
  Future<Map<String, dynamic>> generateMealsIntelligently(
      String prompt, String contextInformation) async {
    try {
      // Step 1: Generate meal titles and types
      final mealData = await generateMealTitles(prompt, contextInformation);
      final mealTitles = mealData['mealTitles'] as List<String>;
      final mealPlan = mealData['mealPlan'] as List<dynamic>;
      final distribution = mealData['distribution'] as Map<String, dynamic>;

      if (mealTitles.isEmpty) {
        throw Exception('Failed to generate meal titles');
      }

      // Step 2: Check which titles already exist in database
      final existingMeals = await checkExistingMealsByTitles(mealTitles);

      // Step 3: Identify missing titles with their meal types
      final missingMeals = <Map<String, dynamic>>[];
      for (final meal in mealPlan) {
        final title = meal['title'] as String;
        final mealType = meal['mealType'] as String;
        if (!existingMeals.containsKey(title)) {
          missingMeals.add({
            'title': title,
            'mealType': mealType,
          });
        }
      }
      final missingTitles =
          missingMeals.map((m) => m['title'] as String).toList();

      // Step 4: Generate only the missing meals
      List<Map<String, dynamic>> newMeals = [];
      if (missingTitles.isNotEmpty) {
        // Use generateMealsWithAI instead of generateSpecificMeals
        // Pass the missing titles and their meal types in the context information
        final enhancedContextInformation = '''
$contextInformation

IMPORTANT: Generate meals for these specific titles with their meal types:
${missingMeals.map((meal) => '- ${meal['title']} (mealType: ${meal['mealType']})').join('\n')}

Use the EXACT meal titles and meal types provided above. Do not generate any other meals.
''';

        final mealPlanResult = await generateMealsWithAI(
          'Generate meals for the specified titles',
          enhancedContextInformation,
        );

        final meals = mealPlanResult['meals'] as List<dynamic>? ?? [];
        newMeals = meals.cast<Map<String, dynamic>>();
      }

      // Step 5: Combine existing and new meals
      final allMeals = <Map<String, dynamic>>[];

      // Add existing meals with their planned meal types
      for (final meal in mealPlan) {
        final title = meal['title'] as String;
        final mealType = meal['mealType'] as String;
        if (existingMeals.containsKey(title)) {
          final existingMeal = existingMeals[title]!;
          allMeals.add({
            'id': existingMeal.mealId,
            'title': existingMeal.title,
            'categories': existingMeal.categories,
            'ingredients': existingMeal.ingredients,
            'calories': existingMeal.calories,
            'instructions': existingMeal.instructions,
            'mealType': mealType, // Include the planned meal type
            'source': 'existing_database',
          });
        }
      }

      // Add new meals
      allMeals.addAll(newMeals);

      // Calculate nutritional summary
      int totalCalories = 0;
      int totalProtein = 0;
      int totalCarbs = 0;
      int totalFat = 0;

      for (final meal in allMeals) {
        // Handle existing meals (they have 'calories' field)
        if (meal['source'] == 'existing_database') {
          totalCalories += (meal['calories'] ?? 0) as int;
          // For existing meals, we might not have detailed macros, so estimate
          totalProtein += 20; // Estimate
          totalCarbs += 25; // Estimate
          totalFat += 10; // Estimate
        } else {
          // Handle new AI-generated meals (they have 'nutritionalInfo' field)
          final nutritionalInfo =
              meal['nutritionalInfo'] as Map<String, dynamic>?;
          if (nutritionalInfo != null) {
            totalCalories += (nutritionalInfo['calories'] ?? 0) as int;
            totalProtein += (nutritionalInfo['protein'] ?? 0) as int;
            totalCarbs += (nutritionalInfo['carbs'] ?? 0) as int;
            totalFat += (nutritionalInfo['fat'] ?? 0) as int;
          }
        }
      }

      return {
        'meals': allMeals,
        'source': 'mixed',
        'count': allMeals.length,
        'message':
            'Generated ${newMeals.length} new meals and found ${existingMeals.length} existing meals',
        'existingCount': existingMeals.length,
        'newCount': newMeals.length,
        'nutritionalSummary': {
          'totalCalories': totalCalories,
          'totalProtein': totalProtein,
          'totalCarbs': totalCarbs,
          'totalFat': totalFat,
        },
      };
    } catch (e) {
      // Fallback to original method
      return await generateMealPlan(prompt, contextInformation);
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
    final userContext = await _getUserContext();

    // Check for existing meals before generating
    final existingMeal = await checkExistingMealForCriteria(
      prompt: prompt,
      userContext: userContext,
      categories: _extractCategoriesFromPrompt(prompt),
      ingredients: _extractIngredientsFromPrompt(prompt),
      contextInformation: contextInformation,
    );

    if (existingMeal != null) {
      if (existingMeal['type'] == 'ingredient_based') {
        // For ingredient-based: Return multiple existing meals
        final existingMeals = existingMeal['existingMeals'] as List<Meal>;
        return {
          'meals': existingMeals
              .map((meal) => {
                    'id': meal.mealId, // Include the meal ID
                    'title': meal.title,
                    'categories': meal.categories,
                    'ingredients': meal.ingredients,
                    'calories': meal.calories,
                    'instructions': meal.instructions,
                    'source': 'existing_database',
                  })
              .toList(),
          'source': 'existing_database',
          'count': existingMeal['count'],
          'message': existingMeal['message'],
        };
      } else {
        // For meal plan-based: Return existing meals
        final existingMeals = existingMeal['existingMeals'] as List<Meal>;
        return {
          'meals': existingMeals
              .map((meal) => {
                    'id': meal.mealId, // Include the meal ID
                    'title': meal.title,
                    'categories': meal.categories,
                    'ingredients': meal.ingredients,
                    'calories': meal.calories,
                    'instructions': meal.instructions,
                    'source': 'existing_database',
                  })
              .toList(),
          'source': 'existing_database',
          'count': existingMeal['count'],
          'message': existingMeal['message'],
        };
      }
    }

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

$userContext

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
- Generate at minimum 8 meals total with the following distribution:
  * 2 breakfast meals (mealType: "breakfast")
  * 2 lunch meals (mealType: "lunch") 
  * 2 dinner meals (mealType: "dinner")
  * 2 snack meals (mealType: "snack")
- Ensure each meal has the correct mealType field set to one of these four values.
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
        final parsed = await _processAIResponse(text, 'meal_plan');
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

    // Ensure we start with Gemini for image analysis (retry logic will handle fallback if needed)
    if (_currentProvider != AIProvider.gemini) {
      debugPrint('Starting image analysis with Gemini provider');
      _currentProvider = AIProvider.gemini;
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

      // For image analysis, we need to handle both Gemini and OpenRouter differently
      // since OpenRouter has different image handling capabilities
      if (_currentProvider == AIProvider.gemini) {
        // Use Gemini's image analysis with retry and fallback support
        final response = await _makeApiCallWithRetry(
          endpoint: '${_activeModel}:generateContent',
          body: {
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
              "temperature": 0.1,
              "topK": 20,
              "topP": 0.8,
              "maxOutputTokens": 4096,
            },
          },
          operation: 'analyze food image',
        );

        if (response.containsKey('candidates') &&
            response['candidates'] is List &&
            response['candidates'].isNotEmpty) {
          final candidate = response['candidates'][0];

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
        // Use OpenRouter for image analysis with retry support
        final response = await _makeApiCallWithRetry(
          endpoint: 'chat/completions',
          body: {
            "model": _getOpenRouterModelName(),
            "messages": [
              {
                "role": "user",
                "content": [
                  {"type": "text", "text": prompt},
                  {
                    "type": "image_url",
                    "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
                  }
                ]
              }
            ],
            "max_tokens": 4096,
            "temperature": 0.1,
          },
          operation: 'analyze food image with OpenRouter',
        );

        if (response.containsKey('choices') &&
            response['choices'] is List &&
            response['choices'].isNotEmpty) {
          final choice = response['choices'][0];
          final message = choice['message'] as Map<String, dynamic>?;

          if (message != null && message.containsKey('content')) {
            final text = message['content'] as String?;

            if (text != null && text.isNotEmpty) {
              try {
                final result = _processAIResponse(text, 'tasty_analysis');
                return result;
              } catch (e) {
                throw Exception('Failed to parse food analysis JSON: $e');
              }
            } else {
              throw Exception('No text content in OpenRouter response');
            }
          } else {
            throw Exception('No message content in OpenRouter response');
          }
        } else {
          throw Exception('No choices in OpenRouter response');
        }
      }
    } catch (e) {
      throw Exception('Failed to analyze food image: $e');
    }
  }

  Future<Map<String, dynamic>> generateMealsFromIngredients(
      List<dynamic> displayedItems,
      BuildContext parentContext,
      bool isDineIn) async {
    try {
      showDialog(
        context: parentContext,
        builder: (context) => const LoadingScreen(
          loadingText: 'Searching for existing meals...',
        ),
      );

      // Extract ingredient names
      final ingredientNames =
          displayedItems.map((item) => item.title.toString()).toList();

      // Check for existing meals with at least 2 matching ingredients
      final existingMeals =
          await mealManager.searchMealsByIngredientsAndCategories(
        ingredients: ingredientNames,
        categories: [], // Allow all categories for ingredient-based search
        maxCalories: null, // No calorie limit for ingredient-based search
        dietType: null, // No diet restriction for ingredient-based search
      );

      // Hide loading dialog
      Navigator.of(parentContext).pop();

      List<Map<String, dynamic>> mealsToShow = [];
      String source = '';

      if (existingMeals.length >= 2) {
        // Found 2+ existing meals - store all but show only 2 initially
        final allExistingMeals = existingMeals
            .map((meal) => {
                  'id': meal.mealId, // Include the meal ID
                  'title': meal.title,
                  'categories': meal.categories,
                  'ingredients': meal.ingredients,
                  'calories': meal.calories is int
                      ? meal.calories
                      : int.tryParse(meal.calories.toString()) ?? 0,
                  'instructions': meal.instructions,
                  'source': 'existing_database',
                })
            .toList();

        // Show only first 2 meals initially
        mealsToShow = allExistingMeals.take(2).toList();
        source = 'existing_database';
      } else {
        // Found 0-1 existing meals - generate new ones with AI
        showDialog(
          context: parentContext,
          builder: (context) => const LoadingScreen(
            loadingText: 'Generating new meals with AI...',
          ),
        );

        // Prepare prompt and generate meal plan
        final mealPlan = await generateMealPlan(
          'Generate 2 meals using these ingredients: ${ingredientNames.join(', ')}',
          'Stay within the ingredients provided',
        );

        // Hide loading dialog
        Navigator.of(parentContext).pop();

        final generatedMeals = mealPlan['meals'] as List<dynamic>? ?? [];
        if (generatedMeals.isEmpty) throw Exception('No meals generated');

        mealsToShow = generatedMeals.cast<Map<String, dynamic>>();
        source = 'ai_generated';
      }

      if (mealsToShow.isEmpty) throw Exception('No meals available');

      // Show dialog to let user pick one meal
      final selectedMeal = await showDialog<Map<String, dynamic>>(
        context: parentContext,
        barrierDismissible: false, // Prevent dismissing during loading
        builder: (context) {
          final isDarkMode = getThemeProvider(context).isDarkMode;
          final textTheme = Theme.of(context).textTheme;

          // Variables for managing the meal list (outside StatefulBuilder to persist)
          List<Map<String, dynamic>> allExistingMeals = [];
          int currentIndex = 0;
          int mealsPerPage = 2;
          bool isGeneratingAI = false;

          return StatefulBuilder(
            builder: (context, setState) {
              bool isProcessing = false; // Global processing state

              // Initialize the meal list if it's from database
              if (source == 'existing_database' && existingMeals.length >= 2) {
                allExistingMeals = existingMeals
                    .map((meal) => {
                          'id': meal.mealId,
                          'title': meal.title,
                          'categories': meal.categories,
                          'ingredients': meal.ingredients,
                          'calories': meal.calories is int
                              ? meal.calories
                              : int.tryParse(meal.calories.toString()) ?? 0,
                          'instructions': meal.instructions,
                          'source': 'existing_database',
                        })
                    .toList();
              }

              // Function to get current meals to show
              List<Map<String, dynamic>> getCurrentMealsToShow() {
                if (source == 'existing_database' &&
                    allExistingMeals.isNotEmpty) {
                  final endIndex = (currentIndex + mealsPerPage)
                      .clamp(0, allExistingMeals.length);
                  final meals =
                      allExistingMeals.sublist(currentIndex, endIndex);
                  return meals;
                }
                debugPrint(
                    'Showing ${mealsToShow.length} meals from source: $source');
                return mealsToShow;
              }

              // Function to refresh the list
              void refreshMealList() {
                if (source == 'existing_database' &&
                    allExistingMeals.isNotEmpty) {
                  currentIndex += mealsPerPage;
                  if (currentIndex >= allExistingMeals.length) {
                    // All meals shown, switch to AI generation
                    source = 'ai_generated';
                    mealsToShow = [];
                  }
                  setState(() {
                    // Force rebuild
                  });
                }
              }

              return AlertDialog(
                backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                title: Text(
                  source == 'existing_database'
                      ? 'Select from Existing Meals'
                      : source == 'ai_generated'
                          ? 'Select an AI-Generated Meal'
                          : 'Select a Meal',
                  style: textTheme.displaySmall?.copyWith(
                      fontSize: getPercentageWidth(7, context),
                      color: kAccent,
                      fontWeight: FontWeight.w500),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: getCurrentMealsToShow().length,
                    itemBuilder: (context, index) {
                      final meal = getCurrentMealsToShow()[index];
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
                                    String? selectedMealId;

                                    // Use the meal ID (either existing database meal or pre-saved AI meal)
                                    selectedMealId = meal['id'];
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
                  if (source == 'existing_database' &&
                      allExistingMeals.isNotEmpty)
                    TextButton(
                      onPressed: (isProcessing || isGeneratingAI)
                          ? null
                          : () async {
                              if (currentIndex + mealsPerPage >=
                                  allExistingMeals.length) {
                                // All meals shown, generate with AI

                                // Set generating state
                                setState(() {
                                  isGeneratingAI = true;
                                });

                                // Generate new meals with AI
                                try {
                                  // Create context with existing meals to avoid duplicates
                                  final existingMealTitles = allExistingMeals
                                      .map((meal) => meal['title'])
                                      .toList();
                                  final contextWithExistingMeals = '''
Stay within the ingredients provided.
IMPORTANT: Do NOT generate these existing meals: ${existingMealTitles.join(', ')}
Generate completely new and different meal ideas using the same ingredients.
''';

                                  debugPrint('Starting AI meal generation...');
                                  final mealPlan = await generateMealsWithAI(
                                    'Generate 2 meals using these ingredients: ${ingredientNames.join(', ')}',
                                    contextWithExistingMeals,
                                  );

                                  debugPrint(
                                      'AI generation successful: ${mealPlan['meals']?.length ?? 0} meals generated');

                                  // Don't reset generating state yet - do it after updating dialog

                                  final generatedMeals =
                                      mealPlan['meals'] as List<dynamic>? ?? [];
                                  debugPrint(
                                      'Generated meals count: ${generatedMeals.length}');
                                  if (generatedMeals.isEmpty) {
                                    debugPrint(
                                        'No meals generated - throwing exception');
                                    throw Exception('No meals generated');
                                  }

                                  // Save ALL AI-generated meals to Firestore first
                                  final userId = userService.userId;
                                  if (userId == null)
                                    throw Exception('User ID not found');

                                  debugPrint(
                                      'Saving ${generatedMeals.length} meals to Firestore...');
                                  final List<String> allMealIds =
                                      await saveMealsToFirestore(
                                    userId,
                                    {'meals': generatedMeals},
                                    '',
                                  );
                                  debugPrint(
                                      'Saved meals with IDs: $allMealIds');

                                  // Update the meals with their new IDs for selection
                                  final mealsWithIds = <Map<String, dynamic>>[];
                                  for (int i = 0;
                                      i < generatedMeals.length;
                                      i++) {
                                    final meal = Map<String, dynamic>.from(
                                        generatedMeals[i]);
                                    meal['id'] =
                                        allMealIds[i]; // Add the Firestore ID
                                    mealsWithIds.add(meal);
                                  }

                                  // Update the current dialog to show AI-generated meals
                                  debugPrint(
                                      'Updating dialog to show ${mealsWithIds.length} AI-generated meals');
                                  setState(() {
                                    isGeneratingAI = false;
                                    source = 'ai_generated';
                                    mealsToShow = mealsWithIds;
                                  });
                                } catch (e) {
                                  debugPrint(
                                      'AI generation failed with error: $e');
                                  setState(() {
                                    isGeneratingAI = false;
                                  });
                                  if (context.mounted) {
                                    // Show error in current dialog instead of closing it
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to generate AI meals. Please try again.',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 3),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                // Show more existing meals
                                refreshMealList();
                              }
                            },
                      child: Text(
                        isGeneratingAI
                            ? 'Generating...'
                            : (currentIndex + mealsPerPage >=
                                    allExistingMeals.length
                                ? 'Generate with AI'
                                : 'Show More'),
                        style: textTheme.bodyLarge?.copyWith(
                          color: (isProcessing || isGeneratingAI)
                              ? kLightGrey
                              : kAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
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
      if (parentContext.mounted) {
        handleError(e, parentContext);
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
      debugPrint('Error saving analysis to Firestore: $e');
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
      debugPrint('Error creating meal from analysis: $e');
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
      debugPrint('Error adding analyzed meal to daily: $e');
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
      final response = await _makeApiCallWithRetry(
        endpoint: '${_activeModel}:generateContent',
        body: {
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.3,
            "topK": 20,
            "topP": 0.8,
            "maxOutputTokens": 4096,
            "stopSequences": ["```", "```json", "```\n", "\n\n\n"],
          },
        },
        operation: 'generate 54321 shopping list',
      );

      if (response.containsKey('candidates') &&
          response['candidates'] is List &&
          response['candidates'].isNotEmpty) {
        final candidate = response['candidates'][0];

        if (candidate.containsKey('content') && candidate['content'] is Map) {
          final content = candidate['content'];

          if (content.containsKey('parts') &&
              content['parts'] is List &&
              content['parts'].isNotEmpty) {
            final part = content['parts'][0];

            if (part.containsKey('text')) {
              final text = part['text'];
              try {
                return _processAIResponse(text, '54321_shopping');
              } catch (e) {
                throw Exception('Failed to parse 54321 shopping list JSON: $e');
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
    } catch (e) {
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
      showTastySnackbar(
          'Something went wrong', 'Please try again later', Get.context!,
          backgroundColor: kRed);
    }

    return shoppingList;
  }

  /// Enhanced ingredient validation with advanced matching
  /// Checks for existing ingredients using fuzzy matching and regex patterns
  /// For meal generation: Uses existing ingredients if found, otherwise keeps original name
  /// For shopping list: Creates missing ingredients
  Future<Map<String, String>> validateAndNormalizeIngredients(
      Map<String, dynamic> ingredients,
      {bool forShoppingList = false}) async {
    final Map<String, String> validatedIngredients = {};

    for (final entry in ingredients.entries) {
      final ingredientName = entry.key;
      final amount = entry.value;

      // Check if ingredient exists in database with advanced matching
      final existingIngredient =
          await checkIngredientExistsAdvanced(ingredientName);
      if (existingIngredient != null) {
        validatedIngredients[existingIngredient.title] = amount;
      } else {
        if (forShoppingList) {
          // For shopping list generation: Create missing ingredient
          validatedIngredients[ingredientName] = amount;
        } else {
          // For meal generation: Keep original name (AI can use any ingredients)
          validatedIngredients[ingredientName] = amount;
        }
      }
    }

    return validatedIngredients;
  }

  /// Advanced ingredient existence check with fuzzy matching
  Future<IngredientData?> checkIngredientExistsAdvanced(
      String ingredientName) async {
    try {
      final normalizedName = _normalizeIngredientName(ingredientName);

      // First try exact match
      var snapshot = await firestore
          .collection('ingredients')
          .where('title', isEqualTo: ingredientName.toLowerCase())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return IngredientData.fromJson(snapshot.docs.first.data());
      }

      // Try normalized name match
      snapshot = await firestore
          .collection('ingredients')
          .where('title', isEqualTo: normalizedName)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return IngredientData.fromJson(snapshot.docs.first.data());
      }

      // Try normalized matching (remove spaces, hyphens, underscores)
      final normalizedInputName = _normalizeIngredientName(ingredientName);

      // Get all ingredients and check for normalized matches
      final allIngredientsSnapshot =
          await firestore.collection('ingredients').get();

      for (final doc in allIngredientsSnapshot.docs) {
        final ingredientData = doc.data();
        final dbTitle = ingredientData['title'] as String? ?? '';
        final normalizedDbTitle = _normalizeIngredientName(dbTitle);

        if (normalizedInputName == normalizedDbTitle) {
          return IngredientData.fromJson(ingredientData);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check for existing meals that match user criteria before generating new ones
  Future<Map<String, dynamic>?> checkExistingMealForCriteria({
    required String prompt,
    required Map<String, dynamic> userContext,
    required List<String> categories,
    required Map<String, String> ingredients,
    required String contextInformation,
  }) async {
    try {
      // Determine if this is ingredient-based or meal plan-based generation
      final isIngredientBased =
          _isIngredientBasedGeneration(contextInformation);

      if (isIngredientBased) {
        // For ingredient-based: Check for 2+ meals with matching ingredients
        return await _checkIngredientBasedMeals(
            prompt, userContext, categories, ingredients);
      } else {
        // For meal plan-based: Check for multiple meals across categories
        return await _checkMealPlanBasedMeals(
            prompt, userContext, categories, ingredients, contextInformation);
      }
    } catch (e) {
      return null;
    }
  }

  /// Determine if this is ingredient-based generation based on context
  bool _isIngredientBasedGeneration(String contextInformation) {
    final contextLower = contextInformation.toLowerCase();
    return contextLower.contains('ingredients') ||
        contextLower.contains('using these ingredients') ||
        contextLower.contains('stay within the ingredients');
  }

  /// Check for existing meals in ingredient-based generation
  Future<Map<String, dynamic>?> _checkIngredientBasedMeals(
    String prompt,
    Map<String, dynamic> userContext,
    List<String> categories,
    Map<String, String> ingredients,
  ) async {
    // Search for meals with 2+ matching ingredients
    final existingMeals =
        await mealManager.searchMealsByIngredientsAndCategories(
      ingredients: ingredients.keys.toList(),
      categories: categories,
      maxCalories: userContext['maxCalories'],
      dietType: userContext['dietPreference'],
    );

    if (existingMeals.length >= 2) {
      // Return up to 3 best matches
      final bestMeals = existingMeals.take(3).toList();
      return {
        'existingMeals': bestMeals,
        'count': bestMeals.length,
        'message':
            'Found ${bestMeals.length} existing meals with matching ingredients',
        'type': 'ingredient_based',
      };
    }

    return null;
  }

  /// Check for existing meals in meal plan-based generation
  Future<Map<String, dynamic>?> _checkMealPlanBasedMeals(
    String prompt,
    Map<String, dynamic> userContext,
    List<String> categories,
    Map<String, String> ingredients,
    String contextInformation,
  ) async {
    // Extract meal type requirements from prompt
    final mealTypeRequirements = _extractMealTypeRequirements(prompt);

    // Search for meals by categories and meal types
    final existingMeals = await mealManager.searchMealsByCategoriesAndTypes(
      categories: categories,
      mealTypeCounts: mealTypeRequirements,
      dietType: userContext['dietPreference'],
      maxCalories: userContext['maxCalories'],
    );

    // Check if we have enough meals for each required type
    final mealsByType = _groupMealsByType(existingMeals);
    final hasEnoughMeals =
        _checkMealTypeCoverage(mealsByType, mealTypeRequirements);

    if (hasEnoughMeals) {
      return {
        'existingMeals': existingMeals,
        'count': existingMeals.length,
        'message': 'Found sufficient existing meals for meal plan',
        'type': 'meal_plan_based',
        'mealTypeCoverage': mealsByType,
      };
    }

    return null;
  }

  /// Extract meal type requirements and age group from the actual prompt
  Map<String, dynamic> _extractMealTypeRequirements(String prompt) {
    final requirements = <String, dynamic>{};
    final promptLower = prompt.toLowerCase();

    // Look for specific meal type counts in the prompt
    // Example: "Include: - 2 protein dishes - 3 grain dishes - 4 vegetable dishes"
    final proteinMatch =
        RegExp(r'(\d+)\s*protein\s*dishes?', caseSensitive: false)
            .firstMatch(prompt);
    final grainMatch = RegExp(r'(\d+)\s*grain\s*dishes?', caseSensitive: false)
        .firstMatch(prompt);
    final vegMatch =
        RegExp(r'(\d+)\s*vegetable\s*dishes?', caseSensitive: false)
            .firstMatch(prompt);

    if (proteinMatch != null) {
      requirements['protein'] = int.tryParse(proteinMatch.group(1) ?? '0') ?? 0;
    }
    if (grainMatch != null) {
      requirements['grain'] = int.tryParse(grainMatch.group(1) ?? '0') ?? 0;
    }
    if (vegMatch != null) {
      requirements['vegetable'] = int.tryParse(vegMatch.group(1) ?? '0') ?? 0;
    }

    // Also look for meal type patterns (breakfast, lunch, dinner, snack)
    if (promptLower.contains('breakfast')) requirements['breakfast'] = 1;
    if (promptLower.contains('lunch')) requirements['lunch'] = 1;
    if (promptLower.contains('dinner')) requirements['dinner'] = 1;
    if (promptLower.contains('snack')) requirements['snack'] = 1;

    // Extract age group from prompt
    // Look for patterns like "for a baby", "for an adult", "for toddlers", etc.
    final ageGroupMatch = RegExp(
            r'for\s+(?:a\s+|an\s+)?(baby|toddler|child|teen|adult)',
            caseSensitive: false)
        .firstMatch(prompt);
    if (ageGroupMatch != null) {
      requirements['ageGroup'] = ageGroupMatch.group(1)?.toLowerCase();
    }

    // If no specific types mentioned, assume we need at least 2 meals
    if (requirements.isEmpty) {
      requirements['meal'] = 2;
    }

    return requirements;
  }

  /// Group meals by their meal type
  Map<String, List<Meal>> _groupMealsByType(List<Meal> meals) {
    final grouped = <String, List<Meal>>{};

    for (final meal in meals) {
      for (final category in meal.categories) {
        final categoryLower = category.toLowerCase();
        if (categoryLower.contains('breakfast')) {
          grouped.putIfAbsent('breakfast', () => []).add(meal);
        } else if (categoryLower.contains('lunch')) {
          grouped.putIfAbsent('lunch', () => []).add(meal);
        } else if (categoryLower.contains('dinner')) {
          grouped.putIfAbsent('dinner', () => []).add(meal);
        } else if (categoryLower.contains('snack')) {
          grouped.putIfAbsent('snack', () => []).add(meal);
        }
      }
    }

    return grouped;
  }

  /// Check if we have enough meals for each required type
  bool _checkMealTypeCoverage(
      Map<String, List<Meal>> mealsByType, Map<String, dynamic> requirements) {
    for (final entry in requirements.entries) {
      final requiredType = entry.key;
      final requiredValue = entry.value;

      // Skip ageGroup as it's not a meal type
      if (requiredType == 'ageGroup') continue;

      // Handle both int and dynamic values
      final requiredCount = requiredValue is int ? requiredValue : 0;
      final availableMeals = mealsByType[requiredType]?.length ?? 0;

      if (availableMeals < requiredCount) {
        return false;
      }
    }

    return true;
  }

  /// Extract categories from prompt
  List<String> _extractCategoriesFromPrompt(String prompt) {
    final categories = <String>[];
    final promptLower = prompt.toLowerCase();

    // Common category keywords
    final categoryKeywords = {
      'breakfast': ['breakfast', 'morning', 'eggs', 'pancakes', 'waffles'],
      'lunch': ['lunch', 'midday', 'sandwich', 'salad'],
      'dinner': ['dinner', 'evening', 'main course', 'entree'],
      'snack': ['snack', 'appetizer', 'finger food'],
      'vegetarian': ['vegetarian', 'veg', 'meatless'],
      'vegan': ['vegan', 'plant-based'],
      'keto': ['keto', 'ketogenic', 'low-carb'],
      'paleo': ['paleo', 'paleolithic'],
      'quick': ['quick', 'fast', 'easy', 'simple'],
      'healthy': ['healthy', 'nutritious', 'wholesome'],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (promptLower.contains(keyword)) {
          categories.add(entry.key);
          break;
        }
      }
    }

    return categories;
  }

  /// Extract ingredients from prompt
  Map<String, String> _extractIngredientsFromPrompt(String prompt) {
    final ingredients = <String, String>{};
    final promptLower = prompt.toLowerCase();

    // Common ingredient keywords (simplified)
    final ingredientKeywords = [
      'chicken',
      'beef',
      'pork',
      'fish',
      'salmon',
      'tuna',
      'rice',
      'pasta',
      'bread',
      'potato',
      'tomato',
      'onion',
      'garlic',
      'olive oil',
      'butter',
      'cheese',
      'egg',
      'milk',
      'yogurt',
      'flour',
      'sugar',
      'salt',
      'pepper',
    ];

    for (final ingredient in ingredientKeywords) {
      if (promptLower.contains(ingredient)) {
        ingredients[ingredient] = '1 portion';
      }
    }

    return ingredients;
  }
}

// Global instance for easy access throughout the app
final geminiService = GeminiService.instance;
