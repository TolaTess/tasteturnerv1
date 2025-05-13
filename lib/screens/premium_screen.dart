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
  String? userPlan;
  Map<String, dynamic>? premiumPlan;
  bool isYearlySelected =
      true; // Default to yearly as it's usually the better deal

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
      final userDoc = await firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      isUserPremium = userData?['isPremium'] ?? false;
      userPlan = userData?['premiumPlan'] ?? '';

      // Get the premium plan
      final planDoc = await firestore.collection('plans').get();
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

  Widget _buildPriceCard(bool isDarkMode) {
    final monthlyPrice = premiumPlan?['plan']?['month']?.toDouble() ?? 9.99;
    final yearlyPrice = premiumPlan?['plan']?['year']?.toDouble() ?? 99.99;
    final isDiscount = premiumPlan?['isDiscount'] ?? false;
    final discountPerc = premiumPlan?['discountPerc']?.toDouble() ?? 0.0;

    final discountedMonthlyPrice = isDiscount && !isUserPremium
        ? monthlyPrice * (1 - discountPerc / 100)
        : monthlyPrice;
    final discountedYearlyPrice = isDiscount && !isUserPremium
        ? yearlyPrice * (1 - discountPerc / 100)
        : yearlyPrice;
    final monthlyPerMonth = discountedMonthlyPrice;
    final yearlyPerMonth = discountedYearlyPrice / 12;

    // If user is premium, only show their current plan
    if (isUserPremium) {
      final isYearlyPlan = userPlan == 'year';
      final currentPrice =
          isYearlyPlan ? discountedYearlyPrice : discountedMonthlyPrice;
      final perMonthPrice = isYearlyPlan ? yearlyPerMonth : monthlyPerMonth;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? kDarkGrey : kAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kAccent.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              isYearlyPlan ? 'Your Yearly Plan' : 'Your Monthly Plan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? kLightGrey : kBlack,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              '\$${currentPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: kAccent,
              ),
            ),
            if (isYearlyPlan)
              Text(
                '\$${perMonthPrice.toStringAsFixed(2)}/mo',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? kLightGrey : kBlack,
                ),
              ),
          ],
        ),
      );
    }

    // Show both plans for non-premium users
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => isYearlySelected = false),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: !isYearlySelected
                    ? (isDarkMode ? kDarkGrey : kAccent.withOpacity(0.1))
                    : (isDarkMode ? Colors.black12 : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !isYearlySelected
                      ? kAccent.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Monthly',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? kLightGrey : kBlack,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (isDiscount && discountPerc > 0)
                    Text(
                      '\$${monthlyPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        decoration: TextDecoration.lineThrough,
                        color: isDarkMode ? Colors.grey : Colors.grey[600],
                      ),
                    ),
                  Text(
                    '\$${monthlyPerMonth.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: kAccent,
                    ),
                  ),
                  Text(
                    '/month',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? kLightGrey : kBlack,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => isYearlySelected = true),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isYearlySelected
                    ? (isDarkMode ? kDarkGrey : kAccent.withOpacity(0.1))
                    : (isDarkMode ? Colors.black12 : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isYearlySelected
                      ? kAccent.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Yearly',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? kLightGrey : kBlack,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            textAlign: TextAlign.center,
                            'SAVE ${((1 - yearlyPerMonth / monthlyPerMonth) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isDiscount && discountPerc > 0)
                    Text(
                      '\$${yearlyPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        decoration: TextDecoration.lineThrough,
                        color: isDarkMode ? Colors.grey : Colors.grey[600],
                      ),
                    ),
                  Text(
                    '\$${discountedYearlyPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: kAccent,
                    ),
                  ),
                  Text(
                    '\$${yearlyPerMonth.toStringAsFixed(2)}/mo',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? kLightGrey : kBlack,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
                    const SizedBox(height: 30),

                    Text(
                      isUserPremium
                          ? 'You are currently enjoying an ad-free experience! Along with the below benefits.'
                          : 'Upgrade to Premium for an ad-free experience!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isUserPremium ? 10 : 40),

                    // Premium Features
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUserPremium ? '' : 'Premium Benefits',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (premiumPlan != null &&
                              premiumPlan!['features'] != null)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  (premiumPlan!['features'] as List).length,
                              itemBuilder: (context, index) {
                                return BulletPoint(
                                  text: premiumPlan!['features'][index],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 45),

                    // Premium Plan Cards
                    _buildPriceCard(isDarkMode),
                    const SizedBox(height: 40),

                    // Action Button
                    if (!isUserPremium)
                      PrimaryButton(
                        text: 'Go Ad-Free Now',
                        press: () async {
                          final userId = userService.userId;
                          if (userId != null) {
                            try {
                              // Update premium status with selected plan
                              final selectedPlan =
                                  isYearlySelected ? 'year' : 'month';
                              await authController.updateIsPremiumStatus(
                                  context, userId, true, selectedPlan);

                              Navigator.pop(context);
                            } catch (e) {
                              print("Error updating Premium: $e");
                              if (mounted) {
                                showTastySnackbar(
                                  'Please try again.',
                                  'Error: $e',
                                  context,
                                  backgroundColor: kRed,
                                );
                              }
                            }
                          }
                        },
                      ),

                    if (isUserPremium)
                      GestureDetector(
                        onTap: () async {
                          final userId = userService.userId;
                          if (userId != null) {
                            try {
                              await authController.updateIsPremiumStatus(
                                  context, userId, false, '');
                            } catch (e) {
                              print("Error updating Premium: $e");
                              if (mounted) {
                                showTastySnackbar(
                                  'Please try again.',
                                  'Error: $e',
                                  context,
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
