import 'package:fit_hify/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/base_model.dart';
import '../helper/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../widgets/bottom_nav.dart';

class ChooseDietScreen extends StatefulWidget {
  const ChooseDietScreen({super.key});

  @override
  State<ChooseDietScreen> createState() => _ChooseDietScreenState();
}

class _ChooseDietScreenState extends State<ChooseDietScreen> {
  String selectedDiet = demoDietData[0].title; // First element is "None"
  final Set<String> selectedAllergies = {};
  int proteinDishes = 2;
  int grainDishes = 2;
  int vegDishes = 3;
  String selectedCuisine = 'Balanced';

  final List<String> cuisineTypes = [
    'Balanced',
    'Italian',
    'Chinese',
    'Indian',
    'Mexican',
    'Japanese',
    'Mediterranean',
    'Thai',
    'French',
    'Korean'
  ];

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
                        items: cuisineTypes.map((String cuisine) {
                          return DropdownMenuItem<String>(
                            value: cuisine,
                            child: Text(
                              cuisine,
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
                                            if (proteinDishes > 1)
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
                                            if (grainDishes > 1) grainDishes--;
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
                                            if (vegDishes > 1) vegDishes--;
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
          await _saveMealsToFirestore(userId, mealPlan);
      await _saveMealPlanToFirestore(userId, date, mealIds, mealPlan);
      await _updateUserPreferences(userId);

      // Hide loading and navigate back
      if (mounted) {
        Navigator.of(context).pop(); // Hide loading
        Get.to(
            () => const BottomNavSec(selectedIndex: 4, foodScreenTabIndex: 2));
      }
    } catch (e) {
      _handleError(e);
    }
  }

// Helper method to show loading dialog
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => noItemTastyWidget(
          'Generating Meal Plan, Please Wait...', '', context, false),
    );
  }

