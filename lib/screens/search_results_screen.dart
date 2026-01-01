import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/recipe_card_flex.dart';
import '../detail_screen/recipe_detail.dart';
import '../service/meal_api_service.dart';

class SearchResultGrid extends StatefulWidget {
  final bool enableSelection;
  final List<String> selectedMealIds;
  final String search;
  final String screen;
  final String?
      searchQuery; // For distinguishing between initial filter and search
  final String? searchIngredient; // For passing original technique context
  final Function(String mealId)? onMealToggle;
  final Function()? onSave;
  final Function(Meal meal)? onRecipeTap; // New callback for recipe navigation
  final String? label;

  const SearchResultGrid({
    super.key,
    this.search = '',
    this.enableSelection = false,
    required this.selectedMealIds,
    this.onMealToggle,
    this.onSave,
    this.screen = 'recipe',
    this.searchQuery,
    this.searchIngredient,
    this.onRecipeTap,
    this.label,
  });

  @override
  State<SearchResultGrid> createState() => _SearchResultGridState();
}

class _SearchResultGridState extends State<SearchResultGrid> {
  final _apiService = MealApiService();
  final RxList<Meal> _apiMeals = <Meal>[].obs;
  final RxBool _isLoading = false.obs;
  final RxBool _hasMore = true.obs;
  final RxInt _localMealsDisplayed = 0.obs;
  String _lastSearchQuery = '';
  static const int _localPageSize = 15;
  static const int _apiPageSize = 20;
  bool isLabel = false;

  @override
  void initState() {
    super.initState();
    // Initialize with exactly 15 local meals
    _localMealsDisplayed.value = _localPageSize;
    _hasMore.value = mealManager.meals.length > _localPageSize;
    _lastSearchQuery = widget.search;
    isLabel = widget.label != 'general' &&
        widget.label?.toLowerCase() == widget.search.toLowerCase();
    // Only perform search if there's a specific search query, not for initial load
    if (widget.search.isNotEmpty &&
        widget.search.toLowerCase() != 'general' &&
        widget.search.toLowerCase() != 'all') {
      _performSearch();
    }
  }

