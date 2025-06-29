import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';

class GeminiService {
  final String _baseUrl = 'https://generativelanguage.googleapis.com/v1';
  String? _activeModel; // Cache the working model name and full path
  bool familyMode = userService.currentUser.value?.familyMode ?? false;

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

    // Add brevity instruction to the role/prompt
    final briefingInstruction =
        "Please provide brief, concise responses in 2-4 sentences maximum. ";
    final modifiedPrompt = role != null
        ? '$briefingInstruction\n$role\nUser: $prompt'
        : '$briefingInstruction\nUser: $prompt';

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

    return jsonDecode(jsonStr);
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

    if (familyMode) {
      prompt =
          'For a family, generate a detailed meal plan based on the following requirements: $prompt';
    } else {
      prompt =
          'Generate a detailed meal plan based on the following requirements: $prompt';
    }

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
You are a professional nutritionist and meal planner. $prompt

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
          return _extractJsonObject(text);
        } catch (e) {
          print('Raw response text: $text');
          throw Exception('Failed to parse meal plan JSON: $e');
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

    if (familyMode) {
      prompt =
          'For a family, generate 2 healthy meal recipes using 2 or more of these ingredients: $prompt';
    } else {
      prompt =
          'Generate 2 healthy meal recipes using 2 or more of these ingredients: $prompt';
    }

    final mealPrompt = '''
    $prompt

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
          return _extractJsonObject(text);
        } catch (e) {
          print('Raw response text: $text');
          throw Exception('Failed to parse meal JSON: $e');
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

    final prompt = '''
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
          return _extractJsonObject(text);
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

      final prompt = '''
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
  "ingredients": ["ingredient1", "ingredient2", ...],
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
          return _extractJsonObject(text);
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
  "ingredients": ["ingredient1", "ingredient2", ...],
  "cookingMethod": "raw|grilled|fried|baked|boiled|steamed|other",
  "confidence": "high|medium|low",
  "healthScore": number (1-10),
  "suggestions": {
    "improvements": ["suggestion1", "suggestion2", ...],
    "alternatives": ["alternative1", "alternative2", ...],
    "additions": ["addition1", "addition2", ...]
  },
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
          return _extractJsonObject(text);
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

      String prompt =
          'Compare these two food images and provide a detailed nutritional comparison.';

      if (comparisonContext != null && comparisonContext.isNotEmpty) {
        prompt += ' Context: $comparisonContext';
      }

      prompt += '''

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
          return _extractJsonObject(text);
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

  /// Save food analysis to tastyanalysis collection
  Future<void> saveAnalysisToFirestore({
    required Map<String, dynamic> analysisResult,
    required String userId,
    required String imagePath,
  }) async {
    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
          .collection(date)
          .doc(userId)
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
  }) async {
    try {
      final docRef = firestore.collection('meals').doc();
      final mealId = docRef.id;

      final totalNutrition =
          analysisResult['totalNutrition'] as Map<String, dynamic>;
      final foodItems = analysisResult['foodItems'] as List<dynamic>;
      final ingredients =
          List<String>.from(analysisResult['ingredients'] ?? []);

      // Create ingredients map from detected ingredients
      final ingredientsMap = <String, String>{};
      for (int i = 0; i < ingredients.length; i++) {
        ingredientsMap['ingredient${i + 1}'] = ingredients[i];
      }

      // Create meal title from primary food item
      String title = 'AI Analyzed Food';
      if (foodItems.isNotEmpty) {
        title = foodItems.first['name'] ?? 'AI Analyzed Food';
      }

      final meal = Meal(
        mealId: mealId,
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
        instructions: [
          'Food analyzed by AI',
          'Nutritional information estimated from image analysis',
        ],
        categories: ['ai-analyzed', mealType.toLowerCase()],
        category: 'ai-analyzed',
      );

      await docRef.set(meal.toJson());
      return mealId;
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

      final today = DateTime.now();
      final dateId = DateFormat('yyyy-MM-dd').format(today);

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
}
