import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:tasteturner/widgets/bottom_nav.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/program_progress_screen.dart';
import '../screens/add_food_screen.dart';
import '../screens/buddy_screen.dart';
import '../screens/message_screen.dart';
import '../service/tasty_popup_service.dart';
import '../service/program_service.dart';
import '../widgets/announcement.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/goal_dash_card.dart';
import '../widgets/milestone_tracker.dart';
import '../widgets/premium_widget.dart';
import '../widgets/second_nav_widget.dart';
import 'food_challenge_screen.dart';
import 'program_screen.dart';
import 'recipe_screen.dart';
import 'shopping_tab.dart';

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
  Timer? _tastyPopupTimer;
  bool allDisabled = false;
  int _lastUnreadCount = 0; // Track last unread count
  DateTime currentDate = DateTime.now();
  final GlobalKey _addMealButtonKey = GlobalKey();
  final GlobalKey _addProfileButtonKey = GlobalKey();
  final GlobalKey _addHomeButtonKey = GlobalKey();
  String? _shoppingDay;
  int selectedUserIndex = 0;
  List<Map<String, dynamic>> familyList = [];
  bool hasMealPlan = true;
  Map<String, dynamic> mealPlan = {};
  bool showCaloriesAndGoal = true;
  static const String _showCaloriesPrefKey = 'showCaloriesAndGoal';
  bool isInFreeTrial = false;
  @override
  void initState() {
    super.initState();
    final freeTrialDate = userService.currentUser.value?.freeTrialDate;
    final isFreeTrial =
        freeTrialDate != null && DateTime.now().isBefore(freeTrialDate);
    setState(() {
      isInFreeTrial = isFreeTrial;
    });
    // Initialize ProgramService
    _programService = Get.put(ProgramService());

    // _initializeMealData();
    _loadShowCaloriesPref();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddMealTutorial();
    });
  }

  void _showAddMealTutorial() {
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'home_screen_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'add_meal_button',
          message: 'Tap here to add your meal!',
          targetKey: _addMealButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_profile_button',
          message: 'Tap here to view your profile!',
          targetKey: _addProfileButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
      ],
    );
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

  Future<List<MealWithType>> _loadMealsForUI(
      String userName, List<Map<String, dynamic>> familyList) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    QuerySnapshot snapshot = await firestore
        .collection('mealPlans')
        .doc(userService.userId)
        .collection('date')
        .where('date', isEqualTo: formattedDate)
        .get();
    List<MealWithType> mealWithTypes = [];

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data() as Map<String, dynamic>?;
      final mealsList = data?['meals'] as List<dynamic>? ?? [];
      mealPlan = data ?? {};
      for (final item in mealsList) {
        if (item is String && item.contains('/')) {
          final parts = item.split('/');
          final mealId = parts[0];
          final mealType = parts.length > 1 ? parts[1] : '';
          final mealMember = parts.length > 2 ? parts[2] : '';
          final meal = await mealManager.getMealbyMealID(mealId);
          if (meal != null) {
            mealWithTypes.add(MealWithType(
                meal: meal, mealType: mealType, familyMember: mealMember));
          }
        }
      }
    }
    return updateMealForFamily(mealWithTypes, userName, familyList);
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
    _scheduleMealReminderNotification();
  }

  Future<void> _scheduleMealReminderNotification() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);

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

    if (tomorrowHasMealPlan == false) {
      // Schedule notification for 8 PM
      final now = DateTime.now();
      final scheduledTime = DateTime(now.year, now.month, now.day, 20, 0);
      if (scheduledTime.isAfter(now)) {
        await notificationService.scheduleDailyReminder(
          id: 1,
          title: 'Meal Plan Reminder',
          body:
              'You haven\'t planned any meals for tomorrow. Don\'t forget to add your meals!',
          hour: 20,
          minute: 0,
        );
      }
    } else {
      final now = DateTime.now();
      final scheduledTime = DateTime(now.year, now.month, now.day, 21, 0);
      if (scheduledTime.isAfter(now)) {
        await notificationService.scheduleDailyReminder(
          id: 1,
          title: 'Evening Review 🌙',
          body: 'Review your goals and plan for tomorrow!',
          hour: 21,
          minute: 0,
        );
      }
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
      if (!await notificationService.hasShownUnreadNotification) {
        await notificationService.showNotification(
          title: 'Taste Turner - New Message',
          body: 'You have $unreadCount unread messages',
        );
        await notificationService.setHasShownUnreadNotification(true);
      }
    } else if (_lastUnreadCount > 0) {
      // Only reset if we're transitioning from unread to read
      await notificationService.resetUnreadNotificationState();
    }

    _lastUnreadCount = unreadCount; // Update last unread count
  }

  // Add this helper method to check if date is today
  bool getCurrentDate(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _loadShowCaloriesPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      showCaloriesAndGoal = prefs.getBool(_showCaloriesPrefKey) ?? true;
    });
  }

  Future<void> _saveShowCaloriesPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showCaloriesPrefKey, value);
  }

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    // SizeConfig().init(context);
    final winners = helperController.winners;

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
      final announceDate =
          DateTime.parse(firebaseService.generalData['isAnnounceDate']);
      final isAnnounceShow = isDateTodayAfterTime(announceDate);

      // Safely access user data with null checks
      familyMode = currentUser.familyMode ?? false;
      final inspiration = currentUser.bio ?? getRandomBio(bios);
      final avatarUrl = currentUser.profileImage ?? intPlaceholderImage;

      return Scaffold(
        drawer: const CustomDrawer(),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(getProportionalHeight(85, context)),
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
                                '$greeting ${currentUser.displayName}!',
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
        floatingActionButtonLocation: CustomFloatingActionButtonLocation(
          verticalOffset: getPercentageHeight(5, context),
          horizontalOffset: getPercentageWidth(2, context),
        ),
        floatingActionButton: buildTastyFloatingActionButton(
          context: context,
          buttonKey: _addHomeButtonKey,
          themeProvider: getThemeProvider(context),
          isInFreeTrial: isInFreeTrial,
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
                              '${getRelativeDayString(currentDate)},',
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
                        //challenge
                        SecondNavWidget(
                          label: 'Diary',
                          icon: 'assets/images/svg/diary.svg',
                          color: isDarkMode
                              ? kAccent
                              : kAccent.withValues(alpha: 0.5),
                          destinationScreen: const AddFoodScreen(),
                          isDarkMode: isDarkMode,
                        ),
                        //shopping
                        SecondNavWidget(
                          label: 'Challenge',
                          icon: 'assets/images/svg/target.svg',
                          color:
                              isDarkMode ? kBlue : kBlue.withValues(alpha: 0.5),
                          destinationScreen: const FoodChallengeScreen(),
                          isDarkMode: isDarkMode,
                        ),
                        //Planner
                        SecondNavWidget(
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

                  //water, track, steps, spin

                  if (winners.isNotEmpty && isAnnounceShow)
                    SizedBox(height: getPercentageHeight(1, context)),

                  if (winners.isNotEmpty && isAnnounceShow)
                    AnnouncementWidget(
                      title: '🏆 Winners of the week 🏆',
                      announcements: winners,
                      height: getPercentageHeight(
                          5, context), // Optional, defaults to 90
                      onTap: () {
                        // Handle tap
                      },
                    ),
                  if (winners.isNotEmpty && isAnnounceShow)
                    SizedBox(height: getPercentageHeight(1, context)),

                  currentUser.isPremium ?? false
                      ? const SizedBox.shrink()
                      : SizedBox(height: getPercentageHeight(0.5, context)),

                  // ------------------------------------Premium / Ads------------------------------------

                  currentUser.isPremium ?? false
                      ? const SizedBox.shrink()
                      : PremiumSection(
                          isPremium: currentUser.isPremium ?? false,
                          titleOne: joinChallenges,
                          titleTwo: premium,
                          isDiv: false,
                        ),

                  // ------------------------------------Premium / Ads-------------------------------------
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
                                  _saveShowCaloriesPref(showCaloriesAndGoal);
                                },
                                onEdit: (editedUser, isDarkMode) {
                                  // Implement edit logic, maybe show a dialog
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),
                          if (hasMealPlan &&
                              currentDate.isAfter(DateTime.now()
                                  .subtract(const Duration(days: 1)))) ...[
                            FutureBuilder<List<MealWithType>>(
                              future: _loadMealsForUI(
                                  displayList[selectedUserIndex]['name']
                                      as String,
                                  familyList),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator(
                                    color: kAccent,
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal:
                                          getPercentageWidth(2, context)),
                                  child: Container(
                                    padding: EdgeInsets.all(
                                        getPercentageWidth(2, context)),
                                    decoration: BoxDecoration(
                                      color: colors[
                                              selectedUserIndex % colors.length]
                                          .withValues(alpha: kMidOpacity),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: colors[selectedUserIndex %
                                              colors.length],
                                          width: 1.5),
                                    ),
                                    child: MealPlanSection(
                                      meals: snapshot.data!,
                                      mealPlan: mealPlan,
                                      isDarkMode: isDarkMode,
                                      showCaloriesAndGoal: showCaloriesAndGoal,
                                      user: user,
                                      color: colors[
                                          selectedUserIndex % colors.length],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          SizedBox(height: getPercentageHeight(3, context)),
                        ],
                      );
                    },
                  ),
                  SizedBox(
                    height: getPercentageHeight(6, context),
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
