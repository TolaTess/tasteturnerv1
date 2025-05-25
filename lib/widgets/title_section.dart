import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';

//title section widget

class TitleSection extends StatelessWidget {
  const TitleSection({
    super.key,
    required this.title,
    required this.press,
    required this.more,
  });

  final String title, more;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: getPercentageWidth(4.5, context),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(
            width: 6,
          ),
          InkWell(
            onTap: press,
            child: Row(
              children: [
                Text(
                  more,
                  style: TextStyle(
                    fontSize: getPercentageWidth(3.5, context),
                    fontWeight: FontWeight.w500,
                    color: themeProvider.isDarkMode
                        ? kDarkModeAccent.withOpacity(0.70)
                        : kDarkGrey.withOpacity(0.70),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: getPercentageWidth(4, context),
                  color: themeProvider.isDarkMode
                      ? kDarkModeAccent.withOpacity(0.70)
                      : kDarkGrey.withOpacity(0.70),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
