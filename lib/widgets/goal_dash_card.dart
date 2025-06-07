import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasteturner/screens/add_food_screen.dart';
import 'dart:ui';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../pages/edit_goal.dart';
import '../data_models/user_data_model.dart';

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
        meals = mealWithTypes
            .where((meal) =>
                meal.familyMember ==
                    displayList[selectedUserIndex]['name'].toLowerCase() ||
                meal.familyMember.isEmpty)
            .toList();
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

    final bool familyMode = userService.currentUser?.familyMode ?? false;
    final List<FamilyMember> familyMembers =
        userService.currentUser?.familyMembers ?? [];
    final List<Map<String, dynamic>> familyList =
        familyMembers.map((f) => f.toMap()).toList();

    displayList = [currentUser, ...familyList];
    user = familyMode ? displayList[selectedUserIndex] : displayList[0];
    final double cardMaxWidth = familyMode ? 400 : double.infinity;

    // Glassmorphism effect
    return Center(
      child: Stack(
        children: [
          SizedBox(
            width: cardMaxWidth,
            child: Container(
              margin: EdgeInsets.only(
                  left: getPercentageWidth(2, context),
                  right: getPercentageWidth(2, context),
                  bottom: getPercentageHeight(2, context)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: colors[selectedUserIndex % colors.length]
                        .withOpacity(0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 12),
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    colors[selectedUserIndex % colors.length].withOpacity(0.55),
                    isDarkMode
                        ? kDarkGrey.withOpacity(0.45)
                        : kWhite.withOpacity(0.45),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                // Glass effect
                backgroundBlendMode: BlendMode.overlay,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Padding(
                    padding: EdgeInsets.all(getPercentageWidth(5, context)),
                    child: Column(
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
                                      Text(
                                        capitalizeFirstLetter(
                                            user['name'] ?? ''),
                                        style: TextStyle(
                                          color:
                                              isDarkMode ? kWhite : kDarkGrey,
                                          fontWeight: FontWeight.bold,
                                          fontSize:
                                              getPercentageWidth(5.2, context),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (user['name'] ==
                                          userService.currentUser?.displayName)
                                        SizedBox(
                                            width:
                                                getPercentageWidth(2, context)),
                                      if (user['name'] ==
                                          userService.currentUser?.displayName)
                                        InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          onTap: () => Get.to(
                                              () => const AddFoodScreen()),
                                          child: Icon(Icons.add,
                                              color: kAccent,
                                              size: getPercentageWidth(
                                                  5, context)),
                                        ),
                                    ],
                                  ),
                                  if ((user['fitnessGoal'] ?? '').isNotEmpty &&
                                      showCaloriesAndGoal)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        user['fitnessGoal'],
                                        style: TextStyle(
                                          color: kAccent,
                                          fontWeight: FontWeight.w600,
                                          fontSize:
                                              getPercentageWidth(3.5, context),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Calorie badge
                            if ((user['foodGoal'] ?? '').isNotEmpty &&
                                showCaloriesAndGoal)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: getPercentageWidth(3, context),
                                    vertical:
                                        getPercentageHeight(0.8, context)),
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
                                    fontSize: getPercentageWidth(3.5, context),
                                  ),
                                ),
                              ),
                            // Edit button as floating action
                            SizedBox(width: getPercentageWidth(2, context)),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => familyMode
                                    ? user['name'] ==
                                            userService.currentUser?.displayName
                                        ? Get.to(
                                            () => const NutritionSettingsPage())
                                        : _showEditModal(user, isDarkMode)
                                    : Get.to(
                                        () => const NutritionSettingsPage()),
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: kAccent.withOpacity(0.13),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.edit,
                                      color: kAccent,
                                      size: getPercentageWidth(5, context)),
                                ),
                              ),
                            ),
                            SizedBox(width: getPercentageWidth(2, context)),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _toggleShowCaloriesAndGoal(),
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: kAccent.withOpacity(0.13),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                      showCaloriesAndGoal
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: kAccent,
                                      size: getPercentageWidth(5, context)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: getPercentageHeight(2.5, context)),
                        // Sleek horizontal progress bar
                        Obx(() {
                          // Only show progress bar for first user/current user
                          if (user['name'] !=
                              userService.currentUser?.displayName) {
                            return const SizedBox.shrink();
                          }

                          double eatenCalories = dailyDataController
                              .eatenCalories.value
                              .toDouble();
                          double targetCalories =
                              dailyDataController.targetCalories.value;
                          double progress = targetCalories > 0
                              ? (eatenCalories / targetCalories).clamp(0.0, 1.0)
                              : 0.0;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    height: 18,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: isDarkMode
                                          ? kDarkGrey.withOpacity(0.18)
                                          : kWhite.withOpacity(0.18),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 600),
                                    height: 18,
                                    width: getPercentageWidth(
                                        70 * progress, context),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        colors: [kAccent, kBlue],
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
                              SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${eatenCalories.toStringAsFixed(0)} kcal',
                                    style: TextStyle(
                                      color: kAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          getPercentageWidth(3.2, context),
                                    ),
                                  ),
                                  Text(
                                    '${targetCalories.toStringAsFixed(0)} kcal',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? kWhite.withOpacity(0.7)
                                          : kDarkGrey.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                      fontSize:
                                          getPercentageWidth(3.2, context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                        SizedBox(height: getPercentageHeight(1, context)),
                        // Meal ListView (unchanged, but with glassy card effect)
                        if (meals.isEmpty)
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                user['name'] ==
                                        userService.currentUser?.displayName
                                    ? 'No meal plan yet'
                                    : 'No meal plan for ${capitalizeFirstLetter(user['name'] ?? '')} yet',
                                style: TextStyle(
                                  color: isDarkMode ? kWhite : kDarkGrey,
                                  fontSize: getPercentageWidth(4, context),
                                ),
                              ),
                            ),
                          ),
                        Center(
                          child: Text(
                            'Today\'s meals',
                            style: TextStyle(
                              color: isDarkMode ? kWhite : kDarkGrey,
                              fontSize: getPercentageWidth(3.5, context),
                            ),
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                        if (meals.isNotEmpty)
                          SizedBox(
                            height: getPercentageHeight(15, context),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: meals.length,
                              separatorBuilder: (context, i) => SizedBox(
                                  width: getPercentageWidth(2, context)),
                              itemBuilder: (context, index) {
                                final meal = meals[index];
                                return GestureDetector(
                                  onTap: () {
                                    Get.to(() => RecipeDetailScreen(
                                        mealData: meal.meal));
                                  },
                                  child: AnimatedScale(
                                    scale: 1.0,
                                    duration: Duration(milliseconds: 200),
                                    child: Container(
                                      width: getPercentageWidth(32, context),
                                      padding: EdgeInsets.symmetric(
                                          horizontal:
                                              getPercentageWidth(2, context),
                                          vertical:
                                              getPercentageHeight(2, context)),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                _getMealIcon(meal.mealType),
                                                color: isDarkMode
                                                    ? kWhite
                                                    : kDarkGrey,
                                                size: getPercentageWidth(
                                                    4, context),
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
                                                    fontSize:
                                                        getPercentageWidth(
                                                            3.2, context),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (showCaloriesAndGoal &&
                                              meal.meal.calories != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 2.0),
                                              child: Text(
                                                '${meal.meal.calories} kcal',
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? kWhite.withOpacity(0.5)
                                                      : kDarkGrey
                                                          .withOpacity(0.5),
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
                                              color: isDarkMode
                                                  ? kWhite
                                                  : kDarkGrey,
                                              fontSize: getPercentageWidth(
                                                  3, context),
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
                        // Family selector (bottom)
                        if (familyMode)
                          Padding(
                            padding: EdgeInsets.only(
                                top: getPercentageHeight(2, context)),
                            child: SizedBox(
                              height: getPercentageHeight(7, context),
                              child: ListView.separated(
                                controller: _familyScrollController,
                                scrollDirection: Axis.horizontal,
                                itemCount: displayList.length,
                                separatorBuilder: (context, i) => SizedBox(
                                    width: getPercentageWidth(1, context)),
                                itemBuilder: (context, i) {
                                  final fam = displayList[i];
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedUserIndex = i;
                                      });
                                      loadMeals();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: i == selectedUserIndex
                                              ? kAccent
                                              : Colors.transparent,
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
                                        radius: getPercentageWidth(7, context),
                                        backgroundColor: i == selectedUserIndex
                                            ? kAccent
                                            : isDarkMode
                                                ? kDarkGrey.withOpacity(0.18)
                                                : kWhite.withOpacity(0.25),
                                        child: fam['avatar'] == null
                                            ? Icon(Icons.person,
                                                color: isDarkMode
                                                    ? kWhite
                                                    : kDarkGrey)
                                            : ClipOval(
                                                child: Image.asset(
                                                  fam['avatar'],
                                                  width: getPercentageWidth(
                                                      7, context),
                                                  height: getPercentageWidth(
                                                      7, context),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
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
