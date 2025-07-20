import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data_models/user_meal.dart';
import '../helper/utils.dart';
import 'badge_service.dart';

class NutritionController extends GetxController {
  static NutritionController instance = Get.find();

  final RxMap<String, List<UserMeal>> userMealList =
      <String, List<UserMeal>>{}.obs;
  final RxBool isLoading = false.obs;

  // Observables for each meal type
  var breakfastCalories = 0.obs;
  var lunchCalories = 0.obs;
  var dinnerCalories = 0.obs;
  var snacksCalories = 0.obs;

  var breakfastTarget = 0.obs;
  var lunchTarget = 0.obs;
  var dinnerTarget = 0.obs;
  var snacksTarget = 0.obs;

  var targetWater = 0.0.obs;
  var currentWater = 0.0.obs;
  var targetSteps = 0.0.obs;
  var currentSteps = 0.0.obs;

  var targetCalories = 0.0.obs;
  var totalCalories = 0.obs;

  final RxInt eatenCalories = 0.obs;
  final ValueNotifier<double> dailyValueNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> breakfastNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> lunchNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> dinnerNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> snacksNotifier = ValueNotifier<double>(0);

  StreamSubscription? _summarySubscription;
  StreamSubscription? _metricsSubscription;

  @override
  void onClose() {
    _summarySubscription?.cancel();
    _metricsSubscription?.cancel();
    super.onClose();
  }

