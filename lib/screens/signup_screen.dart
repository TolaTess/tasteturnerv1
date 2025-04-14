import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';
import '../helper/utils.dart';
import 'emailsignin_screen.dart';
import '../widgets/email_button.dart';
import 'emailsignup_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final List<String> words = ["Health", "Goals", "Cook"];

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
                              color: kAccent.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      // ✅ Actual Image
                      SizedBox(
                        child: Image.asset(
                          'assets/images/tasty.png',
                          width: getPercentageWidth(30, context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
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
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  20,
                                ),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                words[_index],
                                key: ValueKey<String>(words[_index]),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: kDarkGrey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8), // ✅ Adjust spacing
                        const Text(
                          "with Confidence",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // sign up with google
                      Flexible(
                        child: InkWell(
                          onTap: authController.signInWithGoogle,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(9, context),
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                50,
                              ),
                            ),
                            child: SvgPicture.asset(
                              "assets/images/google.svg",
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                  
                      // sign up with facebook
                      Flexible(
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EmailSignupScreen(),
                            ),
                          ),
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
                            child: const Icon(
                              Icons.email,
                              color: kWhite,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  //sign up with email

                  EmailButton(
                    text: "Already have an account? ",
                    text2: "Log In",
                    press: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmailSigninScreen(),
                      ),
                    ),
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
