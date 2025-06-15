import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../data_models/profilescreen_data.dart';
import '../screens/add_food_screen.dart';
import '../screens/badges_screen.dart';
import '../service/battle_management.dart';

class WeeklyIngredientBattle extends StatefulWidget {
  const WeeklyIngredientBattle({super.key});

  @override
  State<WeeklyIngredientBattle> createState() => _WeeklyIngredientBattleState();
}

class _WeeklyIngredientBattleState extends State<WeeklyIngredientBattle> {
  final RxMap<String, int> _ingredientCounts = <String, int>{}.obs;
  final RxBool _isLoading = true.obs;
  final RxString _topIngredient1 = ''.obs;
  final RxString _topIngredient2 = ''.obs;
  final RxInt _count1 = 0.obs;
  final RxInt _count2 = 0.obs;
  final RxBool _showBadge = false.obs;
  final RxString _badgeTitle = ''.obs;
  final BadgeController _badgeController = BadgeController.instance;

  @override
  void initState() {
    super.initState();
    _initializeIngredientData();
    _scheduleWeeklyUpdate();
  }

  Future<void> _initializeIngredientData() async {
    _isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldUpdate = prefs.getBool('ingredient_battle_new_week') ?? true;

      if (shouldUpdate && DateTime.now().hour == 12) {
        // It's time to update the data
        await _loadIngredientData();

        // Save the current top ingredients for static display
        await prefs.setString('top_ingredient_1', _topIngredient1.value);
        await prefs.setString('top_ingredient_2', _topIngredient2.value);
        await prefs.setInt('count_1', _count1.value);
        await prefs.setInt('count_2', _count2.value);

        // Reset the update flag - will be set true again next Friday
        await prefs.setBool('ingredient_battle_new_week', false);
      } else {
        // Load saved static data
        _topIngredient1.value = prefs.getString('top_ingredient_1') ?? '';
        _topIngredient2.value = prefs.getString('top_ingredient_2') ?? '';
        _count1.value = prefs.getInt('count_1') ?? 0;
        _count2.value = prefs.getInt('count_2') ?? 0;
      }
    } catch (e) {
      print('Error initializing ingredient data: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _loadIngredientData() async {
    try {
      // Get meals from the last 7 days
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));

      // Get current user ID
      final userId = userService.userId;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Clear previous counts
      _ingredientCounts.clear();

      // Fetch meal plans for the last 7 days
      final mealPlansData =
          await _getMealPlansForDateRange(oneWeekAgo, now, userId);

      // Extract all meals from the meal plans
      final allMeals = <Meal>[];
      for (var mealPlan in mealPlansData) {
        if (mealPlan.containsKey('meals') && mealPlan['meals'] is List) {
          final meals = mealPlan['meals'] as List;
          for (var meal in meals) {
            if (meal is Meal) {
              allMeals.add(meal);
            }
          }
        }
      }

      // Count ingredients (excluding the ones in the excludedIngredients list)
      for (var meal in allMeals) {
        if (meal.ingredients.isNotEmpty) {
          meal.ingredients.forEach((ingredient, amount) {
            final cleanIngredient = ingredient.trim().toLowerCase();
            bool shouldExclude = excludedIngredients
                .any((excluded) => cleanIngredient.contains(excluded));

            if (cleanIngredient.isNotEmpty && !shouldExclude) {
              _ingredientCounts[cleanIngredient] =
                  (_ingredientCounts[cleanIngredient] ?? 0) + 1;
            }
          });
        }
      }

      // Sort ingredients by count
      final sortedIngredients = _ingredientCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Get top 2 ingredients (if available)
      if (sortedIngredients.length >= 2) {
        _topIngredient1.value = capitalizeFirstLetter(sortedIngredients[0].key);
        _topIngredient2.value = capitalizeFirstLetter(sortedIngredients[1].key);
        _count1.value = sortedIngredients[0].value;
        _count2.value = sortedIngredients[1].value;

        // Check for badges and possibly award a new one
        await _checkAndAwardBadges(sortedIngredients, userId);

        // If it's Friday, send the notification immediately
        if (now.weekday == 5 && now.hour == 12) {
          await notificationService.showNotification(
            id: 2001,
            title: 'Weekly Ingredient Battle Results! 🏆',
            body:
                '${_topIngredient1.value} wins this week with ${_count1.value} uses! Runner up: ${_topIngredient2.value} with ${_count2.value} uses. 10 points awarded!',
          );
          await BattleManagement.instance
              .updateUserPoints(userService.userId ?? '', 10);
        }
      }
    } catch (e) {
      print('Error loading ingredient data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getMealPlansForDateRange(
      DateTime startDate, DateTime endDate, String userId) async {
    try {
      // Query mealplans for this user within the date range
      final querySnapshot = await firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('date')
          .get();

      final mealPlansData = <Map<String, dynamic>>[];

      // Process each meal plan
      for (final doc in querySnapshot.docs) {
        final mealPlanData = doc.data();
        final mealIds = List<String>.from(mealPlanData['meals'] ?? []);

        if (mealIds.isNotEmpty) {
          // Use the meal manager to get meals - it already handles API vs regular meals
          // The getMealsByMealIds method in MealManager separates IDs that start with 'api_'
          // and uses meal_api_service for those, while fetching others from the meals collection
          final meals = await mealManager.getMealsByMealIds(mealIds);

          mealPlansData.add({
            'id': doc.id,
            'date': mealPlanData['date'],
            'meals': meals, // List of Meal objects
          });
        }
      }

      return mealPlansData;
    } catch (e) {
      print('Error fetching meal plans for date range: $e');
      return [];
    }
  }

  // Helper function to create or update a badge
  Future<void> _createOrUpdateBadge({
    required String userId,
    required String title,
    required String description,
    bool checkUserExists = true,
  }) async {
    final existingBadges = _badgeController.badgeAchievements
        .where((badge) => badge.title == title)
        .toList();

    if (existingBadges.isEmpty) {
      // Create new badge
      final newBadge = BadgeAchievementData(
        title: title,
        description: description,
        userids: [userId],
        image: tastyImage,
      );
      await _badgeController.addBadge(newBadge);
    } else if (checkUserExists) {
      // Badge exists, check if user needs to be added
      final badge = existingBadges.first;
      if (!badge.userids.contains(userId)) {
        // Add user to existing badge
        final updatedUserIds = List<String>.from(badge.userids)..add(userId);
        final updatedBadge = BadgeAchievementData(
          title: badge.title,
          description: badge.description,
          userids: updatedUserIds,
          image: tastyImage,
        );
        await _badgeController.addBadge(updatedBadge);
      }
    }

    // Show badge notification
    _showBadge.value = true;
    _badgeTitle.value = title;
  }

  Future<void> _checkAndAwardBadges(
      List<MapEntry<String, int>> sortedIngredients, String userId) async {
    try {
      // Wait for badges to be loaded
      await _badgeController.fetchBadgesByUserId(userId);

      // Top ingredient details
      final topIngredient = sortedIngredients[0].key.toLowerCase();
      final topIngredientCount = sortedIngredients[0].value;

      // Check for vegetable badges
      if (vegetables.contains(topIngredient) && topIngredientCount >= 5) {
        await _createOrUpdateBadge(
          userId: userId,
          title: 'Veggie Victor',
          description:
              'Used vegetables as your main ingredient 5+ times in a week',
        );
      }

      // Check for protein badges
      if (proteins.contains(topIngredient) && topIngredientCount >= 5) {
        await _createOrUpdateBadge(
          userId: userId,
          title: 'Protein Pro',
          description: 'Used protein-rich ingredients 5+ times in a week',
        );
      }

      // Check for variety badge
      if (sortedIngredients.length >= 5) {
        await _createOrUpdateBadge(
          userId: userId,
          title: 'Food Explorer',
          description: 'Used 5+ different ingredients in your meals this week',
        );
      }

      // Check for streak badge
      if (topIngredientCount >= 10) {
        await _createOrUpdateBadge(
          userId: userId,
          title: 'Streak Master',
          description: 'Used 10+ ingredients in a week',
        );
      }
    } catch (e) {
      print('Error checking/awarding badges: $e');
    }
  }

  Future<void> _scheduleWeeklyUpdate() async {
    try {
      final now = DateTime.now();

      // If it's Friday, set the flag for update
      if (now.weekday == 5) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('ingredient_battle_new_week', true);
      }
    } catch (e) {
      print('Error scheduling weekly update: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Obx(() {
      if (_isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(
          color: kAccent,
        ));
      }

      if (_topIngredient1.isEmpty || _topIngredient2.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isDarkMode
                ? kDarkGrey.withOpacity(0.9)
                : kWhite.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddFoodScreen()),
              );
            },
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(getPercentageWidth(2, context)),
                child: Text(
                  'Log more meals to see your top ingredients!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: getTextScale(3, context),
                    fontStyle: FontStyle.italic,
                    color: kLightGrey,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Calculate percentages for progress indicators
      final total = _count1.value + _count2.value;
      final percent1 = total > 0 ? _count1.value / total : 0.5;
      final percent2 = total > 0 ? _count2.value / total : 0.5;

      return Container(
        padding: EdgeInsets.all(getPercentageWidth(2, context)),
        decoration: BoxDecoration(
          color:
              isDarkMode ? kDarkGrey.withOpacity(0.9) : kWhite.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExpansionTile(
              collapsedIconColor: kAccent,
              iconColor: kAccent,
              textColor: kAccent,
              collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _topIngredient1.isNotEmpty,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Ingredient Tug-of-War',
                      style: TextStyle(
                        fontSize: getTextScale(4, context),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_showBadge.value)
                    GestureDetector(
                      onTap: () {
                        Get.to(() => BadgesScreen());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: kAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events,
                              size: getPercentageWidth(4, context),
                              color: kAccent,
                            ),
                            SizedBox(width: getPercentageWidth(1, context)),
                            Flexible(
                              child: Text(
                                _badgeTitle.value,
                                style: TextStyle(
                                  fontSize: getTextScale(2.5, context),
                                  fontWeight: FontWeight.w500,
                                  color: kAccent,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              children: [
                SizedBox(height: getPercentageHeight(1, context)),

                // Battle visualization
                Row(
                  children: [
                    Expanded(
                      flex: (percent1 * 100).round(),
                      child: Container(
                        height: getPercentageHeight(7, context),
                        decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(10),
                            bottomLeft: const Radius.circular(10),
                            topRight: percent2 < 0.05
                                ? const Radius.circular(10)
                                : Radius.zero,
                            bottomRight: percent2 < 0.05
                                ? const Radius.circular(10)
                                : Radius.zero,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _topIngredient1.value,
                                style: TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: getTextScale(3.5, context),
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                '${_count1.value} times',
                                style: TextStyle(
                                  color: kWhite,
                                  fontSize: getTextScale(3, context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: (percent2 * 100).round(),
                      child: Container(
                        height: getPercentageHeight(7, context),
                        decoration: BoxDecoration(
                          color: kAccentLight,
                          borderRadius: BorderRadius.only(
                            topRight: const Radius.circular(10),
                            bottomRight: const Radius.circular(10),
                            topLeft: percent1 < 0.05
                                ? const Radius.circular(10)
                                : Radius.zero,
                            bottomLeft: percent1 < 0.05
                                ? const Radius.circular(10)
                                : Radius.zero,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _topIngredient2.value,
                                style: TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: getTextScale(3.5, context),
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                '${_count2.value} times',
                                style: TextStyle(
                                  color: kWhite,
                                  fontSize: getTextScale(2.5, context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: getPercentageHeight(1, context)),
                Text(
                  'Based on your meal in last 7 days',
                  style: TextStyle(
                    fontSize: getTextScale(2.5, context),
                    fontStyle: FontStyle.italic,
                    color: isDarkMode ? kLightGrey : kDarkGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
