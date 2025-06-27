import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/screens/buddy_screen.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../pages/dietary_choose_screen.dart';
import '../service/chat_controller.dart';
import '../service/program_service.dart';
import '../widgets/goal_diet_widget.dart';
import '../widgets/program_card.dart';
import '../widgets/bottom_nav.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> with SingleTickerProviderStateMixin {
  final ProgramService _programService = Get.put(ProgramService());
  String selectedDiet =
      userService.currentUser.value?.settings['dietPreference'] ?? 'balanced';
  String selectedGoal =
      userService.currentUser.value?.settings['fitnessGoal'] ??
          'Healthy Eating';
  bool isLoading = false;
  String aiCoachResponse = '';
  bool _isLoadingDietGoal = false;
  List<MacroData> _recommendedIngredients = [];
  Meal? _featuredMeal;
  DateTime? _lastPickDate;

  // Program types
  final List<Map<String, dynamic>> programTypes = [
    {
      'type': 'vitality',
      'name': 'Vitality',
      'subtitle': 'Eat like the world\'s\nlongest-living people',
      'isNew': true,
      'gradient': [kAccent.withOpacity(0.5), kAccent],
      'image': 'assets/images/fruit.jpg',
      'enrolled': true,
    },
    {
      'type': 'weight-loss',
      'name': '3 Week Weight Loss',
      'subtitle': '21-day Meal Plan',
      'isPopular': true,
      'gradient': [kAccentLight.withOpacity(0.5), kAccentLight],
      'image': 'assets/images/salad.jpg',
      'enrolled': false,
    },
  ];

  // Add repeating animation controller
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Start the animation and stop after one rotation
    _rotationController.forward().then((_) {
      _rotationController.reset();
    });
    
    _pickDietGoalRecommendationsIfNeeded();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _pickDietGoalRecommendationsIfNeeded({bool force = false}) {
    final now = DateTime.now();
    if (!force && _recommendedIngredients.isNotEmpty && _lastPickDate != null) {
      final daysSince = now.difference(_lastPickDate!).inDays;
      if (daysSince < 7) return;
    }
    _pickDietGoalRecommendations();
  }

  void _pickDietGoalRecommendations() {
    setState(() {
      _isLoadingDietGoal = true;
    });
    Future.delayed(Duration.zero, () {
      final user = userService.currentUser.value;
      final String userDiet =
          user?.settings['dietPreference']?.toString() ?? 'Balanced';
      final String userGoal =
          user?.settings['fitnessGoal']?.toString() ?? 'Healthy Eating';
      final allIngredients = macroManager.ingredient;
      final allMeals = mealManager.meals;
      List<MacroData> filteredIngredients = [];
      List<Meal> filteredMeals = [];

      // Logic for filtering based on user diet and goal
      // 1. Filter for items that match the user's diet (category match is required)
      final dietCategory = userDiet.toLowerCase();
      List<MacroData> dietIngredients = allIngredients
          .where((i) =>
              i.categories.any((c) => c.toLowerCase().contains(dietCategory)))
          .toList();
      List<Meal> dietMeals = allMeals
          .where((m) =>
              m.categories.any((c) => c.toLowerCase().contains(dietCategory)))
          .toList();

      // 2. Among those, prefer items that also match the user's goal
      List<MacroData> preferredIngredients = [];
      List<Meal> preferredMeals = [];
      if (userGoal.toLowerCase().contains('weightloss') ||
          userGoal.toLowerCase().contains('lose weight') ||
          userGoal.toLowerCase().contains('weight loss')) {
        preferredIngredients = dietIngredients.where((i) {
          final matchesGoal = i.categories.any((c) =>
              c.toLowerCase().contains('weightloss') ||
              c.toLowerCase().contains('weight loss') ||
              c.toLowerCase().contains('low calorie') ||
              c.toLowerCase().contains('lowcalorie') ||
              c.toLowerCase().contains('diet') ||
              c.toLowerCase().contains('slimming'));
          final carbsStr = i.macros['carbs']?.toString() ?? '';
          final carbs = double.tryParse(carbsStr);
          final isLowCarb = carbs != null ? carbs < 10 : false;
          return matchesGoal && isLowCarb;
        }).toList();
        preferredMeals = dietMeals
            .where((m) => m.categories.any((c) =>
                c.toLowerCase().contains('weightloss') ||
                c.toLowerCase().contains('weight loss') ||
                c.toLowerCase().contains('low calorie') ||
                c.toLowerCase().contains('lowcalorie') ||
                c.toLowerCase().contains('diet') ||
                c.toLowerCase().contains('slimming')))
            .toList();
      } else if (userGoal.toLowerCase().contains('weightgain') ||
          userGoal.toLowerCase().contains('muscle gain') ||
          userGoal.contains('weight gain')) {
        preferredIngredients = dietIngredients.where((i) {
          final matchesGoal = i.categories.any((c) =>
              c.toLowerCase().contains('weightgain') ||
              c.toLowerCase().contains('weight gain') ||
              c.toLowerCase().contains('high calorie') ||
              c.toLowerCase().contains('muscle gain') ||
              c.toLowerCase().contains('bulking') ||
              c.toLowerCase().contains('mass gain'));
          final proteinStr = i.macros['protein']?.toString() ?? '';
          final protein = double.tryParse(proteinStr);
          final isHighProtein = protein != null ? protein > 10 : false;
          return matchesGoal && isHighProtein;
        }).toList();
        preferredMeals = dietMeals
            .where((m) => m.categories.any((c) =>
                c.toLowerCase().contains('weightgain') ||
                c.toLowerCase().contains('weight gain') ||
                c.toLowerCase().contains('high calorie') ||
                c.toLowerCase().contains('muscle gain') ||
                c.toLowerCase().contains('bulking') ||
                c.toLowerCase().contains('mass gain')))
            .toList();
      } else {
        preferredIngredients = dietIngredients;
        preferredMeals = dietMeals;
      }

      // 3. If not enough preferred, fill from diet-matching only
      filteredIngredients = [...preferredIngredients];
      if (filteredIngredients.length < 3) {
        final extra = dietIngredients
            .where((i) => !filteredIngredients.contains(i))
            .toList();
        filteredIngredients.addAll(extra);
      }
      filteredMeals = [...preferredMeals];
      if (filteredMeals.isEmpty) {
        final extra =
            dietMeals.where((m) => !filteredMeals.contains(m)).toList();
        filteredMeals.addAll(extra);
      }

      // 4. Fallbacks if still not enough
      if (filteredIngredients.length < 3) {
        filteredIngredients = allIngredients;
      }
      if (filteredMeals.isEmpty) {
        filteredMeals = allMeals;
      }

      filteredIngredients.shuffle();
      filteredMeals.shuffle();

      setState(() {
        _recommendedIngredients = filteredIngredients.take(3).toList();
        _featuredMeal = filteredMeals.isNotEmpty ? filteredMeals.first : null;
        _lastPickDate = DateTime.now();
        _isLoadingDietGoal = false;
      });
    });
  }

  Future<void> _showProgramQuestionnaire(String programType) async {
    final questions = [
      'What is your current weight (in kg)?',
      'What is your target weight (in kg)?',
      'How many meals do you prefer per day?',
      'Do you have any food allergies?',
      'How many days per week can you exercise?',
    ];

    final answers = <String, String>{};
    final textTheme = Theme.of(context).textTheme;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Customize Your $programType Program',
          style: textTheme.titleLarge?.copyWith(color: kAccent),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var question in questions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: question,
                      labelStyle: textTheme.bodyMedium,
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kAccent),
                      ),
                    ),
                    style: textTheme.bodyLarge,
                    onChanged: (value) => answers[question] = value,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: textTheme.labelLarge?.copyWith(color: Colors.grey),
            ),
            onPressed: () => Navigator.pop(context, null),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
            ),
            child: Text(
              'Generate Program',
              style: textTheme.labelLarge?.copyWith(color: kWhite),
            ),
            onPressed: () => Navigator.pop(context, answers),
          ),
        ],
      ),
    );

    if (answers.length == questions.length) {
      setState(() => isLoading = true);
      try {
        final programData = await geminiService.generateCustomProgram(
          answers,
          programType,
          selectedDiet,
        );
        await _programService.createProgram(programData);
        setState(() => isLoading = false);
        Get.snackbar(
          'Success',
          'Your program has been created!',
          backgroundColor: kAccentLight,
          colorText: kWhite,
        );
      } catch (e) {
        setState(() => isLoading = false);
        Get.snackbar(
          'Error',
          'Failed to create program. Please try again.',
          backgroundColor: Colors.red,
          colorText: kWhite,
        );
      }
    }
  }

  Future<void> askAICoach() async {
    setState(() {
      isLoading = true;
    });
    final userName = userService.currentUser.value?.displayName;
    final prompt =
        'Give me a meal plan strategy for user $userName with a $selectedDiet diet with the goal to $selectedGoal. User name is $userName';
    final response =
        await geminiService.getResponse(prompt, 256, role: buddyAiRole);
    setState(() {
      aiCoachResponse = response;
      isLoading = false;
    });
    // Save both question and response to buddy chat
    final chatId = userService.buddyId;
    final userId = userService.userId ?? '';
    if (chatId != null && chatId.isNotEmpty) {
      await ChatController.saveMessageToFirestore(
        chatId: chatId,
        content: prompt,
        senderId: userId,
      );
      await ChatController.saveMessageToFirestore(
        chatId: chatId,
        content: response,
        senderId: 'buddy',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final accent = kAccent;
    final user = userService.currentUser.value;
    final String userDiet =
        user?.settings['dietPreference']?.toString() ?? 'Balanced';
    final String userGoal =
        user?.settings['fitnessGoal']?.toString() ?? 'Healthy Eating';
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccent,
        toolbarHeight: getPercentageHeight(10, context),
        automaticallyImplyLeading: false,
        title: Text(
          'A Program Just for You',
          style: textTheme.displayMedium?.copyWith(
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: RotationTransition(
        turns: _rotationController,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BottomNavSec(selectedIndex: 3),
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Base circle with gradient
              Container(
                width: getResponsiveBoxSize(context, 50, 50),
                height: getResponsiveBoxSize(context, 50, 50),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      kAccent.withOpacity(0.3),
                      kAccent.withOpacity(0.7),
                    ],
                    stops: const [0.2, 0.9],
                  ),
                ),
              ),
              // Text centered in circle
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(getPercentageWidth(1, context)),
                    child: Transform.rotate(
                      angle: -0.3,
                      child: Text(
                        'Spin',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: isDarkMode ? kWhite : kDarkGrey,
                          fontSize: getPercentageWidth(3, context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            top: getPercentageHeight(1, context),
            left: getPercentageWidth(2, context),
            right: getPercentageWidth(2, context),
            bottom: getPercentageHeight(2, context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Diet/Goal Selector
              _isLoadingDietGoal
                  ? Center(
                      child: Padding(
                      padding: EdgeInsets.all(getPercentageWidth(2, context)),
                      child: const CircularProgressIndicator(
                        color: kAccent,
                      ),
                    ))
                  : GoalDietWidget(
                      diet: userDiet,
                      goal: userGoal,
                      topIngredients: _recommendedIngredients,
                      featuredMeal: _featuredMeal,
                      onIngredientTap: (ingredient) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IngredientDetailsScreen(
                              item: ingredient,
                              ingredientItems: fullLabelsList,
                            ),
                          ),
                        );
                      },
                      onMealTap: (meal) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailScreen(
                              mealData: meal,
                              screen: 'recipe',
                            ),
                          ),
                        );
                      },
                      onRefresh: _isLoadingDietGoal
                          ? null
                          : () =>
                              _pickDietGoalRecommendationsIfNeeded(force: true),
                    ),
              SizedBox(height: getPercentageHeight(1.5, context)),
              // AI Coach Section
              Text(
                'Speak to "Tasty" AI Coach',
                style: textTheme.titleLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              ElevatedButton.icon(
                icon: const Icon(Icons.lightbulb, color: kWhite),
                label: Text(
                  'Get Meal Plan Guidance',
                  style: textTheme.labelLarge?.copyWith(color: kWhite),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentLight,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isLoading ? null : askAICoach,
              ),
              if (isLoading) ...[
                SizedBox(height: getPercentageHeight(2, context)),
                Center(child: CircularProgressIndicator(color: accent)),
              ],
              if (aiCoachResponse.isNotEmpty) ...[
                SizedBox(height: getPercentageHeight(2, context)),
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(getPercentageWidth(3, context)),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.08),
                      ),
                      child: Text(
                        aiCoachResponse,
                        style: textTheme.bodyLarge?.copyWith(
                          color: isDarkMode ? kWhite : kDarkGrey,
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(getPercentageWidth(3, context)),
                      decoration: BoxDecoration(
                        color: isDarkMode ? kDarkGrey : kWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Get.to(
                                  () => const TastyScreen(screen: 'message'));
                            },
                            child: Text(
                              'Talk More',
                              style: textTheme.titleMedium?.copyWith(
                                color: kAccentLight,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Get.to(() => const ChooseDietScreen(
                                    isDontShowPicker: true,
                                  ));
                            },
                            child: Text(
                              'Generate a meal',
                              style: textTheme.titleMedium?.copyWith(
                                color: kAccentLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: getPercentageHeight(2, context)),
              // Program Cards
              Text(
                'Customize Your Program',
                style: textTheme.displaySmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: getPercentageHeight(2, context)),
              SizedBox(
                height: getPercentageHeight(20, context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(4, context)),
                  separatorBuilder: (context, index) =>
                      SizedBox(width: getPercentageWidth(4, context)),
                  itemCount: programTypes.length,
                  itemBuilder: (context, i) {
                    final program = programTypes[i];
                    return SizedBox(
                      width: getPercentageWidth(40, context),
                      child: ProgramCard(
                        program: program,
                        onTap: () => _showProgramQuestionnaire(program['type']),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: getPercentageHeight(3, context)),
            ],
          ),
        ),
      ),
    );
  }
}
