import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data_models/user_meal.dart';

class NutritionController extends GetxController {
  static NutritionController instance = Get.find();

  final RxMap<String, List<UserMeal>> userMealList =
      <String, List<UserMeal>>{}.obs;
  final RxBool isLoading = false.obs;

  // Observables for each meal type
  var breakfastCalories = 0.obs;
  var lunchCalories = 0.obs;
  var dinnerCalories = 0.obs;

  var breakfastTarget = 0.obs;
  var lunchTarget = 0.obs;
  var dinnerTarget = 0.obs;

  var targetWater = 0.0.obs;
  var currentWater = 0.0.obs;
  var targetSteps = 0.0.obs;
  var currentSteps = 0.0.obs;

  var targetCalories = 0.0.obs;
  var totalCalories = 0.obs;

  var streakDays = 0.obs;
  var pointsAchieved = 0.obs;

  final RxInt eatenCalories = 0.obs;
  final ValueNotifier<double> dailyValueNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> breakfastNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> lunchNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> dinnerNotifier = ValueNotifier<double>(0);

  /// Fetches calories for the past 7 days (including today)
  Future<Map<String, int>> fetchCaloriesByDate(String userId) async {
    if (userId.isEmpty) {
      print("Invalid user ID. Returning empty data.");
      return {};
    }

    try {
      final userMealsRef =
          firestore.collection('userMeals').doc(userId).collection('meals');
      final querySnapshot = await userMealsRef.get();

      if (querySnapshot.docs.isEmpty) {
        return {};
      }

      final today = DateTime.now();
      final lastWeekDate = today.subtract(const Duration(days: 6));
      final dateFormat = DateFormat('yyyy-MM-dd');

      return {
        for (var doc in querySnapshot.docs)
          if (doc.data().containsKey('date') && doc.data().containsKey('meals'))
            if (_isWithinLastWeek(doc['date'], dateFormat, lastWeekDate, today))
              doc['date']: _calculateDailyCalories(doc['meals'])
      };
    } catch (e) {
      print("Error fetching calories: $e");
      return {};
    }
  }

  Future<void> fetchPointsAchieved(String userId) async {
    if (userId.isEmpty) {
      pointsAchieved.value = 0;
      return;
    }

    final userMealsRef = firestore.collection('points').doc(userId);

    final docSnapshot = await userMealsRef.get();

    final data = docSnapshot.data();

    pointsAchieved.value = data?['point'] ?? 0;
  }

  Future<void> fetchStreakDays(String userId) async {
    if (userId.isEmpty) {
      streakDays.value = 0;
      return;
    }

    final today = DateTime.now();
    final lastWeekDate = today.subtract(const Duration(days: 6));
    final dateFormat = DateFormat('yyyy-MM-dd');

    final userMealsRef =
        firestore.collection('userMeals').doc(userId).collection('meals');

    final docSnapshot = await userMealsRef.get();

    // Filter documents by date after fetching
    final todayStr = dateFormat.format(today);
    final lastWeekStr = dateFormat.format(lastWeekDate);

    final data = docSnapshot.docs
        .where((doc) {
          final docDate = doc.id;
          return docDate.compareTo(lastWeekStr) >= 0 &&
              docDate.compareTo(todayStr) <= 0;
        })
        .map((doc) => doc.data())
        .toList();

    if (data.isEmpty) {
      streakDays.value = 0;
      return;
    }

    final streak = data.length;
    // Add null check and filter out any null dates
    final streakDates = data
        .map((doc) => doc['date'])
        .where((date) => date != null)
        .map((date) => date.toString())
        .toList();

    // Only update streak if we have valid dates
    streakDays.value = streakDates.isEmpty ? 0 : streak;
  }

