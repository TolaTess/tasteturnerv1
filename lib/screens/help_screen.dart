import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/widgets/bottom_nav.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../screens/splash_screen.dart';

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
            Text(
              'Frequently Asked Questions',
              style: textTheme.titleLarge?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFAQItem(
                'How do I use Image Analysis?',
                'To use image analysis, click on analyse my meal on the "Home" screen and add a photo of your meal. Select if you want to upload meal as a post and submit.',
                textTheme),
            const SizedBox(height: 8),
            _buildFAQItem(
                'How do I join a Program?',
                'Navigate to the "Programs" screen to see available programs. Tap on any program to view details and join. You can track your progress and earn points.',
                textTheme),
            const SizedBox(height: 8),
            _buildFAQItem(
                'What is the Dine In?',
                'The "Dine In" screen allows you to cook with what you have in your fridge and be creative and spontaneous.',
                textTheme),
            SizedBox(height: getPercentageHeight(2, context)),
            InkWell(
              onTap: () {
               launchUrl(Uri.parse('https://tasteturner.com/faq'));
              },
              child: Center(
                child: Text('see more FAQs', style: textTheme.titleMedium?.copyWith(
                  color: kAccent,
                  fontWeight: FontWeight.bold,
                ),),
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
                'Version 1.0.0',
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
