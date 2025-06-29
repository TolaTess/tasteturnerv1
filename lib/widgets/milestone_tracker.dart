import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

class MilestonesTracker extends StatelessWidget {
  final List<bool> milestones;
  final String title;
  final String subtitle;

  const MilestonesTracker({
    Key? key,
    required this.milestones,
    this.title = 'Milestones Achieved',
    this.subtitle =
        'Regularly monitor your progress to achieve goals and celebrate your accomplishments along the way.',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(1, context),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kAccentLight.withOpacity(0.2),
            kAccentLight.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(4, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.displayMedium?.copyWith(
                fontSize: getTextScale(4.5, context),
                color: isDarkMode ? kWhite : kBlack,
                fontWeight: FontWeight.w200,
              ),
            ),
            SizedBox(height: getPercentageHeight(0.5, context)),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: getTextScale(3, context),
                color: isDarkMode
                    ? kWhite.withOpacity(0.7)
                    : kBlack.withOpacity(0.7),
              ),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                milestones.length,
                (index) => _buildMilestonePoint(
                  context,
                  isCompleted: milestones[index],
                  isLast: index == milestones.length - 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestonePoint(
    BuildContext context, {
    required bool isCompleted,
    required bool isLast,
  }) {
    return Row(
      children: [
        Container(
          width: getPercentageWidth(6, context),
          height: getPercentageWidth(6, context),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? kAccent : kAccent.withOpacity(0.3),
            border: Border.all(
              color: isCompleted ? kAccent : kAccent.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: isCompleted
              ? Icon(
                  Icons.check,
                  size: getIconScale(4, context),
                  color: kWhite,
                )
              : null,
        ),
        if (!isLast)
          Container(
            width: getPercentageWidth(8, context),
            height: 2,
            color: isCompleted ? kAccent : kAccent.withOpacity(0.3),
          ),
      ],
    );
  }
}
