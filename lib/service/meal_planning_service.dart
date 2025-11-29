import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:intl/intl.dart';
import '../constants.dart';
import '../service/gemini_service.dart';

/// Service to consolidate meal planning functionality
/// Used by buddy screen meal plan mode and other meal planning features
class MealPlanningService {
  static final MealPlanningService instance = MealPlanningService._();
  MealPlanningService._();

  final geminiService = GeminiService.instance;

  /// Generate meal plan using AI
  /// Returns a map with meals, mealIds, and other metadata
  Future<Map<String, dynamic>> generateMealPlan(
    String prompt,
    String contextInformation, {
    String cuisine = 'general',
    int mealCount = 10,
    Map<String, int>? distribution,
    bool partOfWeeklyMeal = false,
    String weeklyPlanContext = '',
  }) async {
    try {
      final result = await geminiService.generateMealsIntelligently(
        prompt,
        contextInformation,
        cuisine,
        mealCount: mealCount,
        partOfWeeklyMeal: partOfWeeklyMeal,
        weeklyPlanContext: weeklyPlanContext,
      );

      return {
        'success': true,
        'meals': result['meals'] ?? [],
        'mealIds': result['mealIds'] ?? [],
        'existingMealIds': result['existingMealIds'] ?? [],
        'distribution': result['distribution'] ??
            {
              'breakfast': 2,
              'lunch': 3,
              'dinner': 3,
              'snack': 2,
            },
        'source': result['source'] ?? 'unknown',
      };
    } catch (e) {
      debugPrint('Error generating meal plan: $e');
      return {
        'success': false,
        'error': e.toString(),
        'meals': [],
        'mealIds': [],
      };
    }
  }

  /// Save a recipe to user's recipe collection
  /// The meal should already exist in the meals collection
  Future<bool> saveRecipe(String mealId,
      {Map<String, dynamic>? mealData}) async {
    try {
      final userId = userService.userId;
      if (userId == null || userId.isEmpty) {
        debugPrint('Cannot save recipe: userId is empty');
        return false;
      }

      // If mealData is provided, use it; otherwise fetch from Firestore
      Map<String, dynamic>? meal;
      if (mealData != null) {
        meal = mealData;
      } else {
        final mealDoc = await firestore.collection('meals').doc(mealId).get();
        if (!mealDoc.exists) {
          debugPrint('Meal not found: $mealId');
          return false;
        }
        meal = mealDoc.data();
      }

      if (meal == null) {
        debugPrint('Cannot save recipe: meal data is null');
        return false;
      }

      // Check if recipe already saved
      final savedRecipeRef = firestore
          .collection('users')
          .doc(userId)
          .collection('savedRecipes')
          .doc(mealId);

      final savedRecipeDoc = await savedRecipeRef.get();
      if (savedRecipeDoc.exists) {
        debugPrint('Recipe already saved: $mealId');
        return true; // Already saved, consider it success
      }

      // Save recipe reference
      await savedRecipeRef.set({
        'mealId': mealId,
        'savedAt': FieldValue.serverTimestamp(),
        'title': meal['title'] ?? 'Untitled Recipe',
      });

      debugPrint('Recipe saved successfully: $mealId');
      return true;
    } catch (e) {
      debugPrint('Error saving recipe: $e');
      return false;
    }
  }

  /// Add meal(s) to calendar for a specific date
  /// Returns true if successful, false otherwise
  Future<bool> addMealToCalendar(
    List<String> mealIds,
    DateTime date, {
    String? mealType,
    String dayType = 'regular_day',
    bool isSpecial = false,
    String? sharedCalendarId,
  }) async {
    try {
      final userId = userService.userId;
      if (userId == null || userId.isEmpty) {
        debugPrint('Cannot add meal to calendar: userId is empty');
        return false;
      }

      final formattedDate = DateFormat('yyyy-MM-dd').format(date);

      DocumentReference docRef;
      if (sharedCalendarId != null && sharedCalendarId.isNotEmpty) {
        // Add to shared calendar
        docRef = firestore
            .collection('shared_calendars')
            .doc(sharedCalendarId)
            .collection('date')
            .doc(formattedDate);
      } else {
        // Add to personal calendar
        docRef = firestore
            .collection('mealPlans')
            .doc(userId)
            .collection('date')
            .doc(formattedDate);
      }

      // Get existing document
      final docSnapshot = await docRef.get();
      List<String> existingMealIds = [];

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('meals')) {
          existingMealIds = List<String>.from(data['meals'] ?? []);
        }
      }

      // Format meal IDs with meal type if provided
      List<String> formattedMealIds = [];
      if (mealType != null) {
        // Map meal type to suffix
        final typeMap = <String, String>{
          'breakfast': 'bf',
          'lunch': 'lh',
          'dinner': 'dn',
          'snack': 'sn',
        };
        final suffix = typeMap[mealType.toLowerCase()] ?? 'bf';
        formattedMealIds = mealIds.map((id) => '$id/$suffix').toList();
      } else {
        formattedMealIds = mealIds;
      }

      // Merge with existing meals, avoiding duplicates
      final mergedMealIds = {...existingMealIds, ...formattedMealIds}.toList();

