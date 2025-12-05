import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/settings.dart';
import '../helper/utils.dart';
import 'edit_goal.dart';
import 'profile_edit_screen.dart';
import '../themes/theme_provider.dart';
import '../screens/help_screen.dart';
import '../screens/premium_screen.dart';
import '../helper/onboarding_prompt_helper.dart';
import '../widgets/onboarding_prompt.dart';
import '../service/auth_controller.dart';
import '../service/notification_service.dart';
import '../service/hybrid_notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showProfilePrompt = false;

  @override
  void initState() {
    super.initState();
    _checkProfilePrompt();
  }

  Future<void> _checkProfilePrompt() async {
    final shouldShow = await OnboardingPromptHelper.shouldShowProfilePrompt();
    if (mounted) {
      setState(() {
        _showProfilePrompt = shouldShow;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: getPercentageHeight(10, context),
        backgroundColor: kAccent,
        automaticallyImplyLeading: true,
        centerTitle: true,
        title: Text('Station Setup',
            style:
                textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500, fontSize: getTextScale(7, context))),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: getPercentageHeight(2, context),
            ),
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(2, context)),
                  child: Column(
                    children: [
                      SizedBox(
                        height: getPercentageHeight(2, context),
                      ),

                      // Profile completion prompt
                      if (_showProfilePrompt)
                        OnboardingPrompt(
                          title: "Complete Your Station",
                          message:
                              "Adding your date of birth and gender helps us provide more accurate service recommendations, Chef",
                          actionText: "Complete Now",
                          onAction: () {
                            setState(() {
                              _showProfilePrompt = false;
                            });
                            // Navigate to profile edit screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileEditScreen(),
                              ),
                            );
                          },
                          onDismiss: () {
                            setState(() {
                              _showProfilePrompt = false;
                            });
                          },
                          promptType: 'banner',
                          storageKey:
                              OnboardingPromptHelper.PROMPT_PROFILE_SHOWN,
                        ),

                      //setting category list
                      ...List.generate(
                          demoSetting.length,
                          (index) => SettingCategory(
                                setting: demoSetting[index],
                                press: () {
                                  switch (demoSetting[index].category) {
                                    case 'Edit Station':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const ProfileEditScreen()),
                                      );
                                      break;
                                    case 'Edit Menu Specs':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const NutritionSettingsPage()),
                                      );
                                      break;
                                    case 'Executive Chef':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const PremiumScreen(),
                                        ),
                                      );
                                      break;
                                    case 'Help Center':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const HelpScreen(),
                                        ),
                                      );
                                      break;

                                    case 'Night Shift':
                                      break;
                                    case 'Reminders':
                                      // Handled by toggle in widget
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
  // Helper function to safely convert settings value to bool
  bool _safeBoolFromSettings(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    if (value is int) {
      return value != 0;
    }
    return defaultValue;
  }

  // Handle notification toggle
  Future<void> _handleNotificationToggle(bool value) async {
    final authController = Get.find<AuthController>();

    try {
      await authController.updateUserData({
        'settings.notificationsEnabled': value,
        'settings.notificationPreferenceSet': true,
      });

      // Note: userService.currentUser will automatically update via Firestore listener
      // No need to manually reload - the reactive widget will update automatically

      if (value) {
        // User enabled notifications - initialize them
        await _initializeNotifications();
        if (mounted) {
          showTastySnackbar(
            'Service Alerts Enabled',
            'You\'ll now receive helpful reminders, Chef!',
            context,
            backgroundColor: kAccent,
          );
        }
      } else {
        // User disabled notifications
        if (mounted) {
          showTastySnackbar(
            'Service Alerts Disabled',
            'You won\'t receive reminders, Chef',
            context,
            backgroundColor: kLightGrey,
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating notification preference: $e');
      if (mounted) {
        showTastySnackbar(
          'Service Error',
          'Failed to update alert settings, Chef',
          context,
          backgroundColor: kRed,
        );
        // Force UI update to revert toggle on error
        setState(() {});
      }
    }
  }

  // Initialize notifications (same logic as home_screen)
  Future<void> _initializeNotifications() async {
    try {
      final notificationService = Get.find<NotificationService>();

      // Initialize local notification service (without requesting permissions)
      await notificationService.initNotification(
        onNotificationTapped: (String? payload) {
          if (payload != null) {
            debugPrint('Notification tapped from settings: $payload');
          }
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Notification initialization timed out');
        },
      );

      // Request iOS permissions explicitly now that user has enabled notifications
      try {
        await notificationService.requestIOSPermissions();
        debugPrint('iOS notification permissions requested from settings');
      } catch (e) {
        debugPrint('Error requesting iOS notification permissions: $e');
      }

      // Initialize hybrid notification service for Android/iOS
      try {
        final hybridNotificationService = Get.find<HybridNotificationService>();
        await hybridNotificationService.initializeHybridNotifications();
        debugPrint('Hybrid notifications initialized from settings');
      } catch (e) {
        debugPrint('Error initializing hybrid notifications: $e');
      }

      debugPrint('Notifications initialized successfully from settings');
    } catch (e) {
      debugPrint('Error initializing notifications from settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final isToggleable = widget.setting.category == 'Dark Mode' ||
        widget.setting.category == 'Notifications';

    return Column(
      children: [
        GestureDetector(
          onTap: isToggleable ? null : widget.press,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 5,
            ),
            child: isToggleable
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          //prefix icon
                          Icon(
                            widget.setting.prefixicon,
                            size: getTextScale(6.5, context),
                          ),
                          SizedBox(
                            width: getPercentageWidth(2.5, context),
                          ),

                          //setting category
                          Text(
                            widget.setting.category,
                            style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: getTextScale(5, context),
                                color: isDarkMode ? kWhite : kDarkGrey),
                          ),
                        ],
                      ),
                      // Dark Mode toggle - always shown when category is Dark Mode
                      if (widget.setting.category == 'Dark Mode')
                        CupertinoSwitch(
                          value:
                              Provider.of<ThemeProvider>(context, listen: false)
                                  .isDarkMode,
                          onChanged: (value) =>
                              Provider.of<ThemeProvider>(context, listen: false)
                                  .toggleTheme(),
                        ),
                      // Notifications toggle - always shown when category is Notifications
                      if (widget.setting.category == 'Notifications')
                        Obx(() {
                          final user = userService.currentUser.value;
                          final isEnabled = user != null
                              ? _safeBoolFromSettings(
                                  user.settings['notificationsEnabled'],
                                  defaultValue: false)
                              : false;
                          return CupertinoSwitch(
                            value: isEnabled,
                            onChanged: _handleNotificationToggle,
                          );
                        }),
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
                            size: getTextScale(6.5, context),
                          ),
                          SizedBox(
                            width: getPercentageWidth(2.5, context),
                          ),

                          //setting category
                          Text(
                            widget.setting.category,
                            style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: getTextScale(5, context),
                                color: isDarkMode ? kWhite : kDarkGrey),
                          ),
                        ],
                      ),

                      //suffix icon
                      Icon(
                        widget.setting.suffixicon,
                        size: getTextScale(6.5, context),
                      )
                    ],
                  ),
          ),
        ),
        SizedBox(height: getPercentageHeight(1, context)),

        //divider
        Divider(
          color: isDarkMode
              ? kLightGrey.withValues(alpha: 0.5)
              : kDarkGrey.withValues(alpha: 0.5),
          thickness: 0.5,
        ),
        SizedBox(height: getPercentageHeight(1, context)),
      ],
    );
  }
}
