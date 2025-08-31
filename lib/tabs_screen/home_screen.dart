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

  @override
  void initState() {
    super.initState();
    // Initialize ProgramService
    _programService = Get.put(ProgramService());

    // Initialize NotificationService - will be done in post frame callback
    // to ensure the service is ready

    // _initializeMealData();
    loadShowCaloriesPref().then((value) {
      setState(() {
        showCaloriesAndGoal = value;
      });
    });
    _getAllDisabled().then((value) {
      if (value) {
        allDisabled = value;
        setState(() {
          allDisabled = value;
        });
      }
    });

    _loadShoppingDay();
    _setupDataListeners();
    _startNetworkCheck();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize NotificationService after the widget is built
      try {
        notificationService = Get.find<NotificationService>();
      } catch (e) {
        debugPrint('Error initializing NotificationService: $e');
        return;
      }

      // Show family nutrition dialog first
      _checkAndShowFamilyNutritionDialog();

      // Then show the meal tutorial
      _showAddMealTutorial();

      // Schedule meal reminder notification
      _scheduleMealReminderNotification();
    });
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
          message: 'Tap here to view your dine-in challenge!',
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
            // Optional: Add any actions to perform after the tutorial is completed
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
    try {
      // Convert to FamilyMember objects
      final familyMembers = members
          .where((m) => m['name']?.isNotEmpty == true)
          .map((m) => FamilyMember(
                name: m['name']!,
                ageGroup: m['ageGroup']!,
                fitnessGoal: m['fitnessGoal']!,
                foodGoal: m['foodGoal']!,
              ))
          .toList();

      if (familyMembers.isEmpty) return;

      // Update user in Firestore
      await firestore.collection('users').doc(userService.userId).update({
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
    final formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);
    QuerySnapshot snapshot = await firestore
        .collection('mealPlans')
        .doc(userService.userId)
        .collection('date')
        .where('date', isEqualTo: formattedDate)
        .get();

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
  }

  void _setupDataListeners() {
    // Show Tasty popup after a short delay
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    _initializeMealData();
    chatController.loadUserChats(userService.userId ?? '');
    await helperController.fetchWinners();
    await firebaseService.fetchGeneralData();
    loadMeals(DateFormat('yyyy-MM-dd').format(currentDate));
    await macroManager.fetchIngredients();
  }

  Future<void> _scheduleMealReminderNotification() async {
    // Check if notification service is ready
    if (notificationService == null) {
      return;
    }

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    QuerySnapshot snapshot = await firestore
        .collection('mealPlans')
        .doc(userService.userId)
        .collection('date')
        .where('date', isEqualTo: tomorrowStr)
        .get();

    var tomorrowHasMealPlan = false;
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data() as Map<String, dynamic>?;
      final mealsList = data?['meals'] as List<dynamic>? ?? [];
      if (mealsList.isNotEmpty) {
        tomorrowHasMealPlan = true;
      }
    }

    // Get today's summary data for action items
    Map<String, dynamic> todaySummary = {};
    try {
      final summaryDoc = await firestore
          .collection('users')
          .doc(userService.userId)
          .collection('daily_summary')
          .doc(todayStr)
          .get();

      if (summaryDoc.exists) {
        todaySummary = summaryDoc.data()!;
      }
    } catch (e) {
      debugPrint('Error loading today\'s summary: $e');
    }

    // Check if the notification time (13:35) has already passed today
    final now = DateTime.now();
    final notificationTime = DateTime(now.year, now.month, now.day, 13, 35);
    final isNotificationTimeInPast = now.isAfter(notificationTime);
    // If notification time is in the past, schedule for tomorrow; otherwise, schedule for today
    final targetDate = isNotificationTimeInPast ? tomorrow : now;
    final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);

    if (tomorrowHasMealPlan == false) {
      // Schedule meal plan reminder
      await notificationService?.scheduleDailyReminder(
        id: 1,
        title: 'Meal Plan Reminder',
        body:
            'You haven\'t planned any meals for tomorrow. Don\'t forget to add your meals!',
        hour: 21,
        minute: 00,
        payload: {
          'type': 'meal_plan_reminder',
          'date': targetDateStr,
          'todaySummary': todaySummary,
          'hasMealPlan': false,
        },
      );
    } else {
      // Schedule evening review
      await notificationService?.scheduleDailyReminder(
        id: 2,
        title: 'Evening Review 🌙',
        body: 'Review your goals and plan for tomorrow!',
        hour: 21,
        minute: 00,
        payload: {
          'type': 'evening_review',
          'date': targetDateStr,
          'todaySummary': todaySummary,
          'hasMealPlan': true,
        },
      );
    }

    // Schedule water reminder notification
    _scheduleWaterReminder();
  }

  // Schedule water reminder notification
  Future<void> _scheduleWaterReminder() async {
    if (notificationService == null) return;

    try {
      // Schedule daily water reminder at 11 AM
      await notificationService!.scheduleDailyReminder(
        id: 5002,
        title: "Water Reminder 💧",
        body: "Stay hydrated! Don't forget to track your water intake.",
        hour: 11,
        minute: 0,
      );
      debugPrint('Daily water reminder scheduled for 11:00 AM');
    } catch (e) {
      debugPrint('Error scheduling water reminder: $e');
    }
  }

  void _initializeMealData() async {
    Map<String, String> settings = {};
    userService.currentUser.value?.settings.forEach((key, value) {
      settings[key.toString()] = value.toString();
    });

    dailyDataController.listenToDailyData(
        userService.userId ?? '', DateTime.now());
  }

  void _initializeMealDataByDate() async {
    Map<String, String> settings = {};
    userService.currentUser.value?.settings.forEach((key, value) {
      settings[key.toString()] = value.toString();
    });

    dailyDataController.listenToDailyData(
        userService.userId ?? '', currentDate);
  }

  Future<bool> _getAllDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('allDisabledKey') ?? false;
  }

  Future<void> _loadShoppingDay() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shoppingDay = prefs.getString('shopping_day');
    });
  }

  // Start network connectivity check
  void _startNetworkCheck() {
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkNetworkConnectivity();
    });
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

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    _networkCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      final currentUser = userService.currentUser.value;

      if (currentUser == null) {
        // Show a loading state if user data isn't available yet
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: kAccent),
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

                            // Handle notifications
                            _handleUnreadNotifications(unreadCount);

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
                        'name': currentUser?.displayName ?? '',
                        'fitnessGoal':
                            currentUser?.settings['fitnessGoal'] ?? '',
                        'foodGoal': currentUser?.settings['foodGoal'] ?? '',
                        'meals': [],
                        'avatar': null,
                      };

                      final familyMembers = currentUser?.familyMembers ?? [];
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
                                      });
                                      // Force rebuild of all components that depend on user data
                                      if (mounted) {
                                        setState(() {});
                                      }
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
