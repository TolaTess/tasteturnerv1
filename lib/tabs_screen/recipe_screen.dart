import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tasteturner/detail_screen/recipe_detail.dart';
import '../constants.dart';
import '../data_models/ingredient_model.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../helper/utils.dart';
import '../screens/favorite_screen.dart';
import '../widgets/category_selector.dart';
import '../widgets/circle_image.dart';
import '../widgets/ingredient_features.dart';
import '../widgets/premium_widget.dart';
import '../widgets/title_section.dart';
import '../screens/recipes_list_category_screen.dart';
import '../widgets/goal_diet_widget.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  String selectedCategory = 'All';
  List<MacroData> fullLabelsList = [];
  List<MacroData> availableLabelsList = [];
  final Set<String> headerSet = {};
  List<Meal> mealList = [];
  List<Meal> myMealList = [];
  List<Meal> favouriteMealList = [];
  Timer? _tastyPopupTimer;
  String selectedCategoryId = '';
  List<Map<String, dynamic>> _categoryDatasIngredient = [];
  bool _isLoadingDietGoal = false;
  List<MacroData> _recommendedIngredients = [];
  Meal? _featuredMeal;
  DateTime? _lastPickDate;

  @override
  void initState() {
    super.initState();

    _categoryDatasIngredient = [...helperController.macros];
    final generalCategory = {
      'id': 'general',
      'name': 'General',
      'category': 'General'
    };
    if (_categoryDatasIngredient.isEmpty ||
        _categoryDatasIngredient.first['id'] != 'general') {
      _categoryDatasIngredient.insert(0, generalCategory);
    }
    if (_categoryDatasIngredient.isNotEmpty && selectedCategoryId.isEmpty) {
      selectedCategoryId = _categoryDatasIngredient[0]['id'] ?? '';
      selectedCategory = _categoryDatasIngredient[0]['name'] ?? '';
    }
    fullLabelsList = macroManager.ingredient;
    mealList = mealManager.meals;
    myMealList =
        mealList.where((meal) => meal.userId == userService.userId).toList();

    _fetchFavouriteMeals();
    _pickDietGoalRecommendationsIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchFavouriteMeals();
    _updateIngredientList(selectedCategory);
  }

  Future<void> _fetchFavouriteMeals() async {
    final favs = await mealManager.fetchFavoriteMeals();
    if (mounted) {
      setState(() {
        favouriteMealList = favs;
      });
    }
  }

  Future<void> _updateIngredientList(String category) async {
    fullLabelsList = await macroManager.getIngredientsByCategory(category);
    favouriteMealList = await mealManager.fetchFavoriteMeals();
    for (var item in fullLabelsList) {
      headerSet.addAll(item.features.keys);
    }
  }

  void _updateCategoryData(String categoryId, String category) {
    setState(() {
      selectedCategoryId = categoryId;
      selectedCategory = category;
      _updateIngredientList(category);
    });
  }

  void _pickDietGoalRecommendationsIfNeeded({bool force = false}) {
    final now = DateTime.now();
    if (!force && _recommendedIngredients.isNotEmpty && _lastPickDate != null) {
      final daysSince = now.difference(_lastPickDate!).inDays;
      if (daysSince < 7) return;
    }
    _pickDietGoalRecommendations();
  }

  void _pickDietGoalRecommendations() {
    setState(() {
      _isLoadingDietGoal = true;
    });
    Future.delayed(Duration.zero, () {
      final user = userService.currentUser;
      final String userDiet =
          user?.settings['dietPreference']?.toString() ?? 'Balanced';
      final String userGoal =
          user?.settings['fitnessGoal']?.toString() ?? 'Healthy Eating';
      final allIngredients = macroManager.ingredient;
      final allMeals = mealManager.meals;
      List<MacroData> filteredIngredients = [];
      List<Meal> filteredMeals = [];

      // Logic for filtering based on user diet and goal
      // 1. Filter for items that match the user's diet (category match is required)
      final dietCategory = userDiet.toLowerCase();
      List<MacroData> dietIngredients = allIngredients
          .where((i) =>
              i.categories.any((c) => c.toLowerCase().contains(dietCategory)))
          .toList();
      List<Meal> dietMeals = allMeals
          .where((m) =>
              m.categories.any((c) => c.toLowerCase().contains(dietCategory)))
          .toList();

      // 2. Among those, prefer items that also match the user's goal
      List<MacroData> preferredIngredients = [];
      List<Meal> preferredMeals = [];
      if (userGoal.toLowerCase().contains('weightloss') ||
          userGoal.toLowerCase().contains('lose weight') ||
          userGoal.toLowerCase().contains('weight loss')) {
        preferredIngredients = dietIngredients.where((i) {
          final matchesGoal = i.categories.any((c) =>
              c.toLowerCase().contains('weightloss') ||
              c.toLowerCase().contains('weight loss') ||
              c.toLowerCase().contains('low calorie') ||
              c.toLowerCase().contains('lowcalorie') ||
              c.toLowerCase().contains('diet') ||
              c.toLowerCase().contains('slimming'));
          final carbsStr = i.macros['carbs']?.toString() ?? '';
          final carbs = double.tryParse(carbsStr);
          final isLowCarb = carbs != null ? carbs < 10 : false;
          return matchesGoal && isLowCarb;
        }).toList();
        preferredMeals = dietMeals
            .where((m) => m.categories.any((c) =>
                c.toLowerCase().contains('weightloss') ||
                c.toLowerCase().contains('weight loss') ||
                c.toLowerCase().contains('low calorie') ||
                c.toLowerCase().contains('lowcalorie') ||
                c.toLowerCase().contains('diet') ||
                c.toLowerCase().contains('slimming')))
            .toList();
      } else if (userGoal.toLowerCase().contains('weightgain') ||
          userGoal.toLowerCase().contains('muscle gain') ||
          userGoal.contains('weight gain')) {
        preferredIngredients = dietIngredients.where((i) {
          final matchesGoal = i.categories.any((c) =>
              c.toLowerCase().contains('weightgain') ||
              c.toLowerCase().contains('weight gain') ||
              c.toLowerCase().contains('high calorie') ||
              c.toLowerCase().contains('muscle gain') ||
              c.toLowerCase().contains('bulking') ||
              c.toLowerCase().contains('mass gain'));
          final proteinStr = i.macros['protein']?.toString() ?? '';
          final protein = double.tryParse(proteinStr);
          final isHighProtein = protein != null ? protein > 10 : false;
          return matchesGoal && isHighProtein;
        }).toList();
        preferredMeals = dietMeals
            .where((m) => m.categories.any((c) =>
                c.toLowerCase().contains('weightgain') ||
                c.toLowerCase().contains('weight gain') ||
                c.toLowerCase().contains('high calorie') ||
                c.toLowerCase().contains('muscle gain') ||
                c.toLowerCase().contains('bulking') ||
                c.toLowerCase().contains('mass gain')))
            .toList();
      } else {
        preferredIngredients = dietIngredients;
        preferredMeals = dietMeals;
      }

      // 3. If not enough preferred, fill from diet-matching only
      filteredIngredients = [...preferredIngredients];
      if (filteredIngredients.length < 3) {
        final extra = dietIngredients
            .where((i) => !filteredIngredients.contains(i))
            .toList();
        filteredIngredients.addAll(extra);
      }
      filteredMeals = [...preferredMeals];
      if (filteredMeals.isEmpty) {
        final extra =
            dietMeals.where((m) => !filteredMeals.contains(m)).toList();
        filteredMeals.addAll(extra);
      }

      // 4. Fallbacks if still not enough
      if (filteredIngredients.length < 3) {
        filteredIngredients = allIngredients;
      }
      if (filteredMeals.isEmpty) {
        filteredMeals = allMeals;
      }

      filteredIngredients.shuffle();
      filteredMeals.shuffle();

      setState(() {
        _recommendedIngredients = filteredIngredients.take(3).toList();
        _featuredMeal = filteredMeals.isNotEmpty ? filteredMeals.first : null;
        _lastPickDate = DateTime.now();
        _isLoadingDietGoal = false;
      });
    });
  }

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final user = userService.currentUser;
    final String userDiet =
        user?.settings['dietPreference']?.toString() ?? 'Balanced';
    final String userGoal =
        user?.settings['fitnessGoal']?.toString() ?? 'Healthy Eating';

    return Scaffold(
      appBar: AppBar(
        title: Text('Recipes'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: getPercentageHeight(1, context)),
              _isLoadingDietGoal
                  ? Center(
                      child: Padding(
                      padding: EdgeInsets.all(getPercentageWidth(2, context)),
                      child: const CircularProgressIndicator(
                        color: kAccent,
                      ),
                    ))
                  : GoalDietWidget(
                      diet: userDiet,
                      goal: userGoal,
                      topIngredients: _recommendedIngredients,
                      featuredMeal: _featuredMeal,
                      onIngredientTap: (ingredient) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IngredientDetailsScreen(
                              item: ingredient,
                              ingredientItems: fullLabelsList,
                            ),
                          ),
                        );
                      },
                      onMealTap: (meal) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailScreen(
                              mealData: meal,
                              screen: 'recipe',
                            ),
                          ),
                        );
                      },
                      onRefresh: _isLoadingDietGoal
                          ? null
                          : () =>
                              _pickDietGoalRecommendationsIfNeeded(force: true),
                    ),
              SizedBox(height: getPercentageHeight(2, context)),

              // ------------------------------------Premium / Ads------------------------------------

              userService.currentUser?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : PremiumSection(
                      isPremium: userService.currentUser?.isPremium ?? false,
                      titleOne: joinChallenges,
                      titleTwo: premium,
                      isDiv: false,
                    ),

              userService.currentUser?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : SizedBox(height: getPercentageHeight(1, context)),
              userService.currentUser?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : Divider(color: isDarkMode ? kWhite : kDarkGrey),
              // ------------------------------------Premium / Ads-------------------------------------

              SizedBox(height: getPercentageHeight(1, context)),

              //Search by Meals
              TitleSection(
                title: searchMeal,
                press: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecipeListCategory(
                      index: 1,
                      searchIngredient: '',
                      screen: 'ingredient',
                    ),
                  ),
                ),
                more: seeAll,
              ),
              SizedBox(
                height: getPercentageHeight(2, context),
              ),

              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(5, context)),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: getPercentageWidth(45, context),
                    childAspectRatio: 3 / 2,
                    crossAxisSpacing: getPercentageWidth(2, context),
                    mainAxisSpacing: getPercentageHeight(1, context),
                  ),
                  itemCount: demoMealsData.length,
                  itemBuilder: (BuildContext ctx, index) {
                    return MealsCard(
                      dataSrc: demoMealsData[index],
                      isMyMeal: myMealList.length >= 1,
                      isFavourite: favouriteMealList.length >= 1,
                    );
                  },
                ),
              ),
              SizedBox(
                height: getPercentageHeight(7, context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//Meals Card Widget
class MealsCard extends StatelessWidget {
  const MealsCard({
    super.key,
    required this.dataSrc,
    required this.isMyMeal,
    required this.isFavourite,
  });

  final MealsData dataSrc;
  final bool isMyMeal;
  final bool isFavourite;
  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return GestureDetector(
      onTap: () {
        if (isFavourite && dataSrc.title == "Lunch") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FavoriteScreen(),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeListCategory(
                index: 1,
                searchIngredient: isMyMeal && dataSrc.title == "Breakfast"
                    ? "myMeals"
                    : dataSrc.title,
                isFilter: true,
                screen: 'categories',
              ),
            ),
          );
        }
      },
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: getPercentageWidth(1, context)),
        // Image + Shade
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          image: DecorationImage(
            opacity: isDarkMode ? 0.3 : 1,
            image: AssetImage(dataSrc.image),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDarkMode ? kBlack.withOpacity(0.15) : kBlack.withOpacity(0.3),
              BlendMode.darken,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title
            GestureDetector(
              onTap: () {
                if (isFavourite && dataSrc.title == "Lunch") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoriteScreen(),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeListCategory(
                        index: 1,
                        searchIngredient:
                            isMyMeal && dataSrc.title == "Breakfast"
                                ? "myMeals"
                                : dataSrc.title,
                        isFilter: true,
                        screen: 'categories',
                      ),
                    ),
                  );
                }
              },
              child: Text(
                isMyMeal && dataSrc.title == "Breakfast"
                    ? "My Meals"
                    : isFavourite && dataSrc.title == "Lunch"
                        ? "Favourites"
                        : dataSrc.title,
                style: TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: getTextScale(4, context),
                  shadows: [
                    Shadow(
                      blurRadius: getPercentageWidth(1.5, context),
                      color: kBlack,
                      offset: Offset(getPercentageWidth(0.3, context),
                          getPercentageWidth(0.3, context)),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Subtitle
            Text(
              isMyMeal && dataSrc.title == "Breakfast"
                  ? "View your meals"
                  : isFavourite && dataSrc.title == "Lunch"
                      ? "View your favourites"
                      : dataSrc.subtitle,
              style: TextStyle(
                color: kWhite,
                fontSize: getTextScale(3, context),
                shadows: [
                  Shadow(
                    blurRadius: getPercentageWidth(1.5, context),
                    color: kBlack,
                    offset: Offset(getPercentageWidth(0.3, context),
                        getPercentageWidth(0.3, context)),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