  /// Fetches calories only for today's date
  Future<void> fetchCaloriesForDate(String userId) async {
    if (userId.isEmpty) {
      totalCalories.value = 0;
      return;
    }

    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(date);

      final docSnapshot = await userMealsRef.get();
      final data = docSnapshot.data();

      totalCalories.value = data != null && data.containsKey('meals')
          ? _calculateDailyCalories(data['meals'])
          : 0;
    } catch (e) {
      print("Error fetching calories for $date: $e");
      totalCalories.value = 0;
    }
  }

  /// Helper function to calculate total daily calories
  int _calculateDailyCalories(Map<String, dynamic> meals) {
    return meals.entries.fold<int>(0, (total, entry) {
      final mealList = entry.value as List<dynamic>? ?? [];
      return total +
          mealList.fold<int>(
              0, (sum, meal) => sum + (meal['calories'] as int? ?? 0));
    });
  }

  /// Helper function to check if the date is within the last 7 days
  bool _isWithinLastWeek(String dateString, DateFormat formatter,
      DateTime lastWeekDate, DateTime today) {
    try {
      final DateTime date = formatter.parse(dateString);
      return date.isAfter(lastWeekDate.subtract(const Duration(seconds: 1))) &&
          date.isBefore(today.add(const Duration(days: 1)));
    } catch (e) {
      print("Error parsing date: $dateString - $e");
      return false;
    }
  }

  // -------------------------------------------------------------------------------------------------------

  Future<void> fetchUserDailyMetrics(String userId) async {
    if (userId.isEmpty) {
      currentWater.value = 0.0;
      currentSteps.value = 0.0;
      return;
    }

    try {
      final today = DateTime.now();
      final date =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(date);

      final docSnapshot = await userMealsRef.get();

      if (!docSnapshot.exists) {
        currentWater.value = 0.0;
        currentSteps.value = 0.0;
        return;
      }

      final data = docSnapshot.data();
      if (data == null) {
        currentWater.value = 0.0;
        currentSteps.value = 0.0;
        return;
      }

      // Handle water value
      final waterValue = data['Water'];
      if (waterValue != null) {
        if (waterValue is num) {
          currentWater.value = waterValue.toDouble();
        } else if (waterValue is String) {
          currentWater.value = double.tryParse(waterValue) ?? 0.0;
        } else {
          currentWater.value = 0.0;
        }
      } else {
        currentWater.value = 0.0;
      }

      // Handle steps value
      final stepsValue = data['Steps'];
      if (stepsValue != null) {
        if (stepsValue is num) {
          currentSteps.value = stepsValue.toDouble();
        } else if (stepsValue is String) {
          currentSteps.value = double.tryParse(stepsValue) ?? 0.0;
        } else {
          currentSteps.value = 0.0;
        }
      } else {
        currentSteps.value = 0.0;
      }
    } catch (e) {
      print("Error fetching daily metrics: $e");
      currentWater.value = 0.0;
      currentSteps.value = 0.0;
    }
  }

  // Initialize settings based on user data
  void loadSettings(Map<String, dynamic>? settings) {
    if (settings == null) {
      targetCalories.value = 0.0;
      targetWater.value = 0.0;
      return;
    }

    targetCalories.value =
        (settings['foodGoal'] ?? '0').toString().trim().isEmpty
            ? 0.0
            : double.tryParse(settings['foodGoal'].toString()) ?? 0.0;

    targetWater.value =
        (settings['waterIntake'] ?? '0').toString().trim().isEmpty
            ? 0.0
            : double.tryParse(settings['waterIntake'].toString()) ?? 0.0;

    targetSteps.value =
        (settings['targetSteps'] ?? '0').toString().trim().isEmpty
            ? 0.0
            : double.tryParse(settings['targetSteps'].toString()) ?? 0.0;
  }

  Future<void> updateCurrentWater(String userId, double newCurrentWater) async {
    try {
      final today = DateTime.now();
      final date =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(date);

      // Update Firestore with the new water value, replacing any existing value
      await userMealsRef.set({
        'Water': newCurrentWater.toString(),
      }, SetOptions(merge: true));

      // Update the local observable
      currentWater.value = newCurrentWater;

      if (newCurrentWater >= targetWater.value) {
        await notificationService.showNotification(
          id: 101,
          title: "Water Goal Achieved! 💧",
          body: "Congratulations! You've reached your daily water intake goal!",
        );
      }
    } catch (e) {
      print("Error updating current water: $e");
      throw Exception("Failed to update current water");
    }
  }

  Future<void> updateCurrentSteps(String userId, double newCurrentSteps) async {
    try {
      final today = DateTime.now();
      final date =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(date);

      // Update Firestore with the new steps value, replacing any existing value
      await userMealsRef.set({
        'Steps': newCurrentSteps.toString(),
      }, SetOptions(merge: true));

      // Update the local observable
      currentSteps.value = newCurrentSteps;
      final targetSteps = double.parse(
          userService.currentUser?.settings['targetSteps'].toString() ?? '0');

      if (newCurrentSteps >= targetSteps) {
        await notificationService.showNotification(
          id: 101,
          title: "Steps Goal Achieved! 💧",
          body: "Congratulations! You've reached your daily steps goal!",
        );
      }
    } catch (e) {
      print("Error updating current steps: $e");
      throw Exception("Failed to update current steps");
    }
  }

