import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../pages/edit_goal.dart';
import '../data_models/user_data_model.dart';
import 'date_widget.dart';

class DailyNutritionOverview extends StatefulWidget {
  final Map<String, dynamic> settings;
  final DateTime currentDate;
  final bool familyMode;

  const DailyNutritionOverview({
    super.key,
    required this.settings,
    required this.currentDate,
    this.familyMode = false,
  });

  @override
  State<DailyNutritionOverview> createState() =>
      _DailyNutritionOverview1State();
}

class _DailyNutritionOverview1State extends State<DailyNutritionOverview> {
  int selectedUserIndex = 0;
  List<Map<String, dynamic>> familyList = [];
  bool showCaloriesAndGoal = true;
  List<Map<String, dynamic>> displayList = [];
  Map<String, dynamic> mealPlan = {};
  List<MealWithType> meals = [];
  final colors = [
    kAccent.withOpacity(kMidOpacity),
    kBlue.withOpacity(kMidOpacity),
    kAccentLight.withOpacity(kMidOpacity),
    kPurple.withOpacity(kMidOpacity),
    kPink.withOpacity(kMidOpacity)
  ];

  static const String _showCaloriesPrefKey = 'showCaloriesAndGoal';

  final ScrollController _familyScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadShowCaloriesPref();
    loadMeals();
  }

  Future<void> loadMeals() async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.currentDate);
    QuerySnapshot snapshot;
    if (widget.familyMode) {
      snapshot = await firestore
          .collection('shared_calendars')
          .doc(userService.userId)
          .collection('date')
          .where('date', isEqualTo: formattedDate)
          .get();
    } else {
      snapshot = await firestore
          .collection('mealPlans')
          .doc(userService.userId)
          .collection('date')
          .where('date', isEqualTo: formattedDate)
          .get();
    }

    List<MealWithType> mealWithTypes = [];

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data() as Map<String, dynamic>?;
      mealPlan = data ?? {};
      final mealsList = data?['meals'] as List<dynamic>? ?? [];
      for (final item in mealsList) {
        if (item is String && item.contains('/')) {
          final parts = item.split('/');
          final mealId = parts[0];
          final mealType = parts.length > 1 ? parts[1] : '';
          final meal = await mealManager.getMealbyMealID(mealId);
          if (meal != null) {
            mealWithTypes.add(MealWithType(meal: meal, mealType: mealType));
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        meals = mealWithTypes;
        mealPlan = mealPlan;
      });
    }
  }

  @override
  void dispose() {
    _familyScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadShowCaloriesPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      showCaloriesAndGoal = prefs.getBool(_showCaloriesPrefKey) ?? true;
    });
  }

  Future<void> _saveShowCaloriesPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showCaloriesPrefKey, value);
  }

  void _toggleShowCaloriesAndGoal() {
    setState(() {
      showCaloriesAndGoal = !showCaloriesAndGoal;
    });
    _saveShowCaloriesPref(showCaloriesAndGoal);
  }

  void _showEditModal(Map<String, dynamic> user, bool isDarkMode) async {
    // Get the latest familyMembers list from the user model
    final List<FamilyMember> currentFamilyMembers =
        userService.currentUser?.familyMembers ?? [];
    final List<Map<String, dynamic>> familyList =
        currentFamilyMembers.map((f) => f.toMap()).toList();

    final nameController = TextEditingController(text: user['name'] ?? '');
    final goalController =
        TextEditingController(text: user['fitnessGoal'] ?? '');
    final calorieController =
        TextEditingController(text: user['foodGoal'] ?? '');

    final originalName = user['name'];
    final originalAgeGroup = user['ageGroup'];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
              'Edit ${capitalizeFirstLetter(user['name'] ?? '')} Details',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? kWhite : kDarkGrey)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                style: TextStyle(color: isDarkMode ? kWhite : kDarkGrey),
                controller: nameController,
                decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(
                        color: isDarkMode
                            ? kWhite.withOpacity(0.5)
                            : kDarkGrey.withOpacity(0.5))),
              ),
              TextField(
                controller: goalController,
                style: TextStyle(color: isDarkMode ? kWhite : kDarkGrey),
                decoration: InputDecoration(
                  labelText: 'Goal',
                  labelStyle: TextStyle(
                      color: isDarkMode
                          ? kWhite.withOpacity(0.5)
                          : kDarkGrey.withOpacity(0.5)),
                ),
              ),
              TextField(
                controller: calorieController,
                style: TextStyle(color: isDarkMode ? kWhite : kDarkGrey),
                decoration: InputDecoration(
                  labelText: 'Calorie Target',
                  labelStyle: TextStyle(
                      color: isDarkMode
                          ? kWhite.withOpacity(0.5)
                          : kDarkGrey.withOpacity(0.5)),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style: TextStyle(color: isDarkMode ? kWhite : kDarkGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                // Update the user map with new values
                user['name'] = nameController.text;
                user['fitnessGoal'] = goalController.text;
                user['foodGoal'] = calorieController.text;

                // Find the index using the original values
                final index = familyList.indexWhere((member) =>
                    member['name'] == originalName &&
                    member['ageGroup'] == originalAgeGroup);

                final updatedFamilyList =
                    List<Map<String, dynamic>>.from(familyList);

                if (index != -1) {
                  updatedFamilyList[index] = Map<String, dynamic>.from(user);
                } else {
                  updatedFamilyList.add(Map<String, dynamic>.from(user));
                }

                // Save the updated list to Firestore and userService
                await firestore
                    .collection('users')
                    .doc(userService.userId)
                    .update({
                  'familyMembers': updatedFamilyList,
                });
                userService.setUser(userService.currentUser!.copyWith(
                  familyMembers: updatedFamilyList
                      .map((f) => FamilyMember.fromMap(f))
                      .toList(),
                ));

                Get.snackbar('Success', 'Settings updated successfully!',
                    snackPosition: SnackPosition.BOTTOM);
                Navigator.of(context).pop();
              },
              child: Text('Save',
                  style: TextStyle(color: isDarkMode ? kWhite : kDarkGrey)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final currentUser = {
      'name': userService.currentUser?.displayName ?? '',
      'fitnessGoal': userService.currentUser?.settings['fitnessGoal'] ?? '',
      'foodGoal': userService.currentUser?.settings['foodGoal'] ?? '',
      'meals': [],
      'avatar': null,
    };

    // Use the new FamilyMember model
    final bool familyMode = userService.currentUser?.familyMode ?? false;
    final List<FamilyMember> familyMembers =
        userService.currentUser?.familyMembers ?? [];
    final List<Map<String, dynamic>> familyList =
        familyMembers.map((f) => f.toMap()).toList();

    final displayList = [currentUser, ...familyList];

    final user = familyMode ? displayList[selectedUserIndex] : displayList[0];
    final double cardMaxWidth = familyMode ? 400 : double.infinity;
    return Center(
      child: Stack(
        children: [
          SizedBox(
            width: cardMaxWidth,
            child: Container(
              margin: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context),
                  vertical: getPercentageHeight(2, context)),
              decoration: BoxDecoration(
                color: colors[selectedUserIndex % colors.length],
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: colors[selectedUserIndex % colors.length]
                        .withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(getPercentageWidth(4, context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Obx(() {
                          double eatenCalories = dailyDataController
                              .eatenCalories.value
                              .toDouble();

                          double targetCalories =
                              dailyDataController.targetCalories.value;

                          double remainingValue = targetCalories <= 0
                              ? 0.0
                              : (targetCalories - eatenCalories)
                                  .clamp(0.0, targetCalories);

                          return CustomCircularProgressBar(
                            valueNotifier:
                                dailyDataController.dailyValueNotifier,
                            remainingCalories: remainingValue,
                            currentDate: widget.currentDate,
                          );
                        }),
                        SizedBox(width: getPercentageWidth(3, context)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showCaloriesAndGoal)
                                Text(
                                  '${user['foodGoal']} kcal/day',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? kWhite.withOpacity(0.85)
                                        : kDarkGrey.withOpacity(0.85),
                                    fontWeight: FontWeight.w500,
                                    fontSize: getPercentageWidth(4, context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit,
                              color: isDarkMode ? kWhite : kDarkGrey,
                              size: getPercentageWidth(5, context)),
                          onPressed: () => familyMode
                              ? user['name'] ==
                                      userService.currentUser?.displayName
                                  ? Get.to(() => const NutritionSettingsPage())
                                  : _showEditModal(user, isDarkMode)
                              : Get.to(() => const NutritionSettingsPage()),
                          tooltip: 'Edit details',
                        ),
                        IconButton(
                          icon: Icon(
                            showCaloriesAndGoal
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: isDarkMode ? kWhite : kDarkGrey,
                            size: getPercentageWidth(5, context),
                          ),
                          onPressed: _toggleShowCaloriesAndGoal,
                          tooltip: showCaloriesAndGoal
                              ? 'Hide calories/goal'
                              : 'Show calories/goal',
                        ),
                      ],
                    ),
                    if ((user['foodGoal'] ?? '').isNotEmpty && meals.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                        child: Row(
                          children: [
                            if (meals.isNotEmpty)
                              Icon(
                                getDayTypeIcon(
                                    mealPlan['dayType'].replaceAll('_', ' ')),
                                size: getPercentageWidth(4, context),
                                color: getDayTypeColor(
                                    mealPlan['dayType'].replaceAll('_', ' '),
                                    isDarkMode),
                              ),
                            if (meals.isNotEmpty) const SizedBox(width: 4),
                            if (meals.isNotEmpty)
                              Text(
                                capitalizeFirstLetter(
                                    mealPlan['dayType'].replaceAll('_', ' ')),
                                style: TextStyle(
                                  color: getDayTypeColor(
                                      mealPlan['dayType'].replaceAll('_', ' '),
                                      isDarkMode),
                                  fontSize: getPercentageWidth(4, context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (meals.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            user['name'] == userService.currentUser?.displayName
                                ? 'No meal plan yet'
                                : 'No meal plan for ${capitalizeFirstLetter(user['name'] ?? '')} yet',
                            style: TextStyle(
                              color: isDarkMode ? kWhite : kDarkGrey,
                              fontSize: getPercentageWidth(4, context),
                            ),
                          ),
                        ),
                      ),
                    if (meals.isNotEmpty)
                      SizedBox(
                        height: getPercentageHeight(15, context),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: meals.length,
                          separatorBuilder: (context, i) =>
                              SizedBox(width: getPercentageWidth(2, context)),
                          itemBuilder: (context, index) {
                            final meal = meals[index];
                            return GestureDetector(
                              onTap: () {
                                Get.to(() =>
                                    RecipeDetailScreen(mealData: meal.meal));
                              },
                              child: Container(
                                width: getPercentageWidth(32, context),
                                padding: EdgeInsets.symmetric(
                                    horizontal: getPercentageWidth(2, context),
                                    vertical: getPercentageHeight(2, context)),
                                decoration: BoxDecoration(
                                  color: getDayTypeColor(
                                          mealPlan['dayType']
                                              .replaceAll('_', ' '),
                                          isDarkMode)
                                      .withOpacity(0.13),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _getMealIcon(meal.mealType),
                                          color:
                                              isDarkMode ? kWhite : kDarkGrey,
                                          size: getPercentageWidth(4, context),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            capitalizeFirstLetter(
                                                meal.mealType ?? ''),
                                            style: TextStyle(
                                              color: isDarkMode
                                                  ? kWhite
                                                  : kDarkGrey,
                                              fontWeight: FontWeight.w600,
                                              fontSize: getPercentageWidth(
                                                  3.2, context),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (showCaloriesAndGoal &&
                                        meal.meal.calories != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          '${meal.meal.calories} kcal',
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? kWhite.withOpacity(0.5)
                                                : kDarkGrey.withOpacity(0.5),
                                            fontWeight: FontWeight.w500,
                                            fontSize: getPercentageWidth(
                                                2.8, context),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      capitalizeFirstLetter(
                                          meal.meal.title ?? ''),
                                      style: TextStyle(
                                        color: isDarkMode ? kWhite : kDarkGrey,
                                        fontSize:
                                            getPercentageWidth(3, context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    // Family user selector (if in family mode)
                    if (familyMode)
                      Padding(
                        padding: EdgeInsets.only(
                            top: getPercentageHeight(2, context)),
                        child: SizedBox(
                          height: getPercentageHeight(6, context),
                          child: Scrollbar(
                            controller: _familyScrollController,
                            thumbVisibility: true,
                            radius: Radius.circular(
                                getPercentageWidth(10, context)),
                            child: ListView.separated(
                              controller: _familyScrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: displayList.length,
                              separatorBuilder: (context, i) => SizedBox(
                                  width: getPercentageWidth(2, context)),
                              itemBuilder: (context, i) {
                                final fam = displayList[i];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedUserIndex = i;
                                    });
                                  },
                                  child: CircleAvatar(
                                    radius: getPercentageWidth(10, context),
                                    backgroundColor: i == selectedUserIndex
                                        ? kAccent
                                        : isDarkMode
                                            ? kDarkGrey.withOpacity(0.18)
                                            : kWhite.withOpacity(0.25),
                                    child: fam['avatar'] == null
                                        ? Icon(Icons.person,
                                            color:
                                                isDarkMode ? kWhite : kDarkGrey)
                                        : ClipOval(
                                            child: Image.asset(
                                              fam['avatar'],
                                              width: getPercentageWidth(
                                                  5, context),
                                              height: getPercentageWidth(
                                                  5, context),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (showCaloriesAndGoal && (user['fitnessGoal'] ?? '').isNotEmpty)
            Positioned(
              top: getPercentageHeight(0, context),
              right: getPercentageWidth(5, context),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(0.5, context)),
                decoration: BoxDecoration(
                  color: isDarkMode ? kDarkGrey : kWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user['fitnessGoal'],
                  style: TextStyle(
                    color: isDarkMode ? kWhite : kDarkGrey,
                    fontWeight: FontWeight.w500,
                    fontSize: getPercentageWidth(4, context),
                  ),
                ),
              ),
            ),
          Positioned(
            top: getPercentageHeight(0, context),
            left: getPercentageWidth(5, context),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context),
                  vertical: getPercentageHeight(0.5, context)),
              decoration: BoxDecoration(
                color: isDarkMode ? kDarkGrey : kWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                capitalizeFirstLetter(user['name'] ?? ''),
                style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontWeight: FontWeight.bold,
                  fontSize: getPercentageWidth(4.5, context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _getMealIcon(String? type) {
  switch (type?.toLowerCase()) {
    case 'breakfast':
      return Icons.free_breakfast;
    case 'lunch':
      return Icons.lunch_dining;
    case 'dinner':
      return Icons.dinner_dining;
    case 'snacks':
      return Icons.emoji_food_beverage;
    default:
      return Icons.restaurant_menu;
  }
}

Widget _buildTagChip(dynamic tag, BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    margin: const EdgeInsets.only(top: 2),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.22),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      tag.toString(),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontSize: getPercentageWidth(2, context),
      ),
    ),
  );
}
