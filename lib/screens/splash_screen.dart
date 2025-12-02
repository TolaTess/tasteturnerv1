import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/bottom_nav.dart';
import 'signup_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool isUser;
  const SplashScreen({super.key, this.isUser = false});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _zoomAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // duration of 5 seconds
    _controller = AnimationController(
      duration: Duration(seconds: widget.isUser ? 2 : 3),
      vsync: this,
    );

    // finish at 5 it's original size
    _zoomAnimation =
        Tween<double>(begin: 1.0, end: widget.isUser ? 7.0 : 10.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut, // Smooth zoom effect
      ),
    );

    // Define a Tween for the fade effect (fade to white)
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: widget.isUser ? 0.5 : 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn, // Smooth fade effect
      ),
    );

    // Start the animation
    _controller.forward();

    // Add a status listener to navigate to the onboarding screen after the animation finishes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        if (widget.isUser) {
          _navigateToMainApp();
        } else {
          _navigateToOnboarding();
        }
      }
    });
  }

  void _navigateToOnboarding() {
    if (!mounted) return;
    try {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const SignupScreen(),
      ),
    );
    } catch (e) {
      debugPrint('Error navigating to signup: $e');
    }
  }

  void _navigateToMainApp() {
    if (!mounted) return;
    try {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const BottomNavSec(),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to main app: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      body: Container(
       decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDarkMode
                  ? 'assets/images/background/imagedark.jpeg'
                  : 'assets/images/background/imagelight.jpeg',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDarkMode
                  ? Colors.black.withOpacity(0.5) 
                  : Colors.white.withOpacity(0.5),
              isDarkMode ? BlendMode.darken : BlendMode.lighten,
            ),
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: getPercentageWidth(7, context),
                      child: Transform.scale(
                        scale: _zoomAnimation.value,
                        child: Image.asset(
                          'assets/images/tasty/tasty.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      color: isDarkMode ? kDarkGrey : kWhite,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
