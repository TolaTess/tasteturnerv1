import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../data_models/settings.dart';
import '../helper/utils.dart';
import 'edit_goal.dart';
import 'profile_edit_screen.dart';
import '../themes/theme_provider.dart';
import '../widgets/icon_widget.dart';
import '../screens/help_screen.dart';
import '../screens/premium_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: getPercentageHeight(2, context),
            ),

            //home appbar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(2, context),
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
                        style: TextStyle(
                          fontSize: getPercentageWidth(5, context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: getPercentageHeight(1, context),
            ),
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
                  child: Column(
                    children: [
                      SizedBox(
                        height: getPercentageHeight(2, context),
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
                            size: getPercentageWidth(4, context),
                          ),
                          SizedBox(
                            width: getPercentageWidth(1, context),
                          ),

                          //setting category
                          Text(
                            widget.setting.category,
                            style: TextStyle(
                              fontSize: getPercentageWidth(4, context),
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
                            size: getPercentageWidth(4, context),
                          ),
                          SizedBox(
                            width: getPercentageWidth(1, context),
                          ),

                          //setting category
                          Text(
                            widget.setting.category,
                            style: TextStyle(
                              fontSize: getPercentageWidth(4, context),
                            ),
                          ),
                        ],
                      ),

                      //suffix icon
                      Icon(
                        widget.setting.suffixicon,
                        size: getPercentageWidth(4, context),
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
