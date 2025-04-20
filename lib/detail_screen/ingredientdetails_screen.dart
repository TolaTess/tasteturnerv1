import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../screens/recipes_list_category_screen.dart';
import '../widgets/icon_widget.dart';
import '../widgets/premium_widget.dart';
import '../widgets/secondary_button.dart';
import '../widgets/title_section.dart';

class IngredientDetailsScreen extends StatefulWidget {
  final MacroData item;
  final List<MacroData> ingredientItems;
  final bool isRefresh;

  const IngredientDetailsScreen(
      {super.key,
      required this.item,
      required this.ingredientItems,
      this.isRefresh = true});

  @override
  State<IngredientDetailsScreen> createState() =>
      _IngredientDetailsScreenState();
}

class _IngredientDetailsScreenState extends State<IngredientDetailsScreen> {
  bool isHideList = true;
  bool isHideStorage = true;
  bool isHideTechniques = true;
  List<Meal> demoMealsPlanData = [];
  bool? isPremium = false;
  bool isInShoppingList = false;

  @override
  void initState() {
    demoMealsPlanData = mealManager.meals;
    isPremium = userService.currentUser?.isPremium;
    _checkIfItemInShoppingList();
    super.initState();
  }

  Future<void> _checkIfItemInShoppingList() async {
    final List<MacroData> shoppingList =
        await macroManager.fetchMyShoppingList(userService.userId ?? '');

    setState(() {
      isInShoppingList =
          shoppingList.any((item) => item.title == widget.item.title);
    });
  }

