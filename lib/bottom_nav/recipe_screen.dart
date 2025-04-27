import 'dart:async';

import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/ingredient_model.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';
import '../widgets/category_selector.dart';
import '../widgets/circle_image.dart';
import '../widgets/bottom_model.dart';
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
  Timer? _tastyPopupTimer;
  String selectedCategoryId = '';
  final GlobalKey _addSpinButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    fullLabelsList = macroManager.ingredient;
    mealList = mealManager.meals;
    // Show Tasty popup after a short delay

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddSpinTutorial();
    });
  }

  void _showAddSpinTutorial() {
    tastyPopupService.showTutorialPopup(
      context: context,
      tutorialId: 'add_spin_button',
      message:
          'Tap here to spin the wheel for get a spontaneous meal!',
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
    final headers = helperController.category;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Ingredients and Recipes",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 25,
              ),

              //category options - here is category widget - chatgpt
              CategorySelector(
                categories: headers,
                selectedCategoryId: selectedCategoryId,
                onCategorySelected: _updateCategoryData,
                isDarkMode: isDarkMode,
                accentColor: kAccent,
                darkModeAccentColor: kDarkModeAccent,
              ),
              const SizedBox(
                height: 20,
              ),

              const Center(
                child: Text(
                  searchSpinning,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(
                height: 15,
              ),

              //Spin the wheel options
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: SizedBox(
                  height: getPercentageHeight(22, context),
                  child: GridView.builder(
                    key: _addSpinButtonKey,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      mainAxisExtent: 212,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: demoMacroData.length,
                    itemBuilder: (BuildContext ctx, index) {
                      return Padding(
                        padding: EdgeInsets.only(
                            left: getPercentageWidth(4.5, context)),
                        child: InkWell(
                          onTap: () async {
                            final isPresent =
                                await macroManager.isMacroTypePresent(
                                    fullLabelsList, demoMacroData[index].title);
                            if (isPresent) {
                              final uniqueTypes = await macroManager
                                  .getUniqueTypes(fullLabelsList);
                              showSpinWheel(
                                context,
                                demoMacroData[index].title,
                                fullLabelsList,
                                mealList,
                                uniqueTypes,
                                selectedCategory,
                                false,
                              );
                            } else {
                              if (mounted) {
                                showTastySnackbar(
                                  'Please try again.',
                                  "${demoMacroData[index].title} not applicable to the $selectedCategory",
                                  context,
                                );
                              }
                            }
                          },
                          child: MacroItemWidget(
                            dataSrc: demoMacroData[index],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Divider(color: isDarkMode ? kWhite : kDarkGrey),
              const SizedBox(height: 5),

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

class FoodCategoryItem extends StatelessWidget {
  const FoodCategoryItem({
    super.key,
    required this.dataSrc,
    required this.themeProvider,
  });

  final FoodCategoryData dataSrc;
  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      //image + shade
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        image: DecorationImage(
          opacity: themeProvider.isDarkMode ? 0.3 : 1,
          image: AssetImage(
            dataSrc.image,
          ),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            kBlack.withOpacity(0.3),
            BlendMode.darken,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          //title
          Text(
            dataSrc.title,
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
          //subtitle
          Text(
            dataSrc.subtitle,
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
    );
  }
}

class MacroItemWidget extends StatelessWidget {
  const MacroItemWidget({
    super.key,
    required this.dataSrc,
  });

  final MacroType dataSrc;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            dataSrc.image,
            fit: BoxFit.cover,
            height: 150,
          ),
        ),
        const SizedBox(
          height: 2,
        ),
        Text(
          dataSrc.title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
          ),
        ),
      ],
    );
  }
}

//Meals Card Widget

class MealsCard extends StatelessWidget {
  const MealsCard({
    super.key,
    required this.dataSrc,
  });

  final MealsData dataSrc;

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
              searchIngredient: dataSrc.title,
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
                      searchIngredient: dataSrc.title,
                      isFilter: true,
                      screen: 'categories',
                    ),
                  ),
                );
              },
              child: Text(
                dataSrc.title,
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
              dataSrc.subtitle,
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
