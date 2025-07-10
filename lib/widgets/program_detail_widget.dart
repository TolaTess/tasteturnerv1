import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

class ProgramDetailWidget extends StatefulWidget {
  final Map<String, dynamic> program;
  final VoidCallback? onJoinProgram;

  const ProgramDetailWidget({
    super.key,
    required this.program,
    this.onJoinProgram,
  });

  @override
  State<ProgramDetailWidget> createState() => _ProgramDetailWidgetState();
}

class _ProgramDetailWidgetState extends State<ProgramDetailWidget> {
  bool _showFullDescription = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: getPercentageHeight(85, context),
          maxWidth: getPercentageWidth(90, context),
        ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with program name and close button
            _buildHeader(context, textTheme, isDarkMode),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(getPercentageWidth(5, context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    if (widget.program['description'] != null)
                      _buildDescriptionSection(context, textTheme, isDarkMode),

                    SizedBox(height: getPercentageHeight(2, context)),

                    // Duration Section
                    if (widget.program['duration'] != null)
                      _buildDurationSection(context, textTheme, isDarkMode),

                    SizedBox(height: getPercentageHeight(2, context)),

                    // Goals Section
                    if (widget.program['goals'] != null)
                      _buildGoalsSection(context, textTheme, isDarkMode),

                    SizedBox(height: getPercentageHeight(2, context)),

                    // Guidelines Section
                    if (widget.program['guidelines'] != null)
                      _buildGuidelinesSection(context, textTheme, isDarkMode),

                    SizedBox(height: getPercentageHeight(2, context)),

                    // Tips Section
                    if (widget.program['tips'] != null)
                      _buildTipsSection(context, textTheme, isDarkMode),

                    SizedBox(height: getPercentageHeight(1.5, context)),
                  ],
                ),
              ),
            ),

            // Action buttons
            _buildActionButtons(context, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(getPercentageWidth(5, context)),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.program['name'] ?? 'Program',
              style: textTheme.displayMedium?.copyWith(
                fontSize: getTextScale(5, context),
                color: kAccent,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.close,
                color: kAccent,
                size: getIconScale(5, context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    final description =
        widget.program['description'] ?? 'No description available';
    final firstSentenceEnd = description.indexOf('.');
    final displayText = _showFullDescription
        ? description
        : (firstSentenceEnd > 0
            ? description.substring(0, firstSentenceEnd + 1)
            : description);
    final hasMoreText =
        firstSentenceEnd > 0 && firstSentenceEnd < description.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: textTheme.titleMedium?.copyWith(
            color: kAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(getPercentageWidth(4, context)),
          decoration: BoxDecoration(
            color: isDarkMode
                ? kLightGrey.withValues(alpha: 0.1)
                : kLightGrey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayText,
                style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  height: 1.5,
                ),
              ),
              if (hasMoreText)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showFullDescription = !_showFullDescription;
                    });
                  },
                  child: Padding(
                    padding:
                        EdgeInsets.only(top: getPercentageHeight(1, context)),
                    child: Text(
                      _showFullDescription ? 'See less' : 'See more',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.schedule,
              color: kAccent,
              size: getIconScale(4.5, context),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              'Duration',
              style: textTheme.titleMedium?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(getPercentageWidth(4, context)),
          decoration: BoxDecoration(
            color: isDarkMode
                ? kLightGrey.withValues(alpha: 0.1)
                : kLightGrey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.program['duration'] ?? 'Not specified',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? kWhite : kDarkGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    final goals = List<String>.from(widget.program['goals'] ?? []);
    if (goals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flag,
              color: kAccent,
              size: getIconScale(4.5, context),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              'Goals',
              style: textTheme.titleMedium?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Wrap(
          spacing: getPercentageWidth(2, context),
          runSpacing: getPercentageHeight(1, context),
          children: goals.map((goal) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(3, context),
                vertical: getPercentageHeight(0.8, context),
              ),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Text(
                goal,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGuidelinesSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    final guidelines = List<String>.from(widget.program['guidelines'] ?? []);
    if (guidelines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.checklist,
              color: kAccent,
              size: getIconScale(4.5, context),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              'Guidelines',
              style: textTheme.titleMedium?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(getPercentageWidth(4, context)),
          decoration: BoxDecoration(
            color: isDarkMode
                ? kLightGrey.withValues(alpha: 0.1)
                : kLightGrey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: guidelines.map((guideline) {
              return Padding(
                padding:
                    EdgeInsets.only(bottom: getPercentageHeight(0.8, context)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      size: getIconScale(2, context),
                      color: kAccent,
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    Expanded(
                      child: Text(
                        guideline,
                        style: textTheme.bodyMedium?.copyWith(
                          color: isDarkMode ? kWhite : kDarkGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    final tips = List<String>.from(widget.program['tips'] ?? []);
    if (tips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lightbulb,
              color: kAccent,
              size: getIconScale(4.5, context),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              'Tips',
              style: textTheme.titleMedium?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Wrap(
          spacing: getPercentageWidth(2, context),
          runSpacing: getPercentageHeight(1, context),
          children: tips.map((tip) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(3, context),
                vertical: getPercentageHeight(0.8, context),
              ),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Text(
                tip,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(getPercentageWidth(5, context)),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: getPercentageHeight(1.5, context),
                ),
              ),
              child: Text(
                'Cancel',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: getPercentageWidth(3, context)),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, 'joined');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: kWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: getPercentageHeight(1.5, context),
                ),
              ),
              child: Text(
                'Join Program',
                style: textTheme.bodyMedium?.copyWith(
                  color: kWhite,
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
