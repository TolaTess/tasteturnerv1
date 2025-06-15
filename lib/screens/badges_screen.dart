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

                  SizedBox(height: getPercentageHeight(3, context)),

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
                                      fontSize: getTextScale(4, context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: getPercentageWidth(1, context)),
                                Obx(() {
                                  return Text(
                                    '${dailyDataController.streakDays}',
                                    style: TextStyle(
                                      fontSize: getTextScale(10, context),
                                      fontWeight: FontWeight.bold,
                                      color: kAccentLight,
                                    ),
                                  );
                                }),
                              ],
                            ),
                            SizedBox(width: getPercentageWidth(10, context)),
                            Column(
                              children: [
                                Center(
                                  child: Text(
                                    'Points',
                                    style: TextStyle(
                                      fontSize: getTextScale(4, context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Obx(() {
                                  return Text(
                                    '${dailyDataController.pointsAchieved}',
                                    style: TextStyle(
                                      fontSize: getTextScale(10, context),
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
                          padding: EdgeInsets.only(
                              top: getPercentageHeight(1, context)),
                          child: Text(
                            "This is the longest Streak days you've ever had!",
                            style: TextStyle(
                              fontSize: getTextScale(3, context),
                              color: getThemeProvider(context).isDarkMode
                                  ? kWhite
                                  : kDarkGrey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: getPercentageHeight(3, context)),

                  _buildProgressItem(
                      '🏆 Badges', '${myBadge.length}', isDarkMode),

                  SizedBox(height: getPercentageHeight(2, context)),

                  // User's Earned Badges
                  if (myBadge.isNotEmpty)
                    SizedBox(
                      height: getPercentageHeight(20, context),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: myBadge.length,
                        itemBuilder: (context, index) {
                          final badge = myBadge[index];
                          return Container(
                            width: getPercentageWidth(30, context),
                            margin: EdgeInsets.only(
                                right: getPercentageWidth(1, context)),
                            child: Column(
                              children: [
                                // Background Image
                                CircleAvatar(
                                  radius: getResponsiveBoxSize(context, 18, 18),
                                  backgroundImage: const AssetImage(
                                    'assets/images/vegetable_stamp.jpg',
                                  ),
                                ),
                                SizedBox(
                                    height: getPercentageHeight(1, context)),
                                Text(
                                  badge.title,
                                  style: TextStyle(
                                      fontSize: getTextScale(3, context)),
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

                  SizedBox(height: getPercentageHeight(3, context)),

                  // Badge Categories
                  Text(
                    'Badges to Earn',
                    style: TextStyle(
                      fontSize: getTextScale(3.5, context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(3, context)),
                  SizedBox(
                    height: getPercentageHeight(20, context),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: restBadge.length,
                      itemBuilder: (context, index) {
                        final category = restBadge[index];
                        return Container(
                          width: getPercentageWidth(30, context),
                          margin: EdgeInsets.only(
                              right: getPercentageWidth(1, context)),
                          child: Column(
                            children: [
                              // Background Image
                              Opacity(
                                opacity: kMidOpacity,
                                child: CircleAvatar(
                                  radius: getResponsiveBoxSize(context, 18, 18),
                                  backgroundImage: const AssetImage(
                                    'assets/images/vegetable_stamp.jpg',
                                  ),
                                ),
                              ),
                              SizedBox(height: getPercentageHeight(1, context)),
                              Text(
                                category.title,
                                style: TextStyle(
                                    fontSize: getTextScale(3, context)),
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

                  SizedBox(height: getPercentageHeight(2, context)),
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
      padding: EdgeInsets.only(bottom: getPercentageHeight(1, context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: getTextScale(3.5, context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: getPercentageWidth(1, context)),
          Text(
            value,
            style: TextStyle(
              fontSize: getTextScale(3.5, context),
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
