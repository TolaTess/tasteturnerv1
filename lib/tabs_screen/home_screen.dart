import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/utils.dart';
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
    // Show Tasty popup after a short delay
    _tastyPopupTimer = Timer(const Duration(milliseconds: 4000), () {
      if (mounted) {
        tastyPopupService.showTastyPopup(context, 'home', [], []);
      }
    });
  }

   Future<bool> _getAllDisabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('allDisabledKey') ?? false;
  }

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),

              // Add Horizontal Routine List
              if (!allDisabled)
                DailyRoutineListHorizontal(userId: userService.userId!),
              if (!allDisabled) const SizedBox(height: 15),
              if (!allDisabled) Divider(color: isDarkMode ? kWhite : kDarkGrey),
              if (!allDisabled) const SizedBox(height: 15),

              // Weekly Ingredients Battle Widget
              const WeeklyIngredientBattle(),

              const SizedBox(height: 15),
              Divider(color: isDarkMode ? kWhite : kDarkGrey),
              const SizedBox(height: 15),

              // PageView - today macros and macro breakdown
              SizedBox(
                height: 225,
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
