import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../service/plant_detection_service.dart';

class RainbowTrackerWidget extends StatefulWidget {
  final DateTime weekStart;
  final VoidCallback? onTap;

  const RainbowTrackerWidget({
    super.key,
    required this.weekStart,
    this.onTap,
  });

  @override
  State<RainbowTrackerWidget> createState() => _RainbowTrackerWidgetState();
}

class _RainbowTrackerWidgetState extends State<RainbowTrackerWidget> {
  final plantDetectionService = PlantDetectionService.instance;
  PlantDiversityScore? _diversityScore;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlantData();
  }

  Future<void> _loadPlantData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = userService.userId ?? '';
      if (userId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final score = await plantDetectionService.getPlantDiversityScore(
        userId,
        widget.weekStart,
      );
      if (mounted) {
        setState(() {
          _diversityScore = score;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading plant data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getLevelName(int level) {
    switch (level) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Healthy';
      case 3:
        return 'Gut Hero';
      default:
        return 'Getting Started';
    }
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 1:
        return kGreen;
      case 2:
        return kBlue;
      case 3:
        return kAccent;
      default:
        return kLightGrey;
    }
  }

  String _getCategoryName(PlantCategory category) {
    switch (category) {
      case PlantCategory.vegetable:
        return 'Vegetables';
      case PlantCategory.fruit:
        return 'Fruits';
      case PlantCategory.grain:
        return 'Grains';
      case PlantCategory.legume:
        return 'Legumes';
      case PlantCategory.nutSeed:
        return 'Nuts & Seeds';
      case PlantCategory.herbSpice:
        return 'Herbs & Spices';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
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
        child: Center(
          child: CircularProgressIndicator(color: kAccent),
        ),
      );
    }

    final score = _diversityScore;
    if (score == null) {
      return const SizedBox.shrink();
    }

    final level = score.level;
    final uniquePlants = score.uniquePlants;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
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
                      Icons.eco,
                      color: kAccent,
                      size: getIconScale(5, context),
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    Text(
                      'Rainbow Tracker',
                      style: textTheme.titleLarge?.copyWith(
                        fontSize: getTextScale(5, context),
                        fontWeight: FontWeight.w600,
                        color: kAccent,
                      ),
                    ),
                  ],
                ),
                if (level > 0)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(2, context),
                      vertical: getPercentageHeight(0.5, context),
                    ),
                    decoration: BoxDecoration(
                      color: _getLevelColor(level).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getLevelName(level),
                      style: textTheme.bodySmall?.copyWith(
                        color: _getLevelColor(level),
                        fontWeight: FontWeight.w600,
                        fontSize: getTextScale(2.5, context),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: getPercentageHeight(2, context)),

            // Plant Count Display
            Row(
              children: [
                // Large Count Number
                Container(
                  width: getPercentageWidth(20, context),
                  height: getPercentageWidth(20, context),
                  decoration: BoxDecoration(
                    color: _getLevelColor(level > 0 ? level : 1)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getLevelColor(level > 0 ? level : 1),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$uniquePlants',
                      style: textTheme.headlineLarge?.copyWith(
                        fontSize: getTextScale(10, context),
                        fontWeight: FontWeight.bold,
                        color: _getLevelColor(level > 0 ? level : 1),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: getPercentageWidth(3, context)),

                // Progress Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unique Plants This Week',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? kWhite : kBlack,
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(0.5, context)),
                      if (level < 3)
                        Text(
                          '${(30 - uniquePlants).toString()} more to reach Gut Hero!',
                          style: textTheme.bodySmall?.copyWith(
                            color: isDarkMode ? kLightGrey : kDarkGrey,
                            fontSize: getTextScale(3, context),
                          ),
                        )
                      else
                        Text(
                          '🎉 You\'ve reached Gut Hero level!',
                          style: textTheme.bodySmall?.copyWith(
                            color: kAccent,
                            fontSize: getTextScale(3, context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      SizedBox(height: getPercentageHeight(1, context)),
                      // Category breakdown preview
                      if (score.categoryBreakdown.isNotEmpty)
                        Wrap(
                          spacing: getPercentageWidth(1, context),
                          runSpacing: getPercentageHeight(0.5, context),
                          children: score.categoryBreakdown.entries
                              .take(4)
                              .map((entry) {
                            // Get display name for the category
                            final categoryName = _getCategoryName(entry.key);
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: getPercentageWidth(1.5, context),
                                vertical: getPercentageHeight(0.3, context),
                              ),
                              decoration: BoxDecoration(
                                color: kAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$categoryName: ${entry.value}',
                                style: textTheme.bodySmall?.copyWith(
                                  fontSize: getTextScale(2.5, context),
                                  color: kAccent,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Tap to expand hint (only show if there are plants)
            if (widget.onTap != null && uniquePlants > 0) ...[
              SizedBox(height: getPercentageHeight(1, context)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    size: getIconScale(3, context),
                    color: kAccent.withValues(alpha: 0.7),
                  ),
                  SizedBox(width: getPercentageWidth(1, context)),
                  Text(
                    'Tap to see full details',
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: getTextScale(2.5, context),
                      color: kAccent.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
