import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../data_models/profilescreen_data.dart';
import '../helper/utils.dart';
import '../pages/allbadgepagee.dart';
import '../widgets/follow_button.dart';
import '../widgets/icon_widget.dart';
import '../widgets/helper_widget.dart';
import 'premium_screen.dart';

class BadgesScreen extends StatefulWidget {
  final String userid;
  final bool isPremium;
  final List<BadgeAchievementData> badgeAchievements;

  const BadgesScreen(
      {super.key,
      required this.userid,
      required this.badgeAchievements,
      this.isPremium = false});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  bool showAll = false;
  int badgeCounter = 0;
  List<BadgeAchievementData> myBadge = [];
  List<BadgeAchievementData> restBadge = [];

  @override
  Widget build(BuildContext context) {
    bool isUser = userService.userId == widget.userid;
    return Scaffold(
      body: Obx(() {
        String newUserid =
            widget.userid.isEmpty ? userService.userId ?? '' : widget.userid;

        myBadge = widget.badgeAchievements
            .where((badge) => badge.userids.contains(newUserid))
            .toList();

        restBadge = widget.badgeAchievements
            .where((badge) => !badge.userids.contains(newUserid))
            .toList();

        badgeCounter = 15 - myBadge.length;

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 15),

                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      // Back Arrow
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: const IconCircleButton(
                          isRemoveContainer: true,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            badges,
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Display Achieved Badges
                if (myBadge.isNotEmpty)
                  SizedBox(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      itemCount: myBadge.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemBuilder: (context, index) {
                        return StorySlider(
                            dataSrc: myBadge[index], press: () => {});
                      },
                    ),
                  )
                else
                  noItemTastyWidget(
                    "No badges achieved yet!",
                    "Earn badges to unlock new achievements.",
                    context,
                    false,
                  ),

                const SizedBox(height: 15),

                // Display Rest Badges and Badge Counter
                if (restBadge.isNotEmpty && badgeCounter > 0 && isUser)
                  GestureDetector(
                    onTap: () {
                      // Navigate to a detailed badge screen or show more
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: widget.isPremium
                                      ? "You need $badgeCounter badges to qualify for the $rewardPrice quarterly draw.\n"
                                      : "Join ",
                                ),
                                TextSpan(
                                  text: "Premium", // The clickable part
                                  style: const TextStyle(
                                    color: kAccent,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const PremiumScreen(),
                                          ),
                                        ),
                                ),
                                TextSpan(
                                  text: widget.isPremium
                                      ? ""
                                      : " to have a chance to win $rewardPrice",
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(
                            height: 20,
                        ),
                        FollowButton(
                          title: "More challenges",
                          press: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AllBadgesScreen(
                                  badgeAchievements: restBadge,
                                  userid: newUserid,
                                ),
                              ),
                            );
                          },
                          w: 150,
                          h: 40,
                        )
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
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
