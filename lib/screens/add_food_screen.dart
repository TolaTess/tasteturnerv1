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
import '../widgets/secondary_button.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
    chartDataFuture = fetchChartData(userId);
  }

  Future<Map<String, dynamic>> fetchChartData(String userid) async {
    final caloriesByDate =
        await nutritionController.fetchCaloriesByDate(userid);
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
      nutritionController.fetchMealsForToday(userId);
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

  void _showDetailPopup(dynamic result, String? userId, String foodType) {
    int selectedNumber = 0; // For option
    int selectedUnit = 0; // For option 3
    List<UserMeal> selectedMacroItems = [];

    // Item name
    String itemName = result is Meal
        ? result.title
        : result is MacroData
            ? capitalizeFirstLetter(result.title)
            : result is IngredientData
                ? capitalizeFirstLetter(result.title)
                : 'Unknown Item';
    String mealId = result is Meal
        ? result.mealId
        : result is MacroData
            ? capitalizeFirstLetter(result.title)
            : result is IngredientData
                ? capitalizeFirstLetter(result.title)
                : 'Unknown Item';

    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = getThemeProvider(context).isDarkMode;

        return StatefulBuilder(
          // ✅ Allow UI updates inside the dialog
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor:
                  isDarkMode ? kLightGrey.withOpacity(kOpacity) : kWhite,
              title: Text(
                itemName,
                style: TextStyle(color: isDarkMode ? kWhite : kBlack),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Meal type selection row
                  if (widget.title == 'Add Food') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMealTypeOption(
                            'Breakfast', 'Breakfast', foodType == 'Breakfast',
                            (isSelected) {
                          setModalState(() {
                            foodType = isSelected ? 'Breakfast' : foodType;
                          });
                        }),
                        _buildMealTypeOption(
                            'Lunch', 'Lunch', foodType == 'Lunch',
                            (isSelected) {
                          setModalState(() {
                            foodType = isSelected ? 'Lunch' : foodType;
                          });
                        }),
                        _buildMealTypeOption(
                            'Dinner', 'Dinner', foodType == 'Dinner',
                            (isSelected) {
                          setModalState(() {
                            foodType = isSelected ? 'Dinner' : foodType;
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ] else ...[
                    const SizedBox.shrink(),
                  ],
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
                  // ✅ Show selected macro items if any
                  if (result is MacroData ||
                      result is IngredientData &&
                          selectedMacroItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text("Selected Ingredients:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Column(
                      children: selectedMacroItems
                          .map((item) => ListTile(
                                title: Text(item.name),
                                subtitle:
                                    Text("${item.quantity} ${item.servings}"),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setModalState(
                                        () => selectedMacroItems.remove(item));
                                  },
                                ),
                              ))
                          .toList(),
                    ),
                  ]
                ],
              ),
              actions: [
                if (result is Meal) ...[
                  // ✅ Meal Handling: Cancel & Add buttons

                  SecondaryButton(
                    text: 'Cancel',
                    press: () => Navigator.pop(context),
                  ),
                  SecondaryButton(
                    text: 'Add',
                    press: () async {
                      final userMeal = UserMeal(
                        name: result.title,
                        quantity: '$selectedNumber',
                        servings: '${unitOptions[selectedUnit]}',
                        calories: result.calories,
                        mealId: mealId,
                      );

                      try {
                        await nutritionController.addUserMeal(
                            userId ?? '', foodType, userMeal);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Meal added successfully."),
                            ),
                          );
                        }
                        Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Failed to add meal: $e")),
                          );
                        }
                      }
                    },
                  ),
                ] else if (result is MacroData || result is IngredientData) ...[
                  SecondaryButton(
                    text: 'Add Another',
                    press: () {
                      final calories = result is MacroData
                          ? result.calories
                          : (result as IngredientData).macros['calories']
                                  is String
                              ? int.tryParse(
                                      (result.macros['calories'] as String)
                                          .replaceAll(RegExp(r'[^0-9]'), '')) ??
                                  0
                              : (result.macros['calories'] as num?)?.toInt() ??
                                  0;

                      final newMacroItem = UserMeal(
                        name: result is MacroData
                            ? result.title
                            : (result as IngredientData).title,
                        quantity: '$selectedNumber',
                        servings: '${unitOptions[selectedUnit]}',
                        calories: calories,
                        mealId: result is MacroData ? result.title : result.id,
                      );

                      setModalState(() => selectedMacroItems.add(newMacroItem));
                    },
                  ),
                  SecondaryButton(
                    text: 'Save',
                    press: () async {
                      if (selectedMacroItems.isEmpty) {
                        // If no items have been added with "Add Another", create one item
                        final calories = result is MacroData
                            ? result.calories
                            : (result as IngredientData).macros['calories']
                                    is String
                                ? int.tryParse((result.macros['calories']
                                            as String)
                                        .replaceAll(RegExp(r'[^0-9]'), '')) ??
                                    0
                                : (result.macros['calories'] as num?)
                                        ?.toInt() ??
                                    0;

                        final singleItem = UserMeal(
                          name: result.name,
                          quantity: '$selectedNumber',
                          servings: '${unitOptions[selectedUnit]}',
                          calories: calories,
                          mealId: result.name,
                        );

                        try {
                          await nutritionController.addUserMeal(
                              userId ?? '', foodType, singleItem);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Item saved successfully!")),
                            );
                          }
                          Navigator.pop(context);
                          return;
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("Failed to save item: $e")),
                            );
                          }
                          return;
                        }
                      }

                      try {
                        for (var macroMeal in selectedMacroItems) {
                          await nutritionController.addUserMeal(
                              userId ?? '', foodType, macroMeal);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("All items saved successfully!"),
                            ),
                          );
                        }
                        Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Failed to save items: $e")),
                          );
                        }
                      }
                    },
                  ),
                ]
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && !_isSearching.value) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 16,
      right: 16,
      top: 25 + 58,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          decoration: BoxDecoration(
            color: getThemeProvider(context).isDarkMode ? kLightGrey : kWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Obx(() {
            if (_isSearching.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    color: kAccent,
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                final bool isApiMeal =
                    result is Meal && result.mealId.startsWith('api_');

                return ListTile(
                  leading: result is Meal && result.mediaPaths.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            result.mediaPaths.isNotEmpty
                                ? result.mediaPaths.first
                                : extPlaceholderImage,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              getAssetImageForItem(
                                  result.category ?? 'default'),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : result is IngredientData && result.mediaPaths.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                result.mediaPaths.first,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                  getAssetImageForItem('default'),
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
                    _showDetailPopup(result, userService.userId, widget.title);
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
      ),
    );
  }

  Widget _buildMealTypeOption(
      String label, String value, bool isSelected, Function(bool) onSelected) {
    return GestureDetector(
      onTap: () => onSelected(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kAccentLight : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kAccentLight : kPrimaryColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? kWhite : kPrimaryColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
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
            // NutritionStatusBar - placed before TabBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: NutritionStatusBar(
                userId: userService.userId ?? '',
                userSettings: userService.currentUser!.settings,
              ),
            ),

            const SizedBox(height: 20),

            // TabBar and TabBarView
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TabBar(
                      labelColor: isDarkMode ? kWhite : kBlack,
                      unselectedLabelColor: kLightGrey,
                      indicatorColor: isDarkMode ? kWhite : kBlack,
                      tabs: const [
                        Tab(icon: Icon(Icons.add)),
                        Tab(icon: Icon(Icons.favorite_border)),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Add Meals/Ingredients Tab
                          Stack(
                            children: [
                              // Main Column (Selected Items List)
                              Column(
                                children: [
                                  const SizedBox(height: 25),
                                  // Search TextField
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: SearchButton2(
                                      controller: _searchController,
                                      onChanged: _filterSearchResults,
                                      kText: 'Search meals or ingredients',
                                    ),
                                  ),
                                  const SizedBox(height: 15),

                                  // Manual Add Button
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kAccent,
                                        minimumSize: const Size(120, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddMealManuallyScreen(
                                              mealType: widget.title,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.add_circle_outline,
                                              color: Colors.white),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Add Meal Manually',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Selected Items List
                                  Expanded(
                                    child: Obx(() {
                                      final allMealsByType = widget.title ==
                                              'Add Food'
                                          ? nutritionController
                                              .userMealList.values
                                              .expand((meals) => meals)
                                              .toList()
                                          : nutritionController
                                                  .userMealList[widget.title] ??
                                              [];

                                      if (allMealsByType.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      return ListView.builder(
                                        itemCount: allMealsByType.length,
                                        itemBuilder: (context, index) {
                                          final userMeal =
                                              allMealsByType[index];

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8.0, horizontal: 8.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: kLightGrey
                                                    .withOpacity(kLowOpacity),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(12.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          userMeal.name,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        IconButton(
                                                          iconSize: 20,
                                                          color: isDarkMode
                                                              ? kLightGrey
                                                              : kWhite.withOpacity(
                                                                  kLowOpacity),
                                                          icon: const Icon(
                                                              Icons.delete),
                                                          onPressed: () async {
                                                            await nutritionController
                                                                .removeMeal(
                                                              userService
                                                                      .userId ??
                                                                  '',
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
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          ('${userMeal.quantity} ${userMeal.servings}'),
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${userMeal.calories} kcal',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w200,
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

                              // Overlay for Search Results
                              if (_searchResults.isNotEmpty ||
                                  _isSearching.value)
                                _buildSearchResults(),
                            ],
                          ),
                          // Favorite Meals Tab
                          FutureBuilder<List<Meal>>(
                            future: mealManager.fetchFavoriteMeals(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator(
                                  color: kAccent,
                                ));
                              } else if (snapshot.hasError) {
                                return Center(
                                    child: Text('Error: ${snapshot.error}'));
                              } else if (!snapshot.hasData ||
                                  snapshot.data!.isEmpty) {
                                return const Center(
                                    child: Text('No favorite meals yet.'));
                              } else {
                                final favoriteMeals = snapshot.data!;
                                return ListView.builder(
                                  itemCount: favoriteMeals.length,
                                  itemBuilder: (context, index) {
                                    final meal = favoriteMeals[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 16.0),
                                      child: GestureDetector(
                                        onTap: () {
                                          _showDetailPopup(
                                              meal,
                                              userid,
                                              widget
                                                  .title); // Pass the Meal object
                                          setState(() {
                                            _searchResults
                                                .clear(); // Clear results after selection
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            // Image
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              child: Image.network(
                                                meal.mediaPaths
                                                    .first, // Replace with your image field
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Image.asset(
                                                  getAssetImageForItem(
                                                      'default'),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16.0),
                                            // Title
                                            Expanded(
                                              child: Text(
                                                meal.title, // Replace with your title field
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
