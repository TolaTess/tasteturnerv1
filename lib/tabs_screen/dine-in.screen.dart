import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/helper_files.dart';
import '../helper/utils.dart';
import '../pages/upload_battle.dart';
import '../screens/recipes_list_category_screen.dart';
import '../service/macro_manager.dart';
import '../widgets/optimized_image.dart';
import '../widgets/primary_button.dart';

class DineInScreen extends StatefulWidget {
  const DineInScreen({super.key});

  @override
  State<DineInScreen> createState() => _DineInScreenState();
}

class _DineInScreenState extends State<DineInScreen> {
  final MacroManager _macroManager = Get.find<MacroManager>();

  MacroData? selectedCarb;
  MacroData? selectedProtein;
  bool isLoading = false;
  bool isAccepted = false;
  Map<String, dynamic>? selectedMeal;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadSavedMeal();
    _generateIngredientPair();
  }

  // Local storage keys
  static const String _selectedMealKey = 'dine_in_selected_meal';
  static const String _selectedCarbKey = 'dine_in_selected_carb';
  static const String _selectedProteinKey = 'dine_in_selected_protein';
  static const String _mealTimestampKey = 'dine_in_meal_timestamp';

  // Save meal to local storage
  Future<void> _saveMealToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (selectedMeal != null) {
        await prefs.setString(_selectedMealKey, jsonEncode(selectedMeal));
        // Save timestamp when meal is saved
        await prefs.setInt(
            _mealTimestampKey, DateTime.now().millisecondsSinceEpoch);
      }

      if (selectedCarb != null) {
        await prefs.setString(
            _selectedCarbKey, jsonEncode(selectedCarb!.toJson()));
      }

      if (selectedProtein != null) {
        await prefs.setString(
            _selectedProteinKey, jsonEncode(selectedProtein!.toJson()));
      }
    } catch (e) {
      print('Error saving meal to storage: $e');
    }
  }

  // Load meal from local storage
  Future<void> _loadSavedMeal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if meal is expired (older than 7 days)
      final timestamp = prefs.getInt(_mealTimestampKey);
      final now = DateTime.now().millisecondsSinceEpoch;
      final sevenDaysInMs = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds

      bool isMealExpired = false;
      if (timestamp != null) {
        isMealExpired = (now - timestamp) > sevenDaysInMs;
      }

      // Load selected meal only if not expired
      final savedMeal = prefs.getString(_selectedMealKey);
      if (savedMeal != null && !isMealExpired) {
        selectedMeal = jsonDecode(savedMeal);
        print('Restored saved meal from storage');
      } else if (isMealExpired) {
        // Clear expired meal data
        await prefs.remove(_selectedMealKey);
        await prefs.remove(_mealTimestampKey);
        print('Cleared expired meal data (older than 7 days)');
      }

      // Load selected ingredients
      final savedCarb = prefs.getString(_selectedCarbKey);
      if (savedCarb != null) {
        final carbData = jsonDecode(savedCarb);
        selectedCarb = MacroData.fromJson(carbData, carbData['id'] ?? '');
      }

      final savedProtein = prefs.getString(_selectedProteinKey);
      if (savedProtein != null) {
        final proteinData = jsonDecode(savedProtein);
        selectedProtein =
            MacroData.fromJson(proteinData, proteinData['id'] ?? '');
      }

      if (mounted) {
        setState(() {
          // If we loaded ingredients and meal, set accepted state
          if (selectedCarb != null &&
              selectedProtein != null &&
              selectedMeal != null) {
            isAccepted = true;
          }
        });
      }
    } catch (e) {
      print('Error loading meal from storage: $e');
    }
  }

  // Clear saved meal data
  Future<void> _clearSavedMeal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_selectedMealKey);
      await prefs.remove(_selectedCarbKey);
      await prefs.remove(_selectedProteinKey);
      await prefs.remove(_mealTimestampKey);
    } catch (e) {
      print('Error clearing saved meal: $e');
    }
  }

  Future<void> _generateIngredientPair({bool forceRefresh = false}) async {
    // Only generate new ingredients if none exist or if forced refresh
    if (!forceRefresh && selectedCarb != null && selectedProtein != null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Ensure ingredients are fetched
      if (_macroManager.ingredient.isEmpty) {
        await _macroManager.fetchIngredients();
      }

      final ingredients = _macroManager.ingredient;

      // Get carbs (grains, vegetables, carbs) and shuffle properly
      final allCarbs = ingredients
          .where((ingredient) =>
              (ingredient.type.toLowerCase() == 'grain' ||
                  ingredient.type.toLowerCase() == 'vegetable' ||
                  ingredient.type.toLowerCase() == 'carb') &&
              !excludedIngredients.contains(ingredient.title.toLowerCase()))
          .toList();
      allCarbs.shuffle(_random);
      final carbs = allCarbs.take(10).toList();

      // Get proteins and shuffle properly
      final allProteins = ingredients
          .where((ingredient) =>
              ingredient.type.toLowerCase() == 'protein' &&
              !excludedIngredients.contains(ingredient.title.toLowerCase()))
          .toList();
      allProteins.shuffle(_random);
      final proteins = allProteins.take(10).toList();

      // Randomly select one of each
      if (carbs.isNotEmpty && proteins.isNotEmpty) {
        selectedCarb = carbs[_random.nextInt(carbs.length)];
        selectedProtein = proteins[_random.nextInt(proteins.length)];

        // Clear meal when ingredients change
        if (forceRefresh) {
          selectedMeal = null;
          isAccepted = false;
        }
      }
    } catch (e) {
      print('Error generating ingredient pair: $e');
    }

    setState(() {
      isLoading = false;
    });

    // Save the new ingredients to storage
    _saveMealToStorage();
  }

  // Method to refresh ingredients
  Future<void> _refreshIngredients() async {
    await _generateIngredientPair(forceRefresh: true);
  }

  void _refreshPair() async {
    // If there's a saved meal, show confirmation dialog
    if (selectedMeal != null) {
      final shouldClear = await _showClearMealDialog();
      if (!shouldClear) return;
    }

    // Clear from storage when user explicitly generates new ingredients
    _clearSavedMeal();
    // Use the new refresh method which forces new ingredient generation
    await _refreshIngredients();
  }

  // Show dialog to confirm clearing existing meal
  Future<bool> _showClearMealDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkMode = getThemeProvider(context).isDarkMode;
        final textTheme = Theme.of(context).textTheme;
        return AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Generate New Pair?',
            style: textTheme.titleLarge?.copyWith(color: kAccent),
          ),
          content: Text(
            'You have a saved recipe. Generating new ingredients will clear your current recipe. Continue?',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep Current',
                style: textTheme.bodyMedium?.copyWith(color: kAccent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Generate New',
                style: textTheme.bodyMedium?.copyWith(color: kAccent),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _acceptPair() {
    setState(() {
      isAccepted = true;
    });
  }

  void _showDetails(bool isDarkMode, TextTheme textTheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Ingredient Details',
          style: textTheme.titleLarge?.copyWith(
            color: kAccent,
          ),
        ),
        content: Text(
          '• Use only the listed ingredients plus:\n'
          '  - Onions\n'
          '  - Herbs\n'
          '  - Spices\n\n'
          '• Create a visually stunning dish\n'
          '• Take a high-quality photo\n\n'
          '🏆 Remember: Presentation is key! \n\n Enjoy your meal!',
          style: textTheme.bodyMedium?.copyWith(
            color: isDarkMode ? kWhite : kBlack,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: textTheme.bodyMedium?.copyWith(
                  color: kAccentLight,
                ),
              )),
        ],
      ),
    );
  }

  void _navigateToUploadBattle() {
    if (selectedCarb != null && selectedProtein != null) {
      // Create battle ID from ingredient names + random number
      final battleId =
          '${selectedCarb!.title.toLowerCase().replaceAll(' ', '_')}_'
          '${selectedProtein!.title.toLowerCase().replaceAll(' ', '_')}_'
          '${_random.nextInt(9999).toString().padLeft(4, '0')}';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UploadBattleImageScreen(
            battleId: battleId,
            battleCategory: 'Dine-In Challenge',
            isMainPost: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Dine-In Challenge',
          style: textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w400,
            fontSize: getPercentageWidth(7, context),
          ),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        elevation: 2,
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: kAccent),
                  SizedBox(height: getPercentageHeight(2, context)),
                  Text(
                    'Finding perfect ingredient pair...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: getPercentageHeight(2, context)),
                  // Header text
                  Center(
                    child: Text(
                      'Your Random Ingredient Pair',
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: getPercentageWidth(5, context),
                        color: kAccent,
                      ),
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Center(
                    child: Text(
                      'Create something amazing with these two ingredients!',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                        fontSize: getPercentageWidth(3.5, context),
                      ),
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(2.5, context)),

                  // Ingredient cards
                  if (selectedCarb != null && selectedProtein != null) ...[
                    Row(
                      children: [
                        // Carb card
                        Expanded(
                          child: _buildIngredientCard(
                            selectedCarb!,
                            'Grain',
                            isDarkMode,
                            textTheme,
                            getMealTypeColor('grain'),
                          ),
                        ),
                        SizedBox(width: getPercentageWidth(4, context)),
                        // Plus icon
                        Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(3, context)),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            size: getIconScale(8, context),
                            color: kAccent,
                          ),
                        ),
                        SizedBox(width: getPercentageWidth(4, context)),
                        // Protein card
                        Expanded(
                          child: _buildIngredientCard(
                            selectedProtein!,
                            'Protein',
                            isDarkMode,
                            textTheme,
                            getMealTypeColor('protein'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: getPercentageHeight(1, context)),
                  // Info section
                  Container(
                    padding: EdgeInsets.all(getPercentageWidth(3, context)),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: kAccent,
                          size: getIconScale(5, context),
                        ),
                        SizedBox(width: getPercentageWidth(2, context)),
                        Expanded(
                          child: Text(
                            selectedMeal != null
                                ? 'Your ingredient pair is saved! Tap "Go Back and Refresh Pair" to try new combinations.'
                                : 'Try different combinations to spark new recipe ideas!',
                            style: textTheme.bodySmall?.copyWith(
                              color: isDarkMode ? kLightGrey : kDarkGrey,
                              fontSize: getPercentageWidth(3, context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: getPercentageHeight(2.5, context)),

                  // Action buttons
                  if (!isAccepted) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _refreshPair,
                            icon: Icon(Icons.refresh, color: kAccent),
                            label: Text(
                              'Refresh Pair',
                              style: textTheme.bodyMedium?.copyWith(
                                color: kAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: kAccent),
                              padding: EdgeInsets.symmetric(
                                vertical: getPercentageHeight(1.5, context),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: getPercentageWidth(4, context)),
                        Expanded(
                          child: AppButton(
                            text: 'Accept Pair',
                            onPressed: _acceptPair,
                            type: AppButtonType.primary,
                            width: 100,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Creation submission section
                    Container(
                      padding: EdgeInsets.all(getPercentageWidth(4, context)),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: kAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: kAccent),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Text(
                                'Perfect! Ready to create?',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: kAccent,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),
                          Text(
                            'Time to show your culinary creativity! Upload your creation using these ingredients and share it with the community.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: isDarkMode ? kWhite : kBlack,
                              fontSize: getPercentageWidth(3.5, context),
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      isAccepted = false;
                                    });
                                  },
                                  icon: Icon(Icons.arrow_back, color: kAccent),
                                  label: Text(
                                    'Go Back',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: kAccent,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: kAccent),
                                  ),
                                ),
                              ),
                              SizedBox(width: getPercentageWidth(4, context)),
                              Expanded(
                                child: AppButton(
                                  text: 'See Details',
                                  onPressed: () =>
                                      _showDetails(isDarkMode, textTheme),
                                  type: AppButtonType.follow,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: getPercentageHeight(2, context)),
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPink,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Get.to(() => RecipeListCategory(
                                index: 1,
                                searchIngredient:
                                    selectedProtein!.title.toLowerCase(),
                                screen: 'categories',
                                isNoTechnique: true,
                              ));
                        },
                        icon: const Icon(Icons.restaurant, color: kWhite),
                        label: Text('See Recipes for ${selectedProtein!.title}',
                            style: textTheme.labelLarge?.copyWith(color: kWhite)),
                      ),
                    ),
                  

                    if (selectedMeal == null) ...[
                      SizedBox(height: getPercentageHeight(2, context)),
                      Row(
                        children: [
                          SizedBox(width: getPercentageWidth(4, context)),
                          Expanded(
                            flex: 1,
                            child: GestureDetector(
                              onTap: () async {
                                try {
                                  final meal = await geminiService
                                      .generateMealsFromIngredients(
                                          [selectedCarb!, selectedProtein!],
                                          context,
                                          true);
                                  if (meal != null) {
                                    setState(() {
                                      selectedMeal = meal;
                                    });
                                    // Save the meal to storage
                                    _saveMealToStorage();
                                  }
                                } catch (e) {
                                  // Handle error
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Failed to generate meal: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: getPercentageWidth(2, context),
                                    vertical: getPercentageHeight(1, context)),
                                decoration: BoxDecoration(
                                  color: kAccentLight.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Use Tasty AI',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: kAccentLight,
                                    fontWeight: FontWeight.w600,
                                    fontSize: getPercentageWidth(4, context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: getPercentageWidth(4, context)),
                          Expanded(
                            flex: 3,
                            child: AppButton(
                              text: 'Upload Creation',
                              onPressed: _navigateToUploadBattle,
                              type: AppButtonType.primary,
                              width: 100,
                              color: kAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  // Display selected meal if available
                  if (selectedMeal != null) ...[
                    SizedBox(height: getPercentageHeight(4, context)),
                    Container(
                      padding: EdgeInsets.all(getPercentageWidth(4, context)),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: kAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, color: kAccent),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Expanded(
                                child: Text(
                                  'AI Generated Recipe',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: kAccent,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: kAccent),
                                onPressed: () {
                                  setState(() {
                                    selectedMeal = null;
                                  });
                                  // Note: Keep meal in storage so it can be restored
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),

                          // Meal title
                          Text(
                            selectedMeal!['title'] ?? 'Untitled Recipe',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? kWhite : kBlack,
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),

                          // Description
                          if (selectedMeal!['description'] != null) ...[
                            Text(
                              selectedMeal!['description'],
                              style: textTheme.bodyMedium?.copyWith(
                                color: isDarkMode ? kLightGrey : kDarkGrey,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),
                          ],

                          // Cooking info
                          Row(
                            children: [
                              if (selectedMeal!['cookingTime'] != null) ...[
                                Icon(Icons.timer,
                                    size: getIconScale(4, context),
                                    color: kAccent),
                                SizedBox(width: getPercentageWidth(1, context)),
                                Text(
                                  selectedMeal!['cookingTime'],
                                  style: textTheme.bodySmall?.copyWith(
                                    color: isDarkMode ? kWhite : kBlack,
                                  ),
                                ),
                                SizedBox(width: getPercentageWidth(4, context)),
                              ],
                              if (selectedMeal!['cookingMethod'] != null) ...[
                                Icon(Icons.restaurant_menu,
                                    size: getIconScale(4, context),
                                    color: kAccent),
                                SizedBox(width: getPercentageWidth(1, context)),
                                Text(
                                  selectedMeal!['cookingMethod'],
                                  style: textTheme.bodySmall?.copyWith(
                                    color: isDarkMode ? kWhite : kBlack,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),

                          // Ingredients
                          Text(
                            'Ingredients:',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: kAccent,
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(0.5, context)),
                          if (selectedMeal!['ingredients'] != null) ...[
                            ...((selectedMeal!['ingredients']
                                    as Map<String, dynamic>)
                                .entries
                                .map(
                                  (entry) => Padding(
                                    padding: EdgeInsets.only(
                                        bottom:
                                            getPercentageHeight(0.3, context)),
                                    child: Text(
                                      '• ${entry.key}: ${entry.value}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: isDarkMode ? kWhite : kBlack,
                                      ),
                                    ),
                                  ),
                                )),
                          ],
                          SizedBox(height: getPercentageHeight(2, context)),

                          // Instructions
                          Text(
                            'Instructions:',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: kAccent,
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(0.5, context)),
                          if (selectedMeal!['instructions'] != null) ...[
                            ...((selectedMeal!['instructions'] as List<dynamic>)
                                .asMap()
                                .entries
                                .map(
                                  (entry) => Padding(
                                    padding: EdgeInsets.only(
                                        bottom:
                                            getPercentageHeight(0.5, context)),
                                    child: Text(
                                      '${entry.key + 1}. ${entry.value}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: isDarkMode ? kWhite : kBlack,
                                      ),
                                    ),
                                  ),
                                )),
                          ],

                          SizedBox(height: getPercentageHeight(2, context)),

                          // Action button
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              text: 'Upload Creation!',
                              onPressed: _navigateToUploadBattle,
                              type: AppButtonType.primary,
                              color: kAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: getPercentageHeight(10, context)),
                ],
              ),
            ),
    );
  }

  Widget _buildIngredientCard(
    MacroData ingredient,
    String typeLabel,
    bool isDarkMode,
    TextTheme textTheme,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Type label
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(2, context),
              vertical: getPercentageHeight(0.5, context),
            ),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? kAccent.withValues(alpha: 0.2)
                  : kLightGrey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              typeLabel == 'Grain'
                  ? 'Carb'
                  : typeLabel == 'Protein'
                      ? 'Protein'
                      : typeLabel,
              style: textTheme.bodySmall?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
                fontWeight: FontWeight.w600,
                fontSize: getPercentageWidth(3, context),
              ),
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),

          // Ingredient image
          Container(
            height: getPercentageWidth(20, context),
            width: getPercentageWidth(20, context),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kLightGrey.withValues(alpha: 0.3),
            ),
            child: ClipOval(
              child: ingredient.mediaPaths.isNotEmpty
                  ? ingredient.mediaPaths.first.contains('https')
                      ? OptimizedImage(
                          imageUrl: ingredient.mediaPaths.first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Image.asset(
                          getAssetImageForItem(ingredient.mediaPaths.first),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.food_bank,
                              size: getIconScale(10, context)),
                        )
                  : ingredient.image.isNotEmpty
                      ? Image.asset(
                          getAssetImageForItem(ingredient.image),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.food_bank,
                              size: getIconScale(10, context)),
                        )
                      : Icon(
                          Icons.food_bank,
                          size: getIconScale(10, context),
                          color: kAccent,
                        ),
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),

          // Ingredient name
          Text(
            capitalizeFirstLetter(ingredient.title),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: getPercentageWidth(3.5, context),
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          SizedBox(height: getPercentageHeight(0.5, context)),

          // Calories
          Text(
            '${ingredient.calories} cal',
            style: textTheme.bodySmall?.copyWith(
              color: isDarkMode ? kAccent : kLightGrey,
              fontSize: getPercentageWidth(3, context),
            ),
          ),
        ],
      ),
    );
  }
}
