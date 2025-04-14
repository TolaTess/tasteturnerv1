import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../widgets/icon_widget.dart';
import 'safe_text_field.dart';
import 'spin_stack.dart';

class SpinWheelPop extends StatefulWidget {
  const SpinWheelPop({
    super.key,
    required this.macro,
    required this.ingredientList,
    required this.mealList,
    required this.macroList,
    required this.selectedCategory,
    this.customMacro = false,
  });

  final String macro, selectedCategory;
  final List<MacroData> ingredientList;
  final List<Meal> mealList;
  final List<String> macroList;
  final bool customMacro;

  @override
  _SpinWheelPopState createState() => _SpinWheelPopState();
}

class _SpinWheelPopState extends State<SpinWheelPop>
    with SingleTickerProviderStateMixin {
  late String currentMacro;
  Color circle1Color = kPrimaryColor;
  Color circle2Color = kPrimaryColor;
  Color circle3Color = kPrimaryColor;
  final TextEditingController customController = TextEditingController();
  bool _isExpanded = false;
  List<String> _ingredientList = [];
  List<String> _mealList = [];
  late TabController _tabController;
  final _spinController =
      StreamController<int>.broadcast(); // For SpinWheelWidget control
  late AudioPlayer _audioPlayer;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    currentMacro = widget.macro;
    colourProvider(currentMacro);
    _tabController = TabController(length: 2, vsync: this);
    _fetchMeals(); // Load meals for Meal Spin mode
    _audioPlayer = AudioPlayer();
    _loadMuteState();
  }

  Future<void> _fetchMeals() async {
    final meals =
        await mealManager.fetchMealsByCategory(widget.selectedCategory);
    setState(() {
      _mealList = meals.map((meal) => meal.title).toList();
    });
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
    _tabController.dispose();
    _spinController.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _updateMacro(String newMacro) {
    setState(() {
      currentMacro = newMacro;
      colourProvider(newMacro);
    });
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

  void colourProvider(String newMacro) {
    if (newMacro == protein) {
      circle1Color = kAccent.withOpacity(0.65);
      circle2Color = kPrimaryColor;
      circle3Color = kPrimaryColor;
    } else if (newMacro == carbs) {
      circle1Color = kPrimaryColor;
      circle2Color = kPrimaryColor;
      circle3Color = kAccent.withOpacity(0.65);
    } else if (newMacro == fat) {
      circle1Color = kPrimaryColor;
      circle2Color = kAccent.withOpacity(0.65);
      circle3Color = kPrimaryColor;
    }
  }

  void _playSound() async {
    if (!_isMuted) {
      await _audioPlayer
          .play(AssetSource('audio/spin.mp3')); // Use a spin-specific sound
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _saveMuteState(); // Save state when toggled
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const IconCircleButton(),
        ),
        title: const Text(macroSpinner,
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDarkMode ? kWhite : kBlack,
          unselectedLabelColor: kLightGrey,
          indicatorColor: isDarkMode ? kWhite : kBlack,
          tabs: const [
            Tab(text: 'Ingredient Spin'),
            Tab(text: 'Meal Spin'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
            onPressed: _toggleMute,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Ingredient Spin Tab
          _buildIngredientSpinView(isDarkMode),
          // Meal Spin Tab
          _buildMealSpinView(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildIngredientSpinView(bool isDarkMode) {
    return Column(
      children: [
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
        // Macro selectors row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () => widget.macroList.any((macro) => macro == protein)
                  ? _updateMacro(protein)
                  : snackbar(context, protein, widget.selectedCategory),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: circle1Color,
                child: const Text(proteinLabel,
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            GestureDetector(
              onTap: () => widget.macroList.any((macro) => macro == carbs)
                  ? _updateMacro(carbs)
                  : snackbar(context, carbs, widget.selectedCategory),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: circle3Color,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(carbs,
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            GestureDetector(
              onTap: () => widget.macroList.any((macro) => macro == fat)
                  ? _updateMacro(fat)
                  : snackbar(context, fat, widget.selectedCategory),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: circle2Color,
                child:
                    const Text(fatLabel, style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Spin wheel below macros
        Expanded(
          child: SpinWheelWidget(
            labels: widget.ingredientList,
            customLabels: _ingredientList.isNotEmpty ? _ingredientList : null,
            macro: currentMacro,
            isMealSpin: false,
            playSound: _playSound,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSpinView(bool isDarkMode) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: _mealList.isEmpty
                ? noItemTastyWidget(
                    "No meals found for ${widget.selectedCategory}",
                    "",
                    context,
                    false,
                  )
                : SpinWheelWidget(
                    mealList: widget.mealList,
                    labels: [], // Empty since we use customLabels
                    customLabels: _mealList,
                    macro: widget.macro, // No macro filtering for meals
                    isMealSpin: true,
                    playSound: _playSound,
                  ),
          ),
        ),
      ],
    );
  }

  void snackbar(BuildContext context, String mMacro, String category) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$mMacro not applicable to the $category"),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      );
    }
  }
}
