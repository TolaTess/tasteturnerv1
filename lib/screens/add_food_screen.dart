import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasteturner/pages/edit_goal.dart';
import 'package:image_picker/image_picker.dart';

import '../constants.dart';
import '../data_models/ingredient_data.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../helper/utils.dart';
import '../helper/helper_functions.dart';
import '../service/food_api_service.dart';
import '../service/meal_api_service.dart';

import '../widgets/daily_routine_list_horizontal.dart';
import '../widgets/ingredient_battle_widget.dart';
import '../widgets/search_button.dart';
import 'createrecipe_screen.dart';
import 'food_analysis_results_screen.dart';

class AddFoodScreen extends StatefulWidget {
  final String title;

  const AddFoodScreen({
    super.key,
    this.title = 'Update Goals',
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

  // Replace the food section maps with meal type maps
  final Map<String, List<UserMeal>> breakfastList = {};
  final Map<String, List<UserMeal>> lunchList = {};
  final Map<String, List<UserMeal>> dinnerList = {};
  final Map<String, List<UserMeal>> snacksList = {};
  bool allDisabled = false;
  bool isInFreeTrial = false;

  // Add this as a class field at the top of the class
  List<UserMeal> _pendingMacroItems = [];

  @override
  void initState() {
    super.initState();

    // Defer the data loading until after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    _getAllDisabled().then((value) {
      if (value) {
        allDisabled = value;
        setState(() {
          allDisabled = value;
        });
      }
    });

    // Calculate free trial status
    final freeTrialDate = userService.currentUser.value?.freeTrialDate;
    final isFreeTrial =
        freeTrialDate != null && DateTime.now().isBefore(freeTrialDate);
    setState(() {
      isInFreeTrial = isFreeTrial;
    });
  }

