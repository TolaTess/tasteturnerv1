import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../constants.dart';
import '../helper/utils.dart';

enum AppButtonType { primary, secondary, follow, email }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final AppButtonType type;
  final bool isLoading;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool outlined;

  const AppButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.color,
    this.textColor,
    this.width = 40,
    this.height,
    this.borderRadius = 12,
    this.outlined = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    Color btnColor;
    Color txtColor;
    Color borderCol;

    switch (type) {
      case AppButtonType.primary:
        btnColor = isDarkMode
            ? kDarkModeAccent.withOpacity(0.50)
            : kAccent.withOpacity(0.50);
        txtColor = isDarkMode ? kWhite : kDarkGrey;
        borderCol = btnColor;
        break;
      case AppButtonType.secondary:
        btnColor = isDarkMode
            ? kDarkModeAccent.withOpacity(0.50)
            : kAccentLight.withOpacity(0.50);
        txtColor = isDarkMode ? kWhite : kDarkGrey;
        borderCol = btnColor;
        break;
      case AppButtonType.follow:
        btnColor = isDarkMode
            ? kLightGrey.withOpacity(0.35)
            : kAccent.withOpacity(kOpacity);
        txtColor = kWhite;
        borderCol = btnColor;
        break;
      case AppButtonType.email:
        btnColor = color ?? kDarkGrey;
        txtColor = kWhite;
        borderCol = btnColor;
        break;
    }

    return SizedBox(
      width: getPercentageWidth(width ?? 20, context),
      height: getPercentageHeight(height ?? 6.5, context),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: outlined ? Colors.transparent : btnColor,
          side: BorderSide(color: borderCol, width: outlined ? 2 : 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const CircularProgressIndicator(color: kAccent)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: txtColor),
                    SizedBox(width: getPercentageWidth(2, context)),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: txtColor,
                      fontWeight: FontWeight.bold,
                      fontSize: getPercentageWidth(4, context),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CustomSuffixIcon extends StatelessWidget {
  const CustomSuffixIcon({
    super.key,
    required this.svgIcon,
  });

  final String svgIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 0, bottom: 20, right: 20),
      child: SvgPicture.asset(
        svgIcon,
        height: 18,
        color: kAccent,
      ),
    );
  }
}
