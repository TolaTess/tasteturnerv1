import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/health_journal_model.dart';
import '../helper/utils.dart';

class HealthJournalWidget extends StatefulWidget {
  final HealthJournalEntry journalEntry;

  const HealthJournalWidget({
    super.key,
    required this.journalEntry,
  });

  @override
  State<HealthJournalWidget> createState() => _HealthJournalWidgetState();
}

class _HealthJournalWidgetState extends State<HealthJournalWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final summary = widget.journalEntry.summary;

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
            ],
          ),
          SizedBox(height: getPercentageHeight(2, context)),

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
                'Suggestions for Tomorrow',
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

