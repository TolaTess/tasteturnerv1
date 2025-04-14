import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../widgets/form.dart';
import '../widgets/primary_button.dart';

class EmailSigninScreen extends StatelessWidget {
  const EmailSigninScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const SizedBox(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              Text(
                "Sign In",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Welcome back! A delectable treat is just a tap away.",
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 24),
              SigninForm(),
            ],
          ),
        ),
      ),
    );
  }
}

class SigninForm extends StatefulWidget {
  const SigninForm({
    super.key,
  });

  @override
  State<SigninForm> createState() => _SigninFormState();
}

class _SigninFormState extends State<SigninForm> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool remember = false;
  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //email form
          EmailField(
            kHint: "Your Email",
            themeProvider: isDarkMode,
            controller: emailController,
          ),

          const SizedBox(height: 40),

          //password form
          PasswordField(
            kHint: "Password",
            themeProvider: isDarkMode,
            controller: passwordController,
          ),

          const SizedBox(height: 40),

          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                // Show dialog to get email
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset Password'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Enter your email address and we\'ll send you a link to reset your password.',
                        ),
                        const SizedBox(height: 16),
                        SafeTextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            hintText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (emailController.text.isNotEmpty) {
                            authController.resetPassword(emailController.text);
                            Navigator.pop(context);
                          } else {
                            Get.snackbar(
                              'Error',
                              'Please enter your email address',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                        },
                        child: const Text('Reset Password'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text(
                "Forgot password?",
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          //Sign in button
          PrimaryButton(
            text: "Sign In",
            press: () => authController.loginUser(
                emailController.text, passwordController.text),
          ),
        ],
      ),
    );
  }
}
