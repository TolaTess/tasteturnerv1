import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../data_models/settings.dart';
import '../helper/utils.dart';
import '../service/health_service.dart';
import 'edit_goal.dart';
import 'profile_edit_screen.dart';
import '../themes/theme_provider.dart';
import '../widgets/icon_widget.dart';
import '../screens/help_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/premium_screen.dart';
import '../screens/privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 24,
            ),

            //home appbar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Row(
                children: [
                  // back arrow
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: const IconCircleButton(),
                  ),

                  Expanded(
                    child: Center(
                      child: Text(
                        settings,
                        style: const TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 20,
                      ),

                      //setting category list
                      ...List.generate(
                          demoSetting.length,
                          (index) => SettingCategory(
                                setting: demoSetting[index],
                                press: () {
                                  switch (demoSetting[index].category) {
                                    case 'Edit':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const ProfileEditScreen()),
                                      );
                                      break;
                                    case 'Nutrition & Goals':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const NutritionSettingsPage()),
                                      );
                                      break;
                                    case 'Premium':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const PremiumScreen(),
                                        ),
                                      );
                                      break;
                                    case 'Help & Support':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const HelpSupport(),
                                        ),
                                      );
                                      break;
                                    case 'Notifications':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const NotificationsScreen(),
                                        ),
                                      );
                                      break;
                                    case 'Privacy & Security':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const PrivacyScreen(),
                                        ),
                                      );
                                      break;
                                    case 'Dark Mode':
                                      break;
                                    case 'Health Sync':
                                      break;
                                  }
                                },
                              ))
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingCategory extends StatefulWidget {
  const SettingCategory({
    super.key,
    required this.setting,
    required this.press,
  });

  final dynamic setting;
  final GestureTapCallback press;

  @override
  State<SettingCategory> createState() => _SettingCategoryState();
}

class _SettingCategoryState extends State<SettingCategory> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Column(
      children: [
        GestureDetector(
          onTap: widget.press,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 5,
            ),
            child: widget.setting.category == 'Dark Mode' ||
                    widget.setting.category == 'Health Sync'
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          //prefix icon
                          Icon(
                            widget.setting.prefixicon,
                            size: 28,
                          ),
                          const SizedBox(
                            width: 10,
                          ),

                          //setting category
                          Text(
                            widget.setting.category,
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      if (widget.setting.category == 'Dark Mode')
                        CupertinoSwitch(
                          value:
                              Provider.of<ThemeProvider>(context, listen: false)
                                  .isDarkMode,
                          onChanged: (value) =>
                              Provider.of<ThemeProvider>(context, listen: false)
                                  .toggleTheme(),
                        ),
                      if (widget.setting.category == 'Health Sync')
                        CupertinoSwitch(
                          value: userService.currentUser?.syncHealth ?? false,
                          onChanged: (value) async {
                            if (value) {
                              try {
                                final healthService = Get.put(HealthService());
                                final isAvailable =
                                    await healthService.isHealthDataAvailable();

                                if (isAvailable) {
                                  final granted =
                                      await healthService.initializeHealth();
                                  setState(() {
                                    final updatedSettings = {
                                      'settings': {
                                        'syncHealth': granted,
                                      }
                                    };
                                    // Update the user's settings in Firestore
                                    try {
                                      authController
                                          .updateUserData(updatedSettings);
                                    } catch (e) {
                                      showTastySnackbar(
                                        'Error',
                                        'Failed to update settings. Please try again.',
                                        context,
                                      );
                                    }
                                  });

                                  if (!granted) {
                                    showTastySnackbar(
                                      'Permission Required',
                                      'Please allow access to health data to enable syncing.',
                                      context,
                                    );
                                  }
                                } else {
                                  showTastySnackbar(
                                    'Not Available',
                                    'Health tracking is not available on your device.',
                                    context,
                                    backgroundColor: kRed,
                                  );
                                  setState(() {
                                    // Update user settings to reflect health sync is off
                                    final updatedSettings = {
                                      'settings': {
                                        'syncHealth': false,
                                      }
                                    };
                                    authController
                                        .updateUserData(updatedSettings);
                                  });
                                }
                              } catch (e) {
                                print("Error initializing health sync: $e");
                                showTastySnackbar(
                                  'Please try again.',
                                  'Failed to initialize health sync. Please try again.',
                                  context,
                                  backgroundColor: kRed,
                                );
                                setState(() {
                                  // Update user settings to reflect health sync is off
                                  final updatedSettings = {
                                    'settings': {
                                      'syncHealth': false,
                                    }
                                  };
                                  authController
                                      .updateUserData(updatedSettings);
                                });
                              }
                            } else {
                              setState(() {
                                // Update user settings to reflect health sync is off
                                final updatedSettings = {
                                  'settings': {
                                    'syncHealth': false,
                                  }
                                };
                                authController.updateUserData(updatedSettings);
                              });
                            }
                          },
                        ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          //prefix icon
                          Icon(
                            widget.setting.prefixicon,
                            size: 28,
                          ),
                          const SizedBox(
                            width: 10,
                          ),

                          //setting category
                          Text(
                            widget.setting.category,
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),

                      //suffix icon
                      Icon(
                        widget.setting.suffixicon,
                        size: 34,
                      )
                    ],
                  ),
          ),
        ),

        //divider
        Divider(
          color: isDarkMode ? kLightGrey : kDarkGrey,
          thickness: 1,
        ),
      ],
    );
  }
}
