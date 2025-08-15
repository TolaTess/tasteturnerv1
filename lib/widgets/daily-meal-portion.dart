import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/helper_files.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import '../helper/helper_functions.dart';
import '../data_models/program_model.dart';

class DailyMealPortion extends StatefulWidget {
  final Program? userProgram;
  final List<String> notAllowed;
  final String programName;
  final Map<String, dynamic>? selectedUser; // Add selected user parameter

  const DailyMealPortion({
    super.key,
    this.userProgram,
    this.notAllowed = const [],
    this.programName = '',
    this.selectedUser, // Add this parameter
  });

  @override
  State<DailyMealPortion> createState() => _DailyMealPortionState();
}

class _DailyMealPortionState extends State<DailyMealPortion> {
  List<Map<String, dynamic>> _foodTypes = [];
  late ScrollController _scrollController;

  // Get settings based on selected user or fall back to current user
  Map<String, dynamic>? get settings {
    final selectedUser = widget.selectedUser;
    final currentUser = userService.currentUser.value;

    // For family members, create a settings map from their direct properties
    Map<String, dynamic>? selectedSettings;
    if (selectedUser != null) {
      if (selectedUser['settings'] != null) {
        // If settings exist (current user), use them
        selectedSettings = selectedUser['settings'];
      } else {
        // For family members, create settings from their direct properties
        selectedSettings = {
          'foodGoal': selectedUser['foodGoal'],
          'fitnessGoal': selectedUser['fitnessGoal'],
          'ageGroup': selectedUser['ageGroup'],
        };
      }
    } else {
      // No selected user (single user mode), use current user settings
      selectedSettings = currentUser?.settings;
    }

    return selectedSettings;
  }

  // Default food type configurations
  final Map<String, Map<String, dynamic>> _defaultFoodTypes = {
    'protein': {
      'name': 'Protein',
      'icon': 'protein',
      'color': getMealTypeColor('protein'), // Brown
      'defaultPalmSize': '1 palm',
      'defaultSpatulaSize': '1/2 spatula',
      'defaultExamples': ['Chicken', 'Fish', 'Tofu', 'Eggs'],
      'defaultCalories': '150 kcal',
      'defaultPalmPercentage': 0.25, // 25% of meal calories
    },
    'grain': {
      'name': 'Grains',
      'icon': 'grain',
      'color': getMealTypeColor('grain'), // Goldenrod
      'defaultPalmSize': '1 cupped palm',
      'defaultSpatulaSize': '1 spatula',
      'defaultExamples': ['Rice', 'Pasta', 'Bread', 'Quinoa'],
      'defaultCalories': '120 kcal',
      'defaultPalmPercentage': 0.20, // 30% of meal calories
    },
    'vegetable': {
      'name': 'Vegetables',
      'icon': 'vegetable',
      'color': getMealTypeColor('vegetable'), // Forest Green
      'defaultPalmSize': '2 palms',
      'defaultSpatulaSize': '2 spatulas',
      'defaultExamples': ['Broccoli', 'Spinach', 'Carrots', 'Bell Peppers'],
      'defaultCalories': '30 kcal',
      'defaultPalmPercentage': 0.35, // 20% of meal calories
    },
    'fruit': {
      'name': 'Fruits',
      'icon': 'fruit',
      'color': getMealTypeColor('fruit'), // Tomato Red
      'defaultPalmSize': '1 palm',
      'defaultSpatulaSize': '1 spatula',
      'defaultExamples': ['Apple', 'Banana', 'Berries', 'Orange'],
      'defaultCalories': '80 kcal',
      'defaultPalmPercentage': 0.20, // 15% of meal calories
    },
    'snack': {
      'name': 'Snacks',
      'icon': 'snack',
      'color': getMealTypeColor('snack'), // Dark Orchid
      'defaultPalmSize': '1 palm',
      'defaultSpatulaSize': '1 spatula',
      'defaultExamples': ['Nuts', 'Yogurt', 'Crackers', 'Smoothie'],
      'defaultCalories': '150 kcal',
      'defaultPalmPercentage': 0.10, // 10% of meal calories
    },
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _buildFoodTypesFromProgram();
  }

