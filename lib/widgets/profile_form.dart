import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../helper/utils.dart';
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
    return Form(
      child: Column(
        children: [
          // Edit Name
          SafeTextFormField(
            controller: nameController,
            style: const TextStyle(color: kLightGrey),
            decoration: InputDecoration(
              labelText: "Name",
              labelStyle: TextStyle(
                  color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
              hintText: "Enter your name",
              hintStyle: TextStyle(
                  color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: const CustomSuffixIcon(
                  svgIcon: "assets/images/svg/person.svg"),
              enabledBorder: outlineInputBorder(20),
              focusedBorder: outlineInputBorder(20),
              border: outlineInputBorder(20),
            ),
          ),
          const SizedBox(height: 20),

          // Edit Bio
          SafeTextFormField(
            controller: dobController,
            style: const TextStyle(color: kLightGrey),
            decoration: InputDecoration(
              labelText: "D.O.B (MM-dd)",
              labelStyle: TextStyle(
                  color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
              hintText: "Share you date of birth (MM-dd)?",
              hintStyle: const TextStyle(color: kLightGrey),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: const CustomSuffixIcon(
                  svgIcon: "assets/images/svg/heart.svg"),
              enabledBorder: outlineInputBorder(20),
              focusedBorder: outlineInputBorder(20),
              border: outlineInputBorder(20),
            ),
          ),
          const SizedBox(height: 20),

          // Edit Bio
          SafeTextFormField(
            controller: bioController,
            style: const TextStyle(color: kLightGrey),
            decoration: InputDecoration(
              labelText: "About me",
              labelStyle: TextStyle(
                  color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey),
              hintText: "How do you feel?",
              hintStyle: const TextStyle(color: kLightGrey),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon:
                  const CustomSuffixIcon(svgIcon: "assets/images/svg/book.svg"),
              enabledBorder: outlineInputBorder(20),
              focusedBorder: outlineInputBorder(20),
              border: outlineInputBorder(20),
            ),
          ),
          const SizedBox(height: 20),

          // Save Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: AppButton(
                  text: userService.currentUser?.isPremium == true
                      ? "Premium Access"
                      : "Go Premium",
                  type: AppButtonType.follow,
                  onPressed: () {
                    if (userService.currentUser?.isPremium == true) {
                      // Do nothing if already premium
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PremiumScreen(),
                        ),
                      );
                    }
                  },
                ),
              ),
              Flexible(
                  child: AppButton(
                      text: "Save",
                      onPressed: press,
                      type: AppButtonType.secondary)),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
