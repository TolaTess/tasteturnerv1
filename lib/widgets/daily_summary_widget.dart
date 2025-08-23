import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../service/nutrition_controller.dart';
import '../screens/tomorrow_action_items_screen.dart';
import '../service/notification_handler_service.dart';

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
          'protein': double.tryParse(
                  user.settings['proteinGoal']?.toString() ?? '0') ??
              0,
          'carbs':
              double.tryParse(user.settings['carbsGoal']?.toString() ?? '0') ??
                  0,
          'fat':
              double.tryParse(user.settings['fatGoal']?.toString() ?? '0') ?? 0,
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

    // Handle macro data that might be stored as int or double, or might not exist
    final proteinRaw = summaryData['protein'];
    final protein = proteinRaw is int
        ? proteinRaw.toDouble()
        : proteinRaw is double
            ? proteinRaw
            : 0.0;

    final carbsRaw = summaryData['carbs'];
    final carbs = carbsRaw is int
        ? carbsRaw.toDouble()
        : carbsRaw is double
            ? carbsRaw
            : 0.0;

    final fatRaw = summaryData['fat'];
    final fat = fatRaw is int
        ? fatRaw.toDouble()
        : fatRaw is double
            ? fatRaw
            : 0.0;

    final calorieGoal = goals['calories'] ?? 0.0;
    final proteinGoal = goals['protein'] ?? 0.0;
    final carbsGoal = goals['carbs'] ?? 0.0;
    final fatGoal = goals['fat'] ?? 0.0;

    final calorieProgress = calorieGoal > 0
        ? (calories.toDouble() / calorieGoal).clamp(0.0, 1.0)
        : 0.0;
    final proteinProgress =
        proteinGoal > 0 ? (protein / proteinGoal).clamp(0.0, 1.0) : 0.0;
    final carbsProgress =
        carbsGoal > 0 ? (carbs / carbsGoal).clamp(0.0, 1.0) : 0.0;
    final fatProgress = fatGoal > 0 ? (fat / fatGoal).clamp(0.0, 1.0) : 0.0;

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
            proteinProgress,
            carbsProgress,
            fatProgress,
            calories,
            protein,
            carbs,
            fat,
            calorieGoal,
            proteinGoal,
            carbsGoal,
            fatGoal,
          ),

          SizedBox(height: getPercentageHeight(2, context)),

          // Motivational Message
          _buildMotivationalMessage(
            context,
            calorieProgress,
            proteinProgress,
            carbsProgress,
            fatProgress,
            () async {
              // Use the notification handler service to show action items
              try {
                final notificationHandler =
                    Get.find<NotificationHandlerService>();
                await notificationHandler.showTomorrowActionItems(context);
              } catch (e) {
                print('Error showing action items: $e');
                // Fallback to direct navigation if service is not available
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TomorrowActionItemsScreen(
                      todaySummary: summaryData,
                      tomorrowDate: DateFormat('yyyy-MM-dd').format(
                        DateTime.now().add(const Duration(days: 1)),
                      ),
                      hasMealPlan: false,
                      notificationType: 'manual',
                    ),
                  ),
                );
              }
            },
          ),

          SizedBox(height: getPercentageHeight(1, context)),

          // Recommendations
          _buildRecommendations(
            context,
            calorieProgress,
            proteinProgress,
            carbsProgress,
            fatProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCharts(
    BuildContext context,
    double calorieProgress,
    double proteinProgress,
    double carbsProgress,
    double fatProgress,
    int calories,
    double protein,
    double carbs,
    double fat,
    double calorieGoal,
    double proteinGoal,
    double carbsGoal,
    double fatGoal,
  ) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: getPercentageWidth(3, context),
      mainAxisSpacing: getPercentageHeight(2, context),
      childAspectRatio: 1.2,
      children: [
        // Calories Chart
        _buildCircularProgressCard(
          context,
          title: 'Calories',
          current: calories.toDouble(),
          goal: calorieGoal,
          progress: calorieProgress,
          icon: Icons.local_fire_department,
          color: Colors.orange,
          unit: 'cal',
        ),

        // Protein Chart
        _buildCircularProgressCard(
          context,
          title: 'Protein',
          current: protein,
          goal: proteinGoal,
          progress: proteinProgress,
          icon: Icons.fitness_center,
          color: Colors.blue,
          unit: 'g',
        ),

        // Carbs Chart
        _buildCircularProgressCard(
          context,
          title: 'Carbs',
          current: carbs,
          goal: carbsGoal,
          progress: carbsProgress,
          icon: Icons.grain,
          color: Colors.green,
          unit: 'g',
        ),

        // Fat Chart
        _buildCircularProgressCard(
          context,
          title: 'Fat',
          current: fat,
          goal: fatGoal,
          progress: fatProgress,
          icon: Icons.opacity,
          color: Colors.purple,
          unit: 'g',
        ),
      ],
    );
  }

  Widget _buildCircularProgressCard(
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
      padding: EdgeInsets.symmetric(
          vertical: getPercentageHeight(1, context),
          horizontal: getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: isDarkMode
            ? kDarkGrey.withValues(alpha: 0.5)
            : kWhite.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon and Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: getIconScale(4, context)),
              SizedBox(width: getPercentageWidth(1, context)),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),

          // Circular Progress Indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: getPercentageWidth(15, context),
                height: getPercentageWidth(15, context),
                child: CircularProgressIndicator(
                  value: progress,
                  backgroundColor: color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: getPercentageWidth(0.8, context),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(progress * 100).round()}%',
                    style: textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: getPercentageHeight(1, context)),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${current.toStringAsFixed(current % 1 == 0 ? 0 : 1)}',
                style: textTheme.bodySmall?.copyWith(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '/ ${goal.toStringAsFixed(goal % 1 == 0 ? 0 : 1)} $unit',
                style: textTheme.bodySmall?.copyWith(
                  color: isDarkMode
                      ? kWhite.withOpacity(0.7)
                      : kDarkGrey.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalMessage(
    BuildContext context,
    double calorieProgress,
    double proteinProgress,
    double carbsProgress,
    double fatProgress,
    Function() onTap,
  ) {
    final textTheme = Theme.of(context).textTheme;

    // Check if the date is today
    final isToday = DateFormat('yyyy-MM-dd').format(widget.date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Calculate overall progress
    final overallProgress =
        (calorieProgress + proteinProgress + carbsProgress + fatProgress) / 4;

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
      message = isToday
          ? 'Tap to view your action items for tomorrow! 🌅'
          : 'Every step counts! Tomorrow is a new opportunity! 🌅';
      messageColor = Colors.blue;
      messageIcon = Icons.lightbulb;
    }

    return GestureDetector(
      onTap: isToday ? onTap : null, // Only allow tap if it's today
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isToday) ...[
              Icon(
                Icons.touch_app,
                color: messageColor.withValues(alpha: 0.7),
                size: getIconScale(4, context),
              ),
            ] else ...[
              Icon(messageIcon,
                  color: messageColor, size: getIconScale(5, context)),
            ],
            SizedBox(width: getPercentageWidth(2, context)),
            Expanded(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: messageColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Show tap indicator only if it's today and tap is enabled
            if (isToday) ...[
              Icon(
                Icons.touch_app,
                color: messageColor.withValues(alpha: 0.7),
                size: getIconScale(4, context),
              ),
            ] else ...[
              Icon(
                messageIcon,
                color: messageColor,
                size: getIconScale(5, context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(
    BuildContext context,
    double calorieProgress,
    double proteinProgress,
    double carbsProgress,
    double fatProgress,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final dietPreferences =
        userService.currentUser.value?.settings['dietPreference'] ?? {};

    List<String> recommendations = [];
    final isToday = widget.date.isAtSameMomentAs(DateTime.now());
    final isYesterday = widget.date
        .isAtSameMomentAs(DateTime.now().subtract(const Duration(days: 1)));

    // Calorie recommendations with diet preferences
    if (calorieProgress > 1.2) {
      // Significantly over calorie limit
      if (isToday) {
        recommendations.add(
            'You\'ve exceeded your calorie goal today. Consider a lighter dinner or an evening walk to balance it out.');
      } else if (isYesterday) {
        recommendations.add(
            'You exceeded your calorie goal yesterday. Today, try to stay within your limit and add some extra physical activity.');
      } else {
        recommendations.add(
            'You exceeded your calorie goal on this day. For future days, try to plan meals better and include more physical activity.');
      }
    } else if (calorieProgress > 1.0) {
      // Slightly over calorie limit
      if (isToday) {
        recommendations.add(
            'You\'re slightly over your calorie goal. A short walk or light activity can help balance this out.');
      } else {
        recommendations.add(
            'You were slightly over your calorie goal. Consider portion control for similar meals in the future.');
      }
    } else if (calorieProgress < 0.6) {
      // Significantly under calorie limit
      if (dietPreferences.toLowerCase() == 'vegan') {
        recommendations.add(
            'You\'re well below your calorie goal. Try adding healthy vegan snacks like Nuts, Seeds, Avocados, or plant-based protein sources to reach your target.');
      } else if (dietPreferences.toLowerCase() == 'vegetarian') {
        recommendations.add(
            'You\'re well below your calorie goal. Try adding healthy vegetarian snacks like Nuts, Yogurt, Cheese, or Fruits to reach your target.');
      } else if (dietPreferences.toLowerCase() == 'keto') {
        recommendations.add(
            'You\'re well below your calorie goal. Try adding keto-friendly snacks like Nuts, Cheese, Avocados, or Fatty Fish to reach your target.');
      } else if (dietPreferences.toLowerCase() == 'paleo') {
        recommendations.add(
            'You\'re well below your calorie goal. Try adding paleo-friendly snacks like Nuts, Seeds, Fruits, or Lean Meats to reach your target.');
      } else {
        recommendations.add(
            'You\'re well below your calorie goal. Try adding healthy snacks like Nuts, Yogurt, or Fruits to reach your target.');
      }
    } else if (calorieProgress < 0.8) {
      // Slightly under calorie limit
      recommendations.add(
          'You\'re close to your calorie goal. A small healthy snack can help you reach your target.');
    }

    // Macro-specific recommendations with diet preferences
    if (proteinProgress < 0.7) {
      if (dietPreferences.toLowerCase() == 'vegan') {
        recommendations.add(
            'Increase protein intake with plant-based sources like Beans, Lentils, Quinoa, Tofu, Tempeh, or Nutritional Yeast.');
      } else if (dietPreferences.toLowerCase() == 'vegetarian') {
        recommendations.add(
            'Increase protein intake with Eggs, Dairy, Legumes, Quinoa, or Greek Yogurt.');
      } else if (dietPreferences.toLowerCase() == 'keto') {
        recommendations.add(
            'Increase protein intake with Fatty Fish, Eggs, Cheese, or Lean Meats while keeping carbs low.');
      } else if (dietPreferences.toLowerCase() == 'paleo') {
        recommendations.add(
            'Increase protein intake with Lean Meats, Fish, Eggs, or Nuts and Seeds.');
      } else if (dietPreferences.toLowerCase() == 'carnivore') {
        recommendations
            .add('Increase protein intake with Meats, Fish, Eggs, and Dairy.');
      } else {
        recommendations.add(
            'Increase protein intake with Lean Meats, Fish, Eggs, Legumes, or Greek Yogurt.');
      }
    } else if (proteinProgress > 1.3) {
      recommendations.add(
          'Your protein intake is quite high. Consider balancing with more carbs or fats for variety.');
    }

    if (carbsProgress < 0.7) {
      if (dietPreferences.toLowerCase() == 'vegan') {
        recommendations.add(
            'Add complex carbohydrates like Whole Grains, Quinoa, Sweet Potatoes, or Legumes to your meals.');
      } else if (dietPreferences.toLowerCase() == 'vegetarian') {
        recommendations.add(
            'Add complex carbohydrates like Whole Grains, Sweet Potatoes, Quinoa, or Fruits to your meals.');
      } else if (dietPreferences.toLowerCase() == 'keto') {
        recommendations.add(
            'For Keto, focus on low-carb vegetables like Leafy Greens, Broccoli, and Cauliflower instead of high-carb foods.');
      } else if (dietPreferences.toLowerCase() == 'paleo') {
        recommendations.add(
            'Add Paleo-friendly carbohydrates like Sweet Potatoes, Fruits, or Root Vegetables to your meals.');
      } else if (dietPreferences.toLowerCase() == 'carnivore') {
        recommendations.add('For Carnivores, no carbs are allowed.');
      } else {
        recommendations.add(
            'Add complex carbohydrates like Whole Grains, Sweet Potatoes, or Quinoa to your meals.');
      }
    } else if (carbsProgress > 1.3) {
      if (dietPreferences.toLowerCase() == 'keto') {
        recommendations.add(
            'Your carb intake is high for Keto. Focus on reducing carbs and increasing healthy fats and protein for better satiety.');
      } else {
        recommendations.add(
            'Your carb intake is high. Consider reducing refined carbs and adding more protein or healthy fats for better satiety.');
      }
    }

    if (fatProgress < 0.7) {
      if (dietPreferences.toLowerCase() == 'vegan') {
        recommendations.add(
            'Include healthy fats from Avocados, Nuts, Seeds, Olive Oil, or Coconut Oil in your diet.');
      } else if (dietPreferences.toLowerCase() == 'vegetarian') {
        recommendations.add(
            'Include healthy fats from Avocados, Nuts, Olive Oil, Dairy, or Eggs in your diet.');
      } else if (dietPreferences.toLowerCase() == 'keto') {
        recommendations.add(
            'Increase healthy fats with Avocados, Nuts, Olive Oil, Coconut Oil, or Fatty Fish for keto.');
      } else if (dietPreferences.toLowerCase() == 'paleo') {
        recommendations.add(
            'Include healthy fats from Avocados, Nuts, Olive Oil, Coconut Oil, or Fatty Fish in your diet.');
      } else if (dietPreferences.toLowerCase() == 'carnivore') {
        recommendations
            .add('Include healthy fats from Meats, Butter, Ghee, and Dairy.');
      } else {
        recommendations.add(
            'Include healthy fats from Avocados, Nuts, Olive Oil, or Fatty Fish in your diet.');
      }
    } else if (fatProgress > 1.3) {
      if (dietPreferences.toLowerCase() == 'keto') {
        recommendations.add(
            'Your fat intake is appropriate for Keto, but ensure you\'re getting enough protein too.');
      } else {
        recommendations.add(
            'Your fat intake is high. Focus on leaner protein sources and reduce added oils for better satiety.');
      }
    }

    // Balance recommendations with diet context
    if (proteinProgress > 0.9 &&
        carbsProgress > 0.9 &&
        fatProgress > 0.9 &&
        calorieProgress > 0.9 &&
        calorieProgress < 1.1) {
      recommendations.add(
          'Excellent balance! Your macro distribution is well-aligned with your goals and dietary preferences.');
    } else if (proteinProgress < 0.6 && carbsProgress > 1.2) {
      if (dietPreferences.toLowerCase() == 'keto') {
        recommendations.add(
            'For Keto, consider reducing carbs further and increasing healthy fats for better ketosis.');
      } else {
        recommendations.add(
            'Consider reducing carbs and increasing protein for better muscle support and satiety.');
      }
    } else if (fatProgress > 1.2 && proteinProgress < 0.7) {
      if (dietPreferences.toLowerCase() == 'keto') {
        recommendations.add(
            'For Keto, ensure you\'re getting enough protein while maintaining high fat intake.');
      } else {
        recommendations.add(
            'Try reducing fats and increasing protein for better nutrient balance.');
      }
    }

    // Activity recommendations based on calorie intake
    if (calorieProgress > 1.1) {
      if (isToday) {
        recommendations.add(
            'Consider adding 15-30 minutes of moderate exercise today to help balance your calorie intake.');
      } else {
        recommendations.add(
            'For days when you exceed calories, plan for extra physical activity to maintain balance.');
      }
    }

    // Hydration reminder
    if (calorieProgress > 1.0) {
      recommendations.add(
          'Stay well-hydrated, especially if you\'re active. Aim for 8-10 glasses of water daily.');
    }

    // Diet-specific general advice
    if (dietPreferences.toLowerCase() == 'vegan') {
      recommendations.add(
          'Remember to include a variety of plant-based protein sources throughout the day for complete amino acid profiles.');
    } else if (dietPreferences.toLowerCase() == 'keto') {
      recommendations.add(
          'Stay in ketosis by keeping net carbs under your daily limit and maintaining adequate fat intake.');
    } else if (dietPreferences.toLowerCase() == 'paleo') {
      recommendations.add(
          'Focus on whole, unprocessed foods and avoid grains, legumes, and dairy for optimal paleo benefits.');
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
