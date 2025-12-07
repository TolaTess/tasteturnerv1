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
  Map<String, dynamic>? premiumPlan; // Used for pricing only
  bool isYearlySelected =
      true; // Default to yearly as it's usually the better deal

  bool _purchaseInProgress = false;
  String? _purchaseError;

  StreamSubscription? _paymentSubscription;

  // Local list of premium benefits
  static const List<String> _premiumBenefits = [
    'Meal Tracking',
    'Macros Tracking',
    'AI Food Analysis',
    'Personalized chat with Tasty AI',
    'Ad-free experience',
    'Spin for Spontaneous Cooking',
    'Unlimited Shared Calendars',
    'Unlimited Family Members',
    'Unlimited 7 Days Meal Plan Generations',
    'Weekly Shopping List Generations',
    'track your progress',
    'ai recommendation',
    'dine-in mode',
  ];

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

      // Get the premium plan for pricing information only
      final planDoc = await firestore.collection('plans').get();
      if (planDoc.docs.isNotEmpty) {
        premiumPlan = planDoc.docs[0].data();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching plan: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Maps standard feature names to Executive Chef terminology
  String _getChefFeatureName(String feature) {
    final normalizedFeature = feature.trim().toLowerCase();

    // The Core Operations (Tracking & Data)
    if (normalizedFeature.contains('meal tracking')) {
      return 'Master the Daily Log';
    }
    if (normalizedFeature.contains('macros tracking')) {
      return 'Macros Inventory Control';
    }
    if (normalizedFeature.contains('track your progress')) {
      return 'Kitchen Performance Analytics';
    }
    if (normalizedFeature.contains('ad-free') ||
        normalizedFeature.contains('ad free')) {
      return 'Distraction-Free Service';
    }

    // The Intelligence (AI Features)
    if (normalizedFeature.contains('ai food analysis')) {
      return 'Instant Plate QC';
    }
    if (normalizedFeature.contains('personalized chat') ||
        normalizedFeature.contains('chat with tasty ai')) {
      return 'Direct Line to Turner';
    }
    if (normalizedFeature.contains('ai recommendation') ||
        normalizedFeature.contains('ai-powered recommendation')) {
      return 'Intelligent Menu Sourcing';
    }
    if (normalizedFeature.contains('spin for spontaneous') ||
        normalizedFeature.contains('spontaneous cooking')) {
      return 'Unlimited Spontaneous Cooking';
    }
    if (normalizedFeature.contains('dine-in mode')) {
      return 'Dine-In Mode';
    }

    // The Logistics (Planning & Shopping)
    if (normalizedFeature.contains('unlimited meal plan') ||
        normalizedFeature.contains('7 days meal plan')) {
      return 'Unlimited Menu Design';
    }
    if (normalizedFeature.contains('weekly shopping list') ||
        normalizedFeature.contains('shopping list generation')) {
      return 'Automated Inventory Management';
    }
    if (normalizedFeature.contains('personalized meal plan')) {
      return 'Personalized Menu Curation';
    }
    if (normalizedFeature.contains('unlimited shared calendar')) {
      return 'Family Planning and Calendar Sharing';
    }
    if (normalizedFeature.contains('unlimited family member')) {
      return 'Extended Family Access';
    }

    // Return original if no mapping found
    return feature;
  }

  /// Returns a plain-language explanation for chef lingual benefit names
  String? _getBenefitExplanation(String chefFeatureName) {
    switch (chefFeatureName) {
      // The Core Operations
      case 'Master the Daily Log':
        return 'Track all your meals and food intake throughout the day';
      case 'Macros Inventory Control':
        return 'Monitor protein, carbs, and fats to meet your nutrition goals';
      case 'Kitchen Performance Analytics':
        return 'View detailed progress charts and insights on your health journey';
      case 'Distraction-Free Service':
        return 'Enjoy the app without any advertisements';

      // The Intelligence
      case 'Instant Plate QC':
        return 'AI-powered food analysis - take a photo and get instant nutrition info';
      case 'Direct Line to Turner':
        return 'Chat with Sous Chef Turner for personalized kitchen advice and meal suggestions';
      case 'Intelligent Menu Sourcing':
        return 'Get AI-powered menu recommendations tailored to your preferences';
      case 'Unlimited Spontaneous Cooking':
        return 'Use the spin feature unlimited times to discover random meal ideas';
      case 'Dine-In Mode':
        return 'Switch to Dine-In Mode for an optimized in-restaurant experience with menu scanning and recommendations';

      // The Logistics
      case 'Unlimited Menu Design':
        return 'Generate unlimited 7-day menu plans customized to your goals';
      case 'Automated Inventory Management':
        return 'Automatically generate weekly shopping lists from your meal plans';
      case 'Personalized Menu Curation':
        return 'Get meal plans tailored specifically to your dietary needs and preferences';
      case 'Family Planning and Calendar Sharing':
        return 'Share meal calendars with family members and coordinate meals together';
      case 'Extended Family Access':
        return 'Add unlimited family members to track their nutrition goals';

      default:
        return null;
    }
  }

  /// Categorizes features into their respective groups
  Map<String, List<String>> _categorizeFeatures(List<String> features) {
    final Map<String, List<String>> categorized = {
      'coreOperations': [],
      'intelligence': [],
      'logistics': [],
      'other': [],
    };

    for (final feature in features) {
      final normalizedFeature = feature.trim().toLowerCase();
      final chefName = _getChefFeatureName(feature);

      // The Core Operations (Tracking & Data)
      if (normalizedFeature.contains('meal tracking') ||
          normalizedFeature.contains('macros tracking') ||
          normalizedFeature.contains('track your progress') ||
          normalizedFeature.contains('ad-free') ||
          normalizedFeature.contains('ad free')) {
        categorized['coreOperations']!.add(chefName);
      }
      // The Intelligence (AI Features)
      else if (normalizedFeature.contains('ai food analysis') ||
          normalizedFeature.contains('personalized chat') ||
          normalizedFeature.contains('chat with tasty ai') ||
          normalizedFeature.contains('ai recommendation') ||
          normalizedFeature.contains('ai-powered recommendation') ||
          normalizedFeature.contains('spin for spontaneous') ||
          normalizedFeature.contains('spontaneous cooking') ||
          normalizedFeature.contains('dine-in mode') ||
          normalizedFeature.contains('dine in mode') ||
          chefName == 'Dine-In Mode') {
        categorized['intelligence']!.add(chefName);
      }
      // The Logistics (Planning & Shopping)
      else if (normalizedFeature.contains('unlimited meal plan') ||
          normalizedFeature.contains('7 days meal plan') ||
          normalizedFeature.contains('weekly shopping list') ||
          normalizedFeature.contains('shopping list generation') ||
          normalizedFeature.contains('personalized meal plan') ||
          normalizedFeature.contains('unlimited shared calendar') ||
          normalizedFeature.contains('unlimited family member')) {
        categorized['logistics']!.add(chefName);
      }
      // Other features
      else {
        categorized['other']!.add(chefName);
      }
    }

    return categorized;
  }

  /// Builds a benefit section with heading and benefits list
  Widget _buildBenefitSection(
    BuildContext context,
    String title,
    List<String> benefits,
    TextTheme textTheme,
    bool isDarkMode,
  ) {
    if (benefits.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: getPercentageWidth(4, context)),
          child: Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              color: kAccent,
              fontWeight: FontWeight.w600,
              fontSize: getTextScale(5, context),
            ),
          ),
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: getPercentageWidth(4, context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...benefits.map((benefit) => Padding(
                    padding: EdgeInsets.only(
                      bottom: getPercentageHeight(0.8, context),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: getPercentageHeight(0.5, context),
                            right: getPercentageWidth(2, context),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: getIconScale(4, context),
                            color: kAccent,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                benefit,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode
                                      ? kWhite.withValues(alpha: 0.9)
                                      : kDarkGrey.withValues(alpha: 0.9),
                                  fontSize: getTextScale(3.5, context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_getBenefitExplanation(benefit) != null) ...[
                                SizedBox(
                                    height: getPercentageHeight(0.3, context)),
                                Text(
                                  _getBenefitExplanation(benefit)!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: isDarkMode
                                        ? kWhite.withValues(alpha: 0.6)
                                        : kDarkGrey.withValues(alpha: 0.6),
                                    fontSize: getTextScale(3, context),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        SizedBox(height: getPercentageHeight(2, context)),
      ],
    );
  }

  void _onPurchaseUpdate(purchaseDetails) async {
    if (purchaseDetails == null) return;
    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      try {
        final userId = userService.userId;
        if (userId == null) {
          throw Exception("User ID is not available.");
        }

        // Extract receipt data from purchase details
        final receiptData =
            purchaseDetails.verificationData.serverVerificationData;
        if (receiptData == null || receiptData.isEmpty) {
          throw Exception("Receipt data is missing from purchase.");
        }

        // Determine product ID and plan
        final productId = purchaseDetails.productID;
        final selectedPlan = isYearlySelected ? 'year' : 'month';

        // Verify purchase with server (this will update premium status after validation)
        await authController.verifyPurchaseWithServer(
          context,
          receiptData,
          productId,
          selectedPlan,
        );

        setState(() {
          _purchaseInProgress = false;
        });
        Navigator.pop(context);
      } catch (e) {
        debugPrint("Error processing purchase: $e");
        setState(() {
          _purchaseInProgress = false;
          _purchaseError = e.toString();
        });
      }
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      setState(() {
        _purchaseInProgress = false;
        _purchaseError = purchaseDetails.error?.message ?? 'Unknown error';
      });
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      setState(() {
        _purchaseInProgress = false;
        _purchaseError = 'Purchase cancelled, Chef.';
      });
    }
  }

  Future<void> _buyPremium() async {
    setState(() {
      _purchaseInProgress = true;
      _purchaseError = null;
    });
    try {
      final userId = userService.userId;
      if (isYearlySelected) {
        await PaymentService().buyYearly(userId: userId);
      } else {
        await PaymentService().buyMonthly(userId: userId);
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
              isYearlyPlan ? 'Your Yearly Service' : 'Your Monthly Service',
              style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? kLightGrey : kBlack),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              '\$${currentPrice.toStringAsFixed(2)}',
              style: textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: kAccent),
            ),
            if (isYearlyPlan)
              Text(
                '\$${perMonthPrice.toStringAsFixed(2)}/mo',
                style: textTheme.bodyMedium
                    ?.copyWith(color: isDarkMode ? kLightGrey : kBlack),
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
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Monthly Service',
                    style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? kLightGrey : kBlack),
                  ),
                  SizedBox(height: getPercentageHeight(1.5, context)),
                  if (isDiscount && discountPerc > 0) ...[
                    Text(
                      '\$${monthlyPrice.toStringAsFixed(2)}',
                      style: textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: isDarkMode ? Colors.grey : Colors.grey[600]),
                    ),
                    SizedBox(height: getPercentageHeight(0.5, context)),
                  ],
                  Text(
                    '\$${monthlyPerMonth.toStringAsFixed(2)}',
                    style: textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: kAccent),
                  ),
                  SizedBox(height: getPercentageHeight(0.3, context)),
                  Text(
                    '/month',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: isDarkMode ? kLightGrey : kBlack),
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
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Yearly Service',
                          style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? kLightGrey : kBlack),
                        ),
                      ),
                      SizedBox(width: getPercentageWidth(1, context)),
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(2, context),
                              vertical: getPercentageHeight(0.8, context)),
                          decoration: BoxDecoration(
                            color: kAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            textAlign: TextAlign.center,
                            'SAVE ${((1 - yearlyPerMonth / monthlyPerMonth) * 100).toStringAsFixed(0)}%',
                            style: textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(1.5, context)),
                  if (isDiscount && discountPerc > 0) ...[
                    Text(
                      '\$${yearlyPrice.toStringAsFixed(2)}',
                      style: textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: isDarkMode ? Colors.grey : Colors.grey[600]),
                    ),
                    SizedBox(height: getPercentageHeight(0.5, context)),
                  ],
                  Text(
                    '\$${discountedYearlyPrice.toStringAsFixed(2)}',
                    style: textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: kAccent),
                  ),
                  SizedBox(height: getPercentageHeight(0.3, context)),
                  Text(
                    '\$${yearlyPerMonth.toStringAsFixed(2)}/mo',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: isDarkMode ? kLightGrey : kBlack),
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
          isUserPremium ? 'Your Service Plan' : 'Go Executive Chef',
          style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w500, fontSize: getTextScale(7, context)),
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
                          TextSpan(text: 'Welcome, '),
                          TextSpan(
                            text: user?.displayName ?? '',
                            style: textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: isDarkMode ? kLightGrey : kAccent),
                          ),
                          TextSpan(text: ' Chef'),
                        ],
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(3, context)),

                    Text(
                      isUserPremium
                          ? 'You\'re currently enjoying a distraction free service, Chef!'
                          : 'Upgrade to Executive Chef for a distraction free service, Chef!',
                      style: textTheme.titleMedium?.copyWith(),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                        height: isUserPremium
                            ? getPercentageHeight(1, context)
                            : getPercentageHeight(3, context)),

                    // Premium Features
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: getPercentageHeight(1, context)),
                        Center(
                          child: Text(
                            isUserPremium
                                ? 'Your Executive Chef Benefits:'
                                : 'Executive Chef Benefits:',
                            style: textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: kAccentLight,
                                fontSize: getTextScale(7, context)),
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(3, context)),
                        // Categorize and display benefits by section
                        Builder(
                          builder: (context) {
                            final categorized =
                                _categorizeFeatures(_premiumBenefits);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildBenefitSection(
                                  context,
                                  'The Core Operations',
                                  categorized['coreOperations']!,
                                  textTheme,
                                  isDarkMode,
                                ),
                                _buildBenefitSection(
                                  context,
                                  'The Intelligence',
                                  categorized['intelligence']!,
                                  textTheme,
                                  isDarkMode,
                                ),
                                _buildBenefitSection(
                                  context,
                                  'The Logistics',
                                  categorized['logistics']!,
                                  textTheme,
                                  isDarkMode,
                                ),
                                if (categorized['other']!.isNotEmpty)
                                  _buildBenefitSection(
                                    context,
                                    'Additional Benefits',
                                    categorized['other']!,
                                    textTheme,
                                    isDarkMode,
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
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
                                  style: textTheme.bodyMedium
                                      ?.copyWith(color: Colors.red)),
                            ),
                          AppButton(
                            text: _purchaseInProgress
                                ? 'Processing, Chef...'
                                : 'Go Ad-Free Now, Chef',
                            type: AppButtonType.primary,
                            width: 100,
                            isLoading: _purchaseInProgress,
                            onPressed:
                                _purchaseInProgress ? () {} : _buyPremium,
                          ),
                        ],
                      ),
                    SizedBox(height: getPercentageHeight(1, context)),

                    if (isUserPremium)
                      GestureDetector(
                        onTap: () async {
                          final userId = userService.userId;
                          if (userId != null) {
                            try {
                              await authController.updateIsPremiumStatus(
                                  context, userId, false, '');
                            } catch (e) {
                              debugPrint("Error updating Premium: $e");
                              if (mounted) {
                                showTastySnackbar(
                                  'Service Error',
                                  'Failed to update service, Chef. Please try again.',
                                  context,
                                );
                              }
                            }
                          }
                        },
                        child: Text(
                          'Cancel anytime, Chef',
                          style: textTheme.bodyLarge?.copyWith(
                              color: isDarkMode ? kLightGrey : kBlack),
                        ),
                      ),
                    SizedBox(height: getPercentageHeight(10, context)),
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
