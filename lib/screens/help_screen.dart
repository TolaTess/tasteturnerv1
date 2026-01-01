import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/widgets/bottom_nav.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../screens/splash_screen.dart';
import '../widgets/lingual_popup.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Support',
          style: textTheme.titleLarge?.copyWith(
            color: kAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Speaking the Lingo Section
            InkWell(
              onTap: () {
                LingualPopup.show(context);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kAccent,
                      kPurple.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: kAccent.withValues(alpha: 0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Speaking the Lingo',
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to learn the language of the kitchen',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Text(
              'Frequently Asked Questions',
              style: textTheme.titleLarge?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFAQItem(
                'How do I use Image Analysis, Chef?',
                'To analyze your meal, Chef, tap "Analyse My Meal" on the Kitchen screen and add a photo of your dish. You can choose to share it as a post for other Chefs to see, then submit.',
                textTheme),
            const SizedBox(height: 8),
            _buildFAQItem(
                'What is Cycle Syncing, Chef?',
                'Cycle Syncing adjusts your daily calorie and macro targets based on your menstrual cycle phase (when applicable), Chef. Enable it in your Nutrition Settings to get personalized recommendations that support your body\'s natural rhythms throughout the month.',
                textTheme),
            const SizedBox(height: 8),
            _buildFAQItem(
                'What is the Dine In, Chef?',
                'The Dine In station lets you get creative with what\'s already in your fridge and pantry, Chef. Cook spontaneously with ingredients you have on hand and discover new flavor combinations.',
                textTheme),
            SizedBox(height: getPercentageHeight(2, context)),
            InkWell(
              onTap: () {
                launchUrl(Uri.parse('https://tasteturner.com/faq'));
              },
              child: Center(
                child: Text(
                  'see more FAQs',
                  style: textTheme.titleMedium?.copyWith(
                    color: kAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            SizedBox(height: getPercentageHeight(2, context)),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      // Show confirmation dialog
                      final confirmed =
                          await userDeletionService.showDeletionConfirmation(
                        context,
                        false, // Delete data only
                        isDarkMode,
                      );

                      if (confirmed) {
                        final success =
                            await userDeletionService.deleteUserData(
                          userId: userService.userId!,
                          context: context,
                          deleteAccount: false,
                        );

                        if (success) {
                          // Navigate to splash screen after successful deletion
                          // The auth controller will handle reloading user data
                          Get.offAll(() => const BottomNavSec());
                        } else {
                          showTastySnackbar(
                            'Error',
                            'Failed to delete data. Please try again.',
                            context,
                            backgroundColor: Colors.red,
                          );
                        }
                      }
                    },
                    child: Text('Delete Data Only',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: kAccentLight,
                        )),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      // Show confirmation dialog
                      final confirmed =
                          await userDeletionService.showDeletionConfirmation(
                        context,
                        true, // Delete account
                        isDarkMode,
                      );

                      if (confirmed) {
                        final success =
                            await userDeletionService.deleteUserData(
                          userId: userService.userId!,
                          context: context,
                          deleteAccount: true,
                        );

                        if (success) {
                          // Navigate to splash screen after successful deletion
                          Get.offAll(() => const SplashScreen());
                        } else {
                          showTastySnackbar(
                            'Error',
                            'Failed to delete account. Please try again.',
                            context,
                            backgroundColor: Colors.red,
                          );
                        }
                      }
                    },
                    child: Text('Delete Account',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: kAccentLight,
                        )),
                  ),
                ),
              ],
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Divider(
              color: kAccent,
              thickness: 1,
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    launchUrl(Uri.parse('https://tasteturner.com/contact'));
                  },
                  child: Text(
                    'Contact Support',
                    style: textTheme.bodyMedium?.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    launchUrl(Uri.parse('https://tasteturner.com/privacy'));
                  },
                  child: Text(
                    'Privacy Policy',
                    style: textTheme.bodyMedium?.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    launchUrl(Uri.parse('https://tasteturner.com/terms'));
                  },
                  child: Text(
                    'Terms of Service',
                    style: textTheme.bodyMedium?.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    launchUrl(Uri.parse('https://tasteturner.com/about'));
                  },
                  child: Text(
                    'About Us',
                    style: textTheme.bodyMedium?.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: getPercentageHeight(7, context)),
            Center(
              child: Text(
                'Version 1.0.1',
                style: textTheme.bodySmall?.copyWith(
                  color: kLightGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: textTheme.titleMedium?.copyWith(
              color: kAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: textTheme.bodyMedium?.copyWith(
              color: kLightGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
