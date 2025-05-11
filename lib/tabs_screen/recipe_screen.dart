import 'dart:async';

import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/ingredient_model.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../widgets/category_selector.dart';
import '../widgets/circle_image.dart';
import '../widgets/ingredient_features.dart';
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
  Timer? _tastyPopupTimer;
  String selectedCategoryId = '';
  final GlobalKey _addSpinButtonKey = GlobalKey();
  List<Map<String, dynamic>> _categoryDatasIngredient = [];
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
    if (_categoryDatasIngredient.isNotEmpty &&
        selectedCategoryId.isEmpty) {
      selectedCategoryId = _categoryDatasIngredient[1]['id'] ?? '';
      selectedCategory = _categoryDatasIngredient[1]['name'] ?? '';
    }
    fullLabelsList = macroManager.ingredient;
    mealList = mealManager.meals;
    myMealList =
        mealList.where((meal) => meal.userId == userService.userId).toList();
    // Show Tasty popup after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddSpinTutorial();
    });
  }

  void _showAddSpinTutorial() {
    tastyPopupService.showTutorialPopup(
      context: context,
      tutorialId: 'add_spin_button',
      message: 'Tap here to spin the wheel for get a spontaneous meal!',
      targetKey: _addSpinButtonKey,
      onComplete: () {
        // Optional: Add any actions to perform after the tutorial is completed
      },
    );
  }

  Future<void> _updateIngredientList(String category) async {
    fullLabelsList = await macroManager.getIngredientsByCategory(category);
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 30,
              ),

              //category options - here is category widget - chatgpt
              CategorySelector(
                categories: _categoryDatasIngredient,
                selectedCategoryId: selectedCategoryId,
                onCategorySelected: _updateCategoryData,
                isDarkMode: isDarkMode,
                accentColor: kAccent,
                darkModeAccentColor: kDarkModeAccent,
              ),
              const SizedBox(
                height: 20,
              ),

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
                  : const SizedBox(height: 10),
              userService.currentUser?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : Divider(color: isDarkMode ? kWhite : kDarkGrey),
              // ------------------------------------Premium / Ads-------------------------------------

              const SizedBox(height: 10),
              //Search by Ingredients
              TitleSection(
                title: searchIngredients,
                press: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IngredientFeatures(
                      items: fullLabelsList,
                      isRecipe: true,
                    ),
                  ),
                ),
                more: seeAll,
              ),
              const SizedBox(
                height: 24,
              ),
              //rows of Ingredients
              IngredientListViewRecipe(
                demoAcceptedData: fullLabelsList.take(10).toList(),
                spin: false,
                isEdit: false,
                onRemoveItem: (int) {},
              ),
              const SizedBox(
                height: 10,
              ),
              Divider(color: isDarkMode ? kWhite : kDarkGrey),

              const SizedBox(
                height: 10,
              ),
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
              const SizedBox(
                height: 20,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 3 / 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: demoMealsData.length,
                  itemBuilder: (BuildContext ctx, index) {
                    return MealsCard(
                      dataSrc: demoMealsData[index],
                      isMyMeal: myMealList.length >= 1,
                    );
                  },
                ),
              ),
              const SizedBox(
                height: 72,
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
  });

  final MealsData dataSrc;
  final bool isMyMeal;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeListCategory(
              index: 1,
              searchIngredient:
                  isMyMeal && dataSrc.title.toLowerCase() == "breakfast"
                      ? 'myMeals'
                      : dataSrc.title,
              isFilter: true,
              screen: 'categories',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
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
              },
              child: Text(
                isMyMeal && dataSrc.title == "Breakfast"
                    ? "My Meals"
                    : dataSrc.title,
                style: const TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  shadows: [
                    Shadow(
                      blurRadius: 15.0,
                      color: kBlack,
                      offset: Offset(3.0, 3.0),
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
                  : dataSrc.subtitle,
              style: const TextStyle(
                color: kWhite,
                shadows: [
                  Shadow(
                    blurRadius: 15.0,
                    color: kBlack,
                    offset: Offset(3.0, 3.0),
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
