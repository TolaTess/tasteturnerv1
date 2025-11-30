import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/health_journal_model.dart';

class HealthJournalService extends GetxController {
  static HealthJournalService get instance {
    try {
      return Get.find<HealthJournalService>();
    } catch (e) {
      return Get.put(HealthJournalService());
    }
  }

  /// Fetch journal entry for a specific date
  Future<HealthJournalEntry?> fetchJournalEntry(String userId, DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('health_journal')
          .doc(dateStr);

      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        return null;
      }

      return HealthJournalEntry.fromFirestore(dateStr, docSnapshot.data()!);
    } catch (e) {
      debugPrint('Error fetching journal entry: $e');
      return null;
    }
  }

  /// Stream journal entry for real-time updates
  Stream<HealthJournalEntry?> getJournalEntryStream(String userId, DateTime date) {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      return firestore
          .collection('users')
          .doc(userId)
          .collection('health_journal')
          .doc(dateStr)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) {
          return null;
        }
        return HealthJournalEntry.fromFirestore(dateStr, snapshot.data()!);
      });
    } catch (e) {
      debugPrint('Error setting up journal entry stream: $e');
      return Stream.value(null);
    }
  }

  /// Check if journal entry exists for a date
  Future<bool> hasJournalEntry(String userId, DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('health_journal')
          .doc(dateStr);

      final docSnapshot = await docRef.get();
      return docSnapshot.exists;
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
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('health_journal')
          .doc(dateStr);

      // Get existing entry or create new
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        final existingData = docSnapshot.data()!;
        final existingJournal = HealthJournalEntry.fromFirestore(dateStr, existingData);
        
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
          date: dateStr,
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

