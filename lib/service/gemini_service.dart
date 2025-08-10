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
    try {
      final jsonData = _extractJsonObject(text);

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
      print('Error processing AI response for $operation: $e');
      print('Raw response text: $text');

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
          'healthScore': 5,
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
            "stopSequences": [
              "\n\n"
            ] // Stop at double newline to prevent lengthy responses
          },
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['candidates'][0]['content']['parts'][0]['text'];
        // Clean up any remaining newlines or extra spaces
        final cleanedText = (text ?? "I couldn't understand that.")
            .trim()
            .replaceAll(RegExp(r'\n+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ');
        return cleanedText;
      } else {
        print('AI API Error: ${response.body}');
        _activeModel = null;
        return 'Error: ${response.statusCode}';
      }
    } catch (e) {
      print('AI API Exception: $e');
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
    // Fix trailing quotes after numeric values (e.g., "serveQty": 1" -> "serveQty": 1)
    final beforeFix = jsonStr;
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'":\s*(\d+)"(?=\s*[,}\]])', multiLine: true),
        (match) => '": ${match.group(1)}');

    if (beforeFix != jsonStr) {
      print('Fixed trailing quotes in JSON');
    }

    // Fix any remaining trailing quotes after numbers (more comprehensive)
    jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'"([^"]+)":\s*(\d+)"(?=\s*[,}\]])', multiLine: true),
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

  Future<Map<String, dynamic>> generateMealPlan(String prompt) async {
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

    final contextualPrompt =
        'Generate a detailed meal plan based on the following requirements: $prompt';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/${_activeModel}:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text": '''
You are a professional nutritionist and meal planner.

$aiContext

$contextualPrompt

Generate a 7-day meal plan that is:

Balanced and diverse

Aligned with the specified diet type

Includes at least 2 meal options per meal type (breakfast, lunch, dinner, snack) per day

Designed with real-world cooking practicality and variety

Return ONLY a raw JSON object (no markdown, no code blocks) with the following structure:
{
  "meals": [
    {
      "title": "Dish name",
      "type": "protein|grain|vegetable",
      "mealType": "breakfast | lunch | dinner | snack",
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

Important: 
- Return ONLY the JSON object. Do not include any markdown formatting, explanations, or code block markers.
- Ensure all measurements are in metric units and nutritional values are per serving.
- Format ingredients as key-value pairs where the key is the ingredient name and the value is the amount with unit (e.g., "rice": "1 cup", "chicken breast": "200g")
- Diet type is the diet type of the meal plan (e.g., "keto", "vegan", "paleo", "gluten-free", "dairy-free" "quick prep",).
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
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['candidates'][0]['content']['parts'][0]['text'];
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
      } else {
        print('AI API Error: ${response.body}');
        _activeModel = null;
        throw Exception('Failed to generate meal plan: ${response.statusCode}');
      }
    } catch (e) {
      print('AI API Exception: $e');
      _activeModel = null;
      throw Exception('Failed to generate meal plan: $e');
    }
  }

  Future<Map<String, dynamic>> generateMealFromIngredients(
      String prompt) async {
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

    final checkPromptCount = prompt.split(',').length;
    final promptCount = checkPromptCount > 2 ? checkPromptCount : 'only 2';

    final contextualPrompt = familyMode
        ? 'For a family, generate 2 healthy meal recipes using 2 or more of these ingredients: $prompt'
        : 'Generate 2 healthy meal recipes using $promptCount of these ingredients: $prompt';

    final mealPrompt = '''
    $aiContext
    
    $contextualPrompt

    Return ONLY a raw JSON object (no markdown, no code blocks) with the following structure:
    {
      "meals": [
        {
          "title": "Dish name",
          "type": "protein|grain|vegetable", 
          "description": "describe the dish",
          "cookingTime": "10 minutes",
          "cookingMethod": "frying, boiling, baking, etc.",
          "ingredients": {
            "ingredient1": "amount with unit (e.g., '1 cup', '200g')",
            "ingredient2": "amount with unit"
          },
          "instructions": ["step1", "step2", ...],
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
    ''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/${_activeModel}:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": mealPrompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 2048,
          },
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['candidates'][0]['content']['parts'][0]['text'];
        try {
          final parsed = _processAIResponse(text, 'meal_generation');
          return _normalizeMealPlanData(parsed);
        } catch (e) {
          print('Raw response text: $text');
          try {
            final sanitized = _sanitizeJsonString(text);
            final reparsed = jsonDecode(sanitized) as Map<String, dynamic>;
            return _normalizeMealPlanData(reparsed);
          } catch (_) {
            throw Exception('Failed to parse meal JSON: $e');
          }
        }
      } else {
        print('AI API Error: ${response.body}');
        _activeModel = null;
        throw Exception('Failed to generate meal: ${response.statusCode}');
      }
    } catch (e) {
      print('AI API Exception: $e');
      _activeModel = null;
      throw Exception('Failed to generate meal: $e');
    }
  }

  Future<Map<String, dynamic>> generateCustomProgram(
      Map<String, dynamic> userAnswers,
      String programType,
      String dietPreference,
      {String? additionalContext}) async {
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

    // Get basic user context (but don't include existing program since we're creating a new one)
    final userContext = await _getUserContext();

    final basicContext = '''
USER CONTEXT:
- Family Mode: ${userContext['familyMode'] ? 'Yes (generate family-friendly portions and options)' : 'No (individual portions)'}
- Current Diet Preference: ${userContext['dietPreference']}
''';

    final prompt = '''
$basicContext

Generate a personalized fitness and nutrition program based on the following information:
Program Type: $programType
Program Context: $additionalContext
Diet Preference: $dietPreference
User Answers: ${jsonEncode(userAnswers)}

Return ONLY a raw JSON object (no markdown, no code blocks) with the following structure:
{
  "duration": "4 weeks",
  "weeklyPlans": [
    {
      "week": 1,
      "goals": ["goal1", "goal2"],
      "mealPlan": {
        "breakfast": ["meal suggestion 1", "meal suggestion 2"],
        "lunch": ["meal suggestion 1", "meal suggestion 2"],
        "dinner": ["meal suggestion 1", "meal suggestion 2"],
        "snacks": ["snack 1", "snack 2"]
      },
      "nutritionGuidelines": {
        "calories": "target range",
        "protein": "target range",
        "carbs": "target range",
        "fats": "target range"
      },
      "tips": ["tip1", "tip2"]
    }
  ],
  "requirements": ["requirement1", "requirement2"],
  "recommendations": ["recommendation1", "recommendation2"]
}
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
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 2048,
          },
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['candidates'][0]['content']['parts'][0]['text'];
        try {
          return _processAIResponse(text, 'program_generation');
        } catch (e) {
          print('Raw response text: $text');
          throw Exception('Failed to parse program JSON: $e');
        }
      } else {
        print('AI API Error: ${response.body}');
        _activeModel = null;
        throw Exception('Failed to generate program: ${response.statusCode}');
      }
    } catch (e) {
      print('AI API Exception: $e');
      _activeModel = null;
      throw Exception('Failed to generate program: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeFoodImage(File imageFile) async {
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

      final prompt = '''
$aiContext

Analyze this food image and provide detailed nutritional information. Identify all visible food items, estimate portion sizes, and calculate nutritional values.

Return ONLY a raw JSON object (no markdown, no code blocks) with the following structure:
{
  "foodItems": [
    {
      "name": "food item name",
      "estimatedWeight": "weight in grams",
      "confidence": "high|medium|low",
      "nutritionalInfo": {
        "calories": number,
        "protein": number,
        "carbs": number,
        "fat": number,
        "fiber": number,
        "sugar": number,
        "sodium": number
      }
    }
  ],
  "totalNutrition": {
    "calories": number,
    "protein": number,
    "carbs": number,
    "fat": number,
    "fiber": number,
    "sugar": number,
    "sodium": number
  },
  "mealType": "breakfast|lunch|dinner|snack",
  "estimatedPortionSize": "small|medium|large",
  "ingredients": {
        "ingredient1": "amount with unit (e.g., '1 cup', '200g')",
        "ingredient2": "amount with unit"
    },
  "cookingMethod": "raw|grilled|fried|baked|boiled|steamed|other",
  "confidence": "high|medium|low",
  "notes": "any additional observations about the food"
}

Important guidelines:
- Be as accurate as possible with portion size estimation
- Include confidence levels for your analysis
- If you can't identify something clearly, mark it as low confidence
- Provide realistic nutritional values based on standard food databases
- Consider cooking methods that might affect nutritional content
- All nutritional values should be numbers (not strings)
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
            "temperature":
                0.3, // Lower temperature for more consistent analysis
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 2048,
          },
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['candidates'][0]['content']['parts'][0]['text'];
        try {
          return _processAIResponse(text, 'tasty_analysis');
        } catch (e) {
          print('Raw response text: $text');
          throw Exception('Failed to parse food analysis JSON: $e');
        }
      } else {
        print('AI API Error: ${response.body}');
        _activeModel = null;
        throw Exception('Failed to analyze food image: ${response.statusCode}');
      }
    } catch (e) {
      print('AI API Exception: $e');
      _activeModel = null;
      throw Exception('Failed to analyze food image: $e');
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

Return ONLY a raw JSON object (no markdown, no code blocks) with the following structure:
{
  "foodItems": [
    {
      "name": "food item name",
      "estimatedWeight": "weight in grams",
      "confidence": "high|medium|low",
      "nutritionalInfo": {
        "calories": number,
        "protein": number,
        "carbs": number,
        "fat": number,
        "fiber": number,
        "sugar": number,
        "sodium": number
      }
    }
  ],
  "totalNutrition": {
    "calories": number,
    "protein": number,
    "carbs": number,
    "fat": number,
    "fiber": number,
    "sugar": number,
    "sodium": number
  },
  "mealType": "breakfast|lunch|dinner|snack",
  "estimatedPortionSize": "small|medium|large",
  "ingredients": {
        "ingredient1": "amount with unit (e.g., '1 cup', '200g')",
        "ingredient2": "amount with unit"
    },
  "cookingMethod": "raw|grilled|fried|baked|boiled|steamed|other",
  "confidence": "high|medium|low",
  "healthScore": number (1-10),
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
  "notes": "any additional observations about the food"
}

Important guidelines:
- Be as accurate as possible with portion size estimation
- Include confidence levels for your analysis
- Provide realistic nutritional values based on standard food databases
- Consider cooking methods that might affect nutritional content
- Give helpful suggestions for meal improvement
- All nutritional values should be numbers (not strings)
- Health score should reflect overall nutritional quality (1=poor, 10=excellent)
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
            "temperature":
                0.3, // Lower temperature for more consistent analysis
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 2048,
          },
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['candidates'][0]['content']['parts'][0]['text'];
        try {
          return _processAIResponse(text, 'tasty_analysis');
        } catch (e) {
          print('Raw response text: $text');
          throw Exception('Failed to parse food analysis JSON: $e');
        }
      } else {
        print('AI API Error: ${response.body}');
        _activeModel = null;
        throw Exception('Failed to analyze food image: ${response.statusCode}');
      }
    } catch (e) {
      print('AI API Exception: $e');
      _activeModel = null;
      throw Exception('Failed to analyze food image: $e');
    }
  }

  Future<Map<String, dynamic>> compareFood({
    required File imageFile1,
    required File imageFile2,
    String? comparisonContext,
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
      // Read and encode both images
      final Uint8List imageBytes1 = await imageFile1.readAsBytes();
      final Uint8List imageBytes2 = await imageFile2.readAsBytes();
      final String base64Image1 = base64Encode(imageBytes1);
      final String base64Image2 = base64Encode(imageBytes2);

      // Get comprehensive user context
      final aiContext = await _buildAIContext();

      String prompt =
          'Compare these two food images and provide a detailed nutritional comparison.';

      if (comparisonContext != null && comparisonContext.isNotEmpty) {
        prompt += ' Context: $comparisonContext';
      }

      prompt += '''

$aiContext

Return ONLY a raw JSON object (no markdown, no code blocks) with the following structure:
{
  "image1Analysis": {
    "foodItems": ["item1", "item2", ...],
    "totalNutrition": {
      "calories": number,
      "protein": number,
      "carbs": number,
      "fat": number
    },
    "healthScore": number (1-10)
  },
  "image2Analysis": {
    "foodItems": ["item1", "item2", ...],
    "totalNutrition": {
      "calories": number,
      "protein": number,
      "carbs": number,
      "fat": number
    },
    "healthScore": number (1-10)
  },
  "comparison": {
    "winner": "image1|image2|tie",
    "reasons": ["reason1", "reason2", ...],
    "nutritionalDifferences": {
      "calories": "difference description",
      "protein": "difference description",
      "carbs": "difference description",
      "fat": "difference description"
    }
  },
  "recommendations": ["recommendation1", "recommendation2", ...],
  "summary": "brief comparison summary"
}
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
                    "data": base64Image1
                  }
                },
                {
                  "inline_data": {
                    "mime_type": "image/jpeg",
                    "data": base64Image2
                  }
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.3,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 2048,
          },
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = decoded['candidates'][0]['content']['parts'][0]['text'];
        try {
          return _processAIResponse(text, 'food_comparison');
        } catch (e) {
          print('Raw response text: $text');
          throw Exception('Failed to parse food comparison JSON: $e');
        }
      } else {
        print('AI API Error: ${response.body}');
        _activeModel = null;
        throw Exception(
            'Failed to compare food images: ${response.statusCode}');
      }
    } catch (e) {
      print('AI API Exception: $e');
      _activeModel = null;
      throw Exception('Failed to compare food images: $e');
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
      final mealPlan = await generateMealFromIngredients(
        displayedItems.map((item) => item.title).join(', '),
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

                      String cookingTime = meal['cookingTime'] ?? '';
                      String cookingMethod = meal['cookingMethod'] ?? '';

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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cookingTime.isNotEmpty)
                                Text(
                                  'Cooking Time: $cookingTime',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey,
                                  ),
                                ),
                              if (cookingMethod.isNotEmpty)
                                Text(
                                  'Method: $cookingMethod',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey,
                                  ),
                                ),
                            ],
                          ),
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

Return ONLY a raw JSON object (no markdown, no code blocks) with the following structure:
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
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 2048,
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

  /// Save 54321 shopping list to Firestore
  Future<void> save54321ShoppingList({
    required Map<String, dynamic> shoppingList,
    required String userId,
  }) async {
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
    await save54321ShoppingList(
      shoppingList: shoppingList,
      userId: userId,
    );

    return shoppingList;
  }
}

// Global instance for easy access throughout the app
final geminiService = GeminiService.instance;
