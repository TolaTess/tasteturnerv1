import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/health_journal_model.dart';
import '../helper/utils.dart';
import '../service/health_journal_service.dart';

class HealthJournalWidget extends StatefulWidget {
  final HealthJournalEntry? journalEntry;
  final String? weekId;
  final String? status;
  final Function(String)? onPreviousWeek;
  final VoidCallback? onNextWeek;

  const HealthJournalWidget({
    super.key,
    this.journalEntry,
    this.weekId,
    this.status,
    this.onPreviousWeek,
    this.onNextWeek,
  });

  @override
  State<HealthJournalWidget> createState() => _HealthJournalWidgetState();
}

class _HealthJournalWidgetState extends State<HealthJournalWidget> {
  bool _isExpanded = false;
  final healthJournalService = HealthJournalService.instance;

  String _formatWeekRange(DateTime start, DateTime end) {
    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d, yyyy');
    return '${startFormat.format(start)} - ${endFormat.format(end)}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return kGreen;
      case 'generating':
        return kOrange;
      case 'pending':
        return kLightGrey;
      default:
        return kLightGrey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Ready';
      case 'generating':
        return 'Cooking...';
      case 'pending':
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    
    final entry = widget.journalEntry;
    final status = widget.status ?? entry?.status ?? 'pending';
    final weekStart = entry?.weekStart;
    final weekEnd = entry?.weekEnd;

    // Show "cooking" state if status is generating or pending
    if (status == 'generating' || status == 'pending') {
      return Container(
        margin: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(2.5, context),
          vertical: getPercentageHeight(1, context),
        ),
        padding: EdgeInsets.all(getPercentageWidth(4, context)),
        decoration: BoxDecoration(
          color: isDarkMode ? kDarkGrey : kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kAccent.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.book,
                      color: kAccent,
                      size: getIconScale(5, context),
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    Text(
                      'Food Health Journal',
                      style: textTheme.titleLarge?.copyWith(
                        fontSize: getTextScale(5, context),
                        fontWeight: FontWeight.w600,
                        color: kAccent,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(0.5, context),
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == 'generating')
                        SizedBox(
                          width: getIconScale(3, context),
                          height: getIconScale(3, context),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _getStatusColor(status),
                          ),
                        ),
                      if (status == 'generating')
                        SizedBox(width: getPercentageWidth(1, context)),
                      Text(
                        _getStatusText(status),
                        style: textTheme.bodySmall?.copyWith(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w600,
                          fontSize: getTextScale(2.5, context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            if (weekStart != null && weekEnd != null)
              Text(
                _formatWeekRange(weekStart, weekEnd),
                style: textTheme.titleMedium?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                  fontWeight: FontWeight.w600,
                ),
              ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              status == 'generating'
                  ? 'This week\'s journal is cooking...\nIt will be ready soon!'
                  : 'This week\'s journal is pending.\nIt will be generated at your scheduled time.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: getTextScale(3.5, context),
                color: isDarkMode ? kLightGrey : kDarkGrey,
                height: 1.5,
              ),
            ),
            // Navigation for previous weeks
            if (widget.onPreviousWeek != null && widget.weekId != null) ...[
              SizedBox(height: getPercentageHeight(2, context)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () async {
                      final previousWeeks = healthJournalService.getPreviousWeeks(1);
                      if (previousWeeks.isNotEmpty) {
                        widget.onPreviousWeek?.call(previousWeeks[0]);
                      } else {
                        // Show feedback if no previous weeks available
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'No previous weeks available',
                              style: textTheme.bodyMedium?.copyWith(
                                color: kWhite,
                              ),
                            ),
                            backgroundColor: kLightGrey,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Icons.chevron_left,
                      color: kAccent,
                      size: getIconScale(5, context),
                    ),
                  ),
                  Text(
                    'View Previous Week',
                    style: textTheme.bodySmall?.copyWith(
                      color: kAccent,
                      fontSize: getTextScale(3, context),
                    ),
                  ),
                  IconButton(
                    onPressed: null, // Disabled - no next week for future
                    icon: Icon(
                      Icons.chevron_right,
                      color: kAccent.withValues(alpha: 0.2),
                      size: getIconScale(5, context),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Show completed journal
    if (entry == null) {
      return const SizedBox.shrink();
    }

    final summary = entry.summary;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2.5, context),
        vertical: getPercentageHeight(1, context),
      ),
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? kWhite.withValues(alpha: 0.1)
                : kDarkGrey.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.book,
                    color: kAccent,
                    size: getIconScale(5, context),
                  ),
                  SizedBox(width: getPercentageWidth(2, context)),
                        Expanded(
                          child: Text(
                    'Food Health Journal',
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: getTextScale(5, context),
                      fontWeight: FontWeight.w600,
                      color: kAccent,
                    ),
                  ),
                        ),
                ],
              ),
                    if (weekStart != null && weekEnd != null) ...[
                      SizedBox(height: getPercentageHeight(0.5, context)),
                      Text(
                        _formatWeekRange(weekStart, weekEnd),
                        style: textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                          fontSize: getTextScale(3, context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Previous week navigation
                  if (widget.onPreviousWeek != null && widget.weekId != null)
                    IconButton(
                      onPressed: () async {
                        final previousWeeks = healthJournalService.getPreviousWeeks(1);
                        if (previousWeeks.isNotEmpty) {
                          widget.onPreviousWeek!(previousWeeks[0]);
                        } else {
                          // Show feedback if no previous weeks available
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No previous weeks available',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: kWhite,
                                ),
                              ),
                              backgroundColor: kLightGrey,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        Icons.chevron_left,
                        color: kAccent,
                        size: getIconScale(5, context),
                      ),
                    ),
                  // Expand/collapse
              IconButton(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: kAccent,
                  size: getIconScale(5, context),
                ),
                  ),
                  // Next week navigation (only if not current week)
                  if (widget.onNextWeek != null)
                    IconButton(
                      onPressed: widget.onNextWeek,
                      icon: Icon(
                        Icons.chevron_right,
                        color: kAccent,
                        size: getIconScale(5, context),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(2, context)),

          // Plant Diversity Section (if available)
          if (entry.plantDiversity != null) ...[
            Container(
              padding: EdgeInsets.all(getPercentageWidth(3, context)),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.eco, color: kAccent, size: getIconScale(4, context)),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Expanded(
                    child: Text(
                      '${entry.plantDiversity!.uniquePlants} unique plants this week',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: getPercentageHeight(2, context)),
          ],

          // Narrative Summary
          Text(
            summary.narrative,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: getTextScale(3.5, context),
              color: isDarkMode ? kLightGrey : kDarkGrey,
              height: 1.5,
            ),
          ),

          if (_isExpanded) ...[
            SizedBox(height: getPercentageHeight(2, context)),

            // Highlights
            if (summary.highlights.isNotEmpty) ...[
              _buildSection(
                context,
                'Highlights',
                Icons.star,
                summary.highlights,
                isDarkMode,
                textTheme,
              ),
              SizedBox(height: getPercentageHeight(2, context)),
            ],

            // Insights
            if (summary.insights.isNotEmpty) ...[
              _buildSection(
                context,
                'Insights',
                Icons.lightbulb,
                summary.insights,
                isDarkMode,
                textTheme,
              ),
              SizedBox(height: getPercentageHeight(2, context)),
            ],

            // Suggestions
            if (summary.suggestions.isNotEmpty) ...[
              _buildSection(
                context,
                'Suggestions for Next Week',
                Icons.tips_and_updates,
                summary.suggestions,
                isDarkMode,
                textTheme,
              ),
            ],
          ] else ...[
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              'Tap to expand for highlights, insights, and suggestions',
              style: textTheme.bodySmall?.copyWith(
                fontSize: getTextScale(3, context),
                color: isDarkMode ? kLightGrey.withValues(alpha: 0.7) : kDarkGrey.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<String> items,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: kAccent,
              size: getIconScale(4.5, context),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontSize: getTextScale(4.5, context),
                fontWeight: FontWeight.w600,
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        ...items.map((item) => Padding(
              padding: EdgeInsets.only(
                left: getPercentageWidth(6, context),
                bottom: getPercentageHeight(1, context),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(
                      top: getPercentageHeight(0.5, context),
                      right: getPercentageWidth(2, context),
                    ),
                    width: getPercentageWidth(1, context),
                    height: getPercentageWidth(1, context),
                    decoration: BoxDecoration(
                      color: kAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: getTextScale(3.5, context),
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