// Fetch calories for a specific meal type
  Future<void> fetchCalories(String userId, String mealType) async {
    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(date);

      final docSnapshot = await userMealsRef.get();
      final data = docSnapshot.data();

      if (data == null || !data.containsKey('meals')) {
        _resetMealTypeCalories(mealType);
        return;
      }

      final meals = data['meals'] as Map<String, dynamic>? ?? {};

      if (mealType == 'Add Food') {
        // ✅ Calculate total calories from all meal types
        int totalCalories = meals.values.fold(0, (sum, mealArray) {
          return sum +
              (mealArray as List<dynamic>).fold(0, (innerSum, meal) {
                return innerSum + (meal['calories'] as int? ?? 0);
              });
        });

        updateCalories(totalCalories.toDouble(), targetCalories.value);
      } else if (meals.containsKey(mealType)) {
        // ✅ Calculate calories for the specific meal type
        final mealArray = meals[mealType] as List<dynamic>? ?? [];
        int totalCalories = mealArray.fold(
            0, (sum, meal) => sum + (meal['calories'] as int? ?? 0));

        _updateMealTypeCalories(mealType, totalCalories);
      } else {
        _resetMealTypeCalories(mealType);
      }
    } catch (e) {
      print('Error fetching calories for $mealType: $e');
      _resetMealTypeCalories(mealType);
    }
  }

  /// ✅ Update the correct meal type calories
  void _updateMealTypeCalories(String mealType, int totalCalories) {
    // Ensure we don't divide by zero and handle edge cases
    double progressPercentage = targetCalories.value <= 0
        ? 0.0
        : (totalCalories / targetCalories.value) * 100;

    // Clamp the progress value to prevent NaN or Infinity
    double safeProgressValue =
        progressPercentage.isNaN || progressPercentage.isInfinite
            ? 0.0
            : progressPercentage.clamp(0.0, 100.0);

    switch (mealType) {
      case 'Breakfast':
        breakfastCalories.value = totalCalories;
        breakfastTarget.value = (targetCalories.value * 0.30).toInt();
        breakfastNotifier.value = safeProgressValue;
        break;
      case 'Lunch':
        lunchCalories.value = totalCalories;
        lunchTarget.value = (targetCalories.value * 0.35).toInt();
        lunchNotifier.value = safeProgressValue;
        break;
      case 'Dinner':
        dinnerCalories.value = totalCalories;
        dinnerTarget.value = (targetCalories.value * 0.35).toInt();
        dinnerNotifier.value = safeProgressValue;
        break;
    }
  }

  /// ✅ Reset meal type calories to default values
  void _resetMealTypeCalories(String mealType) {
    _updateMealTypeCalories(mealType, 0);
  }

  void updateCalories(double newCalories, double targetCalories) {
    eatenCalories.value = newCalories.toInt();

    // Prevent division by zero and handle edge cases
    double progressPercentage =
        targetCalories <= 0 ? 0.0 : (newCalories / targetCalories) * 100;

    // Ensure the value is never NaN or Infinity
    double safeProgressValue =
        progressPercentage.isNaN || progressPercentage.isInfinite
            ? 0.0
            : progressPercentage.clamp(0.0, 100.0);

    // ✅ Update ValueNotifier to trigger animation with a valid value
    dailyValueNotifier.value = safeProgressValue;
  }

  Future<List<Map<String, dynamic>>> getMyChallenges(String userid) async {
    try {
      final QuerySnapshot snapshot = await firestore
          .collection('group_cha')
          .where('members', arrayContains: userid)
          .get();

      final now = DateTime.now();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            // ✅ Safely parse `endDate` from Firestore
            final String? endDateString = data['endDate'];
            final DateTime? endDate =
                endDateString != null ? DateTime.tryParse(endDateString) : null;

            // ✅ Only return if `endDate` is not expired or null
            if (endDate == null || endDate.isAfter(now)) {
              return {
                'id': doc.id,
                ...data,
              };
            }

            return null; // Exclude expired challenge
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print("Error fetching challenges: $e");
      return [];
    }
  }

  Future<void> fetchMealsForToday(String userId) async {
    try {
      final today = DateTime.now();
      final dateId = DateFormat('yyyy-MM-dd').format(today);

      final mealRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateId);

      final docSnapshot = await mealRef.get();

      if (!docSnapshot.exists) {
        userMealList.clear();
        return;
      }

      final data = docSnapshot.data()!;
      final mealsMap = Map<String, dynamic>.from(data['meals']);

      final parsedMeals = mealsMap.map((key, value) {
        if (value is! List) {
          return MapEntry(key, <UserMeal>[]);
        }

        final mealList = value.map((mealData) {
          return UserMeal.fromMap(Map<String, dynamic>.from(mealData));
        }).toList();

        return MapEntry(key, mealList);
      });

      userMealList.assignAll(parsedMeals);
      await fetchCalories(userId, 'Add Food');
    } catch (e) {
      print('Error fetching meals: $e');
    }
  }

  void clearMeals() {
    userMealList.clear();
  }

  List<UserMeal> getMealsByType(String mealType) {
    if (userMealList.containsKey(mealType)) {
      return userMealList[mealType]!;
    }
    return [];
  }

  /// Add a new user meal
  Future<void> addUserMeal(
      String userId, String foodType, UserMeal meal) async {
    try {
      final today = DateTime.now();

      final dateId = DateFormat('yyyy-MM-dd').format(today);

      final mealRef = FirebaseFirestore.instance
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateId);

      final docSnapshot = await mealRef.get();

      if (docSnapshot.exists) {
        await mealRef.update({
          'meals.$foodType': FieldValue.arrayUnion([meal.toFirestore()])
        });
      } else {
        await mealRef.set({
          'date': dateId,
          'meals': {
            foodType: [meal.toFirestore()],
          },
        });
      }

      fetchMealsForToday(userId);
    } catch (e) {
      print('Error adding meal: $e');
    }
  }

  /// Delete a user meal
  Future<void> removeMeal(String userId, String foodType, UserMeal meal) async {
    try {
      final today = DateTime.now();
      final dateId = DateFormat('yyyy-MM-dd').format(today);

      final mealRef = FirebaseFirestore.instance
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateId);

      if (foodType == 'Add Food') {
        final mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Add Food'];

        for (String type in mealTypes) {
          final mealSnapshot = await mealRef.get();
          final data = mealSnapshot.data();

          if (data != null &&
              data.containsKey('meals') &&
              (data['meals'] as Map<String, dynamic>).containsKey(type)) {
            final List<dynamic> mealList = (data['meals'][type] ?? []);

            // Check if the meal exists in this type
            if (mealList.any((m) => m['name'] == meal.name)) {
              await mealRef.update({
                'meals.$type': FieldValue.arrayRemove([meal.toFirestore()])
              });
            }
          }
        }
      } else {
        await mealRef.update({
          'meals.$foodType': FieldValue.arrayRemove([meal.toFirestore()])
        });
      }
      if (userMealList.containsKey(foodType)) {
        userMealList[foodType]!.removeWhere((m) => m.name == meal.name);
        userMealList.refresh();
      }
      await fetchCalories(userId, 'Add Food');
    } catch (e) {
      print('Error removing meal: $e');
    }
  }

  // Fetch all meal types
  Future<void> fetchAllMealData(String userId, Map<String, String> userSettings) async {
    loadSettings(userSettings);
    await fetchUserDailyMetrics(userId);
    await fetchCaloriesForDate(userId);
    await fetchCalories(userId, 'Breakfast');
    await fetchCalories(userId, 'Lunch');
    await fetchCalories(userId, 'Dinner');
    await fetchMealsForToday(userId);
    fetchPointsAchieved(userId);
    fetchStreakDays(userId);
  }

  // Add daily meal reminders
  Future<void> setupDailyMealReminders() async {
    // Breakfast reminder
    await notificationService.scheduleDailyReminder(
      id: 1001,
      title: "Breakfast Time! 🍳",
      body: "Time to log your breakfast and start your day right!",
      hour: 8,
      minute: 0,
    );

    // Lunch reminder
    await notificationService.scheduleDailyReminder(
      id: 1002,
      title: "Lunch Break! 🥗",
      body: "Don't forget to log your lunch!",
      hour: 12,
      minute: 30,
    );

    // Dinner reminder
    await notificationService.scheduleDailyReminder(
      id: 1003,
      title: "Dinner Time! 🍽️",
      body: "Remember to log your dinner!",
      hour: 19,
      minute: 0,
    );
  }
}
