import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data_models/user_meal.dart';
import '../helper/utils.dart';
import 'badge_service.dart';
import 'cycle_adjustment_service.dart';
import 'plant_detection_service.dart';

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

  // Track when we're updating to prevent stream from overwriting
  DateTime? _lastWaterUpdate;
  DateTime? _lastStepsUpdate;
  static const _updateCooldown = Duration(milliseconds: 500);

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

        // If "Add Food" is present, show target calories as eaten calories
        final addFoodCalories = mealTotals['Add Food'] as int? ?? 0;
        final caloriesToShow = addFoodCalories > 0
            ? targetCalories.value.toDouble()
            : totalCalories.value.toDouble();
        updateCalories(caloriesToShow, targetCalories.value);

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
          final parsedWater = (waterValue is num)
              ? waterValue.toDouble()
              : (double.tryParse(waterValue.toString()) ?? 0.0);

          // Only update if we haven't recently updated (prevent overwriting our own updates)
          final now = DateTime.now();
          if (_lastWaterUpdate == null ||
              now.difference(_lastWaterUpdate!) > _updateCooldown ||
              (parsedWater - currentWater.value).abs() > 0.01) {
            currentWater.value = parsedWater;
          } else {}
        } else {
          // Only set to 0 if we haven't recently updated
          final now = DateTime.now();
          if (_lastWaterUpdate == null ||
              now.difference(_lastWaterUpdate!) > _updateCooldown) {
            currentWater.value = 0.0;
          }
        }

        final stepsValue = data['Steps'];
        if (stepsValue != null) {
          final parsedSteps = (stepsValue is num)
              ? stepsValue.toDouble()
              : (double.tryParse(stepsValue.toString()) ?? 0.0);

          // Only update if we haven't recently updated (prevent overwriting our own updates)
          final now = DateTime.now();
          if (_lastStepsUpdate == null ||
              now.difference(_lastStepsUpdate!) > _updateCooldown ||
              (parsedSteps - currentSteps.value).abs() > 0.01) {
            currentSteps.value = parsedSteps;
          }
        } else {
          // Only set to 0 if we haven't recently updated
          final now = DateTime.now();
          if (_lastStepsUpdate == null ||
              now.difference(_lastStepsUpdate!) > _updateCooldown) {
            currentSteps.value = 0.0;
          }
        }
      } else {
        // Only set to 0 if we haven't recently updated
        final now = DateTime.now();
        if (_lastWaterUpdate == null ||
            now.difference(_lastWaterUpdate!) > _updateCooldown) {
          currentWater.value = 0.0;
        }
        if (_lastStepsUpdate == null ||
            now.difference(_lastStepsUpdate!) > _updateCooldown) {
          currentSteps.value = 0.0;
        }
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

  /// Fetch water value for a specific date (doesn't update observables)
  Future<double> getWaterForDate(String userId, DateTime date) async {
    try {
      final dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateStr);

      final docSnapshot = await userMealsRef.get();

      if (!docSnapshot.exists) {
        return 0.0;
      }

      final data = docSnapshot.data();
      if (data == null) {
        return 0.0;
      }

      final waterValue = data['Water'];
      if (waterValue != null) {
        if (waterValue is num) {
          return waterValue.toDouble();
        } else if (waterValue is String) {
          return double.tryParse(waterValue) ?? 0.0;
        }
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching water for date: $e');
      return 0.0;
    }
  }

  /// Fetch steps value for a specific date (doesn't update observables)
  Future<double> getStepsForDate(String userId, DateTime date) async {
    try {
      final dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateStr);

      final docSnapshot = await userMealsRef.get();

      if (!docSnapshot.exists) {
        return 0.0;
      }

      final data = docSnapshot.data();
      if (data == null) {
        return 0.0;
      }

      final stepsValue = data['Steps'];
      if (stepsValue != null) {
        if (stepsValue is num) {
          return stepsValue.toDouble();
        } else if (stepsValue is String) {
          return double.tryParse(stepsValue) ?? 0.0;
        }
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching steps for date: $e');
      return 0.0;
    }
  }

  // Initialize settings based on user data
  void loadSettings(Map<String, dynamic>? settings) {
    if (settings == null) {
      targetCalories.value = 0.0;
      targetWater.value = 0.0;
      return;
    }

    double baseCalories =
        (settings['foodGoal'] ?? '0').toString().trim().isEmpty
            ? 0.0
            : double.tryParse(settings['foodGoal'].toString()) ?? 0.0;

    // Apply cycle adjustments if enabled
    final cycleDataRaw = settings['cycleTracking'];
    Map<String, dynamic>? cycleData;
    if (cycleDataRaw != null && cycleDataRaw is Map) {
      cycleData = Map<String, dynamic>.from(cycleDataRaw);
    }

    if (cycleData != null && (cycleData['isEnabled'] as bool? ?? false)) {
      final lastPeriodStartStr = cycleData['lastPeriodStart'] as String?;
      if (lastPeriodStartStr != null) {
        final lastPeriodStart = DateTime.tryParse(lastPeriodStartStr);
        if (lastPeriodStart != null) {
          final cycleLength = (cycleData['cycleLength'] as num?)?.toInt() ?? 28;
          final cycleService = CycleAdjustmentService.instance;
          final phase =
              cycleService.getCurrentPhase(lastPeriodStart, cycleLength);

          final baseGoals = {
            'calories': baseCalories,
            'protein':
                double.tryParse(settings['proteinGoal']?.toString() ?? '0') ??
                    0.0,
            'carbs':
                double.tryParse(settings['carbsGoal']?.toString() ?? '0') ??
                    0.0,
            'fat':
                double.tryParse(settings['fatGoal']?.toString() ?? '0') ?? 0.0,
          };

          final adjustedGoals = cycleService.getAdjustedGoals(baseGoals, phase);
          targetCalories.value = adjustedGoals['calories'] ?? baseCalories;

          // Update macro goals if needed (for future use)
          // Note: Currently only calories are adjusted in the UI
          return;
        }
      }
    }

    targetCalories.value = baseCalories;

    targetWater.value =
        (settings['waterIntake'] ?? '0').toString().trim().isEmpty
            ? 0.0
            : double.tryParse(settings['waterIntake'].toString()) ?? 0.0;

    targetSteps.value =
        (settings['targetSteps'] ?? '0').toString().trim().isEmpty
            ? 0.0
            : double.tryParse(settings['targetSteps'].toString()) ?? 0.0;
  }

  Future<void> updateCurrentWater(String userId, double newCurrentWater,
      {DateTime? date}) async {
    try {
      // Mark that we're updating to prevent stream from overwriting
      _lastWaterUpdate = DateTime.now();

      // Update the local observable FIRST for immediate UI feedback
      // Only update if we're updating today's date, otherwise don't update the observable
      final targetDate = date ?? DateTime.now();
      final today = DateTime.now();
      final isToday = targetDate.year == today.year &&
          targetDate.month == today.month &&
          targetDate.day == today.day;

      if (isToday) {
        currentWater.value = newCurrentWater;
      }

      final dateToUse = date ?? DateTime.now();
      final dateStr =
          "${dateToUse.year}-${dateToUse.month.toString().padLeft(2, '0')}-${dateToUse.day.toString().padLeft(2, '0')}";

      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateStr);

      // Update Firestore with the new water value as a number (not string)
      await userMealsRef.set({
        'Water': newCurrentWater, // Save as number, not string
      }, SetOptions(merge: true));

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

  Future<void> updateCurrentSteps(String userId, double newCurrentSteps,
      {DateTime? date}) async {
    try {
      // Mark that we're updating to prevent stream from overwriting
      _lastStepsUpdate = DateTime.now();

      // Update the local observable FIRST for immediate UI feedback
      // Only update if we're updating today's date, otherwise don't update the observable
      final targetDate = date ?? DateTime.now();
      final today = DateTime.now();
      final isToday = targetDate.year == today.year &&
          targetDate.month == today.month &&
          targetDate.day == today.day;

      if (isToday) {
        currentSteps.value = newCurrentSteps;
      }

      final dateToUse = date ?? DateTime.now();
      final dateStr =
          "${dateToUse.year}-${dateToUse.month.toString().padLeft(2, '0')}-${dateToUse.day.toString().padLeft(2, '0')}";

      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateStr);

      // Update Firestore with the new steps value as a number (not string)
      await userMealsRef.set({
        'Steps': newCurrentSteps, // Save as number, not string
      }, SetOptions(merge: true));

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
      newCalories = newCalories;

      // Add "Add Food" meal to Firestore
      await addUserMeal(
          userService.userId ?? '',
          'Add Food',
          UserMeal(
            name: 'Add Food',
            calories: newCalories.toInt(),
            quantity: '1',
            mealId: 'Add Food',
            macros: {}, // Empty macros for placeholder meal
          ),
          DateTime.now());

      // When "Add Food" is present, show target calories as eaten calories
      updateCalories(targetCalories.toDouble(), targetCalories.toDouble());
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

      // When "Add Food" is removed, show actual total calories
      updateCalories(totalCalories.value.toDouble(), targetCalories.toDouble());
    }
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

      // Track plants from meal ingredients for Rainbow Tracker
      try {
        // Fetch the meal document to get ingredients
        if (meal.mealId.isNotEmpty && meal.mealId != 'Add Food') {
          final mealDoc =
              await firestore.collection('meals').doc(meal.mealId).get();
          if (mealDoc.exists) {
            final mealData = mealDoc.data()!;
            final ingredients =
                mealData['ingredients'] as Map<String, dynamic>?;
            if (ingredients != null && ingredients.isNotEmpty) {
              // Convert to Map<String, String> for plant tracking
              final ingredientsMap = ingredients.map(
                  (key, value) => MapEntry(key.toString(), value.toString()));

              debugPrint(
                  '🌱 Tracking plants from meal ${meal.name} (${meal.mealId}): ${ingredientsMap.keys.length} ingredients');

              // Track plants from ingredients
              await PlantDetectionService.instance.trackPlantsFromIngredients(
                userId,
                ingredientsMap,
                today,
              );

              debugPrint('🌱 Plant tracking completed for meal ${meal.name}');
            } else {
              debugPrint(
                  '🌱 No ingredients found in meal ${meal.name} (${meal.mealId})');
            }
          } else {
            debugPrint('🌱 Meal document not found: ${meal.mealId}');
          }
        } else {
          debugPrint(
              '🌱 Skipping plant tracking for meal: ${meal.name} (mealId: ${meal.mealId})');
        }
      } catch (e) {
        debugPrint('🌱 Error tracking plants from meal: $e');
        // Don't fail the meal logging if plant tracking fails
      }

      // Notification scheduling removed - too many notifications were being sent
      // Points are now shown in snackbars instead
      debugPrint(
          '✅ Meal logged: ${meal.name} to $foodType - No notification scheduled (removed to reduce notification spam)');

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
      title: "Morning, Chef 🍳",
      body:
          "Mise en place is ready. We have a high-protein goal today. Shall I prep the breakfast suggestion?",
      hour: 8,
      minute: 0,
      payload: {
        'type': 'meal_reminder',
        'mealType': 'Breakfast',
      },
    );

    // Lunch reminder
    await notificationService.scheduleDailyReminder(
      id: 1002,
      title: "Lunch Service 🥗",
      body: "Chef, lunch is on the pass. Ready to log it?",
      hour: 12,
      minute: 30,
      payload: {
        'type': 'meal_reminder',
        'mealType': 'Lunch',
      },
    );

    // Dinner reminder
    await notificationService.scheduleDailyReminder(
      id: 1003,
      title: "Dinner Service 🍽️",
      body: "Chef, dinner service is ready. Let's log it to the pass.",
      hour: 19,
      minute: 0,
      payload: {
        'type': 'meal_reminder',
        'mealType': 'Dinner',
      },
    );
  }
}
