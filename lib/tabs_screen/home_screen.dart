import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import '../pages/profile_edit_screen.dart';
import '../pages/program_progress_screen.dart';
import '../screens/add_food_screen.dart';
import '../screens/message_screen.dart';
import '../service/tasty_popup_service.dart';
import '../service/program_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/daily-meal-portion.dart';
import '../widgets/goal_dash_card.dart';
import '../widgets/milestone_tracker.dart';
import '../widgets/second_nav_widget.dart';
import '../pages/family_member.dart';
import '../data_models/user_data_model.dart';
import 'dine-in.screen.dart';
import 'recipe_screen.dart';
import 'shopping_tab.dart';
import '../service/notification_service.dart';
import '../service/hybrid_notification_service.dart';
import '../service/helper_controller.dart';
import '../helper/onboarding_prompt_helper.dart';
import '../widgets/onboarding_prompt.dart';
import '../pages/edit_goal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int currentPage = 0;
  final PageController _pageController = PageController();
  bool familyMode = userService.currentUser.value?.familyMode ?? false;
  late final ProgramService _programService;
  NotificationService? notificationService;
  HybridNotificationService? hybridNotificationService;
  Timer? _tastyPopupTimer;
  bool allDisabled = false;
  int _lastUnreadCount = 0; // Track last unread count
  DateTime currentDate = DateTime.now();
  final GlobalKey _addMealButtonKey = GlobalKey();
  final GlobalKey _addProfileButtonKey = GlobalKey();
  final GlobalKey _addAnalyseButtonKey = GlobalKey();
  final GlobalKey _addDineInButtonKey = GlobalKey();
  final GlobalKey _addShoppingButtonKey = GlobalKey();
  final GlobalKey _addRecipeButtonKey = GlobalKey();
  final GlobalKey _addMessageButtonKey = GlobalKey();
  String? _shoppingDay;
  int selectedUserIndex = 0;
  List<Map<String, dynamic>> familyList = [];
  bool hasMealPlan = true;
  Map<String, dynamic> mealPlan = {};
  bool showCaloriesAndGoal = true;
  bool _isConnected = true;
  Timer? _networkCheckTimer;
  bool _showGoalsPrompt = false;
  bool _tutorialCompleted = false;
  Worker? _unreadNotificationsWorker;

  @override
  void initState() {
    super.initState();
    // Initialize ProgramService
    _programService = Get.put(ProgramService());

    // Setup listener for unread notifications (moved out of build method)
    _setupUnreadNotificationsListener();

    // Initialize NotificationService - will be done in post frame callback
    // to ensure the service is ready

    // _initializeMealData();
    loadShowCaloriesPref().then((value) {
      if (mounted) {
        setState(() {
          showCaloriesAndGoal = value;
        });
      }
    });
    _getAllDisabled().then((value) {
      if (mounted && value) {
        setState(() {
          allDisabled = value;
        });
      }
    });

    _loadShoppingDay();
    _setupDataListeners();
    _startNetworkCheck();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Initialize NotificationService after the widget is built
      try {
        notificationService = Get.find<NotificationService>();
        hybridNotificationService = Get.find<HybridNotificationService>();
      } catch (e) {
        debugPrint('Error initializing NotificationService: $e');
        return;
      }

      if (!mounted) return;

      // Check and show notification preference prompt for existing users
      _checkNotificationPreference();

      if (!mounted) return;

      // Then show the meal tutorial
      _showAddMealTutorial();

      if (!mounted) return;

      // Check goals prompt after tutorial (60 seconds delay)
      _checkGoalsPromptAfterTutorial();

      if (!mounted) return;

      // Setup Cloud Functions notifications (replaces local scheduling)
      _setupHybridNotifications();

      if (!mounted) return;

      // Preload dietary/cuisine data early for better performance
      _preloadDietaryData();
    });
  }

  // Helper function to safely convert settings value to bool
  bool _safeBoolFromSettings(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    if (value is int) {
      return value != 0;
    }
    return defaultValue;
  }

  Future<void> _checkNotificationPreference() async {
    try {
      final user = userService.currentUser.value;
      if (user == null) return;

      // Check if user has set notification preference (safe conversion from String or bool)
      final notificationPreferenceSet = _safeBoolFromSettings(
          user.settings['notificationPreferenceSet'],
          defaultValue: false);

      if (!notificationPreferenceSet) {
        // User hasn't set preference yet, show prompt after user has interacted with the app
        // Wait for user to complete a meaningful action (reduced from 120s to 60s)
        // Or show after tutorial completion if first-time user
        await Future.delayed(const Duration(seconds: 60));
        if (!mounted) return;
        _showNotificationPreferenceDialog();
      } else {
        // User has set preference, check if notifications are enabled
        final notificationsEnabled = _safeBoolFromSettings(
            user.settings['notificationsEnabled'],
            defaultValue: false);
        if (notificationsEnabled && notificationService != null) {
          // Initialize notifications if enabled
          await _initializeNotifications();
        }
      }
    } catch (e) {
      debugPrint('Error checking notification preference: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    if (!mounted) return;

    try {
      // Initialize local notification service (without requesting permissions)
      await notificationService?.initNotification(
        onNotificationTapped: (String? payload) {
          if (payload != null && mounted) {
            _handleNotificationTap(payload);
          }
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Notification initialization timed out');
        },
      );

      if (!mounted) return;

      // Request iOS permissions explicitly now that user has enabled notifications
      try {
        await notificationService?.requestIOSPermissions();
        debugPrint('iOS notification permissions requested');
      } catch (e) {
        debugPrint('Error requesting iOS notification permissions: $e');
      }

      if (!mounted) return;

      // Initialize hybrid notification service for Android/iOS
      try {
        await hybridNotificationService?.initializeHybridNotifications();
        debugPrint('Hybrid notifications initialized successfully');
      } catch (e) {
        debugPrint('Error initializing hybrid notifications: $e');
      }

      debugPrint('Notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  void _handleNotificationTap(String payload) async {
    if (!mounted) return;

    try {
      debugPrint('Notification tapped: $payload');

      if (payload.contains('meal_plan_reminder') ||
          payload.contains('evening_review') ||
          payload.contains('water_reminder')) {
        if (!mounted) return;

        if (payload.contains('meal_plan_reminder')) {
          Get.to(() => const BottomNavSec(selectedIndex: 4));
        } else if (payload.contains('water_reminder')) {
          Get.to(() => AddFoodScreen(date: DateTime.now()));
        } else if (payload.contains('evening_review')) {
          Get.to(() => AddFoodScreen(date: DateTime.now()));
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
      if (mounted && context.mounted) {
        showTastySnackbar(
          'Error',
          'Failed to open notification. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _showNotificationPreferenceDialog() {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Row(
            children: [
              Icon(Icons.notifications_active,
                  color: kAccent, size: getIconScale(8, context)),
              SizedBox(width: getPercentageWidth(3, context)),
              Expanded(
                child: Text(
                  'Enable Notifications?',
                  style: TextStyle(
                    color: isDarkMode ? kWhite : kDarkGrey,
                    fontSize: getTextScale(4.5, context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Stay on track with meal reminders, hydration alerts, and personalized nutrition tips!',
            style: TextStyle(
              color: isDarkMode ? kWhite.withOpacity(0.9) : kDarkGrey,
              fontSize: getTextScale(3.5, context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (!mounted) return;
                try {
                  // User declined
                  await authController.updateUserData({
                    'settings.notificationsEnabled': false,
                    'settings.notificationPreferenceSet': true,
                  });
                  if (mounted && context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  debugPrint('Error updating notification preference: $e');
                  if (mounted && context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: Text(
                'Not Now',
                style: TextStyle(
                  color: isDarkMode ? kWhite.withOpacity(0.7) : kLightGrey,
                  fontSize: getTextScale(3.5, context),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(6, context),
                  vertical: getPercentageHeight(1.5, context),
                ),
              ),
              onPressed: () async {
                if (!mounted) return;
                try {
                  // User accepted
                  await authController.updateUserData({
                    'settings.notificationsEnabled': true,
                    'settings.notificationPreferenceSet': true,
                  });
                  if (mounted && context.mounted) {
                    Navigator.of(context).pop();
                  }

                  if (!mounted) return;

                  // Initialize notifications
                  await _initializeNotifications();

                  // Show success message
                  if (mounted && context.mounted) {
                    showTastySnackbar(
                      'Notifications Enabled',
                      'You\'ll now receive helpful reminders!',
                      context,
                      backgroundColor: kAccent,
                    );
                  }
                } catch (e) {
                  debugPrint('Error enabling notifications: $e');
                  if (mounted && context.mounted) {
                    Navigator.of(context).pop();
                    showTastySnackbar(
                      'Error',
                      'Failed to enable notifications. Please try again.',
                      context,
                      backgroundColor: Colors.red,
                    );
                  }
                }
              },
              child: Text(
                'Enable',
                style: TextStyle(
                  color: kWhite,
                  fontSize: getTextScale(3.5, context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddMealTutorial() {
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'home_screen_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'add_profile_button',
          message: 'Tap here to view your profile!',
          targetKey: _addProfileButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_meal_button',
          message: 'Tap here to add your meal!',
          targetKey: _addMealButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_dine_in_button',
          message: 'Tap here to analyze what is in your fridge!',
          targetKey: _addDineInButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_shopping_button',
          message: 'Tap here to view your shopping list!',
          targetKey: _addShoppingButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_recipe_button',
          message: 'Tap here to view our recipe library!',
          targetKey: _addRecipeButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_message_button',
          message: 'Tap here to view your messages!',
          targetKey: _addMessageButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_analyse_button',
          message: 'Tap here to analyze your meal!',
          targetKey: _addAnalyseButtonKey,
          onComplete: () {
            // Mark tutorial as completed
            setState(() {
              _tutorialCompleted = true;
            });
            // Start family dialog timer after tutorial completion
            _checkFamilyDialogAfterTutorial();
          },
        ),
      ],
    );
  }

  Future<void> _checkAndShowFamilyNutritionDialog() async {
    // Check if user already has family mode enabled
    if (userService.currentUser.value?.familyMode == true) {
      return; // Don't show dialog if family mode is already enabled
    }

    // Check if user has already seen the family nutrition dialog
    final prefs = await SharedPreferences.getInstance();
    final hasSeenFamilyDialog =
        prefs.getBool('has_seen_family_nutrition_dialog') ?? false;

    if (hasSeenFamilyDialog) {
      return; // Don't show dialog if user has already seen it
    }

    // Mark that user has seen the dialog
    await prefs.setBool('has_seen_family_nutrition_dialog', true);

    // Show the dialog
    _showFamilyNutritionDialog();
  }

  void _showFamilyNutritionDialog() {
    // Check if user already has family mode enabled
    if (userService.currentUser.value?.familyMode == true) {
      return; // Don't show dialog if family mode is already enabled
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor:
            getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
        title: Text(
          'Manage Family Nutrition?',
          style: TextStyle(
            color: kAccent,
            fontSize: getTextScale(4, context),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Would you like to manage nutrition for your family members? \n\nYou can add family members and plan their meals \n(you can always change this later in Settings -> Edit Goals).',
          style: TextStyle(
            color: getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
            fontSize: getTextScale(3.5, context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Not Now',
              style: TextStyle(
                color:
                    getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
                fontSize: getTextScale(3.5, context),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _showFamilySetupDialog();
            },
            child: Text(
              'Yes, Set Up Family',
              style: TextStyle(
                fontSize: getTextScale(3.5, context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFamilySetupDialog() {
    List<Map<String, String>> familyMembers = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FamilyMembersDialog(
        initialMembers: familyMembers,
        onMembersChanged: (members) async {
          if (members.isNotEmpty && members.first['name']?.isNotEmpty == true) {
            await _saveFamilyMembers(members);
          }
        },
      ),
    );
  }

  Future<void> _saveFamilyMembers(List<Map<String, String>> members) async {
    if (!mounted) return;

    try {
      final userId = userService.userId;
      if (userId == null || userId.isEmpty) {
        debugPrint('Error: userId is null in _saveFamilyMembers');
        if (mounted && context.mounted) {
          showTastySnackbar(
            'Error',
            'User ID is missing. Please try again.',
            context,
            backgroundColor: Colors.red,
          );
        }
        return;
      }

      // Validate and sanitize family member data
      final familyMembers = members.where((m) {
        final name = m['name']?.trim() ?? '';
        return name.isNotEmpty && name.length >= 2 && name.length <= 50;
      }).map((m) {
        // Sanitize name
        final sanitizedName =
            (m['name']?.trim() ?? '').replaceAll(RegExp(r'[<>{}[\]\\]'), '');

        return FamilyMember(
          name: sanitizedName,
          ageGroup: m['ageGroup'] ?? 'Adult',
          fitnessGoal: m['fitnessGoal'] ?? 'Family Nutrition',
          foodGoal: m['foodGoal'] ?? '2000',
        );
      }).toList();

      if (familyMembers.isEmpty) {
        if (mounted && context.mounted) {
          showTastySnackbar(
            'Invalid Input',
            'Please enter valid family member names (2-50 characters).',
            context,
            backgroundColor: Colors.red,
          );
        }
        return;
      }

      // Update user in Firestore
      await firestore.collection('users').doc(userId).update({
        'familyMode': true,
        'familyMembers': familyMembers.map((f) => f.toMap()).toList(),
      });

      // Update local user data
      final currentUser = userService.currentUser.value;
      if (currentUser != null) {
        final updatedUser = UserModel(
          userId: currentUser.userId,
          displayName: currentUser.displayName,
          bio: currentUser.bio,
          dob: currentUser.dob,
          profileImage: currentUser.profileImage,
          following: currentUser.following,
          settings: currentUser.settings,
          preferences: currentUser.preferences,
          userType: currentUser.userType,
          isPremium: currentUser.isPremium,
          created_At: currentUser.created_At,
          freeTrialDate: currentUser.freeTrialDate,
          familyMode: true,
          familyMembers: familyMembers,
        );
        userService.setUser(updatedUser);
      }

      // Show success message
      if (mounted) {
        showTastySnackbar(
          'Family Setup Complete!',
          'You can now manage nutrition for ${familyMembers.length} family member${familyMembers.length > 1 ? 's' : ''}.',
          context,
          backgroundColor: kAccentLight,
        );
      }
    } catch (e) {
      debugPrint('Error saving family members: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to save family members. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> loadMeals(String date) async {
    if (!mounted) return;

    final userId = userService.userId;
    if (userId == null || userId.isEmpty) {
      debugPrint('Warning: userId is null or empty in loadMeals');
      if (mounted) {
        setState(() {
          hasMealPlan = false;
        });
      }
      return;
    }

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);
      QuerySnapshot snapshot = await firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('date')
          .where('date', isEqualTo: formattedDate)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>?;
        final mealsList = data?['meals'] as List<dynamic>? ?? [];
        if (mealsList.isNotEmpty) {
          hasMealPlan = true;
        } else {
          hasMealPlan = false;
        }
      } else {
        hasMealPlan = false;
      }

      if (mounted) {
        setState(() {
          hasMealPlan = hasMealPlan;
        });
      }
    } catch (e) {
      debugPrint('Error loading meals: $e');
      if (mounted) {
        setState(() {
          hasMealPlan = false;
        });
      }
    }
  }

  void _setupDataListeners() {
    // Show Tasty popup after a short delay
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    if (!mounted) return;

    try {
      _initializeMealData();

      final userId = userService.userId;
      if (userId != null && userId.isNotEmpty) {
        chatController.loadUserChats(userId);
      }

      // Run independent operations in parallel
      await Future.wait([
        helperController.fetchWinners(),
        firebaseService.fetchGeneralData(),
        macroManager.fetchIngredients(),
      ]);

      if (mounted) {
        loadMeals(DateFormat('yyyy-MM-dd').format(currentDate));
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      if (mounted && context.mounted) {
        showTastySnackbar(
          'Refresh Failed',
          'Unable to refresh data. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  /// Setup hybrid notifications (FCM for Android, Local for iOS)
  Future<void> _setupHybridNotifications() async {
    if (hybridNotificationService == null) {
      debugPrint('Hybrid Notification Service not available');
      return;
    }

    try {
      // Set up notification preferences for the current platform
      await _setupUserNotificationPreferences();

      debugPrint(
          'Hybrid notifications setup completed for ${hybridNotificationService!.platform}');
    } catch (e) {
      debugPrint('Error setting up hybrid notifications: $e');
    }
  }

  /// Setup user notification preferences for hybrid system
  Future<void> _setupUserNotificationPreferences() async {
    if (hybridNotificationService == null) return;

    try {
      // Set up default notification preferences if not already set
      final preferences = {
        'mealPlanReminder': {
          'enabled': true,
          'time': {'hour': 21, 'minute': 0},
          'timezone': 'UTC'
        },
        'waterReminder': {
          'enabled': true,
          'time': {'hour': 11, 'minute': 0},
          'timezone': 'UTC'
        },
        'eveningReview': {
          'enabled': true,
          'time': {'hour': 21, 'minute': 0},
          'timezone': 'UTC'
        }
      };

      await hybridNotificationService!
          .updateNotificationPreferences(preferences);
      debugPrint(
          'User notification preferences updated for ${hybridNotificationService!.platform}');
    } catch (e) {
      debugPrint('Error setting up user notification preferences: $e');
    }
  }

  void _initializeMealData() async {
    if (!mounted) return;

    final userId = userService.userId;
    if (userId == null || userId.isEmpty) {
      debugPrint('Warning: userId is null in _initializeMealData');
      return;
    }

    // Settings conversion is not needed - dailyDataController doesn't use it
    // Removed unnecessary settings map creation

    dailyDataController.listenToDailyData(userId, DateTime.now());
  }

  void _initializeMealDataByDate() async {
    if (!mounted) return;

    final userId = userService.userId;
    if (userId == null || userId.isEmpty) {
      debugPrint('Warning: userId is null in _initializeMealDataByDate');
      return;
    }

    // Settings conversion is not needed - dailyDataController doesn't use it
    // Removed unnecessary settings map creation

    dailyDataController.listenToDailyData(userId, currentDate);
  }

  Future<bool> _getAllDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('allDisabledKey') ?? false;
  }

  /// Preload dietary and cuisine data in background for better performance
  /// This ensures data is ready when user navigates to dietary choose screen
  void _preloadDietaryData() {
    // Fetch data in background without blocking UI
    Future.microtask(() async {
      if (!mounted) return;

      try {
        HelperController? helperController;
        try {
          helperController = Get.find<HelperController>();
        } catch (e) {
          debugPrint('HelperController not found: $e');
          return;
        }

        if (!mounted) return;

        // Only fetch if data is not already loaded
        if (helperController.headers.isEmpty) {
          await helperController.fetchHeaders();
        }
        if (mounted && helperController.category.isEmpty) {
          await helperController.fetchCategorys();
        }
        debugPrint('Dietary data preloaded successfully');
      } catch (e) {
        debugPrint('Error preloading dietary data: $e');
      }
    });
  }

  Future<void> _loadShoppingDay() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shoppingDay = prefs.getString('shopping_day');
    });
  }

  // Start network connectivity check (optimized to check every 30 seconds instead of 5)
  void _startNetworkCheck() {
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkNetworkConnectivity();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkGoalsPrompt() async {
    final shouldShow = await OnboardingPromptHelper.shouldShowGoalsPrompt();
    if (mounted) {
      setState(() {
        _showGoalsPrompt = shouldShow;
      });
    }
  }

  Future<void> _checkGoalsPromptAfterTutorial() async {
    // Wait 60 seconds after tutorial starts
    await Future.delayed(const Duration(seconds: 60));
    if (mounted) {
      await _checkGoalsPrompt();
    }
  }

  Future<void> _checkFamilyDialogAfterTutorial() async {
    // Wait 30 seconds after tutorial completion
    await Future.delayed(const Duration(seconds: 30));
    if (mounted && _tutorialCompleted) {
      await _checkAndShowFamilyNutritionDialog();
    }
  }

  // Check network connectivity
  Future<void> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    } on SocketException catch (_) {
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
    }
  }

  bool _isTodayShoppingDay() {
    if (_shoppingDay == null || _shoppingDay == '') return false;
    final today = DateTime.now();
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[today.weekday - 1] == _shoppingDay;
  }

  // Add this method to handle notifications
  Future<void> _handleUnreadNotifications(int unreadCount) async {
    // Only proceed if the unread count has changed
    if (unreadCount == _lastUnreadCount) return;

    if (unreadCount >= 1) {
      // Only show notification if we haven't shown it before
      if (notificationService != null &&
          !await notificationService!.hasShownUnreadNotification) {
        await notificationService?.showNotification(
          title: 'Taste Turner - New Message',
          body: 'You have $unreadCount unread messages',
        );
        await notificationService?.setHasShownUnreadNotification(true);
      }
    } else if (_lastUnreadCount > 0) {
      // Only reset if we're transitioning from unread to read
      await notificationService?.resetUnreadNotificationState();
    }

    _lastUnreadCount = unreadCount; // Update last unread count
  }

  /// Setup listener for unread notifications using GetX Worker
  void _setupUnreadNotificationsListener() {
    _unreadNotificationsWorker = ever(
      chatController.userChats,
      (_) {
        // Calculate unread count when chats change
        final nonBuddyChats = chatController.userChats
            .where((chat) => !(chat['participants'] as List).contains('buddy'))
            .toList();

        final int unreadCount = nonBuddyChats.fold<int>(
          0,
          (sum, chat) => sum + (chat['unreadCount'] as int? ?? 0),
        );

        _handleUnreadNotifications(unreadCount);
      },
    );
  }

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    _networkCheckTimer?.cancel();
    _unreadNotificationsWorker?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      final currentUser = userService.currentUser.value;

      // Check if user is authenticated but data hasn't loaded yet
      final isAuthenticated = firebaseAuth.currentUser != null;
      if (currentUser == null && isAuthenticated) {
        // User is authenticated but data hasn't loaded - wait a bit longer
        // This handles the case where auth state is ready but Firestore data is still loading
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: kAccent),
          ),
        );
      }

      // If user is not authenticated at all, show splash/login screen
      if (!isAuthenticated) {
        // Redirect to splash/login - this should be handled by auth flow
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: kAccent),
          ),
        );
      }

      // If authenticated but currentUser is still null after reasonable time,
      // there might be a permission issue - show error or default state
      if (currentUser == null) {
        debugPrint(
            'Warning: User authenticated but currentUser is null - possible permission issue');
        // Show default/empty state instead of infinite loading
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: kAccent),
                const SizedBox(height: 16),
                Text(
                  'Unable to load user data',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try logging out and back in',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      }

      // Safely access user data with null checks
      familyMode = currentUser.familyMode ?? false;
      final inspiration = currentUser.bio ?? getRandomBio(bios);
      final avatarUrl = currentUser.profileImage ?? intPlaceholderImage;

      return Scaffold(
        drawer: const CustomDrawer(),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(getProportionalHeight(90, context)),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? kLightGrey.withValues(alpha: 0.1) : kWhite,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(2, context),
                      horizontal: getPercentageWidth(2, context)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Avatar and Greeting Section
                      Row(
                        children: [
                          Builder(builder: (context) {
                            return GestureDetector(
                              onTap: () {
                                Scaffold.of(context).openDrawer();
                              },
                              child: CircleAvatar(
                                key: _addProfileButtonKey,
                                radius: getResponsiveBoxSize(context, 20, 20),
                                backgroundColor:
                                    kAccent.withValues(alpha: kOpacity),
                                child: CircleAvatar(
                                  backgroundImage: getAvatarImage(avatarUrl),
                                  radius: getResponsiveBoxSize(context, 18, 18),
                                ),
                              ),
                            );
                          }),
                          SizedBox(width: getPercentageWidth(2, context)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting ${capitalizeFirstLetter(currentUser.displayName ?? '')}!',
                                style: textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: getPercentageWidth(6, context)),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                inspiration,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontSize: getTextScale(3, context),
                                  color: isDarkMode
                                      ? kLightGrey.withValues(alpha: 0.9)
                                      : kDarkGrey.withValues(alpha: 0.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: getPercentageWidth(2, context)),
                        ],
                      ),
                      // Message Section
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MessageScreen(),
                                ),
                              );
                            },
                            key: _addMessageButtonKey,
                            child: SvgPicture.asset(
                              'assets/images/svg/message.svg',
                              height: getIconScale(8, context),
                              width: getIconScale(8, context),
                              color: kAccent,
                            ),
                          ),
                          SizedBox(width: getPercentageWidth(2, context)),

                          // Unread Count Badge
                          Obx(() {
                            final nonBuddyChats = chatController.userChats
                                .where((chat) => !(chat['participants'] as List)
                                    .contains('buddy'))
                                .toList();

                            if (nonBuddyChats.isEmpty) {
                              return const SizedBox
                                  .shrink(); // Hide badge if no chats
                            }

                            // Calculate total unread count across all non-buddy chats
                            final int unreadCount = nonBuddyChats.fold<int>(
                              0,
                              (sum, chat) =>
                                  sum + (chat['unreadCount'] as int? ?? 0),
                            );

                            // Note: Unread notifications are now handled by _setupUnreadNotificationsListener()
                            // This prevents async operations in build method

                            if (unreadCount >= 1) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal:
                                        getPercentageWidth(1.5, context),
                                    vertical: getPercentageWidth(0.5, context)),
                                decoration: BoxDecoration(
                                  color: kRed,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: getTextScale(2.5, context),
                                  ),
                                ),
                              );
                            } else {
                              return const SizedBox
                                  .shrink(); // Hide badge if unreadCount is 0
                            }
                          }),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: buildFullWidthHomeButton(
          key: _addAnalyseButtonKey,
          context: context,
          date: currentDate,
          onSuccess: () {},
          onError: () {},
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await _onRefresh();
            await _loadShoppingDay();
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  vertical: getPercentageHeight(0.5, context),
                  horizontal: getPercentageWidth(2, context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Goals prompt banner
                  if (_showGoalsPrompt)
                    OnboardingPrompt(
                      title: "Personalize Your Nutrition Goals",
                      message:
                          "Set your health goals to get personalized calorie and macro recommendations tailored to you",
                      actionText: "Set Goals",
                      onAction: () async {
                        // Dismiss the prompt immediately
                        setState(() {
                          _showGoalsPrompt = false;
                        });

                        // Mark as shown in storage
                        await OnboardingPromptHelper.markGoalsPromptShown();

                        if (!mounted) return;

                        // Navigate to nutrition settings
                        try {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NutritionSettingsPage(),
                            ),
                          );
                        } catch (e) {
                          debugPrint(
                              'Error navigating to NutritionSettingsPage: $e');
                          if (mounted && context.mounted) {
                            showTastySnackbar(
                              'Error',
                              'Unable to open nutrition settings. Please try again.',
                              context,
                              backgroundColor: Colors.red,
                            );
                          }
                        }
                      },
                      onDismiss: () {
                        setState(() {
                          _showGoalsPrompt = false;
                        });
                      },
                      promptType: 'banner',
                      storageKey: OnboardingPromptHelper.PROMPT_GOALS_SHOWN,
                    ),

                  SizedBox(
                      height: MediaQuery.of(context).size.width > 800
                          ? getPercentageHeight(1.5, context)
                          : getPercentageHeight(0.5, context)),

                  // Network status indicator
                  if (!_isConnected)
                    Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context),
                          vertical: getPercentageHeight(0.5, context)),
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(3, context),
                          vertical: getPercentageHeight(1, context)),
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[700]!, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off,
                              color: kWhite, size: getIconScale(6, context)),
                          SizedBox(width: getPercentageWidth(2, context)),
                          Expanded(
                            child: Text(
                              'No internet connection. Some features may be limited.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: kWhite,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(0.3, context)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            final DateTime sevenDaysAgo = DateTime.now()
                                .subtract(const Duration(days: 7));
                            if (currentDate.isAfter(sevenDaysAgo)) {
                              setState(() {
                                currentDate = DateTime(
                                  currentDate.year,
                                  currentDate.month,
                                  currentDate.day,
                                ).subtract(const Duration(days: 1));
                              });
                              _initializeMealDataByDate(); // Fetch data for new date
                            }
                          },
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            size: getIconScale(7, context),
                            color: currentDate.isBefore(DateTime.now()
                                    .subtract(const Duration(days: 7)))
                                ? isDarkMode
                                    ? kLightGrey.withValues(alpha: 0.5)
                                    : kDarkGrey.withValues(alpha: 0.1)
                                : null,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${getRelativeDayString(currentDate)}',
                              style: textTheme.displaySmall
                                  ?.copyWith(color: kAccent),
                            ),
                            SizedBox(width: getPercentageWidth(0.5, context)),
                            if (getRelativeDayString(currentDate) != 'Today' &&
                                getRelativeDayString(currentDate) !=
                                    'Yesterday')
                              Text(
                                ' ${shortMonthName(currentDate.month)} ${currentDate.day}',
                                style: textTheme.displaySmall
                                    ?.copyWith(color: kAccent),
                              ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            final DateTime now = DateTime.now();
                            final DateTime nextDate = DateTime(
                              currentDate.year,
                              currentDate.month,
                              currentDate.day,
                            ).add(const Duration(days: 1));

                            setState(() {
                              if (!nextDate.isAfter(
                                  DateTime(now.year, now.month, now.day))) {
                                currentDate = nextDate;
                              } else {
                                currentDate =
                                    DateTime(now.year, now.month, now.day);
                              }
                            });
                            _initializeMealDataByDate(); // Fetch data for new date
                          },
                          icon: Icon(
                            Icons.arrow_forward_ios,
                            size: getIconScale(7, context),
                            color: getCurrentDate(currentDate)
                                ? isDarkMode
                                    ? kLightGrey.withValues(alpha: 0.5)
                                    : kDarkGrey.withValues(alpha: 0.1)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).size.height > 1100
                          ? getPercentageHeight(2, context)
                          : getPercentageHeight(0.5, context)),

                  if (_isTodayShoppingDay())
                    SizedBox(height: getPercentageHeight(1, context)),

                  if (_isTodayShoppingDay())
                    Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context)),
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(3, context),
                          vertical: getPercentageHeight(0.5, context)),
                      decoration: BoxDecoration(
                        color: kAccentLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kAccentLight, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shopping_cart,
                              color: kAccentLight,
                              size: getIconScale(8, context)),
                          SizedBox(width: getPercentageWidth(2, context)),
                          Expanded(
                            child: Text(
                              familyMode
                                  ? "Shopping Day: \nTime to shop for healthy family meals! Check your smart grocery list for kid-friendly essentials."
                                  : "Shopping Day: \nReady to shop smart? Your grocery list is loaded with healthy picks for your goals!",
                              style: textTheme.bodyMedium?.copyWith(
                                color: kAccentLight,
                              ),
                            ),
                          ),
                          SizedBox(width: getPercentageWidth(0.2, context)),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(getPercentageWidth(10, context),
                                  getPercentageHeight(4, context)),
                              backgroundColor: kAccentLight,
                              foregroundColor: kWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ShoppingTab(),
                                ),
                              );
                            },
                            child: Text('Go',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: kWhite,
                                )),
                          ),
                        ],
                      ),
                    ),
                  if (_isTodayShoppingDay())
                    SizedBox(height: getPercentageHeight(1, context)),

                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(4.5, context),
                        vertical: getPercentageHeight(1.5, context)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        //diary
                        SecondNavWidget(
                          key: _addMealButtonKey,
                          label: 'Diary',
                          icon: 'assets/images/svg/diary.svg',
                          color: isDarkMode
                              ? kAccent
                              : kAccent.withValues(alpha: 0.5),
                          destinationScreen: familyMode &&
                                  selectedUserIndex != 0
                              ? null // No destination when family member is selected
                              : AddFoodScreen(
                                  date: currentDate,
                                  isShowSummary: true,
                                  notAllowedMealType:
                                      _programService.userPrograms.isNotEmpty
                                          ? _programService
                                              .userPrograms.first.notAllowed
                                              .join(',')
                                          : null,
                                ),
                          onTap: familyMode && selectedUserIndex != 0
                              ? () {
                                  // Show snackbar when family member is selected
                                  showTastySnackbar(
                                    'Tracking Only',
                                    'Food tracking is only available for ${userService.currentUser.value?.displayName}',
                                    context,
                                    backgroundColor: kAccentLight,
                                  );
                                }
                              : null,
                          isDarkMode: isDarkMode,
                        ),
                        //shopping
                        SecondNavWidget(
                          key: _addDineInButtonKey,
                          label: 'Dine In',
                          icon: 'assets/images/svg/target.svg',
                          color:
                              isDarkMode ? kBlue : kBlue.withValues(alpha: 0.5),
                          destinationScreen: const DineInScreen(),
                          isDarkMode: isDarkMode,
                        ),
                        //Planner
                        SecondNavWidget(
                          key: _addShoppingButtonKey,
                          label: 'Shopping',
                          icon: 'assets/images/svg/shopping.svg',
                          color: isDarkMode
                              ? kAccentLight
                              : kAccentLight.withValues(alpha: 0.5),
                          destinationScreen: const ShoppingTab(),
                          isDarkMode: isDarkMode,
                        ),
                        //spin
                        SecondNavWidget(
                          key: _addRecipeButtonKey,
                          label: 'Recipes',
                          icon: 'assets/images/svg/book-outline.svg',
                          color: isDarkMode
                              ? kPurple
                              : kPurple.withValues(alpha: 0.5),
                          destinationScreen: const RecipeScreen(),
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),

                  // ------------------------------------Premium / Ads------------------------------------

                  getAdsWidget(currentUser.isPremium, isDiv: false),

                  // ------------------------------------Premium / Ads-------------------------------------
                  if (!currentUser.isPremium)
                    SizedBox(height: getPercentageHeight(1, context)),
                  const Divider(
                    color: kAccentLight,
                    thickness: 1.5,
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  // Milestones tracker
                  Obx(() => GestureDetector(
                        onTap: () {
                          if (_programService.userPrograms.isNotEmpty) {
                            Get.to(() => const ProgramProgressScreen());
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const BottomNavSec(selectedIndex: 1),
                              ),
                            );
                          }
                        },
                        child: MilestonesTracker(
                          ongoingPrograms: _programService.userPrograms.length,
                          onJoinProgram: () {
                            if (_programService.userPrograms.isNotEmpty) {
                              Get.to(() => const ProgramProgressScreen());
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const BottomNavSec(selectedIndex: 1),
                                ),
                              );
                            }
                          },
                        ),
                      )),

                  SizedBox(height: getPercentageHeight(2, context)),

                  // Nutrition Overview
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDarkMode = getThemeProvider(context).isDarkMode;
                      final userData = {
                        'name': currentUser.displayName ?? '',
                        'fitnessGoal':
                            currentUser.settings['fitnessGoal'] ?? '',
                        'foodGoal': currentUser.settings['foodGoal'] ?? '',
                        'meals': [],
                        'avatar': null,
                      };

                      final familyMembers = currentUser.familyMembers ?? [];
                      final familyList =
                          familyMembers.map((f) => f.toMap()).toList();
                      final displayList = [userData, ...familyList];
                      final user = familyMode
                          ? displayList[selectedUserIndex]
                          : displayList[0];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (familyMode)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(2, context)),
                              child: Container(
                                padding: EdgeInsets.all(
                                    getPercentageWidth(2, context)),
                                decoration: BoxDecoration(
                                  color:
                                      colors[selectedUserIndex % colors.length]
                                          .withValues(alpha: kMidOpacity),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: colors[
                                          selectedUserIndex % colors.length],
                                      width: 1.5),
                                ),
                                child: Center(
                                  child: FamilySelectorSection(
                                    familyMode: familyMode,
                                    selectedUserIndex: selectedUserIndex,
                                    displayList: displayList,
                                    onSelectUser: (index) {
                                      setState(() {
                                        selectedUserIndex = index;
                                        // No need for redundant setState - the above already triggers rebuild
                                      });
                                    },
                                    isDarkMode: isDarkMode,
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: getPercentageHeight(1, context)),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: getPercentageWidth(2, context)),
                            child: Container(
                              padding: EdgeInsets.all(
                                  getPercentageWidth(2, context)),
                              decoration: BoxDecoration(
                                color: colors[selectedUserIndex % colors.length]
                                    .withValues(alpha: kMidOpacity),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: colors[
                                        selectedUserIndex % colors.length],
                                    width: 1.5),
                              ),
                              child: UserDetailsSection(
                                user: user,
                                isDarkMode: isDarkMode,
                                showCaloriesAndGoal: showCaloriesAndGoal,
                                familyMode: familyMode,
                                selectedUserIndex: selectedUserIndex,
                                displayList: displayList,
                                onToggleShowCalories: () {
                                  setState(() {
                                    showCaloriesAndGoal = !showCaloriesAndGoal;
                                  });
                                  saveShowCaloriesPref(showCaloriesAndGoal);
                                },
                                onEdit: (editedUser, isDarkMode) {
                                  // Handle family member editing
                                  if (familyMode &&
                                      editedUser['name'] !=
                                          userService
                                              .currentUser.value?.displayName) {
                                    // Find the family member in the current user's family members
                                    final currentUser =
                                        userService.currentUser.value;
                                    if (currentUser?.familyMembers != null) {
                                      final familyMemberIndex = currentUser!
                                          .familyMembers!
                                          .indexWhere((member) =>
                                              member.name ==
                                              editedUser['name']);

                                      if (familyMemberIndex != -1) {
                                        // Get the specific family member to edit
                                        final familyMember = currentUser
                                            .familyMembers![familyMemberIndex];
                                        final familyMemberData = {
                                          'name': familyMember.name,
                                          'ageGroup': familyMember.ageGroup,
                                          'fitnessGoal':
                                              familyMember.fitnessGoal,
                                          'foodGoal': familyMember.foodGoal,
                                        };

                                        // Show family member edit dialog
                                        showDialog(
                                          context: context,
                                          builder: (context) =>
                                              EditFamilyMemberDialog(
                                            familyMember: familyMemberData,
                                            onMemberUpdated:
                                                (updatedMember) async {
                                              // Update the specific family member
                                              final updatedFamilyMembers =
                                                  List<FamilyMember>.from(
                                                      currentUser
                                                          .familyMembers!);
                                              updatedFamilyMembers[
                                                      familyMemberIndex] =
                                                  FamilyMember.fromMap(
                                                      updatedMember);

                                              final updatedUser =
                                                  currentUser.copyWith(
                                                familyMembers:
                                                    updatedFamilyMembers,
                                              );
                                              userService.setUser(updatedUser);

                                              // Save to Firestore
                                              await firestore
                                                  .collection('users')
                                                  .doc(userService.userId)
                                                  .set({
                                                'familyMembers': updatedUser
                                                    .familyMembers
                                                    ?.map((f) => f.toMap())
                                                    .toList(),
                                                'familyMode': updatedUser
                                                        .familyMembers
                                                        ?.isNotEmpty ??
                                                    false,
                                              }, SetOptions(merge: true));
                                            },
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    // Handle current user editing
                                    Get.to(() => const ProfileEditScreen());
                                  }
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),
                          if (currentDate.isAfter(DateTime.now()
                              .subtract(const Duration(days: 1)))) ...[
                            DailyMealPortion(
                              key: ValueKey(
                                  'daily_meal_portion_$selectedUserIndex'), // Add key for proper rebuilding
                              programName:
                                  _programService.userPrograms.isNotEmpty
                                      ? _programService.userPrograms.first.type
                                      : '',
                              userProgram:
                                  _programService.userPrograms.isNotEmpty
                                      ? _programService.userPrograms.first
                                      : null,
                              notAllowed:
                                  _programService.userPrograms.isNotEmpty
                                      ? (_programService.userPrograms.first
                                              .notAllowed.isNotEmpty
                                          ? _programService
                                              .userPrograms.first.notAllowed
                                          : [])
                                      : [],
                              selectedUser: user, // Pass the selected user data
                            ),
                          ],
                          SizedBox(height: getPercentageHeight(3, context)),
                        ],
                      );
                    },
                  ),
                  SizedBox(
                    height: getPercentageHeight(15, context),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
