import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../themes/theme_provider.dart';

class HelpSupport extends StatelessWidget {
  const HelpSupport({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFAQItem('How do I track my meals?',
                'You can track your meals by going to the "Add Meal" section and selecting the food items you consumed.'),
            _buildFAQItem('How do I set my goals?',
                'You can set your goals in the "Profile" section under "Edit Profile".'),
            _buildFAQItem('How do I change my profile picture?',
                'You can change your profile picture in the "Profile" section under "Edit Profile".'),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: themeProvider.isDarkMode
                      ? kDarkModeAccent.withOpacity(0.50)
                      : kAccent.withOpacity(0.50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                onPressed: () {
                  _launchSupportEmail();
                },
                child: const Text('Contact Support'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  _launchSupportEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@$appName.com',
      queryParameters: {
        'subject': '$appName App Support',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      throw 'Could not launch $emailUri';
    }
  }
}
