import 'package:flutter/material.dart' show debugPrint;
import 'package:get/get.dart';
import '../data_models/symptom_entry.dart';
import '../helper/utils.dart';
import 'symptom_service.dart';

/// Service for analyzing symptom patterns and providing insights
class SymptomAnalysisService extends GetxController {
  static SymptomAnalysisService get instance {
    if (!Get.isRegistered<SymptomAnalysisService>()) {
      debugPrint('⚠️ SymptomAnalysisService not registered, registering now');
      return Get.put(SymptomAnalysisService());
    }
    return Get.find<SymptomAnalysisService>();
  }

  final SymptomService _symptomService = SymptomService.instance;

  /// Analyze symptom patterns over a time period
  /// Returns insights about common triggers and patterns
  Future<Map<String, dynamic>> analyzeSymptomPatterns(
    String userId, {
    int days = 30,
  }) async {
    try {
      // Get symptoms from the last N days
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final allSymptoms =
          await _getSymptomsInDateRange(userId, startDate, endDate);

      if (allSymptoms.isEmpty) {
        return {
          'hasData': false,
          'message':
              'Not enough symptom data to analyze. Keep logging symptoms to see patterns!',
        };
      }

      // Analyze patterns
      final ingredientCorrelations =
          _calculateIngredientCorrelations(allSymptoms);
      final symptomFrequency = _calculateSymptomFrequency(allSymptoms);
      final topTriggers = _getTopTriggers(ingredientCorrelations);
      final severityTrends = _calculateSeverityTrends(allSymptoms);
      final mealTypePatterns = _analyzeMealTypePatterns(allSymptoms);

      return {
        'hasData': true,
        'totalSymptoms': allSymptoms.length,
        'daysAnalyzed': days,
        'ingredientCorrelations': ingredientCorrelations,
        'symptomFrequency': symptomFrequency,
        'topTriggers': topTriggers,
        'severityTrends': severityTrends,
        'mealTypePatterns': mealTypePatterns,
        'recommendations': _generateRecommendations(
          topTriggers,
          symptomFrequency,
          mealTypePatterns,
          days,
          ingredientCorrelations,
        ),
      };
    } catch (e) {
      debugPrint('Error analyzing symptom patterns: $e');
      return {
        'hasData': false,
        'error': e.toString(),
      };
    }
  }

  /// Get correlation data for a specific ingredient
  Future<Map<String, dynamic>> getIngredientCorrelations(
    String userId,
    String ingredient,
  ) async {
    try {
      // Clean descriptive words first, then normalize
      final cleanedIngredient = _cleanDescriptiveWords(ingredient);
      final ingredientLower = cleanedIngredient.toLowerCase().trim();

      // Don't analyze excluded ingredients (water, salt, pepper, etc.)
      if (_excludedIngredients.contains(ingredientLower)) {
        return {
          'ingredient': ingredient,
          'occurrences': 0,
          'correlation': 0.0,
          'symptoms': {},
          'message': 'This ingredient is not analyzed as a potential trigger.',
        };
      }

      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      final allSymptoms =
          await _getSymptomsInDateRange(userId, startDate, endDate);

      // Find symptoms that include this ingredient
      final relatedSymptoms = allSymptoms.where((symptom) {
        return symptom.ingredients.any(
          (ing) =>
              ing.toLowerCase().contains(ingredientLower) ||
              ingredientLower.contains(ing.toLowerCase()),
        );
      }).toList();

      if (relatedSymptoms.isEmpty) {
        return {
          'ingredient': ingredient,
          'occurrences': 0,
          'correlation': 0.0,
          'symptoms': {},
        };
      }

      // Calculate symptom distribution
      final symptomCounts = <String, int>{};
      double totalSeverity = 0;

      for (final symptom in relatedSymptoms) {
        symptomCounts[symptom.type] = (symptomCounts[symptom.type] ?? 0) + 1;
        totalSeverity += symptom.severity.toDouble();
      }

      final avgSeverity = totalSeverity / relatedSymptoms.length;
      final correlation = relatedSymptoms.length / allSymptoms.length;
      final occurrences = relatedSymptoms.length;

      // Only return data if ingredient has 2+ occurrences (same threshold as immediate analysis)
      // This prevents false positives in correlation analysis
      if (occurrences < 2) {
        return {
          'ingredient': ingredient,
          'occurrences': occurrences,
          'correlation': 0.0, // Set to 0 to indicate below threshold
          'averageSeverity': avgSeverity,
          'symptoms': symptomCounts,
          'message':
              'This ingredient has been noted but needs 2+ occurrences to be displayed as a trigger.',
        };
      }

      return {
        'ingredient': ingredient,
        'occurrences': occurrences,
        'correlation': correlation,
        'averageSeverity': avgSeverity,
        'symptoms': symptomCounts,
        'totalSymptomsWithIngredient': relatedSymptoms.length,
        'totalSymptomsAnalyzed': allSymptoms.length,
      };
    } catch (e) {
      debugPrint('Error getting ingredient correlations: $e');
      return {
        'ingredient': ingredient,
        'error': e.toString(),
      };
    }
  }

