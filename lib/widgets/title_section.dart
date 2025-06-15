import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';
import 'date_widget.dart';

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
      padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: getTextScale(4, context),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(
            width: getPercentageWidth(0.6, context),
          ),
          InkWell(
            onTap: press,
            child: Row(
              children: [
                Text(
                  more,
                  style: TextStyle(
                    fontSize: getTextScale(3, context),
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
