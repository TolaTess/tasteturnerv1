import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../data_models/ingredient_data.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../helper/utils.dart';
import '../service/food_api_service.dart';
import '../service/meal_api_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../widgets/search_button.dart';
import 'createrecipe_screen.dart';

class AddFoodScreen extends StatefulWidget {
  final String title;

  const AddFoodScreen({
    super.key,
    this.title = 'Add Food',
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
  final MealApiService _apiService = MealApiService();
  final FoodApiService _macroApiService = FoodApiService();
  final RxBool _isSearching = false.obs;

  // Replace the food section maps with meal type maps
  final Map<String, List<UserMeal>> breakfastList = {};
  final Map<String, List<UserMeal>> lunchList = {};
  final Map<String, List<UserMeal>> dinnerList = {};

  // Add this as a class field at the top of the class
  List<UserMeal> _pendingMacroItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Fetch meals and ingredients
      _allMeals = mealManager.meals;
      _allIngredients = macroManager.ingredient;
      final currentDate = DateTime.now();
      dailyDataController.fetchMealsForToday(userId, currentDate);
      setState(() {});
    } catch (e) {
      print('Error loading data: $e');
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
                        ? kWhite.withOpacity(kMidOpacity)
                        : kBlack.withOpacity(kMidOpacity),
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
                          ? kWhite.withOpacity(0.3)
                          : kBlack.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Meal type header
                  Padding(
                    padding: EdgeInsets.only(
                        top: getPercentageHeight(4, context),
                        bottom: getPercentageHeight(2, context)),
                    child: Text(
                      'Add to $mealType',
                      style: TextStyle(
                        fontSize: getPercentageWidth(4.5, context),
                        fontWeight: FontWeight.w400,
                        color: getThemeProvider(context).isDarkMode
                            ? kWhite
                            : kBlack,
                      ),
                    ),
                  ),
                  // Search box
                  Row(
                    children: [
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
                          color: kAccent.withOpacity(0.5),
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
                                size: getPercentageWidth(6, context))),
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
                                        child: Image.network(
                                          result.mediaPaths.first,
                                          width:
                                              getPercentageWidth(10, context),
                                          height:
                                              getPercentageWidth(10, context),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Image.asset(
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
                                  child: CircularProgressIndicator(
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

    // Helper function to calculate calories based on selected number and unit
    int calculateAdjustedCalories() {
      if (result is Meal) {
        return result.calories; // Meals use their base calories
      }

      // Base calories (per serving)
      int baseCalories = result is MacroData
          ? result.calories
          : (result as IngredientData).getCalories().toInt();

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

      // Calculate ratio and adjust calories
      double ratio = selectedInGrams / baseInGrams;
      int adjustedCalories = (baseCalories * ratio).round();

      return adjustedCalories;
    }

    // Helper function to create UserMeal from any type
    UserMeal createUserMeal() {
      // Calculate adjusted calories
      int adjustedCalories = calculateAdjustedCalories();

      if (result is Meal) {
        final meal = UserMeal(
          name: result.title,
          quantity: '$selectedNumber',
          servings: '${unitOptions[selectedUnit]}',
          calories: result.calories,
          mealId: result.mealId,
        );
        return meal;
      } else if (result is MacroData) {
        final meal = UserMeal(
          name: result.title,
          quantity: '$selectedNumber',
          servings: '${unitOptions[selectedUnit]}',
          calories: adjustedCalories,
          mealId: result.id ?? result.title,
        );
        return meal;
      } else if (result is IngredientData) {
        final meal = UserMeal(
          name: result.title,
          quantity: '$selectedNumber',
          servings: '${unitOptions[selectedUnit]}',
          calories: adjustedCalories,
          mealId: result.title,
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
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.40,
                  ),
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
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.25,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Flexible(
                              flex: 1,
                              child: Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.25,
                                child: buildPicker(
                                    context,
                                    21,
                                    selectedNumber,
                                    (index) => setModalState(
                                        () => selectedNumber = index),
                                    false),
                              ),
                            ),
                            Flexible(
                              flex: 1,
                              child: Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.25,
                                child: buildPicker(
                                  context,
                                  unitOptions.length,
                                  selectedUnit,
                                  (index) =>
                                      setModalState(() => selectedUnit = index),
                                  false,
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
                    _pendingMacroItems.clear();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kAccent,
                      fontSize: getPercentageWidth(3.5, context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    try {
                      final newItem = createUserMeal();
                      _pendingMacroItems.add(newItem);
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
                      fontSize: getPercentageWidth(3.5, context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      // Always add the current item before saving
                      final newItem = createUserMeal();
                      _pendingMacroItems.add(newItem);

                      // Save all pending items
                      for (var item in _pendingMacroItems) {
                        await dailyDataController.addUserMeal(
                          userId ?? '',
                          mealType,
                          item,
                        );
                      }

                      if (mounted) {
                        showTastySnackbar(
                          'Success',
                          'Added ${_pendingMacroItems.length} ${_pendingMacroItems.length == 1 ? 'item' : 'items'} to $mealType',
                          context,
                        );
                      }
                      _pendingMacroItems.clear();
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
                      fontSize: getPercentageWidth(3.5, context),
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BottomNavSec(),
              ),
            );
          },
          child: const IconCircleButton(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: getPercentageHeight(2, context)),

              // Selected Items List
              SizedBox(
                height: MediaQuery.of(context).size.height -
                    getPercentageHeight(
                        30, context), // Fixed height for the list area
                child: Obx(() {
                  return Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // Breakfast Section (Left)
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.all(
                                    getPercentageWidth(2, context)),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? (dailyDataController
                                                  .userMealList['Breakfast']
                                                  ?.isNotEmpty ??
                                              false)
                                          ? kAccent.withOpacity(0.5)
                                          : kDarkGrey.withOpacity(0.9)
                                      : (dailyDataController
                                                  .userMealList['Breakfast']
                                                  ?.isNotEmpty ??
                                              false)
                                          ? kAccent.withOpacity(0.5)
                                          : kWhite.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.wb_sunny_outlined,
                                                  size: getPercentageWidth(
                                                      6, context),
                                                  color: isDarkMode
                                                      ? kWhite
                                                      : kDarkGrey),
                                              SizedBox(
                                                  width: getPercentageWidth(
                                                      2, context)),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    foodType = 'Breakfast';
                                                  });
                                                  _showSearchResults(
                                                      context, 'Breakfast');
                                                },
                                                child: Text(
                                                  'Breakfast',
                                                  style: TextStyle(
                                                    fontSize:
                                                        getPercentageWidth(
                                                            3.5, context),
                                                    fontWeight: FontWeight.bold,
                                                    color: isDarkMode
                                                        ? kWhite
                                                        : kDarkGrey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  foodType = 'Breakfast';
                                                });
                                                _showSearchResults(
                                                    context, 'Breakfast');
                                              },
                                              child: Icon(Icons.add,
                                                  color: kAccent,
                                                  size: getPercentageWidth(
                                                      6, context))),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: dailyDataController
                                                  .userMealList['Breakfast']
                                                  ?.isEmpty ??
                                              true
                                          ? Center(
                                              child: Text(
                                                'No breakfast items added',
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? kWhite.withOpacity(0.5)
                                                      : kDarkGrey
                                                          .withOpacity(0.5),
                                                  fontSize: getPercentageWidth(
                                                      3.5, context),
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              itemCount: dailyDataController
                                                      .userMealList['Breakfast']
                                                      ?.length ??
                                                  0,
                                              itemBuilder: (context, index) {
                                                final meal = dailyDataController
                                                        .userMealList[
                                                    'Breakfast']![index];
                                                return _buildMealItem(meal,
                                                    isDarkMode, 'Breakfast');
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Lunch Section (Right)
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? (dailyDataController
                                                  .userMealList['Lunch']
                                                  ?.isNotEmpty ??
                                              false)
                                          ? kAccent.withOpacity(0.5)
                                          : kDarkGrey.withOpacity(0.9)
                                      : (dailyDataController
                                                  .userMealList['Lunch']
                                                  ?.isNotEmpty ??
                                              false)
                                          ? kAccent.withOpacity(0.5)
                                          : kWhite.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.wb_cloudy_outlined,
                                                  size: getPercentageWidth(
                                                      6, context),
                                                  color: isDarkMode
                                                      ? kWhite
                                                      : kDarkGrey),
                                              SizedBox(
                                                  width: getPercentageWidth(
                                                      2, context)),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    foodType = 'Lunch';
                                                  });
                                                  _showSearchResults(
                                                      context, 'Lunch');
                                                },
                                                child: Text(
                                                  'Lunch',
                                                  style: TextStyle(
                                                    fontSize:
                                                        getPercentageWidth(
                                                            3.5, context),
                                                    fontWeight: FontWeight.bold,
                                                    color: isDarkMode
                                                        ? kWhite
                                                        : kDarkGrey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  foodType = 'Lunch';
                                                });
                                                _showSearchResults(
                                                    context, 'Lunch');
                                              },
                                              child: Icon(Icons.add,
                                                  color: kAccent,
                                                  size: getPercentageWidth(
                                                      6, context))),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: dailyDataController
                                                  .userMealList['Lunch']
                                                  ?.isEmpty ??
                                              true
                                          ? Center(
                                              child: Text(
                                                'No lunch items added',
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? kWhite.withOpacity(0.5)
                                                      : kDarkGrey
                                                          .withOpacity(0.5),
                                                  fontSize: getPercentageWidth(
                                                      3.5, context),
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 2),
                                              itemCount: dailyDataController
                                                      .userMealList['Lunch']
                                                      ?.length ??
                                                  0,
                                              itemBuilder: (context, index) {
                                                final meal = dailyDataController
                                                        .userMealList['Lunch']![
                                                    index];
                                                return _buildMealItem(
                                                    meal, isDarkMode, 'Lunch');
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dinner Section (Bottom)
                      Container(
                        height: MediaQuery.of(context).size.height * 0.3,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? (dailyDataController
                                          .userMealList['Dinner']?.isNotEmpty ??
                                      false)
                                  ? kAccentLight.withOpacity(0.5)
                                  : kDarkGrey.withOpacity(0.9)
                              : (dailyDataController
                                          .userMealList['Dinner']?.isNotEmpty ??
                                      false)
                                  ? kAccent.withOpacity(0.5)
                                  : kWhite.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.nightlight_outlined,
                                          size: getPercentageWidth(6, context),
                                          color:
                                              isDarkMode ? kWhite : kDarkGrey),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(2, context)),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            foodType = 'Dinner';
                                          });
                                          _showSearchResults(context, 'Dinner');
                                        },
                                        child: Text(
                                          'Dinner',
                                          style: TextStyle(
                                            fontSize: getPercentageWidth(
                                                3.5, context),
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isDarkMode ? kWhite : kDarkGrey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          foodType = 'Dinner';
                                        });
                                        _showSearchResults(context, 'Dinner');
                                      },
                                      child: Icon(Icons.add,
                                          color: kAccent,
                                          size:
                                              getPercentageWidth(6, context))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: dailyDataController
                                          .userMealList['Dinner']?.isEmpty ??
                                      true
                                  ? Center(
                                      child: Text(
                                        'No dinner items added',
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? kWhite.withOpacity(0.5)
                                              : kDarkGrey.withOpacity(0.5),
                                          fontSize:
                                              getPercentageWidth(3.5, context),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      itemCount: dailyDataController
                                              .userMealList['Dinner']?.length ??
                                          0,
                                      itemBuilder: (context, index) {
                                        final meal = dailyDataController
                                            .userMealList['Dinner']![index];
                                        return _buildMealItem(
                                            meal, isDarkMode, 'Dinner');
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build consistent meal items
  Widget _buildMealItem(UserMeal meal, bool isDarkMode, String mealType) {
    final currentDate = DateTime.now();
    return Card(
      elevation: 0,
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        title: Text(
          meal.name,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? kWhite : kDarkGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                '${meal.calories} kcal',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? kWhite.withOpacity(0.6) : kLightGrey,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: kRed),
          onPressed: () async {
            // Delete the meal
            await dailyDataController.removeMeal(
              userService.userId ?? '',
              mealType,
              meal,
              currentDate,
            );
          },
        ),
      ),
    );
  }
}
