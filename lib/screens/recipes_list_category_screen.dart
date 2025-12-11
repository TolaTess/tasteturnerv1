import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/edit_goal.dart';
import '../widgets/category_selector.dart';
import '../widgets/icon_widget.dart';
import '../widgets/search_button.dart';
import 'createrecipe_screen.dart';
import 'search_results_screen.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../widgets/card_overlap.dart';
import '../service/symptom_analysis_service.dart';

class RecipeListCategory extends StatefulWidget {
  final String searchIngredient;
  final int index;
  final bool isFilter;
  final bool isMealplan;
  final String? mealPlanDate;
  final String screen;
  final bool? isSpecial;
  final bool isSharedCalendar;
  final String? sharedCalendarId;
  final bool isBack;
  final bool isFamilyMode;
  final String? familyMember;
  final bool? isBackToMealPlan;
  final bool isNoTechnique;

  const RecipeListCategory({
    Key? key,
    required this.index,
    required this.searchIngredient,
    this.isFilter = false,
    this.isMealplan = false,
    this.mealPlanDate,
    this.screen = 'recipe',
    this.isSpecial,
    this.isSharedCalendar = false,
    this.sharedCalendarId,
    this.isBack = false,
    this.isFamilyMode = false,
    this.familyMember = '',
    this.isBackToMealPlan = false,
    this.isNoTechnique = false,
  }) : super(key: key);

  @override
  _RecipeListCategoryState createState() => _RecipeListCategoryState();
}

