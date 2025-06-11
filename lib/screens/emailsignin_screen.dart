import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../widgets/form.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';

class EmailSigninScreen extends StatelessWidget {
  const EmailSigninScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const IconCircleButton(),
        ),
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
                SizedBox(height: getPercentageHeight(1, context)),
                Text(
                  "Sign In",
                  style: TextStyle(
                    fontSize: getPercentageWidth(4, context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: getPercentageHeight(2.5, context)),
                Text(
                  getRandomWelcomeMessage(),
                  style: TextStyle(
                    fontSize: getPercentageWidth(3, context),
                    color: kAccent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: getPercentageHeight(2.5, context)),
                SigninForm(),
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

          SizedBox(height: getPercentageHeight(4, context)),

          //password form
          PasswordField(
            kHint: "Password",
            themeProvider: isDarkMode,
            controller: passwordController,
          ),

          SizedBox(height: getPercentageHeight(4, context)),

          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                // Show dialog to get email
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: getPercentageWidth(3.5, context),
                        color: kAccent,
                      ),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Enter your email address and we\'ll send you a link to reset your password.',
                          style: TextStyle(
                            fontSize: getPercentageWidth(3, context),
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                        SafeTextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: TextStyle(
                              fontSize: getPercentageWidth(3.5, context),
                            ),
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
                          style: TextStyle(
                            fontSize: getPercentageWidth(3.3, context),
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
                          style: TextStyle(
                            fontSize: getPercentageWidth(3.5, context),
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
                style: TextStyle(
                  fontSize: getPercentageWidth(3.5, context),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          SizedBox(height: getPercentageHeight(4, context)),

          //Sign in button
          AppButton(
            text: "Sign In",
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
