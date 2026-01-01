import 'package:flutter/material.dart' show debugPrint;
import 'package:cloud_functions/cloud_functions.dart';

/// Enum to track which AI provider is being used
enum AIProvider { gemini, openai, openrouter }

/// Base service for AI provider management and API calls
///
/// Handles:
/// - Provider selection and health tracking
/// - API calls to Gemini, OpenAI, and OpenRouter
/// - Retry logic and fallback
/// - Cloud function integration
/// - Error handling
class AIProviderService {
  static final AIProviderService _instance = AIProviderService._internal();
  factory AIProviderService() => _instance;
  AIProviderService._internal();

  static AIProviderService get instance => _instance;

  String? _activeModel;
  AIProvider _currentProvider = AIProvider.gemini;

  // Error handling
  static const int _maxRetries = 3;

  /// Initialize the AI model
  /// NOTE: This method is deprecated. AI initialization is handled server-side via cloud functions.
  Future<bool> initializeModel() async {
    // API keys are no longer available client-side
    // AI operations are handled via cloud functions
    debugPrint('AI initialization is handled server-side via cloud functions');
    return false; // Return false to indicate client-side initialization is not available
  }

  /// Make API call with retry and fallback
  Future<Map<String, dynamic>> makeApiCall({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
    bool useFallback = true,
  }) async {
    // Try current provider first
    try {
      return await _makeApiCallToCurrentProvider(
        endpoint: endpoint,
        body: body,
        operation: operation,
        retryCount: retryCount,
      );
    } catch (e) {
      // Fallback logic
      if (useFallback && retryCount < _maxRetries) {
        if (_currentProvider == AIProvider.gemini) {
          // Try OpenRouter
          try {
            _currentProvider = AIProvider.openrouter;
            return await _makeApiCallToCurrentProvider(
              endpoint: endpoint,
              body: body,
              operation: operation,
              retryCount: 0,
            );
          } catch (_) {
            // Fallback failed, rethrow original
          }
        }
      }
      rethrow;
    }
  }

  /// Make API call to current provider
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

  /// Make API call to Gemini
  /// NOTE: Direct API calls are deprecated. All AI operations should use cloud functions.
  /// This method will throw an error to force migration to cloud functions.
  Future<Map<String, dynamic>> _makeGeminiApiCall({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
  }) async {
    // API keys are no longer available client-side for security
    // All AI operations must go through cloud functions
    debugPrint('Direct API call attempted for operation: $operation');
    throw Exception('AI service temporarily unavailable. Please try again.');
  }

  /// Make API call to OpenAI
  /// NOTE: Direct API calls are deprecated. All AI operations should use cloud functions.
  /// This method will throw an error to force migration to cloud functions.
  Future<Map<String, dynamic>> _makeOpenAIApiCall({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
  }) async {
    // API keys are no longer available client-side for security
    // All AI operations must go through cloud functions
    debugPrint('Direct API call attempted for operation: $operation');
    throw Exception('AI service temporarily unavailable. Please try again.');
  }

  /// Make API call to OpenRouter
  /// NOTE: Direct API calls are deprecated. All AI operations should use cloud functions.
  /// This method will throw an error to force migration to cloud functions.
  Future<Map<String, dynamic>> _makeOpenRouterApiCall({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
  }) async {
    // API keys are no longer available client-side for security
    // All AI operations must go through cloud functions
    debugPrint('Direct API call attempted for operation: $operation');
    throw Exception('AI service temporarily unavailable. Please try again.');
  }

  /// Call cloud function
  Future<Map<String, dynamic>> callCloudFunction({
    required String functionName,
    required Map<String, dynamic> data,
    required String operation,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(functionName);
      final result = await callable(data).timeout(const Duration(seconds: 90));

      if (result.data is Map<String, dynamic>) {
        final response = result.data as Map<String, dynamic>;
        if (response['success'] == true) {
          return response;
        } else {
          throw Exception('Cloud function error: ${response['error']}');
        }
      }
      throw Exception('Invalid response format');
    } catch (e) {
      debugPrint('Cloud function failed: $e');
      rethrow;
    }
  }

  /// Get active model name
  String? get activeModel => _activeModel;

  /// Get current provider
  AIProvider get currentProvider => _currentProvider;

  /// Set current provider
  void setProvider(AIProvider provider) {
    _currentProvider = provider;
  }
}
