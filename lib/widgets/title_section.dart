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
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: textTheme.displaySmall?.copyWith(
                fontSize: getTextScale(6, context),
                fontWeight: FontWeight.w500,
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
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: getTextScale(3, context),
                    color: kAccent,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: getPercentageWidth(4, context),
                  color: kAccent,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
