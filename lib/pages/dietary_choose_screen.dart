import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/ingredient_model.dart';
import '../helper/helper_files.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';

class ChooseDietScreen extends StatefulWidget {
  const ChooseDietScreen({
    super.key,
    this.isOnboarding = false,
    this.onPreferencesSelected,
    this.isDontShowPicker = false,
    this.familyMemberName,
    this.familyMemberKcal,
    this.familyMemberGoal,
    this.familyMemberType,
  });

  final bool isOnboarding;
  final Function(String diet, Set<String> allergies, String cuisineType)?
      onPreferencesSelected;
  final bool isDontShowPicker;
  final String? familyMemberName;
  final String? familyMemberKcal;
  final String? familyMemberGoal;
  final String? familyMemberType;
  @override
  State<ChooseDietScreen> createState() => _ChooseDietScreenState();
}

class _ChooseDietScreenState extends State<ChooseDietScreen> {
  String selectedDiet = 'None';
  Set<String> selectedAllergies = {};
  String goal = 'Healthy Eating';
  int proteinDishes = 2;
  int grainDishes = 2;
  int vegDishes = 3;
  String selectedCuisine = 'Balanced';

  List<Map<String, dynamic>> cuisineTypes = [];
  List<Map<String, dynamic>> dietTypes = [];

