import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/bottom_nav.dart';

class PostOnboardingWalkthrough extends StatefulWidget {
  const PostOnboardingWalkthrough({super.key});

  @override
  State<PostOnboardingWalkthrough> createState() =>
      _PostOnboardingWalkthroughState();
}

class _PostOnboardingWalkthroughState extends State<PostOnboardingWalkthrough>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentPage = 0;
  late final AnimationController _bounceController;

  final List<Map<String, dynamic>> _features = [
    {
      'title': 'Track Your Meals',
      'description':
          'Log your daily meals and track your nutrition progress at The Pass',
      'icon': 'assets/images/svg/diary.svg',
      'color': kAccent,
    },
    {
      'title': 'Discover Recipes',
      'description':
          'Explore thousands of healthy recipes tailored to your dietary preferences',
      'icon': 'assets/images/svg/book-outline.svg',
      'color': kPurple,
    },
    {
      'title': 'Spin & Discover',
      'description':
          'Let our smart wheel surprise you with exciting new meal ideas and recipes',
      'icon': 'assets/images/svg/spin.svg',
      'color': kAccentLight,
    },
    {
      'title': 'Set & Achieve Goals',
      'description':
          'Create personalized nutrition goals and track your progress with visual charts',
      'icon': 'assets/images/svg/target.svg',
      'color': kBlue,
    },
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _features.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeWalkthrough();
    }
  }

  void _completeWalkthrough() {
    if (!mounted) return;

    try {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const BottomNavSec(),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating from walkthrough: $e');
      if (mounted) {
        // Fallback navigation
        Get.offAll(() => const BottomNavSec());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _completeWalkthrough,
                child: Text(
                  'Skip',
                  style: textTheme.bodyMedium?.copyWith(
                    color: kAccent,
                    fontSize: getTextScale(3.5, context),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _features.length,
                itemBuilder: (context, index) {
                  final feature = _features[index];
                  return _buildFeaturePage(feature, isDarkMode, textTheme);
                },
              ),
            ),

            // Page indicators
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(5, context)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page dots
                  Row(
                    children: List.generate(_features.length, (index) {
                      return Container(
                        margin: EdgeInsets.only(
                            right: getPercentageWidth(2, context)),
                        width: getPercentageWidth(2, context),
                        height: getPercentageWidth(2, context),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentPage
                              ? _features[index]['color']
                              : (isDarkMode
                                  ? kLightGrey
                                  : kDarkGrey.withValues(alpha: 0.3)),
                        ),
                      );
                    }),
                  ),

                  // Next/Get Started button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: kWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(6, context),
                        vertical: getPercentageHeight(1.5, context),
                      ),
                    ),
                    child: Text(
                      _currentPage == _features.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kWhite,
                        fontSize: getTextScale(3.5, context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: getPercentageHeight(3, context)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePage(
      Map<String, dynamic> feature, bool isDarkMode, TextTheme textTheme) {
    return Padding(
      padding: EdgeInsets.all(getPercentageWidth(5, context)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          Container(
            width: getPercentageWidth(25, context),
            height: getPercentageWidth(25, context),
            decoration: BoxDecoration(
              color: feature['color'].withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                feature['icon'],
                width: getPercentageWidth(12, context),
                height: getPercentageWidth(12, context),
                colorFilter:
                    ColorFilter.mode(feature['color'], BlendMode.srcIn),
              ),
            ),
          ),

          SizedBox(height: getPercentageHeight(5, context)),

          // Feature title
          Text(
            feature['title'],
            style: textTheme.headlineMedium?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
              fontSize: getTextScale(6, context),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: getPercentageHeight(3, context)),

          // Feature description
          Text(
            feature['description'],
            style: textTheme.bodyLarge?.copyWith(
              color: isDarkMode ? kLightGrey : kDarkGrey,
              fontSize: getTextScale(4, context),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
