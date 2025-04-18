import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../screens/message_screen.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/date_widget.dart';
import '../widgets/bottom_model.dart';
import '../widgets/home_widget.dart';
import '../screens/add_food_screen.dart';
import '../widgets/premium_widget.dart';
import '../service/health_service.dart';
import '../pages/update_steps.dart';
import '../widgets/ingredient_battle_widget.dart';
import '../widgets/daily_routine_list_horizontal.dart';

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

  void _openDailyFoodPage(
    BuildContext context,
    double total,
    double current,
    String text,
    bool isWater,
  ) {
    showModel(
      context,
      text,
      total,
      current,
      isWater,
      currentNotifier,
    );
  }

  void _openStepsUpdatePage(
    BuildContext context,
    double total,
    double current,
    String title,
    bool isHealthSynced,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: UpdateStepsModal(
          total: total,
          current: current,
          title: title,
          isHealthSynced: isHealthSynced,
          currentNotifier: currentStepsNotifier,
        ),
      ),
    );
  }

  // Check if we've already sent a notification today for steps goal
  // and send one if we haven't
  void _checkAndSendStepGoalNotification(
      int currentSteps, int targetSteps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String stepNotificationKey = 'step_goal_notification_$today';

      // Check if we've already sent a notification today
      final bool alreadySentToday = prefs.getBool(stepNotificationKey) ?? false;

      if (!alreadySentToday) {
        // Send notification
        await notificationService.showNotification(
          id: 2002, // Unique ID for step goal notification
          title: 'Daily Step Goal Achieved! 🏃‍♂️',
          body:
              'Congratulations! You reached your goal of $targetSteps steps today. Keep moving!',
        );

        // Mark that we've sent a notification today
        await prefs.setBool(stepNotificationKey, true);
      }
    } catch (e) {
      print('Error sending step goal notification: $e');
    }
  }

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
    _initializeMealData();
    chatController.loadUserChats(userService.userId ?? '');
    // Show Tasty popup after a short delay
    _tastyPopupTimer = Timer(const Duration(milliseconds: 4000), () {
      if (mounted) {
        tastyPopupService.showTastyPopup(context, 'home', [], []);
      }
    });
  }

  void _initializeMealData() async {
    await dailyDataController.fetchAllMealData(
        userService.userId!, userService.currentUser!.settings);
  }

  Future<bool> _getAllDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('allDisabledKey') ?? false;
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

  ImageProvider _getAvatarImage(String? imageUrl) {
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        imageUrl.startsWith("http") &&
        imageUrl != "null") {
      return NetworkImage(imageUrl);
    }
    return const AssetImage(intPlaceholderImage);
  }

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    // Safely access user data with null checks
    final currentUser = userService.currentUser;
    if (currentUser == null) {
      // Show a loading state if user data isn't available yet
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final inspiration = currentUser.bio ?? getRandomBio(bios);
    final avatarUrl = currentUser.profileImage ?? intPlaceholderImage;
    final formattedDate = DateFormat('d MMMM').format(currentDate);

    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                            radius: 25,
                            backgroundColor: kAccent.withOpacity(kOpacity),
                            child: CircleAvatar(
                              backgroundImage: _getAvatarImage(avatarUrl),
                              radius: 23,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            inspiration,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: kLightGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Message Section
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? kDarkModeAccent.withOpacity(kLowOpacity)
                          : kBackgroundColor,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
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
                          child: Icon(Icons.message,
                              size: 30, color: kAccent.withOpacity(0.6)),
                        ),
                        const SizedBox(width: 5),

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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: kRed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            );
                          } else {
                            return const SizedBox
                                .shrink(); // Hide badge if unreadCount is 0
                          }
                        }),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                        }
                      },
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: currentDate.isBefore(DateTime.now()
                                .subtract(const Duration(days: 7)))
                            ? kLightGrey.withOpacity(0.5)
                            : null,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          DateFormat('EEEE').format(currentDate),
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('d MMMM').format(currentDate),
                          style: TextStyle(
                            fontSize: 14,
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
                          // Only allow moving forward if next date is not after today
                          if (!nextDate.isAfter(
                              DateTime(now.year, now.month, now.day))) {
                            currentDate = nextDate;
                          } else {
                            currentDate =
                                DateTime(now.year, now.month, now.day);
                          }
                        });
                      },
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        size: 20,
                        color: currentDate.isAtSameMomentAs(DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ))
                            ? kLightGrey.withOpacity(0.5)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Add Horizontal Routine List
              if (!allDisabled)
                DailyRoutineListHorizontal(userId: userService.userId!),
              if (!allDisabled) const SizedBox(height: 15),
              if (!allDisabled) Divider(color: isDarkMode ? kWhite : kDarkGrey),
              if (!allDisabled) const SizedBox(height: 10),

              // PageView - today macros and macro breakdown
              SizedBox(
                height: 180,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (value) => setState(() {
                    currentPage = value;
                  }),
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddFoodScreen(
                                //todo

                                ),
                          ),
                        );
                      },
                      child: DailyNutritionOverview(
                        settings: userService.currentUser!.settings,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Divider(color: isDarkMode ? kWhite : kDarkGrey),
              const SizedBox(height: 10),

              // Weekly Ingredients Battle Widget
              const WeeklyIngredientBattle(),

              const SizedBox(height: 15),
              Divider(color: isDarkMode ? kWhite : kDarkGrey),
              const SizedBox(height: 8),

              // Icons Navigation

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
              const SizedBox(height: 20),

              // Water and Activity status widgets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Obx(() {
                    final settings = userService.currentUser!.settings;
                    final double waterTotal = settings['waterIntake'] != null
                        ? double.tryParse(settings['waterIntake'].toString()) ??
                            0.0
                        : 0.0;
                    final double currentWater =
                        dailyDataController.currentWater.value.toDouble();

                    return StatusWidgetBox(
                      title: water,
                      total: waterTotal,
                      current: currentWater,
                      sym: ml,
                      isSquare: true,
                      upperColor: kBlue,
                      isWater: true,
                      press: () {
                        _openDailyFoodPage(
                          context,
                          waterTotal,
                          currentWater,
                          "Water Tracker",
                          true,
                        );
                      },
                    );
                  }),
                  const SizedBox(width: 35),
                  Obx(() {
                    final healthService = Get.find<HealthService>();
                    final settings = userService.currentUser!.settings;

                    // Get steps from health service if synced, otherwise from settings
                    int currentSteps;
                    if (healthService.isAuthorized.value) {
                      currentSteps = healthService.steps.value;
                    } else {
                      currentSteps =
                          dailyDataController.currentSteps.value.toInt();
                    }

                    // Get target steps from settings, default to 10000 if not set
                    final int targetSteps = int.tryParse(
                            settings['targetSteps']?.toString() ?? '10000') ??
                        10000;

                    // Check if current steps meet or exceed target steps and notify user
                    if (currentSteps >= targetSteps && targetSteps > 0) {
                      // Use SharedPreferences to check if we've already sent a notification today
                      _checkAndSendStepGoalNotification(
                          currentSteps, targetSteps);
                    }

                    return StatusWidgetBox(
                      current: currentSteps.toDouble(),
                      title: "Steps",
                      total: targetSteps.toDouble(),
                      sym: "steps",
                      isSquare: true,
                      upperColor: kAccent,
                      press: () {
                        _openStepsUpdatePage(
                          context,
                          targetSteps.toDouble(),
                          currentSteps.toDouble(),
                          "Steps Tracker",
                          healthService.isAuthorized.value,
                        );
                      },
                    );
                  }),
                ],
              ),

              const SizedBox(height: 72),
            ],
          ),
        ),
      ),
    );
  }
}
