import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/primary_button.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  _PremiumScreenState createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool isLoading = true;
  bool isUserPremium = false;
  Map<String, dynamic>? premiumPlan;

  @override
  void initState() {
    super.initState();
    _fetchPlan();
  }

  Future<void> _fetchPlan() async {
    try {
      final userId = userService.userId;
      if (userId == null || userId.isEmpty) {
        throw Exception("User ID is not available.");
      }

      // Get the user's premium status
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userDoc.data();
      isUserPremium = userData?['isPremium'] ?? false;

      // Get the premium plan
      final planDoc =
          await FirebaseFirestore.instance.collection('plans').get();
      if (planDoc.docs.isNotEmpty) {
        premiumPlan = planDoc.docs[0].data();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching plan: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
      final user = userService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Premium'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
              color: kAccent,
            ))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 30),

                    // Header Text
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            color: isDarkMode ? kLightGrey : kBlack),
                        children: [
                          const TextSpan(text: 'Welcome '),
                          TextSpan(
                            text: user?.displayName ?? '',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isDarkMode ? kLightGrey : kAccent),
                          ),
                          const TextSpan(text: ','),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    Text(
                      isUserPremium
                          ? 'You are currently enjoying an ad-free experience!'
                          : 'Upgrade to Premium for an ad-free experience!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Premium Features
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Premium Benefits',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          BulletPoint(text: premiumPlan?['features'][0] ?? ''),
                          BulletPoint(text: premiumPlan?['features'][1] ?? ''),
                          BulletPoint(text: premiumPlan?['features'][2] ?? ''),
                          BulletPoint(text: premiumPlan?['features'][3] ?? ''),
                        ],
                      ),
                    ),
                    const SizedBox(height: 45),

                    // Premium Plan Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? kDarkGrey : kAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: kAccent.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Premium Plan',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? kLightGrey : kBlack,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            '\$${premiumPlan?['price']?.toStringAsFixed(2) ?? '9.99'}/month',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: kAccent,
                            ),
                          ),
                          const SizedBox(height: 15),
                          if (isUserPremium)
                            GestureDetector(
                              onTap: () async {
                                final userId = userService.userId;
                                if (userId != null) {
                                  try {
                                    await authController.updateIsPremiumStatus(
                                        userId, false);
                                  } catch (e) {
                                    print("Error updating Premium: $e");
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                              child: Text(
                                'Cancel anytime',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkMode ? kLightGrey : kBlack,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Action Button
                    if (!isUserPremium)
                      PrimaryButton(
                        text: 'Go Ad-Free Now',
                        press: () async {
                          final userId = userService.userId;
                          if (userId != null) {
                            try {
                              // Update premium status
                              await authController.updateIsPremiumStatus(
                                  userId, true);

                              Navigator.pop(context);
                            } catch (e) {
                              print("Error updating Premium: $e");
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Bullet Point Widget
class BulletPoint extends StatelessWidget {
  final String text;

  const BulletPoint({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: kAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

