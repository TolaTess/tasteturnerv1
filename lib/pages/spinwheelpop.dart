import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../widgets/category_selector.dart';
import '../widgets/icon_widget.dart';
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
  bool _isExpanded = false;
  List<String> _ingredientList = [];
  List<String> _mealList = [];
  late AudioPlayer _audioPlayer;
  bool _isMuted = false;
  String selectedCategoryMeal = 'Balanced';
  String selectedCategoryIdMeal = '';
  String selectedCategoryIdIngredient = '';
  String selectedCategoryIngredient = 'all';
  bool showIngredientSpin = true; // New state to toggle between modes

  @override
  void initState() {
    super.initState();
    _fetchMeals(); // Load meals for Meal Spin mode
    _audioPlayer = AudioPlayer();
    _loadMuteState();
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
    customController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _updateIngredientList() {
    _isExpanded = false;
    if (customController.text.isNotEmpty) {
      List<String> ingredients = customController.text
          .split(RegExp(r'[,;\n]'))
          .map((ingredient) => ingredient.trim())
          .where((ingredient) => ingredient.isNotEmpty)
          .toList();
      setState(() {
        _ingredientList = ingredients;
      });
    }
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

  void _updateCategoryIngredientData(String categoryId, String category) {
    if (!mounted) return;
    setState(() {
      selectedCategoryIdIngredient = categoryId;
      selectedCategoryIngredient = category;
      _updateIngredientListByType();
    });
  }

  void _updateMealListByType() async {
    if (!mounted) return;

    if (selectedCategoryMeal == 'Balanced') {
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

    if (selectedCategoryIngredient == 'all') {
      setState(() {
        _ingredientList = widget.ingredientList.map((ingredient) => ingredient.title).take(10).toList();
      });
    } else {
      final newIngredientList = widget.ingredientList
          .where((ingredient) => ingredient.categories.contains(selectedCategoryIngredient.toLowerCase()))
          .toList();

      setState(() {
        if (newIngredientList.length > 10) {
          _ingredientList = newIngredientList.map((ingredient) => ingredient.title).take(10).toList();
        } else {    
          _ingredientList = newIngredientList.map((ingredient) => ingredient.title).toList();
        }
      });
    } 
  }

  Future<void> _fetchMeals() async {
    final meals =
        await mealManager.fetchMealsByCategory(widget.selectedCategory);
    setState(() {
      _mealList = meals.map((meal) => meal.title).toList().take(10).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryDatasMeal = helperController.headers;
    final categoryDatasIngredient = helperController.category;
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Scaffold(
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          showIngredientSpin = !showIngredientSpin;
                        });
                      },
                      child: Text(
                        showIngredientSpin
                            ? 'Switch to Meal Spin'
                            : 'Switch to Ingredient Spin',
                        style: TextStyle(
                            fontSize: 18, color: isDarkMode ? kWhite : kAccent),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                      onPressed: _toggleMute,
                    ),
                  ],
                ),
                Expanded(
                  child: showIngredientSpin
                      ? _buildIngredientSpinView(
                          isDarkMode, categoryDatasIngredient)
                      : _buildMealSpinView(isDarkMode, categoryDatasMeal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientSpinView(
      bool isDarkMode, List<Map<String, dynamic>> categoryDatas) {
    return Column(
      children: [
        const SizedBox(height: 20),
        //category options
        CategorySelector(
          categories: categoryDatas,
          selectedCategoryId: selectedCategoryIdIngredient,
          onCategorySelected: _updateCategoryIngredientData,
          isDarkMode: isDarkMode,
          accentColor: kAccent,
          darkModeAccentColor: kDarkModeAccent,
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: isDarkMode
                ? kLightGrey
                : kAccent.withValues(alpha: kMidOpacity),
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextButton(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            child: Text(
              _isExpanded ? "Hide Input" : "Add Your Ingredients",
              style:
                  TextStyle(fontSize: 16, color: isDarkMode ? kWhite : kBlack),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isExpanded ? 100 : 0,
          curve: Curves.easeInOut,
          child: _isExpanded
              ? Row(
                  children: [
                    const SizedBox(width: 10),
                    Expanded(
                      child: SafeTextFormField(
                        controller: customController,
                        style:
                            TextStyle(color: isDarkMode ? kWhite : kDarkGrey),
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: "Add your Ingredients (eggs, tuna, etc.)",
                          labelStyle: TextStyle(
                              color: isDarkMode ? kLightGrey : kDarkGrey),
                          enabledBorder: outlineInputBorder(10),
                          focusedBorder: outlineInputBorder(10),
                          border: outlineInputBorder(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _updateIngredientList,
                      child: const IconCircleButton(icon: Icons.send),
                    ),
                    const SizedBox(width: 8),
                  ],
                )
              : const SizedBox(),
        ),
        const SizedBox(height: 15),

        const SizedBox(height: 10),
        // Spin wheel below macros
        Expanded(
          child: SpinWheelWidget(
            labels: widget.ingredientList,
            customLabels: _ingredientList.isNotEmpty ? _ingredientList : null,
            // macro: currentMacro,
            isMealSpin: false,
            playSound: _playSound,
            stopSound: _stopSound,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSpinView(
      bool isDarkMode, List<Map<String, dynamic>> categoryDatas) {
    return Column(
      children: [
        const SizedBox(height: 35),

        //category options
        CategorySelector(
          categories: categoryDatas,
          selectedCategoryId: selectedCategoryIdMeal,
          onCategorySelected: _updateCategoryData,
          isDarkMode: isDarkMode,
          accentColor: kAccent,
          darkModeAccentColor: kDarkModeAccent,
        ),

        const SizedBox(height: 50),

        Expanded(
          child: Center(
            child: _mealList.isEmpty
                ? noItemTastyWidget(
                    "No meals found for ${widget.selectedCategory} ${selectedCategoryMeal}",
                    "",
                    context,
                    false,
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
