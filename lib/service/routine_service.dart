import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../data_models/routine_item.dart';
import 'package:flutter/material.dart' show debugPrint;

class RoutineService {
  static RoutineService? _instance;

  RoutineService._();

  static RoutineService get instance {
    _instance ??= RoutineService._();
    return _instance!;
  }

  Future<List<RoutineItem>> getRoutineItems(String? userId) async {
    try {
      final String effectiveUserId = userId ?? userService.userId ?? '';
      if (effectiveUserId.isEmpty) {
        return [];
      }

      final snapshot = await firestore
          .collection('userMeals')
          .doc(effectiveUserId)
          .collection('routine')
          .get();

      if (snapshot.docs.isEmpty) {
        // Return default routine items if none exist
        return await _createDefaultRoutine(effectiveUserId);
      }

      return snapshot.docs
          .map((doc) => RoutineItem.fromMap({...doc.data(), 'title': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error getting routine items: $e');
      return [];
    }
  }

  Future<List<RoutineItem>> _createDefaultRoutine(String userId) async {
    final defaultItems = [
      RoutineItem(
        id: 'Exercise',
        title: 'Exercise',
        value: '1 hour',
        type: 'duration',
        isEnabled: true,
      ),
      RoutineItem(
        id: 'Water',
        title: 'Water',
        value: '${userService.currentUser.value!.settings['waterIntake']} ml',
        type: 'quantity',
        isEnabled: true,
      ),
      RoutineItem(
        id: 'Meals',
        title: 'Meals',
        value:
            '${userService.currentUser.value!.settings['foodGoal']} calories',
        type: 'quantity',
        isEnabled: true,
      ),
      RoutineItem(
        id: 'Steps',
        title: 'Steps',
        value: '${userService.currentUser.value!.settings['targetSteps']}',
        type: 'quantity',
        isEnabled: true,
      ),
    ];

    // Save default items to Firestore
    for (var item in defaultItems) {
      await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine')
          .doc(item.title)
          .set(item.toMap());
    }

    return defaultItems;
  }

  Future<void> updateRoutineItem(String userId, RoutineItem item) async {
    try {
      await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine')
          .doc(item.title)
          .update(item.toMap());
    } catch (e) {
      debugPrint('Error updating routine item: $e');
    }
  }

  Future<void> toggleRoutineItem(String userId, RoutineItem item) async {
    try {
      await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine')
          .doc(item.title)
          .update({'isEnabled': !item.isEnabled});
    } catch (e) {
      debugPrint('Error toggling routine item: $e');
    }
  }

  Future<void> setAllDisabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allDisabledKey', value);
  }

  Future<void> addRoutineItem(String userId, RoutineItem item) async {
    try {
      await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine')
          .doc(item.title)
          .set(item.toMap());
    } catch (e) {
      debugPrint('Error adding routine item: $e');
    }
  }

  Future<void> deleteRoutineItem(String userId, RoutineItem item) async {
    try {
      // Prevent deletion of essential items
      final essentialItems = [
        'Water Intake',
        'Nutrition Goal',
        'Steps',
        'Water',
      ];
      if (essentialItems.contains(item.title)) {
        debugPrint('Cannot delete essential routine item: ${item.title}');
        return;
      }

      await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine')
          .doc(item.title)
          .delete();
    } catch (e) {
      debugPrint('Error deleting routine item: $e');
    }
  }
}
