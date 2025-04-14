import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/form.dart';
import '../widgets/primary_button.dart';

class EmailSignupScreen extends StatefulWidget {
  const EmailSignupScreen({
    super.key,
  });

  @override
  State<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends State<EmailSignupScreen> {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    userNameController.dispose();
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
                userNameController: userNameController,
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
      required this.userNameController,
      required this.emailController,
      required this.passwordController,
      required this.confirmPasswordController});

  final TextEditingController userNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  bool remember1 = false;
  bool remember2 = false;
  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name form field
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: FirstNameField(
              kHint: 'Your Username',
              themeProvider: isDarkMode,
              controller: widget.userNameController,
            ),
          ),
          const SizedBox(height: 40),

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
            child: PasswordField(
              kHint: "Confirm Password",
              themeProvider: isDarkMode,
              controller: widget.confirmPasswordController,
            ),
          ),
          const SizedBox(height: 40),

          //TOR
          Row(
            children: [
              Theme(
                data: Theme.of(context).copyWith(
                  unselectedWidgetColor: isDarkMode ? kPrimaryColor : kBlack,
                ),
                child: Checkbox(
                    value: remember2,
                    activeColor: kAccent,
                    onChanged: (value) {
                      setState(() {
                        remember2 = value!;
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
          const SizedBox(height: 24),

          //Sign up button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: PrimaryButton(
              text: "Sign Up",
              press: () => authController.registerUser(
                  context,
                  widget.userNameController.text,
                  widget.emailController.text,
                  widget.passwordController.text),
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
      body: const SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Terms of Service",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "Welcome to our $appName. By using this application, you agree to the following terms:",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
                "1. The nutritional information provided is for informational purposes only and should not replace professional medical advice."),
            SizedBox(height: 8),
            Text(
                "2. We strive for accuracy but cannot guarantee that all nutritional data is 100% accurate."),
            SizedBox(height: 8),
            Text(
                "3. Your personal data will be handled according to our Privacy Policy and will not be shared with third parties without your consent."),
            SizedBox(height: 8),
            Text(
                "4. You are responsible for maintaining the confidentiality of your account information."),
            SizedBox(height: 8),
            Text(
                "5. We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of any changes."),
            SizedBox(height: 16),
            Text(
              "Last updated: 2025",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
