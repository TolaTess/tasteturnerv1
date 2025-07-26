import 'package:flutter/material.dart';
import 'package:tasteturner/helper/utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../widgets/primary_button.dart';

class HelpSupport extends StatelessWidget {
  const HelpSupport({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: getPercentageHeight(2, context)),
                Center(
                  child: Text(
                    'Frequently Asked Questions',
                    style: textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: kAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: getPercentageHeight(1, context)),
                _buildFAQItem(
                    'How do I use the spin feature?',
                    'Double tap to start spinning, and tap once to stop. It\'s that simple!',
                    textTheme),
                SizedBox(height: getPercentageHeight(1, context)),
                _buildFAQItem(
                    'How do I use the calendar and sharing features?',
                    'You can add your special days to the calendar and share them with friends and family by clicking the share icon. Switch between personal and shared calendar views by clicking the person icon.',
                    textTheme),
                SizedBox(height: getPercentageHeight(1, context)),
                _buildFAQItem(
                    'What is the ingredient battle?',
                    'The ingredient battle is our weekly challenge that encourages you to explore different ingredients and get creative with cooking. Join the challenge and earn points for a chance to win vouchers to your favorite restaurants!',
                    textTheme),
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
                        style: textTheme.bodyMedium?.copyWith(
                          color: kAccentLight,
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
                        style: textTheme.bodyMedium?.copyWith(
                          color: kAccentLight,
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
                          style: textTheme.bodyMedium?.copyWith(
                            color: kAccentLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getPercentageHeight(5, context)),
                Center(
                  child: AppButton(
                      text: 'Contact Support',
                      onPressed: () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'support@tasteturner.com',
                        );
                        await launchUrl(emailLaunchUri);
                      },
                      width: 100,
                      type: AppButtonType.secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
