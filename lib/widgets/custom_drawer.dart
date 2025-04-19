import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../pages/leaderboard.dart';
import '../screens/buddy_screen.dart';
import '../screens/favorite_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/premium_screen.dart';
import '../bottom_nav/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../themes/theme_provider.dart';
import '../service/notification_service.dart';
import '../widgets/optimized_image.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
        return Drawer(
      backgroundColor: themeProvider.isDarkMode ? kDarkGrey : kWhite,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            //Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1.5,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: kAccent.withOpacity(kOpacity),
                    child: CircleAvatar(
                      radius: 35,
                      child: ClipOval(
                        child: OptimizedImage(
                          imageUrl: userService.currentUser!.profileImage ??
                              intPlaceholderImage,
                          width: 70,
                          height: 70,
                          isProfileImage: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  
                     Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userService.currentUser!.displayName ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
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
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? kPrimaryColor.withOpacity(0.1)
                      : kPrimaryColor.withOpacity(
                          0.3), // Color should be inside BoxDecoration
                  borderRadius: BorderRadius.circular(5), // Border radius
                ),
                child: 
                   DrawerItem(
                    icon: Icons.workspace_premium,
                    title:
                        userService.currentUser!.isPremium ? premiumM : premium,
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
                      return const TastyScreen();
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
              icon: Icons.notifications_outlined,
              title: notifications,
              press: () {
                //close the drawer
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
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
    return InkWell(
      onTap: press,
      child: Padding(
        padding:
            const EdgeInsets.only(left: 32, right: 20, top: 20, bottom: 20),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
            ),
            const SizedBox(
              width: 20,
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                ),
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
