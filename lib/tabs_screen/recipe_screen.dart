import 'dart:async';

import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/ingredient_model.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../screens/favorite_screen.dart';
import '../widgets/premium_widget.dart';
import '../widgets/title_section.dart';
import '../screens/recipes_list_category_screen.dart';

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

  @override
  void initState() {
    super.initState();

    _categoryDatasIngredient = [...helperController.macros];
    print(
        'Total items in _categoryDatasIngredient: ${_categoryDatasIngredient.length}');
    print(
        'Techniques found: ${_categoryDatasIngredient.where((item) => item['category'] == 'technique').length}');

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

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Recipes',
          style: TextStyle(fontSize: getTextScale(4, context)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: getPercentageHeight(1, context)),

              // Cooking Techniques Section
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(5, context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${userService.currentUser.value?.settings['dietPreference']} Cooking Techniques',
                          style: TextStyle(
                            fontSize: getTextScale(3.5, context),
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? kWhite : kDarkGrey,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: getPercentageWidth(3, context),
                        mainAxisSpacing: getPercentageHeight(2, context),
                      ),
                      itemCount: _categoryDatasIngredient
                          .where((item) {
                            final categories =
                                item['categories'] as List<dynamic>? ?? [];
                            final userDietPreference = userService.currentUser
                                    .value?.settings['dietPreference']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';
                            return userDietPreference.isEmpty ||
                                categories.any((cat) =>
                                    cat.toString().toLowerCase() ==
                                    userDietPreference);
                          })
                          .take(4)
                          .length,
                      itemBuilder: (context, index) {
                        final filteredItems = _categoryDatasIngredient
                            .where((item) {
                              final categories =
                                  item['categories'] as List<dynamic>? ?? [];
                              final userDietPreference = userService.currentUser
                                      .value?.settings['dietPreference']
                                      ?.toString()
                                      .toLowerCase() ??
                                  '';
                              return userDietPreference.isEmpty ||
                                  categories.any((cat) =>
                                      cat.toString().toLowerCase() ==
                                      userDietPreference);
                            })
                            .take(4)
                            .toList();
                        final technique = filteredItems[index];

                        return Card(
                          elevation: 2,
                          color: isDarkMode ? kDarkGrey : kWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(technique['name'] ?? ''),
                                  content: Text(technique['description'] ??
                                      'No description available'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Circular background for illustration
                                  Container(
                                    width: getPercentageWidth(20, context),
                                    height: getPercentageWidth(20, context),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: kAccentLight.withOpacity(0.2),
                                    ),
                                    child: Icon(
                                      _getTechniqueIcon(
                                          technique['name'] ?? ''),
                                      color: kAccent,
                                      size: getPercentageWidth(10, context),
                                    ),
                                  ),
                                  SizedBox(
                                      height: getPercentageHeight(1, context)),
                                  // Technique name
                                  Text(
                                    (technique['name'] ?? '').toUpperCase(),
                                    style: TextStyle(
                                      color: kAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: getTextScale(2.2, context),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(
                                      height:
                                          getPercentageHeight(0.5, context)),
                                  // Description
                                  Text(
                                    technique['description'] ??
                                        'No description available',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: getTextScale(1.8, context),
                                      color: isDarkMode ? kWhite : kDarkGrey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: getPercentageHeight(2, context)),

              // ------------------------------------Premium / Ads------------------------------------

              userService.currentUser.value?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : PremiumSection(
                      isPremium:
                          userService.currentUser.value?.isPremium ?? false,
                      titleOne: joinChallenges,
                      titleTwo: premium,
                      isDiv: false,
                    ),

              userService.currentUser.value?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : SizedBox(height: getPercentageHeight(1, context)),
              userService.currentUser.value?.isPremium ?? false
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

  IconData _getTechniqueIcon(String technique) {
    switch (technique.toLowerCase()) {
      case 'grilling':
        return Icons.outdoor_grill;
      case 'steaming':
        return Icons.whatshot;
      case 'baking':
        return Icons.cake;
      case 'frying':
        return Icons.restaurant;
      case 'boiling':
        return Icons.water;
      case 'roasting':
        return Icons.local_fire_department;
      default:
        return Icons.restaurant_menu;
    }
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
