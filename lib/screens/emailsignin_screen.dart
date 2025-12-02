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
    final isDarkMode = getThemeProvider(context).isDarkMode;
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
        child: SafeArea(
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
  final TextEditingController resetPasswordEmailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    resetPasswordEmailController.dispose();
    super.dispose();
  }

  bool remember = false;

  // Email validation regex
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _handleLogin() {
    _performLogin();
  }

  Future<void> _performLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    // Validate email format
    if (email.isEmpty) {
      showTastySnackbar(
        'Error',
        'Please enter your email address',
        context,
      );
      return;
    }

    if (!_isValidEmail(email)) {
      showTastySnackbar(
        'Error',
        'Please enter a valid email address',
        context,
      );
      return;
    }

    if (password.isEmpty) {
      showTastySnackbar(
        'Error',
        'Please enter your password',
        context,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await authController.loginUser(context, email, password);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
            noCapitalize: false,
          ),

          SizedBox(height: getPercentageHeight(5, context)),

          //password form
          PasswordField(
            kHint: "Password",
            themeProvider: isDarkMode,
            controller: passwordController,
            noCapitalize: false,
          ),

          SizedBox(height: getPercentageHeight(5, context)),

          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                // Clear the reset password email field when opening dialog
                resetPasswordEmailController.clear();
                // Pre-fill with login email if available
                if (emailController.text.isNotEmpty && _isValidEmail(emailController.text)) {
                  resetPasswordEmailController.text = emailController.text;
                }
                // Show dialog to get email
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
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
                          controller: resetPasswordEmailController,
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
                        onPressed: () {
                          resetPasswordEmailController.clear();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Cancel',
                          style: textTheme.bodyMedium?.copyWith(
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final email = resetPasswordEmailController.text.trim();
                          if (email.isEmpty) {
                            showTastySnackbar(
                              'Error',
                              'Please enter your email address',
                              context,
                            );
                            return;
                          }
                          if (!_isValidEmail(email)) {
                            showTastySnackbar(
                              'Error',
                              'Please enter a valid email address',
                              context,
                            );
                            return;
                          }
                          try {
                            await authController.resetPassword(email);
                            resetPasswordEmailController.clear();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            // Error handling is done in authController
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
            text: _isLoading ? "Logging in..." : "Login",
            onPressed: _isLoading ? () {} : _handleLogin,
            type: AppButtonType.primary,
            width: 100,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}
