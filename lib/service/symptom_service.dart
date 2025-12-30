import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/symptom_entry.dart';
import '../helper/utils.dart';

class SymptomService extends GetxController {
  static SymptomService get instance {
    if (!Get.isRegistered<SymptomService>()) {
      debugPrint('⚠️ SymptomService not registered, registering now');
      return Get.put(SymptomService());
    }
    return Get.find<SymptomService>();
  }

  /// Get week ID in ISO format (YYYY-Www) for organizing symptoms by week
  String _getWeekId(DateTime date) {
    final weekStart = getWeekStart(date);
    final year = weekStart.year;

    // Calculate week number: days from Jan 1 to week start / 7, rounded up
    final jan1 = DateTime(year, 1, 1);
    final daysFromJan1 = weekStart.difference(jan1).inDays;
    final weekNumber = ((daysFromJan1 + 1) / 7).ceil();

    return '${year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Add a symptom entry
  /// Symptoms are stored in users/{userId}/symptoms/{weekId} collection
  Future<void> addSymptomEntry(
    String userId,
    DateTime date,
    SymptomEntry symptom,
  ) async {
    try {
      final weekId = _getWeekId(date);
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('symptoms')
          .doc(weekId);

      // Get existing entry or create new
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final existingData = docSnapshot.data()!;
        final existingSymptoms = (existingData['symptoms'] as List<dynamic>?)
                ?.map((e) => SymptomEntry.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [];

        // Add symptom to existing symptoms list
        final updatedSymptoms = List<SymptomEntry>.from(existingSymptoms)
          ..add(symptom);

        // Update Firestore
        await docRef.update({
          'symptoms': updatedSymptoms.map((s) => s.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new entry with symptom
        await docRef.set({
          'weekId': weekId,
          'weekStart': Timestamp.fromDate(getWeekStart(date)),
          'weekEnd': Timestamp.fromDate(
              getWeekStart(date).add(const Duration(days: 6))),
          'symptoms': [symptom.toMap()],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error adding symptom entry: $e');
      rethrow;
    }
  }

  /// Get symptoms for a specific date
  Future<List<SymptomEntry>> getSymptomsForDate(
    String userId,
    DateTime date,
  ) async {
    try {
      final weekId = _getWeekId(date);
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('symptoms')
          .doc(weekId);

      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        return [];
      }

      final data = docSnapshot.data()!;
      final symptoms = (data['symptoms'] as List<dynamic>?)
              ?.map((e) => SymptomEntry.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];

      // Filter symptoms by the specific date
      final targetDateOnly = DateTime(date.year, date.month, date.day);
      return symptoms.where((symptom) {
        final symptomDate = DateTime(
          symptom.timestamp.year,
          symptom.timestamp.month,
          symptom.timestamp.day,
        );
        return symptomDate.isAtSameMomentAs(targetDateOnly);
      }).toList();
    } catch (e) {
      debugPrint('Error getting symptoms for date: $e');
      return [];
    }
  }

  /// Stream symptoms for a specific date (real-time updates)
  Stream<List<SymptomEntry>> getSymptomsStreamForDate(
    String userId,
    DateTime date,
  ) {
    try {
      final weekId = _getWeekId(date);
      return firestore
          .collection('users')
          .doc(userId)
          .collection('symptoms')
          .doc(weekId)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) {
          return <SymptomEntry>[];
        }

        final data = snapshot.data()!;
        final symptoms = (data['symptoms'] as List<dynamic>?)
                ?.map((e) => SymptomEntry.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [];

        // Filter symptoms by the specific date
        final targetDateOnly = DateTime(date.year, date.month, date.day);
        return symptoms.where((symptom) {
          final symptomDate = DateTime(
            symptom.timestamp.year,
            symptom.timestamp.month,
            symptom.timestamp.day,
          );
          return symptomDate.isAtSameMomentAs(targetDateOnly);
        }).toList();
      });
    } catch (e) {
      debugPrint('Error setting up symptoms stream: $e');
      return Stream.value(<SymptomEntry>[]);
    }
  }

  /// Get symptom triggers from Firestore
  /// Returns trigger data with highConfidence and mediumConfidence lists for each symptom type
  /// Falls back to null if Firestore is unavailable
  /// Tries to get document with ID 'triggers' first, then any document in the collection
  Future<Map<String, dynamic>?> getSymptomTriggers() async {
    try {
      // First try to get document with ID 'triggers'
      var docRef = firestore.collection('commonTriggers').doc('triggers');
      var docSnapshot = await docRef.get();

      // If not found, try to get any document from the collection
      if (!docSnapshot.exists) {
        debugPrint(
            '⚠️ Document "triggers" not found, trying to get any document from commonTriggers collection');
        final querySnapshot =
            await firestore.collection('commonTriggers').limit(1).get();

        if (querySnapshot.docs.isEmpty) {
          debugPrint('⚠️ No documents found in commonTriggers collection');
          return null;
        }

        docSnapshot = querySnapshot.docs.first;
        debugPrint('✅ Found document with ID: ${docSnapshot.id}');
      } else {
        debugPrint('✅ Found document with ID: triggers');
      }

      final data = docSnapshot.data()!;

      // The document structure is: { triggers: {...}, version: "...", lastUpdated: "..." }
      // Return the triggers field if it exists, otherwise return the whole document
      if (data.containsKey('triggers')) {
        debugPrint('✅ Found triggers field in document');
        return {
          'triggers': data['triggers'],
          'version': data['version'],
          'lastUpdated': data['lastUpdated'],
        };
      }

      // Fallback: return the whole document (for backward compatibility)
      debugPrint('⚠️ No triggers field found, returning entire document');
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('Error fetching symptom triggers from Firestore: $e');
      return null;
    }
  }
}
