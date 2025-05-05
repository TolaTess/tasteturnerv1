import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tasteturner/helper/utils.dart';
import 'package:tasteturner/pages/safe_text_field.dart';

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
            _buildFAQItem('How do I use the spin feature?',
                'Double tap to start spinning, and tap once to stop. It\'s that simple!'),
            _buildFAQItem('How do I use the calendar and sharing features?',
                'You can add your special days to the calendar and share them with friends and family by clicking the share icon. Switch between personal and shared calendar views by clicking the person icon.'),
            _buildFAQItem('What is the ingredient battle?',
                'The ingredient battle is our weekly challenge that encourages you to explore different ingredients and get creative with cooking. Join the challenge and earn points for a chance to win vouchers to your favorite restaurants!'),
            const SizedBox(height: 24),
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
                onPressed: () {
                  _showSupportModal(context, isDarkMode);
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

  void _showSupportModal(BuildContext context, bool isDarkMode) {
    final _formKey = GlobalKey<FormState>();
    String feedbackType = 'Concerns';
    String message = '';
    final List<String> feedbackTypes = ['Concerns', 'Feedback', 'Improvement'];
    bool isSubmitting = false;

    showModalBottomSheet(
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send us your thoughts',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      dropdownColor: isDarkMode ? kLightGrey : kBackgroundColor,
                      value: feedbackType,
                      items: feedbackTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type,
                                    style: TextStyle(
                                      color: isDarkMode ? kWhite : kDarkGrey,
                                    )),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) feedbackType = val;
                      },
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle: TextStyle(
                          color: isDarkMode ? kWhite : kDarkGrey,
                        ),
                        enabledBorder: outlineInputBorder(20),
                        focusedBorder: outlineInputBorder(20),
                        border: outlineInputBorder(20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SafeTextField(
                      style: TextStyle(
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Message',
                        labelStyle: TextStyle(
                          color: isDarkMode ? kWhite : kDarkGrey,
                        ),
                        enabledBorder: outlineInputBorder(20),
                        focusedBorder: outlineInputBorder(20),
                        border: outlineInputBorder(20),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Enter your message'
                          : null,
                      onChanged: (val) => message = val,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: kAccentLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  setState(() => isSubmitting = true);
                                  final userId =
                                      userService.userId ?? 'anonymous';
                                  await FirebaseFirestore.instance
                                      .collection('supportMessages')
                                      .add({
                                    'userId': userId,
                                    'type': feedbackType,
                                    'message': message,
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });
                                  if (Navigator.canPop(modalContext)) {
                                    Navigator.pop(modalContext);
                                  }
                                  // Use root context for snackbar
                                  Future.delayed(
                                      const Duration(milliseconds: 300), () {
                                    showTastySnackbar(
                                      'Your $feedbackType was sent',
                                      'Thank you for your feedback!',
                                      context,
                                    );
                                  });
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