  @override
  void didUpdateWidget(DailyMealPortion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userProgram != widget.userProgram ||
        oldWidget.selectedUser != widget.selectedUser) {
      _buildFoodTypesFromProgram();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _buildFoodTypesFromProgram() {
    _foodTypes.clear();

    // Use empty map if userProgram is null or portionDetails is null
    final programPortionDetails = widget.userProgram?.portionDetails ?? {};

    // For each default food type, check if program has custom portion details
    for (final entry in _defaultFoodTypes.entries) {
      final foodType = entry.key;
      final defaultConfig = entry.value;
      final programConfig = programPortionDetails.isNotEmpty
          ? programPortionDetails[foodType] as Map<String, dynamic>?
          : null;

      // Create food type configuration combining defaults with program specifics
      final foodTypeConfig = {
        'type': foodType,
        'name': defaultConfig['name'],
        'icon': defaultConfig['icon'],
        'palmPercentage': (parseToNumber(programConfig?['palmPercentage']) ??
                defaultConfig['defaultPalmPercentage'])
            .toDouble(),
        'spatulaSize': programConfig?['spatulaSize'] ??
            defaultConfig['defaultSpatulaSize'],
        'examples': programConfig?['examples'] != null
            ? List<String>.from(programConfig!['examples'])
            : List<String>.from(defaultConfig['defaultExamples']),
        'caloriesPerPalm':
            programConfig?['calories'] ?? defaultConfig['defaultCalories'],
      };

      _foodTypes.add(foodTypeConfig);
    }
  }

  double _getMealTargetCalories(String mealType) {
    // Use selected user's data if available, otherwise fall back to current user
    final selectedUser = widget.selectedUser;
    final currentUser = userService.currentUser.value;

    // Get food goal and fitness goal from selected user or current user
    String? foodGoalValue;
    String? fitnessGoal;

    if (selectedUser != null) {
      foodGoalValue =
          selectedUser['foodGoal'] ?? currentUser?.settings?['foodGoal'];
      fitnessGoal = selectedUser['fitnessGoal'] as String? ??
          currentUser?.settings?['fitnessGoal'] as String?;
    } else {
      foodGoalValue = currentUser?.settings?['foodGoal'];
      fitnessGoal = currentUser?.settings?['fitnessGoal'] as String?;
    }

    final fitnessGoalFinal = fitnessGoal ?? '';

    final baseTargetCalories =
        (parseToNumber(foodGoalValue) ?? 2000).toDouble();

    // Calculate adjusted total target based on fitness goal FIRST
    double adjustedTotalTarget;
    switch (fitnessGoalFinal.toLowerCase()) {
      case 'lose weight':
      case 'weight loss':
        adjustedTotalTarget = baseTargetCalories * 0.8; // 80% for weight loss
        break;
      case 'gain muscle':
      case 'muscle gain':
      case 'build muscle':
        adjustedTotalTarget = baseTargetCalories * 1.0; // 120% for muscle gain
        break;
      default:
        adjustedTotalTarget = baseTargetCalories; // 100% for maintenance
        break;
    }

    // Updated calorie distribution for 3 main meals only (no separate snack allocation)
    double percentage = 0.0;
    switch (mealType) {
      case 'Breakfast':
        percentage = 0.25; // 25%
        break;
      case 'Lunch':
        percentage = 0.375; // 37.5%
        break;
      case 'Dinner':
        percentage = 0.375; // 37.5%
        break;
      case 'Snacks':
        // Snacks are now part of lunch/dinner, no separate allocation
        percentage = 0.0;
        break;
    }

    // Apply meal percentage to the adjusted total target
    return adjustedTotalTarget * percentage;
  }

  String _getCalculatedPalmSize(double palmPercentage, String caloriesPerPalm) {
    final currentMealTime = getMealTimeOfDay();
    final mealTargetCalories = _getMealTargetCalories(currentMealTime);

    // Calculate calories for this food type based on palmPercentage
    final foodTypeCalories = mealTargetCalories * palmPercentage;

    // Extract calories per palm from string (e.g., "120 kcal" -> 120)
    final calorieMatch =
        RegExp(r'(\d+)(?:-\d+)?\s*kcal').firstMatch(caloriesPerPalm);
    final caloriesPerPalmNumber = calorieMatch != null
        ? (int.tryParse(calorieMatch.group(1)!) ?? 120).toDouble()
        : 120.0;

    // Calculate palm count
    final palmCount = foodTypeCalories / caloriesPerPalmNumber;

    // Format the palm size
    final palmSize =
        _formatPalmSize(palmCount, false); // Assuming not cupped for now

    return palmSize;
  }

  String _formatPalmSize(double palmCount, bool isCupped) {
    final cuppedPrefix = isCupped ? 'cupped ' : '';

    if (palmCount >= 1.0) {
      if (palmCount % 1 == 0) {
        return '${palmCount.toInt()} ${cuppedPrefix}palm${palmCount > 1 ? 's' : ''}';
      } else {
        return '${palmCount.toStringAsFixed(1)} ${cuppedPrefix}palm${palmCount > 1 ? 's' : ''}';
      }
    } else if (palmCount >= 0.75) {
      return '3/4 ${cuppedPrefix}palm';
    } else if (palmCount >= 0.67) {
      return '2/3 ${cuppedPrefix}palm';
    } else if (palmCount >= 0.5) {
      return '1/2 ${cuppedPrefix}palm';
    } else if (palmCount >= 0.33) {
      return '1/3 ${cuppedPrefix}palm';
    } else if (palmCount >= 0.25) {
      return '1/4 ${cuppedPrefix}palm';
    } else {
      return '1/8 ${cuppedPrefix}palm';
    }
  }

  String _getCalculatedCalories(double palmPercentage) {
    final currentMealTime = getMealTimeOfDay();
    final mealTargetCalories = _getMealTargetCalories(currentMealTime);

    // Calculate calories for this food type based on palmPercentage
    final foodTypeCalories = mealTargetCalories * palmPercentage;

    return '${foodTypeCalories.round()} kcal';
  }

  List<Map<String, dynamic>> _getAllowedFoodTypes() {
    // Use program's notAllowed first, then widget's notAllowed, then empty list as fallback
    final notAllowed = widget.userProgram?.notAllowed ??
        (widget.notAllowed.isNotEmpty ? widget.notAllowed : []);

    // Get current meal time
    final currentMealTime = getMealTimeOfDay();

    // Check if snacks are allowed by the program
    final isSnackAllowed = !notAllowed.contains('snack');

    final allowedFoods = _foodTypes.where((food) {
      final foodType = food['type'] as String;

      // Always exclude if in notAllowed list
      if (notAllowed.contains(foodType)) {
        return false;
      }

      // Handle snack-specific rules
      if (foodType == 'snack') {
        // Don't show snacks if not allowed by program
        if (!isSnackAllowed) {
          return false;
        }
        // Don't show snacks during breakfast (even if allowed by program)
        if (currentMealTime == 'Breakfast') {
          return false;
        }
      }

      return true;
    }).toList();

    // Redistribute percentages so they add up to 100% of meal calories
    final redistributedFoods = _redistributePercentages(allowedFoods);

    // Cache meal target calories ONCE before sorting to avoid GetX observable access during comparison
    final mealTargetCalories = _getMealTargetCalories(currentMealTime);

    // Sort by highest calories (descending order)
    redistributedFoods.sort((a, b) {
      final aCalories = mealTargetCalories * (a['palmPercentage'] as double);
      final bCalories = mealTargetCalories * (b['palmPercentage'] as double);

      return bCalories.compareTo(aCalories); // Descending order (highest first)
    });

    return redistributedFoods;
  }

  List<Map<String, dynamic>> _redistributePercentages(
      List<Map<String, dynamic>> allowedFoods) {
    if (allowedFoods.isEmpty) return allowedFoods;

    // Calculate total percentage of allowed foods
    double totalAllowedPercentage = 0.0;
    for (final food in allowedFoods) {
      totalAllowedPercentage += food['palmPercentage'] as double;
    }

    // If total is already 1.0 (100%), no redistribution needed
    if (totalAllowedPercentage >= 0.99 && totalAllowedPercentage <= 1.01) {
      return allowedFoods;
    }

    // Redistribute percentages proportionally to sum to 100%
    return allowedFoods.map((food) {
      final originalPercentage = food['palmPercentage'] as double;
      final adjustedPercentage = originalPercentage / totalAllowedPercentage;

      return Map<String, dynamic>.from(food)
        ..['palmPercentage'] = adjustedPercentage;
    }).toList();
  }

  void _showPortionGuide() {
    showDialog(
      context: context,
      builder: (context) => _buildPortionGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final allowedFoods = _getAllowedFoodTypes();
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight < 700
          ? screenHeight * 0.35
          : screenHeight > 800 && screenHeight < 1000
              ? screenHeight * 0.31
              : screenHeight * 0.35,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: getPercentageHeight(2, context)),
          // Header with title and portion guide tool
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(4, context)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Portion Guide',
                      style: textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w200,
                        color: isDarkMode ? kWhite : kBlack,
                        fontSize: getPercentageWidth(4.5, context),
                      ),
                    ),
                    Text(
                      '${getMealTimeOfDay()} portions',
                      style: textTheme.bodySmall?.copyWith(
                        color: kAccent,
                        fontSize: getPercentageWidth(3.5, context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Target: ${getRecommendedCalories(getMealTimeOfDay(), 'dailyPortion', selectedUser: widget.selectedUser)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                        fontSize: getPercentageWidth(3, context),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (widget.userProgram != null)
                      Text(
                        'Based on your program',
                        style: textTheme.labelSmall?.copyWith(
                          color: kLightGrey,
                          fontSize: getPercentageWidth(3, context),
                        ),
                      ),
                    SizedBox(height: getPercentageHeight(1, context)),
                  ],
                ),
                IconButton(
                  onPressed: _showPortionGuide,
                  icon: Icon(
                    Icons.info_outline,
                    size: getIconScale(6, context),
                    color: kAccent,
                  ),
                  tooltip: 'Portion Guide Tools',
                ),
              ],
            ),
          ),

          // Horizontal scroll of portion cards
          Expanded(
            child: allowedFoods.isEmpty
                ? _buildNoAllowedFoodsMessage(isDarkMode, textTheme)
                : Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 4.0,
                    radius: const Radius.circular(8),
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(4, context)),
                      itemCount: allowedFoods.length,
                      itemBuilder: (context, index) {
                        final food = allowedFoods[index];
                        return _buildPortionCard(food, isDarkMode, textTheme);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortionCard(
      Map<String, dynamic> food, bool isDarkMode, TextTheme textTheme) {
    return Container(
      width: getPercentageWidth(35, context),
      margin: EdgeInsets.only(right: getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: getMealTypeColor(food['type'] as String).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              (getMealTypeColor(food['type'] as String)).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(3, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food type header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(getPercentageWidth(1.5, context)),
                  decoration: BoxDecoration(
                    color: (getMealTypeColor(food['type'] as String))
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.asset(
                      getAssetImageForItem(food['icon'] as String),
                      width: getIconScale(5, context),
                      height: getIconScale(5, context),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: getPercentageWidth(2, context)),
                Expanded(
                  child: Text(
                    food['name'] as String,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? kWhite : kBlack,
                      fontSize: getPercentageWidth(3.2, context),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: getPercentageHeight(1, context)),

            // Palm portion visualization
            Container(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color: (getMealTypeColor(food['type'] as String))
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pan_tool,
                    size: getIconScale(4, context),
                    color: getMealTypeColor(food['type'] as String),
                  ),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Expanded(
                    child: Text(
                      _getCalculatedPalmSize(
                        food['palmPercentage'] as double,
                        food['caloriesPerPalm'] as String,
                      ),
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? kWhite : kBlack,
                        fontSize: getPercentageWidth(3, context),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: getPercentageHeight(0.5, context)),

            // Calories
            Text(
              _getCalculatedCalories(food['palmPercentage'] as double),
              style: textTheme.bodySmall?.copyWith(
                color: kAccent,
                fontSize: getPercentageWidth(2.8, context),
                fontWeight: FontWeight.w500,
              ),
            ),

            SizedBox(height: getPercentageHeight(0.5, context)),

            // Examples
            Text(
              'Examples:',
              style: textTheme.bodySmall?.copyWith(
                color: isDarkMode ? kLightGrey : kDarkGrey,
                fontSize: getPercentageWidth(2.5, context),
                fontWeight: FontWeight.w500,
              ),
            ),
            ...((food['examples'] as List<String>).take(2).map(
                  (example) => Text(
                    '• $example',
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? kLightGrey : kDarkGrey,
                      fontSize: getPercentageWidth(2.3, context),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAllowedFoodsMessage(bool isDarkMode, TextTheme textTheme) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(getPercentageWidth(4, context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: getIconScale(8, context),
              color: isDarkMode ? kLightGrey : kDarkGrey,
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              'No food types allowed',
              style: textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? kLightGrey : kDarkGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Check your program restrictions',
              style: textTheme.bodySmall?.copyWith(
                color: isDarkMode ? kLightGrey : kDarkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortionGuideDialog() {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? kDarkGrey : kWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: EdgeInsets.all(getPercentageWidth(6, context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text(
                      'Portion Guide Tools',
                      style: textTheme.displaySmall?.copyWith(
                        color: kAccent,
                        fontSize: getPercentageWidth(7, context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Portion guide for current program: \n${widget.programName}',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: getPercentageWidth(2.5, context),
                        color: kLightGrey,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: kAccent),
                ),
              ],
            ),

            SizedBox(height: getPercentageHeight(2, context)),

            // Palm reference
            _buildPortionReference(
              icon: Icons.pan_tool,
              title: 'Palm Reference',
              description: 'Use your palm to measure portions',
              details: [
                '1 palm = 3-4 oz protein',
                '1 cupped palm = 1/2 cup carbs',
                '2 palms = 2 cups vegetables',
              ],
              color: Color(0xFF8B4513),
              isDarkMode: isDarkMode,
              textTheme: textTheme,
            ),

            SizedBox(height: getPercentageHeight(2, context)),

            // Spatula reference
            _buildPortionReference(
              icon: Icons.soup_kitchen,
              title: 'Spatula Reference',
              description: 'Alternative measuring tool',
              details: [
                '1/2 spatula = 3-4 oz protein',
                '1 spatula = 1/2 cup carbs',
                '2 spatulas = 2 cups vegetables',
              ],
              color: Color(0xFF4682B4),
              isDarkMode: isDarkMode,
              textTheme: textTheme,
            ),

            SizedBox(height: getPercentageHeight(2, context)),

            // Daily calories
            Container(
              padding: EdgeInsets.all(getPercentageWidth(3, context)),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Column(
                    children: [
                      Text(
                        'Your Daily Target',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: kAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final baseTargetValue = settings?['foodGoal'] ?? 2000;
                          final baseTarget =
                              (parseToNumber(baseTargetValue) ?? 2000)
                                  .toDouble();
                          final fitnessGoal =
                              settings?['fitnessGoal'] as String? ?? '';

                          String targetText = '(${baseTarget.round()} kcal)';
                          final fitnessGoalStr = fitnessGoal?.toString() ?? '';
                          if (fitnessGoalStr.toLowerCase().contains('weight')) {
                            final adjustedTarget = (baseTarget * 0.8).round();
                            targetText =
                                '($adjustedTarget kcal for weight loss)';
                          } else if (fitnessGoalStr
                              .toLowerCase()
                              .contains('muscle')) {
                            final adjustedTarget = (baseTarget * 1.2).round();
                            targetText =
                                '($adjustedTarget kcal for muscle gain)';
                          }

                          return Text(
                            targetText,
                            textAlign: TextAlign.center,
                            style: textTheme.labelSmall?.copyWith(
                              color: kLightGrey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMealCalorieInfo(
                          'Breakfast',
                          getRecommendedCalories('Breakfast', 'dailyPortion',
                              selectedUser: widget.selectedUser),
                          textTheme,
                          isDarkMode),
                      _buildMealCalorieInfo(
                          'Lunch',
                          getRecommendedCalories('Lunch', 'dailyPortion',
                              selectedUser: widget.selectedUser),
                          textTheme,
                          isDarkMode),
                      _buildMealCalorieInfo(
                          'Dinner',
                          getRecommendedCalories('Dinner', 'dailyPortion',
                              selectedUser: widget.selectedUser),
                          textTheme,
                          isDarkMode),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Text(
                    'Snacks can be included as part of lunch or dinner',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? kLightGrey : kDarkGrey,
                      fontSize: getPercentageWidth(2.5, context),
                      fontStyle: FontStyle.italic,
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

  Widget _buildPortionReference({
    required IconData icon,
    required String title,
    required String description,
    required List<String> details,
    required Color color,
    required bool isDarkMode,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: getIconScale(6, context)),
              SizedBox(width: getPercentageWidth(2, context)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? kLightGrey : kDarkGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          ...details.map(
            (detail) => Padding(
              padding:
                  EdgeInsets.only(bottom: getPercentageHeight(0.5, context)),
              child: Text(
                '• $detail',
                style: textTheme.bodySmall?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCalorieInfo(
      String mealType, String calories, TextTheme textTheme, bool isDarkMode) {
    return Column(
      children: [
        Text(
          mealType,
          style: textTheme.labelSmall?.copyWith(
            color: isDarkMode ? kWhite : kBlack,
            fontSize: getPercentageWidth(3, context),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          calories,
          style: textTheme.bodySmall?.copyWith(
            color: kAccent,
            fontSize: getPercentageWidth(2.5, context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
