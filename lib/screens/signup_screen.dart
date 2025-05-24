import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/primary_button.dart';
import 'emailsignin_screen.dart';
import 'emailsignup_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final List<String> words = ["Plan", "Cook", "Eat", "Taste"];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _index = (_index + 1) % words.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          color: kAccentLight,
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Column(
                children: [
                  const SizedBox(
                    height: 20,
                  ),

                  const Spacer(),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // ✅ Glow Effect (Blur & Shadow)
                      Container(
                        width: getPercentageWidth(45, context),
                        height: getPercentageWidth(45, context),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kWhite.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      // ✅ Actual Image
                      SizedBox(
                        width: 80,
                        child: Image.asset(
                          'assets/images/tasty/tasty.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 800),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: Text(
                              words[_index],
                              key: ValueKey<String>(words[_index]),
                              style: TextStyle(
                                fontSize: getPercentageWidth(5, context),
                                fontWeight: FontWeight.w600,
                                color: kDarkGrey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8), // ✅ Adjust spacing
                        Text(
                          "with Confidence",
                          style: TextStyle(
                            fontSize: getPercentageWidth(5, context),
                            fontWeight: FontWeight.w600,
                            color: kWhite,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // sign up with Apple
                      if (Platform.isIOS)
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                authController.signInWithApple(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: getPercentageWidth(9, context),
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: kWhite,
                                borderRadius: BorderRadius.circular(
                                  50,
                                ),
                              ),
                              child: SvgPicture.asset(
                                "assets/images/svg/apple.svg",
                                height: 24,
                              ),
                            ),
                          ),
                        ),

                      // sign up with Google
                      Expanded(
                        child: InkWell(
                          onTap: () => authController.signInWithGoogle(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(9, context),
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: kDarkGrey,
                              borderRadius: BorderRadius.circular(
                                50,
                              ),
                            ),
                            child: SvgPicture.asset(
                              "assets/images/svg/google.svg",
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  //sign up with email

                  AppButton(
                    text: "Sign Up with email",
                    type: AppButtonType.email,
                    width: 100,
                    icon: Icons.email,
                    borderRadius: 50,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmailSignupScreen(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      //Send user to sign in screen
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const EmailSigninScreen(), // go to sign up screen
                          ),
                        ),
                        child: const Text(
                          "Log in",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 75),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
