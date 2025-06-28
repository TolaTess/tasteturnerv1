import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../constants.dart';

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
    final jsonStr = text
        .trim()
        .replaceAll(RegExp(r'^```json\\n'), '')
        .replaceAll(RegExp(r'\\n```$'), '')
        .trim();
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

Return ONLY a raw JSON object (no markdown, no code blocks) with the following structure:
{
  "meals": [
    {
      "title": "Dish name",
      "type": "protein|grain|vegetable",
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
- Diet type is the diet type of the meal plan (e.g., "keto", "vegan", "paleo", "gluten-free", "dairy-free",).
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
      String dietPreference) async {
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
Diet Preference: $dietPreference
User Answers: ${jsonEncode(userAnswers)}

Return ONLY a raw JSON object (no markdown, no code blocks) with the following structure:
{
  "programId": "unique_string",
  "type": "program type (balanced, fasting, high protein, low carb)",
  "name": "Program name",
  "description": "Brief program description",
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
}
