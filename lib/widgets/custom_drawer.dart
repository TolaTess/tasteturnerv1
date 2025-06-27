import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/leaderboard.dart';
import '../pages/settings_screen.dart';
import '../screens/buddy_screen.dart';
import '../screens/favorite_screen.dart';
import '../screens/premium_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../themes/theme_provider.dart';
import '../service/notification_service.dart';
import 'bottom_nav.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    return Drawer(
      width: getPercentageWidth(70, context),
      backgroundColor: themeProvider.isDarkMode ? kDarkGrey : kWhite,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: getPercentageHeight(3, context),
            ),
            //Custom Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(4, context),
                vertical: getPercentageHeight(1, context),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const BottomNavSec()),
                      );
                    },
                    child: buildProfileAvatar(
                        imageUrl: userService.currentUser.value!.profileImage ??
                            intPlaceholderImage,
                        context: context),
                  ),
                  SizedBox(
                    width: getPercentageWidth(3, context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userService.currentUser.value!.displayName ?? '',
                        style: textTheme.displaySmall?.copyWith(
                          fontSize: getPercentageWidth(7, context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            //Profile
            DrawerItem(
              icon: Icons.person,
              title: profile,
              press: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),

            //Premium
            Padding(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              child: Container(
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? kPrimaryColor.withOpacity(0.1)
                      : kPrimaryColor.withOpacity(
                          0.3), // Color should be inside BoxDecoration
                  borderRadius: BorderRadius.circular(5), // Border radius
                ),
                child: DrawerItem(
                  icon: Icons.workspace_premium,
                  title: userService.currentUser.value!.isPremium
                      ? premiumM
                      : premium,
                  press: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return const PremiumScreen();
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            //Goal Buddy - Chat

            DrawerItem(
              icon: Icons.chat_rounded,
              title: goalBuddy,
              press: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return const TastyScreen(screen: 'message');
                    },
                  ),
                );
              },
            ),

            DrawerItem(
              icon: Icons.leaderboard_outlined,
              title: leaderBoard,
              press: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return const LeaderboardScreen();
                    },
                  ),
                );
              },
            ),
            //Favorite
            DrawerItem(
              icon: Icons.category_outlined,
              title: favorite,
              press: () {
                //close the drawer
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FavoriteScreen(),
                  ),
                );
              },
            ),

            //Notifications
            DrawerItem(
              icon: Icons.settings_outlined,
              title: settings,
              press: () {
                //close the drawer
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),

            //Theme Change
            DrawerItem(
              icon: Provider.of<ThemeProvider>(context).isDarkMode
                  ? Icons.dark_mode
                  : Icons.light_mode, // Update icon dynamically
              title: Provider.of<ThemeProvider>(context).isDarkMode
                  ? 'Light Mode'
                  : 'Dark Mode', // Update title dynamically
              press: () {
                // Close the drawer
                Navigator.pop(context);

                // Toggle the theme
                Provider.of<ThemeProvider>(context, listen: false)
                    .toggleTheme();
              },
            ),

            //Logout
            DrawerItem(
              icon: Icons.account_circle_outlined,
              title: logout,
              press: () {
                //close the drawer
                authController.signOut();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SplashScreen(),
                  ),
                );
              },
            ),
            SizedBox(
              height: getPercentageHeight(7, context),
            )
          ],
        ),
      ),
    );
  }
}

//Drawer item widget
class DrawerItem extends StatelessWidget {
  const DrawerItem({
    super.key,
    required this.icon,
    required this.title,
    required this.press,
  });

  final IconData icon;
  final String title;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: press,
      child: Padding(
        padding: EdgeInsets.only(
            left: getPercentageWidth(8, context),
            right: getPercentageWidth(4, context),
            top: getPercentageHeight(2, context),
            bottom: getPercentageHeight(2, context)),
        child: Row(
          children: [
            Icon(
              icon,
              size: getPercentageWidth(6, context),
            ),
            SizedBox(
              width: getPercentageWidth(4, context),
            ),
            Expanded(
              child: Text(
                title,
                style: textTheme.bodyLarge?.copyWith(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// For challenge notifications
void notifyChallengeUpdates() {
  NotificationService().scheduleDailyReminder(
    id: 4001,
    title: "Challenge Update ⭐",
    body: "Check your progress in ongoing challenges!",
    hour: 20, // 8 PM
    minute: 0,
  );
}
