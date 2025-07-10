import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui'; // Add this import for ImageFilter
import 'package:get/get.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../constants.dart';
import '../data_models/post_model.dart';
import '../data_models/profilescreen_data.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../helper/utils.dart';
import '../pages/edit_goal.dart';
import '../pages/profile_edit_screen.dart';
import '../pages/upload_battle.dart';
import '../service/tasty_popup_service.dart';
import '../tabs_screen/food_challenge_screen.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../widgets/helper_widget.dart';
import 'badges_screen.dart';
import '../pages/settings_screen.dart';
import '../service/battle_service.dart';
import '../service/post_service.dart';
import '../service/badge_service.dart';
import '../data_models/badge_system_model.dart' as BadgeModel;

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
  List<Map<String, dynamic>> ongoingBattles = [];
  bool isLoading = true;
  bool isPostsLoading = true;
  bool showBattle = false;
  final GlobalKey _addSettingsButtonKey = GlobalKey();
  final GlobalKey _addBattleButtonKey = GlobalKey();
  final GlobalKey _addBadgesButtonKey = GlobalKey();
  final GlobalKey _addWeightButtonKey = GlobalKey();
  late ScrollController _scrollController;

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
    _fetchOngoingBattles(userId);
    // Points are now loaded as part of BadgeService.loadUserProgress
    authController.listenToUserData(userId);
    super.initState();
    setState(() {
      showBattle = ongoingBattles.isNotEmpty;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddMealTutorial();
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
          tutorialId: 'add_battle_button',
          message: 'Tap here to view your Dine-In Challenges!',
          targetKey: _addBattleButtonKey,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchOngoingBattles(userId);
    // Points are now handled by BadgeService
  }

  Future<Map<String, dynamic>> fetchChartData(String userid) async {
    final caloriesByDate =
        await dailyDataController.fetchCaloriesByDate(userid);
    List<String> dateLabels = [];
    List<FlSpot> chartData = prepareChartData(caloriesByDate, dateLabels);

    return {
      'chartData': chartData,
      'dateLabels': dateLabels,
    };
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
          showBattle = ongoingBattles.isNotEmpty;
        });
      } else if (mounted) {
        setState(() {
          searchContentDatas = [];
          isPostsLoading = false;
          showBattle = ongoingBattles.isNotEmpty;
        });
        if (result.error != null) {
          print('Error fetching user posts: ${result.error}');
        }
      }
    } catch (e) {
      print('Error fetching content: $e');
      if (mounted) {
        setState(() {
          searchContentDatas = [];
          isPostsLoading = false;
          showBattle = ongoingBattles.isNotEmpty;
        });
      }
    }
  }

  /// **Fetch list of battles user has signed up for**
  Future<void> _fetchOngoingBattles(String userId) async {
    try {
      final battleDetails =
          await BattleService.instance.getUserOngoingBattles(userId);
      // Transform battle data to match the expected format
      final formattedBattles = battleDetails
          .map((battle) => {
                'id': battle['id'],
                'name':
                    'Ingredient Battle - ${capitalizeFirstLetter(battle['category'])}',
                'category': battle['category'] ?? 'Unknown Category',
              })
          .toList();

      setState(() {
        ongoingBattles = formattedBattles;
        showBattle = ongoingBattles.isNotEmpty;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching ongoing battles: $e");
      setState(() => isLoading = false);
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

  // Helper function to convert Badge to BadgeAchievementData for compatibility
  BadgeAchievementData _convertBadgeToLegacyFormat(BadgeModel.Badge badge) {
    return BadgeAchievementData(
      title: badge.title,
      description: badge.description,
      userids: [userId], // Current user
      image: tastyImage, // Use default image
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
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
      body: SafeArea(
        child: CustomScrollView(controller: _scrollController, slivers: [
          // AppBar
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            expandedHeight: MediaQuery.of(context).size.height > 1100
                ? getPercentageHeight(45, context)
                : getPercentageHeight(43, context),
            title: isShrink
                ? Text(
                    userService.currentUser.value!.displayName ?? '',
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
                      ? kWhite.withOpacity(0.80)
                      : kBlack
                  : isDarkMode
                      ? kLightGrey
                      : kPrimaryColor,
            ),
            leading: InkWell(
              onTap: () => Navigator.canPop(context)
                  ? Navigator.pop(context)
                  : Get.to(() => const BottomNavSec()),
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
                                        userService
                                            .currentUser.value!.profileImage!
                                            .contains('http')
                                    ? NetworkImage(userService
                                        .currentUser.value!.profileImage!)
                                    : const AssetImage(intPlaceholderImage)
                                        as ImageProvider,
                                fit: BoxFit.cover),
                          ),
                          child: Column(
                            children: [
                              SizedBox(height: getPercentageHeight(2, context)),
                              Center(
                                child: GestureDetector(
                                  onTap: () =>
                                      Get.to(() => const ProfileEditScreen()),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
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
                                              ? kDarkGrey.withOpacity(0.5)
                                              : kWhite.withOpacity(0.5)),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          userService.currentUser.value!
                                                  .displayName ??
                                              '',
                                          style:
                                              textTheme.displaySmall?.copyWith(
                                            fontSize: getTextScale(5, context),
                                            fontWeight: FontWeight.w600,
                                            color: isDarkMode ? kWhite : kBlack,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: getPercentageHeight(2, context)),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 5.0, sigmaY: 5.0),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      vertical: getPercentageHeight(1, context),
                                      horizontal:
                                          getPercentageWidth(3, context),
                                    ),
                                    decoration: BoxDecoration(
                                      color: (isDarkMode
                                          ? kDarkGrey.withOpacity(0.5)
                                          : kWhite.withOpacity(0.5)),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        // Points
                                        GestureDetector(
                                          onTap: () =>
                                              Get.to(() => BadgesScreen()),
                                          child: Column(
                                            children: [
                                              Text(
                                                badgeService.totalPoints.toString(),
                                                style: textTheme.bodyLarge
                                                    ?.copyWith(
                                                  color: isDarkMode
                                                      ? kWhite
                                                      : kBlack,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Opacity(
                                                opacity: 0.7,
                                                child: Text(
                                                  'Points',
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: isDarkMode
                                                        ? kWhite
                                                        : kBlack,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          height:
                                              getPercentageHeight(3, context),
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
                                          onTap: () =>
                                              Get.to(() => BadgesScreen()),
                                          child: Column(
                                            children: [
                                              Obx(() {
                                                final earnedBadges =
                                                    BadgeService
                                                        .instance.earnedBadges;
                                                return Text(
                                                  earnedBadges.length
                                                      .toString(),
                                                  style: textTheme.bodyLarge
                                                      ?.copyWith(
                                                    color: isDarkMode
                                                        ? kWhite
                                                        : kBlack,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                );
                                              }),
                                              Opacity(
                                                opacity: 0.5,
                                                child: Text(
                                                  badges,
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: isDarkMode
                                                        ? kWhite
                                                        : kBlack,
                                                    fontWeight: FontWeight.w500,
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
                      CircleAvatar(
                        radius: getResponsiveBoxSize(context, 63, 63),
                        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                        child: CircleAvatar(
                          backgroundImage: userService
                                          .currentUser.value?.profileImage !=
                                      null &&
                                  userService.currentUser.value!.profileImage!
                                      .isNotEmpty &&
                                  userService.currentUser.value!.profileImage!
                                      .contains('http')
                              ? NetworkImage(
                                  userService.currentUser.value!.profileImage!)
                              : const AssetImage(intPlaceholderImage)
                                  as ImageProvider,
                          radius: getResponsiveBoxSize(context, 57, 57),
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
                  SizedBox(
                      height: getPercentageHeight(
                          1, context)), // Reduced since we have margin now

                  // Goals Section
                  if (!shouldShowGoals)
                    Builder(
                      builder: (context) {
                        return ExpansionTile(
                          collapsedIconColor: kAccent,
                          iconColor: kAccent,
                          textColor: kAccent,
                          collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal:
                                        MediaQuery.of(context).size.height >
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
                                onTap: () =>
                                    Get.to(() => const NutritionSettingsPage()),
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
                                                ? startWeight.toInt().toString()
                                                : startWeight
                                                    .toStringAsFixed(1),
                                            style:
                                                textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(1, context)),
                                      Expanded(
                                        child: LinearPercentIndicator(
                                          animation: true,
                                          lineHeight:
                                              getPercentageHeight(3, context),
                                          backgroundColor:
                                              isDarkMode ? kLightGrey : kWhite,
                                          animationDuration: 2000,
                                          percent: progressPercentage.clamp(
                                              0.0, 1.0),
                                          center: Text(
                                            currentWeight % 1 == 0
                                                ? currentWeight
                                                        .toInt()
                                                        .toString() +
                                                    'kg'
                                                : currentWeight
                                                        .toStringAsFixed(1) +
                                                    'kg',
                                            style:
                                                textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          barRadius: Radius.circular(
                                              getPercentageWidth(5, context)),
                                          progressColor: kAccent,
                                        ),
                                      ),
                                      SizedBox(
                                          width:
                                              getPercentageWidth(1, context)),
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
                                                ? goalWeight.toInt().toString()
                                                : goalWeight.toStringAsFixed(1),
                                            style:
                                                textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                          height:
                                              getPercentageHeight(5, context))
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                  Divider(color: isDarkMode ? kWhite : kDarkGrey),

                  // Battles Section

                  ExpansionTile(
                    key: ValueKey(showBattle),
                    collapsedIconColor: kAccent,
                    iconColor: kAccent,
                    textColor: kAccent,
                    collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                    initiallyExpanded: showBattle,
                    title: Text(
                      key: _addBattleButtonKey,
                      'Dine-In Challenges',
                      style: textTheme.displaySmall?.copyWith(
                        fontSize: getTextScale(5, context),
                      ),
                    ),
                    tilePadding: EdgeInsets.only(
                        left: getPercentageWidth(5, context),
                        right: getPercentageWidth(5, context)),
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      SizedBox(
                        height: getPercentageHeight(25, context),
                        child: isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                color: kAccent,
                              ))
                            : ongoingBattles.isEmpty
                                ? GestureDetector(
                                    onTap: () => Get.to(
                                        () => const FoodChallengeScreen()),
                                    child: Center(
                                        child: Text(
                                      "No ongoing battles, \nTap to join a battle now!",
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color:
                                            isDarkMode ? kLightGrey : kAccent,
                                      ),
                                    )),
                                  )
                                : ListView.builder(
                                    itemCount: ongoingBattles.length,
                                    padding: EdgeInsets.symmetric(
                                        vertical:
                                            getPercentageHeight(2, context),
                                        horizontal:
                                            getPercentageWidth(1, context)),
                                    scrollDirection: Axis.horizontal,
                                    itemBuilder: (context, index) {
                                      final battle = ongoingBattles[index];

                                      return SizedBox(
                                        width: getPercentageWidth(45, context),
                                        child: Card(
                                          elevation: 2,
                                          color:
                                              isDarkMode ? kDarkGrey : kWhite,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                getPercentageWidth(2, context)),
                                          ),
                                          child: Column(
                                            children: [
                                              ListTile(
                                                title: Text(
                                                  capitalizeFirstLetter(
                                                      battle['category']),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: isDarkMode
                                                        ? kWhite
                                                        : kBlack,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  capitalizeFirstLetter(
                                                      battle['name']),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 3,
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: isDarkMode
                                                        ? kLightGrey
                                                        : kDarkGrey,
                                                  ),
                                                ),
                                                onTap: () {
                                                  Get.to(
                                                    () =>
                                                        UploadBattleImageScreen(
                                                      battleId: battle['id'],
                                                      battleCategory:
                                                          battle['category'],
                                                    ),
                                                  );
                                                },
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              UploadBattleImageScreen(
                                                            battleId:
                                                                battle['id'],
                                                            battleCategory:
                                                                battle[
                                                                    'category'],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: IconCircleButton(
                                                      icon: Icons.camera,
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () async {
                                                      // Show confirmation dialog
                                                      bool? confirm =
                                                          await showDialog<
                                                              bool>(
                                                        context: context,
                                                        builder: (BuildContext
                                                            context) {
                                                          return AlertDialog(
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          15),
                                                            ),
                                                            backgroundColor:
                                                                isDarkMode
                                                                    ? kDarkGrey
                                                                    : kWhite,
                                                            title: Text(
                                                              'Leave Battle?',
                                                              style: textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                color: kAccent,
                                                              ),
                                                            ),
                                                            content: Text(
                                                              'Are you sure you want to leave this battle?',
                                                              style: textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                color: isDarkMode
                                                                    ? kWhite
                                                                    : kDarkGrey,
                                                              ),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(
                                                                            false),
                                                                child: Text(
                                                                  'Cancel',
                                                                  style: textTheme
                                                                      .bodyMedium
                                                                      ?.copyWith(
                                                                    color:
                                                                        kAccent,
                                                                  ),
                                                                ),
                                                              ),
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(
                                                                            true),
                                                                child: Text(
                                                                  'Leave',
                                                                  style: textTheme
                                                                      .bodyMedium
                                                                      ?.copyWith(
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );

                                                      if (confirm == true) {
                                                        await macroManager
                                                            .removeUserFromBattle(
                                                          userId,
                                                          battle['id'],
                                                        );
                                                        // Refresh the battles list
                                                        _fetchOngoingBattles(
                                                            userId);
                                                      }
                                                    },
                                                    child: IconCircleButton(
                                                      icon: Icons.delete,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                  height: getPercentageHeight(
                                                      2, context)),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),

                  // Search Content Section
                  Builder(
                    builder: (context) {
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(color: kAccent),
                                  SizedBox(
                                      height: getPercentageHeight(2, context)),
                                  Text(
                                    'Loading posts...',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: isDarkMode
                                          ? kWhite.withValues(alpha: 0.7)
                                          : kDarkGrey.withValues(alpha: 0.7),
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
                              physics: const NeverScrollableScrollPhysics(),
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
                                  bottom: getPercentageHeight(1, context)),
                              itemCount: itemCount,
                              itemBuilder: (BuildContext ctx, index) {
                                final data = searchContentDatas[index];
                                // Convert Map to Post for SearchContentPost
                                final post =
                                    Post.fromMap(data, data['id'] ?? '');
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
                                    vertical: getPercentageHeight(1, context)),
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
                    },
                  ),

                  SizedBox(height: getPercentageHeight(18, context)),
                ],
              ),
            ), // Close Container widget
          ),
        ]),
      ),
    );
  }
}
