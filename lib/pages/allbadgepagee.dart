import 'package:flutter/material.dart';

import '../data_models/profilescreen_data.dart';
import '../widgets/icon_widget.dart';
import '../widgets/helper_widget.dart';

class AllBadgesScreen extends StatelessWidget {
  final String userid;
  final List<BadgeAchievementData> badgeAchievements;

  const AllBadgesScreen(
      {super.key, required this.userid, required this.badgeAchievements});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 15),

              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    // Back Arrow
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const IconCircleButton(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          "Earn more Badges",
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
              if (badgeAchievements.isNotEmpty)
                SizedBox(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    itemCount: badgeAchievements.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemBuilder: (context, index) {
                      return StorySlider(
                        dataSrc: badgeAchievements[index],
                        press: () {
                          // Handle badge click
                        },
                        mHeight: 120,
                        mWidth: 120,
                      );
                    },
                  ),
                )
              else
                const Center(child: Text("No badges achieved yet!")),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
