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
                            leading:
                                result is Meal && result.mediaPaths.isNotEmpty
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //row of search icon and + button
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.3,
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  margin: const EdgeInsets.only(top: 12, bottom: 12, right: 14),
                  decoration: BoxDecoration(
                    color: isDarkMode ? kDarkGrey : kWhite,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                          onPressed: () =>
                              _showSearchResults(context, foodType),
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
                ),
              ),

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

              // Selected Items List
              SizedBox(
                height: MediaQuery.of(context).size.height -
                    300, // Fixed height for the list area
                child: Obx(() {
                  return Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // Breakfast Section (Left)
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(8),
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
                                                  color: isDarkMode
                                                      ? kWhite
                                                      : kDarkGrey),
                                              const SizedBox(width: 8),
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
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDarkMode
                                                        ? kWhite
                                                        : kDarkGrey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${dailyDataController.userMealList['Breakfast']?.length ?? 0} items',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDarkMode
                                                  ? kWhite.withOpacity(0.7)
                                                  : kDarkGrey.withOpacity(0.7),
                                            ),
                                          ),
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
                                                  color: isDarkMode
                                                      ? kWhite
                                                      : kDarkGrey),
                                              const SizedBox(width: 8),
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
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDarkMode
                                                        ? kWhite
                                                        : kDarkGrey,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${dailyDataController.userMealList['Lunch']?.length ?? 0} items',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDarkMode
                                                  ? kWhite.withOpacity(0.7)
                                                  : kDarkGrey.withOpacity(0.7),
                                            ),
                                          ),
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
                                  ? kAccent.withOpacity(0.5)
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
                                          color:
                                              isDarkMode ? kWhite : kDarkGrey),
                                      const SizedBox(width: 8),
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
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isDarkMode ? kWhite : kDarkGrey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${dailyDataController.userMealList['Dinner']?.length ?? 0} items',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? kWhite.withOpacity(0.7)
                                          : kDarkGrey.withOpacity(0.7),
                                    ),
                                  ),
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
          icon: Icon(Icons.delete_outline, color: kRed.withOpacity(0.5)),
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
