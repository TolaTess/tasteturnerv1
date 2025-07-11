import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';

import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';
import '../service/payment_service.dart';

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

  bool _purchaseInProgress = false;
  String? _purchaseError;

  StreamSubscription? _paymentSubscription;

  @override
  void initState() {
    super.initState();
    _fetchPlan();
    PaymentService().initialize();
    _paymentSubscription = PaymentService()
        .purchaseResults
        .listen(_onPurchaseUpdate, onError: (error) {
      setState(() {
        _purchaseInProgress = false;
        _purchaseError = error.toString();
      });
    });
  }

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    super.dispose();
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
      userPlan = userData?['premiumPlan'] ?? 'month';

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

  void _onPurchaseUpdate(purchaseDetails) async {
    if (purchaseDetails == null) return;
    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      final userId = userService.userId;
      if (userId != null) {
        final selectedPlan = isYearlySelected ? 'year' : 'month';
        await authController.updateIsPremiumStatus(
            context, userId, true, selectedPlan);
      }
      setState(() {
        _purchaseInProgress = false;
      });
      Navigator.pop(context);
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      setState(() {
        _purchaseInProgress = false;
        _purchaseError = purchaseDetails.error?.message ?? 'Unknown error';
      });
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      setState(() {
        _purchaseInProgress = false;
        _purchaseError = 'Purchase cancelled.';
      });
    }
  }

  Future<void> _buyPremium() async {
    setState(() {
      _purchaseInProgress = true;
      _purchaseError = null;
    });
    try {
      if (isYearlySelected) {
        await PaymentService().buyYearly();
      } else {
        await PaymentService().buyMonthly();
      }
    } catch (e) {
      setState(() {
        _purchaseInProgress = false;
        _purchaseError = e.toString();
      });
    }
  }

  Widget _buildPriceCard(bool isDarkMode) {
    final textTheme = Theme.of(context).textTheme;
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
        padding: EdgeInsets.all(getPercentageWidth(4, context)),
        decoration: BoxDecoration(
          color: isDarkMode ? kDarkGrey : kAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kAccent.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              isYearlyPlan ? 'Your Yearly Plan' : 'Your Monthly Plan',
              style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? kLightGrey : kBlack),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              '\$${currentPrice.toStringAsFixed(2)}',
              style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: kAccent),
            ),
            if (isYearlyPlan)
              Text(
                '\$${perMonthPrice.toStringAsFixed(2)}/mo',
                style: textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? kLightGrey : kBlack),
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
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: !isYearlySelected
                    ? (isDarkMode ? kDarkGrey : kAccent.withValues(alpha: 0.1))
                    : (isDarkMode ? Colors.black12 : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !isYearlySelected
                      ? kAccent.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Monthly',
                    style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? kLightGrey : kBlack),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  if (isDiscount && discountPerc > 0)
                    Text(
                      '\$${monthlyPrice.toStringAsFixed(2)}',
                      style: textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: isDarkMode ? Colors.grey : Colors.grey[600]),
                    ),
                  Text(
                    '\$${monthlyPerMonth.toStringAsFixed(2)}',
                    style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold, color: kAccent),
                  ),
                  Text(
                    '/month',
                    style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kLightGrey : kBlack),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: getPercentageWidth(2, context)),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => isYearlySelected = true),
            child: Container(
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: isYearlySelected
                    ? (isDarkMode ? kDarkGrey : kAccent.withValues(alpha: 0.1))
                    : (isDarkMode ? Colors.black12 : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isYearlySelected
                        ? kAccent.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
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
                        style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? kLightGrey : kBlack),
                      ),
                      SizedBox(width: getPercentageWidth(1, context)),
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(2, context),
                              vertical: getPercentageHeight(1, context)),
                          decoration: BoxDecoration(
                            color: kAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            textAlign: TextAlign.center,
                            'SAVE ${((1 - yearlyPerMonth / monthlyPerMonth) * 100).toStringAsFixed(0)}%',
                            style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  if (isDiscount && discountPerc > 0)
                    Text(
                      '\$${yearlyPrice.toStringAsFixed(2)}',
                      style: textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: isDarkMode ? Colors.grey : Colors.grey[600]),
                    ),
                  Text(
                    '\$${discountedYearlyPrice.toStringAsFixed(2)}',
                    style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold, color: kAccent),
                  ),
                  Text(
                    '\$${yearlyPerMonth.toStringAsFixed(2)}/mo',
                    style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kLightGrey : kBlack),
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
    final user = userService.currentUser.value;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Get.back(),
          child: const IconCircleButton(),
        ),
        title: Text(
          isUserPremium ? 'Your Plan' : 'Go Premium',
          style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
              color: kAccent,
            ))
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(4, context)),
                child: Column(
                  children: [
                    SizedBox(height: getPercentageHeight(3, context)),

                    // Header Text
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w300,
                            color: isDarkMode ? kLightGrey : kBlack),
                        children: [
                          TextSpan(text: 'Welcome '),
                          TextSpan(
                            text: user?.displayName ?? '',
                            style: textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: isDarkMode ? kLightGrey : kAccent),
                          ),
                          TextSpan(text: ','),
                        ],
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(3, context)),

                    Text(
                      isUserPremium
                          ? 'You are currently enjoying an ad-free experience! Along with the below benefits.'
                          : 'Upgrade to Premium for an ad-free experience!',
                      style: textTheme.titleMedium?.copyWith(),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                        height: isUserPremium
                            ? getPercentageHeight(1, context)
                            : getPercentageHeight(4, context)),

                    // Premium Features
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(4, context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUserPremium ? '' : 'Premium Benefits',
                            style: textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),
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
                    SizedBox(height: getPercentageHeight(2, context)),

                    // Premium Plan Cards
                    _buildPriceCard(isDarkMode),
                    SizedBox(height: getPercentageHeight(3, context)),

                    // Action Button
                    if (!isUserPremium)
                      Column(
                        children: [
                          if (_purchaseError != null)
                            Padding(
                              padding: EdgeInsets.only(
                                  bottom: getPercentageHeight(1, context)),
                              child: Text(_purchaseError!,
                                  style: textTheme.bodyMedium?.copyWith(
                                      color: Colors.red)),
                            ),
                          AppButton(
                            text: _purchaseInProgress
                                ? 'Processing...'
                                : 'Go Ad-Free Now',
                            type: AppButtonType.primary,
                            width: 100,
                            isLoading: _purchaseInProgress,
                            onPressed:
                                _purchaseInProgress ? () {} : _buyPremium,
                          ),
                        ],
                      ),
                    SizedBox(height: getPercentageHeight(2, context)),

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
                          style: textTheme.bodyLarge?.copyWith(
                              color: isDarkMode ? kLightGrey : kBlack),
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
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: getPercentageHeight(1, context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle,
              color: kAccent, size: getPercentageWidth(4, context)),
          SizedBox(width: getPercentageWidth(2, context)),
          Expanded(
            child: Text(
              text,
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
