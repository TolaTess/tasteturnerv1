import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../widgets/form.dart';
import '../widgets/primary_button.dart';

class EmailSigninScreen extends StatelessWidget {
  final String welcomeMessage;
  const EmailSigninScreen({super.key, required this.welcomeMessage});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Sign In",
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
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(5, context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: getPercentageHeight(2.5, context)),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(0.5, context),
                  ),
                  child: Text(
                    welcomeMessage,
                    style: textTheme.bodyMedium?.copyWith(
                      color: kAccent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SigninForm(),
              ],
            ),
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
    final textTheme = Theme.of(context).textTheme;
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: getPercentageHeight(2.5, context)),

          //email form
          EmailField(
            kHint: "Your Email",
            themeProvider: isDarkMode,
            controller: emailController,
          ),

          SizedBox(height: getPercentageHeight(5, context)),

          //password form
          PasswordField(
            kHint: "Password",
            themeProvider: isDarkMode,
            controller: passwordController,
          ),

          SizedBox(height: getPercentageHeight(5, context)),

          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                // Show dialog to get email
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                    title: Text(
                      'Reset Password',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kAccent,
                      ),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Enter your email address and we\'ll send you a link to reset your password.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                        SafeTextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: textTheme.bodyMedium?.copyWith(),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: textTheme.bodyMedium?.copyWith(
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (emailController.text.isNotEmpty) {
                            authController.resetPassword(emailController.text);
                            Navigator.pop(context);
                          } else {
                            showTastySnackbar(
                              'Error',
                              'Please enter your email address',
                              context,
                            );
                          }
                        },
                        child: Text(
                          'Reset Password',
                          style: textTheme.bodyMedium?.copyWith(
                            color: kAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Text(
                "Forgot password?",
                style: textTheme.bodyMedium?.copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          SizedBox(height: getPercentageHeight(5, context)),

          //Sign in button
          AppButton(
            text: "Login",
            onPressed: () => authController.loginUser(
                context, emailController.text, passwordController.text),
            type: AppButtonType.primary,
            width: 100,
          ),
        ],
      ),
    );
  }
}
