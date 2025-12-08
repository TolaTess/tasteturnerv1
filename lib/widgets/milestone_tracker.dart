import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../tabs_screen/program_screen.dart';
import 'bottom_nav.dart';

class MilestonesTracker extends StatelessWidget {
  final int ongoingPrograms;
  final VoidCallback? onJoinProgram;

  const MilestonesTracker({
    Key? key,
    required this.ongoingPrograms,
    this.onJoinProgram,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: ongoingPrograms > 0
          ? getPercentageHeight(5, context)
          : getPercentageHeight(5, context),
      margin: EdgeInsets.symmetric(horizontal: getPercentageWidth(4, context)),
      padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: isDarkMode
            ? kDarkGrey.withValues(alpha: 0.5)
            : kAccentLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status Icon
          Icon(
            ongoingPrograms > 0 ? Icons.trending_up : Icons.info_outline,
            size: 12,
            color: ongoingPrograms > 0 ? kAccent : kAccentLight.withValues(alpha: 0.3),
          ),
          SizedBox(width: getPercentageWidth(2, context)),

          // Status Text
          Expanded(
            child: Text(
              ongoingPrograms > 0
                  ? '$ongoingPrograms program${ongoingPrograms > 1 ? 's' : ''} ongoing'
                  : 'No active programs',
              style: textTheme.bodyMedium?.copyWith(
                color: isDarkMode
                      ? kWhite.withValues(alpha: 0.8)
                    : kDarkGrey.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Call to Action
          GestureDetector(
            onTap: () {
              if (onJoinProgram != null) {
                onJoinProgram!();
              } else if (ongoingPrograms == 0) {
                // Navigate to program screen when no active programs
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const BottomNavSec(
                            selectedIndex: 1)));
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context),
                  vertical: getPercentageHeight(1, context)),
              decoration: BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ongoingPrograms > 0 ? 'View' : 'Add Menu',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
