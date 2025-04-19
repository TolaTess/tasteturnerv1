import 'package:fl_chart/fl_chart.dart';
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
import '../widgets/custom_drawer.dart';
import '../widgets/date_widget.dart';
import '../widgets/icon_widget.dart';
import '../widgets/search_button.dart';
import './add_meal_manually_screen.dart';

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
  late Future<Map<String, dynamic>> chartDataFuture;
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

  @override
  void initState() {
    super.initState();
    _loadData();
    chartDataFuture = fetchChartData(userId);
  }

  Future<Map<String, dynamic>> fetchChartData(String userid) async {
    final caloriesByDate =
        await dailyDataController.fetchCaloriesByDate(userid);
    List<String> dateLabels = [];
    List<FlSpot> chartData = prepareChartData(caloriesByDate, dateLabels);

    return {
      'chartData': chartData,
      'dateLabels': dateLabels,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FlSpot> prepareChartData(
      Map<String, int> caloriesByDate, List<String> dateLabels) {
    List<FlSpot> spots = [];
    final sortedDates = caloriesByDate.keys.toList()
      ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));

    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final calories = caloriesByDate[date]!;
      spots.add(FlSpot(i.toDouble(), calories.toDouble()));
      dateLabels.add(date); // Populate date labels for the x-axis
    }

    return spots;
  }

  Future<void> _loadData() async {
    try {
      // Fetch meals and ingredients
      _allMeals = mealManager.meals;
      _allIngredients = macroManager.ingredient;
      dailyDataController.fetchMealsForToday(userId);
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

    try {
      // Search local meals
      final meals = _allMeals
          .where(
              (meal) => meal.title.toLowerCase().contains(query.toLowerCase()))
          .toList();

      // Search ingredients
      final ingredients = _allIngredients
          .where((ingredient) =>
              ingredient.title.toLowerCase().contains(query.toLowerCase()))
          .toList();

      // Search API meals
      List<Meal> apiMeals = [];
      if (query.length >= 3) {
        // Only search API if query is at least 3 characters
        apiMeals = await _apiService.fetchMeals(
          limit: 5, // Limit API results
          searchQuery: query,
        );
      }

      // Search API meals
      List<IngredientData> apiIngredients = [];
      if (query.length >= 3) {
        // Only search API if query is at least 3 characters
        apiIngredients = await _macroApiService.searchIngredients(query);
      }

      // Combine all results
      setState(() {
        _searchResults = [
          ...meals,
          ...ingredients,
          ...apiMeals,
          ...apiIngredients
        ];
      });
    } catch (e) {
      print('Error searching meals: $e');
    } finally {
      _isSearching.value = false;
    }
  }

  void _showSearchResults(BuildContext context, String mealType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: getThemeProvider(context).isDarkMode
                        ? kWhite.withOpacity(0.3)
                        : kBlack.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Meal type header
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text(
                    'Add to $mealType',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: getThemeProvider(context).isDarkMode
                          ? kWhite
                          : kBlack,
                    ),
                  ),
                ),
                // Search box
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SearchButton2(
                    controller: _searchController,
                    onChanged: (query) {
                      _filterSearchResults(query);
                    },
                    kText: 'Search meals or ingredients',
                  ),
                ),
                // Results
                Expanded(
                  child: Obx(() {
                    if (_isSearching.value) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: kAccent,
                        ),
                      );
                    }

                    if (_searchResults.isEmpty) {
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

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: result is Meal &&
                                  result.mediaPaths.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    result.mediaPaths.first,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Image.asset(
                                      getAssetImageForItem(
                                          result.category ?? 'default'),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : result is IngredientData &&
                                      result.mediaPaths.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        result.mediaPaths.first,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error,
                                                stackTrace) =>
                                            Image.asset(intPlaceholderImage),
                                      ),
                                    )
                                  : null,
                          title: Text(
                            result is Meal
                                ? result.title
                                : result is MacroData
                                    ? capitalizeFirstLetter(result.title)
                                    : result is IngredientData
                                        ? capitalizeFirstLetter(result.title)
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
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDetailPopup(dynamic result, String? userId, String mealType) {
    int selectedNumber = 0;
    int selectedUnit = 0;

    String itemName = result is Meal
        ? result.title
        : result is MacroData
            ? capitalizeFirstLetter(result.title)
            : result is IngredientData
                ? capitalizeFirstLetter(result.title)
                : 'Unknown Item';

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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    itemName,
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.3,
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildPicker(
                          context,
                          21,
                          selectedNumber,
                          (index) =>
                              setModalState(() => selectedNumber = index),
                        ),
                        buildPicker(
                          context,
                          unitOptions.length,
                          selectedUnit,
                          (index) => setModalState(() => selectedUnit = index),
                          unitOptions,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kAccent,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final userMeal = UserMeal(
                      name: itemName,
                      quantity: '$selectedNumber',
                      servings: '${unitOptions[selectedUnit]}',
                      calories: result is Meal
                          ? result.calories
                          : result is MacroData
                              ? result.calories
                              : 0,
                      mealId: result is Meal ? result.mealId : itemName,
                    );

                    try {
                      // Add meal to Firestore using nutritionController
                      await dailyDataController.addUserMeal(
                        userService.userId ?? '',
                        mealType, // Using the meal type (Breakfast/Lunch/Dinner)
                        userMeal,
                      );

                      if (mounted) {
                        showTastySnackbar(
                          'Success',
                          'Added ${userMeal.name} to $mealType',
                          context,
                        );
                      }

                      // Update local state
                      setState(() {
                        switch (mealType) {
                          case 'Breakfast':
                            breakfastList[widget.title] ??= [];
                            breakfastList[widget.title]!.add(userMeal);
                            break;
                          case 'Lunch':
                            lunchList[widget.title] ??= [];
                            lunchList[widget.title]!.add(userMeal);
                            break;
                          case 'Dinner':
                            dinnerList[widget.title] ??= [];
                            dinnerList[widget.title]!.add(userMeal);
                            break;
                        }
                      });

                      Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        showTastySnackbar(
                          'Please try again.',
                          'Failed to add meal: $e',
                          context,
                        );
                      }
                    }
                  },
                  child: Text(
                    'Add',
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kAccent,
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
    String? userid = userService.userId;

    return Scaffold(
      drawer: CustomDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
                children: [
                  GestureDetector(
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
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NutritionStatusBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: NutritionStatusBar(
                userId: userService.userId ?? '',
                userSettings: userService.currentUser!.settings,
                onMealTypeSelected: (mealType) {
                  setState(() {
                    foodType = mealType;
                  });
                  _showSearchResults(context, mealType);
                },
              ),
            ),

            const SizedBox(height: 20),

            //row of search icon and + button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    onPressed: () => _showSearchResults(context, foodType),
                    icon: const Icon(Icons.search)),
                IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddMealManuallyScreen(
                            mealType: foodType,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add)),
              ],
            ),

            // Selected Items List
            Expanded(
              child: Obx(() {
                final allMealsByType = widget.title == 'Add Food'
                    ? dailyDataController.userMealList.values
                        .expand((meals) => meals)
                        .toList()
                    : dailyDataController.userMealList[widget.title] ?? [];

                if (allMealsByType.isEmpty) {
                  return noItemTastyWidget(
                      'No items added', '', context, false);
                }

                return ListView.builder(
                  itemCount: allMealsByType.length,
                  itemBuilder: (context, index) {
                    final userMeal = allMealsByType[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kLightGrey.withOpacity(kLowOpacity),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      userMeal.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    iconSize: 20,
                                    color: isDarkMode
                                        ? kLightGrey
                                        : kWhite.withOpacity(kLowOpacity),
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      await dailyDataController.removeMeal(
                                        userService.userId ?? '',
                                        widget.title,
                                        userMeal,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ('${userMeal.quantity} ${userMeal.servings}'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${userMeal.calories} kcal',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w200,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
