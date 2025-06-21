import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/edit_goal.dart';
import '../data_models/user_data_model.dart';
import '../pages/profile_edit_screen.dart';
import '../screens/add_food_screen.dart';
import 'bottom_nav.dart';

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
  Map<String, dynamic> user = {};
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
    QuerySnapshot snapshot = await firestore
        .collection('mealPlans')
        .doc(userService.userId)
        .collection('date')
        .where('date', isEqualTo: formattedDate)
        .get();

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
          final mealMember = parts.length > 2 ? parts[2] : '';
          final meal = await mealManager.getMealbyMealID(mealId);
          if (meal != null) {
            mealWithTypes.add(MealWithType(
                meal: meal, mealType: mealType, familyMember: mealMember));
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        // Filter meals for selected user index
        meals = updateMealForFamily(
            mealWithTypes, displayList[selectedUserIndex]['name'], familyList);
        mealPlan = mealPlan;
      });
    }
    await firebaseService.fetchGeneralData();
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
        final List<String> goalOptions = (helperController.kidsCategory ?? [])
            .map<String>((e) => (e['name'] as String? ?? '').trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
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
              goalOptions.isNotEmpty
                  ? DropdownButtonFormField<String>(
                      value: goalOptions.contains(goalController.text.trim())
                          ? goalController.text.trim()
                          : null,
                      items: goalOptions
                          .map((goal) => DropdownMenuItem(
                                value: goal,
                                child: Text(goal),
                              ))
                          .toList(),
                      onChanged: (val) {
                        goalController.text = val ?? '';
                      },
                      decoration: InputDecoration(
                        labelText: 'Goal',
                        labelStyle: TextStyle(
                            color: isDarkMode
                                ? kWhite.withOpacity(0.5)
                                : kDarkGrey.withOpacity(0.5)),
                      ),
                      dropdownColor: isDarkMode ? kDarkGrey : kWhite,
                      style: TextStyle(color: isDarkMode ? kWhite : kDarkGrey),
                    )
                  : TextField(
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

    final bool familyMode = userService.currentUser?.familyMode ?? false;
    final List<FamilyMember> familyMembers =
        userService.currentUser?.familyMembers ?? [];
    final List<Map<String, dynamic>> familyList =
        familyMembers.map((f) => f.toMap()).toList();

    displayList = [currentUser, ...familyList];
    user = familyMode ? displayList[selectedUserIndex] : displayList[0];

    // Glassmorphism effect
    return Center(
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            child: Container(
              margin: EdgeInsets.only(
                  left: getPercentageWidth(2, context),
                  right: getPercentageWidth(2, context),
                  bottom: getPercentageHeight(2, context)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: colors[selectedUserIndex % colors.length]
                    .withOpacity(kMidOpacity),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Padding(
                  padding: EdgeInsets.all(getPercentageWidth(5, context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserDetailsSection(
                        user: user,
                        isDarkMode: isDarkMode,
                        showCaloriesAndGoal: showCaloriesAndGoal,
                        familyMode: familyMode,
                        selectedUserIndex: selectedUserIndex,
                        displayList: displayList,
                        onToggleShowCalories: _toggleShowCaloriesAndGoal,
                        onEdit: (user, isDarkMode) =>
                            _showEditModal(user, isDarkMode),
                      ),
                      if (meals.isNotEmpty)
                        MealPlanSection(
                          meals: meals,
                          mealPlan: mealPlan,
                          isDarkMode: isDarkMode,
                          showCaloriesAndGoal: showCaloriesAndGoal,
                          user: user,
                        ),
                      if (familyMode)
                        FamilySelectorSection(
                          familyMode: familyMode,
                          selectedUserIndex: selectedUserIndex,
                          displayList: displayList,
                          onSelectUser: (index) {
                            setState(() {
                              selectedUserIndex = index;
                            });
                            loadMeals();
                          },
                          isDarkMode: isDarkMode,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserDetailsSection extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isDarkMode;
  final bool showCaloriesAndGoal;
  final bool familyMode;
  final int selectedUserIndex;
  final List<Map<String, dynamic>> displayList;
  final VoidCallback onToggleShowCalories;
  final Function(Map<String, dynamic>, bool) onEdit;

  const UserDetailsSection({
    super.key,
    required this.user,
    required this.isDarkMode,
    required this.showCaloriesAndGoal,
    required this.familyMode,
    required this.selectedUserIndex,
    required this.displayList,
    required this.onToggleShowCalories,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: Avatar, Name, Calorie Badge, Edit Button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          capitalizeFirstLetter(user['name'] ?? ''),
                          style: TextStyle(
                            color: isDarkMode ? kWhite : kDarkGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: user['name'].length > 10
                                ? getTextScale(4, context)
                                : getTextScale(4.5, context),
                            letterSpacing: 0.5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (user['name'] == userService.currentUser?.displayName)
                        SizedBox(
                            width: user['name'].length > 10
                                ? getPercentageWidth(0.5, context)
                                : getPercentageWidth(1, context)),
                    ],
                  ),
                  if ((user['fitnessGoal'] ?? '').isNotEmpty &&
                      showCaloriesAndGoal)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        user['fitnessGoal'],
                        style: TextStyle(
                          color: isDarkMode ? kAccent : kWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: user['name'].length > 10
                              ? getTextScale(3, context)
                              : getTextScale(3.5, context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Calorie badge
            if ((user['foodGoal'] ?? '').isNotEmpty && showCaloriesAndGoal)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(3, context),
                    vertical: getPercentageHeight(0.8, context)),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: kAccent.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${user['foodGoal']} kcal',
                  style: TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: getTextScale(3.5, context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // Edit button as floating action
            SizedBox(width: getPercentageWidth(1, context)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (familyMode) {
                    if (user['name'] == userService.currentUser?.displayName) {
                      Get.to(() => const ProfileEditScreen());
                    } else {
                      onEdit(user, isDarkMode);
                    }
                  } else {
                    Get.to(() => const NutritionSettingsPage());
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit,
                      color: isDarkMode ? kAccent : kWhite,
                      size: getIconScale(7, context)),
                ),
              ),
            ),
            SizedBox(width: getPercentageWidth(1, context)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onToggleShowCalories,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      showCaloriesAndGoal
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: isDarkMode ? kAccent : kWhite,
                      size: getIconScale(7, context)),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(2, context)),
        // Sleek horizontal progress bar
        Obx(() {
          if (user['name'] != userService.currentUser?.displayName) {
            return const SizedBox.shrink();
          }

          double eatenCalories =
              dailyDataController.eatenCalories.value.toDouble();
          double targetCalories = dailyDataController.targetCalories.value;
          double progress = targetCalories > 0
              ? (eatenCalories / targetCalories).clamp(0.0, 1.0)
              : 0.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: getProportionalHeight(18, context),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDarkMode
                          ? kDarkGrey.withOpacity(0.18)
                          : kWhite.withOpacity(0.18),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    height: getProportionalHeight(12, context),
                    width: getPercentageWidth(100 * progress, context),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [kAccent, kAccentLight],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withOpacity(0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: getPercentageHeight(0.5, context)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${eatenCalories.toStringAsFixed(0)} kcal',
                    style: TextStyle(
                      color: isDarkMode ? kAccent : kWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: getTextScale(3.2, context),
                    ),
                  ),
                  if (targetCalories > 0 && showCaloriesAndGoal)
                    Text(
                      '${targetCalories.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        color: isDarkMode
                            ? kWhite.withOpacity(0.7)
                            : kDarkGrey.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: getTextScale(3.2, context),
                      ),
                    ),
                ],
              ),
            ],
          );
        }),
      ],
    );
  }
}

