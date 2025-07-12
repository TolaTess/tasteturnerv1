import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../data_models/badge_system_model.dart';

class BadgeService extends GetxController {
  static BadgeService instance = Get.find();

  final FirebaseFirestore _firestore = firestore;
  final RxList<Badge> availableBadges = <Badge>[].obs;
  final RxList<UserBadgeProgress> userProgress = <UserBadgeProgress>[].obs;
  final RxList<Badge> earnedBadges = <Badge>[].obs;
  final RxInt totalPoints = 0.obs;
  final RxInt streakDays = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadAvailableBadges();
  }

  /// Load all available badges from Firestore
  Future<void> loadAvailableBadges() async {
    try {
      final snapshot = await _firestore
          .collection('badges')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      availableBadges.value =
          snapshot.docs.map((doc) => Badge.fromFirestore(doc.data())).toList();
      print('availableBadges 1: ${availableBadges.length}');
    } catch (e) {
      print('Error loading badges: $e');
    }
  }

  /// Load user's badge progress and update points/streak
  Future<void> loadUserProgress(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_badge_progress')
          .doc(userId)
          .collection('badges')
          .get();

      userProgress.value = snapshot.docs
          .map((doc) => UserBadgeProgress.fromFirestore(doc.data()))
          .toList();

      // Separate earned badges
      earnedBadges.value = availableBadges
          .where((badge) => userProgress.any(
              (progress) => progress.badgeId == badge.id && progress.isEarned))
          .toList();

      // Load points and streak
      await loadUserPoints(userId);
      await loadUserStreak(userId);
    } catch (e) {
      print('Error loading user progress: $e');
    }
  }

  /// Load user's total points from Firestore
  Future<void> loadUserPoints(String userId) async {
    try {
      final doc = await _firestore.collection('points').doc(userId).get();
      if (doc.exists) {
        totalPoints.value = doc.data()?['points'] ?? 0;
      } else {
        totalPoints.value = 0;
      }
    } catch (e) {
      print('Error loading user points: $e');
      totalPoints.value = 0;
    }
  }

  /// Load user's current streak
  Future<void> loadUserStreak(String userId) async {
    try {
      streakDays.value = await _getCurrentStreak(userId);
    } catch (e) {
      print('Error loading user streak: $e');
      streakDays.value = 0;
    }
  }

  /// Award points to user with optional notification (with daily tracking)
  Future<void> awardPoints(String userId, int points, {String? reason}) async {
    try {
      // Check if this award has already been given today
      if (reason != null && await _hasBeenAwardedToday(userId, reason)) {
        print('Award already given today for: $reason');
        return;
      }

      await _updateUserPoints(userId, points);

      // Show notification if reason provided
      if (reason != null) {
        await notificationService.showNotification(
          id: 101,
          title: "Points Earned! 🏆",
          body: "$reason $points points awarded!",
        );

        // Mark this award as given today
        await _markAwardGivenToday(userId, reason);
      }
    } catch (e) {
      print('Error awarding points: $e');
    }
  }

  /// Check if a specific award has been given today
  Future<bool> _hasBeenAwardedToday(String userId, String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today =
          DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD format
      final key = 'award_${userId}_${reason}_$today';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      print('Error checking daily award: $e');
      return false;
    }
  }

  /// Mark an award as given today
  Future<void> _markAwardGivenToday(String userId, String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today =
          DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD format
      final key = 'award_${userId}_${reason}_$today';
      await prefs.setBool(key, true);

      // Clean up old entries (older than 7 days) to prevent storage bloat
      await _cleanupOldAwardEntries(userId);
    } catch (e) {
      print('Error marking award as given: $e');
    }
  }

  /// Clean up old award entries to prevent SharedPreferences bloat
  Future<void> _cleanupOldAwardEntries(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      final cutoffString = cutoffDate.toIso8601String().split('T')[0];

      for (final key in keys) {
        if (key.startsWith('award_$userId') && key.contains('_')) {
          final parts = key.split('_');
          if (parts.length >= 4) {
            final dateString = parts.last;
            if (dateString.compareTo(cutoffString) < 0) {
              await prefs.remove(key);
            }
          }
        }
      }
    } catch (e) {
      print('Error cleaning up old award entries: $e');
    }
  }

  /// Reset daily awards for a user (for testing or admin purposes)
  Future<void> resetDailyAwards(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final today = DateTime.now().toIso8601String().split('T')[0];

      for (final key in keys) {
        if (key.startsWith('award_$userId') && key.endsWith('_$today')) {
          await prefs.remove(key);
        }
      }
      print('Daily awards reset for user: $userId');
    } catch (e) {
      print('Error resetting daily awards: $e');
    }
  }

  /// Get list of awards already given today (for debugging)
  Future<List<String>> getTodaysAwards(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final todaysAwards = <String>[];

      for (final key in keys) {
        if (key.startsWith('award_$userId') && key.endsWith('_$today')) {
          // Extract the reason from the key
          final parts = key.split('_');
          if (parts.length >= 4) {
            final reason = parts.sublist(2, parts.length - 1).join('_');
            todaysAwards.add(reason);
          }
        }
      }

      return todaysAwards;
    } catch (e) {
      print('Error getting today\'s awards: $e');
      return [];
    }
  }

  /// Check and award goal-related points
  Future<void> checkGoalAchievement(String userId, String goalType,
      {double? currentValue, double? targetValue}) async {
    try {
      if (targetValue == null ||
          currentValue == null ||
          currentValue < targetValue) return;

      switch (goalType) {
        case 'water':
          await awardPoints(userId, 10, reason: "Water goal achieved!");
          await checkBadgeProgress(userId, 'water_goals_met');
          break;
        case 'steps':
          await awardPoints(userId, 10, reason: "Steps goal achieved!");
          await checkBadgeProgress(userId, 'step_goals_met');
          break;
        case 'calories':
          // Check if calories are within 90-110% of target (balanced eating)
          if (currentValue >= targetValue * 0.9 &&
              currentValue <= targetValue * 1.1) {
            await awardPoints(userId, 15, reason: "Calorie goal achieved!");
            await checkBadgeProgress(userId, 'calorie_goals_met');
          }
          break;
      }
    } catch (e) {
      print('Error checking goal achievement: $e');
    }
  }

  /// Check meal logging and award points/badges
  Future<void> checkMealLogged(String userId, String mealType) async {
    try {
      // Award points for logging meals
      await awardPoints(userId, 5, reason: "$mealType logged!");

      // Check badges
      await checkBadgeProgress(userId, 'meals_logged');

      // Update streak after meal log
      await loadUserStreak(userId);
      await checkBadgeProgress(userId, 'streak_days');
    } catch (e) {
      print('Error checking meal logged: $e');
    }
  }

  /// Listen to user points in real-time
  void listenToUserPoints(String userId) {
    _firestore.collection('points').doc(userId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        totalPoints.value = snapshot.data()?['points'] ?? 0;
      } else {
        totalPoints.value = 0;
      }
    });
  }

  /// Check and update badge progress for a user action
  Future<void> checkBadgeProgress(String userId, String actionType,
      {Map<String, dynamic>? actionData}) async {
    try {
      final relevantBadges = availableBadges
          .where((badge) => badge.criteria.type == actionType)
          .toList();

      for (final badge in relevantBadges) {
        await _evaluateBadgeProgress(userId, badge, actionData);
      }
    } catch (e) {
      print('Error checking badge progress: $e');
    }
  }

  /// Evaluate specific badge progress
  Future<void> _evaluateBadgeProgress(
      String userId, Badge badge, Map<String, dynamic>? actionData) async {
    try {
      // Get current progress
      UserBadgeProgress? currentProgress =
          userProgress.firstWhereOrNull((p) => p.badgeId == badge.id);

      // If badge already earned, skip
      if (currentProgress?.isEarned == true) return;

      // Calculate new progress based on criteria
      final newProgress =
          await _calculateProgress(userId, badge, currentProgress, actionData);

      // Check if badge is earned
      if (newProgress >= badge.criteria.target) {
        await _awardBadge(userId, badge);
      } else {
        await _updateProgress(userId, badge, newProgress);
      }
    } catch (e) {
      print('Error evaluating badge progress: $e');
    }
  }

  /// Calculate progress based on badge criteria
  Future<int> _calculateProgress(
      String userId,
      Badge badge,
      UserBadgeProgress? currentProgress,
      Map<String, dynamic>? actionData) async {
    switch (badge.criteria.type) {
      case 'meals_logged':
        return await _getMealsLoggedCount(userId);

      case 'streak_days':
        return await _getCurrentStreak(userId);

      case 'calorie_goals_met':
        return await _getCalorieGoalsMetCount(
            userId, badge.criteria.requirement == 'consecutive');

      case 'water_goals_met':
        return await _getWaterGoalsMetCount(userId);

      case 'step_goals_met':
        return await _getStepGoalsMetCount(userId);

      case 'battles_participated':
        return await _getBattlesParticipatedCount(userId);

      case 'battles_won':
        return await _getBattlesWonCount(userId);

      case 'unique_recipes_tried':
        return await _getUniqueRecipesCount(userId);

      case 'unique_ingredients_logged':
        return await _getUniqueIngredientsCount(userId);

      case 'ingredient_category_logged':
        final category = badge.criteria.additionalData?['category'];
        return await _getIngredientCategoryCount(userId, category);

      case 'perfect_days':
        return await _getPerfectDaysCount(
            userId, badge.criteria.requirement == 'consecutive');

      default:
        return currentProgress?.currentProgress ?? 0;
    }
  }

  /// Award badge to user
  Future<void> _awardBadge(String userId, Badge badge) async {
    try {
      final now = DateTime.now();
      final badgeProgress = UserBadgeProgress(
        badgeId: badge.id,
        userId: userId,
        isEarned: true,
        currentProgress: badge.criteria.target,
        targetProgress: badge.criteria.target,
        startedAt: now,
        earnedAt: now,
        lastUpdated: now,
      );

      await _firestore
          .collection('user_badge_progress')
          .doc(userId)
          .collection('badges')
          .doc(badge.id)
          .set(badgeProgress.toFirestore());

      // Update user points
      await _updateUserPoints(userId, badge.rewards.points);

      // Show notification (simplified without external dependency)
      _showBadgeNotification(badge);

      // Refresh user progress
      await loadUserProgress(userId);
    } catch (e) {
      print('Error awarding badge: $e');
    }
  }

  /// Update badge progress
  Future<void> _updateProgress(
      String userId, Badge badge, int newProgress) async {
    try {
      final now = DateTime.now();
      UserBadgeProgress? existingProgress =
          userProgress.firstWhereOrNull((p) => p.badgeId == badge.id);

      final badgeProgress = UserBadgeProgress(
        badgeId: badge.id,
        userId: userId,
        isEarned: false,
        currentProgress: newProgress,
        targetProgress: badge.criteria.target,
        startedAt: existingProgress?.startedAt ?? now,
        lastUpdated: now,
      );

      await _firestore
          .collection('user_badge_progress')
          .doc(userId)
          .collection('badges')
          .doc(badge.id)
          .set(badgeProgress.toFirestore());

      // Update local progress
      final index = userProgress.indexWhere((p) => p.badgeId == badge.id);
      if (index != -1) {
        userProgress[index] = badgeProgress;
      } else {
        userProgress.add(badgeProgress);
      }
    } catch (e) {
      print('Error updating progress: $e');
    }
  }

  /// Update user points
  Future<void> _updateUserPoints(String userId, int points) async {
    try {
      await _firestore.collection('points').doc(userId).set({
        'points': FieldValue.increment(points),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user points: $e');
    }
  }

  // Progress calculation methods
  Future<int> _getMealsLoggedCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .get();

      int totalMeals = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final meals = data['meals'] as Map<String, dynamic>? ?? {};
        for (final mealType in meals.values) {
          if (mealType is List) {
            totalMeals += mealType.length;
          }
        }
      }
      return totalMeals;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getCurrentStreak(String userId) async {
    try {
      final today = DateTime.now();
      int streak = 0;

      for (int i = 0; i < 365; i++) {
        // Max check 1 year
        final date = today.subtract(Duration(days: i));
        final dateString =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_summary')
            .doc(dateString)
            .get();

        if (doc.exists && (doc.data()?['calories'] ?? 0) > 0) {
          streak++;
        } else {
          break;
        }
      }
      return streak;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getCalorieGoalsMetCount(String userId, bool consecutive) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summary')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(consecutive ? 30 : 365)
          .get();

      final userCalorieGoal = double.tryParse(
              userService.currentUser.value?.settings['foodGoal']?.toString() ??
                  '0') ??
          0;

      if (consecutive) {
        int consecutiveCount = 0;
        for (final doc in snapshot.docs) {
          final calories = doc.data()['calories'] as int? ?? 0;
          if (calories >= userCalorieGoal * 0.9 &&
              calories <= userCalorieGoal * 1.1) {
            consecutiveCount++;
          } else {
            break;
          }
        }
        return consecutiveCount;
      } else {
        return snapshot.docs.where((doc) {
          final calories = doc.data()['calories'] as int? ?? 0;
          return calories >= userCalorieGoal * 0.9 &&
              calories <= userCalorieGoal * 1.1;
        }).length;
      }
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getWaterGoalsMetCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .get();

      final userWaterGoal = double.tryParse(userService
                  .currentUser.value?.settings['waterIntake']
                  ?.toString() ??
              '0') ??
          0;

      int goalsMetCount = 0;
      for (final doc in snapshot.docs) {
        final waterValue = doc.data()['Water'];
        final water = waterValue != null
            ? (waterValue is num
                ? waterValue.toDouble()
                : double.tryParse(waterValue.toString()) ?? 0.0)
            : 0.0;

        if (water >= userWaterGoal) {
          goalsMetCount++;
        }
      }
      return goalsMetCount;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getStepGoalsMetCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .get();

      final userStepsGoal = double.tryParse(userService
                  .currentUser.value?.settings['targetSteps']
                  ?.toString() ??
              '0') ??
          0;

      int goalsMetCount = 0;
      for (final doc in snapshot.docs) {
        final stepsValue = doc.data()['Steps'];
        final steps = stepsValue != null
            ? (stepsValue is num
                ? stepsValue.toDouble()
                : double.tryParse(stepsValue.toString()) ?? 0.0)
            : 0.0;

        if (steps >= userStepsGoal) {
          goalsMetCount++;
        }
      }
      return goalsMetCount;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getBattlesParticipatedCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('battle_votes')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getBattlesWonCount(String userId) async {
    // This would need to be implemented based on your battle results structure
    // For now, returning 0 as placeholder
    return 0;
  }

  Future<int> _getUniqueRecipesCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .get();

      final Set<String> uniqueRecipes = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final meals = data['meals'] as Map<String, dynamic>? ?? {};
        for (final mealType in meals.values) {
          if (mealType is List) {
            for (final meal in mealType) {
              if (meal['mealId'] != null && meal['mealId'] != meal['name']) {
                uniqueRecipes.add(meal['mealId']);
              }
            }
          }
        }
      }
      return uniqueRecipes.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getUniqueIngredientsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .get();

      final Set<String> uniqueIngredients = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final meals = data['meals'] as Map<String, dynamic>? ?? {};
        for (final mealType in meals.values) {
          if (mealType is List) {
            for (final meal in mealType) {
              uniqueIngredients
                  .add(meal['name']?.toString().toLowerCase() ?? '');
            }
          }
        }
      }
      return uniqueIngredients.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getIngredientCategoryCount(
      String userId, String category) async {
    try {
      final snapshot = await _firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .get();

      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final meals = data['meals'] as Map<String, dynamic>? ?? {};
        for (final mealType in meals.values) {
          if (mealType is List) {
            for (final meal in mealType) {
              // This would need ingredient category lookup
              // For now, basic implementation
              final mealName = meal['name']?.toString().toLowerCase() ?? '';
              if (category == 'vegetable' && _isVegetable(mealName)) {
                count++;
              }
            }
          }
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getPerfectDaysCount(String userId, bool consecutive) async {
    try {
      final userCalorieGoal = double.tryParse(
              userService.currentUser.value?.settings['foodGoal']?.toString() ??
                  '0') ??
          0;
      final userWaterGoal = double.tryParse(userService
                  .currentUser.value?.settings['waterIntake']
                  ?.toString() ??
              '0') ??
          0;
      final userStepsGoal = double.tryParse(userService
                  .currentUser.value?.settings['targetSteps']
                  ?.toString() ??
              '0') ??
          0;

      final today = DateTime.now();
      int perfectDays = 0;

      for (int i = 0; i < (consecutive ? 30 : 365); i++) {
        final date = today.subtract(Duration(days: i));
        final dateString =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

        // Check calories
        final summaryDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_summary')
            .doc(dateString)
            .get();

        final calories = summaryDoc.data()?['calories'] as int? ?? 0;
        final calorieGoalMet = calories >= userCalorieGoal * 0.9 &&
            calories <= userCalorieGoal * 1.1;

        // Check water and steps
        final mealsDoc = await _firestore
            .collection('userMeals')
            .doc(userId)
            .collection('meals')
            .doc(dateString)
            .get();

        final data = mealsDoc.data() ?? {};
        final waterValue = data['Water'];
        final water = waterValue != null
            ? (waterValue is num
                ? waterValue.toDouble()
                : double.tryParse(waterValue.toString()) ?? 0.0)
            : 0.0;

        final stepsValue = data['Steps'];
        final steps = stepsValue != null
            ? (stepsValue is num
                ? stepsValue.toDouble()
                : double.tryParse(stepsValue.toString()) ?? 0.0)
            : 0.0;

        final waterGoalMet = water >= userWaterGoal;
        final stepsGoalMet = steps >= userStepsGoal;

        if (calorieGoalMet && waterGoalMet && stepsGoalMet) {
          perfectDays++;
        } else if (consecutive) {
          break;
        }
      }

      return perfectDays;
    } catch (e) {
      return 0;
    }
  }

  bool _isVegetable(String itemName) {
    const vegetables = [
      'carrot',
      'broccoli',
      'spinach',
      'lettuce',
      'tomato',
      'cucumber',
      'pepper',
      'onion',
      'garlic',
      'celery',
      'kale',
      'cabbage'
    ];
    return vegetables.any((veg) => itemName.contains(veg));
  }

  /// Show badge notification (simplified implementation)
  void _showBadgeNotification(Badge badge) {
    try {
      Get.snackbar(
        '🏆 Badge Earned!',
        '${badge.title} (+${badge.rewards.points} points)',
        snackPosition: SnackPosition.TOP,
        backgroundColor: kAccent,
        colorText: kWhite,
      );
    } catch (e) {
      print('Error showing badge notification: $e');
    }
  }
}
