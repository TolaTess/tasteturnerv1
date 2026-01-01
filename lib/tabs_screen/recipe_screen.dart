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
import '../widgets/ingredient_features.dart';
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
  List<Meal> mealList = [];
  List<Meal> myMealList = [];
  List<Meal> favouriteMealList = [];
  String selectedCategoryId = '';
  List<Map<String, dynamic>> _categoryDatasIngredient = [];
  bool showAllTechniques = false;
  // Cached shuffled techniques to avoid shuffling on every build
  List<Map<String, dynamic>>? _cachedShuffledTechniques;

  @override
  void initState() {
    super.initState();

    try {
      // Initialize techniques with error handling
      if (helperController.macros.isNotEmpty) {
        _categoryDatasIngredient = [...helperController.macros];
        if (_categoryDatasIngredient.isNotEmpty && selectedCategoryId.isEmpty) {
          final firstCategory = _categoryDatasIngredient[0];
          selectedCategoryId = firstCategory['id']?.toString() ?? '';
          selectedCategory = firstCategory['name']?.toString() ?? 'All';
        }
        // Cache shuffled techniques once
        _cachedShuffledTechniques =
            List<Map<String, dynamic>>.from(_categoryDatasIngredient)
              ..shuffle();
      } else {
        _categoryDatasIngredient = [];
        _cachedShuffledTechniques = [];
        debugPrint('Warning: helperController.macros is empty');
      }
    } catch (e) {
      debugPrint('Error initializing techniques: $e');
      _categoryDatasIngredient = [];
      _cachedShuffledTechniques = [];
    }

    try {
      fullLabelsList = macroManager.ingredient;
      mealList = mealManager.meals;
    } catch (e) {
      debugPrint('Error initializing meal/ingredient data: $e');
      fullLabelsList = [];
      mealList = [];
    }

    // Add null check for userId
    final userId = userService.userId;
    if (userId != null && userId.isNotEmpty) {
      myMealList = mealList.where((meal) => meal.userId == userId).toList();
    } else {
      myMealList = [];
    }

    _fetchFavouriteMeals();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only update if category has changed to avoid unnecessary calls
    // Removed duplicate _fetchFavouriteMeals() call - already called in initState
    // _updateIngredientList will be called when category changes
  }

  Future<void> _fetchFavouriteMeals() async {
    if (!mounted) return;

    try {
      final favs = await mealManager.fetchFavoriteMeals();
      if (mounted) {
        setState(() {
          favouriteMealList = favs;
        });
      }
    } catch (e) {
      debugPrint('Error fetching favorite meals: $e');
      if (mounted && context.mounted) {
        showTastySnackbar(
          'Error',
          'Failed to load favorites. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _updateIngredientList(String category) async {
    if (!mounted) return;

    try {
      final ingredients = await macroManager.getIngredientsByCategory(category);
      final favs = await mealManager.fetchFavoriteMeals();

      if (!mounted) return;

      setState(() {
        fullLabelsList = ingredients;
        favouriteMealList = favs;
      });
    } catch (e) {
      debugPrint('Error updating ingredient list: $e');
      if (mounted && context.mounted) {
        showTastySnackbar(
          'Error',
          'Failed to load ingredients. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Filter techniques by diet preference
  List<Map<String, dynamic>> _filterTechniquesByDiet(
      List<Map<String, dynamic>> techniques, String dietPreference) {
    if (dietPreference == 'balanced') {
      return techniques;
    }

    final dietLower = dietPreference.toLowerCase();
    return techniques.where((technique) {
      final bestFor = technique['bestFor'] as List<dynamic>? ?? [];
      return bestFor
          .any((item) => item.toString().toLowerCase().contains(dietLower));
    }).toList();
  }

  /// Get cached shuffled techniques or create new cache if needed
  List<Map<String, dynamic>> _getShuffledTechniques() {
    if (_cachedShuffledTechniques == null ||
        _cachedShuffledTechniques!.isEmpty) {
      _cachedShuffledTechniques =
          List<Map<String, dynamic>>.from(_categoryDatasIngredient)..shuffle();
    }
    return _cachedShuffledTechniques!;
  }

  /// Get techniques filtered by diet, or fallback to top 5 if no matches
  List<Map<String, dynamic>> _getFilteredTechniques(String dietPreference) {
    final shuffledTechniques = _getShuffledTechniques();

    if (dietPreference == 'balanced') {
      return showAllTechniques
          ? shuffledTechniques
          : shuffledTechniques.take(5).toList();
    }

    // Filter by diet preference
    final filteredByDiet =
        _filterTechniquesByDiet(shuffledTechniques, dietPreference);

    // If no techniques match the diet, fallback to all techniques (respecting showAllTechniques)
    if (filteredByDiet.isEmpty) {
      return showAllTechniques
          ? shuffledTechniques
          : shuffledTechniques.take(5).toList();
    }

    return showAllTechniques ? filteredByDiet : filteredByDiet.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final dietPreference =
        userService.currentUser.value?.settings['dietPreference'] ?? 'balanced';

    // Get filtered techniques (by diet if applicable, or top 5 if no matches)
    final limitedTechniques = _getFilteredTechniques(dietPreference);

    // Check if there are techniques matching the diet preference
    final shuffledTechniques = _getShuffledTechniques();
    final dietMatchedTechniques = dietPreference != 'balanced'
        ? _filterTechniquesByDiet(shuffledTechniques, dietPreference)
        : [];
    final shouldShowDietPreference =
        dietPreference != 'balanced' && dietMatchedTechniques.isNotEmpty;

    return RefreshIndicator(
      color: kAccent,
      onRefresh: () async {
        if (!mounted) return;
        try {
          // Refresh all data, not just favorites
          await Future.wait([
            _fetchFavouriteMeals(),
            _updateIngredientList(selectedCategory),
          ]);

          // Also refresh meal lists
          if (mounted) {
            setState(() {
              mealList = mealManager.meals;
              final userId = userService.userId;
              if (userId != null && userId.isNotEmpty) {
                myMealList =
                    mealList.where((meal) => meal.userId == userId).toList();
              } else {
                myMealList = [];
              }
            });
          }
        } catch (e) {
          debugPrint('Error refreshing data: $e');
          if (mounted && context.mounted) {
            showTastySnackbar(
              'Refresh Failed',
              'Unable to refresh data. Please try again.',
              context,
              backgroundColor: Colors.red,
            );
          }
        }
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
                'Chef\'s Tome',
                style: textTheme.displaySmall?.copyWith(
                  fontSize: getTextScale(7, context),
                ),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              const InfoIconWidget(
                title: 'The Cookbook',
                description: 'Curate, Organize, and Master Your Menu',
                details: [
                  {
                    'icon': Icons.search,
                    'title': 'Source & Scout',
                    'description':
                        'Find dishes by available inventory, cuisine type, or dietary specs',
                    'color': kPurple,
                  },
                  {
                    'icon': Icons.favorite,
                    'title': 'Chef\'s Selects',
                    'description':
                        'Pin your signature dishes to the permanent menu',
                    'color': kPurple,
                  },
                  {
                    'icon': Icons.restaurant_menu,
                    'title': 'Set the Line',
                    'description':
                        'Schedule recipes for your weekly service plan',
                    'color': kPurple,
                  },
                  {
                    'icon': Icons.restaurant,
                    'title': 'Refine Technique',
                    'description':
                        'Sharpen your skills with fresh culinary methods',
                    'color': kPurple,
                  },
                ],
                iconColor: kPurple,
                tooltip: 'Cookbook Information',
              ),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                getThemeProvider(context).isDarkMode
                    ? 'assets/images/background/imagedark.jpeg'
                    : 'assets/images/background/imagelight.jpeg',
              ),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                getThemeProvider(context).isDarkMode
                    ? Colors.black.withOpacity(0.5)
                    : Colors.white.withOpacity(0.5),
                getThemeProvider(context).isDarkMode
                    ? BlendMode.darken
                    : BlendMode.lighten,
              ),
            ),
          ),
          child: SafeArea(
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
                            if (shouldShowDietPreference)
                              Text(
                                dietPreference,
                                style: textTheme.displayMedium?.copyWith(),
                              ),
                            if (shouldShowDietPreference)
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Chef\'s Notes',
                                  style: textTheme.displaySmall?.copyWith(
                                    fontSize: getTextScale(6, context),
                                    color: isDarkMode ? kWhite : kBlack,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      showAllTechniques = !showAllTechniques;
                                      // Don't re-shuffle when showing all - just toggle the view
                                      // Re-shuffle only when going back to "Show Less" to provide variety
                                      if (!showAllTechniques &&
                                          _cachedShuffledTechniques != null) {
                                        _cachedShuffledTechniques =
                                            List<Map<String, dynamic>>.from(
                                                _categoryDatasIngredient)
                                              ..shuffle();
                                      }
                                      // Force rebuild to update filtered techniques
                                    });
                                  },
                                  child: Text(
                                    showAllTechniques
                                        ? 'Show Less'
                                        : 'Show All',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: kAccent,
                                      fontSize: getTextScale(3, context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
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
                                  title: technique['name']?.toString() ??
                                      'Unknown Technique',
                                  subtitle:
                                      technique['description']?.toString() ??
                                          'No description available',
                                  color: colors[index % colors.length],
                                  onTap: () {
                                    if (!mounted) return;
                                    try {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            TechniqueDetailWidget(
                                          technique: technique,
                                        ),
                                      );
                                    } catch (e) {
                                      debugPrint(
                                          'Error showing technique dialog: $e');
                                      if (mounted && context.mounted) {
                                        showTastySnackbar(
                                          'Error',
                                          'Unable to show technique details.',
                                          context,
                                          backgroundColor: Colors.red,
                                        );
                                      }
                                    }
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

                  getAdsWidget(
                      userService.currentUser.value?.isPremium ?? false,
                      isDiv: false),

                  // ------------------------------------Premium / Ads-------------------------------------

                  SizedBox(height: getPercentageHeight(1, context)),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IngredientFeatures(
                              items: macroManager.ingredient),
                        ),
                      );
                    },
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: kAccent, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: getPercentageHeight(0.5, context),
                          horizontal: getPercentageWidth(5, context),
                        ),
                        child: Text(
                          'View Walk-In Pantry',
                          style: textTheme.displaySmall?.copyWith(
                            color: kAccent,
                            fontSize: getTextScale(7, context),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: getPercentageHeight(3, context)),

                  //Search by Meals
                  TitleSection(
                    title: searchMeal,
                    press: () {
                      if (!mounted) return;
                      try {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RecipeListCategory(
                              index: 1,
                              searchIngredient: '',
                              screen: 'ingredient',
                            ),
                          ),
                        );
                      } catch (e) {
                        debugPrint(
                            'Error navigating to RecipeListCategory: $e');
                        if (mounted && context.mounted) {
                          showTastySnackbar(
                            'Error',
                            'Unable to open recipe list. Please try again.',
                            context,
                            backgroundColor: Colors.red,
                          );
                        }
                      }
                    },
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
        try {
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
        } catch (e) {
          debugPrint('Error navigating from MealsCard: $e');
          showTastySnackbar(
            'Error',
            'Unable to open recipe list. Please try again.',
            context,
            backgroundColor: Colors.red,
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
