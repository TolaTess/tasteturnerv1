import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/screens/buddy_screen.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/dietary_choose_screen.dart';
import '../service/chat_controller.dart';
import '../service/program_service.dart';
import '../widgets/goal_diet_widget.dart';
import '../widgets/program_card.dart';
import '../widgets/card_overlap.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen>
    with SingleTickerProviderStateMixin {
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
  RxList<Map<String, dynamic>> programTypes = <Map<String, dynamic>>[].obs;

  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _rotationController.forward().then((_) {
      _rotationController.reset();
    });

    _pickDietGoalRecommendationsIfNeeded();
    _loadProgramTypes();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadProgramTypes() async {
    try {
      final snapshot = await firestore.collection('programs').get();
      print('snapshot: $snapshot');
      final types = snapshot.docs.map((doc) {
        print('doc: $doc');
        final data = doc.data();
        return {
          'type': doc.id,
          'image': data['image'] ?? '',
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'options': List<String>.from(data['options'] ?? []),
        };
      }).toList();

      programTypes.value = types;
    } catch (e) {
      print('Error loading program types: $e');
      // Fallback to default programs if loading fails
      programTypes.value = [
        {
          'type': 'vitality',
          'name': 'Vitality',
          'image': 'salad',
          'description': 'A program focused on longevity and healthy eating',
          'options': ['beginner', 'intermediate', 'advanced'],
        },
        {
          'type': 'Days Challenge',
          'name': '7 Days Challenge',
          'image': 'herbs',
          'description': 'A program focused on longevity and healthy eating',
          'options': ['beginner', 'intermediate', 'advanced'],
        },
      ];
    }
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
    final programData = programTypes.firstWhere(
      (program) => program['type'] == programType,
      orElse: () => throw Exception('Program type not found'),
    );

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
          'Customize Your ${programData['name']} Program',
          style: textTheme.titleLarge?.copyWith(color: kAccent),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                programData['description'],
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
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
        // Create a detailed prompt for Gemini
        final prompt = '''
Create a personalized fitness and nutrition program with the following details:

Program Type: ${programData['name']}
Description: ${programData['description']}}

User Profile:
- Diet Preference: $selectedDiet
- Fitness Goal: $selectedGoal
- Current Weight: ${answers['What is your current weight (in kg)?']} kg
- Target Weight: ${answers['What is your target weight (in kg)?']} kg
- Preferred Meals/Day: ${answers['How many meals do you prefer per day?']}
- Food Allergies: ${answers['Do you have any food allergies?']}
- Exercise Days/Week: ${answers['How many days per week can you exercise?']}

Requirements:
${programData['requirements'].map((req) => '- $req').join('\n')}

Please provide a structured program including:
1. Weekly meal plans
2. Exercise recommendations
3. Progress tracking metrics
4. Nutrition guidelines
5. Weekly goals and milestones
''';

        final programResponse = await geminiService.generateCustomProgram(
          answers,
          programType,
          selectedDiet,
          additionalContext: prompt,
        );

        // Add program type specific data
        programResponse['type'] = programType;
        programResponse['name'] = programData['name'];
        programResponse['description'] = programData['description'];
        programResponse['duration'] = programData['duration'];
        programResponse['options'] = programData['options'];

        await _programService.createProgram(programResponse);
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
          style: textTheme.displayMedium?.copyWith(),
        ),
        centerTitle: true,
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
                style: textTheme.displaySmall?.copyWith(
                  color: accent,
                  fontSize: getTextScale(7, context),
                  fontWeight: FontWeight.w200,
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
              Text(
                'Customize Your Program',
                style: textTheme.headlineMedium?.copyWith(
                  color: accent,
                ),
              ),
              SizedBox(height: getPercentageHeight(2, context)),
              Obx(() => SizedBox(
                    height: getPercentageHeight(25, context),
                    child: programTypes.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(
                              color: accent,
                            ),
                          )
                        : OverlappingCardsView(
                            cardWidth: getPercentageWidth(70, context),
                            cardHeight: getPercentageHeight(25, context),
                            overlap: 60,
                            padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(4, context),
                            ),
                            children: List.generate(
                              programTypes.length,
                              (index) => OverlappingCard(
                                title: programTypes[index]['name'] ?? '',
                                subtitle:
                                    programTypes[index]['description'] ?? '',
                                color: colors[index % colors.length],
                                imageUrl: programTypes[index]['image'] != null
                                    ? 'assets/images/${programTypes[index]['image']}.jpg'
                                    : null,
                                width: getPercentageWidth(70, context),
                                height: getPercentageHeight(25, context),
                                index: index,
                                onTap: () => _showProgramQuestionnaire(
                                  programTypes[index]['type'],
                                ),
                              ),
                            ),
                          ),
                  )),
              SizedBox(height: getPercentageHeight(3, context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgramCard(BuildContext context, String title, String subtitle,
      String imageName, Color cardColor, int index) {
    return OverlappingCard(
      title: title,
      subtitle: subtitle,
      color: cardColor,
      imageUrl: 'assets/images/$imageName.jpg',
      width: MediaQuery.of(context).size.width * 0.7,
      height: 180,
      index: index,
      onTap: () => _showProgramQuestionnaire(title.toLowerCase()),
    );
  }

  Widget _buildProgramList(BuildContext context) {
    final colors = [
      kAccent.withOpacity(0.8),
      kBlue.withOpacity(0.8),
      kAccentLight.withOpacity(0.8),
      kPurple.withOpacity(0.8),
    ];

    final programs = [
      {
        'title': 'Vitality',
        'subtitle': 'Eat like the world\'s longest-living people',
        'image': 'salad',
      },
      {
        'title': 'Strength',
        'subtitle': 'Build muscle and strength with proper nutrition',
        'image': 'meat',
      },
      {
        'title': 'Weight Loss',
        'subtitle': 'Achieve your ideal weight with balanced meals',
        'image': 'vegetable',
      },
      {
        'title': 'Energy',
        'subtitle': 'Boost your daily energy with the right foods',
        'image': 'fruit',
      },
    ];

    return SizedBox(
      height: 180,
      child: OverlappingCardsView(
        overlap: 60,
        cardWidth: MediaQuery.of(context).size.width * 0.7,
        cardHeight: 180,
        children: List.generate(
          programs.length,
          (index) => _buildProgramCard(
            context,
            programs[index]['title']!,
            programs[index]['subtitle']!,
            programs[index]['image']!,
            colors[index % colors.length],
            index,
          ),
        ),
      ),
    );
  }
}