  @override
  void initState() {
    super.initState();
    goal = userService.currentUser.value?.settings['fitnessGoal'] ??
        'Healthy Eating';

    // Initialize from helperController (reactive lists)
    cuisineTypes = List<Map<String, dynamic>>.from(helperController.headers);
    dietTypes = List<Map<String, dynamic>>.from(helperController.category);

    // Listen to changes in reactive lists
    ever(helperController.headers, (value) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          cuisineTypes = List<Map<String, dynamic>>.from(value);
        });
      });
    });

    ever(helperController.category, (value) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          dietTypes = List<Map<String, dynamic>>.from(value);
        });
      });
    });

    if (!widget.isOnboarding) {
      _checkExistingPreferences();
    }
  }

  Future<void> _checkExistingPreferences() async {
    final userId = userService.userId;
    if (userId == null) return;

    final hasPreferences = await _fetchUserPreferences(userId);
    if (hasPreferences && mounted) {
      _showExistingPreferencesDialog();
    }
  }

  void _showExistingPreferencesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final dietPreference = selectedDiet;

        // Use family member's goal and calorie target if available, otherwise use main user's
        final fitnessGoal = widget.familyMemberGoal ?? goal;

        final allergies = selectedAllergies.isEmpty
            ? ['No allergies']
            : selectedAllergies.toList();
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor:
              getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            'Existing Preferences Found',
            style: TextStyle(
              color: getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.familyMemberName != null
                    ? 'You already have the following preferences for ${capitalizeFirstLetter(widget.familyMemberName!)}:'
                    : 'You already have the following preferences:',
                style: TextStyle(
                  color:
                      getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              Text(
                dietPreference != 'All'
                    ? 'Diet: $dietPreference'
                    : 'Diet: General',
                style: TextStyle(
                  color:
                      getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
              if (selectedAllergies.isNotEmpty)
                Text(
                  'Allergies: ${allergies.join(", ")}',
                  style: TextStyle(
                    color: getThemeProvider(context).isDarkMode
                        ? kWhite
                        : kDarkGrey,
                  ),
                ),
              Text(
                'Cuisine Type: $selectedCuisine',
                style: TextStyle(
                  color:
                      getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
              Text(
                'Nutrition Goal: $fitnessGoal',
                style: TextStyle(
                  color:
                      getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
              },
              child: Text(
                'Update Preferences',
                style: TextStyle(
                  color:
                      getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentLight,
              ),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                if (widget.isDontShowPicker) {
                  _generateMealPlan(selectedCuisine);
                } else {
                  _showMealPlanOptionsDialog(); // Show meal plan options directly
                }
              },
              child: const Text(
                'Generate Plan',
                style: TextStyle(
                  color: kWhite,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMealPlanOptionsDialog() {
    // Ensure cuisineTypes is not empty
    if (cuisineTypes.isEmpty) {
      debugPrint('Error: cuisineTypes is empty');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text(
              'Cuisine types are not loaded. Please restart the app.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width,
              ),
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor:
                    getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
                title: Text(
                  'Meal Plan Preferences',
                  style: TextStyle(
                    color: getThemeProvider(context).isDarkMode
                        ? kWhite
                        : kDarkGrey,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose your meal plan type:',
                        style: TextStyle(
                          color: getThemeProvider(context).isDarkMode
                              ? kWhite
                              : kDarkGrey,
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(2, context)),
                      buildPicker(context, cuisineTypes.length, () {
                        // Find the index of the selected cuisine
                        final index = cuisineTypes.indexWhere(
                            (cuisine) => cuisine['name'] == selectedCuisine);
                        // Return the index if found, otherwise return 0 (first item)
                        return index >= 0 ? index : 0;
                      }(),
                          (index) => setState(() =>
                              selectedCuisine = cuisineTypes[index]['name']),
                          getThemeProvider(context).isDarkMode,
                          cuisineTypes
                              .map((cuisine) => cuisine['name'] as String)
                              .toList()),
                      SizedBox(height: getPercentageHeight(2, context)),
                      if (selectedCuisine != 'Balanced') ...[
                        Text(
                          'Number of dishes:',
                          style: TextStyle(
                            color: getThemeProvider(context).isDarkMode
                                ? kWhite
                                : kDarkGrey,
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(2, context)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Protein',
                                    style: TextStyle(
                                      color:
                                          getThemeProvider(context).isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                      fontSize: getTextScale(4, context),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.remove,
                                            size: getIconScale(7, context)),
                                        onPressed: () {
                                          setState(() {
                                            if (proteinDishes > 0)
                                              proteinDishes--;
                                          });
                                        },
                                      ),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(1, context)),
                                      Text(
                                        '$proteinDishes',
                                        style: TextStyle(
                                          color: getThemeProvider(context)
                                                  .isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                          fontSize: getTextScale(4, context),
                                        ),
                                      ),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(1, context)),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.add,
                                            size: getIconScale(7, context)),
                                        onPressed: () {
                                          setState(() {
                                            proteinDishes++;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Carbs',
                                    style: TextStyle(
                                      color:
                                          getThemeProvider(context).isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                      fontSize: getTextScale(4, context),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.remove,
                                            size: getIconScale(7, context)),
                                        onPressed: () {
                                          setState(() {
                                            if (grainDishes > 0) grainDishes--;
                                          });
                                        },
                                      ),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(1, context)),
                                      Text(
                                        '$grainDishes',
                                        style: TextStyle(
                                          color: getThemeProvider(context)
                                                  .isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                          fontSize: getTextScale(4, context),
                                        ),
                                      ),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(1, context)),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.add,
                                            size: getIconScale(7, context)),
                                        onPressed: () {
                                          setState(() {
                                            grainDishes++;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Veggies',
                                    style: TextStyle(
                                      color:
                                          getThemeProvider(context).isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                      fontSize: getTextScale(4, context),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.remove,
                                            size: getIconScale(7, context)),
                                        onPressed: () {
                                          setState(() {
                                            if (vegDishes > 0) vegDishes--;
                                          });
                                        },
                                      ),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(1, context)),
                                      Text(
                                        '$vegDishes',
                                        style: TextStyle(
                                          color: getThemeProvider(context)
                                                  .isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                          fontSize: getTextScale(4, context),
                                        ),
                                      ),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(1, context)),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.add,
                                            size: getIconScale(7, context)),
                                        onPressed: () {
                                          setState(() {
                                            vegDishes++;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: getThemeProvider(context).isDarkMode
                            ? kWhite
                            : kDarkGrey,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentLight,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _generateMealPlan(selectedCuisine);
                    },
                    child: const Text(
                      'Generate Plan',
                      style: TextStyle(
                        color: kWhite,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Prepare the prompt for Gemini
  Future<void> _generateMealPlan(String cuisine) async {
    if (!canUseAI()) {
      final isDarkMode = getThemeProvider(context).isDarkMode;
      showPremiumRequiredDialog(context, isDarkMode);
      return;
    }

    try {
      // Show loading indicator
      showLoadingDialog(context, loadingText: loadingTextGenerateMeals);

      // Prepare prompt and generate meal plan
      final prompt = _buildGeminiPrompt();
      final mealPlan = await geminiService.generateMealsIntelligently(
          prompt, mealPlanContext, cuisine);

      debugPrint('mealPlan: $mealPlan');

      // Check if meal generation failed
      if (mealPlan['error'] == true ||
          mealPlan['source'] == 'failed' ||
          mealPlan['source'] == 'fallback') {
        hideLoadingDialog(context); // Close loading dialog
        showMealGenerationErrorDialog(
            context,
            mealPlan['message'] ??
                'Failed to generate meals. Please try again.',
            onRetry: () => _generateMealPlan(selectedCuisine));
        return;
      }

      final userId = userService.userId;
      if (userId == null) throw Exception('User ID not found');

      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Collect meal IDs with proper meal type suffixes
      // Note: Meals are already saved by generateMealsIntelligently, so we just collect IDs
      List<String> mealIds = [];
      final meals = mealPlan['meals'] as List<dynamic>? ?? [];
      final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

      for (int i = 0; i < meals.length; i++) {
        final meal = meals[i];
        String mealType = meal['mealType']?.toString().toLowerCase() ?? '';
        final mealId = meal['id'] as String? ?? '';

        // If no mealType is specified, assign based on position
        if (mealType.isEmpty) {
          mealType = mealTypes[i % mealTypes.length];
        }

        if (mealId.isNotEmpty) {
          mealIds.add(appendMealType(mealId, mealType));
        }
      }

      await saveMealPlanToFirestore(
          userId, date, mealIds, mealPlan, selectedDiet,
          familyMemberName: widget.familyMemberName);
      await _updateUserPreferences(userId);
      FirebaseAnalytics.instance.logEvent(name: 'meal_plan_generated');

      // Hide loading and navigate back
      if (mounted) {
        hideLoadingDialog(context); // Hide loading
        Get.to(
            () => const BottomNavSec(selectedIndex: 4, foodScreenTabIndex: 1));
      }
    } catch (e) {
      if (mounted) {
        handleError(e, context);
      }
    }
  }

  void _updatePreferences() {
    if (widget.isOnboarding && widget.onPreferencesSelected != null) {
      widget.onPreferencesSelected!(
          selectedDiet, selectedAllergies, selectedCuisine);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

// Update user preferences
  Future<void> _updateUserPreferences(String userId) async {
    await firestore.collection('users').doc(userId).update({
      'preferences': {
        'diet': selectedDiet,
        'allergies': selectedAllergies.toList(),
        'cuisineType': selectedCuisine,
        'proteinDishes': proteinDishes,
        'grainDishes': grainDishes,
        'vegDishes': vegDishes,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      'settings.dietPreference': selectedDiet
    });

    // Update userService settings
    if (userService.currentUser.value != null) {
      userService.currentUser.value!.settings['dietPreference'] = selectedDiet;
    }
  }

  Future<bool> _fetchUserPreferences(String userId) async {
    final mainDiet =
        userService.currentUser.value?.settings['dietPreference'] ?? '';
    final docRef = firestore.collection('users').doc(userId);
    final doc = await docRef.get();

    if (doc.exists && doc.data()?['preferences'] != null) {
      final data = doc.data() as Map<String, dynamic>;
      final preferences = data['preferences'] as Map<String, dynamic>;

      setState(() {
        if (mainDiet != '') {
          selectedDiet = mainDiet;
        } else {
          selectedDiet = preferences['diet'] as String? ?? '';
        }
        // Convert List<dynamic> to Set<String>
        final allergiesList = preferences['allergies'] as List<dynamic>? ?? [];
        selectedAllergies = allergiesList.map((e) => e.toString()).toSet();

        // Validate cuisine type exists in cuisineTypes list
        final savedCuisine =
            preferences['cuisineType'] as String? ?? 'Balanced';
        selectedCuisine =
            cuisineTypes.any((cuisine) => cuisine['name'] == savedCuisine)
                ? savedCuisine
                : 'Balanced'; // Default to 'Balanced' if not found

        proteinDishes = preferences['proteinDishes'] as int? ?? 2;
        grainDishes = preferences['grainDishes'] as int? ?? 2;
        vegDishes = preferences['vegDishes'] as int? ?? 3;
      });
      return true; // Return true if preferences exist
    }
    return false; // Return false if no preferences found
  }

  String _buildGeminiPrompt() {
    final dietPreference = selectedDiet;

    // Use family member's goal and calorie target if available, otherwise use main user's
    final nutritionalGoal = widget.familyMemberGoal ?? goal;
    final dailyCalorieGoal = widget.familyMemberKcal ??
        calculateRecommendedCaloriesFromGoal(nutritionalGoal);

    final allergies = selectedAllergies.isEmpty
        ? ['No allergies']
        : selectedAllergies.toList();

    final familyMemberAgeGroup = widget.familyMemberType ?? 'adult';

    return '''
IMPORTANT: This meal plan is for a ${familyMemberAgeGroup}. Consider age-appropriate:
- Portion sizes and serving quantities
- Food textures and preparation methods
- Nutritional needs specific to ${familyMemberAgeGroup} development
- Safety considerations for ${familyMemberAgeGroup}s

PRIMARY REQUIREMENTS:
1. Daily calorie target: $dailyCalorieGoal calories (${familyMemberAgeGroup}-appropriate)
2. Nutrition goal: $nutritionalGoal (must be strictly followed)
3. Dietary preference: $dietPreference
4. Allergies to avoid: ${allergies.join(', ')}

Cuisine style: ${selectedCuisine}
Include:
- $proteinDishes protein dishes
- $grainDishes grain dishes  
- $vegDishes vegetable dishes

CRITICAL: Ensure all meals are suitable for ${familyMemberAgeGroup} consumption, meet the calorie target, and align with the nutrition goal.
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(5, context),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: getPercentageHeight(2, context)),
                if (!widget.isOnboarding)
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const IconCircleButton(),
                  ),
                if (!widget.isOnboarding)
                  SizedBox(height: getPercentageHeight(2, context)),

                Text(
                  textAlign: TextAlign.center,
                  "Tell us your dietary preferences?",
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w500, color: kAccent),
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                Text(
                  textAlign: TextAlign.center,
                  "We'll exclusively display recipes aligned with your chosen diet.",
                  style: TextStyle(
                    fontSize: getTextScale(3.5, context),
                  ),
                ),
                SizedBox(height: getPercentageHeight(2, context)),

                //choose diet
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: getPercentageWidth(25, context),
                    mainAxisExtent: getPercentageHeight(14, context),
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                  ),
                  itemCount: dietTypes.length,
                  itemBuilder: (BuildContext ctx, index) {
                    return DietItem(
                      dataSrc: dietTypes[index],
                      isSelected: selectedDiet == dietTypes[index]['name'],
                      onSelected: (title) {
                        setState(() {
                          if (selectedDiet == title) {
                            selectedDiet = dietTypes[0]['name'];
                          } else {
                            selectedDiet = title;
                          }
                          _updatePreferences();
                        });
                      },
                    );
                  },
                ),
                SizedBox(
                  height: getPercentageHeight(4, context),
                ),

                //choose alergy
                Text(
                  "Any allergies?",
                  style: TextStyle(
                    fontSize: getTextScale(4, context),
                  ),
                ),
                SizedBox(height: getPercentageHeight(2, context)),

                Wrap(
                  children: List.generate(
                    demoAllergyItemData.length,
                    (index) => AllergyItem(
                      dataSrc: demoAllergyItemData[index],
                      isSelected: selectedAllergies
                          .contains(demoAllergyItemData[index].allergy),
                      onSelected: (allergy) {
                        setState(() {
                          if (selectedAllergies.contains(allergy)) {
                            selectedAllergies.remove(allergy);
                          } else {
                            selectedAllergies.add(allergy);
                          }
                          _updatePreferences();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: !widget.isOnboarding
          ? Padding(
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(5, context),
                vertical: getPercentageHeight(1, context),
              ),
              child: AppButton(
                text: "Generate",
                onPressed: () => _showMealPlanOptionsDialog(),
                type: AppButtonType.secondary,
              ),
            )
          : null,
    );
  }
}

class DietItem extends StatelessWidget {
  DietItem({
    super.key,
    required this.dataSrc,
    required this.isSelected,
    required this.onSelected,
  });

  final Map<String, dynamic> dataSrc;
  final bool isSelected;
  final Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(dataSrc['name']),
      child: Container(
        decoration: BoxDecoration(
          color: getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              spreadRadius: 0.6,
              blurRadius: 6,
              offset: const Offset(1, 0),
            ),
          ],
          border: Border.all(
            color: isSelected ? kAccentLight : kWhite,
            width: 3,
          ),
        ),
        child: Column(
          children: [
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  getAssetImageForItem(dataSrc['name']),
                  width: getPercentageWidth(20, context),
                  height: getPercentageHeight(12, context),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(getPercentageWidth(1, context)),
              child: Text(
                dataSrc['name'] == 'All' ? 'General' : dataSrc['name'],
                style: TextStyle(
                  fontSize: getTextScale(2.5, context),
                  fontWeight: FontWeight.w600,
                  color:
                      getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class AllergyItem extends StatelessWidget {
  const AllergyItem({
    super.key,
    required this.dataSrc,
    required this.isSelected,
    required this.onSelected,
  });

  final AllergyItemData dataSrc;
  final bool isSelected;
  final Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          right: getPercentageWidth(4, context),
          bottom: getPercentageHeight(2, context)),
      child: InkWell(
        onTap: () => onSelected(dataSrc.allergy),
        splashColor: kPrimaryColor.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.all(
          Radius.circular(50),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(2, context),
            vertical: getPercentageHeight(1, context),
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(
              Radius.circular(10),
            ),
            border: Border.all(
              color: kPrimaryColor,
            ),
            color: isSelected
                ? kAccentLight
                : getThemeProvider(context).isDarkMode
                    ? kWhite
                    : kDarkGrey,
          ),
          child: Text(
            dataSrc.allergy,
            style: TextStyle(
              color: getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
              fontSize: getTextScale(3, context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
