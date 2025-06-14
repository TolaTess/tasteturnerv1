import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';
import '../widgets/bottom_nav.dart';
import 'signup_screen.dart';
import '../constants.dart';
import '../service/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

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
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _zoomAnimation = Tween<double>(begin: 1.0, end: 7.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    _routeAfterSplash();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _routeAfterSplash() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    // Use GetX to check auth state and route
    final authController = Get.find<AuthController>();
    final user = authController.currentUser;
    if (user != null) {
      Get.offAll(() => const BottomNavSec());
    } else {
      Get.offAll(() => const SignupScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    print(MediaQuery.of(context).size.height);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: kAccentLight,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: getPercentageWidth(10, context),
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
