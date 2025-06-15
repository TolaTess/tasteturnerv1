import 'package:flutter/material.dart';
import 'package:tasteturner/helper/utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';

class HelpSupport extends StatelessWidget {
  const HelpSupport({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                        fontSize: getTextScale(4.5, context),
                        fontWeight: FontWeight.bold,
                        color: kAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFAQItem('How do I use the spin feature?',
                    'Double tap to start spinning, and tap once to stop. It\'s that simple!'),
                _buildFAQItem('How do I use the calendar and sharing features?',
                    'You can add your special days to the calendar and share them with friends and family by clicking the share icon. Switch between personal and shared calendar views by clicking the person icon.'),
                _buildFAQItem('What is the ingredient battle?',
                    'The ingredient battle is our weekly challenge that encourages you to explore different ingredients and get creative with cooking. Join the challenge and earn points for a chance to win vouchers to your favorite restaurants!'),
                SizedBox(height: getPercentageHeight(1, context)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () async {
                        final Uri url =
                            Uri.parse('https://tasteturner.com/faq');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      child: Text(
                        'More FAQs',
                        style: TextStyle(
                          color: kAccentLight,
                          fontSize: getTextScale(4, context),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final Uri url =
                            Uri.parse('https://tasteturner.com/privacy');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: kAccentLight,
                          fontSize: getTextScale(4, context),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Flexible(
                      child: InkWell(
                        onTap: () async {
                          final Uri url = Uri.parse('https://tasteturner.com');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                        child: Text(
                          'Our website',
                          style: TextStyle(
                            color: kAccentLight,
                            fontSize: getTextScale(4, context),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: isDarkMode
                          ? kDarkModeAccent.withOpacity(0.50)
                          : kAccent.withOpacity(0.50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    onPressed: () async {
                      final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path: 'support@tasteturner.com',
                      );
                      await launchUrl(emailLaunchUri);
                    },
                    child: const Text('Contact Support'),
                  ),
                ),
              ],
            ),
          ),
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
}
