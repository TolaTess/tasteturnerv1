import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../data_models/ingredient_data.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../helper/ingredient_utils.dart';

/// Enum to track which AI provider is being used
enum AIProvider { gemini, openai, openrouter }

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

  // OpenAI configuration
  final String _openAIBaseUrl = 'https://api.openai.com/v1';
  static int _consecutiveOpenAIErrors = 0;
  String _preferredOpenAIModel = 'gpt-4.1';
  DateTime? _lastOpenAIModelCheck;
  String? _cachedOpenAIModel;
  static const Duration _openAIModelCacheTtl = Duration(minutes: 30);

  // OpenRouter configuration
  static const Map<String, String> _openRouterModels = {
    'gpt-4o': 'openai/gpt-4o',
    'gpt-4o-mini': 'openai/gpt-4o-mini',
    'claude-3-5-sonnet': 'anthropic/claude-3-5-sonnet',
    'claude-3-haiku': 'anthropic/claude-3-haiku',
    'gemini-2.5-flash': 'google/gemini-2.5-flash',
    'gemini-2.0-flash': 'google/gemini-2.0-flash',
    'gemini-1.5-flash': 'google/gemini-1.5-flash',
    'gemini-2.5-pro': 'google/gemini-2.5-pro',
    'gemini-2.0-pro': 'google/gemini-2.0-pro',
    'gemini-1.5-pro': 'google/gemini-1.5-pro',
  };

  String _preferredOpenRouterModel =
      'gemini-2.0-flash'; // Default fallback model (updated to 2.0)

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
    // Try current provider first (Gemini by default)
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

      // If Gemini has been retried and still fails, then try OpenAI fallback, then OpenRouter
      if (useFallback &&
          _currentProvider == AIProvider.gemini &&
          retryCount >= _maxRetries) {
        // Try OpenAI
        try {
          debugPrint(
              'Gemini failed after ${_maxRetries} retries, switching to OpenAI: $e');
          _currentProvider = AIProvider.openai;
          final openaiResult = await _makeApiCallToCurrentProvider(
            endpoint: endpoint,
            body: body,
            operation: operation,
            retryCount: 0,
          );
          _currentProvider = AIProvider.gemini; // reset after success
          debugPrint('Reset back to Gemini provider for next request');
          return openaiResult;
        } catch (openaiErr) {
          debugPrint('OpenAI fallback failed: $openaiErr');
          // Try OpenRouter if allowed
          if (_useOpenRouterFallback) {
            debugPrint('Switching to OpenRouter fallback...');
            _currentProvider = AIProvider.openrouter;
            final orResult = await _makeApiCallToCurrentProvider(
              endpoint: endpoint,
              body: body,
              operation: operation,
              retryCount: 0,
            );
            _currentProvider = AIProvider.gemini; // reset
            debugPrint('Reset back to Gemini provider for next request');
            return orResult;
          }
        }
      }

      // If we're using OpenAI and it fails, retry with OpenAI first
      if (_currentProvider == AIProvider.openai && retryCount < _maxRetries) {
        debugPrint(
            'OpenAI failed, retrying with OpenAI (attempt ${retryCount + 1}): $e');
        return await _makeApiCallWithRetry(
          endpoint: endpoint,
          body: body,
          operation: operation,
          retryCount: retryCount + 1,
          useFallback: useFallback,
        );
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
    } else if (_currentProvider == AIProvider.openai) {
      return await _makeOpenAIApiCall(
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

  /// Fetch analysis data from Firestore using document ID
  Future<Map<String, dynamic>> _fetchAnalysisDataFromFirestore({
    required String analysisId,
    required String operation,
  }) async {
    try {
      String collectionName;

      // Determine collection based on operation
      switch (operation) {
        case 'analyze food image':
          collectionName = 'food_analyses';
          collectionName = 'tastyanalysis';
          break;
        case 'analyze fridge image':
          collectionName = 'fridge_analyses';
          collectionName = 'fridge_analysis';
          break;
        case 'generate meals':
          collectionName = 'mealPlans';
          collectionName = 'meal_plans';
          break;
        default:
          throw Exception('Unknown operation: $operation');
      }

      debugPrint(
          '[Firestore] Fetching from collection: $collectionName, ID: $analysisId');

      final doc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(analysisId)
          .get();

      if (!doc.exists) {
        throw Exception('Analysis document not found: $analysisId');
      }

      final data = doc.data();
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Invalid document data format');
      }
      debugPrint(
          '[Firestore] Successfully fetched data: ${data.keys.toList()}');

      return data;
    } catch (e) {
      debugPrint('[Firestore] Error fetching analysis data: $e');
      rethrow;
    }
  }

  /// Generic cloud function caller with error handling and fallback
  Future<Map<String, dynamic>> _callCloudFunction({
    required String functionName,
    required Map<String, dynamic> data,
    required String operation,
  }) async {
    try {
      debugPrint('[Cloud Function] Calling $functionName for $operation');
      final startTime = DateTime.now();

      final callable = FirebaseFunctions.instance.httpsCallable(functionName);
      final result = await callable(data).timeout(const Duration(seconds: 90));

      final executionTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint(
          '[Cloud Function] $functionName completed in ${executionTime}ms');

      if (result.data is Map<String, dynamic>) {
        final response = result.data as Map<String, dynamic>;
        if (response.isEmpty) {
          throw Exception('Empty response from cloud function');
        }
        if (response['success'] == true) {
          debugPrint(
              '[Cloud Function] $functionName succeeded via cloud function');

          // Handle new optimized response format (complete data included)
          if (response.containsKey('foodItems') ||
              response.containsKey('meals') ||
              response.containsKey('ingredients')) {
            // Data is complete, use it directly (optimized path)
            debugPrint(
                '[Cloud Function] Using direct response data (optimized)');

            // Still add meal IDs if they exist (mealIds is a Map, not List)
            if (response.containsKey('mealIds')) {
              final mealIds = response['mealIds'];
              if (mealIds is Map) {
                debugPrint(
                    '[Cloud Function] Added ${mealIds.length} meal IDs (map) to response');
              } else if (mealIds is List) {
                debugPrint(
                    '[Cloud Function] Added ${mealIds.length} meal IDs (list) to response');
              }
            }

            return response;
          } else if (response.containsKey('analysisId') ||
              response.containsKey('mealPlanId')) {
            // Fallback to Firestore fetch (legacy support)
            final analysisId = response['analysisId'] ?? response['mealPlanId'];
            debugPrint(
                '[Cloud Function] Fetching data from Firestore with ID: $analysisId');

            // Fetch data from Firestore based on operation type
            final firestoreData = await _fetchAnalysisDataFromFirestore(
              analysisId: analysisId,
              operation: operation,
            );

            // Add meal IDs to the response if they exist (mealIds is a Map, not List)
            if (response.containsKey('mealIds')) {
              final mealIds = response['mealIds'];
              firestoreData['mealIds'] = mealIds;
              if (mealIds is Map) {
                debugPrint(
                    '[Cloud Function] Added ${mealIds.length} meal IDs (map) to response');
              } else if (mealIds is List) {
                debugPrint(
                    '[Cloud Function] Added ${mealIds.length} meal IDs (list) to response');
              }
            }

            debugPrint(
                '[Cloud Function] Successfully fetched data from Firestore');
            return firestoreData;
          } else {
            // Fallback to old format (should not happen with new cloud functions)
            debugPrint('[Cloud Function] Using legacy response format');
            return response;
          }
        } else {
          throw Exception(
              'Cloud function returned unsuccessful result: ${response['error'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint(
            '[Cloud Function] Invalid response format: ${result.data.runtimeType}');
        throw Exception('Invalid response format from cloud function');
      }
    } catch (e) {
      debugPrint('[Cloud Function] $functionName failed: $e');
      // Re-throw to trigger fallback to client-side AI
      throw Exception('Cloud function failed: $e');
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
      debugPrint(
          'Gemini health check failed. Consecutive errors: $_consecutiveGeminiErrors');
      debugPrint('Last error time: $_lastGeminiError');
      throw Exception(
          'Gemini API temporarily unavailable. Please try again later.');
    }

    try {
      // Debug: log endpoint and minimal request info
      try {
        final preview = jsonEncode(body).toString();
        final previewShort =
            preview.length > 600 ? preview.substring(0, 600) + '…' : preview;
        debugPrint('[Gemini] POST to $endpoint (retry=$retryCount)');
        debugPrint(
            '[Gemini] Request body preview (${preview.length} chars): $previewShort');
      } catch (e) {
        debugPrint('[Gemini] Error logging request preview: $e');
      }

      final response = await http
          .post(
            Uri.parse('$_geminiBaseUrl/$endpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        // Reset error tracking on success
        _consecutiveGeminiErrors = 0;
        _isGeminiHealthy = true;

        // Check if response body is empty
        if (response.body.isEmpty) {
          throw Exception('Empty response from Gemini API');
        }

        // Debug: log response size and preview
        try {
          final bodyLen = response.body.length;
          final bodyPreview = bodyLen > 1200
              ? response.body.substring(0, 1200) + '…'
              : response.body;
          debugPrint('[Gemini] Response 200 OK, ${bodyLen} chars');
          debugPrint('[Gemini] Response preview: $bodyPreview');
        } catch (e) {
          debugPrint('[Gemini] Error logging response preview: $e');
        }

        final decoded = jsonDecode(response.body);
        return decoded;
      } else {
        // Handle specific error codes
        String errorMessage = 'Unknown error';
        try {
          if (response.body.isNotEmpty) {
            final errorResponse = jsonDecode(response.body);
            errorMessage =
                errorResponse['error']?['message'] ?? 'Unknown error';
          }
        } catch (e) {
          errorMessage = 'Failed to parse error response: ${e.toString()}';
        }
        final errorCode = response.statusCode;

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
          if (parts.isEmpty) {
            debugPrint('[Gemini] Request body has empty parts array');
          }
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
          .timeout(const Duration(seconds: 90));

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
    final contentsRaw = geminiBody['contents'];
    if (contentsRaw == null ||
        contentsRaw is! List<dynamic> ||
        contentsRaw.isEmpty) {
      throw Exception('Invalid Gemini body: missing or empty contents');
    }
    final contents = contentsRaw as List<dynamic>;

    final generationConfigRaw = geminiBody['generationConfig'];
    final generationConfig = (generationConfigRaw is Map<String, dynamic>)
        ? generationConfigRaw
        : <String, dynamic>{};

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
    final modelName = _openRouterModels[_preferredOpenRouterModel] ??
        _openRouterModels['gemini-1.5-flash']!;
    debugPrint(
        'OpenRouter model selected: $modelName (preferred: $_preferredOpenRouterModel)');
    return modelName;
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

  /// Force reset provider health status (for debugging/testing)
  void forceResetProviderHealth() {
    _isGeminiHealthy = true;
    _consecutiveGeminiErrors = 0;
    _lastGeminiError = null;
    _isOpenRouterHealthy = true;
    _consecutiveOpenRouterErrors = 0;
    _lastOpenRouterError = null;
    debugPrint('Force reset all provider health status');
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

  /// Force refresh the model configuration
  void refreshModelConfiguration() {
    debugPrint('Refreshing model configuration...');
    debugPrint('Current preferred model: $_preferredOpenRouterModel');

    // Force update to newer Gemini model if using old ones
    if (_preferredOpenRouterModel == 'gpt-4o-mini' ||
        _preferredOpenRouterModel == 'gemini-1.5-flash') {
      _preferredOpenRouterModel = 'gemini-2.0-flash';
      debugPrint('Updated preferred model to: $_preferredOpenRouterModel');
    }

    // Force reset provider health to allow retries
    forceResetProviderHealth();

    debugPrint('Available models: $_openRouterModels');
    debugPrint('Gemini healthy: $_isGeminiHealthy');
    debugPrint('OpenRouter healthy: $_isOpenRouterHealthy');
    _activeModel = null; // Force re-initialization
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
    // Return empty lists instead of sample meals
    // This will trigger the user to try again
    return {
      'mealTitles': [],
      'mealPlan': [],
      'distribution': {},
      'source': 'fallback',
      'message': 'AI service temporarily unavailable. Please try again.'
    };
  }

  /// Make a provider-level OpenAI API call (used by unified retry flow)
  Future<Map<String, dynamic>> _makeOpenAIApiCall({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API key not configured');
    }

    // Convert Gemini-style request to OpenAI chat format
    final openaiBody = _convertToOpenAIFormat(body);
    openaiBody['model'] = await _getBestAvailableOpenAIModel();
    final url = '$_openAIBaseUrl/chat/completions';
    debugPrint('Making OpenAI API call to: $url');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(openaiBody),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        _consecutiveOpenAIErrors = 0;
        // OpenAI provider recovered
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return _convertFromOpenAIFormat(decoded);
      }

      // Retry on 5xx
      if (response.statusCode >= 500 && retryCount < _maxRetries) {
        await Future.delayed(_retryDelay * (retryCount + 1));
        return _makeOpenAIApiCall(
          endpoint: endpoint,
          body: body,
          operation: operation,
          retryCount: retryCount + 1,
        );
      }

      _handleOpenAIError(
          'Service error: ${response.statusCode} - ${response.body}');
      throw Exception('OpenAI service error');
    } catch (e) {
      _handleOpenAIError('Connection error: ${e.toString()}');
      rethrow;
    }
  }

  Map<String, dynamic> _convertToOpenAIFormat(Map<String, dynamic> geminiBody) {
    // Extract text from Gemini format
    String text = '';
    try {
      final contentsRaw = geminiBody['contents'];
      if (contentsRaw is List<dynamic> && contentsRaw.isNotEmpty) {
        final firstContent = contentsRaw.first;
        if (firstContent is Map<String, dynamic>) {
          final partsRaw = firstContent['parts'];
          if (partsRaw is List<dynamic> && partsRaw.isNotEmpty) {
            final firstPart = partsRaw.first;
            if (firstPart is Map<String, dynamic>) {
              final textRaw = firstPart['text'];
              if (textRaw is String) {
                text = textRaw;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[Gemini] Error extracting text from response: $e');
    }

    final maxTokens =
        (geminiBody['generationConfig']?['maxOutputTokens'] as int?) ?? 4000;
    final temperature =
        (geminiBody['generationConfig']?['temperature'] as num?)?.toDouble() ??
            0.7;

    return {
      'model': 'gpt-4.1', // will be overridden by dynamic selector
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': text}
          ]
        }
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
    };
  }

  Map<String, dynamic> _convertFromOpenAIFormat(
      Map<String, dynamic> openaiResponse) {
    final choices = openaiResponse['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) throw Exception('No response from OpenAI');
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'];
    if (content is String && content.isNotEmpty) {
      // Return as Gemini-style response
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
    throw Exception('Invalid OpenAI response');
  }

  void _handleOpenAIError(String message) {
    _consecutiveOpenAIErrors++;
    if (_consecutiveOpenAIErrors >= _maxConsecutiveErrors) {
      // Provider marked as unhealthy - will be reset by recovery logic
      debugPrint(
          'OpenAI marked as unhealthy after $_consecutiveOpenAIErrors consecutive errors');
    }
    debugPrint('OpenAI error: $message');
  }

  /// Determine best available OpenAI model and cache the selection
  Future<String> _getBestAvailableOpenAIModel() async {
    // Use cached model if recent
    if (_cachedOpenAIModel != null &&
        _lastOpenAIModelCheck != null &&
        DateTime.now().difference(_lastOpenAIModelCheck!) <
            _openAIModelCacheTtl) {
      return _cachedOpenAIModel!;
    }

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return _preferredOpenAIModel; // fallback to preferred if no key
    }

    try {
      final response = await http.get(
        Uri.parse('$_openAIBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(const Duration(seconds: 10));

      final priority = <String>[
        'gpt-4.1',
        'gpt-4.1-mini',
        'gpt-4o',
        'gpt-4o-mini',
        'gpt-4-turbo',
        'gpt-4'
      ];

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as List<dynamic>? ?? [];
        final ids = data
            .map((m) => (m as Map<String, dynamic>)['id']?.toString() ?? '')
            .toSet();
        for (final m in priority) {
          if (ids.contains(m)) {
            _cachedOpenAIModel = m;
            _lastOpenAIModelCheck = DateTime.now();
            debugPrint('Selected OpenAI model: $m');
            return m;
          }
        }
      }
    } catch (e) {
      debugPrint('[OpenAI] Error checking available models: $e');
    }

    // Fallback to preferred
    _cachedOpenAIModel = _preferredOpenAIModel;
    _lastOpenAIModelCheck = DateTime.now();
    return _preferredOpenAIModel;
  }

  /// Parse calories value ensuring it's a valid number
  int _parseCalories(dynamic calories) {
    if (calories == null) return 0;

    if (calories is int) return calories;
    if (calories is double) return calories.round();
    if (calories is String) {
      final parsed = int.tryParse(calories);
      return parsed ?? 0;
    }

    return 0;
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
      final normalizedName = normalizeIngredientName(originalName);

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
        final combinedResult = combineIngredients(ingredientList);
        normalizedIngredients[combinedResult.key] = combinedResult.value;
      }
    });

    return normalizedIngredients;
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

      // Use robust validation for fridge_analysis
      if (operation == 'fridge_analysis') {
        final result = _validateAndExtractFridgeAnalysis(text);
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

  /// Robust JSON validation and extraction for fridge analysis
  Map<String, dynamic> _validateAndExtractFridgeAnalysis(String rawResponse) {
    try {
      debugPrint('=== FRIDGE ANALYSIS PARSING ===');
      debugPrint('Raw AI response: $rawResponse');

      // Try direct JSON parsing first (bypass all the complex processing)
      try {
        final directData = jsonDecode(rawResponse) as Map<String, dynamic>;
        debugPrint('Direct JSON parsing successful: $directData');

        // Validate and normalize the data
        final result = _validateAndNormalizeFridgeAnalysisData(directData);
        debugPrint('Direct parsing result: $result');
        return result;
      } catch (directError) {
        debugPrint('Direct parsing failed: $directError');
      }

      // First attempt: extract JSON from markdown code blocks if present
      final cleanedResponse = _extractJsonFromMarkdown(rawResponse);
      debugPrint('Cleaned response: $cleanedResponse');

      final completedResponse = _completeTruncatedJson(cleanedResponse);
      debugPrint('Completed response: $completedResponse');

      final sanitized = _sanitizeJsonString(completedResponse);
      debugPrint('Sanitized response: $sanitized');

      final data = jsonDecode(sanitized) as Map<String, dynamic>;
      debugPrint('Parsed JSON data: $data');

      // Validate and normalize the data
      final result = _validateAndNormalizeFridgeAnalysisData(data);
      debugPrint('Final normalized result: $result');
      return result;
    } catch (e) {
      // Second attempt: use existing partial extraction method
      final partialData = _extractPartialJson(rawResponse, 'fridge_analysis');
      if (partialData.isNotEmpty &&
          _isValidPartialResponse(partialData, 'fridge_analysis')) {
        return _validateAndNormalizeFridgeAnalysisData(partialData);
      }

      // Third attempt: extract fridge analysis data from malformed response
      final extractedData = _extractFridgeAnalysisFromRawText(rawResponse);
      if (extractedData.isNotEmpty) {
        return _validateAndNormalizeFridgeAnalysisData(extractedData);
      }

      // Return fallback if all extraction attempts fail
      return _createFallbackResponse(
          'fridge_analysis', 'Complete extraction failed');
    }
  }

  /// Validate and normalize fridge analysis data
  Map<String, dynamic> _validateAndNormalizeFridgeAnalysisData(
      Map<String, dynamic> data) {
    final result = <String, dynamic>{};

    // Validate ingredients array
    if (data['ingredients'] is List) {
      final ingredients = (data['ingredients'] as List).map((item) {
        if (item is Map) {
          debugPrint('Ingredient: ${item}');
          return {
            'name': (item['name'] as String?) ?? 'Unknown ingredient',
            'category': (item['category'] as String?) ?? 'other',
          };
        }
        return {
          'name': 'Unknown ingredient',
          'category': 'other',
        };
      }).toList();
      result['ingredients'] = ingredients;
    } else {
      result['ingredients'] = [];
    }

    // Validate suggested meals array
    if (data['suggestedMeals'] is List) {
      final meals = (data['suggestedMeals'] as List).map((item) {
        if (item is Map) {
          debugPrint('Raw suggested meal from AI: ${item}');
          debugPrint(
              'Raw cookingTime: ${item['cookingTime']} (type: ${item['cookingTime'].runtimeType})');
          debugPrint(
              'Raw calories: ${item['calories']} (type: ${item['calories'].runtimeType})');

          final processedMeal = {
            'title': (item['title'] as String?) ?? 'Untitled Meal',
            'cookingTime': (item['cookingTime'] as String?) ?? '20 minutes',
            'difficulty': (item['difficulty'] as String?) ?? 'medium',
            'calories': (item['calories'] as num?) ?? 0,
          };

          debugPrint('Processed suggested meal: ${processedMeal}');
          return processedMeal;
        }
        return {
          'title': 'Untitled Meal',
          'cookingTime': '20 minutes',
          'difficulty': 'medium',
          'calories': 0,
        };
      }).toList();
      result['suggestedMeals'] = meals;
      debugPrint('Final suggested meals array: ${result['suggestedMeals']}');
    } else {
      result['suggestedMeals'] = [];
    }

    // Validate other fields
    result['totalIngredients'] = (data['totalIngredients'] as num?)?.toInt() ??
        result['ingredients'].length;

    return result;
  }

  /// Extract fridge analysis data from raw text using regex patterns
  Map<String, dynamic> _extractFridgeAnalysisFromRawText(String rawResponse) {
    debugPrint('=== USING FALLBACK EXTRACTION METHOD ===');
    debugPrint('Raw response for fallback: $rawResponse');
    final result = <String, dynamic>{};

    // Extract ingredients using regex
    final ingredientPattern =
        RegExp(r'"name"\s*:\s*"([^"]+)"', multiLine: true);
    final ingredients = <Map<String, dynamic>>[];

    final ingredientMatches = ingredientPattern.allMatches(rawResponse);
    for (final match in ingredientMatches) {
      final name = match.group(1);
      if (name != null && name.isNotEmpty) {
        ingredients.add({
          'name': name,
          'category': 'other',
        });
      }
    }
    result['ingredients'] = ingredients;

    // Extract suggested meals with all fields
    final mealPattern = RegExp(r'"title"\s*:\s*"([^"]+)"', multiLine: true);
    final meals = <Map<String, dynamic>>[];

    final mealMatches = mealPattern.allMatches(rawResponse);
    for (final match in mealMatches) {
      final title = match.group(1);
      if (title != null && title.isNotEmpty) {
        // Extract cookingTime for this meal
        String cookingTime = 'Unknown';
        final cookingTimePattern =
            RegExp(r'"cookingTime"\s*:\s*"([^"]+)"', multiLine: true);
        final cookingTimeMatch = cookingTimePattern.firstMatch(rawResponse);
        if (cookingTimeMatch != null) {
          cookingTime = cookingTimeMatch.group(1) ?? 'Unknown';
        }

        // Extract calories for this meal
        int calories = 0;
        final caloriesPattern =
            RegExp(r'"calories"\s*:\s*(\d+)', multiLine: true);
        final caloriesMatch = caloriesPattern.firstMatch(rawResponse);
        if (caloriesMatch != null) {
          calories = int.tryParse(caloriesMatch.group(1) ?? '0') ?? 0;
        }

        // Extract difficulty for this meal
        String difficulty = 'medium';
        final difficultyPattern =
            RegExp(r'"difficulty"\s*:\s*"([^"]+)"', multiLine: true);
        final difficultyMatch = difficultyPattern.firstMatch(rawResponse);
        if (difficultyMatch != null) {
          difficulty = difficultyMatch.group(1) ?? 'medium';
        }

        meals.add({
          'title': title,
          'description': 'No description',
          'cookingTime': cookingTime,
          'difficulty': difficulty,
          'calories': calories,
        });
      }
    }
    result['suggestedMeals'] = meals;

    result['totalIngredients'] = ingredients.length;
    result['confidence'] = 'medium';
    result['notes'] = 'Extracted from partial response';

    debugPrint('Fallback extraction result: $result');
    return result;
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
      // Return empty data if no food items exist
      normalizedData['foodItems'] = [];
      normalizedData['totalNutrition'] = {
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'fiber': 0,
        'sugar': 0,
        'sodium': 0,
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
          'foodItems': [],
          'totalNutrition': {
            'calories': 0,
            'protein': 0,
            'carbs': 0,
            'fat': 0,
            'fiber': 0,
            'sugar': 0,
            'sodium': 0
          },
          'mealType': 'unknown',
          'estimatedPortionSize': 'unknown',
          'ingredients': {},
          'cookingMethod': 'unknown',
          'confidence': 'low',
          'healthScore': 0,
          'instructions': [],
          'dietaryFlags': {
            'vegetarian': false,
            'vegan': false,
            'glutenFree': false,
            'dairyFree': false,
            'keto': false,
            'lowCarb': false,
          },
          'suggestions': {
            'improvements': [],
            'alternatives': [],
            'additions': [],
          },
          'notes': 'AI analysis failed. Please try again.',
          'source': 'fallback',
          'message': 'AI service temporarily unavailable. Please try again.'
        };
      case 'meal_generation':
        return {
          'meals': [],
          'nutritionalSummary': {
            'totalCalories': 0,
            'totalProtein': 0,
            'totalCarbs': 0,
            'totalFat': 0
          },
          'tips': [],
          'source': 'fallback',
          'message': 'AI service temporarily unavailable. Please try again.'
        };
      case 'meal_plan':
        return {
          'meals': [],
          'nutritionalSummary': {
            'totalCalories': 0,
            'totalProtein': 0,
            'totalCarbs': 0,
            'totalFat': 0
          },
          'tips': [],
          'source': 'fallback',
          'message': 'AI service temporarily unavailable. Please try again.'
        };
      case 'program_generation':
        return {
          'duration': '0 weeks',
          'weeklyPlans': [],
          'requirements': [],
          'recommendations': [],
          'source': 'fallback',
          'message': 'AI service temporarily unavailable. Please try again.'
        };
      case 'food_comparison':
        return {
          'image1Analysis': {
            'foodItems': [],
            'totalNutrition': {
              'calories': 0,
              'protein': 0,
              'carbs': 0,
              'fat': 0
            },
            'healthScore': 0
          },
          'image2Analysis': {
            'foodItems': [],
            'totalNutrition': {
              'calories': 0,
              'protein': 0,
              'carbs': 0,
              'fat': 0
            },
            'healthScore': 0
          },
          'comparison': {
            'winner': 'none',
            'reasons': [],
            'nutritionalDifferences': {
              'calories': 'Unable to determine',
              'protein': 'Unable to determine',
              'carbs': 'Unable to determine',
              'fat': 'Unable to determine'
            }
          },
          'recommendations': [],
          'summary': 'AI analysis failed. Please try again.',
          'source': 'fallback',
          'message': 'AI service temporarily unavailable. Please try again.'
        };
      default:
        return {
          'error': true,
          'message': 'AI analysis failed: $error',
          'operation': operation,
          'source': 'fallback'
        };
    }
  }

  // Initialize and find a working model
  Future<bool> initializeModel() async {
    debugPrint('=== Initializing AI model ===');

    // Ensure we're using gemini-2.0-flash as preferred model (or newer if available)
    if (_preferredOpenRouterModel == 'gemini-1.5-flash' ||
        _preferredOpenRouterModel == 'gpt-4o-mini') {
      _preferredOpenRouterModel = 'gemini-2.0-flash';
      debugPrint(
          'Updated preferred OpenRouter model to: $_preferredOpenRouterModel');
    }

    // Force reset provider health status on initialization
    // This ensures we always try both providers even if they were marked unhealthy before
    forceResetProviderHealth();
    debugPrint(
        'Provider health reset - Gemini: $_isGeminiHealthy, OpenRouter: $_isOpenRouterHealthy');

    // Try OpenAI first for client-side fallback (since cloud functions handle primary AI)
    final openaiApiKey = dotenv.env['OPENAI_API_KEY'];
    debugPrint(
        'OpenAI API key present: ${openaiApiKey != null && openaiApiKey.isNotEmpty}');

    if (openaiApiKey != null && openaiApiKey.isNotEmpty) {
      try {
        debugPrint('Testing OpenAI API connection...');
        final response = await http.post(
          Uri.parse('https://api.openai.com/v1/models'),
          headers: {
            'Authorization': 'Bearer $openaiApiKey',
            'Content-Type': 'application/json',
          },
        );

        debugPrint('OpenAI models response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final models = decoded['data'] as List;
          debugPrint('Found ${models.length} OpenAI models');

          // Log all available model names for debugging
          debugPrint('Available OpenAI models:');
          for (var model in models) {
            debugPrint('  - ${model['id']}');
          }

          // Look for available text models in order of preference
          final preferredModels = [
            'gpt-4o',
            'gpt-4o-mini',
            'gpt-4-turbo',
            'gpt-4',
            'gpt-3.5-turbo',
          ];

          // Try preferred models first
          for (final modelName in preferredModels) {
            try {
              final model = models.firstWhere(
                (m) => m['id'].toString().startsWith(modelName),
              );

              // Store the model name
              _activeModel = model['id'].toString();
              _currentProvider = AIProvider.openai;
              debugPrint('✅ OpenAI initialized with model: $_activeModel');
              return true;
            } catch (e) {
              debugPrint('Model $modelName not found, trying next...');
              continue;
            }
          }

          // If no preferred model found, use any available OpenAI model
          debugPrint(
              '⚠️ No preferred models found, looking for any usable OpenAI model...');
          for (var model in models) {
            final modelName = model['id'].toString();
            // Use any OpenAI model
            if (modelName.startsWith('gpt-')) {
              _activeModel = modelName;
              _currentProvider = AIProvider.openai;
              debugPrint('✅ Using fallback OpenAI model: $_activeModel');
              return true;
            }
          }

          debugPrint('❌ No usable OpenAI models found');
        } else {
          debugPrint(
              '❌ OpenAI API returned error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('❌ OpenAI initialization error: $e');
        // OpenAI provider marked as unhealthy
      }
    } else {
      debugPrint('⚠️ OpenAI API key not configured');
    }

    // If OpenAI fails, try Gemini
    debugPrint(
        'OpenAI initialization failed or not available, trying Gemini...');

    final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
    debugPrint(
        'Gemini API key present: ${geminiApiKey != null && geminiApiKey.isNotEmpty}');

    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      try {
        debugPrint('Fetching Gemini models list...');
        final response = await http.get(
          Uri.parse('$_geminiBaseUrl/models?key=$geminiApiKey'),
          headers: {'Content-Type': 'application/json'},
        );

        debugPrint('Gemini models response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final models = decoded['models'] as List;
          debugPrint('Found ${models.length} Gemini models');

          // Log all available model names for debugging
          debugPrint('Available Gemini models:');
          for (var model in models) {
            debugPrint('  - ${model['name']}');
          }

          // Look for available text models in order of preference
          final preferredModels = [
            'gemini-2.5-flash',
            'gemini-2.0-flash-exp',
            'gemini-2.0-flash',
            'gemini-1.5-flash',
            'gemini-1.5-pro',
            'gemini-2.5-pro',
            'gemini-2.0-pro',
            'gemini-pro-vision',
            'gemini-pro',
          ];

          // Try preferred models first
          for (final modelName in preferredModels) {
            try {
              final model = models.firstWhere(
                (m) => m['name'].toString().endsWith(modelName),
              );

              // Store the full model path
              _activeModel = model['name'].toString();
              _currentProvider = AIProvider.gemini;
              debugPrint('✅ Gemini initialized with model: $_activeModel');
              return true;
            } catch (e) {
              debugPrint('Model $modelName not found, trying next...');
              continue;
            }
          }

          // CRITICAL: If no preferred model found, use ANY available Gemini model
          // This ensures we ALWAYS use Gemini direct API over OpenRouter fallback
          // Only skip embedding models as they can't do text/image generation
          debugPrint(
              '⚠️ No preferred models found, looking for any usable Gemini model...');
          for (var model in models) {
            final modelName = model['name'].toString();
            // Skip embedding models and use any other Gemini model
            if (!modelName.contains('embedding') &&
                !modelName.contains('text-embedding')) {
              _activeModel = modelName;
              _currentProvider = AIProvider.gemini;
              debugPrint('✅ Using fallback Gemini model: $_activeModel');
              debugPrint(
                  '   This ensures we use Gemini direct API instead of OpenRouter');
              return true;
            }
          }

          debugPrint(
              '❌ No usable Gemini models found (all are embedding models)');
        } else {
          debugPrint(
              '❌ Gemini API returned error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('❌ Gemini initialization error: $e');
        _isGeminiHealthy = false;
      }
    } else {
      debugPrint('⚠️ Gemini API key not configured');
    }

    // If Gemini fails, try OpenRouter
    debugPrint(
        'Gemini initialization failed or not available, trying OpenRouter...');

    if (_useOpenRouterFallback) {
      final openRouterApiKey = dotenv.env['OPENROUTER_API_KEY'];
      debugPrint(
          'OpenRouter API key present: ${openRouterApiKey != null && openRouterApiKey.isNotEmpty}');

      if (openRouterApiKey != null && openRouterApiKey.isNotEmpty) {
        try {
          debugPrint('Testing OpenRouter connection...');
          final isOpenRouterAvailable = await _testOpenRouterConnection();
          debugPrint('OpenRouter available: $isOpenRouterAvailable');

          if (isOpenRouterAvailable) {
            _currentProvider = AIProvider.openrouter;
            _activeModel = _getOpenRouterModelName();
            debugPrint('✅ OpenRouter initialized with model: $_activeModel');
            return true;
          } else {
            debugPrint('❌ OpenRouter connection test failed');
          }
        } catch (e) {
          debugPrint('❌ OpenRouter initialization error: $e');
          _isOpenRouterHealthy = false;
        }
      } else {
        debugPrint('⚠️ OpenRouter API key not configured');
      }
    } else {
      debugPrint('⚠️ OpenRouter fallback is disabled');
    }

    debugPrint('❌ Both Gemini and OpenRouter initialization failed');
    return false;
  }

  /// Test OpenRouter connection
  Future<bool> _testOpenRouterConnection() async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('OpenRouter API key is missing');
      return false;
    }

    try {
      debugPrint('Fetching OpenRouter models list...');
      final response = await http.get(
        Uri.parse('$_openRouterBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://tasteturner.app',
          'X-Title': 'TasteTurner',
        },
      );

      debugPrint('OpenRouter models response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final models = decoded['data'] as List<dynamic>? ?? [];
        debugPrint('Found ${models.length} OpenRouter models');

        // Check if our preferred model is available
        final preferredModelId = _openRouterModels[_preferredOpenRouterModel];
        debugPrint(
            'Looking for preferred model: $_preferredOpenRouterModel ($preferredModelId)');

        if (preferredModelId != null) {
          final isAvailable = models.any((model) =>
              model['id'] == preferredModelId ||
              model['id'] == _preferredOpenRouterModel);
          debugPrint('Preferred model available: $isAvailable');
          return isAvailable;
        }

        // If preferred model not found, check if any model is available
        final anyAvailable = models.isNotEmpty;
        debugPrint('Any OpenRouter model available: $anyAvailable');
        return anyAvailable;
      } else {
        debugPrint(
            'OpenRouter API error: ${response.statusCode} - ${response.body}');
      }

      return false;
    } catch (e) {
      debugPrint('OpenRouter connection test exception: $e');
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
      };
    } // 'programMessage':
    //     'Consider enrolling in a personalized program to get tailored meal plans and nutrition guidance.',
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
        'maxCalories':
            userService.currentUser.value?.settings['foodGoal'] ?? 2000,
      };

      if (userProgramQuery.docs.isNotEmpty) {
        final userProgramDoc = userProgramQuery.docs.first;
        final userProgramData = userProgramDoc.data();
        final programId = userProgramDoc.id; // Document ID is the program ID

        if (programId.isNotEmpty) {
          // Fetch program details
          DocumentSnapshot? programDoc;
          try {
            programDoc =
                await firestore.collection('programs').doc(programId).get();
          } catch (e) {
            debugPrint('Error fetching program $programId: $e');
            // Continue without program context if fetch fails
            programDoc = null;
          }

          if (programDoc != null && programDoc.exists) {
            final programDataRaw = programDoc.data();
            if (programDataRaw == null ||
                programDataRaw is! Map<String, dynamic>) {
              debugPrint('Invalid program data format for $programId');
            } else {
              final programData = programDataRaw as Map<String, dynamic>;

              context.addAll({
                'hasProgram': true,
                'currentProgram': {
                  'name': programData['name'] ?? 'Current Program',
                  'goal': programData['goal'] ?? 'Health improvement',
                  'dietType':
                      programData['dietType'] ?? context['dietPreference'],
                },
                'programProgress': {
                  'currentWeek': userProgramData['currentWeek'] ?? 1,
                },
              });
            }
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

  /// Build streamlined context string for AI prompts (reduced token usage)
  Future<String> _buildAIContext({bool includeDiet = true, bool includeProgramContext = true}) async {
    final userContext = await _getUserContext();

    String context = '';
    if (includeDiet) {
      context = 'Diet: ${userContext['dietPreference']}';
    }

    if (includeProgramContext && userContext['hasProgram'] == true) {
      final program = userContext['currentProgram'] as Map<String, dynamic>;
      if (context.isNotEmpty) {
        context += ', Program: ${program['name']} (${program['dietType']})';
      } else {
        context = 'Program: ${program['name']} (${program['dietType']})';
      }
    }

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

  Future<String> getResponse(String prompt,
      {int maxTokens = 8000,
      String? role,
      bool includeDietContext = true,
      bool includeProgramContext = true}) async {
    // Initialize model if not already done
    if (_activeModel == null) {
      final initialized = await initializeModel();
      if (!initialized) {
        return 'Error: No suitable AI model available';
      }
    }

    // Get comprehensive user context (optionally exclude diet and program for planning mode)
    final aiContext = await _buildAIContext(
      includeDiet: includeDietContext,
      includeProgramContext: includeProgramContext,
    );

    // Add brevity instruction and context to the role/prompt
    final briefingInstruction =
        "Please provide brief, concise responses in 2-4 sentences maximum. ";
    final modifiedPrompt = role != null
        ? '$briefingInstruction\n${aiContext.isNotEmpty ? '$aiContext\n' : ''}$role\nUser: $prompt'
        : '$briefingInstruction\n${aiContext.isNotEmpty ? '$aiContext\n' : ''}User: $prompt';

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
            "maxOutputTokens":
                maxTokens, // Buddy chat - respects user's preference
          },
        },
        operation: 'get response',
      );

      if (response.containsKey('candidates') &&
          response['candidates'] is List &&
          response['candidates'].isNotEmpty) {
        final candidate = response['candidates'][0];

        if (candidate.containsKey('content') && candidate['content'] is Map) {
          final content = candidate['content'] as Map<String, dynamic>;
          final finishReason = candidate['finishReason'] as String?;

          if (content.containsKey('parts') &&
              content['parts'] is List &&
              (content['parts'] as List).isNotEmpty) {
            final parts = content['parts'] as List;
            final part = parts[0] as Map<String, dynamic>;

            if (part.containsKey('text')) {
              final text = part['text'] as String?;

              // Clean up any remaining newlines or extra spaces
              final cleanedText = (text ?? "I couldn't understand that.")
                  .trim()
                  .replaceAll(RegExp(r'\n+'), ' ')
                  .replaceAll(RegExp(r'\s+'), ' ');

              return cleanedText;
            } else {
              // Check if it's a MAX_TOKENS finish reason
              if (finishReason == 'MAX_TOKENS') {
                return 'Error: Response was cut off due to token limit. Please try rephrasing your question.';
              }
              return 'Error: No text content in API response';
            }
          } else {
            // Check if it's a MAX_TOKENS finish reason - this means we hit token limit
            if (finishReason == 'MAX_TOKENS') {
              return 'Error: Response was cut off due to token limit. Please try rephrasing your question.';
            }
            return 'Error: No content parts in API response';
          }
        } else {
          // Check finish reason even if no content
          final finishReason = candidate['finishReason'] as String?;
          if (finishReason == 'MAX_TOKENS') {
            return 'Error: Response was cut off due to token limit. Please try rephrasing your question.';
          }
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

    try {
      return jsonDecode(jsonStr);
    } catch (e) {
      // If parsing still fails, try to extract just the JSON part
      debugPrint(
          'Initial JSON parsing failed, attempting to extract valid JSON...');

      // Try to find the start and end of JSON content
      final jsonStart = jsonStr.indexOf('{');
      final jsonEnd = jsonStr.lastIndexOf('}');

      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
        final extractedJson = jsonStr.substring(jsonStart, jsonEnd + 1);
        debugPrint(
            'Extracted JSON: ${extractedJson.substring(0, extractedJson.length > 200 ? 200 : extractedJson.length)}...');

        // Clean the extracted JSON more aggressively
        final cleanedExtractedJson = _aggressiveJsonCleanup(extractedJson);

        try {
          return jsonDecode(cleanedExtractedJson);
        } catch (extractError) {
          debugPrint('Extracted JSON parsing also failed: $extractError');
          debugPrint(
              'Attempting to extract partial data from malformed JSON...');

          // Try to extract partial data even from malformed JSON
          final partialData =
              _extractPartialDataFromMalformedJson(extractedJson);
          if (partialData.isNotEmpty) {
            debugPrint('Successfully extracted partial data: $partialData');
            return partialData;
          }

          throw Exception(
              'Failed to parse JSON even after extraction: $extractError');
        }
      }

      // If all else fails, try to extract partial data
      debugPrint(
          'All JSON parsing methods failed. Attempting partial data extraction...');
      try {
        final partialData = _extractPartialDataFromMalformedJson(jsonStr);
        if (partialData.isNotEmpty) {
          debugPrint('Successfully extracted partial data from malformed JSON');
          return partialData;
        }
      } catch (partialError) {
        debugPrint('Partial data extraction also failed: $partialError');
      }

      throw Exception('Could not extract valid JSON from response: $e');
    }
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

    // Fix quoted numeric values that should be numbers (e.g., "calories": "200" -> "calories": 200)
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(
            r'"(calories|protein|carbs|fat|fiber|sugar|sodium)":\s*"(\d+(?:\.\d+)?)"',
            multiLine: true),
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

    // Fix any quoted numeric values that should be numbers (general case)
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"([^"]+)":\s*"(\d+(?:\.\d+)?)"(?=\s*[,}\]])', multiLine: true),
        (match) => '"${match.group(1)}": ${match.group(2)}');

    // Remove control characters (newlines, carriage returns, tabs) from JSON strings
    jsonStr = jsonStr.replaceAll(RegExp(r'[\r\n\t]'), ' ');

    // Clean up multiple spaces
    jsonStr = jsonStr.replaceAll(RegExp(r'\s+'), ' ');

    // Fix incomplete JSON by adding missing closing braces/brackets
    int openBraces = jsonStr.split('{').length - 1;
    int closeBraces = jsonStr.split('}').length - 1;
    int openBrackets = jsonStr.split('[').length - 1;
    int closeBrackets = jsonStr.split(']').length - 1;

    // Add missing closing braces/brackets
    while (closeBraces < openBraces) {
      jsonStr += '}';
      closeBraces++;
    }
    while (closeBrackets < openBrackets) {
      jsonStr += ']';
      closeBrackets++;
    }

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

    // Fix unterminated strings at the end of the JSON
    jsonStr = jsonStr.replaceAllMapped(RegExp(r'"([^"]*?)$', multiLine: true),
        (match) {
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

  /// Aggressively clean JSON that has severe formatting issues
  String _aggressiveJsonCleanup(String jsonStr) {
    // Remove all control characters and normalize whitespace
    jsonStr = jsonStr.replaceAll(RegExp(r'[\r\n\t\x00-\x1F\x7F]'), ' ');

    // Clean up multiple spaces
    jsonStr = jsonStr.replaceAll(RegExp(r'\s+'), ' ');

    // Fix broken string values that might have been split by newlines
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"([^"]*?)\s*,\s*"([^"]*?)"', multiLine: true),
        (match) => '"${match.group(1)} ${match.group(2)}"');

    // Fix broken array items that might have been split
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'}\s*,\s*{', multiLine: true), (match) => '},{');

    // Ensure proper comma placement
    jsonStr = jsonStr.replaceAll(RegExp(r',\s*}'), '}');
    jsonStr = jsonStr.replaceAll(RegExp(r',\s*]'), ']');

    return jsonStr.trim();
  }

  /// Extract partial data from malformed JSON using regex patterns
  Map<String, dynamic> _extractPartialDataFromMalformedJson(
      String malformedJson) {
    final Map<String, dynamic> extractedData = {};

    try {
      // Extract meal plan array
      final mealPlanMatches = RegExp(r'"title":\s*"([^"]+)"', multiLine: true)
          .allMatches(malformedJson);
      final mealTypeMatches =
          RegExp(r'"mealType":\s*"([^"]+)"', multiLine: true)
              .allMatches(malformedJson);
      final typeMatches = RegExp(r'"type":\s*"([^"]+)"', multiLine: true)
          .allMatches(malformedJson);
      final caloriesMatches =
          RegExp(r'"calories":\s*"?(\d+)"?', multiLine: true)
              .allMatches(malformedJson);

      // Extract ingredients using regex
      final ingredientsMatches =
          RegExp(r'"ingredients":\s*\{([^}]+)\}', multiLine: true)
              .allMatches(malformedJson);

      // Build meal plan from extracted data
      final List<Map<String, dynamic>> mealPlan = [];
      final int maxMeals = math.min(
          [mealPlanMatches.length, mealTypeMatches.length, typeMatches.length]
              .reduce(math.min),
          10 // Cap at 10 meals
          );

      for (int i = 0; i < maxMeals; i++) {
        final meal = <String, dynamic>{};

        if (i < mealPlanMatches.length) {
          meal['title'] =
              mealPlanMatches.elementAt(i).group(1) ?? 'Untitled Meal $i';
        }

        if (i < mealTypeMatches.length) {
          meal['mealType'] =
              mealTypeMatches.elementAt(i).group(1) ?? 'breakfast';
        }

        if (i < typeMatches.length) {
          meal['type'] = typeMatches.elementAt(i).group(1) ?? 'protein';
        }

        if (i < caloriesMatches.length) {
          meal['calories'] =
              int.tryParse(caloriesMatches.elementAt(i).group(1) ?? '0') ?? 0;
        } else {
          meal['calories'] = 0; // Default calories
        }

        // Extract ingredients for this meal if available
        if (i < ingredientsMatches.length) {
          final ingredientsText =
              ingredientsMatches.elementAt(i).group(1) ?? '';
          meal['ingredients'] =
              _extractIngredientsFromMalformedJson(ingredientsText);
        } else {
          meal['ingredients'] = {
            'ingredient': '1 serving'
          }; // Default ingredients
        }

        // Add nutritional info
        meal['nutritionalInfo'] = {
          'calories': meal['calories'],
          'protein': 0,
          'carbs': 0,
          'fat': 0,
        };

        mealPlan.add(meal);
      }

      // Extract distribution if available
      final Map<String, dynamic> distribution = {};
      final breakfastMatches = RegExp(r'"breakfast":\s*(\d+)', multiLine: true)
          .allMatches(malformedJson);
      final lunchMatches = RegExp(r'"lunch":\s*(\d+)', multiLine: true)
          .allMatches(malformedJson);
      final dinnerMatches = RegExp(r'"dinner":\s*(\d+)', multiLine: true)
          .allMatches(malformedJson);
      final snackMatches = RegExp(r'"snack":\s*(\d+)', multiLine: true)
          .allMatches(malformedJson);

      if (breakfastMatches.isNotEmpty)
        distribution['breakfast'] =
            int.tryParse(breakfastMatches.first.group(1) ?? '2') ?? 2;
      if (lunchMatches.isNotEmpty)
        distribution['lunch'] =
            int.tryParse(lunchMatches.first.group(1) ?? '3') ?? 3;
      if (dinnerMatches.isNotEmpty)
        distribution['dinner'] =
            int.tryParse(dinnerMatches.first.group(1) ?? '3') ?? 3;
      if (snackMatches.isNotEmpty)
        distribution['snack'] =
            int.tryParse(snackMatches.first.group(1) ?? '2') ?? 2;

      // If no distribution found, create default based on meal count
      if (distribution.isEmpty) {
        distribution['breakfast'] = 2;
        distribution['lunch'] = 3;
        distribution['dinner'] = 3;
        distribution['snack'] = 2;
      }

      extractedData['mealPlan'] = mealPlan;
      extractedData['distribution'] = distribution;

      debugPrint(
          'Successfully extracted ${mealPlan.length} meals from malformed JSON');
    } catch (e) {
      debugPrint('Error extracting partial data: $e');
    }

    // If no usable data was extracted, mark as complete failure
    if (extractedData.isEmpty ||
        (!extractedData.containsKey('mealPlan') &&
            !extractedData.containsKey('foodItems') &&
            !extractedData.containsKey('ingredients'))) {
      extractedData['source'] =
          true; // Mark as complete failure - no usable data
      extractedData['error'] =
          'No usable data could be extracted from malformed JSON';
    }

    return extractedData;
  }

  /// Extract ingredients from text using regex
  Map<String, dynamic> _extractIngredientsFromMalformedJson(
      String ingredientsText) {
    final Map<String, dynamic> ingredients = {};

    try {
      // Look for patterns like "ingredient": "amount" or "ingredient": amount
      final ingredientMatches =
          RegExp(r'"([^"]+)":\s*"?([^",}]+)"?', multiLine: true)
              .allMatches(ingredientsText);

      for (final match in ingredientMatches) {
        final ingredient = match.group(1)?.trim() ?? '';
        final amount = match.group(2)?.trim() ?? '1 serving';

        if (ingredient.isNotEmpty) {
          ingredients[ingredient] = amount;
        }
      }

      // If no structured ingredients found, try to extract individual ingredients
      if (ingredients.isEmpty) {
        final individualIngredients =
            RegExp(r'"([^"]+)"', multiLine: true).allMatches(ingredientsText);
        for (final match in individualIngredients) {
          final ingredient = match.group(1)?.trim() ?? '';
          if (ingredient.isNotEmpty && !ingredient.contains(':')) {
            ingredients[ingredient] = '1 serving';
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting ingredients: $e');
      ingredients['ingredient'] = '1 serving'; // Fallback
    }

    return ingredients;
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

  /// Generate meal titles, types, and basic ingredients based on user context and requirements
  Future<Map<String, dynamic>> generateMealTitlesAndIngredients(
    String prompt,
    String contextInformation, {
    int? mealCount,
    Map<String, int>? customDistribution,
    bool isIngredientBased = false,
  }) async {
    try {
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

      // Determine meal count and distribution based on request type
      final int targetMealCount = mealCount ?? (isIngredientBased ? 2 : 10);
      final Map<String, int> distribution = customDistribution ??
          (isIngredientBased
              ? {"breakfast": 0, "lunch": 1, "dinner": 1, "snack": 0}
              : {"breakfast": 2, "lunch": 3, "dinner": 3, "snack": 2});

      // Generate dynamic instructions based on request type
      final String dynamicInstructions = _generateDynamicInstructions(
          targetMealCount, distribution, isIngredientBased);

      // New explicit attempt order for client-side fallback:
      // 1) OpenAI (primary for client-side fallback)
      // 2) Gemini (secondary fallback)
      // 3) OpenAI (retry)
      // 4) Gemini (retry)

      Future<Map<String, dynamic>> parseGeminiStyleResponse(
          Map<String, dynamic> response) async {
        if (response['candidates'] == null || response['candidates'].isEmpty) {
          throw Exception('No response from AI model');
        }
        final candidate = response['candidates'][0];
        final content = candidate['content'];
        if (content == null ||
            content['parts'] == null ||
            content['parts'].isEmpty) {
          throw Exception('Invalid response structure from AI model');
        }
        final text = content['parts'][0]['text'];
        if (text == null || text.isEmpty) {
          throw Exception('Empty response from AI model');
        }
        debugPrint('[AI] Raw text length: ${text.length}');
        try {
          final snippet =
              text.length > 800 ? text.substring(0, 800) + '…' : text;
          debugPrint('[AI] Raw text preview: $snippet');
        } catch (e) {
          debugPrint('[AI] Error logging text preview: $e');
        }
        Map<String, dynamic> jsonResponse;
        try {
          jsonResponse = _extractJsonObject(text);
        } catch (parseError) {
          throw Exception('Invalid JSON response from AI: $parseError');
        }
        final mealPlan = jsonResponse['mealPlan'] as List<dynamic>? ?? [];
        final mealTitles =
            mealPlan.map((meal) => meal['title'] as String).toList();
        return {
          'mealTitles': mealTitles,
          'mealPlan': mealPlan,
          'distribution':
              jsonResponse['distribution'] as Map<String, dynamic>? ??
                  {'breakfast': 2, 'lunch': 2, 'dinner': 2, 'snack': 2}
        };
      }

      Map<String, dynamic> buildGeminiBody() => {
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

$dynamicInstructions
'''
                  }
                ]
              }
            ],
            "generationConfig": {
              "temperature": 0.7,
              "topK": 40,
              "topP": 0.95,
              "maxOutputTokens": 8000, // Increased for complex meal planning
            },
          };

      // Attempt 1: Gemini
      try {
        debugPrint('Attempt 1: Gemini (8192 tokens)');
        final resp = await _makeGeminiApiCall(
          endpoint: '${_activeModel}:generateContent',
          body: buildGeminiBody(),
          operation: 'generate meal titles and ingredients',
          retryCount: 0,
        );
        return await parseGeminiStyleResponse(resp);
      } catch (e) {
        debugPrint('Attempt 1 (Gemini) failed: $e');
      }

      // Attempt 2: OpenAI
      try {
        debugPrint('Attempt 2: OpenAI');
        final resp = await _makeOpenAIApiCall(
          endpoint: 'chat/completions',
          body: buildGeminiBody(),
          operation: 'generate meal titles and ingredients (OpenAI)',
          retryCount: 0,
        );
        return await parseGeminiStyleResponse(resp);
      } catch (e) {
        debugPrint('Attempt 2 (OpenAI) failed: $e');
      }

      // Attempt 3: Gemini
      try {
        debugPrint('Attempt 3: Gemini (3000 tokens)');
        final resp = await _makeGeminiApiCall(
          endpoint: '${_activeModel}:generateContent',
          body: buildGeminiBody(),
          operation: 'generate meal titles and ingredients (2nd)',
          retryCount: 0,
        );
        return await parseGeminiStyleResponse(resp);
      } catch (e) {
        debugPrint('Attempt 3 (Gemini) failed: $e');
      }

      // Attempt 4: OpenAI
      try {
        debugPrint('Attempt 4: OpenAI');
        final resp = await _makeOpenAIApiCall(
          endpoint: 'chat/completions',
          body: buildGeminiBody(),
          operation: 'generate meal titles and ingredients (OpenAI 2nd)',
          retryCount: 0,
        );
        return await parseGeminiStyleResponse(resp);
      } catch (e) {
        debugPrint('Attempt 4 (OpenAI) failed: $e');
      }

      // All attempts failed; do not try further
      return {
        'mealTitles': [],
        'mealPlan': [],
        'distribution': {},
        'source': 'failed',
        'message': 'AI service temporarily unavailable. Please try again.'
      };
    } catch (e) {
      debugPrint('generateMealTitlesAndIngredients failed with error: $e');
      return {
        'mealTitles': [],
        'mealPlan': [],
        'distribution': {},
        'source': 'failed',
        'message': 'AI service temporarily unavailable. Please try again.'
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

  /// Generate streamlined instructions (reduced token usage)
  String _generateDynamicInstructions(
      int mealCount, Map<String, int> distribution, bool isIngredientBased) {
    return '''
Generate $mealCount meals. Return JSON only:
{
  "mealPlan": [
    {
      "title": "meal name",
      "mealType": "breakfast|lunch|dinner|snack",
      "type": "protein|grain|vegetable|fruit"
    }
  ],
  "distribution": {
    "breakfast": ${distribution['breakfast']},
    "lunch": ${distribution['lunch']},
    "dinner": ${distribution['dinner']},
    "snack": ${distribution['snack']}
  }
}
''';
  }

  /// Generate meals using the new intelligent approach: titles first, then check existing,
  /// then save basic data for Firebase Functions processing
  Future<Map<String, dynamic>> generateMealsIntelligently(
      String prompt, String contextInformation, String cuisine,
      {int mealCount = 10, bool partOfWeeklyMeal = false, String weeklyPlanContext = ''}) async {
    try {
      // Try cloud function first for better performance
      try {
        debugPrint(
            '[Cloud Function] Attempting meal generation via cloud function');
        
        // Calculate distribution based on mealCount
        Map<String, int> distribution;
        if (mealCount == 1) {
          // Single meal - default to breakfast
          distribution = {'breakfast': 1, 'lunch': 0, 'dinner': 0, 'snack': 0};
        } else if (mealCount <= 3) {
          // Few meals - distribute evenly
          final perType = (mealCount / 3).ceil();
          distribution = {
            'breakfast': perType,
            'lunch': perType,
            'dinner': perType,
            'snack': 0
          };
        } else {
          // Default distribution for multiple meals
          distribution = {
            'breakfast': (mealCount * 0.2).round(),
            'lunch': (mealCount * 0.3).round(),
            'dinner': (mealCount * 0.3).round(),
            'snack': (mealCount * 0.2).round()
          };
          // Ensure total matches mealCount
          final total = distribution.values.reduce((a, b) => a + b);
          if (total != mealCount) {
            final diff = mealCount - total;
            distribution['lunch'] = (distribution['lunch'] ?? 0) + diff;
          }
        }
        
        final cloudResult = await _callCloudFunction(
          functionName: 'generateMealsWithAI',
          data: {
            'prompt': prompt,
            'context': contextInformation,
            'cuisine': cuisine,
            'mealCount': mealCount,
            'distribution': distribution,
            'isIngredientBased': false,
            'partOfWeeklyMeal': partOfWeeklyMeal,
            'weeklyPlanContext': weeklyPlanContext,
          },
          operation: 'generate meals intelligently',
        );

        // Convert cloud function response to expected format
        final meals = cloudResult['meals'] as List<dynamic>? ?? [];
        final mealPlan = meals; // Use meals as mealPlan for compatibility
        final responseDistribution =
            cloudResult['distribution'] as Map<String, dynamic>? ??
                {'breakfast': 2, 'lunch': 3, 'dinner': 3, 'snack': 2};

        // Extract meal titles for compatibility with existing logic
        final mealTitles =
            meals.map((meal) => meal['title'] as String).toList();

        debugPrint(
            '[Cloud Function] Successfully generated ${meals.length} meals via cloud function');
        debugPrint(
            '[Cloud Function] New meals: ${cloudResult['newMealCount'] ?? 0}');
        debugPrint(
            '[Cloud Function] Existing meals: ${cloudResult['existingMealCount'] ?? 0}');

        return {
          'meals': meals,
          'mealPlan': mealPlan,
          'mealTitles': mealTitles,
          'distribution': responseDistribution,
          'source': 'cloud_function',
          'executionTime': cloudResult['executionTime'],
          'mealCount': meals.length,
          'newMealCount': cloudResult['newMealCount'] ?? 0,
          'existingMealCount': cloudResult['existingMealCount'] ?? 0,
          'mealIds': cloudResult['mealIds'] ?? [], // Include new meal IDs
          'existingMealIds':
              cloudResult['existingMealIds'] ?? [], // Include existing meal IDs
        };
      } catch (cloudError) {
        debugPrint(
            '[Cloud Function] Meal generation failed, falling back to client-side: $cloudError');
        // Fall through to existing client-side logic
      }

      // Step 1: Generate meal titles, types, and basic ingredients (fallback)
      // Calculate distribution based on mealCount for fallback
      Map<String, int> fallbackDistribution;
      if (mealCount == 1) {
        fallbackDistribution = {'breakfast': 1, 'lunch': 0, 'dinner': 0, 'snack': 0};
      } else if (mealCount <= 3) {
        final perType = (mealCount / 3).ceil();
        fallbackDistribution = {
          'breakfast': perType,
          'lunch': perType,
          'dinner': perType,
          'snack': 0
        };
      } else {
        fallbackDistribution = {
          'breakfast': (mealCount * 0.2).round(),
          'lunch': (mealCount * 0.3).round(),
          'dinner': (mealCount * 0.3).round(),
          'snack': (mealCount * 0.2).round()
        };
        final total = fallbackDistribution.values.reduce((a, b) => a + b);
        if (total != mealCount) {
          final diff = mealCount - total;
          fallbackDistribution['lunch'] = (fallbackDistribution['lunch'] ?? 0) + diff;
        }
      }
      
      final mealData = await generateMealTitlesAndIngredients(
        prompt,
        contextInformation,
        mealCount: mealCount,
        customDistribution: fallbackDistribution,
      );
      final mealTitles = List<String>.from(
          (mealData['mealTitles'] as List?) ?? const <String>[]);
      debugPrint('Generated meal titles: ${mealTitles}');
      final mealPlan = mealData['mealPlan'] as List<dynamic>;

      if (mealTitles.isEmpty) {
        throw Exception('Failed to generate meal titles');
      }

      // Step 2: Check which titles already exist in database
      final existingMeals = await checkExistingMealsByTitles(mealTitles);
      debugPrint('Found ${existingMeals.length} existing meals');

      // Step 3: Identify missing meals with their meal types and basic ingredients
      final missingMeals = <Map<String, dynamic>>[];
      for (final meal in mealPlan) {
        final title = meal['title'] as String;
        final mealType = meal['mealType'] as String;
        final calories = _parseCalories(meal['calories']);
        final type = meal['type'] as String;

        // Debug logging to see what's in the meal data
        debugPrint('Processing meal: $title');
        debugPrint('Meal data keys: ${meal.keys.toList()}');
        debugPrint('Meal data: $meal');

        // Check for ingredients in multiple possible field names
        Map<String, dynamic> basicIngredients = {};
        if (meal['ingredients'] != null) {
          basicIngredients = meal['ingredients'] as Map<String, dynamic>;
        } else if (meal['basicIngredients'] != null) {
          // Handle case where AI returns basicIngredients instead of ingredients
          final basicList = meal['basicIngredients'] as List<dynamic>?;
          if (basicList != null) {
            // Convert list to map with default amounts
            for (final ingredient in basicList) {
              basicIngredients[ingredient.toString()] = '1 serving';
            }
          }
        }

        debugPrint('Extracted ingredients: $basicIngredients');

        if (!existingMeals.containsKey(title)) {
          missingMeals.add({
            'title': title,
            'mealType': mealType,
            'calories': calories,
            'type': type,
            'ingredients': basicIngredients,
            'nutritionalInfo': meal['nutritionalInfo'] ?? {},
          });
        }
      }

      debugPrint('Need to generate ${missingMeals.length} new meals');
      debugPrint('Missing meals: $missingMeals');

      // Step 4: Save basic meals to Firestore with 'pending' status for Firebase Functions processing
      Map<String, dynamic> saveResult = {};
      if (missingMeals.isNotEmpty) {
        saveResult = await saveBasicMealsToFirestore(missingMeals, cuisine,
            partOfWeeklyMeal: partOfWeeklyMeal,
            weeklyPlanContext: weeklyPlanContext);
        debugPrint(
            'Saved ${missingMeals.length} basic meals to Firestore with pending status');
      }

      // Step 5: Return minimal payload for immediate UI use
      final minimalMeals = <Map<String, dynamic>>[];
      final collectedMealIds = <String>[];

      for (final meal in mealPlan) {
        final title = meal['title'] as String;
        final mealType = meal['mealType'] as String;
        String? id;
        String status = 'pending';

        if (existingMeals.containsKey(title)) {
          id = existingMeals[title]!.mealId;
          status = 'completed';
        } else {
          final mealIds = (saveResult['mealIds'] as Map<String, String>?);
          id = mealIds != null ? mealIds[title] : null;
        }

        if (id != null && id.isNotEmpty) {
          minimalMeals.add({
            'id': id,
            'title': title,
            'mealType': mealType,
            'status': status,
          });
          collectedMealIds.add(id);
        }
      }

      if (minimalMeals.isEmpty) {
        return {
          'meals': [],
          'source': 'failed',
          'message': 'Failed to generate meals. Please try again.',
          'error': true
        };
      }

      return {
        'meals': minimalMeals,
        'mealIds': collectedMealIds,
        'source': 'mixed',
        'count': minimalMeals.length,
        'message':
            'Generated ${missingMeals.length} new meals and found ${existingMeals.length} existing meals. Details will be populated asynchronously by Firebase Functions.',
        'existingCount': existingMeals.length,
        'newCount': missingMeals.length,
        'pendingCount': missingMeals.length,
        'firebaseProcessing': {
          'active': missingMeals.isNotEmpty,
          'total': missingMeals.length,
          'pending': missingMeals.length,
          'completed': 0,
          'failed': 0,
        },
      };
    } catch (e) {
      debugPrint('Error in generateMealsIntelligently: $e');
      // Return error response instead of falling back to generateMealPlan
      // which has a different data structure
      return {
        'meals': [],
        'source': 'failed',
        'count': 0,
        'message': 'Failed to generate meals. Please try again.',
        'error': true,
        'existingCount': 0,
        'newCount': 0,
        'pendingCount': 0,
        'nutritionalSummary': {
          'totalCalories': 0,
          'totalProtein': 0,
          'totalCarbs': 0,
          'totalFat': 0,
        },
        'firebaseProcessing': {
          'active': false,
          'total': 0,
          'pending': 0,
          'completed': 0,
          'failed': 0,
        },
      };
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

    // Get comprehensive user context - removed aiContext as it's not used in the new approach
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
      // Determine if this is an ingredient-based request
      final ingredients = _extractIngredientsFromPrompt(prompt);
      final isIngredientBased = ingredients.isNotEmpty;

      // Use generateMealTitlesAndIngredients for better JSON reliability
      final mealData = await generateMealTitlesAndIngredients(
        prompt,
        contextInformation,
        isIngredientBased: isIngredientBased,
        mealCount:
            isIngredientBased ? 2 : 8, // 2 for ingredients, 8 for meal plans
        customDistribution: isIngredientBased
            ? {"breakfast": 0, "lunch": 1, "dinner": 1, "snack": 0}
            : {"breakfast": 2, "lunch": 2, "dinner": 2, "snack": 2},
      );

      final mealPlan = mealData['mealPlan'] as List<dynamic>? ?? [];

      if (mealPlan.isEmpty) {
        throw Exception('No meals generated from AI');
      }

      // Convert to the expected format for meal plan
      final formattedMeals = mealPlan.map((meal) {
        final mealMap = Map<String, dynamic>.from(meal);

        // Add required fields for compatibility
        mealMap['id'] = ''; // Will be set when saved to database
        mealMap['source'] = 'ai_generated';
        mealMap['cookingTime'] = mealMap['cookingTime'] ?? '';
        mealMap['cookingMethod'] = mealMap['cookingMethod'] ?? '';
        mealMap['instructions'] = mealMap['instructions'] ?? [''];
        mealMap['diet'] = mealMap['diet'] ?? 'balanced';
        mealMap['categories'] = mealMap['categories'] ?? [];
        mealMap['serveQty'] = mealMap['serveQty'] ?? 1;

        return mealMap;
      }).toList();

      return {
        'meals': formattedMeals,
        'source': 'ai_generated',
        'count': formattedMeals.length,
        'message': 'AI-generated meal plan using improved method',
        'nutritionalSummary': 0,
        'tips': [
          'Adjust portions according to your dietary needs',
          'Prep ingredients in advance for easier cooking'
        ],
      };
    } catch (e) {
      debugPrint('generateMealPlan failed with error: $e');
      // Return fallback meals if AI fails
      return await _getFallbackMeals(prompt);
    }
  }

  /// Safe integer parsing helper that handles both int and String values
  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is double) return value.toInt();
    return null;
  }

  /// Calculate nutritional summary from a list of meals
  Map<String, dynamic> calculateNutritionalSummary(List<dynamic> meals) {
    int totalCalories = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;

    if (meals.isNotEmpty && meals.first is Map) {
      final Map<String, dynamic> firstMeal = meals.first;
      if (firstMeal.containsKey('groupedMeals')) {
        final Map<String, List<dynamic>> groupedMeals =
            firstMeal['groupedMeals'];

        for (final mealType in groupedMeals.keys) {
          final mealsList = groupedMeals[mealType] ?? [];
          for (final meal in mealsList) {
            // Access the meal property safely
            dynamic mealData;
            try {
              mealData = meal.meal;
            } catch (e) {
              debugPrint('Error accessing meal.meal: $e');
              continue;
            }

            if (mealData == null) {
              debugPrint('Meal data is null, skipping');
              continue;
            }

            // Access nutritional info safely
            Map<String, dynamic> nutritionalInfo = {};
            try {
              nutritionalInfo = mealData.nutritionalInfo ?? {};
            } catch (e) {
              debugPrint('Error accessing nutritionalInfo: $e');
              continue;
            }

            // Safe type conversion - handle both int and String values
            totalCalories += _safeParseInt(nutritionalInfo['calories']) ?? 0;
            totalProtein += _safeParseInt(nutritionalInfo['protein']) ?? 0;
            totalCarbs += _safeParseInt(nutritionalInfo['carbs']) ?? 0;
            totalFat += _safeParseInt(nutritionalInfo['fat']) ?? 0;
          }
        }
      }
    }

    return {
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
    };
  }

  /// Analyze fridge image to identify raw ingredients and suggest meals
  Future<Map<String, dynamic>> analyzeFridgeImage({
    required File imageFile,
    String? dietaryRestrictions,
  }) async {
    try {
      // Try cloud function first for better performance
      debugPrint(
          '[Cloud Function] Attempting fridge image analysis via cloud function');

      // Read and encode image for cloud function
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final cloudResult = await _callCloudFunction(
        functionName: 'analyzeFridgeImage',
        data: {
          'base64Image': base64Image,
          'dietaryRestrictions':
              dietaryRestrictions != null ? [dietaryRestrictions] : [],
        },
        operation: 'analyze fridge image',
      );

      debugPrint(
          '[Cloud Function] Successfully analyzed fridge image via cloud function');

      return {
        'ingredients': cloudResult['ingredients'],
        'suggestedMeals': cloudResult['suggestedMeals'],
        'source': 'cloud_function',
        'executionTime': cloudResult['executionTime'],
        'ingredientCount': cloudResult['ingredientCount'],
        'mealIds': cloudResult['mealIds'] ?? [], // Include meal IDs
      };
    } catch (cloudError) {
      debugPrint(
          '[Cloud Function] Fridge image analysis failed, falling back to client-side: $cloudError');
      // Fall through to existing client-side logic
    }

    // Fallback to client-side analysis
    // Initialize model if not already done
    if (_activeModel == null) {
      final initialized = await initializeModel();
      if (!initialized) {
        throw Exception('No suitable AI model available');
      }
    }

    // Ensure we start with Gemini for image analysis
    if (_currentProvider != AIProvider.gemini) {
      debugPrint('Starting fridge image analysis with Gemini provider');
      _currentProvider = AIProvider.gemini;
    }

    try {
      // Read and encode the image
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Get comprehensive user context
      final aiContext = await _buildAIContext();

      String contextualPrompt =
          'Analyze this fridge image to identify raw ingredients that can be used for cooking.';

      if (dietaryRestrictions != null && dietaryRestrictions.isNotEmpty) {
        contextualPrompt +=
            ' Consider dietary restrictions: $dietaryRestrictions.';
      }

      final prompt = '''
$aiContext

$contextualPrompt

Identify all visible raw ingredients in this fridge that can be used for cooking.

CRITICAL: Return ONLY raw JSON data. Do not wrap in ```json``` or ``` code blocks. Do not add any markdown formatting. Return pure JSON only with the following structure:

{
  "ingredients": [
    {
      "name": "ingredient name",
      "category": "vegetable|protein|dairy|grain|fruit|herb|spice|other",
    }
  ],
  "suggestedMeals": [
    {
      "title": "meal name",
      "cookingTime": "30 minutes",
      "difficulty": "easy|medium|hard",
      "calories": 0,
    }
  ]
}

Important guidelines:
- Return valid, complete JSON only. Do not include markdown or code blocks.
- Focus on ingredients that can be used for cooking main meals.
- Provide 2 diverse (1 medium and 1 hard) meal suggestions using the identified ingredients.
- All nutritional values must be numbers (not strings).
- Category must be one of the following: vegetable|protein|dairy|grain|fruit|herb|spice|other
''';

      // Use Gemini's image analysis
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
            "temperature": 0.2,
            "topK": 20,
            "topP": 0.8,
            "maxOutputTokens":
                8192, // Fridge analysis - complex with multiple ingredients + meal suggestions
          },
        },
        operation: 'analyze fridge image',
      );

      if (response.containsKey('candidates') &&
          response['candidates'] is List &&
          response['candidates'].isNotEmpty) {
        final candidate = response['candidates'][0];

        if (candidate.containsKey('content') && candidate['content'] is Map) {
          final content = candidate['content'] as Map<String, dynamic>;
          final parts = content['parts'] as List<dynamic>?;

          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;

            if (text != null && text.isNotEmpty) {
              try {
                final result = _processAIResponse(text, 'fridge_analysis');
                return result;
              } catch (e) {
                throw Exception('Failed to parse fridge analysis JSON: $e');
              }
            } else {
              throw Exception('No text content in Gemini response');
            }
          } else {
            throw Exception('No parts in Gemini response content');
          }
        } else {
          throw Exception('No content in Gemini response candidate');
        }
      } else {
        throw Exception('No candidates in Gemini response');
      }
    } catch (e) {
      debugPrint('analyzeFridgeImage failed with error: $e');
      // Show snackbar to user
      Get.snackbar(
        'Image Analysis Failed',
        'Please try again later',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
      throw Exception('Failed to analyze fridge image: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeFoodImageWithContext({
    required File imageFile,
    String? mealType,
    String? dietaryRestrictions,
    String? additionalContext,
  }) async {
    debugPrint('=== Starting analyzeFoodImageWithContext ===');

    try {
      // Try cloud function first for better performance
      debugPrint(
          '[Cloud Function] Attempting food image analysis via cloud function');

      // Read and encode image for cloud function
      Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final cloudResult = await _callCloudFunction(
        functionName: 'analyzeFoodImage',
        data: {
          'base64Image': base64Image,
          'mealType': mealType,
          'dietaryRestrictions':
              dietaryRestrictions != null ? [dietaryRestrictions] : [],
        },
        operation: 'analyze food image',
      );

      debugPrint(
          '[Cloud Function] Successfully analyzed food image via cloud function');

      return {
        'foodItems': cloudResult['foodItems'],
        'totalNutrition': cloudResult['totalNutrition'],
        'ingredients': cloudResult['ingredients'],
        'confidence': cloudResult['confidence'],
        'suggestions': cloudResult['suggestions'],
        'source': 'cloud_function',
        'executionTime': cloudResult['executionTime'],
        'itemCount': cloudResult['itemCount'],
        'mealIds': cloudResult['mealIds'] ?? [], // Include meal IDs
      };
    } catch (cloudError) {
      debugPrint(
          '[Cloud Function] Food image analysis failed, falling back to client-side: $cloudError');
      // Fall through to existing client-side logic
    }

    // Fallback to client-side analysis
    debugPrint('Active model: $_activeModel');
    debugPrint('Current provider: ${_currentProvider.name}');
    debugPrint('Gemini healthy: $_isGeminiHealthy');
    debugPrint('OpenRouter healthy: $_isOpenRouterHealthy');

    // Initialize model if not already done
    if (_activeModel == null) {
      debugPrint('No active model, initializing...');
      final initialized = await initializeModel();
      if (!initialized) {
        debugPrint('Model initialization failed!');
        throw Exception(
            'No suitable AI model available - check API keys and provider health');
      }
      debugPrint('Model initialized successfully: $_activeModel');
    }

    // Ensure we start with Gemini for image analysis (retry logic will handle fallback if needed)
    if (_currentProvider != AIProvider.gemini) {
      debugPrint('Starting image analysis with Gemini provider');
      _currentProvider = AIProvider.gemini;
    }

    try {
      debugPrint('Reading image file...');

      // Compress image before sending to API for faster upload
      Uint8List imageBytes = await imageFile.readAsBytes();
      debugPrint(
          'Original image size: ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(2)} KB)');

      // If image is large, compress it to speed up analysis
      if (imageBytes.length > 500 * 1024) {
        // > 500KB
        debugPrint('Compressing large image for faster API call...');
        final img.Image? image = img.decodeImage(imageBytes);

        if (image != null) {
          // Resize to max 1024px on longest side
          final img.Image resized = image.width > image.height
              ? img.copyResize(image, width: 1024)
              : img.copyResize(image, height: 1024);

          // Compress with quality 85
          imageBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
          debugPrint(
              'Compressed image size: ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(2)} KB)');
        }
      }

      final String base64Image = base64Encode(imageBytes);

      // Build minimal context for image analysis (not the full AI context to save tokens)
      String contextualPrompt =
          'Analyze this food and provide nutritional info.';

      if (mealType != null) {
        contextualPrompt += ' Type: $mealType.';
      }

      if (dietaryRestrictions != null && dietaryRestrictions.isNotEmpty) {
        contextualPrompt += ' Diet: $dietaryRestrictions.';
      }

      final prompt = '''
$contextualPrompt

Return ONLY this JSON structure (no markdown, no explanations):

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
  "ingredients": {
        "ingredient1": "amount with unit (e.g., '1 cup', '200g')",
        "ingredient2": "amount with unit"
    },
  "confidence": "high|medium|low",
  "suggestions": {
    "improvements": ["suggestion1", "suggestion2", ...],
    "alternatives": ["alternative1", "alternative2", ...],
    "additions": ["addition1", "addition2", ...]
  },
  "healthScore": 5
}

Rules: JSON only, numbers for nutrition, keep brief, max 3 suggestions each.''';

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
              "maxOutputTokens":
                  8192, // Food analysis - increased for complex analysis
            },
          },
          operation: 'analyze food image',
        );

        if (response.containsKey('candidates') &&
            response['candidates'] is List &&
            response['candidates'].isNotEmpty) {
          final candidate = response['candidates'][0];

          // Check for safety/blocked content
          if (candidate.containsKey('finishReason')) {
            final finishReason = candidate['finishReason'];
            debugPrint('API finish reason: $finishReason');

            if (finishReason == 'SAFETY' || finishReason == 'RECITATION') {
              debugPrint('⚠️ Content blocked by safety filters');
              debugPrint('Full response: $response');
              throw Exception(
                  'Content blocked by safety filters. Try a different image or angle.');
            }

            if (finishReason == 'MAX_TOKENS') {
              debugPrint('⚠️ Response hit token limit - prompt was too long');
              debugPrint('Full response: $response');
              // Retry with increased token limit (6000)
              return await _makeApiCallWithRetry(
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
                    "temperature": 0.1,
                    "topK": 20,
                    "topP": 0.8,
                    "maxOutputTokens": 8192, // Increased token limit
                  },
                },
                operation: 'analyze food image (retry with 6000 tokens)',
              );
            }
          }

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
                debugPrint('❌ No text in part. Part content: $part');
                throw Exception('No text content in API response');
              }
            } else {
              debugPrint('❌ No parts in content. Content: $content');
              debugPrint('Full candidate: $candidate');
              throw Exception(
                  'No content parts in API response. Possible safety block or empty response.');
            }
          } else {
            debugPrint('❌ No content in candidate. Candidate: $candidate');
            throw Exception('No content in API response');
          }
        } else {
          debugPrint('❌ No candidates. Response: $response');
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
            "max_tokens":
                6000, // Food analysis (OpenRouter) - increased for complex analysis
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
      debugPrint('=== Food image analysis error ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      // Show snackbar to user
      Get.snackbar(
        'Food Analysis Failed',
        'Please try again later',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
      throw Exception('Failed to analyze food image: $e');
    }
  }

  Future<Map<String, dynamic>> generateMealsFromIngredients(
      List<dynamic> displayedItems,
      BuildContext parentContext,
      bool isDineIn) async {
    try {
      showLoadingDialog(parentContext, loadingText: loadingTextSearchMeals);

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
      hideLoadingDialog(parentContext);

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
        showLoadingDialog(parentContext, loadingText: loadingTextGenerateMeals);

        // Generate meals directly using generateMealTitlesAndIngredients
        // (no need to check existing meals again since we already did that)
        final mealData = await generateMealTitlesAndIngredients(
          'Generate 2 meals using these ingredients: ${ingredientNames.join(', ')}',
          'Stay within the ingredients provided',
          isIngredientBased: true,
          mealCount: 2,
          customDistribution: {
            "breakfast": 0,
            "lunch": 1,
            "dinner": 1,
            "snack": 0
          },
        );

        final mealList = mealData['mealPlan'] as List<dynamic>? ?? [];
        if (mealList.isEmpty) throw Exception('No meals generated');

        // Convert to expected format and add missing fields
        final formattedMeals = mealList.map((meal) {
          final mealMap = Map<String, dynamic>.from(meal);
          mealMap['id'] = ''; // Will be set when saved to database
          mealMap['source'] = 'ai_generated';
          mealMap['cookingTime'] = mealMap['cookingTime'] ?? '';
          mealMap['cookingMethod'] = mealMap['cookingMethod'] ?? '';
          mealMap['instructions'] = mealMap['instructions'] ??
              ['Prepare according to your preference'];
          mealMap['diet'] = mealMap['diet'] ?? 'balanced';
          mealMap['categories'] = mealMap['categories'] ?? [];
          mealMap['serveQty'] = mealMap['serveQty'] ?? 1;
          return mealMap;
        }).toList();

        // Note: formattedMeals already contains the processed meal data

        // Save basic AI-generated meals to Firestore for Firebase Functions processing
        debugPrint(
            'Saving ${formattedMeals.length} basic meals to Firestore...');
        final saveResult = await saveBasicMealsToFirestore(
          formattedMeals,
          'ingredient_based', // cuisine/category
        );
        final mealIds = saveResult['mealIds'] as Map<String, String>;
        debugPrint('Saved meals with IDs: $mealIds');

        // Update the meals with their Firestore IDs
        final mealsWithIds = <Map<String, dynamic>>[];
        for (final meal in formattedMeals) {
          final title = meal['title'] as String;
          final mealId = mealIds[title];

          if (mealId != null) {
            final mealWithId = Map<String, dynamic>.from(meal);
            mealWithId['id'] = mealId; // Add the Firestore ID
            mealsWithIds.add(mealWithId);
          }
        }

        // Hide loading dialog
        hideLoadingDialog(parentContext);

        if (mealsWithIds.isEmpty) throw Exception('No meals generated');

        mealsToShow = mealsWithIds;
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
          int showMoreClickCount =
              0; // Track how many times "Show More" was clicked
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
                  showMoreClickCount++; // Increment the counter
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
                          ? 'Select a Tasty AI Meal'
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
                      print('meal: $meal');
                      print('mealType: ${meal['mealType']}');

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
                          subtitle: meal['mealType'] != null
                              ? Text(
                                  'Great as your ${meal['mealType']}!',
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
                  // Show three options after 3 "Show More" clicks
                  if (source == 'existing_database' &&
                      allExistingMeals.isNotEmpty &&
                      showMoreClickCount >= 3) ...[
                    // Generate with AI button
                    TextButton(
                      onPressed: (isProcessing || isGeneratingAI)
                          ? null
                          : () async {
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
                                final mealData =
                                    await generateMealTitlesAndIngredients(
                                  'Generate 2 meals using these ingredients: ${ingredientNames.join(', ')}',
                                  contextWithExistingMeals,
                                  isIngredientBased: true,
                                  mealCount: 2,
                                  customDistribution: {
                                    "breakfast": 0,
                                    "lunch": 1,
                                    "dinner": 1,
                                    "snack": 0
                                  },
                                );

                                // Convert to expected format
                                final mealList =
                                    mealData['mealPlan'] as List<dynamic>? ??
                                        [];
                                final formattedMeals = mealList.map((meal) {
                                  final mealMap =
                                      Map<String, dynamic>.from(meal);
                                  mealMap['id'] = '';
                                  mealMap['source'] = 'ai_generated';
                                  mealMap['cookingTime'] =
                                      mealMap['cookingTime'] ?? '30 minutes';
                                  mealMap['cookingMethod'] =
                                      mealMap['cookingMethod'] ?? 'other';
                                  mealMap['instructions'] =
                                      mealMap['instructions'] ??
                                          [
                                            'Prepare according to your preference'
                                          ];
                                  mealMap['diet'] =
                                      mealMap['diet'] ?? 'balanced';
                                  mealMap['categories'] =
                                      mealMap['categories'] ?? [];
                                  mealMap['serveQty'] =
                                      mealMap['serveQty'] ?? 1;
                                  return mealMap;
                                }).toList();

                                final mealPlan = {
                                  'meals': formattedMeals,
                                  'source': 'ai_generated',
                                  'count': formattedMeals.length,
                                  'message':
                                      'AI-generated meals using improved method',
                                };

                                debugPrint(
                                    'AI generation successful: ${(mealPlan['meals'] as List?)?.length ?? 0} meals generated');

                                final generatedMeals =
                                    mealPlan['meals'] as List<dynamic>? ?? [];
                                debugPrint(
                                    'Generated meals count: ${generatedMeals.length}');
                                if (generatedMeals.isEmpty) {
                                  debugPrint(
                                      'No meals generated - throwing exception');
                                  throw Exception('No meals generated');
                                }

                                // Save basic AI-generated meals to Firestore for Firebase Functions processing
                                debugPrint(
                                    'Saving ${generatedMeals.length} basic meals to Firestore...');
                                final saveResult =
                                    await saveBasicMealsToFirestore(
                                  generatedMeals.cast<Map<String, dynamic>>(),
                                  'ingredient_based', // cuisine/category
                                );
                                final mealIds = saveResult['mealIds']
                                    as Map<String, String>;
                                debugPrint('Saved meals with IDs: $mealIds');

                                // Update the meals with their new IDs for selection
                                final mealsWithIds = <Map<String, dynamic>>[];
                                for (final meal in generatedMeals) {
                                  final mealMap =
                                      Map<String, dynamic>.from(meal);
                                  final title = mealMap['title'] as String;
                                  final mealId = mealIds[title];

                                  if (mealId != null) {
                                    mealMap['id'] =
                                        mealId; // Add the Firestore ID
                                    mealsWithIds.add(mealMap);
                                  }
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
                                  showTastySnackbar(
                                    'Error',
                                    'Failed to generate AI meals. Please try again.',
                                    context,
                                    backgroundColor: kRed,
                                  );
                                }
                              }
                            },
                      child: Text(
                        isGeneratingAI ? 'Generating...' : 'Use Tasty AI',
                        style: textTheme.bodyLarge?.copyWith(
                          color: (isProcessing || isGeneratingAI)
                              ? kLightGrey
                              : kAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Continue showing more button
                    TextButton(
                      onPressed: (isProcessing || isGeneratingAI)
                          ? null
                          : () {
                              refreshMealList();
                            },
                      child: Text(
                        'Show More',
                        style: textTheme.bodyLarge?.copyWith(
                          color: (isProcessing || isGeneratingAI)
                              ? kLightGrey
                              : kAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Cancel button
                    TextButton(
                      onPressed: isProcessing
                          ? null
                          : () => Navigator.of(context).pop(),
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
                  ]
                  // Show normal options for first 3 "Show More" clicks
                  else if (source == 'existing_database' &&
                      allExistingMeals.isNotEmpty) ...[
                    // Check if we're on the last page of existing meals
                    // If currentIndex + mealsPerPage >= total meals, we're showing the final set
                    if (currentIndex + mealsPerPage >= allExistingMeals.length)
                      TextButton(
                        onPressed: (isProcessing || isGeneratingAI)
                            ? null
                            : () async {
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
                                  final mealData =
                                      await generateMealTitlesAndIngredients(
                                    'Generate 2 meals using these ingredients: ${ingredientNames.join(', ')}',
                                    contextWithExistingMeals,
                                    isIngredientBased: true,
                                    mealCount: 2,
                                    customDistribution: {
                                      "breakfast": 0,
                                      "lunch": 1,
                                      "dinner": 1,
                                      "snack": 0
                                    },
                                  );

                                  // Convert to expected format
                                  final mealList =
                                      mealData['mealPlan'] as List<dynamic>? ??
                                          [];
                                  final formattedMeals = mealList.map((meal) {
                                    final mealMap =
                                        Map<String, dynamic>.from(meal);
                                    mealMap['id'] = '';
                                    mealMap['source'] = 'ai_generated';
                                    mealMap['cookingTime'] =
                                        mealMap['cookingTime'] ?? '30 minutes';
                                    mealMap['cookingMethod'] =
                                        mealMap['cookingMethod'] ?? 'other';
                                    mealMap['instructions'] =
                                        mealMap['instructions'] ??
                                            [
                                              'Prepare according to your preference'
                                            ];
                                    mealMap['diet'] =
                                        mealMap['diet'] ?? 'balanced';
                                    mealMap['categories'] =
                                        mealMap['categories'] ?? [];
                                    mealMap['serveQty'] =
                                        mealMap['serveQty'] ?? 1;
                                    return mealMap;
                                  }).toList();

                                  final mealPlan = {
                                    'meals': formattedMeals,
                                    'source': 'ai_generated',
                                    'count': formattedMeals.length,
                                    'message':
                                        'AI-generated meals using improved method',
                                  };

                                  debugPrint(
                                      'AI generation successful: ${(mealPlan['meals'] as List?)?.length ?? 0} meals generated');

                                  final generatedMeals =
                                      mealPlan['meals'] as List<dynamic>? ?? [];
                                  debugPrint(
                                      'Generated meals count: ${generatedMeals.length}');
                                  if (generatedMeals.isEmpty) {
                                    debugPrint(
                                        'No meals generated - throwing exception');
                                    throw Exception('No meals generated');
                                  }

                                  // Save basic AI-generated meals to Firestore for Firebase Functions processing
                                  debugPrint(
                                      'Saving ${generatedMeals.length} basic meals to Firestore...');
                                  final saveResult =
                                      await saveBasicMealsToFirestore(
                                    generatedMeals.cast<Map<String, dynamic>>(),
                                    'ingredient_based', // cuisine/category
                                  );
                                  final mealIds = saveResult['mealIds']
                                      as Map<String, String>;
                                  debugPrint('Saved meals with IDs: $mealIds');

                                  // Update the meals with their new IDs for selection
                                  final mealsWithIds = <Map<String, dynamic>>[];
                                  for (final meal in generatedMeals) {
                                    final mealMap =
                                        Map<String, dynamic>.from(meal);
                                    final title = mealMap['title'] as String;
                                    final mealId = mealIds[title];

                                    if (mealId != null) {
                                      mealMap['id'] =
                                          mealId; // Add the Firestore ID
                                      mealsWithIds.add(mealMap);
                                    }
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
                                    showTastySnackbar(
                                      'Error',
                                      'Failed to generate AI meals. Please try again.',
                                      context,
                                      backgroundColor: kRed,
                                    );
                                  }
                                }
                              },
                        child: Text(
                          isGeneratingAI ? 'Generating...' : 'Use Tasty AI',
                          style: textTheme.bodyLarge?.copyWith(
                            color: (isProcessing || isGeneratingAI)
                                ? kLightGrey
                                : kAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: (isProcessing || isGeneratingAI)
                            ? null
                            : () async {
                                // Show more existing meals
                                refreshMealList();
                              },
                        child: Text(
                          'Show More',
                          style: textTheme.bodyLarge?.copyWith(
                            color: (isProcessing || isGeneratingAI)
                                ? kLightGrey
                                : kAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    // Cancel button for normal flow
                    TextButton(
                      onPressed: isProcessing
                          ? null
                          : () => Navigator.of(context).pop(),
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
                  ]
                  // Fallback cancel button for other states
                  else ...[
                    TextButton(
                      onPressed: isProcessing
                          ? null
                          : () => Navigator.of(context).pop(),
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
        instructions: [],
        categories: ['ai-analyzed', mealType.toLowerCase()],
        category: 'ai-analyzed',
        suggestions: analysisResult['suggestions'],
      );

      // Create the meal JSON and add processing metadata
      final mealData = meal.toJson();
      mealData['status'] = 'pending';
      mealData['createdAt'] = FieldValue.serverTimestamp();
      mealData['type'] = mealType;
      mealData['source'] = 'ai_generated';
      mealData['version'] = 'basic';
      mealData['processingAttempts'] = 0;
      mealData['lastProcessingAttempt'] = null;
      mealData['processingPriority'] = DateTime.now().millisecondsSinceEpoch;
      mealData['needsProcessing'] = true;

      await docRef.set(mealData);
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
      final normalizedName = normalizeIngredientName(ingredientName);

      // First try exact match
      try {
        var snapshot = await firestore
            .collection('ingredients')
            .where('title', isEqualTo: ingredientName.toLowerCase())
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          if (data.isNotEmpty) {
            return IngredientData.fromJson(data);
          }
        }
      } catch (e) {
        debugPrint('Error in exact ingredient match query: $e');
      }

      // Try normalized name match
      try {
        var snapshot = await firestore
            .collection('ingredients')
            .where('title', isEqualTo: normalizedName)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          if (data.isNotEmpty) {
            return IngredientData.fromJson(data);
          }
        }
      } catch (e) {
        debugPrint('Error in normalized ingredient match query: $e');
      }

      // Try normalized matching (remove spaces, hyphens, underscores)
      final normalizedInputName = normalizeIngredientName(ingredientName);

      // Get all ingredients and check for normalized matches
      // Limit ingredient query to prevent fetching all ingredients
      // Use a reasonable limit - most ingredient lookups should be by specific name
      try {
        final allIngredientsSnapshot =
            await firestore.collection('ingredients').limit(1000).get();

        if (allIngredientsSnapshot.docs.isEmpty) {
          debugPrint('No ingredients found in database');
          return null;
        }

        for (final doc in allIngredientsSnapshot.docs) {
          try {
            final ingredientData = doc.data();
            if (ingredientData.isEmpty) continue;

            final dbTitle = ingredientData['title'] as String? ?? '';
            if (dbTitle.isEmpty) continue;

            final normalizedDbTitle = normalizeIngredientName(dbTitle);

            if (normalizedInputName == normalizedDbTitle) {
              return IngredientData.fromJson(ingredientData);
            }
          } catch (e) {
            debugPrint('Error processing ingredient document ${doc.id}: $e');
            // Continue to next document
          }
        }
      } catch (e) {
        debugPrint('Error fetching all ingredients for normalized match: $e');
        return null;
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

  /// Save basic meals to Firestore with minimal data for Firebase Functions processing
  Future<Map<String, dynamic>> saveBasicMealsToFirestore(
      List<Map<String, dynamic>> newMeals, String cuisine,
      {bool partOfWeeklyMeal = false, String weeklyPlanContext = ''}) async {
    try {
      final userId = userService.userId ?? '';
      if (userId.isEmpty) {
        throw Exception('User ID not available');
      }

      final mealIds = <String, String>{};
      final batch = firestore.batch();

      for (final meal in newMeals) {
        final mealRef = firestore.collection('meals').doc();
        final mealId = mealRef.id;

        // Create basic meal document with status 'pending' for Firebase Functions processing
        final basicMealData = {
          'title': meal['title'],
          'mealType': meal['mealType'],
          'calories': meal['calories'],
          'categories': [cuisine],
          'nutritionalInfo': {},
          'ingredients': {},
          'status': 'pending', // Firebase Functions will process this
          'createdAt': FieldValue.serverTimestamp(),
          'type': meal['type'],
          'userId': tastyId,
          'source': 'ai_generated',
          'version': 'basic',
          'processingAttempts': 0, // Track retry attempts
          'lastProcessingAttempt': null, // Timestamp of last attempt
          'processingPriority':
              DateTime.now().millisecondsSinceEpoch, // FIFO processing
          'needsProcessing': true, // Flag for Firebase Functions
          'partOfWeeklyMeal':
              partOfWeeklyMeal, // Flag for weekly meal plan context
          'weeklyPlanContext':
              weeklyPlanContext, // Context about the weekly meal plan
        };

        // Debug logging to check ingredients and calories
        debugPrint('Saving meal: ${meal['title']}');
        debugPrint('Calories: ${meal['calories']}');
        debugPrint('Ingredients: ${meal['ingredients']}');
        debugPrint('Basic meal data: $basicMealData');

        batch.set(mealRef, basicMealData);
        mealIds[meal['title']] = mealId;
      }

      // Commit all meals in a single batch
      try {
        await batch.commit();
        debugPrint(
            'Saved ${newMeals.length} basic meals to Firestore with pending status');
      } catch (e) {
        debugPrint('Error committing meal batch to Firestore: $e');
        rethrow;
      }
      debugPrint(
          'Saved ${newMeals.length} basic meals to Firestore with pending status');

      // Create a map of meal titles to their ingredients
      final mealIngredientsMap = <String, Map<String, dynamic>>{};
      for (final meal in newMeals) {
        final title = meal['title'] as String;
        mealIngredientsMap[title] = meal['ingredients'] as Map<String, dynamic>;
      }

      return {
        'mealIds': mealIds,
        'ingredients': mealIngredientsMap,
      };
    } catch (e) {
      debugPrint('Error saving basic meals to Firestore: $e');
      rethrow;
    }
  }
}

// Global instance for easy access throughout the app
final geminiService = GeminiService.instance;
