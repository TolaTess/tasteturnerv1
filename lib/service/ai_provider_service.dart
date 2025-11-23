import 'dart:convert';
import 'package:flutter/material.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  // API Configuration
  final String _geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1';
  final String _openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  final String _openAIBaseUrl = 'https://api.openai.com/v1';
  
  String? _activeModel;
  AIProvider _currentProvider = AIProvider.gemini;
  bool _useOpenRouterFallback = true;

  // OpenRouter configuration
  static final Map<String, String> _openRouterModels = {
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

  String _preferredOpenRouterModel = 'gemini-2.0-flash';

  // OpenAI configuration
  String _preferredOpenAIModel = 'gpt-4o';

  // Error handling
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _backoffMultiplier = Duration(seconds: 1);

  // Health tracking
  static bool _isGeminiHealthy = true;
  static bool _isOpenRouterHealthy = true;
  static bool _isOpenAIHealthy = true;
  static DateTime? _lastGeminiError;
  static DateTime? _lastOpenRouterError;
  static DateTime? _lastOpenAIError;
  static int _consecutiveGeminiErrors = 0;
  static int _consecutiveOpenRouterErrors = 0;
  static int _consecutiveOpenAIErrors = 0;
  static const int _maxConsecutiveErrors = 5;
  static const Duration _apiRecoveryTime = Duration(minutes: 10);

  /// Initialize the AI model
  Future<bool> initializeModel() async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('Gemini API key not configured');
        return false;
      }

      // Try to get available models
      final response = await http.get(
        Uri.parse('$_geminiBaseUrl/models?key=$apiKey'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List?;
        
        if (models != null && models.isNotEmpty) {
          // Prefer newer models
          final preferredModels = [
            'gemini-2.5-flash',
            'gemini-2.0-flash-exp',
            'gemini-2.0-flash',
            'gemini-1.5-flash',
          ];

          for (final preferred in preferredModels) {
            final found = models.firstWhere(
              (m) => m['name']?.toString().contains(preferred) ?? false,
              orElse: () => null,
            );
            if (found != null) {
              _activeModel = found['name'].toString().split('/').last;
              debugPrint('Initialized model: $_activeModel');
              return true;
            }
          }

          // Fallback to first available model
          _activeModel = models.first['name'].toString().split('/').last;
          debugPrint('Using fallback model: $_activeModel');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error initializing model: $e');
      return false;
    }
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

    if (!_isGeminiHealthy) {
      throw Exception('Gemini API temporarily unavailable');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_geminiBaseUrl/$endpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        _consecutiveGeminiErrors = 0;
        _isGeminiHealthy = true;
        return jsonDecode(response.body);
      } else {
        _handleGeminiError('HTTP ${response.statusCode}');
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      _handleGeminiError(e.toString());
      rethrow;
    }
  }

  /// Make API call to OpenAI
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

    if (!_isOpenAIHealthy) {
      throw Exception('OpenAI API temporarily unavailable');
    }

    try {
      // Convert Gemini format to OpenAI format
      final openAIBody = _convertToOpenAIFormat(body);
      final url = '$_openAIBaseUrl/chat/completions';

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(openAIBody),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        _consecutiveOpenAIErrors = 0;
        _isOpenAIHealthy = true;
        final decodedRaw = jsonDecode(response.body);
        if (decodedRaw is! Map<String, dynamic>) {
          throw Exception('Invalid response format from OpenAI API');
        }
        final decoded = decodedRaw as Map<String, dynamic>;
        // Convert OpenAI format to Gemini format for consistency
        return _convertFromOpenAIFormat(decoded);
      } else {
        _handleOpenAIError('HTTP ${response.statusCode}');
        throw Exception('OpenAI API error: ${response.statusCode}');
      }
    } catch (e) {
      _handleOpenAIError(e.toString());
      rethrow;
    }
  }

  /// Convert Gemini format to OpenAI format
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
      debugPrint('Error extracting text from Gemini format: $e');
    }

    // Get generation config
    final generationConfigRaw = geminiBody['generationConfig'];
    final generationConfig = (generationConfigRaw is Map<String, dynamic>)
        ? generationConfigRaw
        : <String, dynamic>{};
    
    final maxTokens = (generationConfig['maxOutputTokens'] as int?) ?? 4000;
    final temperature = (generationConfig['temperature'] as num?)?.toDouble() ?? 0.7;

    // Convert to OpenAI format
    return {
      'model': _preferredOpenAIModel,
      'messages': [
        {
          'role': 'user',
          'content': text,
        }
      ],
      'max_tokens': maxTokens,
      'temperature': temperature,
    };
  }

  /// Convert OpenAI format to Gemini format
  Map<String, dynamic> _convertFromOpenAIFormat(Map<String, dynamic> openaiResponse) {
    final choicesRaw = openaiResponse['choices'];
    final choices = (choicesRaw is List<dynamic>) ? choicesRaw : <dynamic>[];
    if (choices.isEmpty) {
      throw Exception('No choices in OpenAI response');
    }
    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) {
      throw Exception('Invalid choice format in OpenAI response');
    }
    final messageRaw = firstChoice['message'];
    final message = (messageRaw is Map<String, dynamic>) ? messageRaw : null;
    
    if (message == null) {
      throw Exception('No message in OpenAI response');
    }

    final contentRaw = message['content'];
    final content = (contentRaw is String) ? contentRaw : '';

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

  /// Handle OpenAI errors
  void _handleOpenAIError(String error) {
    _consecutiveOpenAIErrors++;
    _lastOpenAIError = DateTime.now();
    if (_consecutiveOpenAIErrors >= _maxConsecutiveErrors) {
      _isOpenAIHealthy = false;
      debugPrint('OpenAI marked as unhealthy after $_consecutiveOpenAIErrors consecutive errors');
    }
    debugPrint('OpenAI error: $error');
  }

  /// Make API call to OpenRouter
  Future<Map<String, dynamic>> _makeOpenRouterApiCall({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
    int retryCount = 0,
  }) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenRouter API key not configured');
    }

    if (!_isOpenRouterHealthy) {
      throw Exception('OpenRouter API temporarily unavailable');
    }

    try {
      // Convert to OpenRouter format
      final openRouterBody = _convertToOpenRouterFormat(body);
      final url = '$_openRouterBaseUrl/chat/completions';

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer': 'https://tasteturner.app',
              'X-Title': 'TasteTurner',
            },
            body: jsonEncode(openRouterBody),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        _consecutiveOpenRouterErrors = 0;
        _isOpenRouterHealthy = true;
        final decoded = jsonDecode(response.body);
        return _convertFromOpenRouterFormat(decoded);
      } else {
        _handleOpenRouterError('HTTP ${response.statusCode}');
        throw Exception('OpenRouter API error: ${response.statusCode}');
      }
    } catch (e) {
      _handleOpenRouterError(e.toString());
      rethrow;
    }
  }

  /// Convert Gemini format to OpenRouter format
  Map<String, dynamic> _convertToOpenRouterFormat(Map<String, dynamic> body) {
    // Implementation for format conversion
    return {
      'model': _openRouterModels[_preferredOpenRouterModel] ?? 'google/gemini-2.0-flash',
      'messages': [
        {
          'role': 'user',
          'content': body['contents']?[0]?['parts']?[0]?['text'] ?? '',
        }
      ],
    };
  }

  /// Convert OpenRouter format to Gemini format
  Map<String, dynamic> _convertFromOpenRouterFormat(Map<String, dynamic> response) {
    // Convert OpenRouter response to Gemini format
    if (response.containsKey('choices') && response['choices'] is List) {
      final choice = response['choices'][0];
      final message = choice['message'];
      return {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': message['content']}
              ]
            }
          }
        ]
      };
    }
    return response;
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

  /// Handle Gemini errors
  void _handleGeminiError(String error) {
    _consecutiveGeminiErrors++;
    _lastGeminiError = DateTime.now();
    if (_consecutiveGeminiErrors >= _maxConsecutiveErrors) {
      _isGeminiHealthy = false;
    }
  }

  /// Handle OpenRouter errors
  void _handleOpenRouterError(String error) {
    _consecutiveOpenRouterErrors++;
    _lastOpenRouterError = DateTime.now();
    if (_consecutiveOpenRouterErrors >= _maxConsecutiveErrors) {
      _isOpenRouterHealthy = false;
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