  /// Get top trigger ingredients
  Future<List<Map<String, dynamic>>> getTopTriggers(
    String userId, {
    int limit = 10,
    int days = 30,
  }) async {
    try {
      final patterns = await analyzeSymptomPatterns(userId, days: days);
      if (patterns['hasData'] != true) {
        return [];
      }

      final topTriggers =
          (patterns['topTriggers'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      return topTriggers.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting top triggers: $e');
      return [];
    }
  }

  /// Get symptom trends over time
  Future<Map<String, dynamic>> getSymptomTrends(
    String userId, {
    int weeks = 4,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: weeks * 7));

      final allSymptoms =
          await _getSymptomsInDateRange(userId, startDate, endDate);

      if (allSymptoms.isEmpty) {
        return {
          'hasData': false,
          'weeklyTrends': [],
        };
      }

      // Group by week
      final weeklyData = <String, List<SymptomEntry>>{};
      for (final symptom in allSymptoms) {
        final weekStart = getWeekStart(symptom.timestamp);
        final weekKey =
            '${weekStart.year}-W${weekStart.month}-${weekStart.day}';
        weeklyData.putIfAbsent(weekKey, () => []).add(symptom);
      }

      final weeklyTrends = weeklyData.entries.map((entry) {
        final weekSymptoms = entry.value;
        final symptomCounts = <String, int>{};
        double totalSeverity = 0;

        for (final symptom in weekSymptoms) {
          symptomCounts[symptom.type] = (symptomCounts[symptom.type] ?? 0) + 1;
          totalSeverity += symptom.severity.toDouble();
        }

        return {
          'week': entry.key,
          'totalSymptoms': weekSymptoms.length,
          'averageSeverity': totalSeverity / weekSymptoms.length,
          'symptomCounts': symptomCounts,
        };
      }).toList();

      return {
        'hasData': true,
        'weeks': weeks,
        'weeklyTrends': weeklyTrends,
      };
    } catch (e) {
      debugPrint('Error getting symptom trends: $e');
      return {
        'hasData': false,
        'error': e.toString(),
      };
    }
  }

  /// Get symptoms in a date range
  Future<List<SymptomEntry>> _getSymptomsInDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final allSymptoms = <SymptomEntry>[];

