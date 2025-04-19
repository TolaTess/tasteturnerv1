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
import '../pages/upload_battle.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../widgets/helper_widget.dart';
import '../screens/badges_screen.dart';
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
    super.initState();
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

      setState(() {
        searchContentDatas = fetchedData;
      });
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
        0.0;
    final double goalWeight = double.tryParse(
            getNumberBeforeSpace(settings['goalWeight'].toString())) ??
        0.0;
    double progressPercentage =
        calculateWeightProgress(startWeight, goalWeight, currentWeight) / 100;
    final fitnessGoal = userService.currentUser?.settings['fitnessGoal'] ?? '';
    final shouldShowGoals = [
      "Improve Health & Track Activities",
      "AI Guidance & Communities"
    ].contains(fitnessGoal);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(controller: _scrollController, slivers: [
          // AppBar
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            expandedHeight: 310,
            title: isShrink
                ? Text(
                    userService.currentUser!.displayName ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
              onTap: () => Get.to(() => const BottomNavSec()),
              child: const IconCircleButton(
                isRemoveContainer: true,
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () => Get.to(() => const SettingsScreen()),
                child: const Padding(
                  padding: EdgeInsets.only(
                    right: 20,
                    left: 12,
                    top: 14,
                    bottom: 14,
                  ),
                  child: IconCircleButton(
                    icon: Icons.settings,
                    isRemoveContainer: true,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                children: [
                  Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          margin: const EdgeInsets.only(top: 74),
                          padding: const EdgeInsets.only(top: 70),
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
                              const SizedBox(height: 20),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? kDarkGrey : kWhite,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    userService.currentUser!.displayName ?? '',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode ? kWhite : kDarkGrey,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  // Points
                                  Container(
                                    width: 70,
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? kDarkGrey : kWhite,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          (dailyDataController.pointsAchieved ??
                                                  0)
                                              .toString(),
                                          style: TextStyle(
                                            color:
                                                isDarkMode ? kWhite : kDarkGrey,
                                            fontSize: 20,
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
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 30,
                                    child: Opacity(
                                      opacity: 0.5,
                                      child: VerticalDivider(
                                        color: isDarkMode ? kDarkGrey : kWhite,
                                        thickness: 1,
                                      ),
                                    ),
                                  ),
                                  // Following
                                  Container(
                                    width: 70,
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? kDarkGrey : kWhite,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          //todo
                                          (userService.currentUser!.followers
                                                      .length ??
                                                  0)
                                              .toString(),
                                          style: TextStyle(
                                            color:
                                                isDarkMode ? kWhite : kDarkGrey,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Opacity(
                                          opacity: 0.5,
                                          child: Text(
                                            followers,
                                            style: TextStyle(
                                              color: isDarkMode
                                                  ? kWhite
                                                  : kDarkGrey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
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
                        radius: 52,
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
                          radius: 50,
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
                const SizedBox(height: 10),

                // Badges Section

                Obx(() {
                  myBadge = badgeController.badgeAchievements
                      .where((badge) => badge.userids.contains(userId))
                      .toList();

                  if (myBadge.isEmpty) return const SizedBox.shrink();
                  return ExpansionTile(
                    collapsedIconColor: kAccent,
                    iconColor: kAccent,
                    textColor: kAccent,
                    collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          badges,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Get.to(() => BadgesScreen()),
                          child: const Text(
                            seeAll,
                            style: TextStyle(
                              color: kAccent,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          itemCount:
                              (myBadge.length > 2 ? 2 : myBadge.length) + 1,
                          padding: const EdgeInsets.only(right: 10),
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) {
                            if (index < 2 && index < myBadge.length) {
                              // Show badges for the first 2 items
                              return Padding(
                                padding: const EdgeInsets.only(left: 10),
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
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Text(
                                goals,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  Get.to(() => const NutritionSettingsPage()),
                              child: const Text(
                                'update',
                                style: TextStyle(
                                  color: kAccent,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      startWeight % 1 == 0
                                          ? startWeight.toInt().toString()
                                          : startWeight.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: LinearPercentIndicator(
                                        animation: true,
                                        lineHeight: 20.0,
                                        backgroundColor:
                                            isDarkMode ? kLightGrey : kWhite,
                                        animationDuration: 2000,
                                        percent:
                                            progressPercentage.clamp(0.0, 1.0),
                                        center: Text(
                                          currentWeight % 1 == 0
                                              ? currentWeight.toInt().toString()
                                              : currentWeight
                                                  .toStringAsFixed(1),
                                        ),
                                        barRadius: const Radius.circular(20.0),
                                        progressColor: kAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      goalWeight % 1 == 0
                                          ? goalWeight.toInt().toString()
                                          : goalWeight.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 20)
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
                  collapsedIconColor: kAccent,
                  iconColor: kAccent,
                  textColor: kAccent,
                  collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                  title: const Text(
                    'Battles',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  initiallyExpanded: true,
                  tilePadding: const EdgeInsets.only(left: 20, right: 20),
                  childrenPadding: EdgeInsets.zero,
                  children: [
                    SizedBox(
                      height: 140,
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                              color: kAccent,
                            ))
                          : ongoingBattles.isEmpty
                              ? Center(
                                  child: Text(
                                  "No ongoing battles found",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode ? kLightGrey : kAccent,
                                  ),
                                ))
                              : ListView.builder(
                                  itemCount: ongoingBattles.length,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 5),
                                  scrollDirection: Axis.horizontal,
                                  itemBuilder: (context, index) {
                                    final battle = ongoingBattles[index];

                                    return SizedBox(
                                      width: 200,
                                      child: Card(
                                        elevation: 2,
                                        color: isDarkMode ? kDarkGrey : kWhite,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
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
                                                  child: const IconCircleButton(
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
                                                          title: const Text(
                                                              'Leave Battle?'),
                                                          content: const Text(
                                                              'Are you sure you want to leave this battle?'),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop(
                                                                          false),
                                                              child: const Text(
                                                                  'Cancel'),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                          context)
                                                                      .pop(
                                                                          true),
                                                              child: const Text(
                                                                'Leave',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .red),
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
                                                  child: const IconCircleButton(
                                                    icon: Icons.delete,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),
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
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "No Posts yet.",
                              style: TextStyle(
                                fontSize: 16,
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
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            itemCount: itemCount,
                            itemBuilder: (BuildContext ctx, index) {
                              final data = searchContentDatas[index];
                              return SearchContentPost(
                                dataSrc: data,
                                press: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChallengeDetailScreen(
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 1.0),
                              child: Icon(
                                showAll
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 36,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 72),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
