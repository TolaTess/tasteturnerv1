import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../service/nutrition_controller.dart';
import '../service/routine_service.dart';
import '../screens/tomorrow_action_items_screen.dart';
import '../service/notification_handler_service.dart';
import '../service/nutrient_breakdown_service.dart';
import '../service/symptom_service.dart';
import '../data_models/symptom_entry.dart';
import '../screens/rainbow_tracker_detail_screen.dart';
import '../screens/add_food_screen.dart';
import 'rainbow_tracker_widget.dart';

class DailySummaryWidget extends StatefulWidget {
  final DateTime date;
  final bool showPreviousDay;
  // Optional meal context for symptom logging (from notification)
  final String? mealId;
  final String? instanceId;
  final String? mealName;
  final String? mealType;

  const DailySummaryWidget({
    super.key,
    required this.date,
    this.showPreviousDay = false,
    this.mealId,
    this.instanceId,
    this.mealName,
    this.mealType,
  });

  @override
  State<DailySummaryWidget> createState() => _DailySummaryWidgetState();
}

class _DailySummaryWidgetState extends State<DailySummaryWidget> {
  final dailyDataController = Get.find<NutritionController>();
  final nutrientBreakdownService = NutrientBreakdownService.instance;
  final symptomService = SymptomService.instance;
  bool isLoading = true;
  Map<String, dynamic> summaryData = {};
  Map<String, dynamic> goals = {};
  Map<String, List<Map<String, dynamic>>> nutrientBreakdowns = {};
  List<SymptomEntry> currentSymptoms = []; // Symptoms for today
  // Meal context for symptom logging (set from notification)
  String? _currentMealId;
  String? _currentInstanceId;
  String? _currentMealName;
  String? _currentMealType;

