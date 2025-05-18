import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/form.dart';
import '../widgets/primary_button.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailSignupScreen extends StatefulWidget {
  const EmailSignupScreen({
    super.key,
  });

  @override
  State<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends State<EmailSignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: SizedBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Text(
                  "Sign Up",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Text(
                  "Save delicious recipes and get personilized content.",
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SignUpForm(
                emailController: emailController,
                passwordController: passwordController,
                confirmPasswordController: confirmPasswordController,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//sign up form widget

class SignUpForm extends StatefulWidget {
  const SignUpForm(
      {super.key,
      required this.emailController,
      required this.passwordController,
      required this.confirmPasswordController});

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  bool remember1 = false;
  bool remember2 = false;
  bool showTermsError = false;
  bool showPasswordError = false;

  void _handleSignUp() {
    setState(() {
      showTermsError = !remember2;
      showPasswordError = widget.passwordController.text !=
          widget.confirmPasswordController.text;
    });

    if (!remember2 || showPasswordError) {
      return;
    }

    authController.registerUser(
        context, widget.emailController.text, widget.passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email form field
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: EmailField(
              kHint: "Your Email",
              themeProvider: isDarkMode,
              controller: widget.emailController,
            ),
          ),
          const SizedBox(height: 40),

          // Password form field
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: PasswordField(
              kHint: "Password",
              themeProvider: isDarkMode,
              controller: widget.passwordController,
            ),
          ),
          const SizedBox(height: 40),

          // Password form field
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PasswordField(
                  kHint: "Confirm Password",
                  themeProvider: isDarkMode,
                  controller: widget.confirmPasswordController,
                ),
                if (showPasswordError)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Passwords do not match",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          //TOR
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Theme(
                    data: Theme.of(context).copyWith(
                      unselectedWidgetColor:
                          isDarkMode ? kPrimaryColor : kBlack,
                    ),
                    child: Checkbox(
                        value: remember2,
                        activeColor: kAccent,
                        onChanged: (value) {
                          setState(() {
                            remember2 = value!;
                            if (remember2) {
                              showTermsError = false;
                            }
                          });
                        }),
                  ),
                  Flexible(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TermsOfServiceScreen(),
                          ),
                        );
                      },
                      child: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: "I agree to "),
                            TextSpan(
                              text: "term of service and privacy policy",
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showTermsError)
                const Padding(
                  padding: EdgeInsets.only(left: 12.0, top: 4.0),
                  child: Text(
                    "Please accept the terms and conditions to continue",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          //Sign up button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: AppButton(
              text: "Sign Up",
              onPressed: _handleSignUp,
              type: AppButtonType.primary,
              width: 100,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "Terms of Service",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kAccent),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Text(
                "Welcome to our $appName. \n \nBy using this application, you agree to the following terms:",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 16),
            Text(
                "1. The nutritional information provided is for informational purposes only and should not replace professional medical advice."),
            SizedBox(height: 8),
            Text(
                "2. AI generated content is not 100% accurate and should not be used as a substitute for professional medical advice."),
            SizedBox(height: 8),
            Text(
                "3. We strive for accuracy but cannot guarantee that all nutritional data is 100% accurate."),
            SizedBox(height: 8),
            Text(
                "4. Your personal data will be handled according to our Privacy Policy and will not be shared with third parties without your consent."),
            SizedBox(height: 8),
            Text(
                "5. You are responsible for maintaining the confidentiality of your account information."),
            SizedBox(height: 8),
            Text(
                "6. We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of any changes."),
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Last updated: 2025",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                SizedBox(height: 16),
                Center(
                  child: InkWell(
                    onTap: () async {
                      final Uri url =
                          Uri.parse('https://tasteturner.com/privacy');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    child: const Text(
                      'View Privacy Policy',
                      style: TextStyle(
                        color: kAccentLight,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