  Map<String, String> _convertToStringMap(dynamic input) {
    if (input is List<dynamic>) {
      // Convert list of strings to a map with indexed keys
      return {
        for (int i = 0; i < input.length; i++)
          'ingredient${i + 1}': input[i].toString()
      };
    } else if (input is Map) {
      // Handle case where input is already a map
      return input
          .map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return {}; // Fallback for invalid input
  }

  Future<List<String>> _saveMealsToFirestore(
      String userId, Map<String, dynamic>? mealPlan) async {
    print(
        'Starting _saveMealsToFirestore for userId: $userId at ${DateTime.now()}');
    if (mealPlan == null ||
        mealPlan['meals'] == null ||
        mealPlan['meals'] is! List) {
      print('Invalid mealPlan: $mealPlan');
      return [];
    }

    final List<String> mealIds = [];
    final mealCollection = firestore.collection('meals');
    final meals = mealPlan['meals'] as List<dynamic>;

    for (final mealData in meals) {
      if (mealData is! Map<String, dynamic>) {
        continue;
      }

      final mealId = mealCollection.doc().id;
      final nutritionalInfo =
          mealData['nutritionalInfo'] as Map<String, dynamic>? ?? {};

      // Process data
      final ingredients = _convertToStringMap(mealData['ingredients'] ?? []);
      final steps = _convertToStringList(mealData['instructions'] ?? []);
      final categories = _convertToStringList(mealData['categories'] ?? []);
      final type = _parseStringOrDefault(mealData['type'], '');

      final processedNutritionalInfo = {
        'calories': (nutritionalInfo['calories']?.toString() ?? '0').trim(),
        'protein': (nutritionalInfo['protein']?.toString() ?? '0').trim(),
        'carbs': (nutritionalInfo['carbs']?.toString() ?? '0').trim(),
        'fat': (nutritionalInfo['fat']?.toString() ?? '0').trim(),
      };

      if (!_validateNutritionalInfo(processedNutritionalInfo)) {
        print(
            'Error: Invalid nutritional information: $processedNutritionalInfo');
        continue;
      }

      final title = mealData['title']?.toString() ?? 'Untitled Meal';

      // Explicitly construct JSON to avoid Meal class serialization issues
      final mealJson = {
        'userId': tastyId,
        'title': title,
        'calories': int.parse(processedNutritionalInfo['calories'] ?? '0'),
        'mealId': mealId,
        'createdAt': Timestamp.fromDate(DateTime.now()), // Use server timestamp
        'ingredients': ingredients,
        'steps': steps,
        'mediaPaths': [type],
        'serveQty': mealData['serveQty'] is int ? mealData['serveQty'] : 1,
        'macros': {
          'protein': processedNutritionalInfo['protein'],
          'carbs': processedNutritionalInfo['carbs'],
          'fat': processedNutritionalInfo['fat'],
        },
        'category': type,
        'categories': categories,
        'mediaType': 'image',
      };

      try {
        await mealCollection.doc(mealId).set(mealJson);
        mealIds.add(mealId);
      } catch (e) {
        print('Error saving meal $mealId: $e');
        continue;
      }
    }
    return mealIds;
  }

  Future<void> _saveMealPlanToFirestore(String userId, String date,
      List<String> mealIds, Map<String, dynamic>? mealPlan) async {
    final docRef = FirebaseFirestore.instance
        .collection('mealPlans')
        .doc(userId)
        .collection('buddy')
        .doc(date);

    // Fetch the existing document (if it exists)
    List<Map<String, dynamic>> existingGenerations = [];
    try {
      final existingDoc = await docRef.get();
      if (existingDoc.exists) {
        final existingData = existingDoc.data() as Map<String, dynamic>?;
        final generations = existingData?['generations'] as List<dynamic>?;
        if (generations != null) {
          existingGenerations =
              generations.map((gen) => gen as Map<String, dynamic>).toList();
        }
      }
    } catch (e) {
      print('Error fetching existing document: $e');
    }

    // Create a new generation object
    final newGeneration = {
      'mealIds': mealIds,
      'timestamp':
          Timestamp.fromDate(DateTime.now()), // Use client-side Timestamp
    };

    // Add nutritionSummary and tips if they exist in mealPlan
    if (mealPlan != null) {
      if (mealPlan['nutritionalSummary'] != null) {
        newGeneration['nutritionalSummary'] = mealPlan['nutritionalSummary'];
      }
      if (mealPlan['tips'] != null) {
        newGeneration['tips'] = mealPlan['tips'];
      }
    }

    // Append the new generation to the list
    existingGenerations.add(newGeneration);

    // Prepare the data to save
    final mealPlanData = {
      'date': date,
      'generations': existingGenerations,
    };

    // Save the updated document
    try {
      await docRef.set(mealPlanData);
    } catch (e) {
      print('Error saving meal plan: $e');
    }
  }

// Update user preferences
  Future<void> _updateUserPreferences(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
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

// Handle errors
  void _handleError(dynamic e) {
    if (mounted) {
      Navigator.of(context).pop(); // Hide loading
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor:
                getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
            title: const Text('$appNameBuddy'),
            content: Text(
              'Unable to generate meal plan at present. Please try again later.',
              style: TextStyle(
                color:
                    getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: getThemeProvider(context).isDarkMode
                        ? kWhite
                        : kDarkGrey,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  // Helper methods for safe type conversion
  int _parseIntOrDefault(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  String _parseStringOrDefault(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  List<String> _convertToStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return [];
  }

  String _buildGeminiPrompt() {
    final dietPreference = selectedDiet;
    final dailyCalorieGoal =
        userService.currentUser?.settings['foodGoals'] ?? 2000;
    final allergies = selectedAllergies.isEmpty
        ? ['No allergies']
        : selectedAllergies.toList();

    if (selectedCuisine == 'Balanced') {
      return '''
Generate a balanced meal plan considering:
Daily calorie goal: $dailyCalorieGoal
Dietary preference: $dietPreference
Allergies to avoid: ${allergies.join(', ')}
Please provide a balanced mix of proteins, grains, legumes, healthy fats and vegetables.
''';
    } else {
      return '''
Generate a ${selectedCuisine} cuisine meal plan considering:
Dietary preference: $dietPreference
Allergies to avoid: ${allergies.join(', ')}
Include:
- $proteinDishes protein dishes
- $grainDishes grain dishes
- $vegDishes vegetable dishes
''';
    }
  }

  Map<String, dynamic> _calculateNutritionalSummary(
      Map<String, dynamic> mealPlan) {
    // Basic implementation - this could be replaced with an actual call to geminiService if that method exists
    int totalCalories = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;

    for (final mealType in ['breakfast', 'lunch', 'dinner', 'snacks']) {
      if (mealPlan[mealType] != null) {
        totalCalories +=
            int.tryParse(mealPlan[mealType]['calories']?.toString() ?? '0') ??
                0;
        totalProtein +=
            int.tryParse(mealPlan[mealType]['protein']?.toString() ?? '0') ?? 0;
        totalCarbs +=
            int.tryParse(mealPlan[mealType]['carbs']?.toString() ?? '0') ?? 0;
        totalFat +=
            int.tryParse(mealPlan[mealType]['fat']?.toString() ?? '0') ?? 0;
      }
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  // Add this helper method for nutritional info validation
  bool _validateNutritionalInfo(Map<String, String> nutritionalInfo) {
    try {
      // Check if all required fields are present and can be parsed as numbers
      final requiredFields = ['calories', 'protein', 'carbs', 'fat'];
      for (final field in requiredFields) {
        if (!nutritionalInfo.containsKey(field) ||
            nutritionalInfo[field] == null ||
            nutritionalInfo[field]!.isEmpty ||
            int.tryParse(nutritionalInfo[field]!) == null) {
          print(
              'Validation failed for field: $field with value: ${nutritionalInfo[field]}');
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error during nutritional info validation: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$appNameBuddy Planner'),
      ),
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
                const Text(
                  textAlign: TextAlign.center,
                  "Tell me your dietary preferences?",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  textAlign: TextAlign.center,
                  "I'll exclusively display recipes aligned with your chosen diet.",
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
                    maxCrossAxisExtent: 104,
                    mainAxisExtent: 132,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: demoDietData.length,
                  itemBuilder: (BuildContext ctx, index) {
                    return DietItem(
                      dataSrc: demoDietData[index],
                      isSelected: selectedDiet == demoDietData[index].title,
                      onSelected: (title) {
                        setState(() {
                          if (selectedDiet == title) {
                            selectedDiet = demoDietData[0].title;
                          } else {
                            selectedDiet = title;
                          }
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        child: SecondaryButton(
          text: "Generate",
          press: () => _showMealPlanOptionsDialog(),
        ),
      ),
    );
  }
}

class DietItem extends StatelessWidget {
  const DietItem({
    super.key,
    required this.dataSrc,
    required this.isSelected,
    required this.onSelected,
  });

  final DataModelBase dataSrc;
  final bool isSelected;
  final Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(dataSrc.title),
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
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                dataSrc.image,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                dataSrc.title,
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
              Radius.circular(50),
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
