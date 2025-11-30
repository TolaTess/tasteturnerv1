import 'package:flutter/material.dart' show debugPrint;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/health_journal_model.dart';

class SymptomCorrelationService extends GetxController {
  static SymptomCorrelationService get instance {
    try {
      return Get.find<SymptomCorrelationService>();
    } catch (e) {
      return Get.put(SymptomCorrelationService());
    }
  }

  /// Analyze symptom patterns to find ingredient correlations
  /// Returns list of correlations where user reported same symptom 3+ times
  Future<List<SymptomCorrelation>> analyzeSymptomPatterns(
    String userId,
    String symptomType,
    int days,
  ) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));
      final dateFormat = DateFormat('yyyy-MM-dd');

      // Fetch health journal entries for date range
      final List<SymptomEntry> symptomEntries = [];
      final Map<String, int> ingredientFrequency = {}; // ingredient -> count

      // Iterate through dates
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = dateFormat.format(date);

        final journalDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('health_journal')
            .doc(dateStr)
            .get();

        if (!journalDoc.exists) continue;

        final journalData = journalDoc.data()!;
        final data = journalData['data'] as Map<String, dynamic>?;
        if (data == null) continue;

        final symptoms = data['symptoms'] as List<dynamic>? ?? [];
        
        // Filter symptoms by type
        for (var symptomData in symptoms) {
          if (symptomData is Map<String, dynamic>) {
            final symptom = SymptomEntry.fromMap(symptomData);
            if (symptom.type.toLowerCase() == symptomType.toLowerCase()) {
              symptomEntries.add(symptom);
              
              // Count ingredient frequency
              for (var ingredient in symptom.ingredients) {
                ingredientFrequency[ingredient.toLowerCase()] =
                    (ingredientFrequency[ingredient.toLowerCase()] ?? 0) + 1;
              }
            }
          }
        }
      }

      // If symptom reported less than 3 times, return empty
      if (symptomEntries.length < 3) {
        return [];
      }

      // Calculate correlations
      final List<SymptomCorrelation> correlations = [];
      final totalOccurrences = symptomEntries.length;

      ingredientFrequency.forEach((ingredient, frequency) {
        // Only include ingredients that appear in at least 50% of symptom occurrences
        final confidence = frequency / totalOccurrences;
        if (confidence >= 0.5) {
          correlations.add(SymptomCorrelation(
            ingredient: ingredient,
            symptom: symptomType,
            frequency: frequency.toDouble(),
            confidence: confidence,
          ));
        }
      });

      // Sort by confidence (highest first)
      correlations.sort((a, b) => b.confidence.compareTo(a.confidence));

      return correlations;
    } catch (e) {
      debugPrint('Error analyzing symptom patterns: $e');
      return [];
    }
  }

  /// Get all symptom correlations for the past week
  Future<List<SymptomCorrelation>> getWeeklySymptomCorrelations(
    String userId,
  ) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7));
      final dateFormat = DateFormat('yyyy-MM-dd');

      final Map<String, List<SymptomEntry>> symptomsByType = {};
      final Map<String, Map<String, int>> ingredientCountsBySymptom = {};

      // Fetch health journal entries for the week
      for (int i = 0; i < 7; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = dateFormat.format(date);

        final journalDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('health_journal')
            .doc(dateStr)
            .get();

        if (!journalDoc.exists) continue;

        final journalData = journalDoc.data()!;
        final data = journalData['data'] as Map<String, dynamic>?;
        if (data == null) continue;

        final symptoms = data['symptoms'] as List<dynamic>? ?? [];
        
        for (var symptomData in symptoms) {
          if (symptomData is Map<String, dynamic>) {
            final symptom = SymptomEntry.fromMap(symptomData);
            final symptomType = symptom.type.toLowerCase();
            
            // Group by symptom type
            if (!symptomsByType.containsKey(symptomType)) {
              symptomsByType[symptomType] = [];
              ingredientCountsBySymptom[symptomType] = {};
            }
            symptomsByType[symptomType]!.add(symptom);
            
            // Count ingredients for this symptom type
            for (var ingredient in symptom.ingredients) {
              final ingKey = ingredient.toLowerCase();
              ingredientCountsBySymptom[symptomType]![ingKey] =
                  (ingredientCountsBySymptom[symptomType]![ingKey] ?? 0) + 1;
            }
          }
        }
      }

      // Generate correlations for symptoms reported 3+ times
      final List<SymptomCorrelation> allCorrelations = [];

      symptomsByType.forEach((symptomType, entries) {
        if (entries.length >= 3) {
          final ingredientCounts = ingredientCountsBySymptom[symptomType]!;
          final totalOccurrences = entries.length;

          ingredientCounts.forEach((ingredient, frequency) {
            final confidence = frequency / totalOccurrences;
            // Only include if ingredient appears in at least 50% of occurrences
            if (confidence >= 0.5) {
              allCorrelations.add(SymptomCorrelation(
                ingredient: ingredient,
                symptom: symptomType,
                frequency: frequency.toDouble(),
                confidence: confidence,
              ));
            }
          });
        }
      });

      // Sort by confidence (highest first)
      allCorrelations.sort((a, b) => b.confidence.compareTo(a.confidence));

      return allCorrelations;
    } catch (e) {
      debugPrint('Error getting weekly symptom correlations: $e');
      return [];
    }
  }

  /// Get symptom count for a specific symptom type in the past week
  Future<int> getSymptomCount(String userId, String symptomType, int days) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));
      final dateFormat = DateFormat('yyyy-MM-dd');

      int count = 0;

      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = dateFormat.format(date);

        final journalDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('health_journal')
            .doc(dateStr)
            .get();

        if (!journalDoc.exists) continue;

        final journalData = journalDoc.data()!;
        final data = journalData['data'] as Map<String, dynamic>?;
        if (data == null) continue;

        final symptoms = data['symptoms'] as List<dynamic>? ?? [];
        
        for (var symptomData in symptoms) {
          if (symptomData is Map<String, dynamic>) {
            final symptom = SymptomEntry.fromMap(symptomData);
            if (symptom.type.toLowerCase() == symptomType.toLowerCase()) {
              count++;
            }
          }
        }
      }

      return count;
    } catch (e) {
      debugPrint('Error getting symptom count: $e');
      return 0;
    }
  }
}

