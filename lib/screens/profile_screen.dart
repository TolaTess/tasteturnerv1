import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; // Add this import for ImageFilter
import 'package:get/get.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../constants.dart';
import '../data_models/post_model.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../helper/utils.dart';
import '../pages/edit_goal.dart';
import '../pages/profile_edit_screen.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/icon_widget.dart';
import '../widgets/helper_widget.dart';
import '../widgets/daily_summary_widget.dart';
import 'badges_screen.dart';
import '../pages/settings_screen.dart';
import '../service/post_service.dart';
import '../service/badge_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'daily_summary_screen.dart';
import '../helper/onboarding_prompt_helper.dart';
import '../widgets/onboarding_prompt.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../widgets/optimized_image.dart';
import '../widgets/tutorial_blocker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool lastStatus = true;
  bool showAll = false;
  List<Map<String, dynamic>> searchContentDatas = [];
  late Future<Map<String, dynamic>> chartDataFuture;
  final userId = userService.userId ?? '';
  bool isPostsLoading = true;
  bool isMealsLoading = false;
  bool showMeals = false; // Toggle between posts and meals
  List<Meal> userMeals = [];
  final GlobalKey _addSettingsButtonKey = GlobalKey();
  final GlobalKey _addBadgesButtonKey = GlobalKey();
  final GlobalKey _addWeightButtonKey = GlobalKey();
  late ScrollController _scrollController;
  bool _showWeightPrompt = false;

  _scrollListener() {
    if (isShrink != lastStatus) {
      setState(() {
        lastStatus = isShrink;
      });
    }
  }

  bool get isShrink {
    return _scrollController.hasClients &&
        _scrollController.offset > (260 - kToolbarHeight);
  }

  @override
  void initState() {
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    // Load badges for current user
    BadgeService.instance.loadUserProgress(userId);
    _fetchContent(userId);
    chartDataFuture = fetchChartData(userId);
    // Points are now loaded as part of BadgeService.loadUserProgress
    authController.listenToUserData(userId);
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddMealTutorial();
      _checkWeightPromptAfterTutorial();
    });
  }

  void _showAddMealTutorial() {
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'profile_screen_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'add_settings_button',
          message: 'Tap here to view your settings!',
          targetKey: _addSettingsButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_badges_button',
          message: 'Tap here to view your badges and points!',
          targetKey: _addBadgesButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_weight_button',
          message: 'Tap here to view your weight and goals!',
          targetKey: _addWeightButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
      ],
    );
  }

  Future<void> _checkWeightPrompt() async {
    final shouldShow = await OnboardingPromptHelper.shouldShowWeightPrompt();
    if (mounted) {
      setState(() {
        _showWeightPrompt = shouldShow;
      });
    }
  }

  Future<void> _checkWeightPromptAfterTutorial() async {
    // Wait 30 seconds after tutorial starts
    await Future.delayed(const Duration(seconds: 60));
    if (mounted) {
      await _checkWeightPrompt();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Points are now handled by BadgeService
  }

  /// Handle errors with consistent snackbar display
  void _handleError(String message, {String? details}) {
    if (!mounted || !context.mounted) return;
    debugPrint('Error: $message${details != null ? ' - $details' : ''}');
    showTastySnackbar(
      'Error',
      message,
      context,
      backgroundColor: Colors.red,
    );
  }

  Future<Map<String, dynamic>> fetchChartData(String userid) async {
    try {
      final caloriesByDate =
          await dailyDataController.fetchCaloriesByDate(userid);
      List<String> dateLabels = [];
      List<FlSpot> chartData = prepareChartData(caloriesByDate, dateLabels);

      return {
        'chartData': chartData,
        'dateLabels': dateLabels,
      };
    } catch (e) {
      debugPrint('Error fetching chart data: $e');
      // Return empty data on error
      return {
        'chartData': <FlSpot>[],
        'dateLabels': <String>[],
      };
    }
  }

  List<FlSpot> prepareChartData(
      Map<String, int> caloriesByDate, List<String> dateLabels) {
    List<FlSpot> spots = [];
    final sortedDates = caloriesByDate.keys.toList()
      ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));

    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final calories = caloriesByDate[date]!;
      spots.add(FlSpot(i.toDouble(), calories.toDouble()));
      dateLabels.add(date); // Populate date labels for the x-axis
    }

    return spots;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchContent(String userId) async {
    if (mounted) {
      setState(() {
        isPostsLoading = true;
        searchContentDatas = [];
      });
    }

    try {
      // Use new optimized PostService for user posts
      final postService = PostService.instance;
      final result = await postService.getUserPosts(
        userId: userId,
        limit: 50, // Load more posts for profile
        includeUserData: true,
      );

      if (result.isSuccess && mounted) {
        setState(() {
          searchContentDatas = result.posts;
          isPostsLoading = false;
        });
      } else if (mounted) {
        setState(() {
          searchContentDatas = [];
          isPostsLoading = false;
        });
        if (result.error != null) {
          _handleError('Failed to load posts. Please try again.',
              details: result.error);
        }
      }
    } catch (e) {
      _handleError('Failed to load posts. Please try again.',
          details: e.toString());
      if (mounted) {
        setState(() {
          searchContentDatas = [];
          isPostsLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserMeals(String userId) async {
    if (mounted) {
      setState(() {
        isMealsLoading = true;
        userMeals = [];
      });
    }

    try {
      // Fetch meals created by this user
      final snapshot = await firestore
          .collection('meals')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (mounted) {
        final meals = snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                return Meal.fromJson(doc.id, data);
              } catch (e) {
                debugPrint('Error parsing meal ${doc.id}: $e');
                return null;
              }
            })
            .whereType<Meal>()
            .toList();

        setState(() {
          userMeals = meals;
          isMealsLoading = false;
        });
      }
    } catch (e) {
      _handleError('Failed to load meals. Please try again.',
          details: e.toString());
      if (mounted) {
        setState(() {
          userMeals = [];
          isMealsLoading = false;
        });
      }
    }
  }

  double calculateWeightProgress(
      double startWeight, double goalWeight, double currentWeight) {
    if (startWeight == 0 || startWeight == goalWeight) {
      return 100.0; // ✅ If no weight change needed, progress is complete
    }

    if (startWeight > goalWeight) {
      // ✅ Weight loss goal
      double totalWeightToLose = startWeight - goalWeight;
      double weightLost = startWeight - currentWeight;
      double progress = (weightLost / totalWeightToLose) * 100;
      return progress.clamp(0.0, 100.0);
    } else {
      // ✅ Weight gain goal
      double totalWeightToGain = goalWeight - startWeight;
      double weightGained = currentWeight - startWeight;
      double progress = (weightGained / totalWeightToGain) * 100;
      return progress.clamp(0.0, 100.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final name = userService.currentUser.value!.displayName ?? '';
    final firstName = name.split(' ').first;
    final nameCapitalized = capitalizeFirstLetter(firstName);
    final settings = userService.currentUser.value!.settings;
    final double startWeight = double.tryParse(
            getNumberBeforeSpace(settings['startingWeight'].toString())) ??
        0.0;

    final double currentWeight = double.tryParse(
            getNumberBeforeSpace(settings['currentWeight'].toString())) ??
        startWeight;
    final double goalWeight = double.tryParse(
            getNumberBeforeSpace(settings['goalWeight'].toString())) ??
        0.0;
    double progressPercentage =
        calculateWeightProgress(startWeight, goalWeight, currentWeight) / 100;
    final fitnessGoal =
        userService.currentUser.value?.settings['fitnessGoal'] ?? '';
    final shouldShowGoals = ["Family Nutrition"].contains(fitnessGoal);

    return Scaffold(
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
        child: SafeArea(
          child: BlockableCustomScrollView(
              controller: _scrollController,
              slivers: [
                // AppBar
                SliverAppBar(
                  pinned: true,
                  automaticallyImplyLeading: false,
                  expandedHeight: MediaQuery.of(context).size.height > 1100
                      ? getPercentageHeight(45, context)
                      : getPercentageHeight(43, context),
                  title: isShrink
                      ? Text(
                          'Chef $nameCapitalized',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: getTextScale(4.5, context),
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        )
                      : const Text(emptyString),
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarIconBrightness:
                        isShrink ? Brightness.dark : Brightness.light,
                  ),
                  iconTheme: IconThemeData(
                    color: isShrink
                        ? isDarkMode
                            ? kWhite.withValues(alpha: 0.80)
                            : kBlack
                        : isDarkMode
                            ? kLightGrey
                            : kPrimaryColor,
                  ),
                  leading: InkWell(
                    onTap: () => Get.back(),
                    child: const IconCircleButton(),
                  ),
                  actions: [
                    GestureDetector(
                      key: _addSettingsButtonKey,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingsScreen()));
                      },
                      child: const IconCircleButton(
                        isRemoveContainer: true,
                        icon: Icons.settings,
                        size: kIconSizeMedium,
                      ),
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Column(
                      children: [
                        Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(6, context)),
                              child: Container(
                                margin: EdgeInsets.only(
                                    top: getPercentageHeight(10.5, context)),
                                padding: EdgeInsets.only(
                                    top: getPercentageHeight(10.5, context)),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                      image: userService.currentUser.value
                                                      ?.profileImage !=
                                                  null &&
                                              userService.currentUser.value!
                                                  .profileImage!.isNotEmpty &&
                                              userService.currentUser.value!
                                                  .profileImage!
                                                  .contains('http')
                                          ? CachedNetworkImageProvider(
                                              userService.currentUser.value!
                                                  .profileImage!)
                                          : const AssetImage(
                                                  intPlaceholderImage)
                                              as ImageProvider,
                                      fit: BoxFit.cover),
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                        height:
                                            getPercentageHeight(2, context)),
                                    Center(
                                      child: GestureDetector(
                                        onTap: () => Get.to(
                                            () => const ProfileEditScreen()),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                                sigmaX: 5.0, sigmaY: 5.0),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                vertical: getPercentageHeight(
                                                    1, context),
                                                horizontal: getPercentageWidth(
                                                    3, context),
                                              ),
                                              decoration: BoxDecoration(
                                                color: (isDarkMode
                                                    ? kDarkGrey.withValues(
                                                        alpha: 0.5)
                                                    : kWhite.withValues(
                                                        alpha: 0.5)),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'Chef ${capitalizeFirstLetter(userService.currentUser.value!.displayName ?? '')}',
                                                style: textTheme.displaySmall
                                                    ?.copyWith(
                                                  fontSize:
                                                      getTextScale(5, context),
                                                  fontWeight: FontWeight.w600,
                                                  color: isDarkMode
                                                      ? kWhite
                                                      : kBlack,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(2, context)),
                                    ClipRRect(
                                      key: _addBadgesButtonKey,
                                      borderRadius: BorderRadius.circular(15),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 5.0, sigmaY: 5.0),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical:
                                                getPercentageHeight(1, context),
                                            horizontal:
                                                getPercentageWidth(3, context),
                                          ),
                                          decoration: BoxDecoration(
                                            color: (isDarkMode
                                                ? kDarkGrey.withValues(
                                                    alpha: 0.5)
                                                : kWhite.withValues(
                                                    alpha: 0.5)),
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              // Points
                                              GestureDetector(
                                                onTap: () => Get.to(
                                                    () => BadgesScreen()),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      badgeService.totalPoints
                                                          .toString(),
                                                      style: textTheme.bodyLarge
                                                          ?.copyWith(
                                                        color: isDarkMode
                                                            ? kWhite
                                                            : kBlack,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    Opacity(
                                                      opacity: 0.7,
                                                      child: Text(
                                                        'Points',
                                                        style: textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                          color: isDarkMode
                                                              ? kWhite
                                                              : kBlack,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                height: getPercentageHeight(
                                                    3, context),
                                                child: Opacity(
                                                  opacity: 0.5,
                                                  child: VerticalDivider(
                                                    color: isDarkMode
                                                        ? kWhite
                                                        : kDarkGrey,
                                                    thickness: 1,
                                                  ),
                                                ),
                                              ),
                                              // Badges
                                              GestureDetector(
                                                onTap: () => Get.to(
                                                    () => BadgesScreen()),
                                                child: Column(
                                                  children: [
                                                    Obx(() {
                                                      final earnedBadges =
                                                          BadgeService.instance
                                                              .earnedBadges;
                                                      return Text(
                                                        earnedBadges.length
                                                            .toString(),
                                                        style: textTheme
                                                            .bodyLarge
                                                            ?.copyWith(
                                                          color: isDarkMode
                                                              ? kWhite
                                                              : kBlack,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      );
                                                    }),
                                                    Opacity(
                                                      opacity: 0.5,
                                                      child: Text(
                                                        badges,
                                                        style: textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                          color: isDarkMode
                                                              ? kWhite
                                                              : kBlack,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Get.to(() => const ProfileEditScreen());
                              },
                              child: CircleAvatar(
                                radius: getResponsiveBoxSize(context, 63, 63),
                                backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                                child: CircleAvatar(
                                  backgroundImage: userService.currentUser.value
                                                  ?.profileImage !=
                                              null &&
                                          userService.currentUser.value!
                                              .profileImage!.isNotEmpty &&
                                          userService
                                              .currentUser.value!.profileImage!
                                              .contains('http')
                                      ? CachedNetworkImageProvider(userService
                                          .currentUser.value!.profileImage!)
                                      : const AssetImage(intPlaceholderImage)
                                          as ImageProvider,
                                  radius: getResponsiveBoxSize(context, 57, 57),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Content Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: EdgeInsets.only(
                      top: getPercentageHeight(2,
                          context), // Add margin to prevent overlap with pinned app bar
                    ),
                    child: Column(
                      children: [
                        // Weight tracking prompt
                        if (_showWeightPrompt)
                          OnboardingPrompt(
                            title: "Track Your Progress",
                            message:
                                "Add your weight information to track your journey and see your progress over time",
                            actionText: "Add Weight",
                            onAction: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NutritionSettingsPage(
                                          isWeightExpand: true),
                                ),
                              );
                            },
                            onDismiss: () {
                              setState(() {
                                _showWeightPrompt = false;
                              });
                            },
                            promptType: 'card',
                            storageKey:
                                OnboardingPromptHelper.PROMPT_WEIGHT_SHOWN,
                          ),

                        SizedBox(
                            height: getPercentageHeight(1,
                                context)), // Reduced since we have margin now

                        // Goals Section
                        if (!shouldShowGoals)
                          Builder(
                            builder: (context) {
                              return ExpansionTile(
                                collapsedIconColor: kAccent,
                                iconColor: kAccent,
                                textColor: kAccent,
                                collapsedTextColor:
                                    isDarkMode ? kWhite : kDarkGrey,
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: MediaQuery.of(context)
                                                      .size
                                                      .height >
                                                  1100
                                              ? getPercentageWidth(2.5, context)
                                              : getPercentageWidth(1, context)),
                                      child: Text(
                                        key: _addWeightButtonKey,
                                        goals,
                                        style: textTheme.displaySmall?.copyWith(
                                          fontSize: getTextScale(5, context),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${userService.currentUser.value?.settings['fitnessGoal']}',
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: kAccent,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Get.to(() =>
                                          const NutritionSettingsPage(
                                              isWeightExpand: true)),
                                      child: Text(
                                        'update',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: kAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(
                                        getPercentageWidth(1, context)),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Column(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .keyboard_double_arrow_right_rounded,
                                                  size: getPercentageWidth(
                                                      3.5, context),
                                                  color: kAccent,
                                                ),
                                                Text(
                                                  startWeight % 1 == 0
                                                      ? startWeight
                                                          .toInt()
                                                          .toString()
                                                      : startWeight
                                                          .toStringAsFixed(1),
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                                width: getPercentageWidth(
                                                    1, context)),
                                            Expanded(
                                              child: LinearPercentIndicator(
                                                animation: true,
                                                lineHeight: getPercentageHeight(
                                                    3, context),
                                                backgroundColor: isDarkMode
                                                    ? kLightGrey
                                                    : kWhite,
                                                animationDuration: 2000,
                                                percent: progressPercentage
                                                    .clamp(0.0, 1.0),
                                                center: Text(
                                                  currentWeight % 1 == 0
                                                      ? currentWeight
                                                              .toInt()
                                                              .toString() +
                                                          'kg'
                                                      : currentWeight
                                                              .toStringAsFixed(
                                                                  1) +
                                                          'kg',
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                barRadius: Radius.circular(
                                                    getPercentageWidth(
                                                        5, context)),
                                                progressColor: kAccent,
                                              ),
                                            ),
                                            SizedBox(
                                                width: getPercentageWidth(
                                                    1, context)),
                                            Column(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .keyboard_double_arrow_left_rounded,
                                                  size: getPercentageWidth(
                                                      3.5, context),
                                                  color: kAccent,
                                                ),
                                                Text(
                                                  goalWeight % 1 == 0
                                                      ? goalWeight
                                                          .toInt()
                                                          .toString()
                                                      : goalWeight
                                                          .toStringAsFixed(1),
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                                height: getPercentageHeight(
                                                    5, context))
                                          ],
                                        ),
                                        SizedBox(
                                            height: getPercentageHeight(
                                                0.5, context)),
                                        if (startWeight == 0 ||
                                            goalWeight == 0) ...[
                                          Text(
                                            'Please update your weight goals.',
                                            style:
                                                textTheme.labelSmall?.copyWith(
                                              color: kAccent,
                                            ),
                                          ),
                                        ] else if (startWeight > 0 &&
                                            goalWeight > 0 &&
                                            startWeight == goalWeight &&
                                            currentWeight == goalWeight) ...[
                                          Text(
                                            'You have reached your goal weight.',
                                            style:
                                                textTheme.labelSmall?.copyWith(
                                              color: kAccent,
                                            ),
                                          ),
                                        ] else if (startWeight > goalWeight &&
                                            currentWeight > goalWeight) ...[
                                          Text(
                                            'You are ${currentWeight - goalWeight} kg away from your goal weight.',
                                            style:
                                                textTheme.labelSmall?.copyWith(
                                              color: kAccent,
                                            ),
                                          ),
                                        ] else ...[
                                          Text(
                                            'You are ${goalWeight - currentWeight} kg away from your goal weight.',
                                            style:
                                                textTheme.labelSmall?.copyWith(
                                              color: kAccent,
                                            ),
                                          ),
                                        ],
                                        SizedBox(
                                            height: getPercentageHeight(
                                                0.5, context)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                        // Daily Summary Section
                        SizedBox(height: getPercentageHeight(1, context)),
                        Container(
                          width: double.infinity,
                          padding:
                              EdgeInsets.all(getPercentageWidth(3, context)),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? kDarkGrey.withValues(alpha: 0.5)
                                : kBackgroundColor,
                            border: Border.all(
                              color: kAccent.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            collapsedIconColor: kAccent,
                            iconColor: kAccent,
                            textColor: kAccent,
                            collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Daily Progress',
                                  style: textTheme.displaySmall?.copyWith(
                                    fontSize: getTextScale(5, context),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    final date = DateTime.now()
                                        .subtract(const Duration(days: 1));
                                    Get.to(
                                        () => DailySummaryScreen(date: date));
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          getPercentageWidth(2, context),
                                      vertical:
                                          getPercentageHeight(0.5, context),
                                    ),
                                    decoration: BoxDecoration(
                                      color: kAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.insights,
                                          color: kAccent,
                                          size: getIconScale(3.5, context),
                                        ),
                                        SizedBox(
                                            width:
                                                getPercentageWidth(1, context)),
                                        Text(
                                          'View History',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: kAccent,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              SizedBox(height: getPercentageHeight(2, context)),
                              // Today's Summary Widget
                              DailySummaryWidget(
                                date: DateTime.now(),
                                showPreviousDay: false,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),

                        // Toggle between Posts and Meals
                        Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(3, context),
                            vertical: getPercentageHeight(1, context),
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? kDarkGrey
                                : kLightGrey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      showMeals = false;
                                      showAll = false;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical:
                                          getPercentageHeight(1.2, context),
                                    ),
                                    decoration: BoxDecoration(
                                      color: !showMeals
                                          ? kAccent
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Posts',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: !showMeals
                                              ? kWhite
                                              : (isDarkMode ? kWhite : kBlack),
                                          fontWeight: !showMeals
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      showMeals = true;
                                      showAll = false;
                                    });
                                    if (userMeals.isEmpty) {
                                      _fetchUserMeals(userId);
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical:
                                          getPercentageHeight(1.2, context),
                                    ),
                                    decoration: BoxDecoration(
                                      color: showMeals
                                          ? kAccent
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Meals',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: showMeals
                                              ? kWhite
                                              : (isDarkMode ? kWhite : kBlack),
                                          fontWeight: showMeals
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Search Content Section (Posts or Meals)
                        Builder(
                          builder: (context) {
                            if (showMeals) {
                              // Show meals
                              final itemCount = showAll
                                  ? userMeals.length
                                  : (userMeals.length > 9
                                      ? 9
                                      : userMeals.length);

                              return Column(
                                children: [
                                  if (isMealsLoading)
                                    Container(
                                      height: getPercentageHeight(20, context),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                              color: kAccent),
                                          SizedBox(
                                              height: getPercentageHeight(
                                                  2, context)),
                                          Text(
                                            'Loading meals...',
                                            style:
                                                textTheme.bodyMedium?.copyWith(
                                              color: isDarkMode
                                                  ? kWhite.withValues(
                                                      alpha: 0.7)
                                                  : kDarkGrey.withValues(
                                                      alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (userMeals.isEmpty)
                                    Padding(
                                      padding: EdgeInsets.all(
                                          getPercentageWidth(4, context)),
                                      child: Text(
                                        "No Meals yet.",
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  else
                                    GridView.builder(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing:
                                            getPercentageWidth(0.5, context),
                                        crossAxisSpacing:
                                            getPercentageWidth(0.5, context),
                                      ),
                                      padding: EdgeInsets.only(
                                          top: getPercentageHeight(1, context),
                                          bottom:
                                              getPercentageHeight(1, context)),
                                      itemCount: itemCount,
                                      itemBuilder: (BuildContext ctx, index) {
                                        final meal = userMeals[index];
                                        return _buildMealCard(meal, context);
                                      },
                                    ),
                                  if (userMeals.isNotEmpty &&
                                      userMeals.length > 9)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          showAll = !showAll;
                                        });
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: getPercentageHeight(
                                                1, context)),
                                        child: Icon(
                                          showAll
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          size: getPercentageWidth(9, context),
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            } else {
                              // Show posts (existing code)
                              final itemCount = showAll
                                  ? searchContentDatas.length
                                  : (searchContentDatas.length > 9
                                      ? 9
                                      : searchContentDatas.length);

                              return Column(
                                children: [
                                  if (isPostsLoading)
                                    Container(
                                      height: getPercentageHeight(20, context),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                              color: kAccent),
                                          SizedBox(
                                              height: getPercentageHeight(
                                                  2, context)),
                                          Text(
                                            'Loading posts...',
                                            style:
                                                textTheme.bodyMedium?.copyWith(
                                              color: isDarkMode
                                                  ? kWhite.withValues(
                                                      alpha: 0.7)
                                                  : kDarkGrey.withValues(
                                                      alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (searchContentDatas.isEmpty)
                                    Padding(
                                      padding: EdgeInsets.all(
                                          getPercentageWidth(4, context)),
                                      child: Text(
                                        "No Posts yet.",
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  else
                                    GridView.builder(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing:
                                            getPercentageWidth(0.5, context),
                                        crossAxisSpacing:
                                            getPercentageWidth(0.5, context),
                                      ),
                                      padding: EdgeInsets.only(
                                          top: getPercentageHeight(1, context),
                                          bottom:
                                              getPercentageHeight(1, context)),
                                      itemCount: itemCount,
                                      itemBuilder: (BuildContext ctx, index) {
                                        final data = searchContentDatas[index];
                                        // Convert Map to Post for SearchContentPost
                                        final post = Post.fromMap(
                                            data, data['id'] ?? '');
                                        return SearchContentPost(
                                          dataSrc: post,
                                          press: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ChallengeDetailScreen(
                                                  dataSrc:
                                                      data, // Use Map directly for ChallengeDetailScreen
                                                  screen: 'myPost',
                                                  allPosts: searchContentDatas,
                                                  initialIndex: index,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  if (searchContentDatas.isNotEmpty &&
                                      searchContentDatas.length > 9)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          showAll = !showAll;
                                        });
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: getPercentageHeight(
                                                1, context)),
                                        child: Icon(
                                          showAll
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          size: getPercentageWidth(9, context),
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }
                          },
                        ),

                        SizedBox(height: getPercentageHeight(18, context)),
                      ],
                    ),
                  ), // Close Container widget
                ),
              ]),
        ),
      ),
    );
  }

  Widget _buildMealCard(Meal meal, BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mediaPath = meal.mediaPaths.isNotEmpty
        ? meal.mediaPaths.first
        : extPlaceholderImage;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(
              mealData: meal,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            height: getPercentageHeight(33, context),
            width: getPercentageWidth(33, context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: mediaPath.isNotEmpty && mediaPath.contains('http')
                  ? OptimizedImage(
                      imageUrl: mediaPath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : Image.asset(
                      getAssetImageForItem(meal.category ?? 'default'),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        extPlaceholderImage,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          // Gradient overlay for better text visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          // Meal title overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.all(getPercentageWidth(1.5, context)),
              child: Text(
                meal.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: kWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: getTextScale(2.8, context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
