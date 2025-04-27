import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../data_models/routine_item.dart';

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
      print('Error getting routine items: $e');
      return [];
    }
  }

  Future<List<RoutineItem>> _createDefaultRoutine(String userId) async {
    final defaultItems = [
      RoutineItem(
        id: 'Make Bed',
        title: 'Make Bed',
        value: '5 min',
        type: 'duration',
        isEnabled: true,
      ),
      RoutineItem(
        id: 'Meditate',
        title: 'Meditate',
        value: '10 min',
        type: 'duration',
        isEnabled: true,
      ),
      RoutineItem(
        id: 'Gym',
        title: 'Gym',
        value: '1 hour',
        type: 'duration',
        isEnabled: true,
      ),
      RoutineItem(
        id: 'Water Intake',
        title: 'Water Intake',
        value: '${userService.currentUser!.settings['waterIntake']} ml',
        type: 'quantity',
        isEnabled: true,
      ),
      RoutineItem(
        id: 'Nutrition Goal',
        title: 'Nutrition Goal',
        value: '${userService.currentUser!.settings['foodGoal']} calories',
        type: 'quantity',
        isEnabled: true,
      ),
      RoutineItem(
        id: 'Steps',
        title: 'Steps',
        value: '${userService.currentUser!.settings['targetSteps']}',
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
      print('Error updating routine item: $e');
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
      print('Error toggling routine item: $e');
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
      print('Error adding routine item: $e');
    }
  }
}
