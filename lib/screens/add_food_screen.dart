import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasteturner/pages/edit_goal.dart';

import '../constants.dart';
import '../data_models/ingredient_data.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../helper/utils.dart';
import '../helper/helper_functions.dart';
import '../service/food_api_service.dart';
import '../service/meal_api_service.dart';
import '../service/calorie_adjustment_service.dart';
import '../service/reverse_pantry_search_service.dart';

import '../widgets/daily_routine_list_horizontal.dart';
import '../widgets/meal_detail_widget.dart';
import '../widgets/search_button.dart';
import '../widgets/info_icon_widget.dart';
import 'createrecipe_screen.dart';
import 'daily_summary_screen.dart';
import 'tomorrow_action_items_screen.dart';

class AddFoodScreen extends StatefulWidget {
  final String title;
  final DateTime? date;
  final String? notAllowedMealType;
  final bool isShowSummary;
  final String? initialMealType;

  const AddFoodScreen({
    super.key,
    this.title = 'Chef\'s Logs',
    this.date,
    this.notAllowedMealType,
    this.isShowSummary = false,
    this.initialMealType,
  });

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen>
    with TickerProviderStateMixin {
  String foodType = 'Breakfast'; // Default meal type
  late DateTime currentDate; // Current date for navigation

  // Updated lists with correct types
  List<Meal> _allMeals = [];
  List<MacroData> _allIngredients = [];
  List<dynamic> _searchResults = [];
  final String userId = userService.userId ?? '';
  final TextEditingController _searchController = TextEditingController();
  final MealApiService _apiService = MealApiService();
  final FoodApiService _macroApiService = FoodApiService();
  final RxBool _isSearching = false.obs;
  final CalorieAdjustmentService _calorieAdjustmentService =
      Get.put(CalorieAdjustmentService());
  Timer? _searchDebounceTimer;

  // Debounce timers for snackbars to prevent repeated displays during slider dragging
  Timer? _waterSnackbarDebounceTimer;
  Timer? _stepsSnackbarDebounceTimer;

  bool allDisabled = false;

  // Add this as a class field at the top of the class
  List<UserMeal> _pendingMacroItems = [];

  // Track when meals were last modified to ensure accurate calorie calculations
  final Map<String, DateTime> _lastMealModification = {};

  // Hide calories feature
  bool showCaloriesAndGoal = true;

  // Scroll controller and keys for scrolling to sections
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _yesterdaySummaryKey = GlobalKey();
  final GlobalKey _quickUpdateKey = GlobalKey();

  /// Handle errors with consistent snackbar display
  void _handleError(String message, {String? details}) {
    if (!mounted || !context.mounted) return;
    debugPrint('Error: $message${details != null ? ' - $details' : ''}');
    showTastySnackbar(
      'Error',
      message,
      context,
      backgroundColor: Colors.red,
    );
  }

  // Track pending items modifications for debugging
  void _addPendingItem(UserMeal item) {
    _pendingMacroItems.add(item);
  }

  void _clearPendingItems() {
    _pendingMacroItems.clear();
  }

  // Helper method to retry operations with exponential backoff
  // Optimized: Reduced retries and delays for faster failure
  Future<T> _retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 2, // Reduced from 3 to 2
    Duration initialDelay =
        const Duration(milliseconds: 300), // Reduced from 1s to 300ms
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }
        // Exponential backoff: 300ms, 600ms (faster than before)
        await Future.delayed(delay);
        delay = Duration(milliseconds: delay.inMilliseconds * 2);
        debugPrint('Retry attempt $attempt/$maxRetries after error: $e');
      }
    }
    throw Exception('Max retries exceeded');
  }

  // Method to manually refresh meal data for a specific meal type
  Future<void> _refreshMealData(String mealType) async {
    try {
      // Force a refresh of the daily data
      // The reactive listeners will automatically update the UI, no need for setState
      dailyDataController.listenToDailyData(
        userId,
        widget.date ?? DateTime.now(),
      );

      // Track when this meal type was last modified
      _lastMealModification[mealType] = DateTime.now();

      // No need for setState - reactive updates will handle UI refresh
    } catch (e) {
      debugPrint('Error refreshing meal data: $e');
    }
  }

  // Helper method to check if any meals have been logged
  bool _hasAnyMealsLogged() {
    final mealList = dailyDataController.userMealList;
    // Check if any meal type has at least one meal
    return mealList.values.any((meals) => meals.isNotEmpty);
  }

  // Helper method to get current calories for a meal type by counting actual meals in the list
  int _getCurrentCaloriesForMealType(String mealType) {
    // Get the actual meals from the userMealList instead of relying on observable values
    final currentMeals = dailyDataController.userMealList[mealType] ?? [];

    // If no meals in the list, return 0
    if (currentMeals.isEmpty) {
      return 0;
    }

    // Count calories from actual meals in the list
    final totalCalories =
        currentMeals.fold<int>(0, (sum, meal) => sum + meal.calories);

    return totalCalories;
  }

  // Method to get a snapshot of current meal data for accurate calculations
  Map<String, dynamic> _getMealTypeSnapshot(String mealType) {
    final currentMeals = dailyDataController.userMealList[mealType] ?? [];
    final currentCalories =
        currentMeals.fold<int>(0, (sum, meal) => sum + meal.calories);

    return {
      'mealCount': currentMeals.length,
      'totalCalories': currentCalories,
      'meals': currentMeals
          .map((meal) => {
                'name': meal.name,
                'calories': meal.calories,
              })
          .toList(),
    };
  }

  // Method to get total pending calories
  int _getTotalPendingCalories() {
    final total =
        _pendingMacroItems.fold<int>(0, (sum, item) => sum + item.calories);
    return total;
  }

  @override
  void initState() {
    super.initState();

    // Initialize current date from widget parameter or use today
    currentDate = widget.date ?? DateTime.now();

    // Initialize meal type from widget parameter if provided
    if (widget.initialMealType != null && widget.initialMealType!.isNotEmpty) {
      foodType = widget.initialMealType!;
    }

    // Load show calories preference
    loadShowCaloriesPref().then((value) {
      if (mounted) {
        setState(() {
          showCaloriesAndGoal = value;
        });
      }
    });

    // Defer the data loading until after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadCalorieAdjustments();
    });

    _getAllDisabled().then((value) {
      if (value) {
        allDisabled = value;
        setState(() {
          allDisabled = value;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when dependencies change (e.g., when returning to this screen)
    // Defer to avoid calling setState/markNeedsBuild during build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  // Load calorie adjustments from SharedPreferences
  Future<void> _loadCalorieAdjustments() async {
    await _calorieAdjustmentService.loadAdjustmentsFromSharedPrefs();
  }

  Future<bool> _getAllDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('allDisabledKey') ?? false;
  }

  @override
  void dispose() {
    // Cancel debounce timers to prevent memory leaks
    _searchDebounceTimer?.cancel();
    _waterSnackbarDebounceTimer?.cancel();
    _stepsSnackbarDebounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    // Clear pending items to prevent memory leaks
    _clearPendingItems();
    _lastMealModification.clear();
    // Don't clear adjustments - let them persist throughout the day
    super.dispose();
  }

  // Scroll to a section using its GlobalKey
  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadData() async {
    try {
      // Fetch meals and ingredients
      _allMeals = mealManager.meals;
      _allIngredients = macroManager.ingredient;
      dailyDataController.listenToDailyData(userId, currentDate);

      // Ensure calorie adjustment service has current data
      await _calorieAdjustmentService.loadAdjustmentsFromSharedPrefs();
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted && context.mounted) {
        _handleError(
          'Failed to load data',
          details:
              'Please try again. If the problem persists, restart the app.',
        );
      }
    }
  }

  // Method to handle date navigation and reload data
  void _handleDateNavigation(DateTime newDate) {
    setState(() {
      currentDate = newDate;
    });
    _loadData();
  }

  // Debounced search handler
  void _onSearchChanged(String query) {
    // Cancel previous timer if exists
    _searchDebounceTimer?.cancel();

    // If query is empty, clear results immediately
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      _isSearching.value = false;
      return;
    }

    // Debounce the actual search by 400ms
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _filterSearchResults(query);
      }
    });
  }

  void _filterSearchResults(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      _isSearching.value = false;
      return;
    }

    _isSearching.value = true;

    // Track the latest query to avoid race conditions
    final String currentQuery = query;

    // Pre-compute lowercase query once for better performance
    final queryLower = query.toLowerCase();

    // Helper function to get title from item
    String? _getItemTitle(dynamic item) {
      if (item is Meal) return item.title;
      if (item is MacroData) return item.title;
      if (item is IngredientData) return item.title;
      return null;
    }

    // Search local meals and ingredients in a single optimized pass
    final localResults = <dynamic>[];

    // Search meals
    for (final meal in _allMeals) {
      if (meal.title.toLowerCase().contains(queryLower)) {
        localResults.add(meal);
      }
    }

    // Search ingredients
    for (final ingredient in _allIngredients) {
      if (ingredient.title.toLowerCase().contains(queryLower)) {
        localResults.add(ingredient);
      }
    }

    // Filter out 'Unknown' items
    final filteredLocalResults = localResults.where((item) {
      final title = _getItemTitle(item);
      return title != null && title != 'Unknown';
    }).toList();

    // Show local results immediately (single setState)
    if (mounted && currentQuery == _searchController.text) {
      setState(() {
        _searchResults = filteredLocalResults;
      });
    }

    // Now fetch API results asynchronously and append them
    if (query.length >= 3) {
      try {
        // Use retry logic for API calls
        final apiMealsFuture = _retryOperation(() => _apiService.fetchMeals(
              limit: 5, // Limit API results
              searchQuery: query,
            ));
        final apiIngredientsFuture =
            _retryOperation(() => _macroApiService.searchIngredients(query));

        // Wait for both API calls
        final results = await Future.wait([
          apiMealsFuture,
          apiIngredientsFuture,
        ]);

        // Before updating, check if the query is still the latest and widget is mounted
        if (!mounted || currentQuery != _searchController.text) {
          // User has typed something else or widget is disposed, so don't update
          _isSearching.value = false;
          return;
        }

        List<Meal> apiMeals = results[0] as List<Meal>;
        List<IngredientData> apiIngredients =
            results[1] as List<IngredientData>;

        // Filter API results efficiently
        final apiResults = <dynamic>[];
        for (final item in [...apiMeals, ...apiIngredients]) {
          final title = _getItemTitle(item);
          if (title != null &&
              title != 'Unknown' &&
              title.toLowerCase().contains(queryLower)) {
            apiResults.add(item);
          }
        }

        // Append API results to local results (single setState)
        if (mounted && currentQuery == _searchController.text) {
          setState(() {
            _searchResults = [...filteredLocalResults, ...apiResults];
          });
        }
      } catch (e) {
        debugPrint('Error fetching API search results: $e');
        // Keep local results even if API fails
      }
    }

    if (mounted) {
      _isSearching.value = false;
    }
  }

  void _showSearchResults(BuildContext context, String mealType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color:
                    getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: getThemeProvider(context).isDarkMode
                        ? kWhite.withValues(alpha: kMidOpacity)
                        : kBlack.withValues(alpha: kMidOpacity),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: getPercentageWidth(10, context),
                    height: getPercentageHeight(1, context),
                    decoration: BoxDecoration(
                      color: getThemeProvider(context).isDarkMode
                          ? kWhite.withValues(alpha: 0.3)
                          : kBlack.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Meal type header
                  Padding(
                    padding: EdgeInsets.only(
                        top: getPercentageHeight(4, context),
                        bottom: getPercentageHeight(2, context)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Log to ${capitalizeFirstLetter(foodType)}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: getPercentageWidth(4.5, context),
                                    fontWeight: FontWeight.w400,
                                    color: getThemeProvider(context).isDarkMode
                                        ? kWhite
                                        : kBlack,
                                  ),
                        ),
                        if (_pendingMacroItems.isNotEmpty) ...[
                          SizedBox(width: getPercentageWidth(2, context)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(2, context),
                              vertical: getPercentageHeight(0.5, context),
                            ),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_pendingMacroItems.length} pending',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: kAccent,
                                    fontWeight: FontWeight.w500,
                                    fontSize: getTextScale(2.5, context),
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Show pending items summary if any
                  if (_pendingMacroItems.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: getPercentageHeight(2, context),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(getPercentageWidth(2, context)),
                        decoration: BoxDecoration(
                          color: kAccentLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: kAccentLight.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: kAccentLight,
                                  size: getIconScale(4, context),
                                ),
                                SizedBox(width: getPercentageWidth(1, context)),
                                Text(
                                  showCaloriesAndGoal
                                      ? 'Pending: ${_getTotalPendingCalories()} kcal (${_pendingMacroItems.length} ${_pendingMacroItems.length == 1 ? 'item' : 'items'})'
                                      : 'Pending: ${_pendingMacroItems.length} ${_pendingMacroItems.length == 1 ? 'item' : 'items'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: kAccentLight,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                            if (_pendingMacroItems.isNotEmpty) ...[
                              SizedBox(height: getPercentageHeight(1, context)),
                              ..._pendingMacroItems
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: getPercentageHeight(0.3, context),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        showCaloriesAndGoal
                                            ? '${index + 1}. ${item.name} (${item.calories} kcal)'
                                            : '${index + 1}. ${item.name}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: kAccentLight.withValues(
                                                  alpha: 0.8),
                                            ),
                                      ),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(1, context)),
                                      Icon(
                                        Icons.check_circle,
                                        color: kAccentLight,
                                        size: getIconScale(3, context),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  // Search box
                  Row(
                    children: [
                      SizedBox(width: getPercentageWidth(2, context)),
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () => _handleCameraAction(),
                            icon: Icon(
                              Icons.camera_alt,
                              color: canUseAI() ? null : Colors.grey,
                              size: getIconScale(7, context),
                            ),
                          ),
                          if (!canUseAI())
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: kAccentLight.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: getIconScale(3, context),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Flexible(
                        child: Padding(
                          padding:
                              EdgeInsets.all(getPercentageWidth(4, context)),
                          child: SearchButton2(
                            controller: _searchController,
                            onChanged: (query) {
                              _onSearchChanged(query);
                            },
                            kText: 'Check pantry or search ingredients',
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(
                            right: getPercentageWidth(2, context)),
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateRecipeScreen(
                                    screenType: 'addManual' + foodType,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.add,
                                size: getIconScale(7, context))),
                      ),
                    ],
                  ),
                  // Results
                  Expanded(
                    child: Obx(() {
                      if (_searchResults.isEmpty && !_isSearching.value) {
                        return Center(
                          child: Text(
                            "I can't find that in the pantry",
                            style: TextStyle(
                              color: getThemeProvider(context).isDarkMode
                                  ? kWhite
                                  : kBlack,
                            ),
                          ),
                        );
                      }

                      return Stack(
                        children: [
                          ListView.builder(
                            controller: scrollController,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              if (index >= _searchResults.length) {
                                // avoid out of range error
                                return const SizedBox.shrink();
                              }
                              final result = _searchResults[index];
                              return ListTile(
                                leading: result is Meal &&
                                        result.mediaPaths.isNotEmpty &&
                                        result.mediaPaths.first
                                            .startsWith('http')
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: buildOptimizedNetworkImage(
                                          imageUrl: result.mediaPaths.first,
                                          width:
                                              getPercentageWidth(10, context),
                                          height:
                                              getPercentageWidth(10, context),
                                          fit: BoxFit.cover,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          errorWidget: Image.asset(
                                            getAssetImageForItem(
                                                result.category ?? 'default'),
                                            width:
                                                getPercentageWidth(10, context),
                                            height:
                                                getPercentageWidth(10, context),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )
                                    : null,
                                title: Text(
                                  result is Meal
                                      ? result.title
                                      : result is MacroData
                                          ? capitalizeFirstLetter(result.title)
                                          : result is IngredientData
                                              ? capitalizeFirstLetter(
                                                  result.title)
                                              : 'Unknown Item',
                                  style: TextStyle(
                                    color: getThemeProvider(context).isDarkMode
                                        ? kWhite
                                        : kBlack,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context); // Close the modal
                                  _showDetailPopup(
                                      result, userService.userId, mealType);
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults.clear();
                                  });
                                },
                              );
                            },
                          ),
                          if (_isSearching.value && _searchResults.isNotEmpty)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 16,
                              child: Center(
                                child: SizedBox(
                                  width: getPercentageWidth(6, context),
                                  height: getPercentageWidth(6, context),
                                  child: const CircularProgressIndicator(
                                    color: kAccent,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleCameraAction() async {
    await handleCameraAction(
      context: context,
      date: currentDate,
      isDarkMode: getThemeProvider(context).isDarkMode,
      mealType: foodType,
      onSuccess: () async {
        // Refresh the data
        await _loadData();
      },
      onError: () {
        // Error handling is already done in the consolidated function
      },
    );
  }

  // Helper method to fetch current macros from daily summary
  Future<Map<String, double>> _getCurrentMacros() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);
      final summaryDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summary')
          .doc(dateStr)
          .get();

      if (!summaryDoc.exists) {
        return {'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
      }

      final data = summaryDoc.data() ?? {};
      final nutritionalInfo = data['nutritionalInfo'] as Map<String, dynamic>?;

      // Check direct fields first (standard path from cloud function), then fall back to nutritionalInfo
      final proteinRaw = data['protein'] ?? nutritionalInfo?['protein'];
      final protein = proteinRaw is int
          ? proteinRaw.toDouble()
          : proteinRaw is double
              ? proteinRaw
              : (proteinRaw is String
                  ? double.tryParse(proteinRaw) ?? 0.0
                  : 0.0);

      final carbsRaw = data['carbs'] ?? nutritionalInfo?['carbs'];
      final carbs = carbsRaw is int
          ? carbsRaw.toDouble()
          : carbsRaw is double
              ? carbsRaw
              : (carbsRaw is String ? double.tryParse(carbsRaw) ?? 0.0 : 0.0);

      final fatRaw = data['fat'] ?? nutritionalInfo?['fat'];
      final fat = fatRaw is int
          ? fatRaw.toDouble()
          : fatRaw is double
              ? fatRaw
              : (fatRaw is String ? double.tryParse(fatRaw) ?? 0.0 : 0.0);

      return {'protein': protein, 'carbs': carbs, 'fat': fat};
    } catch (e) {
      debugPrint('Error fetching current macros: $e');
      return {'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
    }
  }

  Future<void> _showFillRemainingMacrosDialog(BuildContext context) async {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    // Show loading dialog while fetching macros
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(getPercentageWidth(5, context)),
          decoration: BoxDecoration(
            color: isDarkMode ? kDarkGrey : kWhite,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: kAccent),
              SizedBox(height: getPercentageHeight(2, context)),
              Text(
                'Loading macros...',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                  fontSize: getTextScale(3.5, context),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Get current totals and goals
    final settings = userService.currentUser.value?.settings ?? {};
    final targetCalories =
        double.tryParse(settings['foodGoal']?.toString() ?? '0') ?? 0.0;
    final targetProtein =
        double.tryParse(settings['proteinGoal']?.toString() ?? '0') ?? 0.0;
    final targetCarbs =
        double.tryParse(settings['carbsGoal']?.toString() ?? '0') ?? 0.0;
    final targetFat =
        double.tryParse(settings['fatGoal']?.toString() ?? '0') ?? 0.0;

    final currentCalories = dailyDataController.totalCalories.value;

    // Fetch current macros from daily summary
    final currentMacros = await _getCurrentMacros();
    final currentProtein = currentMacros['protein'] ?? 0.0;
    final currentCarbs = currentMacros['carbs'] ?? 0.0;
    final currentFat = currentMacros['fat'] ?? 0.0;

    // Close loading dialog
    if (mounted && context.mounted) {
      Navigator.pop(context);
    }

    // Calculate remaining macros
    final remainingCalories = (targetCalories - currentCalories).round();
    final remainingProtein = targetProtein - currentProtein;
    final remainingCarbs = targetCarbs - currentCarbs;
    final remainingFat = targetFat - currentFat;

    final caloriesController = TextEditingController(
      text: remainingCalories > 0 ? remainingCalories.toString() : '0',
    );
    final proteinController = TextEditingController(
      text: remainingProtein > 0 ? remainingProtein.toStringAsFixed(1) : '0',
    );
    final carbsController = TextEditingController(
      text: remainingCarbs > 0 ? remainingCarbs.toStringAsFixed(1) : '0',
    );
    final fatController = TextEditingController(
      text: remainingFat > 0 ? remainingFat.toStringAsFixed(1) : '0',
    );

    bool isLoading = false;
    List<Map<String, dynamic>> suggestions = [];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            'Complete the Spec',
            style: TextStyle(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your remaining macros, Chef:',
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kBlack,
                      fontSize: getTextScale(3.5, context),
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),

                  // Calories input
                  TextField(
                    controller: caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Remaining Calories (kcal)',
                      labelStyle: TextStyle(
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: isDarkMode ? kWhite : kBlack),
                  ),
                  SizedBox(height: getPercentageHeight(1.5, context)),

                  // Protein input
                  TextField(
                    controller: proteinController,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Remaining Protein (g)',
                      labelStyle: TextStyle(
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: isDarkMode ? kWhite : kBlack),
                  ),
                  SizedBox(height: getPercentageHeight(1.5, context)),

                  // Carbs input
                  TextField(
                    controller: carbsController,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Remaining Carbs (g)',
                      labelStyle: TextStyle(
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: isDarkMode ? kWhite : kBlack),
                  ),
                  SizedBox(height: getPercentageHeight(1.5, context)),

                  // Fat input
                  TextField(
                    controller: fatController,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Remaining Fat (g)',
                      labelStyle: TextStyle(
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: isDarkMode ? kWhite : kBlack),
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),

                  // Search button
                  if (suggestions.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                setDialogState(() {
                                  isLoading = true;
                                  suggestions = [];
                                });

                                try {
                                  final remainingCal =
                                      int.tryParse(caloriesController.text) ??
                                          0;
                                  final remainingProt =
                                      double.tryParse(proteinController.text) ??
                                          0.0;
                                  final remainingCarb =
                                      double.tryParse(carbsController.text) ??
                                          0.0;
                                  final remainingFatVal =
                                      double.tryParse(fatController.text) ??
                                          0.0;

                                  final results =
                                      await ReversePantrySearchService.instance
                                          .searchByRemainingMacros(
                                    remainingCalories: remainingCal,
                                    remainingProtein: remainingProt,
                                    remainingCarbs: remainingCarb,
                                    remainingFat: remainingFatVal,
                                  );

                                  setDialogState(() {
                                    isLoading = false;
                                    suggestions = results;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    isLoading = false;
                                  });
                                  if (mounted) {
                                    showTastySnackbar(
                                      'Error',
                                      'Failed to search: $e',
                                      context,
                                      backgroundColor: kRed,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          padding: EdgeInsets.symmetric(
                            vertical: getPercentageHeight(1.5, context),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                height: getIconScale(4, context),
                                width: getIconScale(4, context),
                                child: CircularProgressIndicator(
                                  color: kWhite,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Search',
                                style: TextStyle(
                                  color: kWhite,
                                  fontSize: getTextScale(4, context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                  // Suggestions list or no results message
                  if (!isLoading) ...[
                    if (suggestions.isNotEmpty) ...[
                      SizedBox(height: getPercentageHeight(2, context)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Suggestions from previous service:',
                            style: TextStyle(
                              color: isDarkMode ? kWhite : kBlack,
                              fontWeight: FontWeight.w600,
                              fontSize: getTextScale(3.5, context),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final remainingCal =
                                  int.tryParse(caloriesController.text) ?? 0;
                              if (remainingCal > 0) {
                                Navigator.pop(dialogContext);
                                await _searchMealsByCalories(remainingCal);
                              }
                            },
                            icon: Icon(Icons.search,
                                color: kAccent, size: getIconScale(4, context)),
                            label: Text(
                              'Search More',
                              style: TextStyle(
                                color: kAccent,
                                fontSize: getTextScale(3, context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: getPercentageHeight(1, context)),
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.3,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final item = suggestions[index];
                            return ListTile(
                              title: Text(
                                item['name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: getTextScale(3, context),
                                  color: isDarkMode ? kWhite : kBlack,
                                ),
                              ),
                              subtitle: Text(
                                '${item['calories']} kcal • P: ${item['protein']?.toStringAsFixed(1) ?? '0'}g • C: ${item['carbs']?.toStringAsFixed(1) ?? '0'}g • F: ${item['fat']?.toStringAsFixed(1) ?? '0'}g',
                                style: TextStyle(
                                  fontSize: getTextScale(2.5, context),
                                  color: isDarkMode ? kLightGrey : kDarkGrey,
                                ),
                              ),
                              trailing: Icon(
                                Icons.add_circle_outline,
                                color: kAccent,
                              ),
                              onTap: () {
                                Navigator.pop(dialogContext);
                                _addSuggestedMeal(item);
                              },
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      // No suggestions found message
                      SizedBox(height: getPercentageHeight(2, context)),
                      Container(
                        padding: EdgeInsets.all(getPercentageWidth(4, context)),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Nothing in the pantry from previous service",
                              style: TextStyle(
                                color: isDarkMode ? kWhite : kBlack,
                                fontWeight: FontWeight.w600,
                                fontSize: getTextScale(3.5, context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final remainingCal =
                                      int.tryParse(caloriesController.text) ??
                                          0;
                                  if (remainingCal > 0) {
                                    Navigator.pop(dialogContext);
                                    await _searchMealsByCalories(remainingCal);
                                  } else {
                                    if (mounted) {
                                      showTastySnackbar(
                                        'Try Again',
                                        'Please enter remaining calories first',
                                        context,
                                        backgroundColor: kRed,
                                      );
                                    }
                                  }
                                },
                                icon: Icon(Icons.search, color: kWhite),
                                label: Text(
                                  'Search Plates by Calories',
                                  style: TextStyle(
                                    color: kWhite,
                                    fontSize: getTextScale(3.5, context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kAccent,
                                  padding: EdgeInsets.symmetric(
                                    vertical: getPercentageHeight(1.5, context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Close',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Search meals from database filtered by calories (10% threshold)
  Future<void> _searchMealsByCalories(int targetCalories) async {
    try {
      // Calculate 10% threshold (allow 10% below and 10% above)
      final minCalories = (targetCalories * 0.9).round();
      final maxCalories = (targetCalories * 1.1).round();

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(getPercentageWidth(5, context)),
            decoration: BoxDecoration(
              color: getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: kAccent),
                SizedBox(height: getPercentageHeight(2, context)),
                Text(
                  'Searching pantry...',
                  style: TextStyle(
                    fontSize: getTextScale(3.5, context),
                    color:
                        getThemeProvider(context).isDarkMode ? kWhite : kBlack,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Query meals collection
      // Note: Since calories might be stored as String or num in Firestore,
      // we can't use range queries reliably. Instead, we fetch a larger set and filter in memory.
      final mealsSnapshot = await firestore
          .collection('meals')
          .limit(200) // Fetch more meals to filter from
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Meal search timed out');
        },
      );

      // Filter in memory to ensure we're within the range
      final filteredDocs = mealsSnapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;

            // Handle calories as String or num
            final caloriesValue = data['calories'];
            int calories = 0;
            if (caloriesValue is num) {
              calories = caloriesValue.toInt();
            } else if (caloriesValue is String) {
              calories = int.tryParse(caloriesValue) ?? 0;
            }

            return calories >= minCalories && calories <= maxCalories;
          })
          .take(20)
          .toList(); // Limit to 20 results

      // Close loading
      if (mounted) Navigator.pop(context);

      if (filteredDocs.isEmpty) {
        if (mounted) {
          showTastySnackbar(
            'Nothing in the Pantry',
            'No plates found within ${minCalories}-${maxCalories} calories, Chef',
            context,
            backgroundColor: Colors.orange,
          );
        }
        return;
      }

      // Convert to list of maps for display
      final meals = filteredDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) {
          return {
            'name': 'Unknown',
            'calories': 0,
            'protein': 0.0,
            'carbs': 0.0,
            'fat': 0.0,
            'mealId': doc.id,
            'type': 'meal',
            'source': 'database',
          };
        }

        // Safely get macros
        final macrosRaw = data['macros'] ?? data['nutritionalInfo'];
        Map<String, dynamic> macros = {};
        if (macrosRaw is Map) {
          macros = Map<String, dynamic>.from(macrosRaw);
        }

        // Handle calories as String or num
        final caloriesValue = data['calories'];
        int calories = 0;
        if (caloriesValue is num) {
          calories = caloriesValue.toInt();
        } else if (caloriesValue is String) {
          calories = int.tryParse(caloriesValue) ?? 0;
        }

        // Safely parse macros (handle String or num)
        double parseMacro(dynamic value) {
          if (value is num) {
            return value.toDouble();
          } else if (value is String) {
            return double.tryParse(value) ?? 0.0;
          }
          return 0.0;
        }

        return {
          'name': data['title'] as String? ?? 'Unknown',
          'calories': calories,
          'protein': parseMacro(macros['protein']),
          'carbs': parseMacro(macros['carbs']),
          'fat': parseMacro(macros['fat']),
          'mealId': doc.id,
          'type': 'meal',
          'source': 'database',
        };
      }).toList();

      // Show meal selection dialog
      if (mounted) {
        _showMealSearchResultsDialog(meals, targetCalories);
      }
    } catch (e) {
      // Close loading if still open
      if (mounted) Navigator.pop(context);
      debugPrint('Error searching meals by calories: $e');
      if (mounted) {
        _handleError("Chef, I can't find that in the pantry. Please try again.",
            details: e.toString());
      }
    }
  }

  /// Show dialog with meal search results
  void _showMealSearchResultsDialog(
    List<Map<String, dynamic>> meals,
    int targetCalories,
  ) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final minCalories = (targetCalories * 0.9).round();
    final maxCalories = (targetCalories * 1.1).round();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plates (${minCalories}-${maxCalories} kcal)',
              style: TextStyle(
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
            Text(
              'Found ${meals.length} ${meals.length == 1 ? 'plate' : 'plates'}',
              style: TextStyle(
                color: isDarkMode ? kLightGrey : kDarkGrey,
                fontSize: getTextScale(3, context),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: meals.length,
            itemBuilder: (context, index) {
              final item = meals[index];
              return ListTile(
                title: Text(
                  item['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: getTextScale(3, context),
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
                subtitle: Text(
                  '${item['calories']} kcal • P: ${item['protein']?.toStringAsFixed(1) ?? '0'}g • C: ${item['carbs']?.toStringAsFixed(1) ?? '0'}g • F: ${item['fat']?.toStringAsFixed(1) ?? '0'}g',
                  style: TextStyle(
                    fontSize: getTextScale(2.5, context),
                    color: isDarkMode ? kLightGrey : kDarkGrey,
                  ),
                ),
                trailing: Icon(
                  Icons.add_circle_outline,
                  color: kAccent,
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _addSuggestedMeal(item);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDarkMode ? kWhite : kAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSuggestedMeal(Map<String, dynamic> item) async {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    // Show dialog to select meal type
    final mealTypeResult = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          String? selectedMealType;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            title: Text(
              'Select Service',
              style: TextStyle(
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Log "${item['name'] ?? 'Unknown'}" to:',
                  style: TextStyle(
                    color: isDarkMode ? kWhite : kBlack,
                    fontSize: getTextScale(3.5, context),
                  ),
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                ...['Breakfast', 'Lunch', 'Dinner', 'Fruits', 'Snacks']
                    .map((mealType) => RadioListTile<String>(
                          title: Text(
                            mealType,
                            style: TextStyle(
                              color: isDarkMode ? kWhite : kBlack,
                            ),
                          ),
                          value: mealType,
                          groupValue: selectedMealType,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedMealType = value;
                            });
                            Navigator.pop(dialogContext, value);
                          },
                          activeColor: kAccent,
                        ))
                    .toList(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDarkMode ? kWhite : kAccent,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (mealTypeResult == null || mealTypeResult.isEmpty) {
      return; // User cancelled
    }

    try {
      // Create UserMeal from item data
      final mealId = item['mealId'] as String? ??
          item['ingredientId'] as String? ??
          item['name'] as String? ??
          'suggested_${DateTime.now().millisecondsSinceEpoch}';

      final calories = item['calories'] as int? ?? 0;
      final protein = (item['protein'] as num?)?.toDouble() ?? 0.0;
      final carbs = (item['carbs'] as num?)?.toDouble() ?? 0.0;
      final fat = (item['fat'] as num?)?.toDouble() ?? 0.0;

      final userMeal = UserMeal(
        name: item['name'] as String? ?? 'Unknown',
        quantity: '1',
        servings: 'serving',
        calories: calories,
        mealId: mealId,
        macros: {
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
        },
      );

      // Add meal to selected meal type with retry logic
      await _retryOperation(() => dailyDataController.addUserMeal(
            userId,
            mealTypeResult,
            userMeal,
            currentDate,
          ));

      // Refresh data (no setState needed - reactive updates handle it)
      await _refreshMealData(mealTypeResult);

      // Check if points were already awarded for this meal type today
      // BadgeService.checkMealLogged uses reason pattern: "[mealType] logged!"
      final reason = "$mealTypeResult logged!";
      final alreadyAwarded =
          await badgeService.hasBeenAwardedToday(userService.userId!, reason);

      if (mounted) {
        if (!alreadyAwarded) {
          // Points will be awarded by BadgeService.checkMealLogged
          showTastySnackbar(
            'Success',
            'Logged ${item['name']} to $mealTypeResult, Chef!',
            context,
          );
        } else {
          // Already awarded today, just show update confirmation
          showTastySnackbar(
            'Success',
            'Logged ${item['name']} to $mealTypeResult, Chef!',
            context,
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding suggested meal: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to add plate, Chef: $e',
          context,
          backgroundColor: kRed,
        );
      }
    }
  }

  /// Show dialog to copy meals from another date
  Future<void> _showCopyFromDateDialog(BuildContext context) async {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final currentDate = widget.date ?? DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    // First, fetch recent dates with meals (last 30 days)
    try {
      final recentDates = <Map<String, dynamic>>[];

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(getPercentageWidth(5, context)),
            decoration: BoxDecoration(
              color: isDarkMode ? kDarkGrey : kWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: kAccent),
                SizedBox(height: getPercentageHeight(2, context)),
                Text(
                  'Loading recent plates...',
                  style: TextStyle(
                    color: isDarkMode ? kWhite : kBlack,
                    fontSize: getTextScale(4, context),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Fetch last 30 days in parallel for better performance
      final dateQueries = <Future<Map<String, dynamic>?>>[];

      for (int i = 1; i <= 30; i++) {
        final checkDate = currentDate.subtract(Duration(days: i));
        final dateStr = dateFormat.format(checkDate);

        dateQueries.add(
          firestore
              .collection('userMeals')
              .doc(userId)
              .collection('meals')
              .doc(dateStr)
              .get()
              .then((mealsDoc) {
            if (mealsDoc.exists) {
              final mealsData =
                  mealsDoc.data()?['meals'] as Map<String, dynamic>? ?? {};
              int totalMeals = 0;
              for (var mealType in ['Breakfast', 'Lunch', 'Dinner', 'Fruits']) {
                final mealList = mealsData[mealType] as List<dynamic>? ?? [];
                totalMeals += mealList.length;
              }

              if (totalMeals > 0) {
                return {
                  'date': checkDate,
                  'dateStr': dateStr,
                  'mealCount': totalMeals,
                };
              }
            }
            return null;
          }).catchError((e) {
            debugPrint('Error checking date $dateStr: $e');
            return null;
          }),
        );
      }

      // Wait for all queries to complete in parallel
      final results = await Future.wait(dateQueries);

      // Filter out null results and add to recentDates
      for (var result in results) {
        if (result != null) {
          recentDates.add(result);
        }
      }

      // Sort by date (most recent first)
      recentDates.sort((a, b) {
        final dateA = a['date'] as DateTime;
        final dateB = b['date'] as DateTime;
        return dateB.compareTo(dateA);
      });

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (recentDates.isEmpty) {
        if (mounted) {
          showTastySnackbar(
            'No Previous Plates',
            'No plates found in the last 30 days, Chef',
            context,
            backgroundColor: Colors.orange,
          );
        }
        return;
      }

      // Show date selection dialog with recent dates
      if (mounted) {
        _showRecentDatesDialog(context, recentDates, currentDate);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);
      debugPrint('Error fetching recent dates: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to load recent meals: $e',
          context,
          backgroundColor: kRed,
        );
      }
    }
  }

  /// Show dialog with recent dates that have meals
  void _showRecentDatesDialog(
    BuildContext context,
    List<Map<String, dynamic>> recentDates,
    DateTime currentDate,
  ) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Text(
          'Copy Plates from Previous Service',
          style: TextStyle(
            color: isDarkMode ? kWhite : kBlack,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a date to view plates:',
                style: TextStyle(
                  color: isDarkMode ? kLightGrey : kDarkGrey,
                  fontSize: getTextScale(3, context),
                ),
              ),
              SizedBox(height: getPercentageHeight(2, context)),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: recentDates.length,
                  itemBuilder: (context, index) {
                    final dateInfo = recentDates[index];
                    final date = dateInfo['date'] as DateTime;
                    final mealCount = dateInfo['mealCount'] as int;

                    return ListTile(
                      leading: Icon(
                        Icons.calendar_today,
                        color: kAccent,
                        size: getIconScale(5, context),
                      ),
                      title: Text(
                        DateFormat('EEEE, MMM dd, yyyy').format(date),
                        style: TextStyle(
                          color: isDarkMode ? kWhite : kBlack,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$mealCount ${mealCount == 1 ? 'plate' : 'plates'}',
                        style: TextStyle(
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: kAccent,
                        size: getIconScale(4, context),
                      ),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        _loadAndShowMealsForDate(context, date);
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              Divider(color: isDarkMode ? kLightGrey : kDarkGrey),
              SizedBox(height: getPercentageHeight(1, context)),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  // Show date picker for older dates
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: currentDate.subtract(const Duration(days: 1)),
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: currentDate.subtract(const Duration(days: 1)),
                    helpText: 'Select date to copy plates from',
                  );
                  if (selectedDate != null) {
                    _loadAndShowMealsForDate(context, selectedDate);
                  }
                },
                icon: Icon(Icons.calendar_month, color: kAccent),
                label: Text(
                  'Choose Another Date',
                  style: TextStyle(color: kAccent),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? kWhite : kAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Load meals for a specific date and show selection dialog
  Future<void> _loadAndShowMealsForDate(
    BuildContext context,
    DateTime selectedDate,
  ) async {
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStr = dateFormat.format(selectedDate);

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(getPercentageWidth(5, context)),
            decoration: BoxDecoration(
              color: getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: kAccent),
                SizedBox(height: getPercentageHeight(2, context)),
                Text(
                  'Loading plates...',
                  style: TextStyle(
                    color:
                        getThemeProvider(context).isDarkMode ? kWhite : kBlack,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final mealsDoc = await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .doc(dateStr)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Loading meals timed out');
        },
      );

      // Close loading
      if (mounted) Navigator.pop(context);

      if (!mealsDoc.exists) {
        if (mounted) {
          showTastySnackbar(
            'No Plates Found',
            'No plates found for the selected date, Chef',
            context,
            backgroundColor: Colors.orange,
          );
        }
        return;
      }

      final mealsData =
          mealsDoc.data()?['meals'] as Map<String, dynamic>? ?? {};
      final allMeals = <String, List<UserMeal>>{};

      // Parse meals from all meal types
      for (var mealType in ['Breakfast', 'Lunch', 'Dinner', 'Fruits']) {
        final mealList = mealsData[mealType] as List<dynamic>? ?? [];
        allMeals[mealType] = mealList
            .map((meal) => UserMeal.fromMap(meal as Map<String, dynamic>))
            .toList();
      }

      // Show meal selection dialog
      if (mounted) {
        _showMealSelectionDialog(context, allMeals, selectedDate);
      }
    } catch (e) {
      // Close loading if still open
      if (mounted) Navigator.pop(context);
      debugPrint('Error fetching meals from date: $e');
      if (mounted) {
        _handleError('Failed to load plates, Chef. Please try again.',
            details: e.toString());
      }
    }
  }

  /// Show dialog to select meals to copy
  void _showMealSelectionDialog(
    BuildContext context,
    Map<String, List<UserMeal>> allMeals,
    DateTime sourceDate,
  ) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final selectedMeals = <UserMeal>[];
    final selectedMealTypes = <String, List<UserMeal>>{};

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            'Copy Plates from ${DateFormat('MMM dd, yyyy').format(sourceDate)}',
            style: TextStyle(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          content: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select plates to copy:',
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kBlack,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),
                  ...allMeals.entries.map((entry) {
                    if (entry.value.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: kAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: getTextScale(4, context),
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                        ...entry.value.map((meal) {
                          final isSelected = selectedMeals.contains(meal);
                          return CheckboxListTile(
                            title: Text(
                              meal.name,
                              style: TextStyle(
                                color: isDarkMode ? kWhite : kBlack,
                              ),
                            ),
                            subtitle: showCaloriesAndGoal
                                ? Text(
                                    '${meal.calories} kcal',
                                    style: TextStyle(
                                      color:
                                          isDarkMode ? kLightGrey : kDarkGrey,
                                    ),
                                  )
                                : null,
                            value: isSelected,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedMeals.add(meal);
                                  selectedMealTypes
                                      .putIfAbsent(entry.key, () => [])
                                      .add(meal);
                                } else {
                                  selectedMeals.remove(meal);
                                  selectedMealTypes[entry.key]?.remove(meal);
                                }
                              });
                            },
                            activeColor: kAccent,
                          );
                        }),
                        SizedBox(height: getPercentageHeight(1, context)),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kAccent,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedMeals.isEmpty
                  ? null
                  : () async {
                      await _copyMealsToCurrentDate(
                          selectedMeals, selectedMealTypes);
                      Navigator.pop(dialogContext);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
              ),
              child: Text(
                'Copy ${selectedMeals.length} ${selectedMeals.length == 1 ? 'Plate' : 'Plates'}',
                style: const TextStyle(color: kWhite),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Copy selected meals to current date as new instances
  Future<void> _copyMealsToCurrentDate(
    List<UserMeal> mealsToCopy,
    Map<String, List<UserMeal>> mealTypes,
  ) async {
    int successCount = 0;
    int failCount = 0;
    String? lastError;

    try {
      final currentDate = widget.date ?? DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

      for (var entry in mealTypes.entries) {
        final mealType = entry.key;
        final meals = entry.value;

        for (var mealIndex = 0; mealIndex < meals.length; mealIndex++) {
          final meal = meals[mealIndex];
          try {
            // Create new instance with originalMealId and NEW instanceId
            // Use timestamp + index + random component to ensure uniqueness
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final random = (DateTime.now().microsecondsSinceEpoch % 10000);
            final newInstanceId = '${timestamp}_${mealIndex}_$random';

            final newInstance = meal.copyWith({
              'originalMealId': meal.mealId,
              'instanceId': newInstanceId, // Generate new instanceId
              'isInstance': true,
              'loggedAt': DateTime.now(),
            });

            await _retryOperation(() => dailyDataController.addUserMeal(
                  userId,
                  mealType,
                  newInstance,
                  currentDate,
                ));

            successCount++;
            debugPrint(
                'Successfully copied meal "${meal.name}" (${newInstance.instanceId}) to $dateStr');
          } catch (e) {
            failCount++;
            lastError = e.toString();
            debugPrint('Error copying meal "${meal.name}": $e');
            // Continue with other meals even if one fails
          }
        }
      }

      // Refresh data
      await _loadData();

      // Show appropriate message based on results
      if (mounted) {
        if (failCount == 0) {
          // All meals copied successfully
          showTastySnackbar(
            'Success',
            'Copied ${successCount} ${successCount == 1 ? 'plate' : 'plates'} to today, Chef',
            context,
          );
        } else if (successCount > 0) {
          // Some succeeded, some failed
          showTastySnackbar(
            'Partial Success',
            'Copied $successCount ${successCount == 1 ? 'plate' : 'plates'}, ${failCount} ${failCount == 1 ? 'failed' : 'failed'}, Chef',
            context,
            backgroundColor: Colors.orange,
          );
        } else {
          // All failed
          showTastySnackbar(
            'Error',
            'Failed to copy plates${lastError != null ? ': ${lastError.substring(0, lastError.length > 50 ? 50 : lastError.length)}' : ''}, Chef',
            context,
            backgroundColor: kRed,
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _copyMealsToCurrentDate: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to copy meals: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}',
          context,
          backgroundColor: kRed,
        );
      }
    }
  }

  void _showMealDetailModal(
    BuildContext context,
    String mealType,
    List<UserMeal> meals,
    int currentCalories,
    String recommendedCalories,
    IconData icon,
  ) {
    final currentDate = widget.date ?? DateTime.now();
    showDialog(
      context: context,
      builder: (context) => MealDetailWidget(
        mealType: mealType,
        meals: meals,
        currentCalories: currentCalories,
        recommendedCalories: recommendedCalories,
        icon: icon,
        showCalories: showCaloriesAndGoal,
        currentDate: currentDate,
        onAddMeal: () {
          setState(() {
            foodType = mealType;
          });
          _showSearchResults(context, mealType);
        },
      ),
    );
  }

  void _showDetailPopup(dynamic result, String? userId, String mealType) {
    int selectedNumber = 0;
    int selectedUnit = 0;

    if (result is Meal) {
    } else if (result is MacroData) {
    } else if (result is IngredientData) {}

    String itemName = result is Meal
        ? result.title
        : result is MacroData
            ? result.title
            : result is IngredientData
                ? result.title
                : 'Unknown Item';

    // Helper function to calculate calories and macros based on selected number and unit
    Map<String, dynamic> calculateAdjustedNutrition() {
      if (result is Meal) {
        // For meals, use the macros from the meal object
        Map<String, double> mealMacros = {};
        if (result.macros.isNotEmpty) {
          mealMacros = result.macros.map(
              (key, value) => MapEntry(key, double.tryParse(value) ?? 0.0));
        }
        return {
          'calories': result.calories,
          'macros': mealMacros,
        };
      }

      // Base nutrition (per serving)
      int baseCalories = result is MacroData
          ? result.calories
          : (result as IngredientData).getCalories().toInt();

      // Get macros from the data
      Map<String, double> baseMacros = {};
      if (result is MacroData) {
        baseMacros = result.macros.map((key, value) =>
            MapEntry(key, (value is num) ? value.toDouble() : 0.0));
      } else if (result is IngredientData) {
        baseMacros = {
          'protein': result.getProtein(),
          'fat': result.getFat(),
          'carbs': result.getCarbs(),
        };
      }

      // Get the base unit from the data
      String baseUnit = '';
      if (result is MacroData) {
        // Assuming MacroData has a standard serving size, default to 'serving'
        baseUnit = 'serving';
      } else if (result is IngredientData) {
        baseUnit = result.servingSize.toLowerCase();
      }

      // Selected unit from picker
      String selectedUnitStr = unitOptions[selectedUnit].toLowerCase();

      // Convert everything to grams for calculation
      double baseAmount = 1.0; // Default to 1 unit
      double selectedAmount = selectedNumber.toDouble();

      // Conversion factors to grams
      const Map<String, double> toGrams = {
        'g': 1.0,
        'gram': 1.0,
        'grams': 1.0,
        'kg': 1000.0,
        'kilogram': 1000.0,
        'kilograms': 1000.0,
        'oz': 28.35,
        'ounce': 28.35,
        'ounces': 28.35,
        'lb': 453.59,
        'pound': 453.59,
        'pounds': 453.59,
        'cup': 128.0,
        'cups': 128.0,
        'tbsp': 15.0,
        'tablespoon': 15.0,
        'tablespoons': 15.0,
        'tsp': 5.0,
        'teaspoon': 5.0,
        'teaspoons': 5.0,
        'ml': 1.0,
        'milliliter': 1.0,
        'milliliters': 1.0,
        'l': 1000.0,
        'liter': 1000.0,
        'liters': 1000.0,
        'serving': 1.0,
        'servings': 1.0,
        'piece': 1.0,
        'pieces': 1.0,
      };

      // Extract numeric value and unit from base serving size
      if (result is IngredientData) {
        RegExp regex = RegExp(r'(\d*\.?\d+)\s*([a-zA-Z]+)');
        Match? match = regex.firstMatch(baseUnit);
        if (match != null) {
          baseAmount = double.tryParse(match.group(1) ?? '1') ?? 1.0;
          baseUnit = match.group(2)?.toLowerCase() ?? 'serving';
        }
      }

      // Convert both amounts to grams
      double baseInGrams = baseAmount * (toGrams[baseUnit] ?? 1.0);
      double selectedInGrams =
          selectedAmount * (toGrams[selectedUnitStr] ?? 1.0);

      // Calculate ratio and adjust nutrition
      double ratio = selectedInGrams / baseInGrams;
      int adjustedCalories = (baseCalories * ratio).round();

      // Adjust macros by the same ratio
      Map<String, double> adjustedMacros = {};
      baseMacros.forEach((key, value) {
        adjustedMacros[key] = value * ratio;
      });

      return {
        'calories': adjustedCalories,
        'macros': adjustedMacros,
      };
    }

    // Helper function to create UserMeal from any type
    // Supports creating instances when copying from past dates
    UserMeal createUserMeal({
      String? originalMealId,
      bool isInstance = false,
    }) {
      // Calculate adjusted nutrition (calories and macros)
      final nutrition = calculateAdjustedNutrition();
      final adjustedCalories = nutrition['calories'] as int;
      final adjustedMacros = nutrition['macros'] as Map<String, double>;

      if (result is Meal) {
        final meal = UserMeal(
          name: result.title,
          quantity: '$selectedNumber',
          servings: '${unitOptions[selectedUnit]}',
          calories: result.calories,
          mealId: result.mealId,
          macros: adjustedMacros,
          originalMealId: originalMealId ?? (isInstance ? result.mealId : null),
          loggedAt: isInstance ? DateTime.now() : null,
          isInstance: isInstance,
        );
        return meal;
      } else if (result is MacroData) {
        final mealId = result.id ?? result.title;
        final meal = UserMeal(
          name: result.title,
          quantity: '$selectedNumber',
          servings: '${unitOptions[selectedUnit]}',
          calories: adjustedCalories,
          mealId: mealId,
          macros: adjustedMacros,
          originalMealId: originalMealId ?? (isInstance ? mealId : null),
          loggedAt: isInstance ? DateTime.now() : null,
          isInstance: isInstance,
        );
        return meal;
      } else if (result is IngredientData) {
        final mealId = result.title;
        final meal = UserMeal(
          name: result.title,
          quantity: '$selectedNumber',
          servings: '${unitOptions[selectedUnit]}',
          calories: adjustedCalories,
          mealId: mealId,
          macros: adjustedMacros,
          originalMealId: originalMealId ?? (isInstance ? mealId : null),
          loggedAt: isInstance ? DateTime.now() : null,
          isInstance: isInstance,
        );
        return meal;
      } else {
        throw Exception('Invalid item type: ${result.runtimeType}');
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDarkMode = getThemeProvider(context).isDarkMode;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: isDarkMode ? kDarkGrey : kWhite,
              title: Text(
                'Log to $mealType',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
              content: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.97,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        itemName,
                        style: TextStyle(
                          color: isDarkMode ? kWhite : kBlack,
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(1, context)),

                      // Show current meal type status
                      Container(
                        padding: EdgeInsets.all(getPercentageWidth(2, context)),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? kDarkGrey.withValues(alpha: 0.3)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Current $mealType Status:',
                              style: TextStyle(
                                color: isDarkMode ? kWhite : kBlack,
                                fontWeight: FontWeight.w500,
                                fontSize: getTextScale(3, context),
                              ),
                            ),
                            if (showCaloriesAndGoal) ...[
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                '${_getCurrentCaloriesForMealType(mealType)} kcal from ${dailyDataController.userMealList[mealType]?.length ?? 0} ${dailyDataController.userMealList[mealType]?.length == 1 ? 'plate' : 'plates'}',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: getTextScale(2.5, context),
                                ),
                              ),
                            ] else ...[
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                '${dailyDataController.userMealList[mealType]?.length ?? 0} ${dailyDataController.userMealList[mealType]?.length == 1 ? 'plate' : 'plates'}',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: getTextScale(2.5, context),
                                ),
                              ),
                            ],
                            if (_pendingMacroItems.isNotEmpty &&
                                showCaloriesAndGoal) ...[
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                'Pending: ${_getTotalPendingCalories()} kcal from ${_pendingMacroItems.length} ${_pendingMacroItems.length == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  color: kAccent,
                                  fontWeight: FontWeight.w500,
                                  fontSize: getTextScale(2.5, context),
                                ),
                              ),
                            ] else if (_pendingMacroItems.isNotEmpty) ...[
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                'Pending: ${_pendingMacroItems.length} ${_pendingMacroItems.length == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  color: kAccent,
                                  fontWeight: FontWeight.w500,
                                  fontSize: getTextScale(2.5, context),
                                ),
                              ),
                            ],
                            if (showCaloriesAndGoal) ...[
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(2, context),
                                  vertical: getPercentageHeight(0.5, context),
                                ),
                                decoration: BoxDecoration(
                                  color: kAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: kAccent.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Projected Total: ${_getCurrentCaloriesForMealType(mealType) + _getTotalPendingCalories()} kcal',
                                  style: TextStyle(
                                    color: kAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: getTextScale(2.5, context),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(1, context)),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Flexible(
                              flex: 1,
                              child: Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.28,
                                child: buildPicker(
                                    context,
                                    1000,
                                    selectedNumber,
                                    (index) => setModalState(
                                        () => selectedNumber = index),
                                    isDarkMode ? true : false,
                                    null),
                              ),
                            ),
                            Flexible(
                              flex: 1,
                              child: Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.28,
                                child: buildPicker(
                                  context,
                                  unitOptions.length,
                                  selectedUnit,
                                  (index) =>
                                      setModalState(() => selectedUnit = index),
                                  isDarkMode ? true : false,
                                  unitOptions,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearPendingItems();
                    // Also refresh the data to ensure UI is current
                    _refreshMealData(mealType);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kAccent,
                      fontSize: getTextScale(3.5, context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      final newItem = createUserMeal();
                      _addPendingItem(newItem);
                      Navigator.pop(context);
                      _showSearchResults(context, mealType);
                    } catch (e) {
                      if (mounted) {
                        showTastySnackbar(
                          'Error',
                          'Failed to add item: $e',
                          context,
                          backgroundColor: kRed,
                        );
                      }
                    }
                  },
                  child: Text(
                    'Add Another Item',
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kAccent,
                      fontSize: getTextScale(3.5, context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      // Always add the current item to pending list FIRST
                      final newItem = createUserMeal();
                      _addPendingItem(newItem);

                      // NOW calculate calories with the complete pending list
                      final newCalories = _getTotalPendingCalories();

                      // Get a snapshot of current meal data BEFORE adding new meals to the database
                      final mealSnapshot = _getMealTypeSnapshot(mealType);
                      int existingCalories =
                          mealSnapshot['totalCalories'] as int;

                      // Calculate total calories that will exist after adding
                      final totalCalories = existingCalories + newCalories;

                      // Save all pending items with retry logic
                      // Use userService.userId directly with null coalescing to avoid type inference issues
                      final String currentUserId = userService.userId ?? '';
                      for (var item in _pendingMacroItems) {
                        await _retryOperation(
                            () => dailyDataController.addUserMeal(
                                  currentUserId,
                                  mealType,
                                  item,
                                  currentDate,
                                ));
                      }

                      // Check for calorie overage using the pre-calculated values
                      if (mounted && context.mounted) {
                        // Also refresh the calorie adjustment service to ensure it has current data
                        await _calorieAdjustmentService
                            .loadAdjustmentsFromSharedPrefs();

                        await _calorieAdjustmentService
                            .checkAndShowAdjustmentDialog(
                          context,
                          mealType,
                          totalCalories,
                          notAllowedMealType: widget.notAllowedMealType,
                          selectedUser:
                              null, // Single user mode, use current user
                        );
                      }

                      // Refresh the meal data to ensure UI shows current state
                      await _refreshMealData(mealType);

                      // Points are awarded per meal type (5 points each)
                      // If multiple items added to same meal type, still only 5 points total
                      final pointsEarned = 5;

                      if (mounted && context.mounted) {
                        showTastySnackbar(
                          'Success',
                          'Logged ${_pendingMacroItems.length} ${_pendingMacroItems.length == 1 ? 'item' : 'items'} to $mealType, Chef! +$pointsEarned points',
                          context,
                        );
                      }
                      _clearPendingItems();
                      Navigator.pop(context);
                    } catch (e) {
                      if (mounted && context.mounted) {
                        showTastySnackbar(
                          'Error',
                          'Failed to save items: $e',
                          context,
                          backgroundColor: kRed,
                        );
                      }
                    }
                  },
                  child: Text(
                    'Log All',
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kAccent,
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
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();
    final isToday = DateFormat('dd/MM/yyyy').format(currentDate) ==
        DateFormat('dd/MM/yyyy').format(today);

    // Ensure we have the most current data when building
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _calorieAdjustmentService.loadAdjustmentsFromSharedPrefs();
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: kAccent,
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(14, context),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row with title and InfoIconWidget
            Text(
              widget.title,
              style: textTheme.displaySmall?.copyWith(
                fontSize: getTextScale(8, context),
              ),
            ),
            // Icons row below title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                InfoIconWidget(
                  title: 'The Pass',
                  description: 'Review orders and track your daily service',
                  details: const [
                    {
                      'icon': Icons.restaurant,
                      'title': 'Log Plates',
                      'description': 'Record what you eat throughout the day',
                      'color': kAccent,
                    },
                    {
                      'icon': Icons.analytics,
                      'title': 'Track Nutrition',
                      'description': 'Monitor calories, macros, and nutrients',
                      'color': kAccent,
                    },
                    {
                      'icon': Icons.history,
                      'title': 'View Service History',
                      'description':
                          'See your eating patterns over time and get recommendations',
                      'color': kAccent,
                    },
                    {
                      'icon': Icons.calendar_month,
                      'title': 'Plan Ahead',
                      'description': 'View Today or Next day action items',
                      'color': kAccent,
                    },
                    {
                      'icon': Icons.analytics,
                      'title': 'Analyze Plates',
                      'description':
                          'Analyze your plates with AI and get insights',
                      'color': kAccent,
                    },
                  ],
                  iconColor: isDarkMode ? kWhite : kDarkGrey,
                  tooltip: 'The Pass Information',
                ),
                // Hide Calories Toggle
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        showCaloriesAndGoal = !showCaloriesAndGoal;
                      });
                      saveShowCaloriesPref(showCaloriesAndGoal);

                      // Show snackbar feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            showCaloriesAndGoal
                                ? 'Calories visibility toggled on'
                                : 'Calories visibility toggled off',
                          ),
                          duration: const Duration(seconds: 1),
                          backgroundColor: kAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(1, context),
                      ),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        showCaloriesAndGoal
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: isDarkMode ? kWhite : kDarkGrey,
                        size: getIconScale(5, context),
                      ),
                    ),
                  ),
                ),
                // Copy from Date Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showCopyFromDateDialog(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(1, context),
                      ),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.copy_all,
                        color: isDarkMode ? kWhite : kDarkGrey,
                        size: getIconScale(5, context),
                      ),
                    ),
                  ),
                ),
                // View Yesterday's Summary icon (only show when isToday)
                if (isToday)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _scrollToSection(_yesterdaySummaryKey),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(1, context),
                        ),
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.insights,
                          color: isDarkMode ? kWhite : kDarkGrey,
                          size: getIconScale(5, context),
                        ),
                      ),
                    ),
                  ),
                // Quick Update icon (only show when isToday)
                if (isToday)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _scrollToSection(_quickUpdateKey),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(1, context),
                        ),
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.update,
                          color: isDarkMode ? kWhite : kDarkGrey,
                          size: getIconScale(5, context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(2.5, context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: getPercentageHeight(2, context)),
                // Date navigation - always shown
                _buildDateNavigation(context, isDarkMode, textTheme),
                if (widget.notAllowedMealType != null &&
                    widget.notAllowedMealType != '')
                  Center(
                    child: Text(
                      'Your menu does not include ${capitalizeFirstLetter(widget.notAllowedMealType ?? '')}, Chef',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: getPercentageWidth(3.5, context),
                            fontWeight: FontWeight.w200,
                            color: kAccent,
                          ),
                    ),
                  ),
                SizedBox(height: getPercentageHeight(0.5, context)),

                // Fill Remaining Macros Button - only show if meals have been logged
                if (isToday)
                  Obx(() {
                    // Access userMealList to trigger reactivity
                    dailyDataController.userMealList;
                    // Access targetCalories to trigger reactivity
                    final targetCalories =
                        dailyDataController.targetCalories.value;

                    // Only show if at least one meal has been logged and eaten < targetCalories
                    // (meaning there are still calories/macros remaining to fill)
                    if (!_hasAnyMealsLogged() ||
                        dailyDataController.eatenCalories.value >=
                            targetCalories ||
                        targetCalories <= 0) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context)),
                      child: GestureDetector(
                        onTap: () {
                          _showFillRemainingMacrosDialog(context);
                        },
                        child: Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(3, context)),
                          decoration: BoxDecoration(
                            color: kPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kPurple.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                color: kPurple,
                                size: getIconScale(5, context),
                              ),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Complete the Spec',
                                      style: textTheme.titleMedium?.copyWith(
                                        color: kPurple,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(0.3, context)),
                                    Text(
                                      'Find plates that fit your remaining macros, Chef',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: kPurple.withValues(alpha: 0.7),
                                        fontSize: getTextScale(2.5, context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: kPurple,
                                size: getIconScale(4, context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                SizedBox(height: getPercentageHeight(1, context)),

                // Selected Items List
                Column(
                  children: [
                    Obx(() {
                      // Access observable variables to trigger updates
                      _calorieAdjustmentService.mealAdjustments;
                      dailyDataController.breakfastCalories.value;
                      dailyDataController.userMealList['Breakfast'];

                      return _buildMealCard(
                        context: context,
                        mealType: 'Breakfast',
                        recommendedCalories: _calorieAdjustmentService
                            .getAdjustedRecommendation('Breakfast', 'addFood',
                                notAllowedMealType: widget.notAllowedMealType,
                                selectedUser: null), // Single user mode
                        currentCalories:
                            dailyDataController.breakfastCalories.value,
                        meals:
                            dailyDataController.userMealList['Breakfast'] ?? [],
                        icon: Icons.emoji_food_beverage_outlined,
                        onAdd: () {
                          // Defer setState to avoid calling during build
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                foodType = 'Breakfast';
                              });
                              _showSearchResults(context, 'Breakfast');
                            }
                          });
                        },
                        onTap: () {
                          _showMealDetailModal(
                            context,
                            'Breakfast',
                            dailyDataController.userMealList['Breakfast'] ?? [],
                            dailyDataController.breakfastCalories.value,
                            _calorieAdjustmentService.getAdjustedRecommendation(
                                'Breakfast', 'addFood',
                                notAllowedMealType: widget.notAllowedMealType),
                            Icons.emoji_food_beverage_outlined,
                          );
                        },
                      );
                    }),
                    Obx(() {
                      // Access observable variables to trigger updates
                      _calorieAdjustmentService.mealAdjustments;
                      dailyDataController.lunchCalories.value;
                      dailyDataController.userMealList['Lunch'];

                      return _buildMealCard(
                        context: context,
                        mealType: 'Lunch',
                        recommendedCalories: _calorieAdjustmentService
                            .getAdjustedRecommendation('Lunch', 'addFood',
                                notAllowedMealType: widget.notAllowedMealType,
                                selectedUser: null), // Single user mode
                        currentCalories:
                            dailyDataController.lunchCalories.value,
                        meals: dailyDataController.userMealList['Lunch'] ?? [],
                        icon: Icons.lunch_dining_outlined,
                        onAdd: () {
                          // Defer setState to avoid calling during build
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                foodType = 'Lunch';
                              });
                              _showSearchResults(context, 'Lunch');
                            }
                          });
                        },
                        onTap: () {
                          _showMealDetailModal(
                            context,
                            'Lunch',
                            dailyDataController.userMealList['Lunch'] ?? [],
                            dailyDataController.lunchCalories.value,
                            _calorieAdjustmentService.getAdjustedRecommendation(
                                'Lunch', 'addFood',
                                notAllowedMealType: widget.notAllowedMealType,
                                selectedUser: null), // Single user mode
                            Icons.lunch_dining_outlined,
                          );
                        },
                      );
                    }),
                    Obx(() {
                      // Access observable variables to trigger updates
                      _calorieAdjustmentService.mealAdjustments;
                      dailyDataController.dinnerCalories.value;
                      dailyDataController.userMealList['Dinner'];

                      return _buildMealCard(
                        context: context,
                        mealType: 'Dinner',
                        recommendedCalories: _calorieAdjustmentService
                            .getAdjustedRecommendation('Dinner', 'addFood',
                                notAllowedMealType: widget.notAllowedMealType,
                                selectedUser: null), // Single user mode
                        currentCalories:
                            dailyDataController.dinnerCalories.value,
                        meals: dailyDataController.userMealList['Dinner'] ?? [],
                        icon: Icons.dinner_dining_outlined,
                        onAdd: () {
                          // Defer setState to avoid calling during build
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                foodType = 'Dinner';
                              });
                              _showSearchResults(context, 'Dinner');
                            }
                          });
                        },
                        onTap: () {
                          _showMealDetailModal(
                            context,
                            'Dinner',
                            dailyDataController.userMealList['Dinner'] ?? [],
                            dailyDataController.dinnerCalories.value,
                            _calorieAdjustmentService.getAdjustedRecommendation(
                                'Dinner', 'addFood',
                                notAllowedMealType: widget.notAllowedMealType,
                                selectedUser: null), // Single user mode
                            Icons.dinner_dining_outlined,
                          );
                        },
                      );
                    }),
                    Obx(() {
                      // Access observable variables to trigger updates
                      _calorieAdjustmentService.mealAdjustments;
                      dailyDataController.snacksCalories.value;
                      dailyDataController.userMealList['Fruits'];

                      return _buildMealCard(
                        context: context,
                        mealType: 'Fruits',
                        recommendedCalories: _calorieAdjustmentService
                            .getAdjustedRecommendation('Fruits', 'addFood',
                                notAllowedMealType: widget.notAllowedMealType,
                                selectedUser: null), // Single user mode
                        currentCalories:
                            dailyDataController.snacksCalories.value,
                        meals: dailyDataController.userMealList['Fruits'] ?? [],
                        icon: Icons.fastfood_outlined,
                        onAdd: () {
                          // Defer setState to avoid calling during build
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                foodType = 'Fruits';
                              });
                              _showSearchResults(context, 'Fruits');
                            }
                          });
                        },
                        onTap: () {
                          _showMealDetailModal(
                            context,
                            'Fruits',
                            dailyDataController.userMealList['Fruits'] ?? [],
                            dailyDataController.snacksCalories.value,
                            _calorieAdjustmentService.getAdjustedRecommendation(
                                'Fruits', 'addFood',
                                notAllowedMealType: widget.notAllowedMealType,
                                selectedUser: null), // Single user mode
                            Icons.fastfood_outlined,
                          );
                        },
                      );
                    }),
                    Obx(() {
                      // Access observable variables to trigger updates
                      _calorieAdjustmentService.mealAdjustments;
                      dailyDataController.snacksCalories.value;
                      dailyDataController.userMealList['Snacks'];

                      return _buildMealCard(
                        context: context,
                        mealType: 'Snacks',
                        recommendedCalories: _calorieAdjustmentService
                            .getAdjustedRecommendation('Snacks', 'addFood',
                                notAllowedMealType: widget.notAllowedMealType,
                                selectedUser: null), // Single user mode
                        currentCalories:
                            dailyDataController.snacksCalories.value,
                        meals: dailyDataController.userMealList['Snacks'] ?? [],
                        icon: Icons.fastfood_outlined,
                        onAdd: () {
                          // Defer setState to avoid calling during build
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                foodType = 'Snacks';
                              });
                              _showSearchResults(context, 'Snacks');
                            }
                          });
                        },
                        onTap: () {
                          _showMealDetailModal(
                            context,
                            'Snacks',
                            dailyDataController.userMealList['Snacks'] ?? [],
                            dailyDataController.snacksCalories.value,
                            _calorieAdjustmentService.getAdjustedRecommendation(
                                'Snacks', 'addFood',
                                notAllowedMealType: widget.notAllowedMealType,
                                selectedUser: null), // Single user mode
                            Icons.fastfood_outlined,
                          );
                        },
                      );
                    }),
                    // View Yesterday's Summary and Today's Action Items
                    if (isToday) ...[
                      SizedBox(height: getPercentageHeight(2, context)),

                      // Daily Summary Link
                      Padding(
                        key: _yesterdaySummaryKey,
                        padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(4, context)),
                        child: GestureDetector(
                          onTap: () {
                            final date = DateTime.now()
                                .subtract(const Duration(days: 1));
                            Get.to(() => DailySummaryScreen(date: date));
                          },
                          child: Container(
                            padding:
                                EdgeInsets.all(getPercentageWidth(3, context)),
                            decoration: BoxDecoration(
                              color: kAccentLight.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: kAccentLight.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Icon(
                                  Icons.insights,
                                  color: kAccentLight,
                                  size: getIconScale(4, context),
                                ),
                                SizedBox(width: getPercentageWidth(2, context)),
                                Text(
                                  'View Yesterday\'s Service',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: kAccentLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: getPercentageWidth(1, context)),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: kAccentLight,
                                  size: getIconScale(3.5, context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: getPercentageHeight(2, context)),
                      // Today's action items
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(2, context)),
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              // Get yesterday's date for the summary data
                              final yesterday = DateTime.now()
                                  .subtract(const Duration(days: 1));
                              final yesterdayStr =
                                  DateFormat('yyyy-MM-dd').format(yesterday);

                              // Get yesterday's summary data
                              final String userId = userService.userId ?? '';
                              Map<String, dynamic> yesterdaySummary = {};

                              if (userId.isNotEmpty) {
                                final summaryDoc = await firestore
                                    .collection('users')
                                    .doc(userId)
                                    .collection('daily_summary')
                                    .doc(yesterdayStr)
                                    .get();

                                if (summaryDoc.exists) {
                                  yesterdaySummary = summaryDoc.data() ?? {};
                                }
                              }

                              // Navigate directly to TomorrowActionItemsScreen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TomorrowActionItemsScreen(
                                    todaySummary: yesterdaySummary,
                                    tomorrowDate: DateFormat('yyyy-MM-dd')
                                        .format(DateTime.now()), // Today's date
                                    hasMealPlan: false,
                                    notificationType: 'manual',
                                  ),
                                ),
                              );
                            } catch (e) {
                              debugPrint('Error showing action items: $e');
                            }
                          },
                          child: Container(
                            padding:
                                EdgeInsets.all(getPercentageWidth(3, context)),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: kAccent.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: kAccent,
                                  size: getIconScale(4, context),
                                ),
                                SizedBox(width: getPercentageWidth(2, context)),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        'View Today\'s Prep List',
                                        style: textTheme.titleMedium?.copyWith(
                                          color: kAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(
                                          height: getPercentageHeight(
                                              0.5, context)),
                                      Text(
                                        'Based on yesterday\'s service',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: kAccent.withValues(alpha: 0.7),
                                          fontSize: getTextScale(2.5, context),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: getPercentageWidth(2, context)),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: kAccent,
                                  size: getIconScale(3.5, context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(2, context)),
                      // Quick Update Section (no longer expandable)
                      Padding(
                        key: _quickUpdateKey,
                        padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(2, context)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? kDarkGrey : kWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kAccent.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding:
                                EdgeInsets.all(getPercentageWidth(3, context)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Quick Update Header
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Quick Service Update',
                                      style: textTheme.titleLarge?.copyWith(
                                        fontSize:
                                            getPercentageWidth(5, context),
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode ? kWhite : kBlack,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const NutritionSettingsPage(
                                              isRoutineExpand: true,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Icon(Icons.edit,
                                          color: kAccent,
                                          size: getIconScale(5, context)),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                    height: getPercentageHeight(2, context)),
                                // Daily Routine Section
                                if (!allDisabled) ...[
                                  _buildDailyRoutineCard(context),
                                  SizedBox(
                                      height: getPercentageHeight(2, context)),
                                ],
                                // Water and Steps Labels
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Text(
                                      'Water',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                            fontSize: getPercentageWidth(
                                                4.5, context),
                                            fontWeight: FontWeight.w200,
                                          ),
                                    ),
                                    Text(
                                      'Steps',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                            fontSize: getPercentageWidth(
                                                4.5, context),
                                            fontWeight: FontWeight.w200,
                                          ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                    height: getPercentageHeight(1, context)),
                                // Water and Steps Trackers
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal:
                                          getPercentageWidth(3, context)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Obx(() {
                                          final currentUser =
                                              userService.currentUser.value;
                                          if (currentUser == null) {
                                            return const SizedBox.shrink();
                                          }
                                          final settings = currentUser.settings;
                                          final double waterTotal =
                                              double.tryParse(
                                                      settings['waterIntake']
                                                              ?.toString() ??
                                                          '0') ??
                                                  0.0;
                                          final double currentWater =
                                              dailyDataController
                                                  .currentWater.value;
                                          return _buildGoalTracker(
                                            context: context,
                                            title: 'Water',
                                            currentValue: currentWater,
                                            totalValue: waterTotal,
                                            unit: 'ml',
                                            onAdd: () async {
                                              // Not used with slider, but kept for compatibility
                                            },
                                            onRemove: () async {
                                              // Not used with slider, but kept for compatibility
                                            },
                                            onValueChanged: (newValue) async {
                                              final previousValue =
                                                  dailyDataController
                                                      .currentWater.value;

                                              await dailyDataController
                                                  .updateCurrentWater(
                                                      userService.userId!,
                                                      newValue,
                                                      date: currentDate);
                                              // Refresh the observable to trigger UI update
                                              final updatedValue =
                                                  await dailyDataController
                                                      .getWaterForDate(
                                                          userService.userId!,
                                                          currentDate);
                                              dailyDataController.currentWater
                                                  .value = updatedValue;

                                              // Award points if value actually changed
                                              // Use debounce to prevent multiple snackbars during dragging
                                              if (mounted &&
                                                  context.mounted &&
                                                  updatedValue !=
                                                      previousValue &&
                                                  updatedValue > 0) {
                                                // Cancel any pending snackbar
                                                _waterSnackbarDebounceTimer
                                                    ?.cancel();

                                                // Set a debounced snackbar that will show after user stops dragging
                                                _waterSnackbarDebounceTimer =
                                                    Timer(
                                                  const Duration(
                                                      milliseconds: 500),
                                                  () async {
                                                    if (!mounted ||
                                                        !context.mounted)
                                                      return;

                                                    final alreadyAwarded =
                                                        await badgeService
                                                            .hasBeenAwardedToday(
                                                      userService.userId!,
                                                      "Water logged!",
                                                    );
                                                    if (!alreadyAwarded) {
                                                      await badgeService
                                                          .awardPoints(
                                                        userService.userId!,
                                                        10,
                                                        reason: "Water logged!",
                                                      );
                                                      showTastySnackbar(
                                                        'Success',
                                                        'Water updated! +10 points',
                                                        context,
                                                      );
                                                    } else {
                                                      // Already awarded today, just show update confirmation
                                                      showTastySnackbar(
                                                        'Success',
                                                        'Water updated',
                                                        context,
                                                      );
                                                    }
                                                  },
                                                );
                                              }
                                            },
                                            iconColor: kBlue,
                                          );
                                        }),
                                      ),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(2, context)),
                                      Expanded(
                                        child: Obx(() {
                                          final currentUser =
                                              userService.currentUser.value;
                                          if (currentUser == null) {
                                            return const SizedBox.shrink();
                                          }
                                          final settings = currentUser.settings;
                                          final double stepsTotal =
                                              double.tryParse(
                                                      settings['targetSteps']
                                                              ?.toString() ??
                                                          '0') ??
                                                  0.0;
                                          final double currentSteps =
                                              dailyDataController
                                                  .currentSteps.value;

                                          return _buildGoalTracker(
                                            context: context,
                                            title: 'Steps',
                                            currentValue: currentSteps,
                                            totalValue: stepsTotal,
                                            unit: 'steps',
                                            onAdd: () async {
                                              // Not used with slider, but kept for compatibility
                                            },
                                            onRemove: () async {
                                              // Not used with slider, but kept for compatibility
                                            },
                                            onValueChanged: (newValue) async {
                                              final previousValue =
                                                  dailyDataController
                                                      .currentSteps.value;

                                              await dailyDataController
                                                  .updateCurrentSteps(
                                                      userService.userId!,
                                                      newValue,
                                                      date: currentDate);
                                              // Refresh the observable to trigger UI update
                                              final updatedValue =
                                                  await dailyDataController
                                                      .getStepsForDate(
                                                          userService.userId!,
                                                          currentDate);
                                              dailyDataController.currentSteps
                                                  .value = updatedValue;

                                              // Award points if value actually changed
                                              // Use debounce to prevent multiple snackbars during dragging
                                              if (mounted &&
                                                  context.mounted &&
                                                  updatedValue !=
                                                      previousValue &&
                                                  updatedValue > 0) {
                                                // Cancel any pending snackbar
                                                _stepsSnackbarDebounceTimer
                                                    ?.cancel();

                                                // Set a debounced snackbar that will show after user stops dragging
                                                _stepsSnackbarDebounceTimer =
                                                    Timer(
                                                  const Duration(
                                                      milliseconds: 500),
                                                  () async {
                                                    if (!mounted ||
                                                        !context.mounted)
                                                      return;

                                                    final alreadyAwarded =
                                                        await badgeService
                                                            .hasBeenAwardedToday(
                                                      userService.userId!,
                                                      "Steps logged!",
                                                    );
                                                    if (!alreadyAwarded) {
                                                      await badgeService
                                                          .awardPoints(
                                                        userService.userId!,
                                                        10,
                                                        reason: "Steps logged!",
                                                      );
                                                      showTastySnackbar(
                                                        'Success',
                                                        'Steps updated! +10 points',
                                                        context,
                                                      );
                                                    } else {
                                                      // Already awarded today, just show update confirmation
                                                      showTastySnackbar(
                                                        'Success',
                                                        'Steps updated',
                                                        context,
                                                      );
                                                    }
                                                  },
                                                );
                                              }
                                            },
                                            iconColor: kPurple,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRoutineCard(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? kDarkGrey : kWhite,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: getPercentageHeight(1, context)),
            SizedBox(
              height: getPercentageHeight(7, context),
              child: DailyRoutineListHorizontal(
                userId: userService.userId!,
                date: currentDate,
                isCardStyle: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalTracker({
    required BuildContext context,
    required String title,
    required double currentValue,
    required double totalValue,
    required String unit,
    required Future<void> Function() onAdd,
    required Future<void> Function() onRemove,
    required Color iconColor,
    required Future<void> Function(double newValue) onValueChanged,
  }) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final progress =
        totalValue > 0 ? (currentValue / totalValue).clamp(0.0, 1.0) : 0.0;

    return Container(
      height: getPercentageHeight(7, context),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background progress indicator
            LinearProgressIndicator(
              value: progress,
              minHeight: getProportionalHeight(60, context),
              backgroundColor: isDarkMode
                  ? kDarkGrey.withValues(alpha: kLowOpacity)
                  : kWhite.withValues(alpha: kLowOpacity),
              valueColor: AlwaysStoppedAnimation<Color>(
                  iconColor.withValues(alpha: 0.5)),
            ),
            // Draggable slider - must be on top for touch handling
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: iconColor,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: getIconScale(4, context),
                ),
                overlayShape: RoundSliderOverlayShape(
                  overlayRadius: getIconScale(8, context),
                ),
                trackHeight: getProportionalHeight(60, context),
                // Make the entire track area tappable
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                value: currentValue.clamp(
                    0.0, totalValue > 0 ? totalValue : 100.0),
                min: 0.0,
                max: totalValue > 0 ? totalValue : 100.0,
                onChanged: (value) async {
                  await onValueChanged(value);
                },
              ),
            ),
            // Value text overlay - positioned to not interfere with slider
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${currentValue.toInt()} ',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isDarkMode ? kWhite : kBlack,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(width: getPercentageWidth(1, context)),
                  Text(
                    unit,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isDarkMode ? kWhite : kBlack,
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard({
    required BuildContext context,
    required String mealType,
    required String recommendedCalories,
    required int currentCalories,
    required List<UserMeal> meals,
    required IconData icon,
    required VoidCallback onAdd,
    VoidCallback? onTap,
  }) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(2.5, context),
          vertical: getPercentageHeight(1, context)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? kDarkGrey : kWhite,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(2, context)),
        child: Row(
          children: [
            // Main clickable area
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Icon(icon,
                            size: getIconScale(10, context), color: kAccent),
                        if (meals.isNotEmpty)
                          Positioned(
                            right: -5,
                            top: -5,
                            child: Container(
                              padding: EdgeInsets.all(
                                  getPercentageWidth(0.5, context)),
                              decoration: const BoxDecoration(
                                color: kAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${meals.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: getTextScale(2, context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mealType,
                            style: textTheme.titleLarge?.copyWith(
                              fontSize: getPercentageWidth(4.5, context),
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? kWhite : kBlack,
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(0.5, context)),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  recommendedCalories,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                              if (_calorieAdjustmentService
                                  .hasAdjustment(mealType))
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        getPercentageWidth(1.5, context),
                                    vertical: getPercentageHeight(0.3, context),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          Colors.orange.withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Adjusted',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                      fontSize: getTextScale(2.5, context),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (currentCalories > 0 && showCaloriesAndGoal)
                            SizedBox(height: getPercentageHeight(1, context)),
                          if (currentCalories > 0 && showCaloriesAndGoal)
                            Text(
                              'Logged: $currentCalories kcal (${meals.length} ${meals.length == 1 ? 'plate' : 'plates'})',
                              style: textTheme.bodyMedium?.copyWith(
                                color: kAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (meals.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                  top: getPercentageHeight(1, context)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current plates:',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          getPercentageHeight(0.5, context)),
                                  ...meals.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final meal = entry.value;
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        left: getPercentageWidth(2, context),
                                        bottom:
                                            getPercentageHeight(0.3, context),
                                      ),
                                      child: index < 1
                                          ? Text(
                                              showCaloriesAndGoal
                                                  ? '${index + 1}. ${meal.name} (${meal.calories} kcal)'
                                                  : '${index + 1}. ${meal.name}',
                                              style:
                                                  textTheme.bodySmall?.copyWith(
                                                color: isDarkMode
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                            )
                                          : index == 1
                                              ? Text(
                                                  'Tap to see ${meals.length - 1} more plates...',
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: kAccent,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                )
                                              : const SizedBox(),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Add button - separate from main clickable area
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: EdgeInsets.all(getPercentageWidth(2, context)),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add,
                    color: Colors.grey.shade800,
                    size: getIconScale(4, context)),
              ),
            )
          ],
        ),
      ),
    );
  }

  /// Build date navigation section
  Widget _buildDateNavigation(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: getPercentageWidth(0.3, context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              if (DateNavigationUtils.canNavigateBackward(currentDate)) {
                _handleDateNavigation(
                    DateNavigationUtils.getPreviousDate(currentDate));
              }
            },
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: getIconScale(7, context),
              color: !DateNavigationUtils.canNavigateBackward(currentDate)
                  ? isDarkMode
                      ? kLightGrey.withValues(alpha: 0.5)
                      : kDarkGrey.withValues(alpha: 0.1)
                  : null,
            ),
          ),
          Row(
            children: [
              Text(
                '${getRelativeDayString(currentDate)}',
                style: textTheme.displaySmall?.copyWith(color: kAccent),
              ),
              SizedBox(width: getPercentageWidth(0.5, context)),
              if (getRelativeDayString(currentDate) != 'Today' &&
                  getRelativeDayString(currentDate) != 'Yesterday')
                Text(
                  ' ${shortMonthName(currentDate.month)} ${currentDate.day}',
                  style: textTheme.displaySmall?.copyWith(color: kAccent),
                ),
            ],
          ),
          IconButton(
            onPressed: () {
              if (DateNavigationUtils.isNextDateInFuture(currentDate)) {
                _handleDateNavigation(DateNavigationUtils.getTodayDate());
              } else {
                _handleDateNavigation(
                    DateNavigationUtils.getNextDate(currentDate));
              }
            },
            icon: Icon(
              Icons.arrow_forward_ios,
              size: getIconScale(7, context),
              color: DateNavigationUtils.isToday(currentDate)
                  ? isDarkMode
                      ? kLightGrey.withValues(alpha: 0.5)
                      : kDarkGrey.withValues(alpha: 0.1)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