      // Save to calendar
      await docRef.set({
        'userId': userId,
        'date': formattedDate,
        'dayType': dayType,
        'isSpecial': isSpecial || (dayType != 'regular_day'),
        'meals': mergedMealIds,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
          'Meals added to calendar: ${formattedMealIds.length} meals for $formattedDate');
      return true;
    } catch (e) {
      debugPrint('Error adding meal to calendar: $e');
      return false;
    }
  }

  /// Get recipes for a meal plan
  /// Returns list of meal data
  Future<List<Map<String, dynamic>>> getRecipesForMealPlan(
    List<String> mealIds,
  ) async {
    try {
      final recipes = <Map<String, dynamic>>[];

      for (final mealId in mealIds) {
        // Remove meal type suffix if present (e.g., "mealId/bf" -> "mealId")
        final cleanMealId = mealId.split('/').first;

        try {
          final mealDoc =
              await firestore.collection('meals').doc(cleanMealId).get();
          if (mealDoc.exists) {
            final mealData = mealDoc.data();
            if (mealData != null) {
              recipes.add({
                'mealId': cleanMealId,
                ...mealData,
              });
            }
          }
        } catch (e) {
          debugPrint('Error fetching meal $cleanMealId: $e');
          continue;
        }
      }

      return recipes;
    } catch (e) {
      debugPrint('Error getting recipes for meal plan: $e');
      return [];
    }
  }

  /// Generate meal plan from user prompt in meal plan mode
  /// This is a convenience method that combines prompt building and generation
  /// Supports family member context for generating meals for family members
  Future<Map<String, dynamic>> generateMealPlanFromPrompt(
    String userPrompt, {
    String? cuisine,
    int? mealCount,
    String? familyMemberName,
    String? familyMemberKcal,
    String? familyMemberGoal,
    String? familyMemberType,
  }) async {
    try {
      // Get user context (use family member context if provided)
      final userContext = _getUserContext(
        familyMemberName: familyMemberName,
        familyMemberKcal: familyMemberKcal,
        familyMemberGoal: familyMemberGoal,
        familyMemberType: familyMemberType,
      );

      // Build prompt with family member context if applicable
      String targetPerson = familyMemberName ?? userContext['displayName'];
      String prompt;

      // Add timestamp for variation to avoid repetitive meals
      final timestamp = DateTime.now().toIso8601String();
      final variationNote =
          'Current time: $timestamp. Please generate diverse meal options, avoiding repetition from previous requests.';

      if (familyMemberName != null && familyMemberName.isNotEmpty) {
        prompt = """
Generate a meal plan for $familyMemberName based on the following request:

User Request: $userPrompt

$familyMemberName's Context:
- Age Group: ${familyMemberType ?? 'Adult'}
- Fitness Goal: ${userContext['fitnessGoal']}
- Daily Calorie Target: ${userContext['foodGoal']} kcal
- Diet Preference: ${userContext['dietPreference']}

$variationNote

Please generate ${mealCount ?? 10} diverse meals appropriate for $familyMemberName that align with the request and their specific needs. Ensure variety and avoid repeating the same meals.
""";
      } else {
        prompt = """
Generate a meal plan based on the following request:

User Request: $userPrompt

User Context:
- Fitness Goal: ${userContext['fitnessGoal']}
- Diet Preference: ${userContext['dietPreference']}
- Current Weight: ${userContext['currentWeight']}
- Goal Weight: ${userContext['goalWeight']}

$variationNote

Please generate ${mealCount ?? 10} diverse meals that align with the user's request and preferences. Ensure variety and avoid repeating the same meals.
""";
      }

      final contextInfo = """
Target: $targetPerson
Fitness Goal: ${userContext['fitnessGoal']}
Diet Preference: ${userContext['dietPreference']}
${familyMemberKcal != null ? 'Daily Calories: $familyMemberKcal kcal' : 'Current Weight: ${userContext['currentWeight']} kg'}
${familyMemberType != null ? 'Age Group: $familyMemberType' : 'Goal Weight: ${userContext['goalWeight']} kg'}
""";

      final result = await generateMealPlan(
        prompt,
        contextInfo,
        cuisine: cuisine ?? 'general',
        mealCount: mealCount ?? 10,
      );

      // Add family member name to result for storage
      if (familyMemberName != null && familyMemberName.isNotEmpty) {
        result['familyMemberName'] = familyMemberName;
      }

      return result;
    } catch (e) {
      debugPrint('Error generating meal plan from prompt: $e');
      return {
        'success': false,
        'error': e.toString(),
        'meals': [],
        'mealIds': [],
      };
    }
  }

  /// Get user context for meal planning
  /// Supports family member context overrides
  Map<String, dynamic> _getUserContext({
    String? familyMemberName,
    String? familyMemberKcal,
    String? familyMemberGoal,
    String? familyMemberType,
  }) {
    final user = userService.currentUser.value;

    // If family member context is provided, use it; otherwise use main user settings
    if (familyMemberName != null && familyMemberName.isNotEmpty) {
      return {
        'displayName': familyMemberName,
        'fitnessGoal': familyMemberGoal ?? 'Healthy Eating',
        'dietPreference': user?.settings['dietPreference'] ?? 'Balanced',
        'currentWeight': 0.0, // Family members may not have weight data
        'goalWeight': 0.0,
        'startingWeight': 0.0,
        'foodGoal': familyMemberKcal ?? '2000',
        'ageGroup': familyMemberType ?? 'Adult',
      };
    }

    return {
      'displayName': user?.displayName ?? 'there',
      'fitnessGoal': user?.settings['fitnessGoal'] ?? 'Healthy Eating',
      'dietPreference': user?.settings['dietPreference'] ?? 'Balanced',
      'currentWeight': user?.settings['currentWeight'] ?? 0.0,
      'goalWeight': user?.settings['goalWeight'] ?? 0.0,
      'startingWeight': user?.settings['startingWeight'] ?? 0.0,
      'foodGoal': user?.settings['foodGoal'] ?? 0.0,
    };
  }
}