      // Get all weeks that might contain symptoms in this range
      var currentDate = startDate;
      while (currentDate.isBefore(endDate) ||
          currentDate.isAtSameMomentAs(endDate)) {
        try {
          final weekSymptoms =
              await _symptomService.getSymptomsForDate(userId, currentDate);
          allSymptoms.addAll(weekSymptoms);
        } catch (e) {
          debugPrint('Error getting symptoms for date ${currentDate}: $e');
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      // Filter to only include symptoms in the date range
      return allSymptoms.where((symptom) {
        return symptom.timestamp
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            symptom.timestamp.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    } catch (e) {
      debugPrint('Error getting symptoms in date range: $e');
      return [];
    }
  }

  /// Calculate correlations between ingredients and symptoms
  Map<String, Map<String, dynamic>> _calculateIngredientCorrelations(
    List<SymptomEntry> symptoms,
  ) {
    final correlations = <String, Map<String, dynamic>>{};
    final ingredientSymptomCounts = <String, Map<String, int>>{};
    final ingredientSeveritySums = <String, double>{};
    final ingredientOccurrences = <String, int>{};

    // Count occurrences
    for (final symptom in symptoms) {
      for (final ingredient in symptom.ingredients) {
        // Clean descriptive words first, then normalize
        final cleanedIngredient = _cleanDescriptiveWords(ingredient);
        final ingLower = cleanedIngredient.toLowerCase().trim();

        // Skip excluded ingredients (water, salt, pepper, etc.)
        if (_excludedIngredients.contains(ingLower)) {
          continue;
        }

        // Also check if ingredient contains excluded terms as standalone words
        bool isExcluded = false;
        for (final excluded in _excludedIngredients) {
          if (ingLower == excluded ||
              ingLower.startsWith('$excluded ') ||
              ingLower.endsWith(' $excluded') ||
              ingLower.contains(' $excluded ')) {
            isExcluded = true;
            break;
          }
        }
        if (isExcluded) {
          continue;
        }

        ingredientOccurrences[ingLower] =
            (ingredientOccurrences[ingLower] ?? 0) + 1;

        ingredientSymptomCounts.putIfAbsent(ingLower, () => {});
        ingredientSymptomCounts[ingLower]![symptom.type] =
            (ingredientSymptomCounts[ingLower]![symptom.type] ?? 0) + 1;

        ingredientSeveritySums[ingLower] =
            (ingredientSeveritySums[ingLower] ?? 0.0) +
                symptom.severity.toDouble();
      }
    }

    // Calculate correlations
    for (final entry in ingredientOccurrences.entries) {
      final ingredient = entry.key;
      final occurrences = entry.value;
      final symptomCounts = ingredientSymptomCounts[ingredient] ?? {};
      final avgSeverity = ingredientSeveritySums[ingredient]! / occurrences;

      // Find most common symptom for this ingredient
      String? mostCommonSymptom;
      int maxCount = 0;
      for (final symptomEntry in symptomCounts.entries) {
        if (symptomEntry.value > maxCount) {
          maxCount = symptomEntry.value;
          mostCommonSymptom = symptomEntry.key;
        }
      }

      correlations[ingredient] = {
        'occurrences': occurrences,
        'correlation': occurrences / symptoms.length,
        'averageSeverity': avgSeverity,
        'symptomCounts': symptomCounts,
        'mostCommonSymptom': mostCommonSymptom,
        'mostCommonSymptomCount': maxCount,
      };
    }

    return correlations;
  }

  /// Calculate frequency of each symptom type
  Map<String, int> _calculateSymptomFrequency(List<SymptomEntry> symptoms) {
    final frequency = <String, int>{};
    for (final symptom in symptoms) {
      frequency[symptom.type] = (frequency[symptom.type] ?? 0) + 1;
    }
    return frequency;
  }

  /// Remove descriptive words from ingredient name (fresh, small, large, etc.)
  /// Examples: "fresh parsley" -> "parsley", "small apple" -> "apple"
  String _cleanDescriptiveWords(String name) {
    // List of descriptive words to remove (case-insensitive)
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
      'whole',
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
      'roasted',
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

  /// Common ingredients that should not be flagged as triggers
  /// These are basic, non-reactive ingredients that are unlikely to cause symptoms
  static const Set<String> _excludedIngredients = {
    'water',
    'salt',
    'pepper',
    'black pepper',
    'sea salt',
    'table salt',
    'kosher salt',
    'ice',
    'ice water',
    'tap water',
    'mineral water',
    'sparkling water',
    'still water',
  };

  /// Get top trigger ingredients sorted by correlation and severity
  List<Map<String, dynamic>> _getTopTriggers(
    Map<String, Map<String, dynamic>> correlations,
  ) {
    final triggers = <Map<String, dynamic>>[];

    for (final entry in correlations.entries) {
      // Clean descriptive words first, then normalize
      final cleanedIngredient = _cleanDescriptiveWords(entry.key);
      final ingredient = cleanedIngredient.toLowerCase().trim();

      // Skip excluded ingredients (water, salt, pepper, etc.)
      if (_excludedIngredients.contains(ingredient)) {
        continue;
      }

      // Also check if ingredient contains excluded terms (e.g., "water" in "coconut water")
      // But allow if it's part of a compound ingredient (e.g., "coconut water" is fine)
      bool isExcluded = false;
      for (final excluded in _excludedIngredients) {
        // Only exclude if ingredient is exactly the excluded term or starts with it followed by space
        if (ingredient == excluded ||
            ingredient.startsWith('$excluded ') ||
            ingredient.endsWith(' $excluded') ||
            ingredient.contains(' $excluded ')) {
          isExcluded = true;
          break;
        }
      }
      if (isExcluded) {
        continue;
      }

      final data = entry.value;
      final isNegative = data['mostCommonSymptom'] != 'good' &&
          data['mostCommonSymptom'] != 'energy';
      final occurrences = data['occurrences'] as int;

      // Only show triggers with 2+ occurrences (same threshold as immediate analysis)
      // This prevents false positives like "olive oil: 50% correlation with 1 occurrence"
      if (isNegative &&
          data['correlation'] as double > 0.1 &&
          occurrences >= 2) {
        triggers.add({
          'ingredient': entry.key,
          'correlation': data['correlation'],
          'averageSeverity': data['averageSeverity'],
          'occurrences': occurrences,
          'mostCommonSymptom': data['mostCommonSymptom'],
          'mostCommonSymptomCount': data['mostCommonSymptomCount'],
        });
      }
    }

    // Sort by correlation * severity (higher is worse)
    triggers.sort((a, b) {
      final scoreA =
          (a['correlation'] as double) * (a['averageSeverity'] as double);
      final scoreB =
          (b['correlation'] as double) * (b['averageSeverity'] as double);
      return scoreB.compareTo(scoreA);
    });

    return triggers;
  }

  /// Calculate severity trends
  Map<String, dynamic> _calculateSeverityTrends(List<SymptomEntry> symptoms) {
    if (symptoms.isEmpty) {
      return {
        'averageSeverity': 0.0,
        'trend': 'stable',
      };
    }

    final totalSeverity = symptoms.fold<double>(
      0.0,
      (sum, symptom) => sum + symptom.severity.toDouble(),
    );
    final avgSeverity = totalSeverity / symptoms.length;

    // Calculate trend (comparing first half vs second half)
    if (symptoms.length < 4) {
      return {
        'averageSeverity': avgSeverity,
        'trend': 'insufficient_data',
      };
    }

    final midPoint = symptoms.length ~/ 2;
    final firstHalf = symptoms.sublist(0, midPoint);
    final secondHalf = symptoms.sublist(midPoint);

    final firstAvg = firstHalf.fold<double>(
          0.0,
          (sum, s) => sum + s.severity.toDouble(),
        ) /
        firstHalf.length;
    final secondAvg = secondHalf.fold<double>(
          0.0,
          (sum, s) => sum + s.severity.toDouble(),
        ) /
        secondHalf.length;

    String trend;
    if (secondAvg < firstAvg - 0.5) {
      trend = 'improving';
    } else if (secondAvg > firstAvg + 0.5) {
      trend = 'worsening';
    } else {
      trend = 'stable';
    }

    return {
      'averageSeverity': avgSeverity,
      'trend': trend,
      'firstHalfAverage': firstAvg,
      'secondHalfAverage': secondAvg,
    };
  }

  /// Analyze patterns by meal type
  Map<String, dynamic> _analyzeMealTypePatterns(List<SymptomEntry> symptoms) {
    final mealTypeCounts = <String, Map<String, int>>{};
    final mealTypeSeverities = <String, double>{};
    final mealTypeOccurrences = <String, int>{};

    for (final symptom in symptoms) {
      final mealType = symptom.mealType ?? symptom.mealContext ?? 'unknown';
      mealTypeOccurrences[mealType] = (mealTypeOccurrences[mealType] ?? 0) + 1;

      mealTypeCounts.putIfAbsent(mealType, () => {});
      mealTypeCounts[mealType]![symptom.type] =
          (mealTypeCounts[mealType]![symptom.type] ?? 0) + 1;

      mealTypeSeverities[mealType] =
          (mealTypeSeverities[mealType] ?? 0.0) + symptom.severity.toDouble();
    }

    final patterns = <String, Map<String, dynamic>>{};
    for (final entry in mealTypeOccurrences.entries) {
      final mealType = entry.key;
      final occurrences = entry.value;
      patterns[mealType] = {
        'occurrences': occurrences,
        'averageSeverity': mealTypeSeverities[mealType]! / occurrences,
        'symptomCounts': mealTypeCounts[mealType] ?? {},
      };
    }

    return patterns;
  }

  /// Generate recommendations based on analysis
  List<String> _generateRecommendations(
    List<Map<String, dynamic>> topTriggers,
    Map<String, int> symptomFrequency,
    Map<String, dynamic> mealTypePatterns,
    int daysAnalyzed,
    Map<String, Map<String, dynamic>> ingredientCorrelations,
  ) {
    final recommendations = <String>[];

    // Top trigger recommendations
    if (topTriggers.isNotEmpty) {
      final topTrigger = topTriggers.first;
      final ingredient = topTrigger['ingredient'] as String;
      final symptom = topTrigger['mostCommonSymptom'] as String;
      recommendations.add(
        'Consider reducing $ingredient intake. It appears in ${topTrigger['occurrences']}% of your $symptom episodes.',
      );
    }

    // Most common symptom recommendation
    if (symptomFrequency.isNotEmpty) {
      final mostCommon = symptomFrequency.entries
          .where((e) => e.key != 'good' && e.key != 'energy')
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (mostCommon.isNotEmpty) {
        final symptomType = mostCommon.first.key;
        final occurrenceCount = mostCommon.first.value;
        final symptomName =
            symptomType[0].toUpperCase() + symptomType.substring(1);

        // Determine time period text
        String timePeriod;
        if (daysAnalyzed == 7) {
          timePeriod = 'this week';
        } else if (daysAnalyzed == 30) {
          timePeriod = 'in the last 30 days';
        } else if (daysAnalyzed == 1) {
          timePeriod = 'today';
        } else {
          timePeriod = 'in the last $daysAnalyzed days';
        }

        // Count ingredients with 1 occurrence (waiting for 2nd occurrence to be displayed)
        int trackedIngredientsCount = 0;
        for (final entry in ingredientCorrelations.entries) {
          final occurrences = entry.value['occurrences'] as int? ?? 0;
          final mostCommonSymptom = entry.value['mostCommonSymptom'] as String?;
          // Count ingredients with exactly 1 occurrence that are negative symptoms
          if (occurrences == 1 &&
              mostCommonSymptom != null &&
              mostCommonSymptom != 'good' &&
              mostCommonSymptom != 'energy') {
            trackedIngredientsCount++;
          }
        }

        String recommendationMessage =
            '$symptomName is your most common symptom with $occurrenceCount occurrence${occurrenceCount == 1 ? '' : 's'} $timePeriod.';

        if (trackedIngredientsCount > 0) {
          recommendationMessage +=
              ' Some ingredients have been saved but below threshold for now.';
        }

        recommendationMessage +=
            ' Continue to track your meals to identify patterns.';

        recommendations.add(recommendationMessage);
      }
    }

    // Meal type recommendations
    if (mealTypePatterns.isNotEmpty) {
      final problematicMeals = <String>[];
      for (final entry in mealTypePatterns.entries) {
        final data = entry.value as Map<String, dynamic>;
        if (data['averageSeverity'] as double > 3.0) {
          problematicMeals.add(entry.key);
        }
      }

      if (problematicMeals.isNotEmpty) {
        // Normalize meal types to lowercase, remove duplicates, then capitalize
        final normalizedMeals = problematicMeals
            .map((meal) => meal.toLowerCase())
            .toSet()
            .map((meal) =>
                meal.isEmpty ? meal : meal[0].toUpperCase() + meal.substring(1))
            .toList();

        recommendations.add(
          'Symptoms are more severe after ${normalizedMeals.join(" and ")}. Consider lighter options.',
        );
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Keep tracking your symptoms to identify patterns. The more data, the better insights!',
      );
    }

    return recommendations;
  }
}
