import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/screens/buddy_screen.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/dietary_choose_screen.dart';
import '../pages/edit_goal.dart';
import '../pages/program_progress_screen.dart';
import '../screens/recipes_list_category_screen.dart';
import '../service/chat_controller.dart';
import '../service/program_service.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/card_overlap.dart';
import '../widgets/program_detail_widget.dart';
import '../widgets/info_icon_widget.dart';
import '../helper/onboarding_prompt_helper.dart';
import '../widgets/onboarding_prompt.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  late final ProgramService _programService;
  String selectedDiet =
      userService.currentUser.value?.settings['dietPreference'] ?? 'balanced';
  String selectedGoal =
      userService.currentUser.value?.settings['fitnessGoal'] ??
          'Healthy Eating';
  bool isLoading = false;
  String aiCoachResponse = '';
  bool showCaloriesAndGoal = true;
  RxList<Map<String, dynamic>> programTypes = <Map<String, dynamic>>[].obs;
  final GlobalKey _addFeaturedButtonKey = GlobalKey();
  final GlobalKey _addTastyAIButtonKey = GlobalKey();
  final GlobalKey _addProgramButtonKey = GlobalKey();
  bool _showDietaryPrompt = false;
  Map<String, int> _programUserCounts = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize ProgramService using Get.find() with try-catch fallback
    try {
      _programService = Get.find<ProgramService>();
    } catch (e) {
      // If not found, put it
      _programService = Get.put(ProgramService());
    }

    _loadProgramTypes();
    // Load user's enrolled programs
    _programService.loadUserPrograms();
    _checkDietaryPrompt();
    loadShowCaloriesPref().then((value) {
      if (mounted) {
        setState(() {
          showCaloriesAndGoal = value;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddMealTutorial();
    });
  }

  Future<void> _checkDietaryPrompt() async {
    final shouldShow = await OnboardingPromptHelper.shouldShowDietaryPrompt();
    if (mounted) {
      setState(() {
        _showDietaryPrompt = shouldShow;
      });
    }
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

      if (mounted) {
        programTypes.value = types;
        // Load user counts for all programs in batch
        _loadProgramUserCounts(types);
      }
    } catch (e) {
      debugPrint('Error loading program types: $e');
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to load programs. Please try again.',
          backgroundColor: Colors.red,
          colorText: kWhite,
        );
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
  }

  Future<void> _loadProgramUserCounts(List<Map<String, dynamic>> programs) async {
    try {
      final Map<String, int> counts = {};
      await Future.wait(
        programs.map((program) async {
          final programId = program['programId'] as String?;
          if (programId != null && programId.isNotEmpty) {
            try {
              final users = await _programService.getProgramUsers(programId);
              counts[programId] = users.length;
            } catch (e) {
              debugPrint('Error loading user count for program $programId: $e');
              counts[programId] = 0;
            }
          }
        }),
      );
      if (mounted) {
        setState(() {
          _programUserCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('Error loading program user counts: $e');
    }
  }

  Future<void> _showProgramQuestionnaire(
      String programType, bool isDarkMode) async {
    try {
      final programData = programTypes.firstWhereOrNull(
        (program) => program['type'] == programType,
      );

      if (programData == null) {
        if (mounted) {
          Get.snackbar(
            'Error',
            'Program not found. Please try again.',
            backgroundColor: Colors.red,
            colorText: kWhite,
          );
        }
        return;
      }

      final programId = programData['programId'] as String?;
      if (programId == null || programId.isEmpty) {
        if (mounted) {
          Get.snackbar(
            'Error',
            'Invalid program data. Please try again.',
            backgroundColor: Colors.red,
            colorText: kWhite,
          );
        }
        return;
      }

      // Check if user is already enrolled in this program
      final isEnrolled = _programService.userPrograms.any(
        (program) => program.programId == programId,
      );

      if (isEnrolled) {
        // User is already enrolled, show enrolled status or redirect to progress
        final enrolledProgram = _programService.userPrograms.firstWhere(
          (program) => program.programId == programId,
        );

        Get.to(() => ProgramProgressScreen(
              programId: enrolledProgram.programId,
              programName: enrolledProgram.name,
              programDescription: enrolledProgram.description,
              benefits: enrolledProgram.benefits,
              duration: enrolledProgram.duration,
            ));
        return;
      }

      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ProgramDetailWidget(
          program: programData,
          isEnrolled: isEnrolled,
        ),
      );

      if (result == 'joined' && mounted) {
        setState(() => isLoading = true);
        try {
          // Join the program with default option since no options are available
          await _programService.joinProgram(programId, 'default');

          if (mounted) {
            setState(() => isLoading = false);
            Get.snackbar(
              'Success',
              'You\'ve successfully joined the ${programData['name'] ?? 'program'} program!',
              backgroundColor: kAccentLight,
              colorText: kWhite,
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => isLoading = false);
            final errorMessage = e.toString().contains('already enrolled')
                ? 'You are already enrolled in this program'
                : 'Failed to join program. Please try again.';
            Get.snackbar(
              'Error',
              errorMessage,
              backgroundColor: Colors.red,
              colorText: kWhite,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _showProgramQuestionnaire: $e');
      if (mounted) {
        Get.snackbar(
          'Error',
          'An error occurred. Please try again.',
          backgroundColor: Colors.red,
          colorText: kWhite,
        );
      }
    }
  }

  Future<void> askAICoach() async {
    if (!canUseAI()) {
      final isDarkMode = getThemeProvider(context).isDarkMode;
      showPremiumRequiredDialog(context, isDarkMode);
      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = true;
      aiCoachResponse = '';
    });

    try {
      final userName = userService.currentUser.value?.displayName ?? 'User';
      final prompt =
          'Give me a meal plan strategy for user $userName with a $selectedDiet diet with the goal to $selectedGoal. User name is $userName';
      
      final response = await geminiService.getResponse(
        prompt,
        maxTokens: 1024,
        role: buddyAiRole,
      );

      if (!mounted) return;

      setState(() {
        aiCoachResponse = response;
        isLoading = false;
      });

      // Save both question and response to buddy chat
      final chatId = userService.buddyId;
      final userId = userService.userId ?? '';
      if (chatId != null && chatId.isNotEmpty && userId.isNotEmpty) {
        try {
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
        } catch (e) {
          debugPrint('Error saving chat messages: $e');
          // Don't show error to user as the main functionality worked
        }
      }
    } catch (e) {
      debugPrint('Error in askAICoach: $e');
      if (!mounted) return;

      setState(() {
        isLoading = false;
        aiCoachResponse = 'Sorry, I encountered an error. Please try again later.';
      });

      Get.snackbar(
        'Error',
        'Failed to get AI coach response. Please try again.',
        backgroundColor: Colors.red,
        colorText: kWhite,
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
            key: _addProgramButtonKey,
            ' Current Programs',
            style: textTheme.headlineMedium?.copyWith(
              color: isDarkMode ? kWhite : kDarkGrey,
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          ...List.generate(_programService.userPrograms.length, (index) {
            final program = _programService.userPrograms[index];
            final userCount = _programUserCounts[program.programId] ?? 0;

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
                        Get.to(() => ProgramDetailWidget(
                              program: programData,
                              isEnrolled: true,
                            ));
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
                        };
                        Get.to(() => ProgramDetailWidget(
                              program: programData,
                            ));
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
    final fontSize = getTextScale(5, context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccent,
        toolbarHeight: getPercentageHeight(10, context),
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'A Program Just for You',
              style: textTheme.displayMedium
                  ?.copyWith(fontSize: getTextScale(5.8, context)),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            InfoIconWidget(
              title: 'Nutrition Programs',
              description:
                  'Join personalized programs to achieve your health goals',
              details: const [
                {
                  'icon': Icons.fitness_center,
                  'title': 'Personalized Programs',
                  'description':
                      'Programs tailored to your diet preferences and fitness goals',
                  'color': kAccent,
                },
                {
                  'icon': Icons.track_changes,
                  'title': 'Progress Tracking',
                  'description':
                      'Monitor your progress with visual charts and milestones',
                  'color': kAccent,
                },
                // {
                //   'icon': Icons.people,
                //   'title': 'Community Support',
                //   'description': 'Join others on similar health journeys',
                //   'color': kAccent,
                // },
                {
                  'icon': Icons.schedule,
                  'title': 'Flexible Duration',
                  'description':
                      'Programs ranging from 7 days to long-term commitments',
                  'color': kAccent,
                },
              ],
              iconColor: isDarkMode ? kWhite : kDarkGrey,
              tooltip: 'Program Information',
            ),
          ],
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
              // Dietary prompt
              if (_showDietaryPrompt)
                OnboardingPrompt(
                  title: "Better Meal Recommendations",
                  message:
                      "Tell us your dietary preferences and allergies so we can suggest meals that are perfect for you",
                  actionText: "Set Preferences",
                  onAction: () {
                    setState(() {
                      _showDietaryPrompt = false;
                    });
                    // Navigate to dietary choose screen
                    Get.to(() => const ChooseDietScreen());
                  },
                  onDismiss: () {
                    setState(() {
                      _showDietaryPrompt = false;
                    });
                  },
                  promptType: 'banner',
                  storageKey: OnboardingPromptHelper.PROMPT_DIETARY_SHOWN,
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (showCaloriesAndGoal) ...[
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Get.to(() => const NutritionSettingsPage(
                                    isHealthExpand: true,
                                  ));
                            },
                            child: Text(
                              'Your Diet: ',
                              style: textTheme.displaySmall?.copyWith(
                                color: kAccent,
                                fontSize: getTextScale(5, context),
                              ),
                            ),
                          ),
                          Text(
                            userDiet.isNotEmpty
                                ? capitalizeFirstLetter(userDiet)
                                : 'Not set',
                            style: textTheme.titleLarge?.copyWith(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w100,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(width: getPercentageWidth(4, context)),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        if (showCaloriesAndGoal)
                          SizedBox(width: getPercentageWidth(1, context)),
                        if (showCaloriesAndGoal)
                          GestureDetector(
                            onTap: () {
                              Get.to(() => const NutritionSettingsPage(
                                    isHealthExpand: true,
                                  ));
                            },
                            child: Text(
                              'Goal: ',
                              style: textTheme.displaySmall?.copyWith(
                                color: kAccent,
                                fontSize: getTextScale(5.5, context),
                              ),
                            ),
                          ),
                        if (showCaloriesAndGoal)
                          Text(
                            userGoal.isNotEmpty
                                ? userGoal.toLowerCase() == "lose weight"
                                    ? 'Weight Loss'
                                    : userGoal.toLowerCase() == "muscle gain"
                                        ? 'Muscle Gain'
                                        : capitalizeFirstLetter(userGoal)
                                : 'Not set',
                            style: textTheme.titleLarge?.copyWith(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w100,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: getPercentageHeight(2.5, context)),

              Text(
                'See Recipes for your $userDiet diet',
                maxLines: 2,
                style: textTheme.headlineMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w200,
                  fontSize: getTextScale(5, context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: getPercentageHeight(1.5, context)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPink,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Get.to(() => RecipeListCategory(
                        index: 1,
                        searchIngredient: userDiet.toLowerCase(),
                        screen: 'categories',
                        isNoTechnique: true,
                      ));
                },
                icon: const Icon(Icons.restaurant, color: kWhite),
                label: Text('Recipes',
                    style: textTheme.labelLarge?.copyWith(color: kWhite)),
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
              SizedBox(height: getPercentageHeight(1.5, context)),
              ElevatedButton.icon(
                icon: const Icon(Icons.lightbulb, color: kWhite),
                label: Text(
                  key: _addTastyAIButtonKey,
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
                        aiCoachResponse.contains('Error')
                            ? 'Sorry, I snoozed for a moment. Please try again.'
                            : aiCoachResponse,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
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

              // Create Custom Plan Button
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, color: kWhite),
                label: Text(
                  'Create Custom Plan with AI',
                  style: textTheme.labelLarge?.copyWith(color: kWhite),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(5, context),
                    vertical: getPercentageHeight(1.5, context),
                  ),
                ),
                onPressed: () {
                  if (!canUseAI()) {
                    showPremiumRequiredDialog(context, isDarkMode);
                    return;
                  }
                  Get.to(() => const TastyScreen(screen: 'message'),
                      arguments: {'planningMode': true});
                },
              ),
              SizedBox(height: getPercentageHeight(2, context)),

              // Current enrolled programs section
              _buildEnrolledProgramsSection(context, textTheme, isDarkMode),

              Obx(() => Text(
                    _programService.userPrograms.length > 1
                        ? 'Explore More Programs'
                        : _programService.userPrograms.length == 1
                            ? 'Explore More Programs'
                            : 'Customize Your Program',
                    style: textTheme.headlineMedium?.copyWith(
                      color: accent,
                    ),
                  )),
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
                              (index) {
                                final programData = programTypes[index];
                                final isEnrolled =
                                    _programService.userPrograms.any(
                                  (program) =>
                                      program.programId ==
                                      programData['programId'],
                                );

                                return OverlappingCard(
                                  title: programData['name'] ?? '',
                                  type: programData['type'],
                                  subtitle: programData['description'] ?? '',
                                  color: colors[index % colors.length],
                                  imageUrl: programData['image'] != null
                                      ? 'assets/images/${programData['image']}.jpg'
                                      : null,
                                  width: getPercentageWidth(70, context),
                                  height: getPercentageHeight(25, context),
                                  index: index,
                                  onTap: () => _showProgramQuestionnaire(
                                    programData['type'],
                                    isDarkMode,
                                  ),
                                  isProgram: true,
                                  isEnrolled: isEnrolled,
                                );
                              },
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
