import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';

class HomepageGuidanceWidget extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const HomepageGuidanceWidget({
    super.key,
    this.onComplete,
    this.onSkip,
  });

  @override
  State<HomepageGuidanceWidget> createState() => _HomepageGuidanceWidgetState();
}

class _HomepageGuidanceWidgetState extends State<HomepageGuidanceWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentStep = 0;
  bool _isVisible = true;

  final List<Map<String, dynamic>> _guidanceSteps = [
    {
      'title': 'Welcome to Taste Turner!',
      'description':
          'Let\'s get you started with a quick tour of the key features.',
      'icon': Icons.home,
      'color': kAccent,
    },
    {
      'title': 'Start with Your Profile',
      'description':
          'Complete your profile and set your nutrition goals to get personalized recommendations.',
      'icon': Icons.person,
      'color': kBlue,
    },
    {
      'title': 'Track Your Meals',
      'description':
          'Use The Pass to review orders and log your daily meals and track your nutrition progress.',
      'icon': Icons.restaurant,
      'color': kAccent,
    },
    {
      'title': 'Discover Recipes',
      'description':
          'Explore the Recipes section to find healthy meal ideas that match your preferences.',
      'icon': Icons.book,
      'color': kPurple,
    },
    {
      'title': 'Spin for Inspiration',
      'description':
          'Use the Spin feature when you\'re not sure what to cook - it\'ll surprise you with great ideas!',
      'icon': Icons.casino,
      'color': kAccentLight,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _guidanceSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _animationController.reset();
      _animationController.forward();
    } else {
      _completeGuidance();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _completeGuidance() async {
    // Save that user has completed the guidance
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_homepage_guidance', true);

    setState(() {
      _isVisible = false;
    });

    widget.onComplete?.call();
  }

  void _skipGuidance() async {
    // Save that user has skipped the guidance
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_homepage_guidance', true);

    setState(() {
      _isVisible = false;
    });

    widget.onSkip?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final currentStep = _guidanceSteps[_currentStep];

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              margin: EdgeInsets.all(getPercentageWidth(3, context)),
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: isDarkMode ? kDarkGrey : kWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: currentStep['color'].withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Getting Started',
                        style: textTheme.titleMedium?.copyWith(
                          color: currentStep['color'],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: _skipGuidance,
                        icon: Icon(
                          Icons.close,
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                          size: getIconScale(5, context),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: getPercentageHeight(2, context)),

                  // Step indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_guidanceSteps.length, (index) {
                      return Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(1, context),
                        ),
                        width: getPercentageWidth(2, context),
                        height: getPercentageWidth(2, context),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentStep
                              ? currentStep['color']
                              : (isDarkMode
                                  ? kLightGrey
                                  : kDarkGrey.withValues(alpha: 0.3)),
                        ),
                      );
                    }),
                  ),

                  SizedBox(height: getPercentageHeight(3, context)),

                  // Icon
                  Container(
                    width: getPercentageWidth(15, context),
                    height: getPercentageWidth(15, context),
                    decoration: BoxDecoration(
                      color: currentStep['color'].withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      currentStep['icon'],
                      color: currentStep['color'],
                      size: getIconScale(8, context),
                    ),
                  ),

                  SizedBox(height: getPercentageHeight(3, context)),

                  // Title
                  Text(
                    currentStep['title'],
                    style: textTheme.headlineSmall?.copyWith(
                      color: isDarkMode ? kWhite : kBlack,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: getPercentageHeight(2, context)),

                  // Description
                  Text(
                    currentStep['description'],
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? kLightGrey : kDarkGrey,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: getPercentageHeight(4, context)),

                  // Navigation buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Previous button
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: _previousStep,
                          child: Text(
                            'Previous',
                            style: textTheme.bodyMedium?.copyWith(
                              color: currentStep['color'],
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      // Next/Complete button
                      ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentStep['color'],
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
                          _currentStep == _guidanceSteps.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: textTheme.bodyMedium?.copyWith(
                            color: kWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Skip button
                      if (_currentStep == 0)
                        TextButton(
                          onPressed: _skipGuidance,
                          child: Text(
                            'Skip',
                            style: textTheme.bodyMedium?.copyWith(
                              color: isDarkMode ? kLightGrey : kDarkGrey,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