class MealPlanSection extends StatelessWidget {
  final List<MealWithType> meals;
  final Map<String, dynamic> mealPlan;
  final bool isDarkMode;
  final bool showCaloriesAndGoal;
  final Map<String, dynamic> user;

  const MealPlanSection({
    super.key,
    required this.meals,
    required this.mealPlan,
    required this.isDarkMode,
    required this.showCaloriesAndGoal,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: getPercentageHeight(1, context)),
        // Meal ListView (unchanged, but with glassy card effect)
        if (meals.isEmpty)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BottomNavSec(selectedIndex: 4),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(1, context),
                    vertical: getPercentageHeight(1, context)),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: getPercentageHeight(1, context)),
                    child: Text(
                      user['name'] == userService.currentUser?.displayName
                          ? 'Add a meal plan'
                          : 'Add a meal plan for ${capitalizeFirstLetter(user['name'] ?? '')}',
                      style: TextStyle(
                        color: isDarkMode ? kWhite : kDarkGrey,
                        fontSize: getTextScale(3.5, context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        SizedBox(height: getPercentageHeight(0.5, context)),
        if (meals.isNotEmpty &&
            (user['name'] == userService.currentUser?.displayName))
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BottomNavSec(selectedIndex: 4),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(1.2, context),
                      vertical: getPercentageHeight(0.6, context)),
                  decoration: BoxDecoration(
                    color: getDayTypeColor(
                            (mealPlan['dayType'] ?? '').replaceAll('_', ' '),
                            isDarkMode)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (meals.isNotEmpty)
                        Icon(
                          getDayTypeIcon(
                              (mealPlan['dayType'] ?? '').replaceAll('_', ' ')),
                          size: getIconScale(5.5, context),
                          color: getDayTypeColor(
                              (mealPlan['dayType'] ?? '').replaceAll('_', ' '),
                              isDarkMode),
                        ),
                      if (meals.isNotEmpty)
                        SizedBox(width: getPercentageWidth(1, context)),
                      if (meals.isNotEmpty)
                        Text(
                          (mealPlan['dayType'] ?? '').toLowerCase() ==
                                  'regular_day'
                              ? 'Meal Plan'
                              : capitalizeFirstLetter(
                                  (mealPlan['dayType'] ?? '')
                                      .replaceAll('_', ' ')),
                          style: TextStyle(
                            color: getDayTypeColor(
                                (mealPlan['dayType'] ?? '')
                                    .replaceAll('_', ' '),
                                isDarkMode),
                            fontSize: getTextScale(4, context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      SizedBox(width: getPercentageWidth(1, context)),
                      Icon(
                        Icons.edit,
                        size: getIconScale(5.5, context),
                        color: getDayTypeColor(
                            (mealPlan['dayType'] ?? '').replaceAll('_', ' '),
                            isDarkMode),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        SizedBox(height: getPercentageHeight(1.5, context)),
        if (meals.isNotEmpty)
          SizedBox(
            height: getProportionalHeight(140, context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: meals.length,
              separatorBuilder: (context, i) =>
                  SizedBox(width: getPercentageWidth(2, context)),
              itemBuilder: (context, index) {
                final meal = meals[index];
                return GestureDetector(
                  onTap: () {
                    Get.to(() => RecipeDetailScreen(mealData: meal.meal));
                  },
                  child: AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: getPercentageWidth(32, context),
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context),
                          vertical: getPercentageHeight(2, context)),
                      decoration: BoxDecoration(
                        color: kWhite.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: kAccent.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: kAccent.withOpacity(0.18),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getMealIcon(meal.mealType),
                                color: isDarkMode ? kWhite : kDarkGrey,
                                size: getPercentageWidth(4, context),
                              ),
                              SizedBox(width: getPercentageWidth(0.8, context)),
                              Expanded(
                                child: Text(
                                  capitalizeFirstLetter(meal.mealType ?? ''),
                                  style: TextStyle(
                                    color: isDarkMode ? kWhite : kDarkGrey,
                                    fontWeight: FontWeight.w600,
                                    fontSize: getTextScale(3.2, context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (showCaloriesAndGoal && meal.meal.calories != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                '${meal.meal.calories} kcal',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? kWhite.withOpacity(0.5)
                                      : kDarkGrey.withOpacity(0.5),
                                  fontWeight: FontWeight.w500,
                                  fontSize: getTextScale(2.8, context),
                                ),
                              ),
                            ),
                          Text(
                            capitalizeFirstLetter(meal.meal.title ?? ''),
                            style: TextStyle(
                              color: isDarkMode ? kWhite : kDarkGrey,
                              fontSize: meal.meal.title.length > 13
                                  ? getTextScale(2.8, context)
                                  : getTextScale(3, context),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class FamilySelectorSection extends StatelessWidget {
  final bool familyMode;
  final int selectedUserIndex;
  final List<Map<String, dynamic>> displayList;
  final Function(int) onSelectUser;
  final bool isDarkMode;

  const FamilySelectorSection({
    super.key,
    required this.familyMode,
    required this.selectedUserIndex,
    required this.displayList,
    required this.onSelectUser,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    if (!familyMode) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: getPercentageHeight(7, context),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: displayList.length,
        separatorBuilder: (context, i) =>
            SizedBox(width: getPercentageWidth(1, context)),
        itemBuilder: (context, i) {
          final fam = displayList[i];
          return GestureDetector(
            onTap: () => onSelectUser(i),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: i == selectedUserIndex ? kAccent : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  if (i == selectedUserIndex)
                    BoxShadow(
                      color: kAccent.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: CircleAvatar(
                radius: getResponsiveBoxSize(context, 20, 20),
                backgroundColor: i == selectedUserIndex
                    ? kAccent
                    : isDarkMode
                        ? kDarkGrey.withOpacity(0.18)
                        : kWhite.withOpacity(0.25),
                child: fam['avatar'] == null
                    ? _getAvatar(fam['ageGroup'], context, isDarkMode)
                    : ClipOval(
                        child: Image.asset(
                          fam['avatar'],
                          width: getResponsiveBoxSize(context, 18, 18),
                          height: getResponsiveBoxSize(context, 18, 18),
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _getAvatar(String? avatar, BuildContext context, bool isDarkMode) {
  switch (avatar?.toLowerCase()) {
    case 'infant':
    case 'baby':
      return SvgPicture.asset('assets/images/svg/baby.svg',
          height: getPercentageWidth(7, context),
          width: getPercentageWidth(7, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    case 'toddler':
      return SvgPicture.asset('assets/images/svg/toddler.svg',
          height: getPercentageWidth(7, context),
          width: getPercentageWidth(7, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    case 'child':
      return SvgPicture.asset('assets/images/svg/child.svg',
          height: getPercentageWidth(7, context),
          width: getPercentageWidth(7, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    case 'teen':
      return SvgPicture.asset('assets/images/svg/teen.svg',
          height: getPercentageWidth(6, context),
          width: getPercentageWidth(6, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    default:
      return SvgPicture.asset('assets/images/svg/adult.svg',
          height: getPercentageWidth(6, context),
          width: getPercentageWidth(6, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
  }
}

IconData _getMealIcon(String? type) {
  switch (type?.toLowerCase()) {
    case 'breakfast':
      return Icons.emoji_food_beverage;
    case 'lunch':
      return Icons.lunch_dining;
    case 'dinner':
      return Icons.dinner_dining;
    case 'snacks':
      return Icons.fastfood;
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
        fontSize: getTextScale(2, context),
      ),
    ),
  );
}