  @override
  void didUpdateWidget(SearchResultGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only perform search if search query actually changed and it's not empty
    if (widget.search != _lastSearchQuery &&
        widget.search.isNotEmpty &&
        widget.search.toLowerCase() != 'general' &&
        widget.search.toLowerCase() != 'all') {
      _lastSearchQuery = widget.search;
      // Defer to avoid calling setState/markNeedsBuild during build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _performSearch();
        }
      });
    } else if (widget.search != _lastSearchQuery) {
      // If search changed to empty/general/all, just reset without fetching
      _lastSearchQuery = widget.search;
      // Defer observable updates to avoid triggering reactive rebuilds during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _apiMeals.clear();
          _localMealsDisplayed.value = _localPageSize;
          _hasMore.value = mealManager.meals.length > _localPageSize;
        }
      });
    }
  }

  Future<void> _performSearch() async {
    if (_isLoading.value) return;

    _isLoading.value = true;
    _apiMeals.clear();
    _hasMore.value = true;
    _localMealsDisplayed.value = _localPageSize;

    try {
      if (widget.search.isNotEmpty &&
          widget.search.toLowerCase() != 'general' &&
          widget.search.toLowerCase() != 'all') {
        // Use existing meals data if available to avoid unnecessary Firestore calls
        String search = '';
        if (widget.search.toLowerCase() == 'veg heavy') {
          search = 'vegetable';
        } else {
          search = widget.search.replaceAll('-', ' ').toLowerCase();
        }
        List<Meal> allMeals = mealManager.meals;

        // Only fetch from Firestore if we don't have meals data
        if (allMeals.isEmpty) {
          final querySnapshot = await firestore
              .collection('meals')
              .orderBy('createdAt', descending: true)
              .get();

          allMeals = querySnapshot.docs
              .map((doc) => Meal.fromJson(doc.id, doc.data()))
              .toList();
        }

        // Special case: show only user's meals if search == 'myMeals'
        if (search == 'myMeals') {
          final userId = userService.userId;
          final myMeals =
              allMeals.where((meal) => meal.userId == userId).toList();
          _apiMeals.addAll(myMeals);
          _hasMore.value = false;
          _localMealsDisplayed.value = myMeals.length;
        } else {
          List<Meal> filteredMeals = [];
          if (widget.screen == 'ingredient') {
            if (isLabel) {
              filteredMeals = allMeals
                  .where((meal) => (meal.categories).any((category) =>
                      category.toLowerCase().trim() == search.trim()))
                  .toList();
            } else {
              filteredMeals = allMeals
                  .where((meal) =>
                      meal.title.toLowerCase().contains(search) ||
                      (meal.categories).any((category) =>
                          category.toLowerCase().contains(search)) ||
                      (meal.ingredients).keys.any((ingredient) =>
                          ingredient.toLowerCase().contains(search)))
                  .toList();
            }
          } else if (widget.screen == 'technique') {
            if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
              // User is searching - first filter by technique, then search within results

              // Get the original technique from searchIngredient parameter
              String originalTechnique =
                  widget.searchIngredient ?? widget.search;

              // First, get technique-filtered meals
              final techniqueFilteredMeals = allMeals
                  .where((meal) => originalTechnique.contains('&')
                      ? originalTechnique.toLowerCase().split('&').every(
                          (method) => meal.cookingMethod!
                              .toLowerCase()
                              .contains(method.trim()))
                      : meal.cookingMethod!
                          .toLowerCase()
                          .contains(originalTechnique.toLowerCase()))
                  .toList();

              // Then search within technique-filtered meals
              filteredMeals = techniqueFilteredMeals
                  .where((meal) => meal.title
                      .toLowerCase()
                      .contains(widget.searchQuery!.toLowerCase()))
                  .toList();
            } else {
              // No search query, show technique-filtered meals
              filteredMeals = allMeals
                  .where((meal) => search.contains('&')
                      ? search.toLowerCase().split('&').every((method) => meal
                          .cookingMethod!
                          .toLowerCase()
                          .contains(method.trim()))
                      : meal.cookingMethod!.toLowerCase().contains(search))
                  .toList();
            }
          } else {
            // Default search: search by title, ingredients, and categories
            filteredMeals = allMeals
                .where((meal) =>
                    meal.title.toLowerCase().contains(search) ||
                    (meal.ingredients).keys.any((ingredient) =>
                        ingredient.toLowerCase().contains(search)) ||
                    (meal.categories).any(
                        (category) => category.toLowerCase().contains(search)))
                .toList();
          }

          // Show only the most recent meals first
          filteredMeals.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          _apiMeals.addAll(filteredMeals);
          _hasMore.value = false;
          _localMealsDisplayed.value = filteredMeals.length;
        }
      } else {
        _apiMeals.clear();
        _hasMore.value = mealManager.meals.length > _localPageSize;
      }
    } catch (e) {
    } finally {
      _isLoading.value = false;
    }
  }

  List<Meal> _getFilteredMeals() {
    if (widget.search.isNotEmpty &&
        widget.search.toLowerCase() != 'all' &&
        widget.search.toLowerCase() != 'general') {
      // For search, just show the Firestore (api) meals, already sorted
      return _apiMeals;
    } else {
      // For normal browsing or 'all'/'general', show local meals paginated
      final localMeals = mealManager.meals;
      final sortedLocalMeals = [...localMeals];
      sortedLocalMeals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return [
        ...sortedLocalMeals.take(_localMealsDisplayed.value),
        ..._apiMeals
      ];
    }
  }

  Future<void> _loadMoreMealsIfNeeded() async {
    if (_isLoading.value) return;

    final localMeals = mealManager.meals;

    // Set loading state before any operation
    _isLoading.value = true;

    try {
      // If we still have local meals to show
      if (_localMealsDisplayed.value < localMeals.length) {
        // Add a small delay to show loading state
        await Future.delayed(const Duration(milliseconds: 300));
        _localMealsDisplayed.value += _localPageSize;
        _hasMore.value = _localMealsDisplayed.value < localMeals.length ||
            widget.search.isEmpty;
        return;
      }

      // If we've shown all local meals and search is empty, start fetching from API
      if (widget.search.isEmpty &&
          _localMealsDisplayed.value >= localMeals.length) {
        final newMeals = await _apiService.fetchMeals(
          limit: _apiPageSize,
          searchQuery: widget.search,
          screen: widget.screen,
        );

        // Filter out duplicates
        final existingIds = [
          ...localMeals.map((m) => m.mealId),
          ..._apiMeals.map((m) => m.mealId)
        ];
        final uniqueNewMeals = newMeals
            .where((meal) => !existingIds.contains(meal.mealId))
            .toList();

        _apiMeals.addAll(uniqueNewMeals);
        _hasMore.value = uniqueNewMeals.isNotEmpty;
      }
    } catch (e) {
    } finally {
      _isLoading.value = false;
    }
  }

  Widget _buildNoMealsWidget(BuildContext context) {
    final themeProvider = getThemeProvider(context);
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = themeProvider.isDarkMode;

    return Center(
      child: StatefulBuilder(
        builder: (context, setState) {
          bool isGenerating = false;

          return GestureDetector(
            onTap: () async {
              if (canUseAI() && !isGenerating && widget.screen != 'technique') {
                setState(() {
                  isGenerating = true;
                });

                try {
                  dynamic items;

                  // Show appropriate dialog based on whether it's a category or ingredient
                  if (widget.label != null &&
                      widget.label!.isNotEmpty &&
                      widget.search.isNotEmpty &&
                      widget.search.toLowerCase() ==
                          widget.label?.toLowerCase()) {
                    // Category-based meal generation with specific label
                    try {
                      items = await showCategoryInputDialog(
                        context,
                        label: widget.label!.trim(),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to show category dialog. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  } else if (widget.search.isNotEmpty &&
                      widget.search.toLowerCase() != 'general' &&
                      widget.search.toLowerCase() != 'all') {
                    // Ingredient-based meal generation
                    try {
                      items = await showIngredientInputDialog(
                        context,
                        initialIngredient: widget.search.trim(),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to show ingredient dialog. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  } else {
                    // General category-based meal generation (fallback)
                    try {
                      items = await showCategoryInputDialog(
                        context,
                        label: 'general',
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to show category dialog. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }

                  // Check if user cancelled the dialog
                  if (items == null) {
                    // User cancelled the dialog, no need to show error
                    return;
                  }

                  // Show loading dialog while AI is generating meals
                  showLoadingDialog(context,
                      loadingText: loadingTextGenerateMeals);

                  // Create appropriate prompt based on whether it's category or ingredient
                  String prompt;
                  String contextInfo;

                  if (widget.label != null && items is Map<String, dynamic>) {
                    // Category-based meal generation
                    final categoryData = items as Map<String, dynamic>;
                    final categories =
                        categoryData['categories'] as List<String>? ?? [];

                    // Validate categories before proceeding
                    if (categories.isEmpty) {
                      if (context.mounted) {
                        hideLoadingDialog(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Invalid category data. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    final familyMember =
                        categoryData['familyMember'] as String?;
                    final ageGroup = categoryData['ageGroup'] as String?;

                    // Build prompt with family context if available
                    prompt =
                        'Generate 3 meals that are: ${categories.join(', ')}.';
                    if (familyMember != null && ageGroup != null) {
                      prompt +=
                          ' These meals are for a $ageGroup family member. Please ensure the meals are age-appropriate and suitable for their dietary needs.';
                    }
                    prompt +=
                        ' Focus on meals that match these categories and dietary requirements.';
                    contextInfo = 'Category-based meal generation';
                  } else if (items is List<String>) {
                    // Ingredient-based meal generation
                    final ingredients = items as List<String>;

                    // Validate ingredients before proceeding
                    if (ingredients.isEmpty) {
                      if (context.mounted) {
                        hideLoadingDialog(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'No valid ingredients provided. Please try again.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    prompt =
                        'Generate 2 meals using these ingredients: ${ingredients.join(', ')}. Create delicious and nutritious meals.';
                    contextInfo = 'Ingredient-based meal generation';
                  } else {
                    // Fallback for unexpected data type
                    if (context.mounted) {
                      hideLoadingDialog(context); // Close loading dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Invalid data format. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  // Use generateMealTitlesAndIngredients for both cases

                  // Determine if this is ingredient-based or category-based
                  final isIngredientBased = items is List<String>;
                  final mealCount = isIngredientBased ? 2 : 3;
                  final distribution = isIngredientBased
                      ? {"breakfast": 0, "lunch": 1, "dinner": 1, "snack": 0}
                      : {"breakfast": 1, "lunch": 1, "dinner": 1, "snack": 0};

                  final mealData =
                      await geminiService.generateMealTitlesAndIngredients(
                    prompt,
                    contextInfo,
                    isIngredientBased: isIngredientBased,
                    mealCount: mealCount,
                    customDistribution: distribution,
                  );

                  // Convert to expected format
                  final mealList = mealData['mealPlan'] as List<dynamic>? ?? [];
                  final formattedMeals = mealList.map((meal) {
                    final mealMap = Map<String, dynamic>.from(meal);
                    mealMap['id'] = '';
                    mealMap['source'] = 'ai_generated';
                    mealMap['cookingTime'] =
                        mealMap['cookingTime'] ?? '30 minutes';
                    mealMap['cookingMethod'] =
                        mealMap['cookingMethod'] ?? 'other';
                    mealMap['instructions'] = mealMap['instructions'] ??
                        ['Prepare according to your preference'];
                    mealMap['diet'] = mealMap['diet'] ?? 'balanced';
                    mealMap['categories'] = mealMap['categories'] ?? [];
                    mealMap['serveQty'] = mealMap['serveQty'] ?? 1;
                    return mealMap;
                  }).toList();

                  final mealPlan = {
                    'meals': formattedMeals,
                    'source': 'ai_generated',
                    'count': formattedMeals.length,
                    'message': 'AI-generated meals using improved method',
                  };

                  // Close the loading dialog
                  if (context.mounted) {
                    hideLoadingDialog(context);
                  }

                  // Validate meal plan data before proceeding
                  if (mealPlan == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to generate meals. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  if (mealPlan['meals'] == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to generate meals. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  if (mealPlan['meals'] is! List) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to generate meals. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  final meals = mealPlan['meals'] as List<dynamic>? ?? [];
                  if (meals.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'No meals were generated. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  // Show the generated meals in a selection dialog
                  if (meals.isNotEmpty) {
                    // Show dialog to let user pick one meal
                    await showDialog<Map<String, dynamic>>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        final isDarkMode = getThemeProvider(context).isDarkMode;
                        final textTheme = Theme.of(context).textTheme;
                        return StatefulBuilder(
                          builder: (context, setState) {
                            bool isProcessing = false;

                            return AlertDialog(
                              backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                ),
                              ),
                              title: Text(
                                'Select a Meal',
                                style: textTheme.displaySmall?.copyWith(
                                    fontSize: getPercentageWidth(7, context),
                                    color: kAccent,
                                    fontWeight: FontWeight.w500),
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: meals.length,
                                  itemBuilder: (context, index) {
                                    final meal = meals[index];
                                    final title = meal['title'] ?? 'Untitled';

                                    String cookingTime =
                                        meal['cookingTime'] ?? '';
                                    String cookingMethod =
                                        meal['cookingMethod'] ?? '';

                                    return Card(
                                      color: colors[index % colors.length],
                                      child: ListTile(
                                        enabled: !isProcessing,
                                        title: Text(
                                          title,
                                          style: textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                isDarkMode ? kWhite : kDarkGrey,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (cookingTime.isNotEmpty)
                                              Text(
                                                'Cooking Time: $cookingTime',
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                  color: isDarkMode
                                                      ? kWhite
                                                      : kDarkGrey,
                                                ),
                                              ),
                                            if (cookingMethod.isNotEmpty)
                                              Text(
                                                'Method: $cookingMethod',
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                  color: isDarkMode
                                                      ? kWhite
                                                      : kDarkGrey,
                                                ),
                                              ),
                                          ],
                                        ),
                                        onTap: isProcessing
                                            ? null
                                            : () async {
                                                setState(() {
                                                  isProcessing = true;
                                                });

                                                try {
                                                  // Save basic AI-generated meals to Firestore for Firebase Functions processing
                                                  final userId =
                                                      userService.userId;
                                                  if (userId == null)
                                                    throw Exception(
                                                        'User ID not found');

                                                  // Determine cuisine/category based on request type
                                                  final cuisine =
                                                      items is List<String>
                                                          ? 'ingredient_based'
                                                          : 'category_based';

                                                  // Use saveBasicMealsToFirestore since we have basic meal data
                                                  final saveResult =
                                                      await geminiService
                                                          .saveBasicMealsToFirestore(
                                                    meals.cast<
                                                        Map<String, dynamic>>(),
                                                    cuisine,
                                                  );

                                                  final mealIds = saveResult[
                                                          'mealIds']
                                                      as Map<String, String>;

                                                  // Validate that meals were saved successfully
                                                  if (mealIds.isEmpty) {
                                                    throw Exception(
                                                        'No meals were saved to database');
                                                  }

                                                  // Find the selected meal's ID using title
                                                  final selectedMealTitle =
                                                      meal['title'] as String;
                                                  final selectedMealId =
                                                      mealIds[
                                                          selectedMealTitle];

                                                  // Validate that we found a valid meal ID
                                                  if (selectedMealId == null ||
                                                      selectedMealId.isEmpty) {
                                                    throw Exception(
                                                        'Failed to identify selected meal');
                                                  }

                                                  // Format the meal ID for meal plan storage
                                                  String mealPlanId =
                                                      selectedMealId;
                                                  final isFamilyMode =
                                                      userService
                                                              .currentUser
                                                              .value
                                                              ?.familyMode ??
                                                          false;

                                                  if (isFamilyMode &&
                                                      selectedMealId != null) {
                                                    // Check if we have family member context from category search
                                                    final familyMember = widget
                                                                .label !=
                                                            null
                                                        ? ((items as Map<String,
                                                                    dynamic>)[
                                                                'familyMember']
                                                            as String?)
                                                        : null;
                                                    if (familyMember != null) {
                                                      mealPlanId =
                                                          '$selectedMealId/$familyMember';
                                                    } else {
                                                      // Default to current user
                                                      mealPlanId =
                                                          '$selectedMealId';
                                                    }
                                                  }

                                                  // Validate mealPlanId before proceeding
                                                  if (mealPlanId.isEmpty) {
                                                    throw Exception(
                                                        'Invalid meal plan ID');
                                                  }

                                                  // Store the meal in the meal plan for today
                                                  final today = DateTime.now();
                                                  final formattedDate =
                                                      DateFormat('yyyy-MM-dd')
                                                          .format(today);

                                                  // Validate formattedDate before proceeding
                                                  if (formattedDate.isEmpty) {
                                                    throw Exception(
                                                        'Invalid date format');
                                                  }

                                                  final docRef = firestore
                                                      .collection('mealPlans')
                                                      .doc(userId)
                                                      .collection('date')
                                                      .doc(formattedDate);

                                                  // Validate userId before proceeding
                                                  if (userId.isEmpty) {
                                                    throw Exception(
                                                        'Invalid user ID');
                                                  }

                                                  DocumentSnapshot docSnapshot;
                                                  try {
                                                    docSnapshot =
                                                        await docRef.get();
                                                  } catch (e) {
                                                    throw Exception(
                                                        'Failed to access meal plan document');
                                                  }

                                                  try {
                                                    if (docSnapshot.exists) {
                                                      // Update existing document
                                                      await docRef.update({
                                                        'meals': FieldValue
                                                            .arrayUnion(
                                                                [mealPlanId]),
                                                        'date': formattedDate,
                                                        'isSpecial': (docSnapshot
                                                                        .data()
                                                                    as Map<
                                                                        String,
                                                                        dynamic>?)?[
                                                                'isSpecial'] ??
                                                            false,
                                                        'userId': userId,
                                                        'timestamp': FieldValue
                                                            .serverTimestamp(),
                                                      });
                                                    } else {
                                                      // Create new document
                                                      await docRef.set({
                                                        'meals': [mealPlanId],
                                                        'date': formattedDate,
                                                        'isSpecial': false,
                                                        'userId': userId,
                                                        'timestamp': FieldValue
                                                            .serverTimestamp(),
                                                      });
                                                    }
                                                  } catch (e) {
                                                    throw Exception(
                                                        'Failed to update meal plan');
                                                  }

                                                  if (context.mounted) {
                                                    Navigator.of(context).pop();
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            'Meal created and added to today\'s meal plan!'),
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            'Failed to create meal: $e'),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
                                                  }
                                                } finally {
                                                  setState(() {
                                                    isProcessing = false;
                                                  });
                                                }
                                              },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: getTextScale(3.5, context),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  } else {
                    throw Exception('No meals generated');
                  }
                } catch (e) {
                  // Show error message if meal generation fails
                  String errorMessage =
                      'Chef, the kitchen hit a snag. Let me reset and try again.';

                  if (e.toString().contains('overloaded') ||
                      e.toString().contains('503')) {
                    errorMessage =
                        'Chef, the station is busy right now. Please try again in a few minutes.';
                  } else if (e.toString().contains('fallback')) {
                    errorMessage =
                        'Using backup menu suggestions while the main station is unavailable.';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: e.toString().contains('fallback')
                          ? Colors.orange
                          : Colors.red,
                      duration: Duration(
                          seconds: e.toString().contains('fallback') ? 3 : 5),
                    ),
                  );
                } finally {
                  setState(() {
                    isGenerating = false;
                  });
                }
              } else {
                if (widget.screen != 'technique') {
                  showPremiumRequiredDialog(context, isDarkMode);
                }
              }
            },
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: getPercentageHeight(8, context)),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(seconds: 15),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(
                            value * 200 - 100, 0), // Moves from -100 to +100
                        child: CircleAvatar(
                          backgroundColor: isDarkMode ? kWhite : kBlack,
                          radius: getResponsiveBoxSize(context, 18, 18),
                          backgroundImage: AssetImage(tastyImage),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "No meals available.",
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w400,
                      fontSize: getTextScale(6, context),
                      color: kAccentLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (widget.screen != 'technique')
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(4, context),
                      ),
                      child: Text(
                        canUseAI()
                            ? 'Generate Meals with ${capitalizeFirstLetter(widget.search)}!'
                            : 'Go Premium to generate a Meal!',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: kAccent,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  SizedBox(height: getPercentageHeight(8, context)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final displayedMeals = _getFilteredMeals();

      if (displayedMeals.isEmpty && !_isLoading.value) {
        return SliverFillRemaining(
          child: _buildNoMealsWidget(context),
        );
      }

      return SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(3, context),
          vertical: getPercentageHeight(1, context),
        ),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == displayedMeals.length) {
                if (!_hasMore.value) return null;

                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(getPercentageWidth(1, context)),
                    child: _isLoading.value
                        ? Container(
                            padding: EdgeInsets.all(
                                getPercentageWidth(0.8, context)),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const CircularProgressIndicator(
                              color: kAccent,
                              strokeWidth: 3,
                            ),
                          )
                        : TextButton(
                            onPressed: _loadMoreMealsIfNeeded,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(2, context),
                                  vertical: getPercentageHeight(1, context)),
                              backgroundColor: kAccent.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'See More',
                              style: TextStyle(
                                fontSize: getTextScale(3, context),
                                color: kAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                );
              }

              final meal = displayedMeals[index];
              final isSelected = widget.selectedMealIds.contains(meal.mealId);
              return RecipeCardFlex(
                recipe: meal,
                isSelected: widget.enableSelection && isSelected,
                press: widget.enableSelection
                    ? () {
                        if (widget.onMealToggle != null) {
                          widget.onMealToggle!(meal.mealId);
                        }
                      }
                    : () {
                        // Use the callback if provided, otherwise fall back to direct navigation
                        if (widget.onRecipeTap != null) {
                          widget.onRecipeTap!(meal);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipeDetailScreen(
                                mealData: meal,
                              ),
                            ),
                          );
                        }
                      },
                height: getPercentageHeight(22, context),
              );
            },
            childCount: displayedMeals.length + (_hasMore.value ? 1 : 0),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: getPercentageHeight(20, context),
            crossAxisSpacing: getPercentageWidth(2, context),
            mainAxisSpacing: getPercentageHeight(2, context),
          ),
        ),
      );
    });
  }
}
