import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

/// Compact plant count badge widget
/// Displays the number of unique plants in a visually appealing badge
class PlantCountBadge extends StatelessWidget {
  final int plantCount;
  final double? size;
  final bool showIcon;
  final String screen;

  const PlantCountBadge({
    super.key,
    required this.plantCount,
    this.size,
    this.showIcon = true,
    this.screen = 'home',
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badgeSize = size ?? getIconScale(4, context);

    if (plantCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2.5, context),
        vertical: getPercentageHeight(0.6, context),
      ),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.eco,
              color: kAccent,
              size: badgeSize,
            ),
            SizedBox(width: getPercentageWidth(1, context)),
          ],
          Text(
            screen == 'meal_detail'
                ? '${plantCount}'
                : '$plantCount ${plantCount == 1 ? 'plant' : 'plants'}',
            style: textTheme.bodySmall?.copyWith(
              color: kAccent,
              fontWeight: FontWeight.w600,
              fontSize: getTextScale(2.8, context),
            ),
          ),
        ],
      ),
    );
  }
}

