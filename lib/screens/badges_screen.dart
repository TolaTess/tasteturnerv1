import 'package:fit_hify/helper/utils.dart';
import 'package:fit_hify/widgets/icon_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../data_models/profilescreen_data.dart';

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
                'No badges earned yet', '', context, false);
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
                  Center(
                    child: Column(
                      children: [
                        const Center(
                          child: Text(
                            'Streak',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
                        if (dailyDataController.streakDays > 0)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              "This is the longest Streak days you've ever had!",
                              style: TextStyle(
                                fontSize: 11,
                                color: kAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

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
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                      child:
                                          // badge.image.isEmpty
                                          //     ?
                                          Image.asset(
                                    'assets/images/tasty.png',
                                    width: 40,
                                    height: 40,
                                  )
                                      // :
                                      // Image.asset(
                                      //     badge.image,
                                      //     width: 40,
                                      //     height: 40,
                                      //   ),
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  badge.title,
                                  style: const TextStyle(fontSize: 12),
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
                    'Other Badges',
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
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                    child:
                                        // category.image.isEmpty
                                        //     ?
                                        Image.asset(
                                  'assets/images/tasty.png',
                                  width: 40,
                                  height: 40,
                                )
                                    // : Image.asset(
                                    //     category.image,
                                    //     width: 40,
                                    //     height: 40,
                                    //   ),
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                category.title,
                                style: const TextStyle(fontSize: 12),
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

                  // Overall Progress
                  const Text(
                    'Your Overall Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildProgressItem(
                      'Completed Badges', '${myBadge.length}', isDarkMode),

                  const SizedBox(height: 16),
                  Obx(() {
                    return _buildScoredPoints(
                        dailyDataController.pointsAchieved.toString(),
                        isDarkMode);
                  }),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoredPoints(String points, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Scored Points',
          style: TextStyle(
            fontSize: 14,
          ),
        ),
        Row(
          children: [
            Text(
              points,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.monetization_on,
              size: 16,
              color: Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  // When a new badge is earned
  void onBadgeEarned(BadgeAchievementData badge) {
    notificationService.showNotification(
      id: 3001,
      title: "New Badge Earned! 🏆",
      body: "Congratulations! You've earned the ${badge.title} badge!",
    );
  }
}
