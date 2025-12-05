import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../screens/recipes_list_category_screen.dart';
import '../widgets/icon_widget.dart';
import '../widgets/premium_widget.dart';
import '../widgets/primary_button.dart';
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
  late List<MacroData> _displayIngredientItems;

  @override
  void initState() {
    demoMealsPlanData = mealManager.meals;
    isPremium = userService.currentUser.value?.isPremium;
    _checkIfItemInShoppingList();
    // Make a local copy of ingredientItems for shuffling
    _displayIngredientItems = List<MacroData>.from(widget.ingredientItems);
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
          userService.userId ?? '', widget.item);
      if (mounted) {
        showTastySnackbar(
          'Success',
          '${capitalizeFirstLetter(widget.item.title)} was removed from your Shopping List!',
          context,
        );
      }
    } else {
      await macroManager.saveShoppingList([widget.item]);
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
    final imagePath = widget.item.mediaPaths.isNotEmpty
        ? widget.item.mediaPaths.first
        : widget.item.type.isNotEmpty
            ? widget.item.type.toLowerCase()
            : intPlaceholderImage;
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Get.back(),
          child: const IconCircleButton(
            isRemoveContainer: true,
          ),
        ),
        title: Text(
          capitalizeFirstLetter(widget.item.title),
          style: TextStyle(
            fontSize: getTextScale(5, context),
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
                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                //image
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    getAssetImageForItem(imagePath),
                    width: getPercentageWidth(70, context),
                    height: getPercentageWidth(70, context),
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(
                  height: getPercentageHeight(1.5, context),
                ),
                //macros
                if (widget.item.macros.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      // Convert the map into a formatted string and add calories
                      '${widget.item.macros.entries.map((entry) => '${entry.key.toUpperCase()}: ${entry.value}g').join(', ')}${widget.item.calories > 0 ? ', KCAL: ${widget.item.calories}' : ''}',
                      style: TextStyle(
                        fontSize: getTextScale(2.5, context),
                      ),
                    ),
                  ),
                SizedBox(height: getPercentageHeight(0.5, context)),

                //Grams message
                Text(
                  'per 100 grams',
                  style: TextStyle(
                    fontSize: getTextScale(2, context),
                  ),
                ),

                SizedBox(
                  height: getPercentageHeight(0.5, context),
                ),

                // Key characteristics subtitle
                if (_hasKeyCharacteristics())
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(5, context)),
                    child: Text(
                      _buildKeyCharacteristicsSubtitle(),
                      style: TextStyle(
                        fontSize: getTextScale(3, context),
                        fontStyle: FontStyle.italic,
                        color: isDarkMode ? kWhite.withValues(alpha: 0.8) : kDarkGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  const SizedBox.shrink(),

                SizedBox(
                  height: getPercentageHeight(1.5, context),
                ),

                // Turner's Notes Section
                if (_hasKeyCharacteristics())
                  _buildTurnersNotes(context, isDarkMode),

                if (_hasKeyCharacteristics())
                  SizedBox(
                    height: getPercentageHeight(1, context),
                ),
                //Techniques
                if (widget.item.techniques.isNotEmpty)
                  SizedBox(
                    height: getPercentageWidth(10, context),
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
                  SizedBox(
                    height: getPercentageHeight(0.8, context),
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
                  SizedBox(
                    height: getPercentageHeight(1, context),
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
                          screen: 'ingredient',
                          isBack: true,
                          isNoTechnique: true,
                        ),
                      ),
                    );
                  },
                  more: seeAll,
                ),
                if (widget.item.features.isNotEmpty)
                  SizedBox(
                    height: getPercentageHeight(1, context),
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
                  SizedBox(
                    height: getPercentageHeight(1, context),
                  ),

                //Features
                // Only show this Column if features are not empty
                if (widget.item.features.isNotEmpty)
                  Column(
                    children: [
                      TitleSection(
                        title: "Specs",
                        press: () {
                          setState(() {
                            isHideList = !isHideList;
                          });
                        }, // Toggle full features
                        more: isHideList ? seeAll : 'Less',
                      ),
                      SizedBox(height: getPercentageHeight(1, context)),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: isHideList
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Column(
                          children: [
                            SizedBox(height: getPercentageHeight(0.5, context)),
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
                SizedBox(
                  height: getPercentageHeight(0.5, context),
                ),
                Divider(color: isDarkMode ? kWhite : kDarkGrey),
                SizedBox(
                  height: getPercentageHeight(0.5, context),
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
                      SizedBox(height: getPercentageHeight(1, context)),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: isHideStorage
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Column(
                          children: [
                            SizedBox(height: getPercentageHeight(0.5, context)),
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
                SizedBox(
                  height: getPercentageHeight(0.5, context),
                ),
                Divider(color: isDarkMode ? kWhite : kDarkGrey),
                SizedBox(
                  height: getPercentageHeight(0.5, context),
                ),

// ------------------------------------Premium------------------------------------

                isPremium ?? userService.currentUser.value?.isPremium ?? false
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
                    : Divider(color: isDarkMode ? kWhite : kDarkGrey),
                // ------------------------------------Premium------------------------------------
                SizedBox(height: getPercentageHeight(1, context)),
                widget.isRefresh
                    ? SizedBox(height: getPercentageHeight(1, context))
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
                            Text(
                              "You may also like",
                              style: TextStyle(
                                fontSize: getTextScale(4, context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _displayIngredientItems.shuffle();
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(1, context),
                                  vertical: getPercentageHeight(0.2, context),
                                ),
                                decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? kLightGrey.withValues(alpha: 0.4)
                                        : kLightGrey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    Text(
                                      "Refresh",
                                      style: TextStyle(
                                        color: isDarkMode ? kWhite : kBlack,
                                        fontSize: getTextScale(3, context),
                                      ),
                                    ),
                                    Icon(
                                      Icons.refresh_outlined,
                                      size: getPercentageWidth(2.5, context),
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
                    ? SizedBox(height: getPercentageHeight(2, context))
                    : const SizedBox.shrink(),
                widget.isRefresh
                    ? Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(0.5, context)),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: getPercentageWidth(1, context),
                            childAspectRatio: 0.5,
                          ),
                          itemCount: _displayIngredientItems.length > 3
                              ? 3
                              : _displayIngredientItems.length,
                          itemBuilder: (BuildContext ctx, index) {
                            return RecomendationItem(
                              dataSrc: _displayIngredientItems[index],
                              press: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        IngredientDetailsScreen(
                                      item: _displayIngredientItems[index],
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
                    ? SizedBox(
                        height: getPercentageHeight(2.4, context),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.symmetric(
          vertical: getPercentageHeight(1.5, context),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: AppButton(
              text: isInShoppingList
                  ? "Remove from Shopping List"
                  : "Add to Shopping List",
              onPressed: _toggleShoppingList,
              type: AppButtonType.primary,
              width: 100,
            ),
          ),
        ]),
      ),
    );
  }

  // Check if item has key characteristics to display
  bool _hasKeyCharacteristics() {
    return widget.item.features.containsKey('g_i') ||
        widget.item.features.containsKey('fiber') ||
        widget.item.features.containsKey('season') ||
        widget.item.features.containsKey('rainbow');
  }

  // Build key characteristics subtitle
  String _buildKeyCharacteristicsSubtitle() {
    List<String> parts = [];
    
    // Burn Rate
    if (widget.item.features.containsKey('g_i')) {
      final giValue = widget.item.features['g_i']?.toString() ?? '';
      final chefTerm = getChefTermForFeature('g_i', giValue);
      parts.add(chefTerm);
    }
    
    // Satiety
    if (widget.item.features.containsKey('fiber')) {
      final fiberValue = widget.item.features['fiber']?.toString() ?? '';
      final chefTerm = getChefTermForFeature('fiber', fiberValue);
      if (chefTerm == 'Light') {
        parts.add('Light Texture');
      } else if (chefTerm == 'Medium Body') {
        parts.add('Medium Satiety');
      } else if (chefTerm == 'Dense') {
        parts.add('High Satiety');
      } else {
        parts.add(chefTerm);
      }
    }
    
    // Seasonality
    if (widget.item.features.containsKey('season')) {
      final season = widget.item.features['season']?.toString() ?? '';
      if (isCurrentlyInSeason(season)) {
        parts.add('Peak Season');
      }
    }
    
    return parts.isEmpty ? '' : parts.join(' • ');
  }

  // Build Turner's Notes section
  Widget _buildTurnersNotes(BuildContext context, bool isDarkMode) {
    List<String> notes = [];
    
    // Seasonality note
    if (widget.item.features.containsKey('season')) {
      final season = widget.item.features['season']?.toString() ?? '';
      if (isCurrentlyInSeason(season)) {
        notes.add('It\'s currently **In Season**.');
      } else if (season.toLowerCase().contains('all-year') ||
          season.toLowerCase().contains('year-round')) {
        notes.add('Year-round staple.');
      }
    }
    
    // Burn Rate note
    if (widget.item.features.containsKey('g_i')) {
      final giValue = widget.item.features['g_i']?.toString() ?? '';
      final chefTerm = getChefTermForFeature('g_i', giValue);
      if (chefTerm == 'Slow Burn') {
        notes.add('This offers a **Slow Burn** energy release, perfect for sustained work shifts.');
      } else if (chefTerm == 'Fast Burn') {
        notes.add('**Fast Burn** energy release for quick fuel.');
      }
    }
    
    // Satiety note
    if (widget.item.features.containsKey('fiber')) {
      final fiberValue = widget.item.features['fiber']?.toString() ?? '';
      final chefTerm = getChefTermForFeature('fiber', fiberValue);
      if (chefTerm == 'Dense') {
        notes.add('High **Satiety** score keeps hunger down.');
      } else if (chefTerm == 'Light') {
        notes.add('Light texture, easy to digest.');
      }
    }
    
    // Rainbow/Plating note
    if (widget.item.features.containsKey('rainbow')) {
      final rainbowValue = widget.item.features['rainbow']?.toString() ?? '';
      notes.add('Perfect for **${capitalizeFirstLetter(rainbowValue)}** plating aesthetics.');
    }
    
    if (notes.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(5, context)),
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Turner\'s Notes',
                style: TextStyle(
                  fontSize: getTextScale(4.5, context),
                  fontWeight: FontWeight.w700,
                  color: kAccent,
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          ...notes.map((note) => Padding(
                padding: EdgeInsets.only(bottom: getPercentageHeight(0.5, context)),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: getTextScale(3.5, context),
                      fontStyle: FontStyle.italic,
                      color: isDarkMode ? kWhite : kBlack,
                      height: 1.5,
                    ),
                    children: _parseTurnerNote(note),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // Parse Turner's note to highlight key terms
  List<TextSpan> _parseTurnerNote(String note) {
    final parts = note.split('**');
    List<TextSpan> spans = [];
    
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // Regular text
        spans.add(TextSpan(text: parts[i]));
      } else {
        // Bold text (key term)
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: kAccent,
          ),
        ));
      }
    }
    
    return spans;
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
    final imagePath = dataSrc.mediaPaths.isNotEmpty
        ? dataSrc.mediaPaths.first
        : 'placeholder';
    return GestureDetector(
      onTap: press,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              getAssetImageForItem(imagePath),
              fit: BoxFit.cover,
              height: getPercentageHeight(16, context),
            ),
          ),
          SizedBox(
            height: getPercentageHeight(1, context),
          ),
          Text(
            capitalizeFirstLetter(dataSrc.title),
            maxLines: 2,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: getTextScale(3, context),
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
              fontSize: getTextScale(4.5, context),
            ),
          ),
          SizedBox(width: getPercentageWidth(2, context)),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        showFeatureDialog(context, isDarkMode, entry.key, entry.value);
      },
      child: entry.value.toString().toLowerCase() == 'na' ||
              entry.value.toString().toLowerCase() == 'all'
          ? const SizedBox.shrink()
          : Container(
              margin: EdgeInsets.only(right: getPercentageWidth(1, context)),
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(1.2, context),
                  vertical: getPercentageHeight(0.8, context)),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    getFeatureIcon(entry.key),
                    style: TextStyle(
                      fontSize: getTextScale(3.5, context),
                    ),
                  ),
                  SizedBox(width: getPercentageWidth(0.4, context)),
                  Text(
                    _getChefDisplayText(entry.key, entry.value),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? kWhite : kBlack,
                      fontSize: getTextScale(3.5, context),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Get chef terminology display text for features
  String _getChefDisplayText(String key, dynamic value) {
    final valueStr = value?.toString() ?? '';
    
    // Map feature keys to chef terminology labels
    String label;
    switch (key.toLowerCase()) {
      case 'rainbow':
        label = 'Spectrum';
        break;
      case 'g_i':
      case 'gi':
        label = 'Burn Rate';
        break;
      case 'season':
        label = 'Market Status';
        break;
      case 'fiber':
        label = 'Texture / Satiety';
        break;
      default:
        label = capitalizeFirstLetter(key);
    }
    
    // Get chef term for value
    final chefValue = getChefTermForFeature(key, valueStr);
    
    // Add visual indicator emoji
    String emoji = '';
    if (key.toLowerCase() == 'g_i' || key.toLowerCase() == 'gi') {
      final numericValue = _extractNumericValueFromString(valueStr);
      if (numericValue != null) {
        if (numericValue < 55) {
          emoji = ' 📉';
        } else if (numericValue < 70) {
          emoji = ' ⚡';
        } else {
          emoji = ' 🔥';
        }
      } else if (chefValue.toLowerCase().contains('slow')) {
        emoji = ' 📉';
      } else if (chefValue.toLowerCase().contains('fast')) {
        emoji = ' 🔥';
      }
    } else if (key.toLowerCase() == 'fiber') {
      if (chefValue == 'Dense') {
        emoji = ' ⚖️';
      } else if (chefValue == 'Light') {
        emoji = ' ⚡';
      }
    } else if (key.toLowerCase() == 'season') {
      if (isCurrentlyInSeason(valueStr)) {
        emoji = ' 🌱';
      } else {
        emoji = ' 📅';
      }
    } else if (key.toLowerCase() == 'rainbow') {
      // Add colored dot emoji based on color
      final color = getRainbowColor(valueStr);
      if (color == Colors.red) emoji = ' 🔴';
      else if (color == Colors.orange) emoji = ' 🟠';
      else if (color == Colors.yellow) emoji = ' 🟡';
      else if (color == Colors.green) emoji = ' 🟢';
      else if (color == Colors.blue) emoji = ' 🔵';
      else if (color == Colors.purple) emoji = ' 🟣';
      else if (color == Colors.white) emoji = ' ⚪';
    }
    
    return '$label: $chefValue$emoji';
  }

  // Helper to extract numeric value from string
  double? _extractNumericValueFromString(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll('g', '')
        .replaceAll('%', '')
        .replaceAll(' ', '')
        .trim();
    
    try {
      return double.parse(cleaned);
    } catch (e) {
      return null;
    }
  }
}
