import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/ingredient_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../widgets/secondary_button.dart';

class ChooseDietScreen extends StatefulWidget {
  const ChooseDietScreen({
    super.key,
    this.isOnboarding = false,
    this.onPreferencesSelected,
  });

  final bool isOnboarding;
  final Function(String diet, Set<String> allergies, String cuisineType)?
      onPreferencesSelected;

  @override
  State<ChooseDietScreen> createState() => _ChooseDietScreenState();
}

class _ChooseDietScreenState extends State<ChooseDietScreen> {
  String selectedDiet = 'None';
  Set<String> selectedAllergies = {};
  int proteinDishes = 2;
  int grainDishes = 2;
  int vegDishes = 3;
  String selectedCuisine = 'Balanced';

  List<Map<String, dynamic>> cuisineTypes = [];
  List<Map<String, dynamic>> dietTypes = [];

  @override
  void initState() {
    super.initState();
    cuisineTypes = helperController.headers;
    dietTypes = helperController.category;
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
                'You already have the following preferences:',
                style: TextStyle(
                  color:
                      getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Diet: $selectedDiet',
                style: TextStyle(
                  color:
                      getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
              if (selectedAllergies.isNotEmpty)
                Text(
                  'Allergies: ${selectedAllergies.join(", ")}',
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
                _showMealPlanOptionsDialog(); // Show meal plan options directly
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: getThemeProvider(context).isDarkMode
                            ? kLightGrey
                            : kBackgroundColor,
                        value: selectedCuisine,
                        decoration: InputDecoration(
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: kAccentLight,
                            ),
                          ),
                          labelText: 'Cuisine Type',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(
                            color: getThemeProvider(context).isDarkMode
                                ? kWhite
                                : kDarkGrey,
                          ),
                        ),
                        items: cuisineTypes.map((Map<String, dynamic> cuisine) {
                          return DropdownMenuItem<String>(
                            value: cuisine['name'],
                            child: Text(
                              cuisine['name'],
                              style: TextStyle(
                                color: getThemeProvider(context).isDarkMode
                                    ? kWhite
                                    : kDarkGrey,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedCuisine = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (selectedCuisine != 'Balanced') ...[
                        Text(
                          'Number of dishes:',
                          style: TextStyle(
                            color: getThemeProvider(context).isDarkMode
                                ? kWhite
                                : kDarkGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon:
                                            const Icon(Icons.remove, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            if (proteinDishes > 0)
                                              proteinDishes--;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$proteinDishes',
                                        style: TextStyle(
                                          color: getThemeProvider(context)
                                                  .isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.add, size: 20),
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
                                    'Grains',
                                    style: TextStyle(
                                      color:
                                          getThemeProvider(context).isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon:
                                            const Icon(Icons.remove, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            if (grainDishes > 0) grainDishes--;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$grainDishes',
                                        style: TextStyle(
                                          color: getThemeProvider(context)
                                                  .isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.add, size: 20),
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
                                    'Vegetables',
                                    style: TextStyle(
                                      color:
                                          getThemeProvider(context).isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon:
                                            const Icon(Icons.remove, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            if (vegDishes > 0) vegDishes--;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$vegDishes',
                                        style: TextStyle(
                                          color: getThemeProvider(context)
                                                  .isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.add, size: 20),
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
                      _generateMealPlan();
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
  Future<void> _generateMealPlan() async {
    try {
      // Show loading indicator
      _showLoadingDialog();

      // Prepare prompt and generate meal plan
      final prompt = _buildGeminiPrompt();
      final mealPlan = await geminiService.generateMealPlan(prompt);

      final userId = userService.userId;
      if (userId == null) throw Exception('User ID not found');

      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final List<String> mealIds =
          await saveMealsToFirestore(userId, mealPlan, selectedCuisine);
      await saveMealPlanToFirestore(userId, date, mealIds, mealPlan);
      await _updateUserPreferences(userId);

      // Hide loading and navigate back
      if (mounted) {
        Navigator.of(context).pop(); // Hide loading
        Get.to(
            () => const BottomNavSec(selectedIndex: 4, foodScreenTabIndex: 1));
      }
    } catch (e) {
      if (mounted) {
        handleError(e, context);
      }
    }
  }

// Helper method to show loading dialog
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => noItemTastyWidget(
          'Generating Meal Plan, Please Wait...', '', context, false, ''),
    );
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
      }
    });
  }

  Future<bool> _fetchUserPreferences(String userId) async {
    final docRef = firestore.collection('users').doc(userId);
    final doc = await docRef.get();

    if (doc.exists && doc.data()?['preferences'] != null) {
      final data = doc.data() as Map<String, dynamic>;
      final preferences = data['preferences'] as Map<String, dynamic>;

      if (preferences != null) {
        setState(() {
          selectedDiet = preferences['diet'] as String? ?? '';
          // Convert List<dynamic> to Set<String>
          final allergiesList =
              preferences['allergies'] as List<dynamic>? ?? [];
          selectedAllergies = allergiesList.map((e) => e.toString()).toSet();
          selectedCuisine = preferences['cuisineType'] as String? ?? '';
          proteinDishes = preferences['proteinDishes'] as int? ?? 2;
          grainDishes = preferences['grainDishes'] as int? ?? 2;
          vegDishes = preferences['vegDishes'] as int? ?? 3;
        });
        return true; // Return true if preferences exist
      }
    }
    return false; // Return false if no preferences found
  }

  String _buildGeminiPrompt() {
    final dietPreference = selectedDiet;
    final dailyCalorieGoal =
        userService.currentUser?.settings['foodGoals'] ?? 2000;
    final allergies = selectedAllergies.isEmpty
        ? ['No allergies']
        : selectedAllergies.toList();

    return '''

Generate a ${selectedCuisine} cuisine meal plan considering:
Daily calorie goal: $dailyCalorieGoal
Dietary preference: $dietPreference
Allergies to avoid: ${allergies.join(', ')}
Include:
- $proteinDishes protein dishes
- $grainDishes grain dishes
- $vegDishes vegetable dishes
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                if (!widget.isOnboarding)
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const IconCircleButton(),
                  ),
                if (!widget.isOnboarding) const SizedBox(height: 24),

                const Text(
                  textAlign: TextAlign.center,
                  "Tell us your dietary preferences?",
                  style: TextStyle(
                    fontSize: 20,
                    overflow: TextOverflow.ellipsis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  textAlign: TextAlign.center,
                  "We'll exclusively display recipes aligned with your chosen diet.",
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                //choose diet
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 100,
                    mainAxisExtent: 90,
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
                const SizedBox(
                  height: 32,
                ),

                //choose alergy
                const Text(
                  "Any allergies?",
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),

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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: SecondaryButton(
                text: "Generate",
                press: () => _showMealPlanOptionsDialog(),
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
                  width: 85,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                dataSrc['name'] == 'All'
                    ? 'General'
                    : dataSrc['name'],
                style: TextStyle(
                  fontSize: 10,
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
      padding: const EdgeInsets.only(right: 16, bottom: 16),
      child: InkWell(
        onTap: () => onSelected(dataSrc.allergy),
        splashColor: kPrimaryColor.withOpacity(0.4),
        borderRadius: const BorderRadius.all(
          Radius.circular(50),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
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
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
