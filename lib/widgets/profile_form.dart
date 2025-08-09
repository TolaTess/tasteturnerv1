import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../pages/edit_goal.dart';
import '../pages/safe_text_field.dart';
import '../screens/premium_screen.dart';
import '../themes/theme_provider.dart';
import 'primary_button.dart';

class EditProfileForm extends StatelessWidget {
  const EditProfileForm({
    super.key,
    required this.nameController,
    required this.bioController,
    required this.dobController,
    required this.press,
  });

  final TextEditingController nameController;
  final TextEditingController bioController;
  final TextEditingController dobController;
  final GestureTapCallback press;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    return Form(
      child: Column(
        children: [
          // Edit Name
          SafeTextFormField(
            controller: nameController,
            style: textTheme.bodyMedium?.copyWith(
                color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
            decoration: InputDecoration(
              labelText: "Name",
              labelStyle: textTheme.bodyMedium?.copyWith(
                  color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
              hintText: "Enter your name",
              hintStyle: textTheme.bodyMedium?.copyWith(
                  color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: const CustomSuffixIcon(
                  svgIcon: "assets/images/svg/person.svg"),
              enabledBorder: outlineInputBorder(20),
              focusedBorder: outlineInputBorder(20),
              border: outlineInputBorder(20),
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),

          // Edit Bio
          SafeTextFormField(
            controller: dobController,
            style: textTheme.bodyMedium?.copyWith(
                color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
            decoration: InputDecoration(
              labelText: "D.O.B (MM-dd)",
              labelStyle: textTheme.bodyMedium?.copyWith(
                  color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
              hintText: "Share you date of birth (MM-dd)?",
              hintStyle: textTheme.bodyMedium?.copyWith(
                  color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: const CustomSuffixIcon(
                  svgIcon: "assets/images/svg/heart.svg"),
              enabledBorder: outlineInputBorder(20),
              focusedBorder: outlineInputBorder(20),
              border: outlineInputBorder(20),
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),

          // Edit Bio
          SafeTextFormField(
            controller: bioController,
            style: textTheme.bodyMedium?.copyWith(
                color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
            decoration: InputDecoration(
              labelText: "About me",
              labelStyle: textTheme.bodyMedium?.copyWith(
                  color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
              hintText: "How do you feel?",
              hintStyle: textTheme.bodyMedium?.copyWith(
                  color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon:
                  const CustomSuffixIcon(svgIcon: "assets/images/svg/book.svg"),
              enabledBorder: outlineInputBorder(20),
              focusedBorder: outlineInputBorder(20),
              border: outlineInputBorder(20),
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),

          // Family member management moved to Edit Goals page
          if (userService.currentUser.value?.familyMode == true)
            Container(
              padding: EdgeInsets.all(getPercentageWidth(3, context)),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? kDarkGrey.withValues(alpha: 0.3)
                    : kLightGrey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kAccent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.family_restroom,
                      color: kAccent, size: getIconScale(6, context)),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Family Mode Active',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color:
                                themeProvider.isDarkMode ? kWhite : kDarkGrey,
                          ),
                        ),
                        Text(
                          'Manage family members in Edit Goals',
                          style: textTheme.bodySmall?.copyWith(
                            color: themeProvider.isDarkMode
                                ? kLightGrey
                                : kDarkGrey.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const NutritionSettingsPage(isFamilyModeExpand: true)),
                      );
                    },
                    icon: Icon(Icons.settings,
                        size: getIconScale(7, context), color: kAccent),
                  ),
                ],
              ),
            ),
          SizedBox(height: getPercentageHeight(5, context)),

          // Save Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              userService.currentUser.value?.isPremium == true
                  ? const SizedBox.shrink()
                  : Expanded(
                      child: AppButton(
                        text: "Go Premium",
                        type: AppButtonType.follow,
                        width: 40,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PremiumScreen(),
                            ),
                          );
                        },
                      ),
                    ),
              Flexible(
                  child: AppButton(
                      text: "Save",
                      onPressed: press,
                      width: userService.currentUser.value?.isPremium == true
                          ? 100
                          : 40,
                      type: AppButtonType.secondary)),
            ],
          ),
          SizedBox(height: getPercentageHeight(2, context)),
        ],
      ),
    );
  }
}
