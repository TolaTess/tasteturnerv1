
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../themes/theme_provider.dart';
import 'email_button.dart';
import 'primary_button.dart';

class EditProfileForm extends StatelessWidget {
  const EditProfileForm({
    super.key,
    required this.nameController,
    required this.bioController,
    required this.press,
  });

  final TextEditingController nameController;
  final TextEditingController bioController;
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
              suffixIcon:
                  const CustomSuffixIcon(svgIcon: "assets/images/svg/person.svg"),
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
              suffixIcon: const CustomSuffixIcon(
                  svgIcon: "assets/images/svg/heart.svg"),
              enabledBorder: outlineInputBorder(20),
              focusedBorder: outlineInputBorder(20),
              border: outlineInputBorder(20),
            ),
          ),
          const SizedBox(height: 20),

          // Save Button
          PrimaryButton(text: "Save", press: press),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
