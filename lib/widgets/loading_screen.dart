import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';

class LoadingScreen extends StatefulWidget {
  final int? progressPercentage;
  final String? loadingText;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const LoadingScreen({
    super.key,
    this.progressPercentage = 50,
    this.loadingText = "Loading",
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _sparkleController;
  late Animation<double> _progressAnimation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _sparkleController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: (widget.progressPercentage ?? 50) / 100.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.elasticOut,
    ));

    _progressController.forward();
    _sparkleController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: isDarkMode ? kDarkGrey.withOpacity(0.3) : kWhite.withOpacity(0.3),
      body: SafeArea(
        child: Stack(
          children: [
            // Back button
            if (widget.showBackButton)
              Positioned(
                top: 20,
                left: 20,
                child: GestureDetector(
                  onTap:
                      widget.onBackPressed ?? () => Navigator.of(context).pop(),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: kDarkGrey,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: kWhite,
                      size: 24,
                    ),
                  ),
                ),
              ),

            // Center content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress percentage
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: kBlack.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          '${(_progressAnimation.value * 100).toInt()}%',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? kWhite : kDarkGrey,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Progress bar
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: 12,
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Stack(
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width *
                                  0.7 *
                                  _progressAnimation.value,
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8FD14F),
                                    Color(0xFF7BC84A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8FD14F)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Loading text
                  Text(
                    widget.loadingText ?? "Loading",
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: getPercentageWidth(7, context),
                      color: isDarkMode ? kWhite : kDarkGrey,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Please wait text
                  Text(
                    "Please Wait...",
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: kLightGrey,
                    ),
                  ),
                ],
              ),
            ),

            // Sparkle icon
            Positioned(
              bottom: 40,
              right: 20,
              child: AnimatedBuilder(
                animation: _sparkleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.8 + (_sparkleAnimation.value * 0.2),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: kDarkGrey,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Transform.rotate(
                        angle: _sparkleAnimation.value * 2 * 3.14159,
                        child: const Icon(
                          Icons.auto_awesome,
                          color: kWhite,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
