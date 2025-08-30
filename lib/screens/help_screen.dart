import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/widgets/bottom_nav.dart';

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
                'To use image analysis, click on analyse my meal on the home screen and add a photo of your meal. Select if you want to upload meal as a post or upload meal to your daily meal tracker.',
                textTheme),
            const SizedBox(height: 8),
            _buildFAQItem(
                'How do I join a program?',
                'Navigate to the "Programs" tab to see available programs. Tap on any program to view details and join. You can track your progress and earn rewards.',
                textTheme),
            const SizedBox(height: 8),
            _buildFAQItem(
                'What is the Dine In Challenge?',
                'The Dine In Challenge is our weekly challenge that encourages you to explore different restaurants and get creative with your meal. Join the challenge and earn points for a chance to feature on our dine in leaderboard!',
                textTheme),
            SizedBox(height: getPercentageHeight(3, context)),
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
                    // TODO: Implement contact support
                    showTastySnackbar(
                      'Contact Support',
                      'Support feature coming soon!',
                      context,
                    );
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
                    // TODO: Implement privacy policy
                    showTastySnackbar(
                      'Privacy Policy',
                      'Privacy policy coming soon!',
                      context,
                    );
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    // TODO: Implement terms of service
                    showTastySnackbar(
                      'Terms of Service',
                      'Terms of service coming soon!',
                      context,
                    );
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
                    // TODO: Implement about us
                    showTastySnackbar(
                      'About Us',
                      'About us information coming soon!',
                      context,
                    );
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
