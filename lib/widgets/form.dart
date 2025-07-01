import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';

//you can find all form widget here

class FirstNameField extends StatelessWidget {
  const FirstNameField(
      {super.key,
      required this.kHint,
      required this.themeProvider,
      required this.controller});

  final bool themeProvider;

  final String kHint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SafeTextField(
      controller: controller,
      style: TextStyle(
        color: themeProvider ? kWhite : kBlack,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: themeProvider ? kDarkGrey : kBackgroundColor,
        enabledBorder: underlineInputBorder(),
        focusedBorder: underlineInputBorder(),
        border: underlineInputBorder(),
        labelStyle: TextStyle(
          color: kLightGrey,
          fontSize: getTextScale(3.5, context),
        ),
        labelText: kHint,
        suffixIcon: Icon(
          Icons.person_outline,
          color: themeProvider ? kPrimaryColor : kBlack,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 0,
          vertical: getPercentageHeight(0.5, context),
        ),
        hintStyle: TextStyle(
          fontSize: getTextScale(3.5, context),
        ),
      ),
    );
  }
}

class EmailField extends StatelessWidget {
  const EmailField(
      {super.key,
      required this.kHint,
      required this.themeProvider,
      required this.controller});

  final bool themeProvider;
  final String kHint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {  
    final textTheme = Theme.of(context).textTheme;
    return SafeTextField(
      controller: controller,
      style: textTheme.bodyMedium?.copyWith(
        color: themeProvider ? kWhite : kBlack,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: themeProvider ? kDarkGrey : kBackgroundColor,
        enabledBorder: underlineInputBorder(),
        focusedBorder: underlineInputBorder(),
        border: underlineInputBorder(),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: kLightGrey,
        ),
        labelText: kHint,
        suffixIcon: Icon(
          Icons.email_outlined,
          color: themeProvider ? kWhite : kDarkGrey,
          size: getIconScale(5.5, context),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 0,
          vertical: getPercentageHeight(0.5, context),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField(
      {super.key,
      required this.kHint,
      required this.themeProvider,
      required this.controller});

  final String kHint;
  final bool themeProvider;
  final TextEditingController controller;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _isTextVisible = false;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeTextField(
      controller: widget.controller,
      style: textTheme.bodyMedium?.copyWith(
        color: widget.themeProvider ? kWhite : kBlack,
      ),
      obscureText: !_isTextVisible,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        filled: true,
        fillColor: widget.themeProvider ? kDarkGrey : kBackgroundColor,
        enabledBorder: underlineInputBorder(),
        focusedBorder: underlineInputBorder(),
        border: underlineInputBorder(),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: kLightGrey,
        ),
        labelText: widget.kHint,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 0,
          vertical: getPercentageHeight(0.5, context),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(),
        suffixIcon: IconButton(
          icon: Icon(
            _isTextVisible ? Icons.visibility : Icons.visibility_off,
            color: widget.themeProvider ? kWhite : kDarkGrey,
            size: getIconScale(5.5, context),   
          ),
          onPressed: () {
            setState(() {
              _isTextVisible = !_isTextVisible;
            });
          },
        ),
      ),
    );
  }
}

UnderlineInputBorder underlineInputBorder() {
  return const UnderlineInputBorder(
    borderSide: BorderSide(
      color: Colors.black26,
      width: 1.0,
    ),
  );
}
