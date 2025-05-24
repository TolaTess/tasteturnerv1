import 'dart:async';

import 'package:flutter/material.dart';
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
import '../widgets/date_widget.dart';
import '../widgets/icon_widget.dart';
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
  Timer? _tastyPopupTimer;
  bool allDisabled = false;
  int _lastUnreadCount = 0; // Track last unread count
  DateTime currentDate = DateTime.now();
  final GlobalKey _addMealButtonKey = GlobalKey();
  final GlobalKey _addProfileButtonKey = GlobalKey();
  String? _shoppingDay;

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

  void _setupDataListeners() {
    // Show Tasty popup after a short delay
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    _initializeMealData();
    chatController.loadUserChats(userService.userId ?? '');
    await helperController.fetchWinners();
    await firebaseService.fetchGeneralData();
    if (mounted) setState(() {});
  }

  void _initializeMealData() async {
    await dailyDataController.fetchAllMealData(
        userService.userId!, userService.currentUser!.settings, DateTime.now());
    await firebaseService.fetchGeneralData();
  }

  void _initializeMealDataByDate() async {
    await dailyDataController.fetchAllMealDataByDate(
        userService.userId!, userService.currentUser!.settings, currentDate);
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
        preferredSize: const Size.fromHeight(75),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? kLightGrey.withOpacity(0.1) : kWhite,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting ${currentUser.displayName}!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: getPercentageWidth(4.5, context),
                              ),
                            ),
                            Text(
                              inspiration,
                              style: TextStyle(
                                fontSize: getPercentageWidth(3, context),
                                fontWeight: FontWeight.w400,
                                color: kLightGrey,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
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
                          child: IconCircleButton(
                            icon: Icons.message,
                            h: getPercentageWidth(11, context),
                            w: getPercentageWidth(11, context), 
                            colorD: kAccent.withOpacity(0.6),
                            colorL: kDarkGrey.withOpacity(0.6),
                            isRemoveContainer: true,
                          ),
                        ),
                        SizedBox(width: getPercentageWidth(1, context)),

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
                                  horizontal: getPercentageWidth(1, context), vertical: getPercentageWidth(0.5, context)),
                              decoration: BoxDecoration(
                                color: kRed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: getPercentageWidth(3, context),
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
            padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(0.3, context)),
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
                            // _initializeRoutineDataByDate();
                          }
                        },
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
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
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (getRelativeDayString(currentDate) != 'Today' && 
                              getRelativeDayString(currentDate) != 'Yesterday')
                            Text(
                              DateFormat('d MMMM').format(currentDate),
                              style: TextStyle(
                                fontSize: 20,
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
                          size: 20,
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

                // Add Horizontal Routine List
                if (!allDisabled)
                  DailyRoutineListHorizontal(
                      userId: userService.userId!, date: currentDate),
                if (!allDisabled) const SizedBox(height: 10),
                if (!allDisabled)
                  Divider(color: isDarkMode ? kWhite : kDarkGrey),
                if (!allDisabled) const SizedBox(height: 5),

                if (winners.isNotEmpty && isAnnounceShow)
                  AnnouncementWidget(
                    title: '🏆 Winners of the week 🏆',
                    announcements: winners,
                    height: 50, // Optional, defaults to 90
                    onTap: () {
                      // Handle tap
                    },
                  ),
                if (winners.isNotEmpty && isAnnounceShow)
                  const SizedBox(height: 10),

                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : const SizedBox(height: 5),

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
                    : const SizedBox(height: 10),
                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : Divider(color: isDarkMode ? kWhite : kDarkGrey),

                // ------------------------------------Premium / Ads-------------------------------------
                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : const SizedBox(height: 10),

                if (_isTodayShoppingDay())
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart,
                            color: kAccent, size: 32),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            "It's your shopping day! Don't forget to check your shopping list.",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: kAccent,
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BottomNavSec(
                                    selectedIndex: 3, foodScreenTabIndex: 1),
                              ),
                            );
                          },
                          child: const Text('Go'),
                        ),
                      ],
                    ),
                  ),
                if (_isTodayShoppingDay()) const SizedBox(height: 10),

                // Nutrition Overview
                SizedBox(
                  height: 200,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (value) => setState(() {
                      currentPage = value;
                    }),
                    children: [
                      DailyNutritionOverview(
                        settings: userService.currentUser!.settings,
                        key: _addMealButtonKey,
                        currentDate: currentDate,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                Divider(color: isDarkMode ? kWhite : kDarkGrey),
                const SizedBox(height: 8),

                // Weekly Ingredients Battle Widget
                const WeeklyIngredientBattle(),

                const SizedBox(
                  height: 60,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
