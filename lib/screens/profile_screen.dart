import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../widgets/helper_widget.dart';
import 'badges_screen.dart';
import '../pages/settings_screen.dart';
import '../service/battle_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool lastStatus = true;
  bool showAll = false;
  List<Post> searchContentDatas = [];
  List<BadgeAchievementData> myBadge = [];
  late Future<Map<String, dynamic>> chartDataFuture;
  final userId = userService.userId ?? '';
  List<Map<String, dynamic>> ongoingBattles = [];
  bool isLoading = true;
  bool showBattle = false;

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
    badgeController.fetchBadges();
    _fetchContent(userId);
    chartDataFuture = fetchChartData(userId);
    _fetchOngoingBattles(userId);
    dailyDataController.fetchPointsAchieved(userId);
    authController.getCurrentUserData(userId);
    super.initState();
    setState(() {
      showBattle = ongoingBattles.isNotEmpty;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchOngoingBattles(userId);
    dailyDataController.fetchPointsAchieved(userId);
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
    try {
      List<Post> fetchedData;
      fetchedData = await postController.getUserPosts(userId);
      if (mounted) {
        setState(() {
          searchContentDatas = fetchedData;
          showBattle = ongoingBattles.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error fetching content: $e');
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final settings = userService.currentUser!.settings;
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
    final fitnessGoal = userService.currentUser?.settings['fitnessGoal'] ?? '';
    final shouldShowGoals =
        ["Family Nutrition", "AI Guidance"].contains(fitnessGoal);

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
                    userService.currentUser!.displayName ?? '',
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
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()));
                },
                child: const IconCircleButton(
                  isRemoveContainer: true,
                  icon: Icons.settings,
                  w: 8,
                  h: 8,
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
                                image: userService
                                                .currentUser?.profileImage !=
                                            null &&
                                        userService.currentUser!.profileImage!
                                            .isNotEmpty &&
                                        userService.currentUser!.profileImage!
                                            .contains('http')
                                    ? NetworkImage(
                                        userService.currentUser!.profileImage!)
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
                                  child: Container(
                                    padding: EdgeInsets.all(
                                        getPercentageWidth(1, context)),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? kDarkGrey : kWhite,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      userService.currentUser!.displayName ??
                                          '',
                                      style: TextStyle(
                                        fontSize: getTextScale(4.5, context),
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode ? kWhite : kDarkGrey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: getPercentageHeight(2, context)),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  // Points
                                  GestureDetector(
                                    onTap: () => Get.to(() => BadgesScreen()),
                                    child: Container(
                                      width: getPercentageWidth(14, context),
                                      padding: EdgeInsets.all(
                                          getPercentageWidth(1, context)),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? kDarkGrey : kWhite,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            (dailyDataController
                                                        .pointsAchieved ??
                                                    0)
                                                .toString(),
                                            style: TextStyle(
                                              color: isDarkMode
                                                  ? kWhite
                                                  : kDarkGrey,
                                              fontSize:
                                                  getTextScale(4.5, context),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Opacity(
                                            opacity: 0.7,
                                            child: Text(
                                              'Points',
                                              style: TextStyle(
                                                color: isDarkMode
                                                    ? kWhite
                                                    : kDarkGrey,
                                                fontSize:
                                                    getTextScale(3, context),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: getPercentageHeight(3, context),
                                    child: Opacity(
                                      opacity: 0.5,
                                      child: VerticalDivider(
                                        color: isDarkMode ? kDarkGrey : kWhite,
                                        thickness: 1,
                                      ),
                                    ),
                                  ),
                                  // Following
                                  GestureDetector(
                                    onTap: () => Get.to(() => BadgesScreen()),
                                    child: Container(
                                      width: getPercentageWidth(14, context),
                                      padding: EdgeInsets.all(
                                          getPercentageWidth(1, context)),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? kDarkGrey : kWhite,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Obx(() {
                                            myBadge = badgeController
                                                .badgeAchievements
                                                .where((badge) => badge.userids
                                                    .contains(userId))
                                                .toList();

                                            return Text(
                                              myBadge.length.toString(),
                                              style: TextStyle(
                                                color: isDarkMode
                                                    ? kWhite
                                                    : kDarkGrey,
                                                fontSize:
                                                    getTextScale(4.5, context),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            );
                                          }),
                                          Opacity(
                                            opacity: 0.5,
                                            child: Text(
                                              badges,
                                              style: TextStyle(
                                                color: isDarkMode
                                                    ? kWhite
                                                    : kDarkGrey,
                                                fontSize:
                                                    getTextScale(3, context),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: getResponsiveBoxSize(context, 20, 20),
                        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                        child: CircleAvatar(
                          backgroundImage:
                              userService.currentUser?.profileImage != null &&
                                      userService.currentUser!.profileImage!
                                          .isNotEmpty &&
                                      userService.currentUser!.profileImage!
                                          .contains('http')
                                  ? NetworkImage(
                                      userService.currentUser!.profileImage!)
                                  : const AssetImage(intPlaceholderImage)
                                      as ImageProvider,
                          radius: getResponsiveBoxSize(context, 18, 18),
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
            child: Column(
              children: [
                SizedBox(height: getPercentageHeight(2, context)),

                // Badges Section

                Obx(() {
                  myBadge = badgeController.badgeAchievements
                      .where((badge) => badge.userids.contains(userId))
                      .toList();

                  if (myBadge.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding:
                        EdgeInsets.only(left: getPercentageWidth(1, context)),
                    child: ExpansionTile(
                      collapsedIconColor: kAccent,
                      iconColor: kAccent,
                      textColor: kAccent,
                      collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            badges,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: getTextScale(4.5, context),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Get.to(() => BadgesScreen()),
                            child: Text(
                              seeAll,
                              style: TextStyle(
                                color: kAccent,
                                fontSize: getTextScale(3.5, context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        SizedBox(
                          height: getPercentageHeight(25, context),
                          child: ListView.builder(
                            itemCount:
                                (myBadge.length > 3 ? 3 : myBadge.length) + 1,
                            padding: EdgeInsets.only(
                                right: getPercentageWidth(2, context)),
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, index) {
                              if (index < 3 && index < myBadge.length) {
                                // Show badges for the first 2 items
                                return Padding(
                                  padding: EdgeInsets.only(
                                      left: getPercentageWidth(2, context)),
                                  child: StorySlider(
                                    dataSrc: myBadge[index],
                                    press: () {
                                      //todo
                                    },
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (!shouldShowGoals)
                  Divider(color: isDarkMode ? kWhite : kDarkGrey),

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
                                      MediaQuery.of(context).size.height > 1100
                                          ? getPercentageWidth(2.5, context)
                                          : getPercentageWidth(1, context)),
                              child: Text(
                                goals,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: getTextScale(4.5, context),
                                ),
                              ),
                            ),
                            Text(
                              '${userService.currentUser?.settings['fitnessGoal']}',
                              style: TextStyle(
                                fontSize: getTextScale(3.5, context),
                                color: kAccent,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  Get.to(() => const NutritionSettingsPage()),
                              child: Text(
                                'update',
                                style: TextStyle(
                                  color: kAccent,
                                  fontSize: getTextScale(3.5, context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding:
                                EdgeInsets.all(getPercentageWidth(1, context)),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Column(
                                      children: [
                                        Icon(
                                          Icons
                                              .keyboard_double_arrow_right_rounded,
                                          size:
                                              getPercentageWidth(3.5, context),
                                          color: kAccent,
                                        ),
                                        Text(
                                          startWeight % 1 == 0
                                              ? startWeight.toInt().toString()
                                              : startWeight.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: getTextScale(3, context),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                        width: getPercentageWidth(1, context)),
                                    Expanded(
                                      child: LinearPercentIndicator(
                                        animation: true,
                                        lineHeight:
                                            getPercentageHeight(3, context),
                                        backgroundColor:
                                            isDarkMode ? kLightGrey : kWhite,
                                        animationDuration: 2000,
                                        percent:
                                            progressPercentage.clamp(0.0, 1.0),
                                        center: Text(
                                          currentWeight % 1 == 0
                                              ? currentWeight
                                                      .toInt()
                                                      .toString() +
                                                  'kg'
                                              : currentWeight
                                                      .toStringAsFixed(1) +
                                                  'kg',
                                          style: TextStyle(
                                            fontSize:
                                                getTextScale(3.5, context),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        barRadius: Radius.circular(
                                            getPercentageWidth(5, context)),
                                        progressColor: kAccent,
                                      ),
                                    ),
                                    SizedBox(
                                        width: getPercentageWidth(1, context)),
                                    Column(
                                      children: [
                                        Icon(
                                          Icons
                                              .keyboard_double_arrow_left_rounded,
                                          size:
                                              getPercentageWidth(3.5, context),
                                          color: kAccent,
                                        ),
                                        Text(
                                          goalWeight % 1 == 0
                                              ? goalWeight.toInt().toString()
                                              : goalWeight.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: getTextScale(3, context),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                        height: getPercentageHeight(5, context))
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
                    'Battles',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: getTextScale(4.5, context),
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
                          ? Center(
                              child: CircularProgressIndicator(
                              color: kAccent,
                            ))
                          : ongoingBattles.isEmpty
                              ? GestureDetector(
                                  onTap: () => Get.to(() => const BottomNavSec(
                                        selectedIndex: 1,
                                      )),
                                  child: Center(
                                      child: Text(
                                    "No ongoing battles, join a battle now!",
                                    style: TextStyle(
                                      fontSize: getTextScale(3.5, context),
                                      color: isDarkMode ? kLightGrey : kAccent,
                                      decoration: TextDecoration.underline,
                                    ),
                                  )),
                                )
                              : ListView.builder(
                                  itemCount: ongoingBattles.length,
                                  padding: EdgeInsets.symmetric(
                                      vertical: getPercentageHeight(2, context),
                                      horizontal:
                                          getPercentageWidth(1, context)),
                                  scrollDirection: Axis.horizontal,
                                  itemBuilder: (context, index) {
                                    final battle = ongoingBattles[index];

                                    return SizedBox(
                                      width: getPercentageWidth(45, context),
                                      child: Card(
                                        elevation: 2,
                                        color: isDarkMode ? kDarkGrey : kWhite,
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
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? kWhite
                                                      : kBlack,
                                                  fontSize: getTextScale(
                                                      4.5, context),
                                                ),
                                              ),
                                              subtitle: Text(
                                                capitalizeFirstLetter(
                                                    battle['name']),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 3,
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? kLightGrey
                                                      : kDarkGrey,
                                                  fontSize: getTextScale(
                                                      3.5, context),
                                                ),
                                              ),
                                              onTap: () {
                                                Get.to(
                                                  () => UploadBattleImageScreen(
                                                    battleId: battle['id'],
                                                    battleCategory:
                                                        battle['category'],
                                                  ),
                                                );
                                              },
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
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
                                                        await showDialog<bool>(
                                                      context: context,
                                                      builder: (BuildContext
                                                          context) {
                                                        return AlertDialog(
                                                          backgroundColor:
                                                              isDarkMode
                                                                  ? kDarkGrey
                                                                  : kWhite,
                                                          title: Text(
                                                            'Leave Battle?',
                                                            style: TextStyle(
                                                              color: kAccent,
                                                              fontSize:
                                                                  getTextScale(
                                                                      3.5,
                                                                      context),
                                                            ),
                                                          ),
                                                          content: Text(
                                                            'Are you sure you want to leave this battle?',
                                                            style: TextStyle(
                                                              color: isDarkMode
                                                                  ? kWhite
                                                                  : kDarkGrey,
                                                              fontSize:
                                                                  getTextScale(
                                                                      3,
                                                                      context),
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
                                                                style:
                                                                    TextStyle(
                                                                  color:
                                                                      kAccent,
                                                                  fontSize:
                                                                      getTextScale(
                                                                          3.5,
                                                                          context),
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
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .red,
                                                                  fontSize:
                                                                      getTextScale(
                                                                          3.5,
                                                                          context),
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

                SizedBox(height: getPercentageHeight(1, context)),
                Divider(color: isDarkMode ? kWhite : kDarkGrey),

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
                        if (searchContentDatas.isEmpty)
                          Padding(
                            padding:
                                EdgeInsets.all(getPercentageWidth(4, context)),
                            child: Text(
                              "No Posts yet.",
                              style: TextStyle(
                                fontSize: getTextScale(4, context),
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
                              mainAxisSpacing: getPercentageWidth(0.5, context),
                              crossAxisSpacing:
                                  getPercentageWidth(0.5, context),
                            ),
                            padding: EdgeInsets.only(
                                top: getPercentageHeight(1, context),
                                bottom: getPercentageHeight(1, context)),
                            itemCount: itemCount,
                            itemBuilder: (BuildContext ctx, index) {
                              final data = searchContentDatas[index];
                              return SearchContentPost(
                                dataSrc: data,
                                press: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ChallengeDetailScreen(
                                        dataSrc: data.toFirestore(),
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
          ),
        ]),
      ),
    );
  }
}
