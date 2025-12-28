import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import 'notification_service.dart';

enum PlantCategory {
  vegetable,
  fruit,
  grain,
  legume,
  nutSeed,
  herbSpice,
}

class PlantIngredient {
  final String name;
  final PlantCategory category;
  final double points; // 1.0 for most, 0.25 for herbs/spices
  final DateTime firstSeen;

  PlantIngredient({
    required this.name,
    required this.category,
    required this.points,
    required this.firstSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.name,
      'points': points,
      'firstSeen': Timestamp.fromDate(firstSeen),
    };
  }

  factory PlantIngredient.fromMap(Map<String, dynamic> map) {
    return PlantIngredient(
      name: map['name'] as String? ?? '',
      category: PlantCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => PlantCategory.vegetable,
      ),
      points: (map['points'] as num?)?.toDouble() ?? 1.0,
      firstSeen: (map['firstSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class PlantDiversityScore {
  final int uniquePlants;
  final int level; // 1-3 (10, 20, 30+)
  final double progress; // 0.0 to 1.0
  final Map<PlantCategory, int> categoryBreakdown;

  PlantDiversityScore({
    required this.uniquePlants,
    required this.level,
    required this.progress,
    required this.categoryBreakdown,
  });
}

class PlantDetectionService extends GetxController {
  static PlantDetectionService get instance {
    if (!Get.isRegistered<PlantDetectionService>()) {
      debugPrint('⚠️ PlantDetectionService not registered, registering now');
      return Get.put(PlantDetectionService());
    }
    return Get.find<PlantDetectionService>();
  }

  // Plant keyword lists for categorization
  static const List<String> _vegetables = [
    'spinach',
    'kale',
    'lettuce',
    'broccoli',
    'cauliflower',
    'carrot',
    'celery',
    'cucumber',
    'tomato',
    'pepper',
    'onion',
    'garlic',
    'mushroom',
    'zucchini',
    'eggplant',
    'cabbage',
    'brussels',
    'asparagus',
    'green beans',
    'peas',
    'corn',
    'potato',
    'sweet potato',
    'beet',
    'radish',
    'turnip',
    'artichoke',
    'avocado',
    'pumpkin',
    'squash',
    'okra',
    'chard',
    'collard',
    'mustard',
  ];

  static const List<String> _fruits = [
    'apple',
    'banana',
    'orange',
    'grape',
    'strawberry',
    'blueberry',
    'raspberry',
    'blackberry',
    'cherry',
    'peach',
    'pear',
    'plum',
    'apricot',
    'mango',
    'pineapple',
    'watermelon',
    'cantaloupe',
    'honeydew',
    'kiwi',
    'papaya',
    'pomegranate',
    'cranberry',
    'date',
    'fig',
    'grapefruit',
    'lemon',
    'lime',
    'tangerine',
    'coconut',
    'olive',
  ];

  static const List<String> _grains = [
    'rice',
    'wheat',
    'oats',
    'quinoa',
    'barley',
    'millet',
    'buckwheat',
    'rye',
    'corn',
    'amaranth',
    'teff',
    'sorghum',
    'bulgur',
    'couscous',
    'farro',
    'spelt',
    'freekeh',
  ];

  static const List<String> _legumes = [
    'bean', 'lentil', 'chickpea', 'soy', 'tofu', 'tempeh', 'edamame',
    'black bean', 'kidney bean', 'pinto bean', 'navy bean', 'lima bean',
    'fava bean', 'split pea', 'black-eyed pea', 'mung bean', 'adzuki',
    'peanut', // Technically a legume
  ];

  static const List<String> _nutsSeeds = [
    'almond',
    'walnut',
    'cashew',
    'pistachio',
    'pecan',
    'hazelnut',
    'macadamia',
    'brazil nut',
    'pine nut',
    'chia',
    'flax',
    'hemp',
    'pumpkin seed',
    'sunflower seed',
    'sesame',
    'poppy seed',
    'pomegranate seed',
  ];

  static const List<String> _herbsSpices = [
    'basil',
    'oregano',
    'thyme',
    'rosemary',
    'sage',
    'parsley',
    'cilantro',
    'dill',
    'mint',
    'chive',
    'tarragon',
    'marjoram',
    'turmeric',
    'ginger',
    'garlic',
    'onion powder',
    'cumin',
    'coriander',
    'paprika',
    'cayenne',
    'black pepper',
    'white pepper',
    'cardamom',
    'cinnamon',
    'nutmeg',
    'clove',
    'allspice',
    'vanilla',
    'saffron',
    'bay leaf',
    'fennel',
    'star anise',
  ];

  static const List<String> _excludedIngredients = [
    'oil',
    'oils',
    'sauce',
    'dressings',
    'spice',
    'spices',
    'sugar',
    'sweeteners',
    'salt',
    'water',
    'coffee',
    'tea',
    'meat',
    'fish',
    'poultry',
    'dairy',
    'eggs',
    'flour', // To exclude refined flour (assuming whole grain is explicitly listed otherwise)
    'yeast',
  ];

  /// Check if an ingredient should be excluded from plant detection
  bool _isExcluded(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    for (final excluded in _excludedIngredients) {
      if (lowerName.contains(excluded.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Remove descriptive words from ingredient name (fresh, small, large, etc.)
  /// Examples: "fresh parsley" -> "parsley", "small apple" -> "apple"
  /// This ensures "fresh parsley" and "parsley" are treated as the same plant
  String _cleanDescriptiveWords(String name) {
    // List of descriptive words to remove (case-insensitive)
    // Must match the list in symptom_analysis_service.dart for consistency
    final descriptiveWords = [
      'fresh',
      'small',
      'large',
      'big',
      'dried',
      'frozen',
      'raw',
      'cooked',
      'organic',
      'whole',
      'chopped',
      'minced',
      'sliced',
      'diced',
      'grated',
      'crushed',
      'smashed',
      'peeled',
      'deveined',
      'boneless',
      'skinless',
      'half',
      'quarter',
      'baby',
      'young',
      'mature',
      'ripe',
      'unripe',
      'green',
      'red',
      'yellow',
      'orange',
      'purple',
      'white',
      'black',
      'brown',
      'pink',
      'wild',
      'cultivated',
      'local',
      'imported',
      'extra',
      'virgin',
      'pure',
      'natural',
      'artificial',
      'loin',
      'roast',
      'roasted',
      'roasting',
      'loins',
      'leaves',
      'stalks',
      'bulbs',
      'cloves',
      'heads',
      'bunch',
      'bunches',
      'sprigs',
      '(minced)',
      'juice',
      'juices',
      'firm',
    ];

    String cleaned = name.trim();

    // Remove descriptive words at the beginning
    for (final word in descriptiveWords) {
      final regex = RegExp('^$word\\s+', caseSensitive: false);
      cleaned = cleaned.replaceFirst(regex, '');
    }

    // Remove descriptive words at the end
    for (final word in descriptiveWords) {
      final regex = RegExp('\\s+$word\$', caseSensitive: false);
      cleaned = cleaned.replaceFirst(regex, '');
    }

    // Remove descriptive words in the middle (with spaces on both sides)
    for (final word in descriptiveWords) {
      final regex = RegExp('\\s+$word\\s+', caseSensitive: false);
      cleaned = cleaned.replaceAll(regex, ' ');
    }

    // Clean up multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  /// Normalize ingredient name for comparison (handles plurals, spaces, etc.)
  /// Examples: "apples" -> "apple", "sesame oil" -> "sesameoil", "SesameOil" -> "sesameoil"
  /// This is public so it can be used for consistent normalization across the app
  String normalizeIngredientName(String name) {
    // First clean descriptive words, then normalize
    final cleaned = _cleanDescriptiveWords(name);
    // Convert to lowercase and remove spaces
    String normalized =
        cleaned.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();

    // Remove common plural endings
    if (normalized.endsWith('ies')) {
      // berries -> berri -> berry (but we'll keep as is for now)
      normalized = normalized.substring(0, normalized.length - 3) + 'y';
    } else if (normalized.endsWith('es') && normalized.length > 3) {
      // Handle words ending in 'es'
      // First check if removing just 's' gives us a word ending in 'e' (like "apples" -> "apple")
      final withJustS =
          normalized.substring(0, normalized.length - 1); // Remove just 's'
      if (withJustS.endsWith('e') && withJustS.length > 1) {
        // "apples" -> "apple" (remove just 's', not 'es')
        normalized = withJustS;
      } else {
        // Handle other 'es' endings like "tomatoes" -> "tomato"
        final beforeEs = normalized.substring(0, normalized.length - 2);
        // Only remove 'es' if the word before it doesn't end in certain letters
        // This prevents "sesame" -> "sesam" (since "sesam" ends with 'e', but we already handled that above)
        if (!beforeEs.endsWith('s') &&
            !beforeEs.endsWith('x') &&
            !beforeEs.endsWith('z') &&
            !beforeEs.endsWith('ch') &&
            !beforeEs.endsWith('sh')) {
          normalized = beforeEs;
        }
      }
    } else if (normalized.endsWith('s') && normalized.length > 3) {
      // Remove trailing 's' for simple plurals (apples -> apple)
      // But avoid removing 's' from words that naturally end in 's'
      final beforeS = normalized.substring(0, normalized.length - 1);
      // Only remove 's' if the word before doesn't end in 's' (to avoid "rice" -> "ric")
      if (!beforeS.endsWith('s')) {
        normalized = beforeS;
      }
    }

    return normalized;
  }

  /// Detect plants from a meal's ingredients
  List<PlantIngredient> detectPlantsFromMeal(Meal meal) {
    final plants = <PlantIngredient>[];
    final seenNames = <String>{};

    for (final ingredientEntry in meal.ingredients.entries) {
      final ingredientName = ingredientEntry.key.toLowerCase().trim();
      final normalizedName = normalizeIngredientName(ingredientName);

      // Skip if excluded
      if (_isExcluded(ingredientName)) continue;

      // Skip if already seen (normalized comparison)
      if (seenNames.contains(normalizedName)) continue;
      seenNames.add(normalizedName);

      final category = _categorizeIngredient(ingredientName);
      if (category != null) {
        final points = category == PlantCategory.herbSpice ? 0.25 : 1.0;
        // Clean descriptive words from the name before storing
        final cleanedName = _cleanDescriptiveWords(ingredientEntry.key);
        plants.add(PlantIngredient(
          name: cleanedName.isEmpty
              ? ingredientEntry.key
              : cleanedName, // Use cleaned name
          category: category,
          points: points,
          firstSeen: meal.createdAt,
        ));
      }
    }

    return plants;
  }

  /// Detect plants from ingredient map (for UserMeal or other sources)
  List<PlantIngredient> detectPlantsFromIngredients(
    Map<String, String> ingredients,
    DateTime date,
  ) {
    final plants = <PlantIngredient>[];
    final seenNames = <String>{};

    debugPrint('🌱 Detecting plants from ${ingredients.length} ingredients');

    for (final ingredientEntry in ingredients.entries) {
      final ingredientName = ingredientEntry.key.toLowerCase().trim();
      final normalizedName = normalizeIngredientName(ingredientName);

      // Skip if excluded
      if (_isExcluded(ingredientName)) continue;

      // Skip if already seen (normalized comparison)
      if (seenNames.contains(normalizedName)) continue;
      seenNames.add(normalizedName);

      final category = _categorizeIngredient(ingredientName);
      if (category != null) {
        final points = category == PlantCategory.herbSpice ? 0.25 : 1.0;
        // Clean descriptive words from the name before storing
        final cleanedName = _cleanDescriptiveWords(ingredientEntry.key);
        plants.add(PlantIngredient(
          name: cleanedName.isEmpty
              ? ingredientEntry.key
              : cleanedName, // Use cleaned name
          category: category,
          points: points,
          firstSeen: date,
        ));
      }
    }

    return plants;
  }

  /// Categorize an ingredient into a plant category
  PlantCategory? _categorizeIngredient(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();

    // Check herbs/spices first (most specific)
    for (final herb in _herbsSpices) {
      if (lowerName.contains(herb)) {
        return PlantCategory.herbSpice;
      }
    }

    // Check nuts/seeds
    for (final nut in _nutsSeeds) {
      if (lowerName.contains(nut)) {
        return PlantCategory.nutSeed;
      }
    }

    // Check legumes
    for (final legume in _legumes) {
      if (lowerName.contains(legume)) {
        return PlantCategory.legume;
      }
    }

    // Check grains
    for (final grain in _grains) {
      if (lowerName.contains(grain)) {
        return PlantCategory.grain;
      }
    }

    // Check fruits
    for (final fruit in _fruits) {
      if (lowerName.contains(fruit)) {
        return PlantCategory.fruit;
      }
    }

    // Check vegetables
    for (final vegetable in _vegetables) {
      if (lowerName.contains(vegetable)) {
        return PlantCategory.vegetable;
      }
    }

    // If no match, return null (not a plant or unknown)
    return null;
  }

  /// Get unique plants for a week
  Future<List<PlantIngredient>> getUniquePlantsForWeek(
    String userId,
    DateTime weekStart,
  ) async {
    try {
      final weekId = _getWeekId(weekStart);
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('plant_tracking')
          .doc(weekId);

      final doc = await docRef.get();
      if (!doc.exists) {
        return [];
      }

      final data = doc.data()!;
      final plantsList = (data['plantDetails'] as List<dynamic>?)
              ?.map((e) => PlantIngredient.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];

      return plantsList;
    } catch (e) {
      debugPrint('Error getting unique plants for week: $e');
      return [];
    }
  }

  /// Get plant count for a week
  Future<int> getPlantCountForWeek(String userId, DateTime weekStart) async {
    final plants = await getUniquePlantsForWeek(userId, weekStart);
    return plants.length;
  }

  /// Get plant diversity score for a week
  Future<PlantDiversityScore> getPlantDiversityScore(
    String userId,
    DateTime weekStart,
  ) async {
    final plants = await getUniquePlantsForWeek(userId, weekStart);
    final uniqueCount = plants.length;

    // Calculate level (1: 10+, 2: 20+, 3: 30+)
    int level = 0;
    if (uniqueCount >= 30) {
      level = 3;
    } else if (uniqueCount >= 20) {
      level = 2;
    } else if (uniqueCount >= 10) {
      level = 1;
    }

    // Calculate progress (0.0 to 1.0) towards next level
    double progress = 0.0;
    if (level == 0) {
      progress = uniqueCount / 10.0; // Progress to level 1
    } else if (level == 1) {
      progress = (uniqueCount - 10) / 10.0; // Progress to level 2
    } else if (level == 2) {
      progress = (uniqueCount - 20) / 10.0; // Progress to level 3
    } else {
      progress = 1.0; // Maxed out
    }
    progress = progress.clamp(0.0, 1.0);

    // Category breakdown
    final categoryBreakdown = <PlantCategory, int>{};
    for (final plant in plants) {
      categoryBreakdown[plant.category] =
          (categoryBreakdown[plant.category] ?? 0) + 1;
    }

    return PlantDiversityScore(
      uniquePlants: uniqueCount,
      level: level,
      progress: progress,
      categoryBreakdown: categoryBreakdown,
    );
  }

  /// Stream plant diversity score for a week (realtime updates)
  Stream<PlantDiversityScore> streamPlantDiversityScore(
    String userId,
    DateTime weekStart,
  ) {
    try {
      final weekId = _getWeekId(weekStart);
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('plant_tracking')
          .doc(weekId);

      return docRef.snapshots().asyncMap((doc) {
        if (!doc.exists) {
          // Return empty score if document doesn't exist
          return PlantDiversityScore(
            uniquePlants: 0,
            level: 0,
            progress: 0.0,
            categoryBreakdown: {},
          );
        }

        final data = doc.data()!;
        final plantsList = (data['plantDetails'] as List<dynamic>?)
                ?.map((e) => PlantIngredient.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [];

        final uniqueCount = plantsList.length;

        // Calculate level (1: 10+, 2: 20+, 3: 30+)
        int level = 0;
        if (uniqueCount >= 30) {
          level = 3;
        } else if (uniqueCount >= 20) {
          level = 2;
        } else if (uniqueCount >= 10) {
          level = 1;
        }

        // Calculate progress (0.0 to 1.0) towards next level
        double progress = 0.0;
        if (level == 0) {
          progress = uniqueCount / 10.0; // Progress to level 1
        } else if (level == 1) {
          progress = (uniqueCount - 10) / 10.0; // Progress to level 2
        } else if (level == 2) {
          progress = (uniqueCount - 20) / 10.0; // Progress to level 3
        } else {
          progress = 1.0; // Maxed out
        }
        progress = progress.clamp(0.0, 1.0);

        // Category breakdown
        final categoryBreakdown = <PlantCategory, int>{};
        for (final plant in plantsList) {
          categoryBreakdown[plant.category] =
              (categoryBreakdown[plant.category] ?? 0) + 1;
        }

        return PlantDiversityScore(
          uniquePlants: uniqueCount,
          level: level,
          progress: progress,
          categoryBreakdown: categoryBreakdown,
        );
      }).handleError((error) {
        debugPrint('Error in plant diversity score stream: $error');
        // Return empty score on error
        return PlantDiversityScore(
          uniquePlants: 0,
          level: 0,
          progress: 0.0,
          categoryBreakdown: {},
        );
      });
    } catch (e) {
      debugPrint('Error creating plant diversity score stream: $e');
      // Return a stream with empty score
      return Stream.value(PlantDiversityScore(
        uniquePlants: 0,
        level: 0,
        progress: 0.0,
        categoryBreakdown: {},
      ));
    }
  }

  /// Track plants from a meal and update Firestore
  Future<void> trackPlantsFromMeal(
    String userId,
    Meal meal,
    DateTime mealDate,
  ) async {
    try {
      final weekStart = getWeekStart(mealDate);
      final weekId = _getWeekId(weekStart);
      final detectedPlants = detectPlantsFromMeal(meal);

      if (detectedPlants.isEmpty) return;

      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('plant_tracking')
          .doc(weekId);

      final doc = await docRef.get();
      final existingPlants = <String, PlantIngredient>{};

      if (doc.exists) {
        final data = doc.data()!;
        final existingList = (data['plantDetails'] as List<dynamic>?)
                ?.map((e) => PlantIngredient.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [];

        debugPrint(
            '🌱 Found ${existingList.length} existing plants in Firestore (from meal)');

        for (final plant in existingList) {
          final normalizedKey = normalizeIngredientName(plant.name);
          existingPlants[normalizedKey] = plant;
        }
      } else {
        debugPrint(
            '🌱 No existing plant tracking document found, creating new one (from meal)');
      }

      debugPrint('🌱 Detected ${detectedPlants.length} new plants from meal');
      debugPrint(
          '🌱 New plants: ${detectedPlants.map((p) => p.name).join(", ")}');

      // Add new plants (normalized deduplication - handles "fresh parsley" vs "parsley")
      int newPlantsAdded = 0;
      int existingPlantsUpdated = 0;
      for (final plant in detectedPlants) {
        // Use normalized name for deduplication to catch "fresh parsley" vs "parsley"
        final normalizedKey = normalizeIngredientName(plant.name);
        if (!existingPlants.containsKey(normalizedKey)) {
          existingPlants[normalizedKey] = plant;
          newPlantsAdded++;
          debugPrint(
              '🌱 Adding new plant: ${plant.name} (normalized: $normalizedKey)');
        } else {
          // Update firstSeen if this is earlier
          final existing = existingPlants[normalizedKey]!;
          if (plant.firstSeen.isBefore(existing.firstSeen)) {
            existingPlants[normalizedKey] = plant;
            existingPlantsUpdated++;
            debugPrint(
                '🌱 Updating firstSeen for existing plant: ${plant.name} (normalized: $normalizedKey)');
          } else {
            debugPrint(
                '🌱 Plant already exists (skipping): ${plant.name} (normalized: $normalizedKey matches ${existing.name})');
          }
        }
      }

      debugPrint(
          '🌱 Total plants after merge: ${existingPlants.length} (Added: $newPlantsAdded, Updated: $existingPlantsUpdated)');

      // Calculate total points
      final totalPoints = existingPlants.values
          .map((p) => p.points)
          .fold(0.0, (sum, points) => sum + points);

      // Calculate previous and new levels
      // Use the count from existingPlants map (which includes merged plants)
      final previousCount = existingPlants.length -
          newPlantsAdded; // Count before adding new ones
      final newCount = existingPlants.length;

      final previousLevel = _calculateLevel(previousCount);
      final newLevel = _calculateLevel(newCount);

      // Prepare the plant data
      final uniquePlantsList =
          existingPlants.values.map((p) => p.name).toList();
      final plantDetailsList =
          existingPlants.values.map((p) => p.toMap()).toList();

      // Save to Firestore - use set() with merge to ensure all fields are updated
      // Note: merge: true merges top-level fields, but replaces arrays (which is what we want)
      await docRef.set({
        'weekId': weekId,
        'weekStart': Timestamp.fromDate(weekStart),
        'uniquePlants': uniquePlantsList,
        'plantDetails': plantDetailsList,
        'totalPoints': totalPoints,
        'currentLevel': newLevel,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Check for milestone achievement and send notification
      if (newLevel > previousLevel && newLevel > 0) {
        await _notifyMilestoneAchievement(userId, newLevel, newCount);
      }
    } catch (e) {
      debugPrint('Error tracking plants from meal: $e');
    }
  }

  /// Track plants from ingredient map
  Future<void> trackPlantsFromIngredients(
    String userId,
    Map<String, String> ingredients,
    DateTime mealDate,
  ) async {
    try {
      final weekStart = getWeekStart(mealDate);
      final weekId = _getWeekId(weekStart);
      final detectedPlants = detectPlantsFromIngredients(ingredients, mealDate);

      if (detectedPlants.isEmpty) {
        return;
      }

      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('plant_tracking')
          .doc(weekId);

      final doc = await docRef.get();
      final existingPlants = <String, PlantIngredient>{};

      if (doc.exists) {
        final data = doc.data()!;
        final existingList = (data['plantDetails'] as List<dynamic>?)
                ?.map((e) => PlantIngredient.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [];

        for (final plant in existingList) {
          final normalizedKey = normalizeIngredientName(plant.name);
          existingPlants[normalizedKey] = plant;
        }
      } else {
        debugPrint(
            '🌱 No existing plant tracking document found, creating new one (from ingredients)');
      }

      // Add new plants (normalized deduplication)
      int newPlantsAdded = 0;
      int existingPlantsUpdated = 0;
      for (final plant in detectedPlants) {
        final normalizedKey = normalizeIngredientName(plant.name);
        if (!existingPlants.containsKey(normalizedKey)) {
          existingPlants[normalizedKey] = plant;
          newPlantsAdded++;
        } else {
          // Update firstSeen if this is earlier
          final existing = existingPlants[normalizedKey]!;
          if (plant.firstSeen.isBefore(existing.firstSeen)) {
            existingPlants[normalizedKey] = plant;
            existingPlantsUpdated++;
          } else {
            debugPrint(
                '🌱 Plant already exists (skipping): ${plant.name} (from ingredients)');
          }
        }
      }

      // Calculate total points
      final totalPoints = existingPlants.values
          .map((p) => p.points)
          .fold(0.0, (sum, points) => sum + points);

      // Calculate previous and new levels
      // Use the count from existingPlants map (which includes merged plants)
      final previousCount = existingPlants.length -
          newPlantsAdded; // Count before adding new ones
      final newCount = existingPlants.length;

      final previousLevel = _calculateLevel(previousCount);
      final newLevel = _calculateLevel(newCount);

      // Prepare the plant data
      final uniquePlantsList =
          existingPlants.values.map((p) => p.name).toList();
      final plantDetailsList =
          existingPlants.values.map((p) => p.toMap()).toList();

      // Save to Firestore - use set() with merge to ensure all fields are updated
      // Note: merge: true merges top-level fields, but replaces arrays (which is what we want)
      await docRef.set({
        'weekId': weekId,
        'weekStart': Timestamp.fromDate(weekStart),
        'uniquePlants': uniquePlantsList,
        'plantDetails': plantDetailsList,
        'totalPoints': totalPoints,
        'currentLevel': newLevel,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Check for milestone achievement and send notification
      if (newLevel > previousLevel && newLevel > 0) {
        await _notifyMilestoneAchievement(userId, newLevel, newCount);
      }
    } catch (e) {
      debugPrint('Error tracking plants from ingredients: $e');
      debugPrint('Error stack trace: ${e.toString()}');
    }
  }

  /// Calculate level from plant count
  int _calculateLevel(int count) {
    if (count >= 30) {
      return 3;
    } else if (count >= 20) {
      return 2;
    } else if (count >= 10) {
      return 1;
    }
    return 0;
  }

  /// Notify user when they reach a rainbow milestone
  Future<void> _notifyMilestoneAchievement(
    String userId,
    int level,
    int plantCount,
  ) async {
    try {
      // Check if we've already notified for this level this week
      final weekStart = getWeekStart(DateTime.now());
      final weekId = _getWeekId(weekStart);
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('plant_tracking')
          .doc(weekId);

      final doc = await docRef.get();
      final notifiedLevels = (doc.data()?['notifiedLevels'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [];

      // If we've already notified for this level, skip
      if (notifiedLevels.contains(level)) {
        return;
      }

      // Get level name and message
      String levelName;
      String message;
      switch (level) {
        case 1:
          levelName = 'Beginner';
          message =
              'Congratulations! You\'ve reached Beginner level with $plantCount unique plants! 🌱';
          break;
        case 2:
          levelName = 'Healthy';
          message =
              'Amazing! You\'ve reached Healthy level with $plantCount unique plants! 🥗';
          break;
        case 3:
          levelName = 'Gut Hero';
          message =
              'Incredible! You\'ve reached Gut Hero level with $plantCount unique plants! 🏆';
          break;
        default:
          return; // Should not happen
      }

      // Send notification with payload to navigate to Rainbow Tracker
      try {
        final notificationService = NotificationService();
        final payload = {
          'type': 'plant_milestone',
          'level': level,
          'levelName': levelName,
          'plantCount': plantCount,
          'weekStart':
              weekStart.toIso8601String(), // ISO 8601 format for parsing
        };

        await notificationService.showNotification(
          id: 2000 + level, // Unique ID for each level
          title: 'Rainbow Milestone: $levelName!',
          body: message,
          payload: payload,
        );
      } catch (e) {
        debugPrint('Error sending milestone notification: $e');
        // Continue to mark as notified even if notification fails
      }

      // Mark this level as notified
      notifiedLevels.add(level);
      await docRef.set({
        'notifiedLevels': notifiedLevels,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending milestone notification: $e');
    }
  }

  /// Get week ID in ISO format (YYYY-Www)
  String _getWeekId(DateTime date) {
    // Get ISO week number
    final weekStart = getWeekStart(date);
    final year = weekStart.year;

    // Calculate week number: days from Jan 1 to week start / 7, rounded up
    final jan1 = DateTime(year, 1, 1);
    final daysFromJan1 = weekStart.difference(jan1).inDays;
    final weekNumber = ((daysFromJan1 + 1) / 7).ceil();

    return '${year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Get summary of plants from previous weeks
  /// Returns a list of week summaries with plant counts
  Future<List<Map<String, dynamic>>> getPreviousWeeksSummary(
    String userId,
    DateTime currentWeekStart, {
    int numberOfWeeks = 4,
  }) async {
    try {
      final summaries = <Map<String, dynamic>>[];

      // Get previous weeks (going back from current week)
      for (int i = 1; i <= numberOfWeeks; i++) {
        final previousWeekStart =
            currentWeekStart.subtract(Duration(days: 7 * i));
        final weekId = _getWeekId(previousWeekStart);

        try {
          final docRef = firestore
              .collection('users')
              .doc(userId)
              .collection('plant_tracking')
              .doc(weekId);

          final doc = await docRef.get();
          if (doc.exists) {
            final data = doc.data()!;
            final plantCount =
                (data['plantDetails'] as List<dynamic>?)?.length ?? 0;
            final uniquePlants =
                (data['uniquePlants'] as List<dynamic>?)?.length ?? 0;
            final level = (data['currentLevel'] as int?) ?? 0;

            summaries.add({
              'weekStart': previousWeekStart,
              'weekId': weekId,
              'plantCount': plantCount,
              'uniquePlants': uniquePlants,
              'level': level,
            });
          }
        } catch (e) {
          debugPrint('Error loading week $weekId: $e');
          // Continue to next week even if one fails
        }
      }

      // Sort by weekStart descending (most recent first)
      summaries.sort((a, b) =>
          (b['weekStart'] as DateTime).compareTo(a['weekStart'] as DateTime));

      return summaries;
    } catch (e) {
      debugPrint('Error getting previous weeks summary: $e');
      return [];
    }
  }
}