  Future<bool> _getAllDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('allDisabledKey') ?? false;
  }

  // Check if user can use AI features (premium or free trial)
  bool get _canUseAI {
    final isPremium = userService.currentUser.value?.isPremium ?? false;
    return isPremium || isInFreeTrial;
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
      dailyDataController.listenToDailyData(userId, currentDate);
      // No need for setState() when using GetX reactive state management
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
                      'Add to ${getMealTimeOfDay()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                      SizedBox(width: getPercentageWidth(2, context)),
                      Stack(
                        children: [
                          IconButton(
                            onPressed: () => _handleCameraAction(),
                            icon: Icon(
                              Icons.camera_alt,
                              color: _canUseAI ? null : Colors.grey,
                              size: getIconScale(7, context),
                            ),
                          ),
                          if (!_canUseAI)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
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
    // Check if user can use AI features
    if (!_canUseAI) {
      _showPremiumRequiredDialog();
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: kAccent),
        ),
      );

      // Pick image using the custom image picker
      List<XFile> pickedImages =
          await openMultiImagePickerModal(context: context);

      if (pickedImages.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        return;
      }

      // Crop the first image
      XFile? croppedImage = await cropImage(pickedImages.first, context);
      if (croppedImage == null) {
        Navigator.pop(context); // Close loading dialog
        return;
      }

      // Analyze the image
      final analysisResult = await geminiService.analyzeFoodImageWithContext(
        imageFile: File(croppedImage.path),
      );

      Navigator.pop(context); // Close loading dialog

      // Navigate to results screen for review and editing
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodAnalysisResultsScreen(
            imageFile: File(croppedImage.path),
            analysisResult: analysisResult,
          ),
        ),
      );

      // Refresh the data
      await _loadData();
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorDialog('Analysis failed: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show premium required dialog
  void _showPremiumRequiredDialog() {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Text(
          'Premium Feature',
          style: TextStyle(
            color: isDarkMode ? kWhite : kBlack,
            fontWeight: FontWeight.w600,
            fontSize: getTextScale(4.5, context),
          ),
        ),
        content: Text(
          'AI food analysis is a premium feature. Subscribe to unlock this and many other features!',
          style: TextStyle(
            color:
                isDarkMode ? kWhite.withOpacity(0.8) : kBlack.withOpacity(0.7),
            fontSize: getTextScale(3.5, context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Maybe Later',
              style: TextStyle(
                color: Colors.grey,
                fontSize: getTextScale(3.5, context),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to premium screen
              Navigator.pushNamed(context, '/premium');
            },
            child: Text(
              'Subscribe',
              style: TextStyle(
                color: kAccent,
                fontWeight: FontWeight.w600,
                fontSize: getTextScale(3.5, context),
              ),
            ),
          ),
        ],
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
                                    true),
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
                                  true,
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
                      fontSize: getTextScale(3.5, context),
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
                      fontSize: getTextScale(3.5, context),
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: kAccent,
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        title: Text(
          widget.title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
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
                if (!allDisabled)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
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
                if (!allDisabled)
                  SizedBox(height: getPercentageHeight(2, context)),
                if (!allDisabled) _buildDailyRoutineCard(context),

                SizedBox(height: getPercentageHeight(2, context)),
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

                SizedBox(height: getPercentageHeight(3.5, context)),

                // Water and Steps Trackers
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
                                  settings['waterIntake']?.toString() ?? '0') ??
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
                                  settings['targetSteps']?.toString() ?? '0') ??
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

                Center(
                  child: Text(
                    'Ingredient Tug-of-War',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: getPercentageWidth(4.5, context),
                          fontWeight: FontWeight.w600,
                          color: kAccentLight,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: getPercentageHeight(2, context)),

                // Weekly Ingredients Battle Widget
                const WeeklyIngredientBattle(),

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

                // Selected Items List
                SizedBox(
                  height: MediaQuery.of(context).size.height -
                      getPercentageHeight(
                          30, context), // Fixed height for the list area
                  child: Obx(
                    () => Column(
                      children: [
                        _buildMealCard(
                          context: context,
                          mealType: 'Breakfast',
                          recommendedCalories:
                              _getRecommendedCalories('Breakfast'),
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
                        ),
                        _buildMealCard(
                          context: context,
                          mealType: 'Lunch',
                          recommendedCalories: _getRecommendedCalories('Lunch'),
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
                        ),
                        _buildMealCard(
                          context: context,
                          mealType: 'Dinner',
                          recommendedCalories:
                              _getRecommendedCalories('Dinner'),
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
                        ),
                        _buildMealCard(
                          context: context,
                          mealType: 'Snacks',
                          recommendedCalories:
                              _getRecommendedCalories('Snacks'),
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
                        ),
                      ],
                    ),
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

  String _getRecommendedCalories(String mealType) {
    final settings = userService.currentUser.value?.settings;
    final targetCalories = settings?['targetCalories'] as num? ?? 2000;
    double percentage = 0.0;
    switch (mealType) {
      case 'Breakfast':
        percentage = 0.20;
        break;
      case 'Lunch':
        percentage = 0.35;
        break;
      case 'Dinner':
        percentage = 0.35;
        break;
      case 'Snacks':
        percentage = 0.10;
        break;
    }
    final avg = targetCalories * percentage;
    final min = avg * 0.8;
    final max = avg * 1.2;
    return 'Recommended ${min.round()} - ${max.round()} kcal';
  }

  Widget _buildMealCard({
    required BuildContext context,
    required String mealType,
    required String recommendedCalories,
    required int currentCalories,
    required List<UserMeal> meals,
    required IconData icon,
    required VoidCallback onAdd,
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
            Icon(icon, size: getIconScale(10, context), color: kAccent),
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
                  Text(
                    recommendedCalories,
                    style: textTheme.bodyLarge?.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  if (currentCalories > 0)
                    SizedBox(height: getPercentageHeight(1, context)),
                  if (currentCalories > 0)
                    Text(
                      'Added: $currentCalories kcal',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (meals.isNotEmpty)
                    Padding(
                      padding:
                          EdgeInsets.only(top: getPercentageHeight(1, context)),
                      child: Text(
                        meals.map((e) => e.name).join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
