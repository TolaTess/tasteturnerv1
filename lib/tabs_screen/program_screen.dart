import 'dart:async';

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
import '../service/buddy_chat_controller.dart';
import '../service/program_service.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/card_overlap.dart';
import '../widgets/program_detail_widget.dart';
import '../widgets/info_icon_widget.dart';
import '../widgets/tutorial_blocker.dart';
import '../helper/onboarding_prompt_helper.dart';
import '../widgets/onboarding_prompt.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  late final ProgramService _programService;
  bool isLoading = false;
  String aiCoachResponse = '';
  bool showCaloriesAndGoal = true;
  RxList<Map<String, dynamic>> programTypes = <Map<String, dynamic>>[].obs;
  RxBool _programsLoaded =
      false.obs; // Track if programs have been loaded (even if empty)
  final GlobalKey _addTastyAIButtonKey = GlobalKey();
  final GlobalKey _addProgramButtonKey = GlobalKey();
  bool _showDietaryPrompt = false;
  Map<String, int> _programUserCounts = {};

  @override
  void initState() {
    super.initState();

    // Initialize ProgramService using Get.find() with try-catch fallback
    _programService =
        ProgramService.instance; // Instance getter handles registration

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
          tutorialId: 'add_tasty_ai_button',
          message: 'Tap here to speak to Sous Chef Turner!',
          targetKey: _addTastyAIButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_program_button',
          message: 'Tap here to view available menus, Chef!',
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

  /// Load program details from Firestore
  Future<Map<String, dynamic>?> _loadProgramDetails(String programId) async {
    try {
      final programDoc =
          await firestore.collection('programs').doc(programId).get();

      if (programDoc.exists) {
        return {
          'programId': programId,
          ...programDoc.data()!,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error loading program details for $programId: $e');
      return null;
    }
  }

  /// Show error snackbar with consistent styling
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red,
      colorText: kWhite,
      duration: const Duration(seconds: 3),
    );
  }

  /// Show success snackbar with consistent styling
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    Get.snackbar(
      'Success',
      message,
      backgroundColor: kAccentLight,
      colorText: kWhite,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _loadProgramTypes() async {
    try {
      // Get all programs and filter client-side to handle missing isPrivate field
      // Filter out: isPrivate == true OR type == 'custom'
      final snapshot = await firestore.collection('programs').get().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Timeout loading programs from Firestore');
          throw TimeoutException('Loading programs timed out');
        },
      );

      // Filter out private programs and custom type programs
      final types = snapshot.docs.where((doc) {
        final data = doc.data();
        final isPrivate = data['isPrivate'] as bool? ?? false;
        final type = data['type']?.toString().toLowerCase() ?? '';
        // Exclude: private programs OR custom type programs
        return !isPrivate && type != 'custom';
      }).map((doc) {
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
          'portionDetails':
              Map<String, dynamic>.from(data['portionDetails'] ?? {}),
          'routine': data['routine'] != null
              ? List<dynamic>.from(data['routine'])
              : [],
          'notAllowed': List<String>.from(data['notAllowed'] ?? []),
          'programDetails': List<String>.from(data['programDetails'] ?? []),
        };
      }).toList();

      debugPrint(
          'Loaded ${types.length} public programs from ${snapshot.docs.length} total (excluding private and custom type)');

      if (mounted) {
        // Always set programTypes, even if empty, to stop loading indicator
        programTypes.value = types;
        _programsLoaded.value = true; // Mark as loaded
        // Load user counts for all programs in batch (non-blocking)
        if (types.isNotEmpty) {
          _loadProgramUserCounts(types);
        }
      }
    } on TimeoutException {
      debugPrint('Timeout loading program types');
      if (mounted) {
        _showErrorSnackbar(
            'Loading programs timed out, Chef. Please check your connection.');
        // Set fallback programs to stop loading indicator
        programTypes.value = [
          {
            'programId': 'fallback_vitality',
            'type': 'vitality',
            'name': 'Vitality',
            'image': 'salad',
            'description': 'A program focused on longevity and healthy eating',
            'options': ['beginner', 'intermediate', 'advanced'],
            'goals': [],
            'guidelines': [],
            'tips': [],
            'duration': '30 days',
            'benefits': [],
            'fitnessProgram': {},
            'mealPlan': {},
            'nutrition': {},
          },
          {
            'programId': 'fallback_challenge',
            'type': 'Days Challenge',
            'name': '7 Days Challenge',
            'image': 'herbs',
            'description': 'A program focused on longevity and healthy eating',
            'options': ['beginner', 'intermediate', 'advanced'],
            'goals': [],
            'guidelines': [],
            'tips': [],
            'duration': '7 days',
            'benefits': [],
            'fitnessProgram': {},
            'mealPlan': {},
            'nutrition': {},
          },
        ];
        _programsLoaded.value = true; // Mark as loaded even with fallback
      }
    } catch (e) {
      debugPrint('Error loading program types: $e');
      if (mounted) {
        _showErrorSnackbar(
            'Couldn\'t load the program menu, Chef. Please try again.');
        // Fallback to default programs if loading fails
        programTypes.value = [
          {
            'programId': 'fallback_vitality',
            'type': 'vitality',
            'name': 'Vitality',
            'image': 'salad',
            'description': 'A program focused on longevity and healthy eating',
            'options': ['beginner', 'intermediate', 'advanced'],
            'goals': [],
            'guidelines': [],
            'tips': [],
            'duration': '30 days',
            'benefits': [],
            'fitnessProgram': {},
            'mealPlan': {},
            'nutrition': {},
          },
          {
            'programId': 'fallback_challenge',
            'type': 'Days Challenge',
            'name': '7 Days Challenge',
            'image': 'herbs',
            'description': 'A program focused on longevity and healthy eating',
            'options': ['beginner', 'intermediate', 'advanced'],
            'goals': [],
            'guidelines': [],
            'tips': [],
            'duration': '7 days',
            'benefits': [],
            'fitnessProgram': {},
            'mealPlan': {},
            'nutrition': {},
          },
        ];
        _programsLoaded.value = true; // Mark as loaded even with fallback
      }
    }
  }

  Future<void> _loadProgramUserCounts(
      List<Map<String, dynamic>> programs) async {
    if (!mounted) return;

    try {
      final Map<String, int> counts = {};
      try {
        await Future.wait(
          programs.map((program) async {
            final programId = program['programId'] as String?;
            if (programId != null && programId.isNotEmpty) {
              try {
                final users = await _programService.getProgramUsers(programId);
                counts[programId] = users.length;
              } catch (e) {
                debugPrint(
                    'Error loading user count for program $programId: $e');
                counts[programId] = 0;
              }
            }
          }),
        ).timeout(const Duration(seconds: 30));
      } on TimeoutException {
        debugPrint('Warning: Program user counts loading timed out');
      }

      if (mounted) {
        setState(() {
          _programUserCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('Error loading program user counts: $e');
      // Fail silently - not critical for main functionality
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
          _showErrorSnackbar('Menu not available, Chef. Please try again.');
        }
        return;
      }

      final programId = programData['programId'] as String?;
      if (programId == null || programId.isEmpty) {
        if (mounted) {
          _showErrorSnackbar('Invalid menu data, Chef. Please try again.');
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

      // Load full program details before showing dialog
      final fullProgramData = await _loadProgramDetails(programId);
      final programToShow = fullProgramData ?? programData;

      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ProgramDetailWidget(
          program: programToShow,
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
            _showSuccessSnackbar(
                'You\'ve joined the ${programData['name'] ?? 'menu'} menu, Chef!');
          }
        } catch (e) {
          if (mounted) {
            setState(() => isLoading = false);
            final errorMessage = e.toString().contains('already enrolled')
                ? 'You are already enrolled in this menu, Chef'
                : 'Couldn\'t join menu, Chef. Please try again.';
            _showErrorSnackbar(errorMessage);
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _showProgramQuestionnaire: $e');
      if (mounted) {
        _showErrorSnackbar(
            'Something went wrong in the kitchen, Chef. Please try again.');
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
      final userDiet = userService.currentUser.value?.settings['dietPreference']
              ?.toString() ??
          'balanced';
      final userGoal =
          userService.currentUser.value?.settings['fitnessGoal']?.toString() ??
              'Healthy Eating';
      final prompt =
          'Give me a meal plan strategy for user $userName with a $userDiet diet with the goal to $userGoal. User name is $userName';

      final response = await geminiService.getResponse(
        prompt,
        maxTokens: 1024,
        role: buddyAiRole,
      );

      if (!mounted) return;

      // Filter out any AI instructions that may have leaked through
      final cleanedResponse =
          BuddyChatController.filterSystemInstructions(response);

      setState(() {
        aiCoachResponse = cleanedResponse;
        isLoading = false;
      });

      // Save both question and response to buddy chat
      final chatId = userService.buddyId;
      final userId = userService.userId ?? '';
      if (chatId != null && chatId.isNotEmpty && userId.isNotEmpty) {
        try {
          await BuddyChatController.saveMessageToFirestore(
            chatId: chatId,
            content: prompt,
            senderId: userId,
          );
          // Save the cleaned response, not the raw one
          await BuddyChatController.saveMessageToFirestore(
            chatId: chatId,
            content: cleanedResponse,
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
        aiCoachResponse =
            'Apologies, Chef. I dozed off for a moment. Please try again.';
      });

      _showErrorSnackbar('Couldn\'t reach Turner, Chef. Please try again.');
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
            ' Current Menu, Chef',
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
                final programData =
                    await _loadProgramDetails(program.programId);
                if (programData != null && mounted) {
                  Get.to(() => ProgramDetailWidget(
                        program: programData,
                        isEnrolled: true,
                      ));
                } else if (mounted) {
                  // Fallback to basic program data
                  final fallbackData = {
                    'programId': program.programId,
                    'name': program.name,
                    'description': program.description,
                    'type': program.type,
                    'duration': program.duration,
                    'goals': [],
                    'guidelines': [],
                    'tips': [],
                    'options': [],
                    'benefits': program.benefits,
                    'notAllowed': program.notAllowed,
                    'programDetails': program.programDetails,
                    'portionDetails': program.portionDetails,
                    'routine': [],
                    'fitnessProgram': {},
                  };
                  Get.to(() => ProgramDetailWidget(
                        program: fallbackData,
                      ));
                }
              },
              child: Container(
                width: double.infinity,
                margin:
                    EdgeInsets.only(bottom: getPercentageHeight(1, context)),
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
                      padding: EdgeInsets.all(getPercentageWidth(3, context)),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
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
                          SizedBox(height: getPercentageHeight(0.5, context)),
                          Text(
                            program.description,
                            style: textTheme.bodySmall?.copyWith(
                              color: isDarkMode
                                  ? kWhite.withValues(alpha: 0.7)
                                  : kDarkGrey.withValues(alpha: 0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: getPercentageHeight(0.8, context)),
                          Row(
                            children: [
                              // Stats (people + duration) take remaining space and
                              // shrink if needed to avoid horizontal overflow.
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.people,
                                      color: Colors.green,
                                      size: getIconScale(4, context),
                                    ),
                                    SizedBox(
                                        width: getPercentageWidth(1, context)),
                                    Flexible(
                                      child: Text(
                                        '$userCount chefs',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
                                    Flexible(
                                      child: Text(
                                        program.duration,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: getPercentageWidth(2.5, context)),
                              GestureDetector(
                                onTap: () {
                                  Get.to(
                                    () => ProgramProgressScreen(
                                      programId: program.programId,
                                      programName: program.name,
                                      programDescription: program.description,
                                      benefits: program.benefits,
                                      duration: program.duration,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.all(
                                    getPercentageWidth(1.5, context),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'View Progress',
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

                    // Archive program button
                    PopupMenuButton<String>(
                      color: isDarkMode ? kDarkGrey : kWhite,
                      icon: Container(
                        padding: EdgeInsets.all(getPercentageWidth(2, context)),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? kDarkGrey.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: isDarkMode ? kWhite : kDarkGrey,
                          size: getIconScale(5, context),
                        ),
                      ),
                      onSelected: (value) async {
                        if (value == 'archive') {
                          try {
                            await _programService
                                .archiveProgram(program.programId);
                            _showSuccessSnackbar(
                                '${program.name} has been archived, Chef');
                          } catch (e) {
                            _showErrorSnackbar(
                                'Couldn\'t archive menu, Chef: ${e.toString()}');
                          }
                        } else if (value == 'leave') {
                          try {
                            await _programService
                                .leaveProgram(program.programId);
                            _showSuccessSnackbar(
                                'You\'ve left the ${program.name} menu, Chef');
                          } catch (e) {
                            _showErrorSnackbar(
                                'Couldn\'t leave menu, Chef: ${e.toString()}');
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive,
                                  color: isDarkMode ? kWhite : kDarkGrey),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Text('Archive'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'leave',
                          child: Row(
                            children: [
                              Icon(Icons.exit_to_app, color: kRed),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Text('Leave Menu', style: TextStyle(color: kRed)),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildArchivedProgramsSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return Obx(() {
      // Check if user has archived programs
      if (_programService.archivedPrograms.isEmpty) {
        return const SizedBox.shrink();
      }

      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: kAccent,
          iconColor: kAccent,
          tilePadding: EdgeInsets.zero,
          title: Text(
            'Archived Menus',
            style: textTheme.headlineMedium?.copyWith(
              color: isDarkMode
                  ? kWhite.withValues(alpha: 0.7)
                  : kDarkGrey.withValues(alpha: 0.7),
            ),
          ),
          children:
              List.generate(_programService.archivedPrograms.length, (index) {
            final program = _programService.archivedPrograms[index];

            return GestureDetector(
              onTap: () async {
                final programData =
                    await _loadProgramDetails(program.programId);
                if (programData != null && mounted) {
                  Get.to(() => ProgramDetailWidget(
                        program: programData,
                        isEnrolled: true,
                      ));
                } else if (mounted) {
                  _showErrorSnackbar('Unable to load menu details, Chef');
                }
              },
              child: Container(
                width: double.infinity,
                margin:
                    EdgeInsets.only(bottom: getPercentageHeight(1, context)),
                padding: EdgeInsets.all(getPercentageWidth(4, context)),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? kDarkGrey.withValues(alpha: 0.5)
                      : kWhite.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Program icon
                    Container(
                      padding: EdgeInsets.all(getPercentageWidth(3, context)),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.archive,
                        color: Colors.grey,
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
                              color: isDarkMode
                                  ? kWhite.withValues(alpha: 0.7)
                                  : kDarkGrey.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(0.5, context)),
                          Text(
                            program.description,
                            style: textTheme.bodySmall?.copyWith(
                              color: isDarkMode
                                  ? kWhite.withValues(alpha: 0.5)
                                  : kDarkGrey.withValues(alpha: 0.5),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Unarchive button
                    GestureDetector(
                      onTap: () async {
                        try {
                          await _programService
                              .unarchiveProgram(program.programId);
                          _showSuccessSnackbar(
                              '${program.name} has been unarchived, Chef');
                        } catch (e) {
                          _showErrorSnackbar(
                              'Couldn\'t unarchive menu, Chef: ${e.toString()}');
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(getPercentageWidth(2, context)),
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.unarchive,
                          color: kAccent,
                          size: getIconScale(5, context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      );
    });
  }

  /// Build the AppBar
  PreferredSizeWidget _buildAppBar(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    return AppBar(
      backgroundColor: kAccent,
      toolbarHeight: getPercentageHeight(10, context),
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'A Menu Just for You, Chef',
            style: textTheme.displayMedium
                ?.copyWith(fontSize: getTextScale(5, context)),
          ),
          SizedBox(width: getPercentageWidth(2, context)),
          InfoIconWidget(
            title: 'Chef\'s Menu Programs',
            description:
                'Step into a tailored kitchen journey, Chef! Join menus designed to sharpen your culinary health game.',
            details: const [
              {
                'icon': Icons.fitness_center,
                'title': 'Personalized for You, Chef',
                'description':
                    'Every menu is prepped to fit your unique taste and health goals, Chef.',
                'color': kAccent,
              },
              {
                'icon': Icons.track_changes,
                'title': 'Track Your Progress',
                'description':
                    'Check your culinary progress right on your Chef Dashboard, with easy-to-digest charts and milestones.',
                'color': kAccent,
              },
              {
                'icon': Icons.schedule,
                'title': 'Choose Your Timing',
                'description':
                    'Menus from a quick 7-day boost to a long-term chef commitment—whatever fits your schedule, Chef.',
                'color': kAccent,
              },
            ],
            iconColor: isDarkMode ? kWhite : kDarkGrey,
            tooltip: 'Menu Details for Chefs',
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final user = userService.currentUser.value;
    final String userDiet =
        user?.settings['dietPreference']?.toString() ?? 'Balanced';
    final String userGoal =
        user?.settings['fitnessGoal']?.toString() ?? 'Healthy Eating';
    final textTheme = Theme.of(context).textTheme;
    final fontSize = getTextScale(5, context);
    return Scaffold(
      appBar: _buildAppBar(context, isDarkMode, textTheme),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDarkMode
                  ? 'assets/images/background/imagedark.jpeg'
                  : 'assets/images/background/imagelight.jpeg',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDarkMode
                  ? Colors.black.withOpacity(0.5)
                  : Colors.white.withOpacity(0.5),
              isDarkMode ? BlendMode.darken : BlendMode.lighten,
            ),
          ),
        ),
        child: BlockableSingleChildScrollView(
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
                    title: "Better Dish Recommendations, Chef",
                    message:
                        "Tell us your dietary preferences and allergies, Chef, so we can suggest dishes that are perfect for your station",
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
                                fontWeight: FontWeight.w300,
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
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getPercentageHeight(2.5, context)),

                Center(
                  child: Text(
                    'See the Cookbook for $userDiet meals, Chef',
                    maxLines: 2,
                    style: textTheme.headlineMedium?.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w400,
                      fontSize: getTextScale(5, context),
                      overflow: TextOverflow.ellipsis,
                    ),
                    textAlign: TextAlign.center,
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
                  label: Text('Cookbook',
                      style: textTheme.labelLarge?.copyWith(color: kWhite)),
                ),
                SizedBox(height: getPercentageHeight(1.5, context)),

                // AI Coach Section
                Text(
                  'Speak to Sous Chef Turner',
                  style: textTheme.displaySmall?.copyWith(
                    color: kAccent,
                    fontSize: getTextScale(7, context),
                    fontWeight: FontWeight.w200,
                  ),
                ),
                SizedBox(height: getPercentageHeight(1.5, context)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.lightbulb, color: kWhite),
                  label: Text(
                    key: _addTastyAIButtonKey,
                    'Get Station Guidance',
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
                  Center(child: CircularProgressIndicator(color: kAccent)),
                ],
                if (aiCoachResponse.isNotEmpty) ...[
                  SizedBox(height: getPercentageHeight(2, context)),
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(getPercentageWidth(3, context)),
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.08),
                        ),
                        child: Text(
                          aiCoachResponse.contains('Error')
                              ? 'Apologies, Chef, I dozed off for a moment. Please try again.'
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
                                  () => const TastyScreen(screen: 'buddy'),
                                  arguments: {
                                    'mealPlanMode': false,
                                  },
                                );
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
                                Get.to(
                                  () => const TastyScreen(screen: 'buddy'),
                                  arguments: {
                                    'mealPlanMode': true,
                                  },
                                );
                              },
                              child: Text(
                                'Generate a dish',
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

                _buildArchivedProgramsSection(context, textTheme, isDarkMode),

                SizedBox(height: getPercentageHeight(2.5, context)),

                Obx(() => Text(
                      key: _addProgramButtonKey,
                      _programService.userPrograms.length > 1
                          ? 'Explore More Menus, Chef'
                          : _programService.userPrograms.length == 1
                              ? 'Explore More Menus, Chef'
                              : 'Choose a Menu, Chef',
                      style: textTheme.headlineMedium?.copyWith(
                        color: kAccent,
                      ),
                    )),
                SizedBox(height: getPercentageHeight(3, context)),
                Obx(() {
                  // Show loading indicator only if programs haven't been loaded yet
                  final isLoading = !_programsLoaded.value;

                  return SizedBox(
                    height: getPercentageHeight(25, context),
                    child: isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: kAccent,
                                ),
                                SizedBox(
                                    height: getPercentageHeight(2, context)),
                                Text(
                                  'Preparing menus...',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : programTypes.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: getIconScale(10, context),
                                      color:
                                          isDarkMode ? kLightGrey : kDarkGrey,
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(2, context)),
                                    Text(
                                      'No menus on the menu, Chef',
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: isDarkMode ? kWhite : kDarkGrey,
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(1, context)),
                                    Text(
                                      'Check back later for new menus, Chef',
                                      style: textTheme.bodySmall?.copyWith(
                                        color:
                                            isDarkMode ? kLightGrey : kDarkGrey,
                                      ),
                                    ),
                                  ],
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
                                      subtitle:
                                          programData['description'] ?? '',
                                      color: colors[index % colors.length],
                                      imageUrl: programData['image'] != null
                                          ? 'assets/images/${programData['image']}.jpg'
                                          : null,
                                      width: getPercentageWidth(70, context),
                                      height: getPercentageHeight(25, context),
                                      index: index,
                                      onTap: () async {
                                        final programId =
                                            programData['programId'] as String?;
                                        if (programId == null ||
                                            programId.isEmpty) {
                                          if (mounted) {
                                            _showErrorSnackbar(
                                                'Invalid menu data, Chef. Please try again.');
                                          }
                                          return;
                                        }

                                        final loadedProgramData =
                                            await _loadProgramDetails(
                                                programId);
                                        if (loadedProgramData != null &&
                                            mounted) {
                                          Get.to(() => ProgramDetailWidget(
                                                program: loadedProgramData,
                                                isEnrolled: isEnrolled,
                                              ));
                                        } else if (mounted) {
                                          // Fallback to basic program data
                                          final fallbackData = {
                                            'programId': programId,
                                            'name': programData['name'] ?? '',
                                            'description':
                                                programData['description'] ??
                                                    '',
                                            'type': programData['type'],
                                            'duration':
                                                programData['duration'] ?? '',
                                            'goals': [],
                                            'guidelines': [],
                                            'tips': [],
                                            'options': [],
                                            'benefits':
                                                programData['benefits'] ?? [],
                                            'notAllowed':
                                                programData['notAllowed'] ?? [],
                                            'programDetails':
                                                programData['programDetails'] ??
                                                    {},
                                            'portionDetails':
                                                programData['portionDetails'] ??
                                                    {},
                                            'routine': [],
                                            'fitnessProgram': {},
                                          };
                                          Get.to(() => ProgramDetailWidget(
                                                program: fallbackData,
                                                isEnrolled: isEnrolled,
                                              ));
                                        }
                                      },
                                      isProgram: true,
                                      isEnrolled: isEnrolled,
                                    );
                                  },
                                ),
                              ),
                  );
                }),
                SizedBox(height: getPercentageHeight(6, context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
