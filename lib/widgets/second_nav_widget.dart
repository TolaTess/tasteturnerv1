import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:tasteturner/helper/utils.dart';

import '../constants.dart';

class SecondNavWidget extends StatelessWidget {
  final String icon;
  final Color color;
  final String label;
  final Widget destinationScreen;
  final bool isDarkMode;

  const SecondNavWidget({
    Key? key,
    required this.icon,
    required this.color,
    required this.label,
    required this.destinationScreen,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationScreen),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: getPercentageWidth(10.5, context),
            height: getPercentageWidth(10.5, context),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.4), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(
                icon,
                height: getIconScale(5, context),
                width: getIconScale(5, context),
                colorFilter:
                    ColorFilter.mode(isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn),
              ),
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
