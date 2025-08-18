import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../service/nutrition_controller.dart';

class DailySummaryWidget extends StatefulWidget {
  final DateTime date;
  final bool showPreviousDay;

  const DailySummaryWidget({
    super.key,
    required this.date,
    this.showPreviousDay = false,
  });

  @override
  State<DailySummaryWidget> createState() => _DailySummaryWidgetState();
}

class _DailySummaryWidgetState extends State<DailySummaryWidget> {
  final dailyDataController = Get.find<NutritionController>();
  bool isLoading = true;
  Map<String, dynamic> summaryData = {};
  Map<String, dynamic> goals = {};

  @override
  void initState() {
    super.initState();
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final userId = userService.userId ?? '';
      final dateString = DateFormat('yyyy-MM-dd').format(widget.date);

      // Load daily summary data
      final summaryDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summary')
          .doc(dateString)
          .get();

      if (summaryDoc.exists) {
        summaryData = summaryDoc.data()!;
      }

      // Load user goals
      final user = userService.currentUser.value;
      if (user != null) {
        goals = {
          'calories':
              double.tryParse(user.settings['foodGoal']?.toString() ?? '0') ??
                  0,
          'water': double.tryParse(
                  user.settings['waterIntake']?.toString() ?? '0') ??
              0,
          'steps': double.tryParse(
                  user.settings['targetSteps']?.toString() ?? '0') ??
              0,
        };
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading daily summary: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    if (isLoading) {
      return Container(
        padding: EdgeInsets.all(getPercentageWidth(4, context)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final calories = summaryData['calories'] as int? ?? 0;
    final water = summaryData['water'] as double? ?? 0.0;
    final steps = summaryData['steps'] as double? ?? 0.0;

    final calorieGoal = goals['calories'] ?? 0.0;
    final waterGoal = goals['water'] ?? 0.0;
    final stepsGoal = goals['steps'] ?? 0.0;

    final calorieProgress =
        calorieGoal > 0 ? (calories / calorieGoal).clamp(0.0, 1.0) : 0.0;
    final waterProgress =
        waterGoal > 0 ? (water / waterGoal).clamp(0.0, 1.0) : 0.0;
    final stepsProgress =
        stepsGoal > 0 ? (steps / stepsGoal).clamp(0.0, 1.0) : 0.0;

    final dateText =
        '${getRelativeDayString(widget.date) == 'Today' ? 'Today\'s' : getRelativeDayString(widget.date) == 'Yesterday' ? 'Yesterday\'s' : '${shortMonthName(widget.date.month)} ${widget.date.day}\'s'} Summary';

    return Container(
      margin: EdgeInsets.all(getPercentageWidth(2, context)),
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
              Text(
                dateText,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: getTextScale(5, context),
                  fontWeight: FontWeight.w600,
                  color: kAccent,
                ),
              ),
              Icon(
                Icons.insights,
                color: kAccent,
                size: getIconScale(5, context),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(2, context)),

          // Progress Charts
          _buildProgressCharts(
            context,
            calorieProgress,
            waterProgress,
            stepsProgress,
            calories,
            water,
            steps,
            calorieGoal,
            waterGoal,
            stepsGoal,
          ),

          SizedBox(height: getPercentageHeight(2, context)),

          // Motivational Message
          _buildMotivationalMessage(
            context,
            calorieProgress,
            waterProgress,
            stepsProgress,
          ),

          SizedBox(height: getPercentageHeight(1, context)),

          // Recommendations
          _buildRecommendations(
            context,
            calorieProgress,
            waterProgress,
            stepsProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCharts(
    BuildContext context,
    double calorieProgress,
    double waterProgress,
    double stepsProgress,
    int calories,
    double water,
    double steps,
    double calorieGoal,
    double waterGoal,
    double stepsGoal,
  ) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Calories Chart
        _buildProgressCard(
          context,
          title: 'Calories',
          current: calories.toDouble(),
          goal: calorieGoal,
          progress: calorieProgress,
          icon: Icons.local_fire_department,
          color: kAccent,
          unit: 'cal',
        ),
        SizedBox(height: getPercentageHeight(1.5, context)),

        // Water Chart
        _buildProgressCard(
          context,
          title: 'Water',
          current: water,
          goal: waterGoal,
          progress: waterProgress,
          icon: Icons.water_drop,
          color: kBlue,
          unit: 'ml',
        ),
        SizedBox(height: getPercentageHeight(1.5, context)),

        // Steps Chart
        _buildProgressCard(
          context,
          title: 'Steps',
          current: steps,
          goal: stepsGoal,
          progress: stepsProgress,
          icon: Icons.directions_walk,
          color: kPurple,
          unit: 'steps',
        ),
      ],
    );
  }

  Widget _buildProgressCard(
    BuildContext context, {
    required String title,
    required double current,
    required double goal,
    required double progress,
    required IconData icon,
    required Color color,
    required String unit,
  }) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: isDarkMode
            ? kDarkGrey.withValues(alpha: 0.5)
            : kWhite.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: getIconScale(4, context)),
              SizedBox(width: getPercentageWidth(2, context)),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
              const Spacer(),
              Text(
                '${current.toStringAsFixed(current % 1 == 0 ? 0 : 1)} / ${goal.toStringAsFixed(goal % 1 == 0 ? 0 : 1)} $unit',
                style: textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: getPercentageHeight(1.5, context),
            borderRadius: BorderRadius.circular(8),
          ),
          SizedBox(height: getPercentageHeight(0.5, context)),
          Text(
            '${(progress * 100).round()}% Complete',
            style: textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalMessage(
    BuildContext context,
    double calorieProgress,
    double waterProgress,
    double stepsProgress,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;

    // Calculate overall progress
    final overallProgress =
        (calorieProgress + waterProgress + stepsProgress) / 3;

    String message;
    Color messageColor;
    IconData messageIcon;

    if (overallProgress >= 0.8) {
      message = 'Excellent work! You\'re crushing your goals today! 🎉';
      messageColor = Colors.green;
      messageIcon = Icons.celebration;
    } else if (overallProgress >= 0.6) {
      message = 'Great progress! Keep up the momentum! 💪';
      messageColor = kAccent;
      messageIcon = Icons.thumb_up;
    } else if (overallProgress >= 0.4) {
      message = 'Good start! You\'re on the right track! 🌟';
      messageColor = Colors.orange;
      messageIcon = Icons.star;
    } else {
      message = 'Every step counts! Tomorrow is a new opportunity! 🌅';
      messageColor = Colors.blue;
      messageIcon = Icons.lightbulb;
    }

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: messageColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: messageColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(messageIcon,
              color: messageColor, size: getIconScale(5, context)),
          SizedBox(width: getPercentageWidth(2, context)),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: messageColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(
    BuildContext context,
    double calorieProgress,
    double waterProgress,
    double stepsProgress,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;

    List<String> recommendations = [];

    if (calorieProgress < 0.8) {
      recommendations
          .add('Try adding a healthy snack to reach your calorie goal');
    }
    if (waterProgress < 0.8) {
      recommendations.add('Drink more water throughout the day');
    }
    if (stepsProgress < 0.8) {
      recommendations.add('Take a short walk to boost your step count');
    }

    if (recommendations.isEmpty) {
      recommendations.add('You\'re doing great! Keep up the healthy habits!');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommendations',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: kAccent,
          ),
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        ...recommendations
            .map((rec) => Padding(
                  padding: EdgeInsets.only(
                      bottom: getPercentageHeight(0.5, context)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: kAccent,
                        size: getIconScale(3.5, context),
                      ),
                      SizedBox(width: getPercentageWidth(2, context)),
                      Expanded(
                        child: Text(
                          rec,
                          style: textTheme.bodyMedium?.copyWith(
                            color: isDarkMode ? kWhite : kDarkGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ],
    );
  }
}