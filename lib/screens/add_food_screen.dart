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
import '../service/auth_controller.dart';
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

  const AddFoodScreen({
    super.key,
    this.title = 'Update Goals',
    this.date,
    this.notAllowedMealType,
    this.isShowSummary = false,
  });

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen>
    with TickerProviderStateMixin {
  int currentPage = 0;

  String foodType = 'Breakfast'; // Default meal type

  // Updated lists with correct types
  List<Meal> _allMeals = [];
  List<MacroData> _allIngredients = [];
  List<dynamic> _searchResults = [];
  final userId = userService.userId ?? '';
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<double> currentNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> currentStepsNotifier = ValueNotifier<double>(0);
  final MealApiService _apiService = MealApiService();
  final FoodApiService _macroApiService = FoodApiService();
  final RxBool _isSearching = false.obs;
  final CalorieAdjustmentService _calorieAdjustmentService =
      Get.put(CalorieAdjustmentService());

  // Replace the food section maps with meal type maps
  final Map<String, List<UserMeal>> breakfastList = {};
  final Map<String, List<UserMeal>> lunchList = {};
  final Map<String, List<UserMeal>> dinnerList = {};
  final Map<String, List<UserMeal>> snacksList = {};
  bool allDisabled = false;

  // Add this as a class field at the top of the class
  List<UserMeal> _pendingMacroItems = [];

  // Track when meals were last modified to ensure accurate calorie calculations
  final Map<String, DateTime> _lastMealModification = {};

  // Hide calories feature
  bool showCaloriesAndGoal = true;

  // Helper function to safely convert settings value to bool
  bool _safeBoolFromSettings(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    if (value is int) {
      return value != 0;
    }
    return defaultValue;
  }

  // Handle health journal toggle
  Future<void> _handleHealthJournalToggle(bool value) async {
    final authController = Get.find<AuthController>();

    try {
      await authController.updateUserData({
        'settings.healthJournalEnabled': value,
      });

      if (mounted) {
        showTastySnackbar(
          value ? 'Health Journal Enabled' : 'Health Journal Disabled',
          value
              ? 'You can now track symptoms and how you feel after eating'
              : 'Health journal tracking is now disabled',
          context,
          backgroundColor: value ? kAccent : kLightGrey,
        );
      }
    } catch (e) {
      debugPrint('Error updating health journal preference: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to update health journal settings',
          context,
          backgroundColor: kRed,
        );
        // Force UI update to revert toggle on error
        setState(() {});
      }
    }
  }

  // Track pending items modifications for debugging
  void _addPendingItem(UserMeal item) {
    _pendingMacroItems.add(item);
  }

  void _clearPendingItems() {
    _pendingMacroItems.clear();
  }

  // Method to manually refresh meal data for a specific meal type
  Future<void> _refreshMealData(String mealType) async {
    try {
      // Force a refresh of the daily data
      dailyDataController.listenToDailyData(
        userId,
        widget.date ?? DateTime.now(),
      );

      // Wait for the data to be updated
      await Future.delayed(const Duration(milliseconds: 200));

      // Track when this meal type was last modified
      _lastMealModification[mealType] = DateTime.now();

      // Force a rebuild of the UI
      setState(() {});
    } catch (e) {
      debugPrint('Error refreshing meal data: $e');
    }
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

  // Method to check if we need to force a refresh for a meal type
  bool _needsRefresh(String mealType) {
    final lastMod = _lastMealModification[mealType];
    if (lastMod == null) return false;

    // If the last modification was more than 5 seconds ago, we might need a refresh
    final timeSinceLastMod = DateTime.now().difference(lastMod);
    return timeSinceLastMod.inSeconds > 5;
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
    _loadData();
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
    _searchController.dispose();
    // Clear pending items to prevent memory leaks
    _clearPendingItems();
    _lastMealModification.clear();
    // Don't clear adjustments - let them persist throughout the day
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Fetch meals and ingredients
      _allMeals = mealManager.meals;
      _allIngredients = macroManager.ingredient;
      final currentDate = widget.date ?? DateTime.now();
      dailyDataController.listenToDailyData(userId, currentDate);

      // Ensure calorie adjustment service has current data
      await _calorieAdjustmentService.loadAdjustmentsFromSharedPrefs();
    } catch (e) {
      debugPrint('Error loading data: $e');
      // TODO: Handle error
    }
  }

  void _filterSearchResults(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _isSearching.value = true;

    // Track the latest query to avoid race conditions
    final String currentQuery = query;

    // Search local meals
    final meals = _allMeals
        .where((meal) => meal.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    // Search ingredients
    final ingredients = _allIngredients
        .where((ingredient) =>
            ingredient.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    // Combine and filter local results
    final localResults = [
      ...meals,
      ...ingredients,
    ].where((item) {
      if (item == null) return false;
      final title = item is Meal
          ? item.title
          : item is MacroData
              ? item.title
              : item is IngredientData
                  ? item.title
                  : null;
      return title != null && title != 'Unknown';
    }).toList();

    // Show local results immediately
    setState(() {
      // Only keep items that match the current query
      _searchResults = localResults;
    });

    // Now fetch API results asynchronously and append them
    if (query.length >= 3) {
      final apiMealsFuture = _apiService.fetchMeals(
        limit: 5, // Limit API results
        searchQuery: query,
      );
      final apiIngredientsFuture = _macroApiService.searchIngredients(query);

      // Wait for both API calls
      final results = await Future.wait([
        apiMealsFuture,
        apiIngredientsFuture,
      ]);
      // Before updating, check if the query is still the latest
      if (currentQuery != _searchController.text) {
        // User has typed something else, so don't update
        return;
      }
      List<Meal> apiMeals = results[0] as List<Meal>;
      List<IngredientData> apiIngredients = results[1] as List<IngredientData>;

      // Filter API results
      final apiResults = [
        ...apiMeals,
        ...apiIngredients,
      ].where((item) {
        if (item == null) return false;
        final title = item is Meal
            ? item.title
            : item is MacroData
                ? item.title
                : item is IngredientData
                    ? item.title
                    : null;
        return title != null &&
            title != 'Unknown' &&
            title.toLowerCase().contains(query.toLowerCase());
      }).toList();

      // Append API results to the current search results, but only if they match the query
      setState(() {
        // Only keep items that match the current query
        final filteredLocal = _searchResults.where((item) {
          final title = item is Meal
              ? item.title
              : item is MacroData
                  ? item.title
                  : item is IngredientData
                      ? item.title
                      : null;
          return title != null &&
              title != 'Unknown' &&
              title.toLowerCase().contains(query.toLowerCase());
        }).toList();
        _searchResults = [...filteredLocal, ...apiResults];
      });
    }
    _isSearching.value = false;
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
                          'Add to ${capitalizeFirstLetter(foodType)}',
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
                              _filterSearchResults(query);
                            },
                            kText: 'Search meals or ingredients',
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
                            'No results found',
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
      date: widget.date ?? DateTime.now(),
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

  void _showFillRemainingMacrosDialog(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

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
    final currentProtein = 0.0; // TODO: Get from daily summary
    final currentCarbs = 0.0; // TODO: Get from daily summary
    final currentFat = 0.0; // TODO: Get from daily summary

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
            'Fill Remaining Macros',
            style: TextStyle(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          content: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your remaining macros:',
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
                                    int.tryParse(caloriesController.text) ?? 0;
                                final remainingProt =
                                    double.tryParse(proteinController.text) ??
                                        0.0;
                                final remainingCarb =
                                    double.tryParse(carbsController.text) ??
                                        0.0;
                                final remainingFatVal =
                                    double.tryParse(fatController.text) ?? 0.0;

                                final results = await ReversePantrySearchService
                                    .instance
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

                  // Suggestions list
                  if (suggestions.isNotEmpty) ...[
                    SizedBox(height: getPercentageHeight(2, context)),
                    Text(
                      'Suggestions:',
                      style: TextStyle(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.w600,
                        fontSize: getTextScale(4, context),
                      ),
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
                                color: isDarkMode ? kWhite : kBlack,
                              ),
                            ),
                            subtitle: Text(
                              '${item['calories']} kcal • P: ${item['protein']?.toStringAsFixed(1) ?? '0'}g • C: ${item['carbs']?.toStringAsFixed(1) ?? '0'}g • F: ${item['fat']?.toStringAsFixed(1) ?? '0'}g',
                              style: TextStyle(
                                color: isDarkMode ? kLightGrey : kDarkGrey,
                              ),
                            ),
                            trailing: Icon(
                              Icons.add_circle_outline,
                              color: kAccent,
                            ),
                            onTap: () {
                              // Add this item to the current meal type
                              Navigator.pop(dialogContext);
                              // TODO: Navigate to add this meal
                              _addSuggestedMeal(item);
                            },
                          );
                        },
                      ),
                    ),
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

  Future<void> _addSuggestedMeal(Map<String, dynamic> item) async {
    // TODO: Implement adding suggested meal to current meal type
    // For now, show a message
    if (mounted) {
      showTastySnackbar(
        'Meal Selected',
        '${item['name']} - Add this meal from the search results',
        context,
      );
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
                  'Loading recent meals...',
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

      // Fetch last 30 days
      for (int i = 1; i <= 30; i++) {
        final checkDate = currentDate.subtract(Duration(days: i));
        final dateStr = dateFormat.format(checkDate);

        try {
          final mealsDoc = await firestore
              .collection('userMeals')
              .doc(userId)
              .collection('meals')
              .doc(dateStr)
              .get();

          if (mealsDoc.exists) {
            final mealsData =
                mealsDoc.data()?['meals'] as Map<String, dynamic>? ?? {};
            int totalMeals = 0;
            for (var mealType in ['Breakfast', 'Lunch', 'Dinner', 'Fruits']) {
              final mealList = mealsData[mealType] as List<dynamic>? ?? [];
              totalMeals += mealList.length;
            }

            if (totalMeals > 0) {
              recentDates.add({
                'date': checkDate,
                'dateStr': dateStr,
                'mealCount': totalMeals,
              });
            }
          }
        } catch (e) {
          debugPrint('Error checking date $dateStr: $e');
        }
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (recentDates.isEmpty) {
        if (mounted) {
          showTastySnackbar(
            'No Previous Meals',
            'No meals found in the last 30 days',
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
          'Copy Meals from Previous Days',
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
                'Select a date to view meals:',
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
                        '$mealCount ${mealCount == 1 ? 'meal' : 'meals'}',
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
                    helpText: 'Select date to copy meals from',
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
                  'Loading meals...',
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
          .get();

      // Close loading
      if (mounted) Navigator.pop(context);

      if (!mealsDoc.exists) {
        if (mounted) {
          showTastySnackbar(
            'No Meals Found',
            'No meals found for the selected date',
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
        showTastySnackbar(
          'Error',
          'Failed to fetch meals: $e',
          context,
          backgroundColor: kRed,
        );
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
            'Copy Meals from ${DateFormat('MMM dd, yyyy').format(sourceDate)}',
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
                    'Select meals to copy:',
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
                'Copy ${selectedMeals.length} ${selectedMeals.length == 1 ? 'Meal' : 'Meals'}',
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
    try {
      final currentDate = widget.date ?? DateTime.now();

      for (var entry in mealTypes.entries) {
        final mealType = entry.key;
        final meals = entry.value;

        for (var meal in meals) {
          // Create new instance with originalMealId
          final newInstance = meal.copyWith({
            'originalMealId': meal.mealId,
            'isInstance': true,
            'loggedAt': DateTime.now(),
          });

          await dailyDataController.addUserMeal(
            userId,
            mealType,
            newInstance,
            currentDate,
          );
        }
      }

      if (mounted) {
        showTastySnackbar(
          'Success',
          'Copied ${mealsToCopy.length} ${mealsToCopy.length == 1 ? 'meal' : 'meals'} to today',
          context,
        );
      }

      // Refresh data
      await _loadData();
    } catch (e) {
      debugPrint('Error copying meals: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to copy meals: $e',
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
    showDialog(
      context: context,
      builder: (context) => MealDetailWidget(
        mealType: mealType,
        meals: meals,
        currentCalories: currentCalories,
        recommendedCalories: recommendedCalories,
        icon: icon,
        showCalories: showCaloriesAndGoal,
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
    String? selectedContext; // Track selected eating context

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
          eatingContext: selectedContext,
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
          eatingContext: selectedContext,
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
          eatingContext: selectedContext,
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
                'Add to $mealType',
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
                                '${_getCurrentCaloriesForMealType(mealType)} kcal from ${dailyDataController.userMealList[mealType]?.length ?? 0} ${dailyDataController.userMealList[mealType]?.length == 1 ? 'meal' : 'meals'}',
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
                                '${dailyDataController.userMealList[mealType]?.length ?? 0} ${dailyDataController.userMealList[mealType]?.length == 1 ? 'meal' : 'meals'}',
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
                      // Eating Context Selection
                      SizedBox(height: getPercentageHeight(1, context)),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Why did you eat this? (Optional)',
                              style: TextStyle(
                                color: isDarkMode ? kWhite : kBlack,
                                fontWeight: FontWeight.w600,
                                fontSize: getTextScale(3, context),
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(0.5, context)),
                            Wrap(
                              spacing: getPercentageWidth(1.5, context),
                              runSpacing: getPercentageHeight(0.5, context),
                              children: [
                                _buildContextButton(
                                  context,
                                  'Meal',
                                  '🍽️',
                                  selectedContext == 'meal',
                                  () => setModalState(() => selectedContext =
                                      selectedContext == 'meal'
                                          ? null
                                          : 'meal'),
                                  isDarkMode,
                                ),
                                _buildContextButton(
                                  context,
                                  'Hunger',
                                  '🍽️',
                                  selectedContext == 'hunger',
                                  () => setModalState(() => selectedContext =
                                      selectedContext == 'hunger'
                                          ? null
                                          : 'hunger'),
                                  isDarkMode,
                                ),
                                _buildContextButton(
                                  context,
                                  'Boredom',
                                  '😴',
                                  selectedContext == 'boredom',
                                  () => setModalState(() => selectedContext =
                                      selectedContext == 'boredom'
                                          ? null
                                          : 'boredom'),
                                  isDarkMode,
                                ),
                                _buildContextButton(
                                  context,
                                  'Stress',
                                  '😰',
                                  selectedContext == 'stress',
                                  () => setModalState(() => selectedContext =
                                      selectedContext == 'stress'
                                          ? null
                                          : 'stress'),
                                  isDarkMode,
                                ),
                                _buildContextButton(
                                  context,
                                  'Social',
                                  '👥',
                                  selectedContext == 'social',
                                  () => setModalState(() => selectedContext =
                                      selectedContext == 'social'
                                          ? null
                                          : 'social'),
                                  isDarkMode,
                                ),
                                _buildContextButton(
                                  context,
                                  'Planned',
                                  '✅',
                                  selectedContext == 'planned',
                                  () => setModalState(() => selectedContext =
                                      selectedContext == 'planned'
                                          ? null
                                          : 'planned'),
                                  isDarkMode,
                                ),
                              ],
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
                    'Add Another',
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

                      // Save all pending items
                      for (var item in _pendingMacroItems) {
                        await dailyDataController.addUserMeal(
                          userId ?? '',
                          mealType,
                          item,
                          widget.date ?? DateTime.now(),
                        );
                      }

                      // Check for calorie overage using the pre-calculated values
                      if (mounted) {
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

                      if (mounted) {
                        showTastySnackbar(
                          'Success',
                          'Added ${_pendingMacroItems.length} ${_pendingMacroItems.length == 1 ? 'item' : 'items'} to $mealType',
                          context,
                        );
                      }
                      _clearPendingItems();
                      Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
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
                    'Save All',
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
    final isToday = widget.date != null &&
        DateFormat('dd/MM/yyyy').format(widget.date!) ==
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
        toolbarHeight: getPercentageHeight(10, context),
          title: Text(
              widget.title,
              style: textTheme.displaySmall?.copyWith(
                fontSize: getTextScale(7, context),
              ),
            ),
        actions: [

                     InfoIconWidget(
              title: 'Food Diary',
              description: 'Track your daily meals and nutrition',
              details: const [
                {
                  'icon': Icons.restaurant,
                  'title': 'Log Meals',
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
                  'title': 'View History',
                  'description': 'See your eating patterns over time',
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
                  'title': 'Analyze Meals',
                  'description': 'Analyze your meals with AI and get insights',
                  'color': kAccent,
                },
              ],
              iconColor: isDarkMode ? kWhite : kDarkGrey,
              tooltip: 'Food Diary Information',
            ),
          // Health Journal Toggle
          Obx(() {
            final user = userService.currentUser.value;
            final isHealthJournalEnabled = user != null
                ? _safeBoolFromSettings(user.settings['healthJournalEnabled'],
                    defaultValue: false)
                : false;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _handleHealthJournalToggle(!isHealthJournalEnabled);
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
                    isHealthJournalEnabled
                        ? Icons.health_and_safety
                        : Icons.health_and_safety_outlined,
                    color: isDarkMode ? kWhite : kDarkGrey,
                    size: getIconScale(5, context),
                  ),
                ),
              ),
            );
          }),
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
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context),
                ),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  showCaloriesAndGoal ? Icons.visibility_off : Icons.visibility,
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
                  horizontal: getPercentageWidth(2, context),
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
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(2.5, context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: getPercentageHeight(2, context)),

                // Daily Routine Section
                if (!allDisabled && isToday)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Quick Update',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: getPercentageWidth(4.5, context),
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? kWhite : kBlack,
                            ),
                      ),
                      SizedBox(width: getPercentageWidth(2, context)),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NutritionSettingsPage(
                                isRoutineExpand: true,
                              ),
                            ),
                          );
                        },
                        child: Icon(Icons.edit,
                            color: kAccent, size: getIconScale(4.5, context)),
                      ),
                    ],
                  ),
                if (!allDisabled && isToday)
                  SizedBox(height: getPercentageHeight(2, context)),
                if (!allDisabled && isToday) _buildDailyRoutineCard(context),
                if (isToday) SizedBox(height: getPercentageHeight(2, context)),
                if (isToday)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        'Water',
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontSize: getPercentageWidth(4.5, context),
                                  fontWeight: FontWeight.w200,
                                ),
                      ),
                      Text(
                        'Steps',
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontSize: getPercentageWidth(4.5, context),
                                  fontWeight: FontWeight.w200,
                                ),
                      ),
                    ],
                  ),
                if (isToday)
                  SizedBox(height: getPercentageHeight(3.5, context)),

                // Water and Steps Trackers
                if (isToday)
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(3, context)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Obx(() {
                            final settings =
                                userService.currentUser.value!.settings;
                            final double waterTotal = double.tryParse(
                                    settings['waterIntake']?.toString() ??
                                        '0') ??
                                0.0;
                            final double currentWater =
                                dailyDataController.currentWater.value;
                            return _buildGoalTracker(
                              context: context,
                              title: 'Water',
                              currentValue: currentWater,
                              totalValue: waterTotal,
                              unit: 'ml',
                              onAdd: () {
                                dailyDataController.updateCurrentWater(
                                    userService.userId!, currentWater + 250);
                              },
                              onRemove: () {
                                dailyDataController.updateCurrentWater(
                                    userService.userId!, currentWater - 250);
                              },
                              iconColor: kBlue,
                            );
                          }),
                        ),
                        SizedBox(width: getPercentageWidth(2, context)),
                        Expanded(
                          child: Obx(() {
                            final settings =
                                userService.currentUser.value!.settings;
                            final double stepsTotal = double.tryParse(
                                    settings['targetSteps']?.toString() ??
                                        '0') ??
                                0.0;
                            final double currentSteps =
                                dailyDataController.currentSteps.value;
                            return _buildGoalTracker(
                              context: context,
                              title: 'Steps',
                              currentValue: currentSteps,
                              totalValue: stepsTotal,
                              unit: 'steps',
                              onAdd: () {
                                dailyDataController.updateCurrentSteps(
                                    userService.userId!, currentSteps + 1000);
                              },
                              onRemove: () {
                                dailyDataController.updateCurrentSteps(
                                    userService.userId!, currentSteps - 1000);
                              },
                              iconColor: kPurple,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: getPercentageHeight(2, context)),

                // Fill Remaining Macros Button
                if (isToday)
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(3, context)),
                    child: GestureDetector(
                      onTap: () => _showFillRemainingMacrosDialog(context),
                      child: Container(
                        padding: EdgeInsets.all(getPercentageWidth(3, context)),
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
                              Icons.search,
                              color: kAccent,
                              size: getIconScale(5, context),
                            ),
                            SizedBox(width: getPercentageWidth(2, context)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Fill Remaining Macros',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: kAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          getPercentageHeight(0.3, context)),
                                  Text(
                                    'Find foods that fit your remaining macros',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: kAccent.withValues(alpha: 0.7),
                                      fontSize: getTextScale(2.5, context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: kAccent,
                              size: getIconScale(4, context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isToday) SizedBox(height: getPercentageHeight(2, context)),

                // Daily Summary Link
                if (isToday || widget.isShowSummary)
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(3, context)),
                    child: GestureDetector(
                      onTap: () {
                        final date =
                            DateTime.now().subtract(const Duration(days: 1));
                        Get.to(() => DailySummaryScreen(date: date));
                      },
                      child: Container(
                        padding: EdgeInsets.all(getPercentageWidth(3, context)),
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
                              'View Yesterday\'s Summary',
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

                // Todays's action items
                if (isToday || widget.isShowSummary)
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(3, context)),
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          // Get yesterday's date for the summary data
                          final yesterday =
                              DateTime.now().subtract(const Duration(days: 1));
                          final yesterdayStr =
                              DateFormat('yyyy-MM-dd').format(yesterday);

                          // Get yesterday's summary data
                          final userId = userService.userId ?? '';
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
                              builder: (context) => TomorrowActionItemsScreen(
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
                        padding: EdgeInsets.all(getPercentageWidth(3, context)),
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
                                    'View Today\'s Action Items',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: kAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(
                                      height:
                                          getPercentageHeight(0.5, context)),
                                  Text(
                                    'Based on yesterday\'s summary',
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

                Center(
                  child: Text(
                    'Track Your Meals',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: getPercentageWidth(4.5, context),
                          fontWeight: FontWeight.w600,
                          color: kAccentLight,
                        ),
                  ),
                ),
                SizedBox(height: getPercentageHeight(1, context)),
                if (widget.notAllowedMealType != null &&
                    widget.notAllowedMealType != '')
                  Center(
                    child: Text(
                      'Your program does not include ${capitalizeFirstLetter(widget.notAllowedMealType ?? '')}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: getPercentageWidth(3.5, context),
                            fontWeight: FontWeight.w200,
                            color: kAccent,
                          ),
                    ),
                  ),

                SizedBox(height: getPercentageHeight(1, context)),

                // Selected Items List
                SizedBox(
                  height: MediaQuery.of(context).size.height -
                      getPercentageHeight(
                          20, context), // Fixed height for the list area
                  child: Column(
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
                              dailyDataController.userMealList['Breakfast'] ??
                                  [],
                          icon: Icons.emoji_food_beverage_outlined,
                          onAdd: () {
                            setState(() {
                              foodType = 'Breakfast';
                            });
                            _showSearchResults(context, 'Breakfast');
                          },
                          onTap: () {
                            _showMealDetailModal(
                              context,
                              'Breakfast',
                              dailyDataController.userMealList['Breakfast'] ??
                                  [],
                              dailyDataController.breakfastCalories.value,
                              _calorieAdjustmentService
                                  .getAdjustedRecommendation(
                                      'Breakfast', 'addFood',
                                      notAllowedMealType:
                                          widget.notAllowedMealType),
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
                          meals:
                              dailyDataController.userMealList['Lunch'] ?? [],
                          icon: Icons.lunch_dining_outlined,
                          onAdd: () {
                            setState(() {
                              foodType = 'Lunch';
                            });
                            _showSearchResults(context, 'Lunch');
                          },
                          onTap: () {
                            _showMealDetailModal(
                              context,
                              'Lunch',
                              dailyDataController.userMealList['Lunch'] ?? [],
                              dailyDataController.lunchCalories.value,
                              _calorieAdjustmentService
                                  .getAdjustedRecommendation('Lunch', 'addFood',
                                      notAllowedMealType:
                                          widget.notAllowedMealType,
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
                          meals:
                              dailyDataController.userMealList['Dinner'] ?? [],
                          icon: Icons.dinner_dining_outlined,
                          onAdd: () {
                            setState(() {
                              foodType = 'Dinner';
                            });
                            _showSearchResults(context, 'Dinner');
                          },
                          onTap: () {
                            _showMealDetailModal(
                              context,
                              'Dinner',
                              dailyDataController.userMealList['Dinner'] ?? [],
                              dailyDataController.dinnerCalories.value,
                              _calorieAdjustmentService
                                  .getAdjustedRecommendation(
                                      'Dinner', 'addFood',
                                      notAllowedMealType:
                                          widget.notAllowedMealType,
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
                          meals:
                              dailyDataController.userMealList['Fruits'] ?? [],
                          icon: Icons.fastfood_outlined,
                          onAdd: () {
                            setState(() {
                              foodType = 'Fruits';
                            });
                            _showSearchResults(context, 'Fruits');
                          },
                          onTap: () {
                            _showMealDetailModal(
                              context,
                              'Fruits',
                              dailyDataController.userMealList['Fruits'] ?? [],
                              dailyDataController.snacksCalories.value,
                              _calorieAdjustmentService
                                  .getAdjustedRecommendation(
                                      'Fruits', 'addFood',
                                      notAllowedMealType:
                                          widget.notAllowedMealType,
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
                          meals:
                              dailyDataController.userMealList['Snacks'] ?? [],
                          icon: Icons.fastfood_outlined,
                          onAdd: () {
                            setState(() {
                              foodType = 'Snacks';
                            });
                            _showSearchResults(context, 'Snacks');
                          },
                          onTap: () {
                            _showMealDetailModal(
                              context,
                              'Snacks',
                              dailyDataController.userMealList['Snacks'] ?? [],
                              dailyDataController.snacksCalories.value,
                              _calorieAdjustmentService
                                  .getAdjustedRecommendation(
                                      'Snacks', 'addFood',
                                      notAllowedMealType:
                                          widget.notAllowedMealType,
                                      selectedUser: null), // Single user mode
                              Icons.fastfood_outlined,
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextButton(
    BuildContext context,
    String label,
    String emoji,
    bool isSelected,
    VoidCallback onTap,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(2.5, context),
          vertical: getPercentageHeight(0.8, context),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? kAccent.withValues(alpha: 0.2)
              : (isDarkMode ? kDarkGrey : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? kAccent
                : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: getTextScale(3.5, context)),
            ),
            SizedBox(width: getPercentageWidth(0.8, context)),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? kAccent : (isDarkMode ? kWhite : kBlack),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: getTextScale(2.8, context),
              ),
            ),
          ],
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
                date: DateTime.now(),
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
    required VoidCallback onAdd,
    required VoidCallback onRemove,
    required Color iconColor,
  }) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final progress =
        totalValue > 0 ? (currentValue / totalValue).clamp(0.0, 1.0) : 0.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
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
                LinearProgressIndicator(
                  value: progress,
                  minHeight: getProportionalHeight(60, context),
                  backgroundColor: isDarkMode
                      ? kDarkGrey.withValues(alpha: kLowOpacity)
                      : kWhite.withValues(alpha: kLowOpacity),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      iconColor.withValues(alpha: 0.5)),
                ),
                Row(
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
              ],
            ),
          ),
        ),
        Positioned(
          top: -20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: kAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add,
                      color: Colors.white, size: getIconScale(7, context)),
                ),
              ),
              SizedBox(width: getPercentageWidth(5, context)),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: kAccentLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.remove,
                      color: Colors.white, size: getIconScale(7, context)),
                ),
              ),
            ],
          ),
        ),
      ],
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
                              'Added: $currentCalories kcal (${meals.length} ${meals.length == 1 ? 'meal' : 'meals'})',
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
                                    'Current meals:',
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
                                                  'Tap to see ${meals.length - 1} more...',
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
}
