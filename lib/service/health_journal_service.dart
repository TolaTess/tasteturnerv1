import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/health_journal_model.dart';
import '../helper/utils.dart';

class HealthJournalService extends GetxController {
  static HealthJournalService get instance {
    try {
      return Get.find<HealthJournalService>();
    } catch (e) {
      return Get.put(HealthJournalService());
    }
  }

  /// Get week ID in ISO format (YYYY-Www)
  String _getWeekId(DateTime date) {
    final weekStart = getWeekStart(date);
    final year = weekStart.year;
    
    // Calculate week number: days from Jan 1 to week start / 7, rounded up
    final jan1 = DateTime(year, 1, 1);
    final daysFromJan1 = weekStart.difference(jan1).inDays;
    final weekNumber = ((daysFromJan1 + 1) / 7).ceil();
    
    return '${year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Fetch weekly journal entry for a specific week
  Future<HealthJournalEntry?> fetchWeeklyJournalEntry(
    String userId,
    String weekId,
  ) async {
    try {
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('health_journal')
          .doc(weekId);

      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        return null;
      }

      return HealthJournalEntry.fromFirestore(weekId, docSnapshot.data()!);
    } catch (e) {
      debugPrint('Error fetching weekly journal entry: $e');
      return null;
    }
  }

  /// Fetch journal entry for a specific date (backward compatibility)
  /// Now fetches the weekly journal for that date's week
  Future<HealthJournalEntry?> fetchJournalEntry(String userId, DateTime date) async {
    try {
      final weekId = _getWeekId(date);
      return await fetchWeeklyJournalEntry(userId, weekId);
    } catch (e) {
      debugPrint('Error fetching journal entry: $e');
      return null;
    }
  }

  /// Stream weekly journal entry for real-time updates
  Stream<HealthJournalEntry?> getWeeklyJournalEntryStream(
    String userId,
    String weekId,
  ) {
    try {
      return firestore
          .collection('users')
          .doc(userId)
          .collection('health_journal')
          .doc(weekId)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) {
          return null;
        }
        return HealthJournalEntry.fromFirestore(weekId, snapshot.data()!);
      });
    } catch (e) {
      debugPrint('Error setting up weekly journal entry stream: $e');
      return Stream.value(null);
    }
  }

  /// Stream journal entry for real-time updates (backward compatibility)
  Stream<HealthJournalEntry?> getJournalEntryStream(String userId, DateTime date) {
    try {
      final weekId = _getWeekId(date);
      return getWeeklyJournalEntryStream(userId, weekId);
    } catch (e) {
      debugPrint('Error setting up journal entry stream: $e');
      return Stream.value(null);
    }
  }

  /// Get journal status for a week
  Future<String> getJournalStatus(String userId, String weekId) async {
    try {
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('health_journal')
          .doc(weekId);

      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        return 'pending';
      }

      final data = docSnapshot.data()!;
      return data['status'] as String? ?? 'pending';
    } catch (e) {
      debugPrint('Error getting journal status: $e');
      return 'pending';
    }
  }

  /// Get previous weeks (week IDs)
  List<String> getPreviousWeeks(int count, {DateTime? fromDate}) {
    final startDate = fromDate ?? DateTime.now();
    final weeks = <String>[];
    
    for (int i = 0; i < count; i++) {
      final date = startDate.subtract(Duration(days: 7 * i));
      final weekId = _getWeekId(date);
      weeks.add(weekId);
    }
    
    return weeks;
  }

  /// Check if journal entry exists for a date (backward compatibility)
  Future<bool> hasJournalEntry(String userId, DateTime date) async {
    try {
      final weekId = _getWeekId(date);
      final status = await getJournalStatus(userId, weekId);
      return status != 'pending' || status == 'completed' || status == 'generating';
    } catch (e) {
      debugPrint('Error checking journal entry: $e');
      return false;
    }
  }

  /// Add a symptom entry to health journal
  Future<void> addSymptomEntry(
    String userId,
    DateTime date,
    SymptomEntry symptom,
  ) async {
    try {
      final weekId = _getWeekId(date);
      final weekStart = getWeekStart(date);
      final weekEnd = weekStart.add(const Duration(days: 6));
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('health_journal')
          .doc(weekId);

      // Get existing entry or create new
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        final existingData = docSnapshot.data()!;
        final existingJournal = HealthJournalEntry.fromFirestore(weekId, existingData);
        
        // Add symptom to existing symptoms list
        final updatedSymptoms = List<SymptomEntry>.from(existingJournal.data.symptoms)
          ..add(symptom);
        
        // Update Firestore
        await docRef.update({
          'data.symptoms': updatedSymptoms.map((s) => s.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new journal entry with symptom
        // Note: This creates a minimal entry - full journal is usually created by cloud function
        final newJournalData = JournalData(
          nutrition: NutritionData(
            calories: MacroData(consumed: 0, goal: 0, progress: 0),
            protein: MacroData(consumed: 0, goal: 0, progress: 0),
            carbs: MacroData(consumed: 0, goal: 0, progress: 0),
            fat: MacroData(consumed: 0, goal: 0, progress: 0),
          ),
          activity: ActivityData(
            water: MacroData(consumed: 0, goal: 0, progress: 0),
            steps: MacroData(consumed: 0, goal: 0, progress: 0),
            routineCompletion: 0.0,
          ),
          meals: MealsData(
            breakfast: [],
            lunch: [],
            dinner: [],
            snacks: [],
          ),
          goals: GoalsData(
            calories: MacroData(consumed: 0, goal: 0, progress: 0),
            protein: MacroData(consumed: 0, goal: 0, progress: 0),
            carbs: MacroData(consumed: 0, goal: 0, progress: 0),
            fat: MacroData(consumed: 0, goal: 0, progress: 0),
          ),
          symptoms: [symptom],
        );
        
        final newJournal = HealthJournalEntry(
          weekId: weekId,
          weekStart: weekStart,
          weekEnd: weekEnd,
          status: 'pending',
          summary: JournalSummary(
            narrative: '',
            highlights: [],
            insights: [],
            suggestions: [],
          ),
          data: newJournalData,
          userNotes: [],
          createdAt: DateTime.now(),
        );
        
        await docRef.set(newJournal.toFirestore());
      }
    } catch (e) {
      debugPrint('Error adding symptom entry: $e');
      rethrow;
    }
  }
}

