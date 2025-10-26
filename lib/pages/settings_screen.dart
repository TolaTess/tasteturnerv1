import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        title: Text('Settings',
            style:
                textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500)),
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
                          title: "Complete Your Profile",
                          message:
                              "Adding your date of birth and gender helps us provide more accurate nutrition recommendations",
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
                                    case 'Edit Profile':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const ProfileEditScreen()),
                                      );
                                      break;
                                    case 'Edit Goals':
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
                                              const HelpScreen(),
                                        ),
                                      );
                                      break;

                                    case 'Dark Mode':
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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        GestureDetector(
          onTap: widget.press,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 5,
            ),
            child: widget.setting.category == 'Dark Mode'
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
                      if (widget.setting.category == 'Dark Mode')
                        CupertinoSwitch(
                          value:
                              Provider.of<ThemeProvider>(context, listen: false)
                                  .isDarkMode,
                          onChanged: (value) =>
                              Provider.of<ThemeProvider>(context, listen: false)
                                  .toggleTheme(),
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
