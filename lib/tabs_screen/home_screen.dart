import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../screens/message_screen.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/announcement.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/goal_dash_card.dart';
import '../widgets/premium_widget.dart';
import '../widgets/daily_routine_list_horizontal.dart';
import '../widgets/ingredient_battle_widget.dart';
import '../widgets/bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int currentPage = 0;
  final PageController _pageController = PageController();
  final ValueNotifier<double> currentNotifier = ValueNotifier<double>(0);
  final ValueNotifier<double> currentStepsNotifier = ValueNotifier<double>(0);
  bool familyMode = userService.currentUser?.familyMode ?? false;
  Timer? _tastyPopupTimer;
  bool allDisabled = false;
  int _lastUnreadCount = 0; // Track last unread count
  DateTime currentDate = DateTime.now();
  final GlobalKey _addMealButtonKey = GlobalKey();
  final GlobalKey _addProfileButtonKey = GlobalKey();
  String? _shoppingDay;
  int selectedUserIndex = 0;
  List<Map<String, dynamic>> familyList = [];
  bool hasMealPlan = true;
  @override
  void initState() {
    super.initState();
    // _initializeMealData();
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
    QuerySnapshot snapshot = await firestore
        .collection('mealPlans')
        .doc(userService.userId)
        .collection('date')
        .where('date', isEqualTo: date)
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
    _scheduleMealReminderNotification();
  }

  Future<void> _scheduleMealReminderNotification() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);
    await loadMeals(tomorrowStr);

    if (hasMealPlan == false) {
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
    userService.currentUser?.settings.forEach((key, value) {
      settings[key.toString()] = value.toString();
    });

    await dailyDataController.fetchAllMealData(
        userService.userId!, settings, DateTime.now());
    await firebaseService.fetchGeneralData();
  }

  void _initializeMealDataByDate() async {
    Map<String, String> settings = {};
    userService.currentUser?.settings.forEach((key, value) {
      settings[key.toString()] = value.toString();
    });

    await dailyDataController.fetchAllMealDataByDate(
        userService.userId!, settings, currentDate);
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
          title: 'Unread Messages',
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

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    // SizeConfig().init(context);
    final winners = helperController.winners;
    final announceDate =
        DateTime.parse(firebaseService.generalData['isAnnounceDate']);
    final isAnnounceShow = isDateTodayAfterTime(announceDate);
    // Safely access user data with null checks
    final currentUser = userService.currentUser;
    if (currentUser == null) {
      // Show a loading state if user data isn't available yet
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: kAccent),
        ),
      );
    }
    final inspiration = currentUser.bio ?? getRandomBio(bios);
    final avatarUrl = currentUser.profileImage ?? intPlaceholderImage;

    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(getProportionalHeight(100, context)),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? kLightGrey.withOpacity(0.1) : kWhite,
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
                              radius: getPercentageWidth(6, context),
                              backgroundColor: kAccent.withOpacity(kOpacity),
                              child: CircleAvatar(
                                backgroundImage: getAvatarImage(avatarUrl),
                                radius: getPercentageWidth(5.5, context),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    currentUser.displayName?.length != null &&
                                            currentUser.displayName!.length > 10
                                        ? getPercentageWidth(4, context)
                                        : getPercentageWidth(4.5, context),
                              ),
                            ),
                            Text(
                              inspiration,
                              style: TextStyle(
                                fontSize:
                                    currentUser.displayName?.length != null &&
                                            currentUser.displayName!.length > 15
                                        ? getPercentageWidth(2.5, context)
                                        : getPercentageWidth(3, context),
                                fontWeight: FontWeight.w400,
                                color: kLightGrey,
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
                            height: getPercentageWidth(6.5, context),
                            width: getPercentageWidth(6.5, context),
                            color: isDarkMode ? kAccent : kDarkGrey,
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
                                  horizontal: getPercentageWidth(1.5, context),
                                  vertical: getPercentageWidth(0.5, context)),
                              decoration: BoxDecoration(
                                color: kRed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: getPercentageWidth(2.5, context),
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
                    height: MediaQuery.of(context).size.height > 1100
                        ? getPercentageHeight(2, context)
                        : getPercentageHeight(0.5, context)),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(0.3, context)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          final DateTime sevenDaysAgo =
                              DateTime.now().subtract(const Duration(days: 7));
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
                          size: getPercentageWidth(4.5, context),
                          color: currentDate.isBefore(DateTime.now()
                                  .subtract(const Duration(days: 7)))
                              ? isDarkMode
                                  ? kLightGrey.withOpacity(0.5)
                                  : kDarkGrey.withOpacity(0.1)
                              : null,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${getRelativeDayString(currentDate)},',
                            style: TextStyle(
                              fontSize: getPercentageWidth(4, context),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(width: getPercentageWidth(0.5, context)),
                          if (getRelativeDayString(currentDate) != 'Today' &&
                              getRelativeDayString(currentDate) != 'Yesterday')
                            Text(
                              DateFormat('d MMMM').format(currentDate),
                              style: TextStyle(
                                fontSize: getPercentageWidth(4, context),
                                fontWeight: FontWeight.w400,
                                color: Colors.amber[700],
                              ),
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
                          size: getPercentageWidth(4.5, context),
                          color: getCurrentDate(currentDate)
                              ? isDarkMode
                                  ? kLightGrey.withOpacity(0.5)
                                  : kDarkGrey.withOpacity(0.1)
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

                // Add Horizontal Routine List
                if (!allDisabled)
                  DailyRoutineListHorizontal(
                      userId: userService.userId!, date: currentDate),
                if (!allDisabled)
                  SizedBox(height: getPercentageHeight(1, context)),

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

                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : SizedBox(height: getPercentageHeight(0.5, context)),

                // ------------------------------------Premium / Ads------------------------------------

                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : PremiumSection(
                        isPremium: userService.currentUser?.isPremium ?? false,
                        titleOne: joinChallenges,
                        titleTwo: premium,
                        isDiv: false,
                      ),

                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : SizedBox(height: getPercentageHeight(1, context)),
                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : Divider(color: isDarkMode ? kWhite : kDarkGrey),

                // ------------------------------------Premium / Ads-------------------------------------
                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : SizedBox(height: getPercentageHeight(1, context)),

                if (_isTodayShoppingDay())
                  Container(
                    margin: EdgeInsets.all(getPercentageWidth(1, context)),
                    padding: EdgeInsets.all(getPercentageWidth(3, context)),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shopping_cart,
                            color: kAccent,
                            size: getPercentageWidth(10, context)),
                        SizedBox(width: getPercentageWidth(1, context)),
                        Expanded(
                          child: Text(
                            "It's your shopping day! Don't forget to check your shopping list.",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: getPercentageWidth(3.5, context),
                              color: kAccent,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(getPercentageWidth(10, context),
                                getPercentageHeight(5, context)),
                            backgroundColor: kAccent,
                            foregroundColor: kWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BottomNavSec(
                                    selectedIndex: 3, foodScreenTabIndex: 1),
                              ),
                            );
                          },
                          child: Text('Go',
                              style: TextStyle(
                                  fontSize: getPercentageWidth(3.5, context))),
                        ),
                      ],
                    ),
                  ),
                if (_isTodayShoppingDay())
                  SizedBox(height: getPercentageHeight(1, context)),

                // Nutrition Overview
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      height: _calculateHeight(
                        context: context,
                        maxHeight: constraints.maxHeight,
                        hasFamilyMode: familyMode,
                        hasMealPlan: hasMealPlan,
                      ),
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (value) => setState(() {
                          currentPage = value;
                        }),
                        children: [
                          DailyNutritionOverview(
                            settings: userService.currentUser?.settings ??
                                {} as Map<String, dynamic>,
                            currentDate: currentDate,
                            familyMode: familyMode,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Weekly Ingredients Battle Widget
                const WeeklyIngredientBattle(),

                SizedBox(
                  height: getPercentageHeight(6, context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double _calculateHeight({
  required BuildContext context,
  required double maxHeight,
  required bool hasFamilyMode,
  required bool hasMealPlan,
}) {
  // Use maxHeight if it's finite, otherwise fallback to screen height
  final double availableHeight = (maxHeight.isFinite && maxHeight > 0)
      ? maxHeight
      : MediaQuery.of(context).size.height;

  double designHeight;

  if (availableHeight > 1100) {
    designHeight =
        hasFamilyMode ? (hasMealPlan ? 570 : 435) : (hasMealPlan ? 485 : 350);
  } else if (availableHeight > 855 && availableHeight < 1009) {
    designHeight =
        hasFamilyMode ? (hasMealPlan ? 470 : 350) : (hasMealPlan ? 385 : 270);
  } else if (availableHeight > 700 && availableHeight <= 855) {
    designHeight =
        hasFamilyMode ? (hasMealPlan ? 475 : 360) : (hasMealPlan ? 400 : 270);
  } else {
    designHeight =
        hasFamilyMode ? (hasMealPlan ? 540 : 390) : (hasMealPlan ? 460 : 320);
  }

  double calculated = (designHeight / 840.0) * availableHeight;

  // Clamp to availableHeight to avoid overflow
  return calculated.clamp(0, availableHeight);
}
