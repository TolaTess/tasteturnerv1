import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';

class IconCircleButton extends StatelessWidget {
  final IconData icon;
  final double h;
  final double w;
  final bool isColorChange, isRemoveContainer;
  final Color colorL;
  final Color colorD;

  const IconCircleButton({
    super.key,
    this.icon = Icons.arrow_back_ios,
    this.h = 8,
    this.w = 8,
    this.isColorChange = false,
    this.isRemoveContainer = false,
    this.colorL = kBlack,
    this.colorD = kWhite,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return isRemoveContainer
        ? Icon(icon,
            size: getPercentageWidth(h, context) * 0.6,
            color: isColorChange
                ? kAccent.withValues(alpha: kOpacity)
                : themeProvider.isDarkMode
                    ? colorD
                    : colorL)
        : Container(
            height: MediaQuery.of(context).size.height > 1000
                ? getProportionalHeight(h, context) + 50
                : getProportionalHeight(h, context) + 35,
            width: MediaQuery.of(context).size.height > 1000
                ? getProportionalWidth(w, context) + 50
                : getProportionalWidth(w, context) + 35,
            margin: const EdgeInsets.only(left: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isColorChange
                  ? themeProvider.isDarkMode
                      ? colorD.withValues(alpha: kMidOpacity)
                      : colorL.withValues(alpha: kMidOpacity)
                  : themeProvider.isDarkMode
                      ? colorD.withValues(alpha: kLowOpacity)
                      : colorL.withValues(alpha: kLowOpacity),
            ),
            child: Icon(icon,
                size: getPercentageWidth(h, context) * 0.6,
                color: isColorChange
                    ? kAccent.withValues(alpha: kOpacity)
                    : themeProvider.isDarkMode
                        ? colorD
                        : colorL),
          );
  }
}
