import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../themes/theme_provider.dart';

class IconCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isColorChange, isRemoveContainer;
  final Color colorL;
  final Color colorD;

  const IconCircleButton({
    super.key,
    this.icon = Icons.arrow_back_ios,
    this.size = kIconSizeMedium,
    this.isColorChange = false,
    this.isRemoveContainer = false,
    this.colorL = kBlack,
    this.colorD = kWhite,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final containerSize = size * 1.8;

    return isRemoveContainer
        ? Icon(icon,
            size: size,
            color: isColorChange
                ? kAccent.withOpacity(kOpacity)
                : themeProvider.isDarkMode
                    ? colorD
                    : colorL)
        : Container(
            height: containerSize,
            width: containerSize,
            margin: const EdgeInsets.only(left: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kAccent.withOpacity(kMidOpacity)
            ),
            child: Icon(icon,
                size: size,
                color: themeProvider.isDarkMode
                        ? colorD
                        : colorL),
          );
  }
}