  Future<void> _toggleShoppingList() async {
    if (isInShoppingList) {
      await macroManager.removeFromShoppingList(
        userService.userId ?? '',
        widget.item,
      );
      if (mounted) {
        showTastySnackbar(
          'Success',
          '${capitalizeFirstLetter(widget.item.title)} was removed from your Shopping List!',
          context,
        );
      }
    } else {
      await macroManager.addToShoppingList(
        userService.userId ?? '',
        widget.item,
      );
      if (mounted) {
        showTastySnackbar(
          'Success',
          '${capitalizeFirstLetter(widget.item.title)} was added to your Shopping List!',
          context,
        );
      }
    }
    // Refresh the button state
    setState(() {
      isInShoppingList = !isInShoppingList;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const IconCircleButton(
            isRemoveContainer: true,
          ),
        ),
        title: Text(
          capitalizeFirstLetter(widget.item.title),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const SizedBox(
                  height: 1,
                ),

                //image
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    getAssetImageForItem(widget.item.mediaPaths.first),
                    width: getPercentageWidth(70, context),
                    height: getPercentageWidth(70, context),
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(
                  height: 1.5,
                ),
                //macros
                if (widget.item.macros.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      // Convert the map into a formatted string and add calories
                      '${widget.item.macros.entries.map((entry) => '${entry.key.toUpperCase()}: ${entry.value}g').join(', ')}${widget.item.calories != null ? ', KCAL: ${widget.item.calories}' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ),

                //Grams message
                const Text(
                  'per 100 grams',
                  style: TextStyle(
                    fontSize: 11,
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),
                //Techniques
                if (widget.item.techniques.isNotEmpty)
                  SizedBox(
                    height: getPercentageWidth(8, context),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(5),
                      shrinkWrap: true,
                      itemCount: widget.item.techniques.length,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final featureKey = widget.item.techniques[index];
                        return TopFeatures(
                          dataSrc: {featureKey: featureKey},
                          isTechniqie: true,
                        );
                      },
                    ),
                  ),

                if (widget.item.macros.isNotEmpty)
                  const SizedBox(
                    height: 10,
                  ),
                if (widget.item.macros.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                    ),
                    child: Divider(
                      color: isDarkMode ? kWhite : kDarkGrey,
                    ),
                  ),
                if (widget.item.macros.isNotEmpty)
                  const SizedBox(
                    height: 10,
                  ),

                //recipes

                TitleSection(
                  title:
                      "Recipes with ${capitalizeFirstLetter(widget.item.title)}",
                  press: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecipeListCategory(
                          index: 1,
                          searchIngredient: widget.item.title,
                          isFilter: true,
                          screen: 'ingredient',
                        ),
                      ),
                    );
                  },
                  more: seeAll,
                ),
                if (widget.item.features.isNotEmpty)
                  const SizedBox(
                    height: 10,
                  ),
                if (widget.item.features.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                    ),
                    child: Divider(
                      color: isDarkMode ? kWhite : kDarkGrey,
                    ),
                  ),
                if (widget.item.features.isNotEmpty)
                  const SizedBox(
                    height: 10,
                  ),

                //Features
                // Only show this Column if features are not empty
                if (widget.item.features.isNotEmpty)
                  Column(
                    children: [
                      TitleSection(
                        title: "Main Components",
                        press: () {
                          setState(() {
                            isHideList = !isHideList;
                          });
                        }, // Toggle full features
                        more: isHideList ? seeAll : 'Less',
                      ),
                      const SizedBox(height: 10),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: isHideList
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Column(
                          children: [
                            const SizedBox(height: 2.8),
                            // Avatar list
                            SizedBox(
                              height: getPercentageWidth(10, context),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: widget.item.features.length,
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  final featureKey = widget.item.features.keys
                                      .elementAt(index);
                                  final featureValue =
                                      widget.item.features[featureKey];
                                  return TopFeatures(
                                    dataSrc: {featureKey: featureValue},
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                const SizedBox(
                  height: 5,
                ),
                Divider(color: isDarkMode ? kWhite : kDarkGrey),
                const SizedBox(
                  height: 5,
                ),

                //Storage
                // Only show this Column if features are not empty
                if (widget.item.storageOptions.isNotEmpty)
                  Column(
                    children: [
                      TitleSection(
                        title: "Storage Options",
                        press: () {
                          setState(() {
                            isHideStorage = !isHideStorage;
                          });
                        }, // Toggle full features
                        more: isHideStorage ? seeAll : 'Less',
                      ),
                      const SizedBox(height: 10),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: isHideStorage
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Column(
                          children: [
                            const SizedBox(height: 2.8),
                            // Avatar list
                            SizedBox(
                              height: getPercentageWidth(10, context),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: widget.item.storageOptions.length,
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  final featureKey = widget
                                      .item.storageOptions.keys
                                      .elementAt(index);
                                  final featureValue =
                                      widget.item.storageOptions[featureKey];
                                  return TopFeatures(
                                    dataSrc: {featureKey: featureValue},
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                const SizedBox(
                  height: 5,
                ),
                Divider(color: isDarkMode ? kWhite : kDarkGrey),
                const SizedBox(
                  height: 5,
                ),

// ------------------------------------Premium------------------------------------

                isPremium ?? userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : PremiumSection(
                        isPremium: userService.currentUser?.isPremium ?? false,
                        titleOne: joinChallenges,
                        titleTwo: premium,
                        isDiv: false,
                      ),

                isPremium ?? userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : const SizedBox(height: 10),
                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : Divider(color: isDarkMode ? kWhite : kDarkGrey),
                // ------------------------------------Premium------------------------------------

                widget.isRefresh
                    ? const SizedBox(height: 10)
                    : const SizedBox.shrink(),
                //more ingredients
                widget.isRefresh
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "You may also like",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  widget.ingredientItems.shuffle();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? kLightGrey.withOpacity(0.4)
                                        : kLightGrey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    Text(
                                      "Refresh",
                                      style: TextStyle(
                                        color: isDarkMode ? kWhite : kBlack,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Icon(
                                      Icons.refresh_outlined,
                                      size: 17,
                                      color: isDarkMode ? kWhite : kBlack,
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
                widget.isRefresh
                    ? const SizedBox(height: 20)
                    : const SizedBox.shrink(),
                widget.isRefresh
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.3),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 5,
                            crossAxisSpacing: 15,
                            childAspectRatio: 0.55,
                          ),
                          itemCount: widget.ingredientItems.length > 3
                              ? 3
                              : widget.ingredientItems.length,
                          itemBuilder: (BuildContext ctx, index) {
                            return RecomendationItem(
                              dataSrc: widget.ingredientItems[index],
                              press: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        IngredientDetailsScreen(
                                      item: widget.ingredientItems[index],
                                      ingredientItems: const [],
                                      isRefresh: false,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
                widget.isRefresh
                    ? const SizedBox(
                        height: 24,
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: SecondaryButton(
              text: isInShoppingList
                  ? "Remove from Shopping List"
                  : "Add to Shopping List",
              press: _toggleShoppingList,
            ),
          ),
        ]),
      ),
    );
  }
}

//Recomendation Item widget

class RecomendationItem extends StatelessWidget {
  const RecomendationItem({
    super.key,
    required this.dataSrc,
    required this.press,
  });

  final MacroData dataSrc;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              getAssetImageForItem(dataSrc.mediaPaths.first),
              fit: BoxFit.cover,
              height: 160,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            capitalizeFirstLetter(dataSrc.title),
            maxLines: 2,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class TopFeatures extends StatelessWidget {
  const TopFeatures({
    super.key,
    required this.dataSrc,
    this.isTechniqie = false,
  });

  final Map<String, dynamic> dataSrc;
  final bool isTechniqie;

  String _getFeatureDescription(String key, dynamic value) {
    switch (key.toLowerCase()) {
      case 'season':
        return 'Best harvested and consumed during $value season.\nThis is when the ingredient is at its peak freshness and flavor.';
      case 'water':
        return 'Contains $value water content.\nThis affects the ingredient\'s texture, cooking properties, and nutritional density.';
      case 'rainbow':
        return 'Natural color: $value\nColor indicates presence of different phytonutrients and antioxidants.';
      case 'fiber':
        return 'Contains $value fiber content.\nThis affects the ingredient\'s texture, cooking properties, and nutritional density.';
      case 'g_i':
        return 'Glycemic Index: $value\nGlycemic index measures how quickly a food raises blood sugar levels.';
      case 'freezer':
        return 'Store in freezer at $value°F.\nThis helps preserve the ingredient\'s freshness and flavor.';
      case 'fridge':
        return 'Store in refrigerator at $value°F.\nThis helps preserve the ingredient\'s freshness and flavor.';
      case 'countertop':
        return 'Store at room temperature.\nThis helps preserve the ingredient\'s freshness and flavor.';
      default:
        return '$key: $value';
    }
  }

  String _getFeatureIcon(String key) {
    switch (key.toLowerCase()) {
      case 'season':
        return '🌱';
      case 'water':
        return '💧';
      case 'rainbow':
        return '🎨';
      case 'fiber':
        return '⚖️';
      case 'g_i':
        return '🍬';
      case 'freezer':
        return '🧊';
      case 'fridge':
        return '❄️';
      case 'countertop':
        return '🍽️';
      default:
        return '📌';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = dataSrc.entries.first;
    final isDarkMode = getThemeProvider(context).isDarkMode;

    if (isTechniqie) {
      return Row(
        children: [
          Text(
            capitalizeFirstLetter(entry.value),
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: isDarkMode ? kWhite : kBlack,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 20),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: isDarkMode ? kDarkGrey : kWhite,
              title: Row(
                children: [
                  Text(
                    _getFeatureIcon(entry.key),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      color: kAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Text(
                _getFeatureDescription(entry.key, entry.value),
                style: TextStyle(
                  height: 1.5,
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: kAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
      child: entry.value.toString().toLowerCase() == 'na' ||
              entry.value.toString().toLowerCase() == 'all'
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getFeatureIcon(entry.key),
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${capitalizeFirstLetter(entry.key)}: ${capitalizeFirstLetter(entry.value)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
