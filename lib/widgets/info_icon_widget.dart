import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

class InfoIconWidget extends StatelessWidget {
  final String title;
  final String description;
  final List<Map<String, dynamic>> details;
  final Color iconColor;
  final String tooltip;

  const InfoIconWidget({
    super.key,
    required this.title,
    required this.description,
    required this.details,
    this.iconColor = kAccent,
    this.tooltip = 'Information',
  });

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _buildInfoDialog(context),
    );
  }

  Widget _buildInfoDialog(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? kDarkGrey : kWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: EdgeInsets.all(getPercentageWidth(6, context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.displaySmall?.copyWith(
                          color: iconColor,
                          fontSize: getTextScale(5, context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: getTextScale(3, context),
                            color: kLightGrey,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: iconColor),
                ),
              ],
            ),

            SizedBox(height: getPercentageHeight(2, context)),

            // Details
            ...details
                .map((detail) => _buildDetailItem(
                      context,
                      detail['icon'] ?? Icons.info_outline,
                      detail['title'] ?? '',
                      detail['description'] ?? '',
                      detail['color'] ?? iconColor,
                      isDarkMode,
                      textTheme,
                    ))
                .toList(),

            SizedBox(height: getPercentageHeight(2, context)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: getPercentageHeight(2, context)),
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(getPercentageWidth(2, context)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: getIconScale(5, context),
            ),
          ),
          SizedBox(width: getPercentageWidth(3, context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    color: isDarkMode ? kWhite : kBlack,
                    fontSize: getTextScale(3.5, context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? kLightGrey : kDarkGrey,
                      fontSize: getTextScale(3, context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showInfoDialog(context),
      icon: Icon(
        Icons.info_outline,
        size: getIconScale(6, context),
        color: iconColor,
      ),
      tooltip: tooltip,
    );
  }
}