  @override
  void initState() {
    super.initState();
    // Set meal context from widget parameters if provided
    _currentMealId = widget.mealId;
    _currentInstanceId = widget.instanceId;
    _currentMealName = widget.mealName;
    _currentMealType = widget.mealType;

    // Debug logging
    if (_currentMealName != null) {
      debugPrint(
          '🍽️ DailySummaryWidget initialized with meal context: ${_currentMealName} (ID: ${_currentMealId})');
    }

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

      // Load routine completion data
      await _loadRoutineCompletionData(userId, dateString);

      // Load nutrient breakdowns
      final breakdowns =
          await nutrientBreakdownService.analyzeDailyNutrientBreakdowns(
        userId,
        widget.date,
      );
      nutrientBreakdowns = breakdowns;

      // Load existing symptoms for this date
      currentSymptoms =
          await symptomService.getSymptomsForDate(userId, widget.date);

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
      debugPrint('Error loading daily summary: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadRoutineCompletionData(
      String userId, String dateString) async {
    try {
      // Load routine completion data
      final routineDoc = await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine_completed')
          .doc(dateString)
          .get();

      if (routineDoc.exists) {
        final routineData = routineDoc.data()!;
        summaryData['routineCompletionPercentage'] =
            routineData['completionPercentage'] ?? 0.0;
      } else {
        // Calculate routine completion percentage if not stored
        final routinePercentage =
            await _calculateRoutineCompletionPercentage(userId, dateString);
        summaryData['routineCompletionPercentage'] = routinePercentage;
      }
    } catch (e) {
      debugPrint('Error loading routine completion data: $e');
      summaryData['routineCompletionPercentage'] = 0.0;
    }
  }

  Future<double> _calculateRoutineCompletionPercentage(
      String userId, String dateString) async {
    try {
      // Get routine items
      final routineService = RoutineService.instance;
      final routineItems = await routineService.getRoutineItems(userId);
      final enabledItems =
          routineItems.where((item) => item.isEnabled).toList();

      if (enabledItems.isEmpty) return 0.0;

      // Load completion status
      final routineDoc = await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine_completed')
          .doc(dateString)
          .get();

      if (!routineDoc.exists) return 0.0;

      final completionData = routineDoc.data()!;
      final completedCount = enabledItems.where((item) {
        final status = completionData[item.title];
        if (status is bool) return status;
        if (status is num) return status > 0;
        return false;
      }).length;

      return (completedCount / enabledItems.length) * 100;
    } catch (e) {
      debugPrint('Error calculating routine completion percentage: $e');
      return 0.0;
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
    // Cloud function saves macros directly as protein, carbs, fat at root level
    // Also check nutritionalInfo as fallback for backward compatibility
    final nutritionalInfo =
        summaryData['nutritionalInfo'] as Map<String, dynamic>?;

    // Check direct fields first (standard path from cloud function), then fall back to nutritionalInfo
    final proteinRaw = summaryData['protein'] ?? nutritionalInfo?['protein'];
    final protein = proteinRaw is int
        ? proteinRaw.toDouble()
        : proteinRaw is double
            ? proteinRaw
            : (proteinRaw is String ? double.tryParse(proteinRaw) ?? 0.0 : 0.0);

    final carbsRaw = summaryData['carbs'] ?? nutritionalInfo?['carbs'];
    final carbs = carbsRaw is int
        ? carbsRaw.toDouble()
        : carbsRaw is double
            ? carbsRaw
            : (carbsRaw is String ? double.tryParse(carbsRaw) ?? 0.0 : 0.0);

    final fatRaw = summaryData['fat'] ?? nutritionalInfo?['fat'];
    final fat = fatRaw is int
        ? fatRaw.toDouble()
        : fatRaw is double
            ? fatRaw
            : (fatRaw is String ? double.tryParse(fatRaw) ?? 0.0 : 0.0);

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

    // Get routine completion percentage
    final routineCompletionPercentage =
        summaryData['routineCompletionPercentage'] as double? ?? 0.0;
    final routineProgress = routineCompletionPercentage / 100.0;

    final dateText =
        '${getRelativeDayString(widget.date) == 'Today' ? 'Today\'s' : getRelativeDayString(widget.date) == 'Yesterday' ? 'Yesterday\'s' : '${shortMonthName(widget.date.month)} ${widget.date.day}\'s'} Service';

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
            routineProgress,
            calories,
            protein,
            carbs,
            fat,
            routineCompletionPercentage,
            calorieGoal,
            proteinGoal,
            carbsGoal,
            fatGoal,
          ),

          SizedBox(height: getPercentageHeight(2, context)),

          // Check if in "Weeds" (macro gap situation)
          if (_isInWeeds(calories.toDouble(), protein, carbs, fat, calorieGoal,
              proteinGoal, carbsGoal, fatGoal)) ...[
            _buildWeedsProtocol(context, calories.toDouble(), protein,
                calorieGoal, proteinGoal),
            SizedBox(height: getPercentageHeight(2, context)),
          ],

          // Motivational Message
          _buildMotivationalMessage(
            context,
            calorieProgress,
            proteinProgress,
            carbsProgress,
            fatProgress,
            routineProgress,
            () async {
              // Use the notification handler service to show action items
              try {
                final notificationHandler =
                    Get.find<NotificationHandlerService>();
                await notificationHandler.showTomorrowActionItems(context);
              } catch (e) {
                debugPrint('Error showing action items: $e');
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
            routineProgress,
          ),

          // Nutrient Breakdown
          if (nutrientBreakdowns.isNotEmpty) ...[
            SizedBox(height: getPercentageHeight(2, context)),
            _buildNutrientBreakdown(context),
          ],

          // Symptom Input Section
          SizedBox(height: getPercentageHeight(2, context)),
          _buildSymptomInputSection(context, isDarkMode, textTheme),

          // Rainbow Tracker Widget
          SizedBox(height: getPercentageHeight(2, context)),
          RainbowTrackerWidget(
            weekStart: getWeekStart(widget.date),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RainbowTrackerDetailScreen(
                    weekStart: getWeekStart(widget.date),
                  ),
                ),
              );
            },
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
    double routineProgress,
    int calories,
    double protein,
    double carbs,
    double fat,
    double routineCompletionPercentage,
    double calorieGoal,
    double proteinGoal,
    double carbsGoal,
    double fatGoal,
  ) {
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

        // // Routine Chart
        // _buildCircularProgressCard(
        //   context,
        //   title: 'Routine',
        //   current: routineCompletionPercentage,
        //   goal: 100.0,
        //   progress: routineProgress,
        //   icon: Icons.checklist,
        //   color: kAccent,
        //   unit: '%',
        // ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon and Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: getIconScale(4, context)),
              SizedBox(width: getPercentageWidth(1, context)),
              Flexible(
                child: Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? kWhite : kDarkGrey,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(0.8, context)),

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

          SizedBox(height: getPercentageHeight(0.8, context)),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${current.toStringAsFixed(current % 1 == 0 ? 0 : 1)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? kWhite : kDarkGrey,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  '/ ${goal.toStringAsFixed(goal % 1 == 0 ? 0 : 1)} $unit',
                  style: textTheme.bodySmall?.copyWith(
                    color: isDarkMode
                        ? kWhite.withValues(alpha: 0.7)
                        : kDarkGrey.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
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
    double routineProgress,
    Function() onTap,
  ) {
    final textTheme = Theme.of(context).textTheme;

    // Check if the date is today
    final isToday = DateFormat('yyyy-MM-dd').format(widget.date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Calculate overall progress including routine
    final overallProgress = (calorieProgress +
            proteinProgress +
            carbsProgress +
            fatProgress +
            routineProgress) /
        5;

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
    double routineProgress,
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

    // Routine-specific recommendations
    if (routineProgress < 0.5) {
      recommendations.add(
          'Your routine completion is low. Try to complete at least 50% of your daily routine tasks for better consistency.');
    } else if (routineProgress < 0.8) {
      recommendations.add(
          'Good routine progress! Try to complete more routine tasks to reach 80% completion for optimal daily habits.');
    } else if (routineProgress >= 0.8) {
      recommendations.add(
          'Excellent routine completion! You\'re maintaining great daily habits. Keep up the consistency!');
    }

    if (recommendations.isEmpty) {
      recommendations.add('You\'re doing great! Keep up the healthy habits!');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Turner\'s Notes',
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

  Widget _buildNutrientBreakdown(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    bool isExpanded = false;

    return StatefulBuilder(
      builder: (context, setState) => Container(
        padding: EdgeInsets.all(getPercentageWidth(3, context)),
        decoration: BoxDecoration(
          color: isDarkMode ? kDarkGrey : kLightGrey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => isExpanded = !isExpanded),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: kAccent,
                        size: getIconScale(4, context),
                      ),
                      SizedBox(width: getPercentageWidth(2, context)),
                      Text(
                        'Nutrient Breakdown',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: kAccent,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: kAccent,
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              SizedBox(height: getPercentageHeight(1.5, context)),
              ...nutrientBreakdowns.entries.map((entry) {
                final mealType = entry.key;
                final meals = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalizeMealType(mealType),
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(0.5, context)),
                    ...meals.map((meal) => _buildMealNutrientBreakdown(
                          context,
                          meal,
                          isDarkMode,
                          textTheme,
                        )),
                    SizedBox(height: getPercentageHeight(1, context)),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMealNutrientBreakdown(
    BuildContext context,
    Map<String, dynamic> meal,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    final mealName = meal['mealName'] as String? ?? 'Unknown Meal';
    final sodium = meal['sodium'] as List<dynamic>? ?? [];
    final sugar = meal['sugar'] as List<dynamic>? ?? [];
    final saturatedFat = meal['saturatedFat'] as List<dynamic>? ?? [];

    return Container(
      margin: EdgeInsets.only(
        left: getPercentageWidth(2, context),
        bottom: getPercentageHeight(1, context),
      ),
      padding: EdgeInsets.all(getPercentageWidth(2, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mealName,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          SizedBox(height: getPercentageHeight(0.5, context)),
          if (sodium.isNotEmpty) ...[
            _buildNutrientContributors(
              context,
              'Sodium',
              sodium,
              isDarkMode,
              textTheme,
            ),
          ],
          if (sugar.isNotEmpty) ...[
            SizedBox(height: getPercentageHeight(0.5, context)),
            _buildNutrientContributors(
              context,
              'Sugar',
              sugar,
              isDarkMode,
              textTheme,
            ),
          ],
          if (saturatedFat.isNotEmpty) ...[
            SizedBox(height: getPercentageHeight(0.5, context)),
            _buildNutrientContributors(
              context,
              'Saturated Fat',
              saturatedFat,
              isDarkMode,
              textTheme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutrientContributors(
    BuildContext context,
    String nutrientName,
    List<dynamic> contributors,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$nutrientName:',
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        SizedBox(height: getPercentageHeight(0.3, context)),
        ...contributors.map((contributor) {
          final ingredient = contributor['ingredient'] as String? ?? '';
          final contribution = contributor['contribution'] as double? ?? 0.0;
          return Padding(
            padding: EdgeInsets.only(
              left: getPercentageWidth(2, context),
              bottom: getPercentageHeight(0.3, context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ingredient,
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                Container(
                  width: getPercentageWidth(15, context),
                  height: getPercentageHeight(0.8, context),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (contribution / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: kAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: getPercentageWidth(1, context)),
                Text(
                  '${contribution.toStringAsFixed(0)}%',
                  style: textTheme.bodySmall?.copyWith(
                    color: kAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: getTextScale(2.5, context),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _capitalizeMealType(String mealType) {
    if (mealType.isEmpty) return mealType;
    return mealType[0].toUpperCase() + mealType.substring(1);
  }

  /// Filter symptoms by specific date
  List<SymptomEntry> _filterSymptomsByDate(
    List<SymptomEntry> symptoms,
    DateTime targetDate,
  ) {
    final targetDateOnly =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    return symptoms.where((symptom) {
      final symptomDate = DateTime(
        symptom.timestamp.year,
        symptom.timestamp.month,
        symptom.timestamp.day,
      );
      return symptomDate.isAtSameMomentAs(targetDateOnly);
    }).toList();
  }

  Widget _buildSymptomInputSection(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    // Check if viewing today - only allow symptom logging for today
    final isToday = DateFormat('yyyy-MM-dd').format(widget.date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Allow symptom logging if it's today OR if meal context is provided (from notification)
    final canLogSymptoms =
        isToday || (_currentMealId != null && _currentMealName != null);

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite,
                color: kAccent,
                size: getIconScale(4, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How are you feeling?',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                    ),
                    if (_currentMealName != null) ...[
                      SizedBox(height: getPercentageHeight(0.5, context)),
                      Text(
                        'After ${_currentMealName}',
                        style: textTheme.bodySmall?.copyWith(
                          color: kAccent,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1.5, context)),
          if (canLogSymptoms) ...[
            Wrap(
              spacing: getPercentageWidth(2, context),
              runSpacing: getPercentageHeight(1, context),
              children: [
                _buildSymptomButton(context, 'bloating', '💨', 'Bloating',
                    isDarkMode, textTheme),
                _buildSymptomButton(context, 'headache', '🤕', 'Headache',
                    isDarkMode, textTheme),
                _buildSymptomButton(
                    context, 'fatigue', '😴', 'Fatigue', isDarkMode, textTheme),
                _buildSymptomButton(
                    context, 'nausea', '🤢', 'Nausea', isDarkMode, textTheme),
                _buildSymptomButton(
                    context, 'energy', '⚡', 'Energy', isDarkMode, textTheme),
                _buildSymptomButton(
                    context, 'good', '✅', 'Good', isDarkMode, textTheme),
              ],
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(getPercentageWidth(3, context)),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? kDarkGrey.withValues(alpha: 0.5)
                    : kLightGrey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    size: getIconScale(4, context),
                  ),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Expanded(
                    child: Text(
                      _currentMealName != null
                          ? 'You can log symptoms for this meal, Chef.'
                          : 'You can only log symptoms for today, Chef.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Display logged symptoms grouped by meal
          if (currentSymptoms.isNotEmpty) ...[
            SizedBox(height: getPercentageHeight(1.5, context)),
            Divider(color: kAccent.withValues(alpha: 0.3)),
            SizedBox(height: getPercentageHeight(1, context)),
            _buildMealSymptomsList(context, isDarkMode, textTheme),
          ],
        ],
      ),
    );
  }

  Widget _buildSymptomButton(
    BuildContext context,
    String symptomType,
    String emoji,
    String label,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    final isSelected = currentSymptoms.any((s) => s.type == symptomType);

    return GestureDetector(
      onTap: () => _showSymptomSeverityDialog(
          context, symptomType, emoji, label, isDarkMode, textTheme),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(3, context),
          vertical: getPercentageHeight(0.8, context),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? kAccent.withValues(alpha: 0.2)
              : kAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kAccent : kAccent.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: getTextScale(3.5, context)),
            ),
            SizedBox(width: getPercentageWidth(1.5, context)),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSymptomSeverityDialog(
    BuildContext context,
    String symptomType,
    String emoji,
    String label,
    bool isDarkMode,
    TextTheme textTheme,
  ) async {
    int severity = 3; // Default severity

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: getTextScale(5, context))),
              SizedBox(width: getPercentageWidth(2, context)),
              Text(
                label,
                style: textTheme.titleMedium?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Severity (1 = mild, 5 = severe)',
                style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              SizedBox(height: getPercentageHeight(2, context)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        severity = value;
                      });
                    },
                    child: Container(
                      width: getPercentageWidth(8, context),
                      height: getPercentageWidth(8, context),
                      decoration: BoxDecoration(
                        color: severity == value
                            ? kAccent
                            : (isDarkMode ? kLightGrey : Colors.grey[300]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$value',
                          style: textTheme.bodyLarge?.copyWith(
                            color: severity == value
                                ? kWhite
                                : (isDarkMode ? kWhite : kBlack),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, severity),
              child: Text(
                'Save',
                style: textTheme.bodyMedium?.copyWith(
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _saveSymptom(symptomType, result);
    }
  }

  Future<void> _saveSymptom(String symptomType, int severity) async {
    try {
      final userId = userService.userId ?? '';
      if (userId.isEmpty) return;

      // Check if viewing today or a past date
      final isToday = DateFormat('yyyy-MM-dd').format(widget.date) ==
          DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Allow logging symptoms for today or if meal context is provided (from notification)
      if (!isToday && _currentMealId == null) {
        if (mounted) {
          showTastySnackbar(
            'Cannot Log Symptoms',
            'You can only log symptoms for today, Chef.',
            context,
            backgroundColor: kRed,
          );
        }
        return;
      }

      // If meal context is provided but date is not today, check if meal was logged within 24 hours
      if (!isToday && _currentMealId != null) {
        final mealDate = widget.date;
        final now = DateTime.now();
        final hoursSinceMeal = now.difference(mealDate).inHours;

        if (hoursSinceMeal > 24) {
          if (mounted) {
            showTastySnackbar(
              'Cannot Log Symptoms',
              'You can only log symptoms for meals eaten within the last 24 hours, Chef.',
              context,
              backgroundColor: kRed,
            );
          }
          return;
        }
      }

      final now = DateTime.now();
      List<String> ingredients = [];

      // If meal context is provided, get ingredients from that specific meal
      if (_currentMealId != null && _currentMealId!.isNotEmpty) {
        ingredients = await _getIngredientsFromMeal(_currentMealId!);
      } else {
        // Fallback: Get meals eaten 2-4 hours before now
        final fourHoursAgo = now.subtract(const Duration(hours: 4));
        final twoHoursAgo = now.subtract(const Duration(hours: 2));
        ingredients = await _getIngredientsFromRecentMeals(
            userId, twoHoursAgo, fourHoursAgo);
      }

      // Use meal context if provided, otherwise determine from time
      String? mealContext = _currentMealType;
      if (mealContext == null) {
        if (now.hour >= 6 && now.hour < 11) {
          mealContext = 'breakfast';
        } else if (now.hour >= 11 && now.hour < 15) {
          mealContext = 'lunch';
        } else if (now.hour >= 15 && now.hour < 20) {
          mealContext = 'dinner';
        } else {
          mealContext = 'snacks';
        }
      }

      final symptom = SymptomEntry(
        type: symptomType,
        severity: severity,
        timestamp: now,
        mealContext: mealContext,
        ingredients: ingredients,
        mealId: _currentMealId,
        instanceId: _currentInstanceId,
        mealName: _currentMealName,
        mealType: _currentMealType ?? mealContext,
      );

      await symptomService.addSymptomEntry(userId, widget.date, symptom);

      // Clear meal context after saving
      setState(() {
        _currentMealId = null;
        _currentInstanceId = null;
        _currentMealName = null;
        _currentMealType = null;
      });

      // Reload symptoms to update UI
      final updatedSymptoms =
          await symptomService.getSymptomsForDate(userId, widget.date);
      if (mounted) {
        setState(() {
          currentSymptoms = _filterSymptomsByDate(updatedSymptoms, widget.date);
        });
      }

      if (mounted) {
        showTastySnackbar(
          'Success',
          'Symptom logged successfully',
          context,
          backgroundColor: kAccent,
        );
      }
    } catch (e) {
      debugPrint('Error saving symptom: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to save symptom. Please try again.',
          context,
          backgroundColor: kRed,
        );
      }
    }
  }

  Future<List<String>> _getIngredientsFromRecentMeals(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final ingredients = <String>{};

      // Get meals from today and yesterday (in case symptom is logged late)
      final dates = [
        DateFormat('yyyy-MM-dd').format(widget.date),
        DateFormat('yyyy-MM-dd')
            .format(widget.date.subtract(const Duration(days: 1))),
      ];

      for (final dateStr in dates) {
        final mealsDoc = await firestore
            .collection('userMeals')
            .doc(userId)
            .collection('meals')
            .doc(dateStr)
            .get();

        if (!mealsDoc.exists) continue;

        final data = mealsDoc.data()!;
        final mealsMap = Map<String, dynamic>.from(data['meals'] ?? {});

        // Get meal IDs from meals eaten in the time window
        mealsMap.forEach((mealType, mealList) {
          if (mealList is List) {
            for (var mealData in mealList) {
              final mealMap = Map<String, dynamic>.from(mealData);
              final mealId = mealMap['mealId'] as String?;

              if (mealId != null && mealId.isNotEmpty) {
                // Fetch meal to get ingredients
                _fetchMealIngredients(mealId, ingredients);
              }
            }
          }
        });
      }

      return ingredients.toList();
    } catch (e) {
      debugPrint('Error getting ingredients from recent meals: $e');
      return [];
    }
  }

  Future<void> _fetchMealIngredients(
      String mealId, Set<String> ingredients) async {
    try {
      final mealDoc = await firestore.collection('meals').doc(mealId).get();
      if (mealDoc.exists) {
        final mealData = mealDoc.data()!;
        final mealIngredients =
            mealData['ingredients'] as Map<String, dynamic>? ?? {};
        ingredients.addAll(mealIngredients.keys);
      }
    } catch (e) {
      debugPrint('Error fetching meal ingredients: $e');
    }
  }

  /// Get ingredients from a specific meal
  Future<List<String>> _getIngredientsFromMeal(String mealId) async {
    try {
      final mealDoc = await firestore.collection('meals').doc(mealId).get();
      if (mealDoc.exists) {
        final mealData = mealDoc.data()!;
        final mealIngredients =
            mealData['ingredients'] as Map<String, dynamic>? ?? {};
        return mealIngredients.keys.toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting ingredients from meal: $e');
      return [];
    }
  }

  /// Build symptoms list grouped by meal
  Widget _buildMealSymptomsList(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    // Group symptoms by meal (instanceId or mealId)
    final Map<String, List<SymptomEntry>> symptomsByMeal = {};
    final List<SymptomEntry> generalSymptoms = [];

    for (var symptom in currentSymptoms) {
      final key = symptom.instanceId ?? symptom.mealId;
      if (key != null && key.isNotEmpty) {
        symptomsByMeal.putIfAbsent(key, () => []).add(symptom);
      } else {
        generalSymptoms.add(symptom);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // General symptoms (no meal association)
        if (generalSymptoms.isNotEmpty) ...[
          Text(
            'General Symptoms:',
            style: textTheme.bodySmall?.copyWith(
              color: isDarkMode ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: getPercentageHeight(0.5, context)),
          Wrap(
            spacing: getPercentageWidth(2, context),
            runSpacing: getPercentageHeight(0.5, context),
            children: generalSymptoms.map((symptom) {
              return _buildSymptomChip(context, symptom, isDarkMode, textTheme);
            }).toList(),
          ),
          if (symptomsByMeal.isNotEmpty)
            SizedBox(height: getPercentageHeight(1.5, context)),
        ],
        // Symptoms grouped by meal
        ...symptomsByMeal.entries.map((entry) {
          final mealSymptoms = entry.value;
          final firstSymptom = mealSymptoms.first;
          final mealName = firstSymptom.mealName ?? 'Meal';
          final mealType =
              firstSymptom.mealType ?? firstSymptom.mealContext ?? '';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$mealName${mealType.isNotEmpty ? ' ($mealType)' : ''}:',
                style: textTheme.bodySmall?.copyWith(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: getPercentageHeight(0.5, context)),
              Wrap(
                spacing: getPercentageWidth(2, context),
                runSpacing: getPercentageHeight(0.5, context),
                children: mealSymptoms.map((symptom) {
                  return _buildSymptomChip(
                      context, symptom, isDarkMode, textTheme);
                }).toList(),
              ),
              if (entry != symptomsByMeal.entries.last)
                SizedBox(height: getPercentageHeight(1.5, context)),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildSymptomChip(
    BuildContext context,
    SymptomEntry symptom,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    final (emoji, label) = _getSymptomEmojiAndLabel(symptom.type);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2.5, context),
        vertical: getPercentageHeight(0.6, context),
      ),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: getTextScale(3, context))),
          SizedBox(width: getPercentageWidth(1, context)),
          Text(
            '$label (${symptom.severity}/5)',
            style: textTheme.bodySmall?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
              fontSize: getTextScale(2.8, context),
            ),
          ),
        ],
      ),
    );
  }

  (String, String) _getSymptomEmojiAndLabel(String symptomType) {
    switch (symptomType.toLowerCase()) {
      case 'bloating':
        return ('💨', 'Bloating');
      case 'headache':
        return ('🤕', 'Headache');
      case 'fatigue':
        return ('😴', 'Fatigue');
      case 'nausea':
        return ('🤢', 'Nausea');
      case 'energy':
        return ('⚡', 'Energy');
      case 'good':
        return ('✅', 'Good');
      default:
        return ('📝', symptomType);
    }
  }

  // Check if user is "in the weeds" (macro gap situation)
  bool _isInWeeds(
      double calories,
      double protein,
      double carbs,
      double fat,
      double calorieGoal,
      double proteinGoal,
      double carbsGoal,
      double fatGoal) {
    // User is in the weeds if:
    // - Low calories remaining (< 300) but high protein needed (> 30g remaining)
    // - Or significantly under on protein (< 60% of goal) with low calories remaining
    final remainingCalories = calorieGoal - calories;
    final remainingProtein = proteinGoal - protein;

    final isToday = DateFormat('yyyy-MM-dd').format(widget.date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (!isToday) return false; // Only show for today

    return (remainingCalories < 300 && remainingProtein > 30) ||
        (remainingCalories < 500 && protein < proteinGoal * 0.6);
  }

  // Build "Weeds" protocol widget with "Order Fire" button
  Widget _buildWeedsProtocol(BuildContext context, double calories,
      double protein, double calorieGoal, double proteinGoal) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final remainingCalories = (calorieGoal - calories).round();
    final remainingProtein = (proteinGoal - protein).round();

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: getIconScale(6, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Expanded(
                child: Text(
                  'In The Weeds',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Text(
            remainingProtein > 30
                ? 'Chef, we\'re in the weeds on protein today. You have $remainingCalories calories left but need ${remainingProtein}g protein. Don\'t worry, I\'ve got a fix.'
                : 'Chef, the station needs attention. We\'re low on calories ($remainingCalories left) and protein is behind. Let me help you fix this.',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? kWhite : kDarkGrey,
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate to meal suggestions or AI chat for macro fix
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddFoodScreen(
                      date: widget.date,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.local_fire_department, color: kWhite),
              label: Text(
                'Order Fire',
                style: TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(
                  vertical: getPercentageHeight(1.5, context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
