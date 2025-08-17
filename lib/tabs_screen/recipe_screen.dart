import 'dart:async';

import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/ingredient_model.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/helper_functions.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import '../screens/favorite_screen.dart';
import '../widgets/title_section.dart';
import '../screens/recipes_list_category_screen.dart';
import '../widgets/card_overlap.dart';
import '../widgets/technique_detail_widget.dart';
import '../widgets/info_icon_widget.dart';

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

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final dietPreference =
        userService.currentUser.value?.settings['dietPreference'];

    // Filter techniques based on user's diet preference
    final filteredTechniques = _categoryDatasIngredient..shuffle();
    final limitedTechniques = filteredTechniques.take(5).toList();

    return RefreshIndicator(
      color: kAccent,
      onRefresh: () async {
        await _fetchFavouriteMeals();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: kAccent,
          automaticallyImplyLeading: true,
          toolbarHeight: getPercentageHeight(10, context),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Recipes',
                style: textTheme.displaySmall?.copyWith(
                  fontSize: getTextScale(7, context),
                ),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              const InfoIconWidget(
                title: 'Recipe Collection',
                description: 'Discover and save healthy recipes',
                details: [
                  {
                    'icon': Icons.search,
                    'title': 'Browse Recipes',
                    'description':
                        'Find recipes by ingredients, cuisine, or diet',
                    'color': kPurple,
                  },
                  {
                    'icon': Icons.favorite,
                    'title': 'Save Favorites',
                    'description': 'Bookmark your favorite recipes',
                    'color': kPurple,
                  },
                  {
                    'icon': Icons.restaurant_menu,
                    'title': 'Meal Planning',
                    'description': 'Add recipes to your weekly meal plan',
                    'color': kPurple,
                  },
                  {
                    'icon': Icons.restaurant,
                    'title': 'Cooking Techniques',
                    'description': 'Learn new cooking methods and skills',
                    'color': kPurple,
                  },
                ],
                iconColor: kPurple,
                tooltip: 'Recipe Information',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: getPercentageHeight(2, context)),

                // Cooking Techniques Section
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(5, context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dietPreference != 'balanced')
                            Text(
                              dietPreference ?? '',
                              style: textTheme.displayMedium?.copyWith(),
                            ),
                          if (dietPreference != 'balanced')
                            SizedBox(height: getPercentageHeight(0.5, context)),
                          Center(
                            child: Text(
                              'Cooking Techniques',
                              style: textTheme.displaySmall?.copyWith(
                                color: kAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: getPercentageHeight(2.5, context)),
                      SizedBox(
                        height: getPercentageHeight(
                            25, context), // Adjust height as needed
                        child: OverlappingCardsView(
                          cardWidth: getPercentageWidth(50, context),
                          cardHeight: getPercentageHeight(20, context),
                          overlap: 50,
                          isRecipe: false,
                          isTechnique: true,
                          children: List.generate(
                            limitedTechniques.length,
                            (index) {
                              final technique = limitedTechniques[index];
                              return OverlappingCard(
                                title: technique['name'] ?? '',
                                subtitle: technique['description'] ??
                                    'No description available',
                                color: colors[index % colors.length],
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => TechniqueDetailWidget(
                                      technique: technique,
                                    ),
                                  );
                                },
                                index: index,
                                isSelected: false,
                                isRecipe: false,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ------------------------------------Premium / Ads------------------------------------

                getAdsWidget(userService.currentUser.value?.isPremium ?? false,
                    isDiv: false),

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
    final textTheme = Theme.of(context).textTheme;

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
                screen: 'categories',
                isNoTechnique: true,
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors[dataSrc.title.hashCode % colors.length],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (dataSrc.image.isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    dataSrc.image,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    colors[dataSrc.title.hashCode % colors.length]
                        .withValues(alpha: 0.8),
                    colors[dataSrc.title.hashCode % colors.length]
                        .withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(4, context),
                vertical: getPercentageHeight(2, context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMyMeal && dataSrc.title == "Breakfast"
                        ? "My Meals"
                        : isFavourite && dataSrc.title == "Lunch"
                            ? "Favourites"
                            : dataSrc.title,
                    style: textTheme.displayMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: isDarkMode ? kWhite : kDarkGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      isMyMeal && dataSrc.title == "Breakfast"
                          ? "View your meals"
                          : isFavourite && dataSrc.title == "Lunch"
                              ? "View your favourites"
                              : dataSrc.subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode
                            ? kWhite.withValues(alpha: 0.7)
                            : kDarkGrey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
}
