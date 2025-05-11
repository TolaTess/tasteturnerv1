
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../data_models/profilescreen_data.dart';
import '../helper/utils.dart';
import '../service/battle_management.dart';
import '../widgets/icon_widget.dart';

class BadgesScreen extends StatefulWidget {
  BadgesScreen({Key? key}) : super(key: key) {}

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  List<BadgeAchievementData> myBadge = [];
  List<BadgeAchievementData> restBadge = [];
  int badgeCounter = 0;
  @override
  void initState() {
    super.initState();
    _badgeController.fetchBadges();
    dailyDataController.fetchStreakDays(userService.userId ?? '');
    dailyDataController.fetchPointsAchieved(userService.userId ?? '');
  }

  final BadgeController _badgeController = BadgeController.instance;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          if (_badgeController.badgeAchievements.isEmpty) {
            return noItemTastyWidget(
                'No badges earned yet', '', context, false, '');
          }

          myBadge = _badgeController.badgeAchievements
              .where(
                  (badge) => badge.userids.contains(userService.userId ?? ''))
              .toList();

          restBadge = _badgeController.badgeAchievements
              .where(
                  (badge) => !badge.userids.contains(userService.userId ?? ''))
              .toList();

          badgeCounter = 15 - myBadge.length;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with share button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          Get.back();
                        },
                        child: const IconCircleButton(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Streak Days Counter
                  Column(
                    children: [
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                Center(
                                  child: Text(
                                    'Streak',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Obx(() {
                                  return Text(
                                    '${dailyDataController.streakDays}',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: kAccentLight,
                                    ),
                                  );
                                }),
                              ],
                            ),
                            SizedBox(width: 40),
                            Column(
                              children: [
                                Center(
                                  child: Text(
                                    'Points',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Obx(() {
                                  return Text(
                                    '${dailyDataController.pointsAchieved}',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: kAccentLight,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (dailyDataController.streakDays > 0)
                        Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            "This is the longest Streak days you've ever had!",
                            style: TextStyle(
                              fontSize: 11,
                              color: getThemeProvider(context).isDarkMode
                                  ? kWhite
                                  : kDarkGrey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  _buildProgressItem(
                      '🏆 Badges', '${myBadge.length}', isDarkMode),

                  // User's Earned Badges
                  if (myBadge.isNotEmpty)
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: myBadge.length,
                        itemBuilder: (context, index) {
                          final badge = myBadge[index];
                          return Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                // Background Image
                                const CircleAvatar(
                                  radius: 60 / 2,
                                  backgroundImage: const AssetImage(
                                    'assets/images/vegetable_stamp.jpg',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  badge.title,
                                  style: const TextStyle(fontSize: 11),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Badge Categories
                  const Text(
                    'Badges to Collect',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: restBadge.length,
                      itemBuilder: (context, index) {
                        final category = restBadge[index];
                        return Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              // Background Image
                              const Opacity(
                                opacity: kMidOpacity,
                                child: CircleAvatar(
                                  radius: 60 / 2,
                                  backgroundImage: const AssetImage(
                                    'assets/images/vegetable_stamp.jpg',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                category.title,
                                style: const TextStyle(fontSize: 11),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: Column(
                        children: [
                          const Text(
                            'Collect ${pointsToWin} points to get a chance to win a \$50 food voucher!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: kAccent,
                            ),
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                          Text(
                            'As part of our quarterly $appName challenge!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: getThemeProvider(context).isDarkMode
                                  ? kWhite
                                  : kBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProgressItem(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kAccentLight,
            ),
          ),
        ],
      ),
    );
  }

  // When a new badge is earned
  void onBadgeEarned(BadgeAchievementData badge) {
    notificationService.showNotification(
      id: 3001,
      title: "New Badge Earned! 🏆",
      body:
          "Congratulations! You've earned the ${badge.title} badge! 10 points awarded!",
    );
    BattleManagement.instance.updateUserPoints(userService.userId ?? '', 10);
  }
}
