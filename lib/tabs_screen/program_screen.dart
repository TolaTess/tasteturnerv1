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
import '../pages/program_progress_screen.dart';
import '../service/chat_controller.dart';
import '../service/program_service.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/goal_diet_widget.dart';
import '../widgets/card_overlap.dart';
import '../widgets/program_detail_widget.dart';

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
  final GlobalKey _addFeaturedButtonKey = GlobalKey();
  final GlobalKey _addTastyAIButtonKey = GlobalKey();
  final GlobalKey _addProgramButtonKey = GlobalKey();
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
    // Load user's enrolled programs
    _programService.loadUserPrograms();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddMealTutorial();
    });
  }

  void _showAddMealTutorial() {
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'program_screen_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'add_featured_button',
          message: 'Tap here to view your featured meal!',
          targetKey: _addFeaturedButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_tasty_ai_button',
          message: 'Tap here to view your Tasty AI!',
          targetKey: _addTastyAIButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_program_button',
          message: 'Tap here to view your programs!',
          targetKey: _addProgramButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadProgramTypes() async {
    try {
      final snapshot = await firestore.collection('programs').get();
      final types = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'programId': doc.id,
          'image': data['image'] ?? '',
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'type': data['type'] ?? '',
          'goals': List<String>.from(data['goals'] ?? []),
          'guidelines': List<String>.from(data['guidelines'] ?? []),
          'tips': List<String>.from(data['tips'] ?? []),
          'duration': data['duration'] ?? '',
          'options': List<String>.from(data['options'] ?? []),
          'benefits': List<String>.from(data['benefits'] ?? []),
          'fitnessProgram':
              Map<String, dynamic>.from(data['fitnessProgram'] ?? {}),
          'mealPlan': Map<String, dynamic>.from(data['mealPlan'] ?? {}),
          'nutrition': Map<String, dynamic>.from(data['nutrition'] ?? {}),
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

  Future<void> _showProgramQuestionnaire(
      String programType, bool isDarkMode) async {
    final programData = programTypes.firstWhere(
      (program) => program['type'] == programType,
      orElse: () => throw Exception('Program type not found'),
    );

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProgramDetailWidget(
        program: programData,
      ),
    );

    if (result == 'joined') {
      setState(() => isLoading = true);
      try {
        // Join the program with default option since no options are available
        await _programService.joinProgram(programData['programId'], 'default');

        setState(() => isLoading = false);
        Get.snackbar(
          'Success',
          'You\'ve successfully joined the ${programData['name']} program!',
          backgroundColor: kAccentLight,
          colorText: kWhite,
        );
      } catch (e) {
        setState(() => isLoading = false);
        Get.snackbar(
          'Error',
          'Failed to join program. Please try again.',
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

  Widget _buildEnrolledProgramsSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return Obx(() {
      // Check if user has enrolled programs
      if (_programService.userPrograms.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ' Current Programs',
            style: textTheme.headlineMedium?.copyWith(
              color: isDarkMode ? kWhite : kDarkGrey,
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          ...List.generate(_programService.userPrograms.length, (index) {
            final program = _programService.userPrograms[index];
            return FutureBuilder<List<String>>(
              future: _programService.getProgramUsers(program.programId),
              builder: (context, snapshot) {
                final userCount = snapshot.data?.length ?? 0;

                return GestureDetector(
                  onTap: () async {
                    // Find complete program data from Firestore
                    try {
                      final programDoc = await firestore
                          .collection('programs')
                          .doc(program.programId)
                          .get();

                      if (programDoc.exists) {
                        final programData = {
                          'programId': program.programId,
                          ...programDoc.data()!,
                        };
                        Get.to(() => ProgramDetailWidget(program: programData));
                      } else {
                        // Fallback to basic program data
                        final programData = {
                          'programId': program.programId,
                          'name': program.name,
                          'description': program.description,
                          'type': program.type,
                          'duration': program.duration,
                          'goals': [],
                          'guidelines': [],
                          'tips': [],
                          'options': [],
                          'duration': program.duration,
                        };
                        Get.to(() => ProgramDetailWidget(program: programData));
                      }
                    } catch (e) {
                      Get.snackbar(
                        'Error',
                        'Unable to load program details',
                        backgroundColor: Colors.red,
                        colorText: kWhite,
                      );
                    }
                  },
                  key: index == 0
                      ? _addProgramButtonKey
                      : null, // Only apply key to first program to avoid GlobalKey conflicts
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(
                        bottom: getPercentageHeight(1, context)),
                    padding: EdgeInsets.all(getPercentageWidth(4, context)),
                    decoration: BoxDecoration(
                      color: isDarkMode ? kDarkGrey : kWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kAccent.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Program icon
                        Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(3, context)),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.fitness_center,
                            color: kAccent,
                            size: getIconScale(6, context),
                          ),
                        ),
                        SizedBox(width: getPercentageWidth(4, context)),

                        // Program details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                program.name,
                                style: textTheme.titleMedium?.copyWith(
                                  color: kAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                program.description,
                                style: textTheme.bodySmall?.copyWith(
                                  color: isDarkMode
                                      ? kWhite.withValues(alpha: 0.7)
                                      : kDarkGrey.withValues(alpha: 0.7),
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.8, context)),
                              Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    color: Colors.green,
                                    size: getIconScale(4, context),
                                  ),
                                  SizedBox(
                                      width: getPercentageWidth(1, context)),
                                  Text(
                                    '$userCount members',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(
                                      width: getPercentageWidth(3, context)),
                                  Icon(
                                    Icons.schedule,
                                    color: Colors.orange,
                                    size: getIconScale(4, context),
                                  ),
                                  SizedBox(
                                      width: getPercentageWidth(1, context)),
                                  Text(
                                    program.duration,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(
                                      width: getPercentageWidth(2.5, context)),
                                  GestureDetector(
                                    onTap: () {
                                      Get.to(() => ProgramProgressScreen(
                                            programId: program.programId,
                                            programName: program.name,
                                            programDescription:
                                                program.description,
                                            benefits: program.benefits,
                                            duration: program.duration,
                                          ));
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(
                                          getPercentageWidth(1.5, context)),
                                      decoration: BoxDecoration(
                                        color: Colors.purple
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Tracking',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.purple,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Leave program button
                        GestureDetector(
                          onTap: () async {
                            try {
                              await _programService
                                  .leaveProgram(program.programId);
                              Get.snackbar(
                                'Success',
                                'You\'ve left the ${program.name} program',
                                backgroundColor: kAccentLight,
                                colorText: kWhite,
                              );
                            } catch (e) {
                              Get.snackbar(
                                'Error',
                                'Failed to leave program',
                                backgroundColor: Colors.red,
                                colorText: kWhite,
                              );
                            }
                          },
                          child: Container(
                            padding:
                                EdgeInsets.all(getPercentageWidth(2, context)),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.exit_to_app,
                              color: Colors.red,
                              size: getIconScale(5, context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
          SizedBox(height: getPercentageHeight(2, context)),
        ],
      );
    });
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
                      key: _addFeaturedButtonKey,
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
              // AI Coach Section
              Text(
                'Speak to "Tasty" AI Coach',
                style: textTheme.displaySmall?.copyWith(
                  color: accent,
                  fontSize: getTextScale(7, context),
                  fontWeight: FontWeight.w200,
                ),
              ),
              SizedBox(height: getPercentageHeight(1.5, context)),
              ElevatedButton.icon(
                key: _addTastyAIButtonKey,
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
                        color: accent.withValues(alpha: 0.08),
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
              SizedBox(height: getPercentageHeight(2.5, context)),

              // Current enrolled programs section
              _buildEnrolledProgramsSection(context, textTheme, isDarkMode),

              Text(
                _programService.userPrograms.length > 1
                    ? 'Explore More Programs'
                    : 'Customize Your Program',
                style: textTheme.headlineMedium?.copyWith(
                  color: accent,
                ),
              ),
              SizedBox(height: getPercentageHeight(3, context)),
              Obx(() => SizedBox(
                    height: getPercentageHeight(25, context),
                    child: programTypes.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(
                              color: accent,
                            ),
                          )
                        : OverlappingCardsView(
                            cardWidth: getPercentageWidth(65, context),
                            cardHeight: getPercentageHeight(25, context),
                            isProgram: true,
                            overlap: 60,
                            padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(4, context),
                            ),
                            children: List.generate(
                              programTypes.length,
                              (index) => OverlappingCard(
                                title: programTypes[index]['name'] ?? '',
                                type: programTypes[index]['type'],
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
                                  isDarkMode,
                                ),
                                isProgram: true,
                              ),
                            ),
                          ),
                  )),
              SizedBox(height: getPercentageHeight(6, context)),
            ],
          ),
        ),
      ),
    );
  }
}