class _RecipeListCategoryState extends State<RecipeListCategory> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String searchQuery = '';
  List<String> selectedMealIds = [];
  String selectedCategory = 'general';
  String selectedCategoryId = '';
  String selectedDietFilter = '';
  bool _isRefreshing = false;
  double _savedScrollPosition = 0.0;
  List<Map<String, dynamic>> categoryDatas = [];

  @override
  void initState() {
    super.initState();
    // Remove automatic refresh call to prevent double loading
    _searchController.text = widget.searchIngredient;
    // Set default for meal category
    categoryDatas = helperController.mainCategory;
    if (userService.currentUser.value?.familyMode ?? false) {
      // Add "General" option first
      categoryDatas.clear();

      final categoryDatasMeal = helperController.kidsCategory;
      if (categoryDatasMeal.isNotEmpty) {
        categoryDatasMeal.forEach((element) {
          categoryDatas.add({'id': element['name'], 'name': element['name']});
        });
      }
    }

    // Only refresh if we don't have data yet
    if (mealManager.meals.isEmpty) {
      _onRefresh();
    }

    // Restore scroll position after the widget is built with a delay for smoother UX
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _restoreScrollPosition();
        }
      });
    });
  }

  @override
  void dispose() {
    _saveScrollPosition();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveScrollPosition() {
    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.offset;
      // Store in a global map or shared preferences for persistence across app sessions
      // For now, we'll use a simple static map
      _scrollPositions[_getScrollKey()] = _savedScrollPosition;
    }
  }

  void _restoreScrollPosition() {
    final key = _getScrollKey();
    final savedPosition = _scrollPositions[key];
    if (savedPosition != null && _scrollController.hasClients) {
      final currentPosition = _scrollController.offset;
      final scrollDistance = (savedPosition - currentPosition).abs();

      // If the scroll distance is very large (more than 2 screen heights),
      // jump instantly to avoid very long animations
      if (scrollDistance > MediaQuery.of(context).size.height * 2) {
        _scrollController.jumpTo(savedPosition);
      } else {
        // Use smooth animation for shorter distances
        _scrollController.animateTo(
          savedPosition,
          duration: Duration(
              milliseconds: (scrollDistance / 2).clamp(400, 1000).round()),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  String _getScrollKey() {
    // Create a unique key based on the screen parameters
    return 'recipes_${widget.searchIngredient}_${widget.screen}_${widget.index}';
  }

  // Static map to store scroll positions
  static final Map<String, double> _scrollPositions = {};

  Future<void> _onRefresh() async {
    if (_isRefreshing) return; // Prevent multiple simultaneous refreshes

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Determine what category/search to refresh based on current state
      String refreshTarget = _determineRefreshTarget();

      // Only fetch meals if we have a specific target
      if (refreshTarget != 'general' && refreshTarget != 'all') {
        await mealManager.fetchMealsByCategory(refreshTarget);
      }

      // If there's a search query, also refresh search results
      if (searchQuery.isNotEmpty) {
        await mealManager.searchMeals(searchQuery);
      } else if (widget.searchIngredient.isNotEmpty &&
          widget.searchIngredient != 'general') {
        await mealManager.searchMeals(widget.searchIngredient);
      }
    } catch (e) {
      debugPrint('Error refreshing recipes: $e');
      // Show error message to user
      if (mounted) {
        showTastySnackbar(
          'Refresh Failed',
          'Unable to refresh recipes. Please try again.',
          context,
          backgroundColor: kRed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  String _determineRefreshTarget() {
    // Determine what to refresh based on current screen state
    if (searchQuery.isNotEmpty) {
      return searchQuery;
    } else if (widget.searchIngredient.isNotEmpty) {
      return widget.searchIngredient;
    } else {
      return selectedCategory;
    }
  }

  String _getSearchTarget() {
    // Priority order: search query > selected category (family mode) > search ingredient > general
    if (searchQuery.isNotEmpty) {
      return searchQuery;
    } else if (selectedCategory.isNotEmpty && selectedCategory != 'general') {
      return selectedCategory;
    } else if (widget.searchIngredient.isNotEmpty) {
      return widget.searchIngredient;
    } else {
      return 'general';
    }
  }

  void toggleMealSelection(String mealId) {
    setState(() {
      if (selectedMealIds.contains(mealId)) {
        selectedMealIds.remove(mealId);
      } else {
        selectedMealIds.add(mealId);
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });

    // Debounce search to avoid too many requests
    if (query.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (query == searchQuery) {
          // Still the same query after delay, perform search
          mealManager.searchMeals(query);
        }
      });
    }
  }

  // Helper method to navigate to recipe detail with scroll position saving
  void _navigateToRecipeDetail(Meal meal) {
    // Save scroll position before navigating
    _saveScrollPosition();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(
          mealData: meal,
        ),
      ),
    ).then((_) {
      // When returning from recipe detail, restore scroll position with a slight delay
      // This allows the UI to settle before scrolling
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _restoreScrollPosition();
        }
      });
    });
  }

  Future<void> addMealsToMealPlan(
      List<String> selectedMealIds, String? mealPlanDate) async {
    if (mealPlanDate == null) {
      debugPrint('Meal plan date is required.');
      return;
    }

    // Check for symptom triggers before adding meals
    final shouldProceed = await _checkSymptomTriggers(selectedMealIds);
    if (!shouldProceed) {
      return; // User cancelled
    }

    try {
      final userId = userService.userId!;
      final docRef = widget.isSharedCalendar
          ? firestore
              .collection('shared_calendars')
              .doc(widget.sharedCalendarId ?? '')
              .collection('date')
              .doc(mealPlanDate)
          : firestore
              .collection('mealPlans')
              .doc(userId)
              .collection('date')
              .doc(mealPlanDate);

      // Check if the document exists
      final docSnapshot = await docRef.get();

      if (widget.isFamilyMode && widget.familyMember != null) {
        // Append family member to each meal ID for family mode
        if (widget.familyMember?.toLowerCase() ==
            userService.currentUser.value?.displayName?.toLowerCase()) {
          selectedMealIds = selectedMealIds
              .map((mealId) => '$mealId/${userService.userId}')
              .toList();
        } else {
          selectedMealIds = selectedMealIds
              .map((mealId) => '$mealId/${widget.familyMember}')
              .toList();
        }
      }

      if (docSnapshot.exists) {
        // Update the existing document with the new mealIds
        await docRef.update({
          'meals': FieldValue.arrayUnion(selectedMealIds),
          'date': mealPlanDate,
          'isSpecial': docSnapshot.data()?['isSpecial'] ?? false,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Create a new document for the date
        final data = {
          'meals': selectedMealIds,
          'date': mealPlanDate,
          'isSpecial': widget.isSpecial ?? false,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        };

        await docRef.set(data);
      }

      Get.back();
    } catch (e) {
      debugPrint('Error adding meals to meal plan: $e');
    }
  }

  /// Check if selected meals contain ingredients that have caused symptoms
  Future<bool> _checkSymptomTriggers(List<String> mealIds) async {
    try {
      final userId = userService.userId ?? '';
      if (userId.isEmpty) return true; // No user, skip check

      // Get top triggers from symptom analysis
      final symptomAnalysisService = SymptomAnalysisService.instance;
      final topTriggers = await symptomAnalysisService.getTopTriggers(userId,
          limit: 5, days: 30);

      if (topTriggers.isEmpty) {
        return true; // No triggers found, proceed
      }

      // Get ingredients from selected meals
      final allMealIngredients = <String>[];
      for (final mealId in mealIds) {
        // Clean meal ID (remove meal type suffix if present)
        final cleanMealId = mealId.split('/').first;
        try {
          final mealDoc =
              await firestore.collection('meals').doc(cleanMealId).get();
          if (mealDoc.exists) {
            final mealData = mealDoc.data()!;
            final ingredients =
                mealData['ingredients'] as Map<String, dynamic>? ?? {};
            allMealIngredients
                .addAll(ingredients.keys.map((k) => k.toLowerCase()));
          }
        } catch (e) {
          debugPrint('Error fetching meal ingredients: $e');
        }
      }

      // Check for matches
      final matchedTriggers = <Map<String, dynamic>>[];
      for (final trigger in topTriggers) {
        final triggerIngredient =
            (trigger['ingredient'] as String).toLowerCase();
        if (allMealIngredients.any((ing) =>
            ing.contains(triggerIngredient) ||
            triggerIngredient.contains(ing))) {
          matchedTriggers.add(trigger);
        }
      }

      if (matchedTriggers.isEmpty) {
        return true; // No matches, proceed
      }

      // Show warning dialog
      return await _showSymptomWarningDialog(matchedTriggers);
    } catch (e) {
      debugPrint('Error checking symptom triggers: $e');
      return true; // On error, proceed anyway
    }
  }

  /// Show warning dialog about symptom triggers
  Future<bool> _showSymptomWarningDialog(
      List<Map<String, dynamic>> triggers) async {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: getIconScale(6, context)),
                SizedBox(width: getPercentageWidth(2, context)),
                Expanded(
                  child: Text(
                    'Symptom Trigger Warning',
                    style: textTheme.titleLarge?.copyWith(
                      color: isDarkMode ? kWhite : kBlack,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'These meals contain ingredients that have caused symptoms in the past:',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1.5, context)),
                  ...triggers.map((trigger) {
                    final ingredient = trigger['ingredient'] as String;
                    final symptom = trigger['mostCommonSymptom'] as String;
                    final occurrences = trigger['occurrences'] as int;
                    final avgSeverity = trigger['averageSeverity'] as double;

                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: getPercentageHeight(1, context)),
                      child: Container(
                        padding: EdgeInsets.all(getPercentageWidth(3, context)),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              capitalizeFirstLetter(ingredient),
                              style: textTheme.titleSmall?.copyWith(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(0.5, context)),
                            Text(
                              'Has caused $symptom $occurrences time(s) with average severity ${avgSeverity.toStringAsFixed(1)}/5',
                              style: textTheme.bodySmall?.copyWith(
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Text(
                    'Chef, when cooking, please ensure to remove any ingredient that have caused symptoms in the past.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancel',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'Understood',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final isFamilyMode = userService.currentUser.value?.familyMode ?? false;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        centerTitle: true,
        title: Text(
          capitalizeFirstLetter(widget.searchIngredient.isEmpty
              ? 'Full Plates'
              : widget.searchIngredient),
          style: textTheme.displaySmall?.copyWith(
            fontSize: getTextScale(7, context),
          ),
        ),
        actions: [
          // Add new recipe button
          InkWell(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateRecipeScreen(
                  screenType: 'list',
                ),
              ),
            ),
            child: const IconCircleButton(
              icon: Icons.add,
              isRemoveContainer: false,
            ),
          ),
          SizedBox(width: getPercentageWidth(2, context)),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: kAccent,
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            strokeWidth: 3,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      widget.isFilter
                          ? const SizedBox.shrink()
                          : SizedBox(height: getPercentageHeight(2, context)),
                      // Search bar
                      widget.isFilter
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(1.5, context)),
                              child: SearchButton2(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                kText: widget.screen == 'technique'
                                    ? 'Search ${capitalizeFirstLetter(widget.searchIngredient)} meals..'
                                    : searchMealHint,
                              ),
                            ),
                      widget.isFilter || searchQuery.isNotEmpty
                          ? const SizedBox.shrink()
                          : SizedBox(height: getPercentageHeight(2, context)),

                      // Curated dietPreference meals section
                      (widget.isNoTechnique || searchQuery.isNotEmpty)
                          ? const SizedBox.shrink()
                          : Obx(() {
                              final dietPreference = userService.currentUser
                                  .value?.settings['dietPreference'];
                              if (dietPreference != null &&
                                  !widget.isNoTechnique &&
                                  searchQuery.isEmpty) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(
                                              left: getPercentageWidth(
                                                  3, context)),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Curated',
                                                style: textTheme.titleLarge
                                                    ?.copyWith(
                                                  fontSize:
                                                      getTextScale(5, context),
                                                  fontWeight: FontWeight.w600,
                                                  color: isDarkMode
                                                      ? kWhite
                                                      : kDarkGrey,
                                                ),
                                              ),
                                              SizedBox(
                                                  width: getPercentageWidth(
                                                      1, context)),
                                              Text(
                                                '$dietPreference Meals',
                                                textAlign: TextAlign.left,
                                                style: textTheme.titleLarge
                                                    ?.copyWith(
                                                        fontSize: getTextScale(
                                                            5, context),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        color: kAccent),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const NutritionSettingsPage(
                                                        isHealthExpand: true),
                                              ),
                                            );
                                          },
                                          icon: Icon(
                                            Icons.edit,
                                            size: getIconScale(4.5, context),
                                            color: kAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    FutureBuilder<List<Meal>>(
                                      key: ValueKey(
                                          'curated_${dietPreference}_${widget.searchIngredient}_${searchQuery.isEmpty ? 'no_search' : 'searching'}'),
                                      future: mealManager.fetchMealsByCategory(
                                        dietPreference.toString().toLowerCase(),
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return SizedBox(
                                            height: getPercentageHeight(
                                                25, context),
                                            child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        color: kAccent)),
                                          );
                                        }
                                        if (!snapshot.hasData ||
                                            snapshot.data!.isEmpty) {
                                          return SizedBox(
                                            height:
                                                getPercentageHeight(6, context),
                                            child: const Center(
                                                child: Text(
                                                    'No meals found for your diet preference.')),
                                          );
                                        }
                                        final allMeals = snapshot.data!;
                                        // Randomly select 5 meals
                                        allMeals.shuffle();
                                        final meals = allMeals.take(5).toList();

                                        return Container(
                                          height: getPercentageHeight(
                                              25, context), // Increased height
                                          margin: EdgeInsets.symmetric(
                                            vertical:
                                                getPercentageHeight(1, context),
                                          ), // Add vertical margin
                                          child: OverlappingCardsView(
                                            cardWidth:
                                                getPercentageWidth(70, context),
                                            cardHeight: getPercentageHeight(25,
                                                context), // Slightly reduced card height
                                            overlap: 60,
                                            isRecipe: true,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: getPercentageWidth(2,
                                                  context), // Reduced horizontal padding
                                            ),
                                            children: List.generate(
                                              meals.length,
                                              (index) {
                                                final meal = meals[index];
                                                return OverlappingCard(
                                                  title: meal.title,
                                                  subtitle: (meal.description
                                                                  ?.isNotEmpty ==
                                                              true &&
                                                          meal.description !=
                                                              'unknown description')
                                                      ? meal.description!
                                                      : '${meal.calories} kcal • ${meal.serveQty} servings',
                                                  color: colors[
                                                      index % colors.length],
                                                  imageUrl: meal.mediaPaths
                                                              .isNotEmpty &&
                                                          meal.mediaPaths.first
                                                              .startsWith(
                                                                  'http')
                                                      ? meal.mediaPaths.first
                                                      : null,
                                                  width: getPercentageWidth(
                                                      70, context),
                                                  height: getPercentageHeight(
                                                      20,
                                                      context), // Match the cardHeight
                                                  index: index,
                                                  isRecipe: true,
                                                  onTap: () {
                                                    _navigateToRecipeDetail(
                                                        meal);
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              }
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const NutritionSettingsPage(
                                                isHealthExpand: true)),
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.all(
                                      getPercentageWidth(2, context)),
                                  decoration: BoxDecoration(
                                    color: kAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                        getPercentageWidth(2, context)),
                                  ),
                                  child: Text(
                                    'No diet preference found',
                                    style: TextStyle(
                                      fontSize: getTextScale(3, context),
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode ? kWhite : kDarkGrey,
                                    ),
                                  ),
                                ),
                              );
                            }),

                      SizedBox(height: getPercentageHeight(3, context)),

                      if (categoryDatas.isNotEmpty) ...[
                        CategorySelector(
                          categories: categoryDatas
                              .map((e) => {'id': e['name'], 'name': e['name']})
                              .toList(),
                          selectedCategoryId: selectedCategoryId.isNotEmpty
                              ? selectedCategoryId
                              : selectedCategory,
                          onCategorySelected: (category, categoryId) async {
                            setState(() {
                              selectedCategory = category;
                              selectedCategoryId = categoryId;
                            });

                            // Fetch meals for the selected category
                            if (category.isNotEmpty && category != 'general') {
                              await mealManager
                                  .fetchMealsByCategory(category.toLowerCase());
                            }
                          },
                          isDarkMode: isDarkMode,
                          accentColor: kAccentLight,
                          darkModeAccentColor: kDarkModeAccent,
                          isFunMode: false,
                        ),
                      ],

                      widget.isNoTechnique
                          ? const SizedBox.shrink()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                    height: getPercentageHeight(4, context)),
                                Center(
                                  child: Text(
                                    isFamilyMode &&
                                            selectedCategory != 'general'
                                        ? capitalizeFirstLetter(
                                            selectedCategory)
                                        : 'All Full Plates',
                                    style: textTheme.displayMedium?.copyWith(
                                      fontSize: getTextScale(5.5, context),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                    height: getPercentageHeight(1.5, context)),
                              ],
                            ),
                    ],
                  ),
                ),

                // Recipes list per category
                SearchResultGrid(
                  key: ValueKey(
                      'search_grid_${widget.screen}_${widget.searchIngredient}_${searchQuery}_${selectedCategory}_${_isRefreshing ? 'refreshing' : 'stable'}'),
                  search: _getSearchTarget(),
                  searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
                  searchIngredient: widget.searchIngredient.isNotEmpty
                      ? widget.searchIngredient
                      : null,
                  enableSelection: widget.isMealplan,
                  selectedMealIds: selectedMealIds,
                  onMealToggle: toggleMealSelection,
                  screen: widget.screen,
                  onRecipeTap: _navigateToRecipeDetail,
                  label: selectedCategory,
                ),
              ],
            ),
          ),

          // Loading overlay when refreshing
          if (_isRefreshing)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(
                  color: kAccent,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: widget.isMealplan
          ? MediaQuery.of(context).size.height > 1100
              ? FloatingActionButton.large(
                  onPressed: selectedMealIds.isNotEmpty
                      ? () => addMealsToMealPlan(
                          appendMealTypes(selectedMealIds), widget.mealPlanDate)
                      : null,
                  backgroundColor:
                      selectedMealIds.isNotEmpty ? kAccent : kLightGrey,
                  child: Icon(Icons.save_alt,
                      size: getPercentageWidth(7, context)),
                )
              : FloatingActionButton(
                  onPressed: selectedMealIds.isNotEmpty
                      ? () => addMealsToMealPlan(
                          appendMealTypes(selectedMealIds), widget.mealPlanDate)
                      : null,
                  backgroundColor:
                      selectedMealIds.isNotEmpty ? kAccent : kLightGrey,
                  child: Icon(Icons.save_alt,
                      size: getPercentageWidth(7, context)),
                )
          : null,
    );
  }
}