  /// Establishes a real-time listener for all daily nutritional data.
  void listenToDailyData(String userId, DateTime mDate) {
    if (userId.isEmpty) return;

    loadSettings(userService.currentUser.value?.settings);

    // Cancel previous listeners to avoid multiple streams on date change
    _summarySubscription?.cancel();
    _metricsSubscription?.cancel();

    final date = DateFormat('yyyy-MM-dd').format(mDate);

    // Listener for calculated summaries (calories, macros)
    _summarySubscription = firestore
        .collection('users')
        .doc(userId)
        .collection('daily_summary')
        .doc(date)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final mealTotals = data['mealTotals'] as Map<String, dynamic>? ?? {};

        totalCalories.value = data['calories'] as int? ?? 0;
        _updateMealTypeCalories(
            'Breakfast', mealTotals['Breakfast'] as int? ?? 0);
        _updateMealTypeCalories('Lunch', mealTotals['Lunch'] as int? ?? 0);
        _updateMealTypeCalories('Dinner', mealTotals['Dinner'] as int? ?? 0);
        _updateMealTypeCalories('Snacks', mealTotals['Snacks'] as int? ?? 0);
        updateCalories(totalCalories.value.toDouble(), targetCalories.value);

        // Check calorie goal achievement using BadgeService
        BadgeService.instance.checkGoalAchievement(userId, 'calories',
            currentValue: totalCalories.value.toDouble(),
            targetValue: targetCalories.value);
      } else {
        // Reset all calorie values if no summary document exists
        totalCalories.value = 0;
        _resetMealTypeCalories('Breakfast');
        _resetMealTypeCalories('Lunch');
        _resetMealTypeCalories('Dinner');
        _resetMealTypeCalories('Snacks');
        updateCalories(0, targetCalories.value);
      }
    });

    // Listener for manually tracked metrics (water, steps)
    _metricsSubscription = firestore
        .collection('userMeals')
        .doc(userId)
        .collection('meals')
        .doc(date)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final waterValue = data['Water'];
        if (waterValue != null) {
          currentWater.value = (waterValue is num)
              ? waterValue.toDouble()
              : (double.tryParse(waterValue.toString()) ?? 0.0);
        } else {
          currentWater.value = 0.0;
        }

        final stepsValue = data['Steps'];
        if (stepsValue != null) {
          currentSteps.value = (stepsValue is num)
              ? stepsValue.toDouble()
              : (double.tryParse(stepsValue.toString()) ?? 0.0);
        } else {
          currentSteps.value = 0.0;
        }
      } else {
        currentWater.value = 0.0;
        currentSteps.value = 0.0;
      }
    });

    // Also fetch the meal list for the day (this doesn't need to be a stream unless you want real-time adds/removes to show without a refresh)
    fetchMealsForToday(userId, mDate);
  }

  /// Fetches calories for the past 7 days (including today) from the daily_summary collection.
  Future<Map<String, int>> fetchCaloriesByDate(String userId) async {
    if (userId.isEmpty) {
      return {};
    }

    try {
      final today = DateTime.now();
      final lastWeekDate = today.subtract(const Duration(days: 6));
      final dateFormat = DateFormat('yyyy-MM-dd');
      final lastWeekDateString = dateFormat.format(lastWeekDate);

      final summaryRef = firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summary')
          .where(FieldPath.documentId,
              isGreaterThanOrEqualTo: lastWeekDateString)
          .get();

      final querySnapshot = await summaryRef;
      if (querySnapshot.docs.isEmpty) {
        return {};
      }

      return {
        for (var doc in querySnapshot.docs)
          doc.id: doc.data()['calories'] as int? ?? 0
      };
    } catch (e) {
      return {};
    }
  }

  // -------------------------------------------------------------------------------------------------------

  Future<void> fetchUserDailyMetrics(String userId, DateTime mDate) async {
    if (userId.isEmpty) {
      currentWater.value = 0.0;
      currentSteps.value = 0.0;
      return;
    }

    try {
      final date =
          "${mDate.year}-${mDate.month.toString().padLeft(2, '0')}-${mDate.day.toString().padLeft(2, '0')}";

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

      // Use BadgeService for goal achievement
      await BadgeService.instance.checkGoalAchievement(
        userId,
        'water',
        currentValue: newCurrentWater,
        targetValue: targetWater.value,
      );
    } catch (e) {
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

      // Use BadgeService for goal achievement
      await BadgeService.instance.checkGoalAchievement(
        userId,
        'steps',
        currentValue: newCurrentSteps,
        targetValue: targetSteps.value,
      );
    } catch (e) {
      throw Exception("Failed to update current steps");
    }
  }

  Future<void> updateAllCalories(double newCalories, bool addCalories) async {
    final targetCalories = this.targetCalories.value;
    if (addCalories) {
      newCalories = targetCalories - newCalories;

      // Add "Add Food" meal to Firestore
      await addUserMeal(
          userService.userId ?? '',
          'Add Food',
          UserMeal(
            name: 'Add Food',
            calories: newCalories.toInt(),
            quantity: '1',
            mealId: 'Add Food',
          ), DateTime.now());
    } else {
      final today = DateTime.now();
      final date =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      // Remove "Add Food" meal from Firestore
      final userMealRef = firestore
          .collection('userMeals')
          .doc(userService.userId ?? '')
          .collection('meals')
          .doc(date);

      await userMealRef.update({
        'meals.Add Food': FieldValue.delete(),
      });
    }

    updateCalories(newCalories.toDouble(), targetCalories.toDouble());
  }

  /// ✅ Update the correct meal type calories
  void _updateMealTypeCalories(String mealType, int totalCalories) {
    switch (mealType) {
      case 'Breakfast':
        breakfastCalories.value = totalCalories;
        breakfastTarget.value = (targetCalories.value * 0.20).toInt();

        // Calculate progress percentage for breakfast
        double breakfastProgress = breakfastTarget.value <= 0
            ? 0.0
            : (totalCalories / breakfastTarget.value) * 100;

        breakfastNotifier.value =
            breakfastProgress.isNaN || breakfastProgress.isInfinite
                ? 0.0
                : breakfastProgress.clamp(0.0, 100.0);
        break;

      case 'Lunch':
        lunchCalories.value = totalCalories;
        lunchTarget.value = (targetCalories.value * 0.35).toInt();

        // Calculate progress percentage for lunch
        double lunchProgress = lunchTarget.value <= 0
            ? 0.0
            : (totalCalories / lunchTarget.value) * 100;

        lunchNotifier.value = lunchProgress.isNaN || lunchProgress.isInfinite
            ? 0.0
            : lunchProgress.clamp(0.0, 100.0);
        break;

      case 'Dinner':
        dinnerCalories.value = totalCalories;
        dinnerTarget.value = (targetCalories.value * 0.35).toInt();

        // Calculate progress percentage for dinner
        double dinnerProgress = dinnerTarget.value <= 0
            ? 0.0
            : (totalCalories / dinnerTarget.value) * 100;

        dinnerNotifier.value = dinnerProgress.isNaN || dinnerProgress.isInfinite
            ? 0.0
            : dinnerProgress.clamp(0.0, 100.0);
        break;
      case 'Snacks':
        snacksCalories.value = totalCalories;
        snacksTarget.value = (targetCalories.value * 0.10).toInt();

        // Calculate progress percentage for snacks
        double snacksProgress = snacksTarget.value <= 0
            ? 0.0
            : (totalCalories / snacksTarget.value) * 100;

        snacksNotifier.value = snacksProgress.isNaN || snacksProgress.isInfinite
            ? 0.0
            : snacksProgress.clamp(0.0, 100.0);
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

  Future<void> fetchMealsForToday(String userId, DateTime mDate) async {
    try {
      final dateId = DateFormat('yyyy-MM-dd').format(mDate);

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
    } catch (e) {
      return;
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
      String userId, String foodType, UserMeal meal, DateTime mDate) async {
    try {
      final today = mDate;

      final dateId = DateFormat('yyyy-MM-dd').format(today);

      final mealRef = firestore
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

      // Use BadgeService for meal logging
      await BadgeService.instance.checkMealLogged(userId, foodType);

      fetchMealsForToday(userId, today);
    } catch (e) {
      return;
    }
  }

  /// Delete a user meal
  Future<void> removeMeal(
      String userId, String foodType, UserMeal meal, DateTime mDate) async {
    try {
      String dateId = '';
      if (getCurrentDate(mDate)) {
        final today = DateTime.now();
        dateId = DateFormat('yyyy-MM-dd').format(today);
      } else {
        Get.snackbar(
          'Error',
          'You cannot remove a meal from a previous day',
          colorText: kRed,
          backgroundColor: kDarkGrey,
        );
      }

      final mealRef = firestore
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
    } catch (e) {
      return;
    }
  }

  // Fetch all meal types
  Future<void> fetchAllMealData(
      String userId, Map<String, dynamic>? userSettings, DateTime date) async {
    loadSettings(userSettings);
    listenToDailyData(userId, date);
    if (getCurrentDate(date)) {
      // Load points and streak from BadgeService
      await BadgeService.instance.loadUserPoints(userId);
      await BadgeService.instance.loadUserStreak(userId);
    }
  }

  Future<void> fetchAllMealDataByDate(
      String userId, Map<String, dynamic>? userSettings, DateTime date) async {
    loadSettings(userSettings);
    listenToDailyData(userId, date);
  }

  void resetCalories() {
    eatenCalories.value = breakfastCalories.value +
        lunchCalories.value +
        dinnerCalories.value +
        snacksCalories.value;
    double progressPercentage = targetCalories.value <= 0
        ? 0.0
        : (eatenCalories.value / targetCalories.value) * 100;

    double safeProgressValue =
        progressPercentage.isNaN || progressPercentage.isInfinite
            ? 0.0
            : progressPercentage.clamp(0.0, 100.0);

    dailyValueNotifier.value = safeProgressValue;
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
