import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/helper_files.dart';
import '../helper/utils.dart';
import '../screens/buddy_screen.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/category_selector.dart';
import '../widgets/premium_widget.dart';
import 'safe_text_field.dart';
import 'spin_stack.dart';

class SpinWheelPop extends StatefulWidget {
  const SpinWheelPop({
    super.key,
    // required this.macro,
    required this.ingredientList,
    required this.mealList,
    required this.macroList,
    required this.selectedCategory,
    this.customMacro = false,
  });

  final String selectedCategory;
  final List<MacroData> ingredientList;
  final List<Meal> mealList;
  final List<String> macroList;
  final bool customMacro;

  @override
  _SpinWheelPopState createState() => _SpinWheelPopState();
}

class _SpinWheelPopState extends State<SpinWheelPop>
    with SingleTickerProviderStateMixin {
  final TextEditingController customController = TextEditingController();
  List<String> _ingredientList = [];
  List<String> _mealList = [];
  late AudioPlayer _audioPlayer;
  bool _isMuted = false;
  String selectedCategoryMeal = 'all';
  String selectedCategoryIdMeal = '';
  String selectedCategoryIdIngredient = '';
  String selectedCategoryIngredient = 'all';
  bool showIngredientSpin = true; // New state to toggle between modes
  bool _funMode = false;

  List<Map<String, dynamic>> _mealDietCategories = [];
  final GlobalKey _addSpinButtonKey = GlobalKey();
  final GlobalKey _addSwitchButtonKey = GlobalKey();
  bool showDietCategories = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadMuteState();

    // Set default for meal category
    final categoryDatasMeal = helperController.headers;
    if (categoryDatasMeal.isNotEmpty && selectedCategoryIdMeal.isEmpty) {
      selectedCategoryIdMeal = categoryDatasMeal[1]['id'] ?? '';
      selectedCategoryMeal = categoryDatasMeal[1]['name'] ?? '';
    }

    // Set default for meal diet categories
    if (userService.currentUser.value?.familyMode ?? false) {
      _mealDietCategories = [
        ...helperController.category
            .where((category) => category['kidsFriendly'] == true)
      ];
    } else {
      _mealDietCategories = [...helperController.category];
    }

    // Ensure meal list is populated for default category
    _updateMealListByType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddSpinTutorial();
    });
  }

  void _showAddSpinTutorial() {
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'spin_wheel_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'add_switch_button',
          message: 'Tap here to switch view from ingredient to meal spin!',
          targetKey: _addSwitchButtonKey,
          autoCloseDuration: const Duration(seconds: 5),
          arrowDirection: ArrowDirection.UP,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_spin_button',
          message: 'Double tap on the wheel for a spontaneous meal!',
          targetKey: _addSpinButtonKey,
          autoCloseDuration: const Duration(seconds: 5),
          arrowDirection: ArrowDirection.DOWN,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
      ],
    );
  }

  Future<void> _loadMuteState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMuted =
          prefs.getBool('isMuted') ?? false; // Default to false if not set
    });
  }

  Future<void> _saveMuteState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isMuted', _isMuted);
  }

  @override
  void dispose() {
    if (_funMode) {
      customController.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playSound() async {
    if (!_isMuted) {
      await _audioPlayer
          .play(AssetSource('audio/spin.mp3')); // Use a spin-specific sound
    }
  }

  void _stopSound() async {
    await _audioPlayer.stop();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _saveMuteState(); // Save state when toggled
    });
  }

  void _updateCategoryData(String categoryId, String category) {
    if (!mounted) return;
    setState(() {
      selectedCategoryIdMeal = categoryId;
      selectedCategoryMeal = category;
      _updateMealListByType();
    });
  }

  void _updateCategoryIngredientData(String categoryId, String category) async {
    if (!mounted) return;
    setState(() {
      selectedCategoryIdIngredient = categoryId;
      selectedCategoryIngredient = category;
    });
    if (categoryId == 'custom') {
      final result = await showDialog<List<String>>(
        context: context,
        builder: (context) {
          final TextEditingController modalController = TextEditingController();
          final isDarkMode = getThemeProvider(context).isDarkMode;
          final textTheme = Theme.of(context).textTheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            title: Text(
              'Enter Ingredients',
              style: textTheme.titleMedium
                  ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
            ),
            content: SafeTextFormField(
              controller: modalController,
              style: textTheme.bodyMedium
                  ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: "Add your Ingredients (eggs, tuna, etc.)",
                labelStyle: textTheme.bodyMedium
                    ?.copyWith(color: isDarkMode ? kLightGrey : kDarkGrey),
                enabledBorder: outlineInputBorder(10),
                focusedBorder: outlineInputBorder(10),
                border: outlineInputBorder(10),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                ),
              ),
              TextButton(
                onPressed: () {
                  final text = modalController.text;
                  final items = text
                      .split(RegExp(r'[,;\n]'))
                      .map((i) => i.trim())
                      .where((i) => i.isNotEmpty)
                      .toList();
                  _funMode = true;
                  Navigator.pop(context, items);
                },
                child: Text(
                  'Add',
                  style: textTheme.bodyMedium?.copyWith(color: kAccent),
                ),
              ),
            ],
          );
        },
      );
      if (result != null && result.isNotEmpty) {
        setState(() {
          _ingredientList = result;
        });
      }
    } else {
      _updateIngredientListByType();
    }
  }

  void _updateMealListByType() async {
    if (!mounted) return;

    if (selectedCategoryMeal.isEmpty ||
        selectedCategoryMeal.toLowerCase() == 'balanced' ||
        selectedCategoryMeal.toLowerCase() == 'general' ||
        selectedCategoryMeal.toLowerCase() == 'all') {
      setState(() {
        _mealList = widget.mealList.map((meal) => meal.title).take(10).toList();
      });
    } else {
      final newMealList = widget.mealList
          .where((meal) => meal.categories.contains(selectedCategoryMeal))
          .toList();

      setState(() {
        if (newMealList.length > 10) {
          _mealList = newMealList.map((meal) => meal.title).take(10).toList();
        } else {
          _mealList = newMealList.map((meal) => meal.title).toList();
        }
      });
    }
  }

  void _updateIngredientListByType() async {
    if (!mounted) return;

    if (selectedCategoryIngredient.isEmpty ||
        selectedCategoryIngredient == 'all' ||
        selectedCategoryIngredient == 'general') {
      setState(() {
        _ingredientList = widget.ingredientList
            .map((ingredient) => ingredient.title)
            .take(10)
            .toList();
      });
    } else {
      final newIngredientList = widget.ingredientList.where((ingredient) {
        final selectedCategory = selectedCategoryIngredient.toLowerCase();

        // Check if the ingredient type matches or contains the category
        if (ingredient.type.toLowerCase().contains(selectedCategory)) {
          return true;
        }

        // Check if any of the ingredient's categories contain the selected category
        if (ingredient.categories.any(
            (category) => category.toLowerCase().contains(selectedCategory))) {
          return true;
        }

        // Additional checks for common ingredient mappings
        switch (selectedCategory) {
          case 'protein':
            return ingredient.type.toLowerCase().contains('meat') ||
                ingredient.type.toLowerCase().contains('protein') ||
                ingredient.type.toLowerCase().contains('fish') ||
                ingredient.type.toLowerCase().contains('poultry') ||
                ingredient.type.toLowerCase().contains('egg') ||
                ingredient.type.toLowerCase().contains('bean') ||
                ingredient.type.toLowerCase().contains('legume') ||
                ingredient.categories.any((cat) =>
                    cat.toLowerCase().contains('protein') ||
                    cat.toLowerCase().contains('meat') ||
                    cat.toLowerCase().contains('fish'));
          case 'grain':
            return ingredient.type.toLowerCase().contains('grain') ||
                ingredient.type.toLowerCase().contains('cereal') ||
                ingredient.type.toLowerCase().contains('rice') ||
                ingredient.type.toLowerCase().contains('wheat') ||
                ingredient.type.toLowerCase().contains('oat') ||
                ingredient.categories.any((cat) =>
                    cat.toLowerCase().contains('grain') ||
                    cat.toLowerCase().contains('carb'));
          case 'vegetable':
            return ingredient.type.toLowerCase().contains('vegetable') ||
                ingredient.type.toLowerCase().contains('veggie') ||
                ingredient.categories.any((cat) =>
                    cat.toLowerCase().contains('vegetable') ||
                    cat.toLowerCase().contains('veggie'));
          case 'fruit':
            return ingredient.type.toLowerCase().contains('fruit') ||
                ingredient.categories
                    .any((cat) => cat.toLowerCase().contains('fruit'));
          default:
            return false;
        }
      }).toList();

      setState(() {
        if (newIngredientList.length > 10) {
          _ingredientList = newIngredientList
              .map((ingredient) => ingredient.title)
              .take(10)
              .toList();
        } else {
          _ingredientList =
              newIngredientList.map((ingredient) => ingredient.title).toList();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryDatasMeal = helperController.headers;
    final categoryDatasIngredientDiet = _mealDietCategories;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final dietPreference =
        userService.currentUser.value?.settings?['dietPreference'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        toolbarHeight:
            getPercentageHeight(10, context), // Control height with percentage
        title: Text('Don\'t Know What to Eat?', style: textTheme.displayMedium),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(
            () => const TastyScreen(screen: 'message'),
          );
        },
        backgroundColor: kAccentLight,
        child: CircleAvatar(
          backgroundColor: kAccentLight,
          child: Image.asset(
            'assets/images/tasty/tasty.png',
            width: getIconScale(5, context),
            height: getIconScale(5, context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
                SizedBox(height: getPercentageHeight(2, context)),
                Text(
                  'Take a Spin!',
                  style: textTheme.displaySmall?.copyWith(color: kAccent),
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(2, context),
                      ),
                      decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            showIngredientSpin = !showIngredientSpin;
                            if (!showIngredientSpin) {
                              // Switched to meal spin, update meal list
                              _updateMealListByType();
                            }
                          });
                        },
                        child: Text(
                          key: _addSwitchButtonKey,
                          showIngredientSpin
                              ? 'Switch to Meal Spin'
                              : 'Switch to Ingredient Spin',
                          style: textTheme.titleMedium?.copyWith(
                              color: kAccentLight, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: getIconScale(6, context),
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                      ),
                      onPressed: _toggleMute,
                    ),
                  ],
                ),
                Expanded(
                  child: showIngredientSpin
                      ? _buildIngredientSpinView(isDarkMode)
                      : _buildMealSpinView(
                          isDarkMode,
                          categoryDatasMeal,
                          categoryDatasIngredientDiet,
                          textTheme,
                          dietPreference),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientSpinView(bool isDarkMode) {
    return Column(
      children: [
        SizedBox(height: getPercentageHeight(3, context)),

        //category options
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () => _updateCategoryIngredientData('protein', 'protein'),
              child: buildAddMealTypeLegend(
                context,
                'protein',
                isSelected: selectedCategoryIngredient == 'protein',
              ),
            ),
            GestureDetector(
              onTap: () => _updateCategoryIngredientData('grain', 'grain'),
              child: buildAddMealTypeLegend(
                context,
                'grain',
                isSelected: selectedCategoryIngredient == 'grain',
              ),
            ),
            GestureDetector(
              onTap: () =>
                  _updateCategoryIngredientData('vegetable', 'vegetable'),
              child: buildAddMealTypeLegend(
                context,
                'vegetable',
                isSelected: selectedCategoryIngredient == 'vegetable',
              ),
            ),
            GestureDetector(
              onTap: () => _updateCategoryIngredientData('fruit', 'fruit'),
              child: buildAddMealTypeLegend(
                context,
                'fruit',
                isSelected: selectedCategoryIngredient == 'fruit',
              ),
            ),
          ],
        ),

        SizedBox(height: getPercentageHeight(2, context)),
        // Removed custom mode checkbox row
        //const SizedBox(height: 15),
        // Spin wheel below macros
        Expanded(
          child: SpinWheelWidget(
            key: _addSpinButtonKey,
            labels: widget.ingredientList,
            customLabels: _ingredientList.isNotEmpty ? _ingredientList : null,
            isMealSpin: false,
            playSound: _playSound,
            stopSound: _stopSound,
            funMode: _funMode,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSpinView(
      bool isDarkMode,
      List<Map<String, dynamic>> categoryDatas,
      List<Map<String, dynamic>> categoryDatatDiet,
      TextTheme textTheme,
      String dietPreference) {
    return Column(
      children: [
        userService.currentUser.value?.isPremium ?? false
            ? const SizedBox.shrink()
            : SizedBox(height: getPercentageHeight(0.5, context)),

        // ------------------------------------Premium / Ads------------------------------------

        userService.currentUser.value?.isPremium ?? false
            ? const SizedBox.shrink()
            : PremiumSection(
                isPremium: userService.currentUser.value?.isPremium ?? false,
                titleOne: joinChallenges,
                titleTwo: premium,
                isDiv: false,
              ),

        userService.currentUser.value?.isPremium ?? false
            ? const SizedBox.shrink()
            : SizedBox(height: getPercentageHeight(1, context)),

        // ------------------------------------Premium / Ads-------------------------------------
        userService.currentUser.value?.isPremium ?? false
            ? SizedBox(height: getPercentageHeight(2, context))
            : const SizedBox.shrink(),

        Row(
          children: [
            if (dietPreference != null)
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(1.3, context),
                  ),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.2),  
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            selectedCategoryIdMeal = dietPreference;
                            selectedCategoryMeal = dietPreference;
                          });
                          _updateMealListByType();
                        }
                      });
                    },
                    child: Text(
                      dietPreference,
                      style: textTheme.titleMedium?.copyWith(color: kAccent),
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: 3,
              child: CategorySelector(
                categories:
                    showDietCategories ? categoryDatatDiet : categoryDatas,
                selectedCategoryId: selectedCategoryIdMeal,
                onCategorySelected: _updateCategoryData,
                isDarkMode: isDarkMode,
                accentColor: kAccentLight,
                darkModeAccentColor: kDarkModeAccent,
                isFunMode: false,
              ),
            ),
          ],
        ),
        _ingredientList.isEmpty
            ? SizedBox(height: getPercentageHeight(1.5, context))
            : SizedBox(height: getPercentageHeight(1, context)),

        _mealList.isEmpty
            ? const SizedBox(height: 1)
            : SizedBox(height: getPercentageHeight(1.5, context)),

        Expanded(
          child: Center(
            child: _mealList.isEmpty
                ? noItemTastyWidget(
                    "No meals found for ${widget.selectedCategory} ${selectedCategoryMeal}",
                    "",
                    context,
                    false,
                    '',
                  )
                : SpinWheelWidget(
                    mealList: widget.mealList,
                    labels: [], // Empty since we use customLabels
                    customLabels: _mealList,
                    isMealSpin: true,
                    playSound: _playSound,
                    stopSound: _stopSound,
                  ),
          ),
        ),
      ],
    );
  }

  void snackbar(BuildContext context, String mMacro, String category) {
    if (mounted) {
      showTastySnackbar(
        'Please try again.',
        "$mMacro not 2 applicable to the $category",
        context,
      );
    }
  }
}
