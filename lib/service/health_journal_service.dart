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
}

