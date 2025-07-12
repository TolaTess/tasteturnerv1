import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/form.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailSignupScreen extends StatefulWidget {
  final String welcomeMessage;
  const EmailSignupScreen({
    super.key,
    required this.welcomeMessage,
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Sign Up",
          style: textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: true,
        backgroundColor: kAccent,
        toolbarHeight: getPercentageHeight(10, context),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: getPercentageHeight(2, context)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(5, context),
                ),
                child: Text(
                  widget.welcomeMessage,
                  style: textTheme.bodyMedium?.copyWith(
                    color: kAccent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              SizedBox(height: getPercentageHeight(2.5, context)),
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
    final textTheme = Theme.of(context).textTheme;
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email form field
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(5, context),
            ),
            child: EmailField(
              kHint: "Your Email",
              themeProvider: isDarkMode,
              controller: widget.emailController,
            ),
          ),
          SizedBox(height: getPercentageHeight(5, context)),

          // Password form field
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(5, context),
            ),
            child: PasswordField(
              kHint: "Password",
              themeProvider: isDarkMode,
              controller: widget.passwordController,
            ),
          ),
          SizedBox(height: getPercentageHeight(5, context)),

          // Password form field
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(5, context),
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
                  Padding(
                    padding:
                        EdgeInsets.only(top: getPercentageHeight(1, context)),
                    child: Text(
                      "Passwords do not match",
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: getPercentageHeight(5, context)),

          //TOR
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: "I agree to ",
                              style: textTheme.bodyMedium?.copyWith(),
                            ),
                            TextSpan(
                              text: "term of service and privacy policy",
                              style: textTheme.bodyMedium?.copyWith(
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
                Padding(
                  padding: EdgeInsets.only(
                      left: getPercentageWidth(3, context),
                      top: getPercentageHeight(1, context)),
                  child: Text(
                    "Please accept the terms and conditions to continue",
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: getPercentageHeight(2.5, context)),

          //Sign up button
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(5, context),
            ),
            child: AppButton(
              text: "Sign Up",
              onPressed: _handleSignUp,
              type: AppButtonType.primary,
              width: 100,
            ),
          ),

          SizedBox(height: getPercentageHeight(2, context)),
        ],
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Get.back(),
          child: const IconCircleButton(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "Terms of Service",
                style: textTheme.displaySmall
                    ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: kAccent,
                        fontSize: getTextScale(7, context)),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Welcome to our $appName.",
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall?.copyWith(),
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),
                  Text(
                    textAlign: TextAlign.center,
                    "By using this application, you agree to the following terms:",
                    style: textTheme.titleMedium?.copyWith(),
                  ),
                ],
              ),
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Text(
              "1. The nutritional information provided is for informational purposes only and should not replace professional medical advice.",
              style: textTheme.bodyMedium?.copyWith(),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              "2. AI generated content is not 100% accurate and should not be used as a substitute for professional medical advice.",
              style: textTheme.bodyMedium?.copyWith(),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              "3. We strive for accuracy but cannot guarantee that all nutritional data is 100% accurate.",
              style: textTheme.bodyMedium?.copyWith(),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              "4. Your personal data will be handled according to our Privacy Policy and will not be shared with third parties without your consent.",
              style: textTheme.bodyMedium?.copyWith(),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              "5. You are responsible for maintaining the confidentiality of your account information.",
              style: textTheme.bodyMedium?.copyWith(),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              "6. We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of any changes.",
              style: textTheme.bodyMedium?.copyWith(),
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Last updated: 2025",
                  style: textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                Center(
                  child: InkWell(
                    onTap: () async {
                      final Uri url =
                          Uri.parse('https://tasteturner.com/privacy');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    child: Text(
                      'View Privacy Policy',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kAccentLight,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: getPercentageHeight(5, context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
