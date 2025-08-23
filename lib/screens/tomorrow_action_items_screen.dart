import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/primary_button.dart';

class TomorrowActionItemsScreen extends StatefulWidget {
  final Map<String, dynamic> todaySummary;
  final String tomorrowDate;
  final bool hasMealPlan;
  final String notificationType;

  const TomorrowActionItemsScreen({
    super.key,
    required this.todaySummary,
    required this.tomorrowDate,
    required this.hasMealPlan,
    required this.notificationType,
  });

  // Static method to show action items from anywhere in the app
  static void showActionItems(
    BuildContext context, {
    required Map<String, dynamic> todaySummary,
    required String tomorrowDate,
    required bool hasMealPlan,
    required String notificationType,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TomorrowActionItemsScreen(
          todaySummary: todaySummary,
          tomorrowDate: tomorrowDate,
          hasMealPlan: hasMealPlan,
          notificationType: notificationType,
        ),
      ),
    );
  }

  @override
  State<TomorrowActionItemsScreen> createState() =>
      _TomorrowActionItemsScreenState();
}

class _TomorrowActionItemsScreenState extends State<TomorrowActionItemsScreen> {
  late DateTime tomorrowDate;

  @override
  void initState() {
    super.initState();
    // Parse tomorrow's date
    final parts = widget.tomorrowDate.split('-');
    if (parts.length == 3) {
      tomorrowDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } else {
      tomorrowDate = DateTime.now().add(const Duration(days: 1));
    }
  }

  List<Map<String, dynamic>> _generateActionItems() {
    final List<Map<String, dynamic>> actionItems = [];

    // Get today's data
    final calories = widget.todaySummary['calories'] as int? ?? 0;
    final protein = _parseMacro(widget.todaySummary['protein']);
    final carbs = _parseMacro(widget.todaySummary['carbs']);
    final fat = _parseMacro(widget.todaySummary['fat']);
    final water = _parseMacro(widget.todaySummary['water']);
    final steps = _parseMacro(widget.todaySummary['steps']);

    // Get user goals (you might want to fetch these from user service)
    final settings = userService.currentUser.value?.settings;
    final calorieGoal = _parseMacro(settings?['foodGoal']);
    final proteinGoal = _parseMacro(settings?['proteinGoal']);
    final carbsGoal = _parseMacro(settings?['carbsGoal']);
    final fatGoal = _parseMacro(settings?['fatGoal']);

    // check if tomorrow is today
    final isTomorrow = DateFormat('yyyy-MM-dd').format(tomorrowDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Analyze today's performance and suggest tomorrow's actions
    if (calories < calorieGoal * 0.8) {
      actionItems.add({
        'title': 'Increase Calorie Intake',
        'description':
            'You ${isTomorrow ? 'were' : 'are'} ${(calorieGoal - calories).round()} calories below your goal ${isTomorrow ? 'yesterday' : 'today'}. Plan for more substantial meals ${isTomorrow ? 'today' : 'tomorrow'}.',
        'icon': Icons.restaurant,
        'color': kAccent,
        'priority': 'high',
      });
    } else if (calories > calorieGoal * 1.2) {
      actionItems.add({
        'title': 'Reduce Calorie Intake',
        'description':
            'You ${isTomorrow ? 'were' : 'are'} ${(calories - calorieGoal).round()} calories above your goal ${isTomorrow ? 'yesterday' : 'today'}. Plan for smaller meals ${isTomorrow ? 'today' : 'tomorrow'}.',
        'icon': Icons.restaurant,
        'color': kRed,
        'priority': 'high',
      });
    } else {
      actionItems.add({
        'title': 'Calorie Intake',
        'description':
            'You\'ve hit ${((calories / calorieGoal) * 100).round()}% of your calorie intake goal ${isTomorrow ? 'today' : 'today'}. ${isTomorrow ? 'Keep up the good work!' : 'Try similar calorie intake tomorrow.'} ',
        'icon': Icons.restaurant,
        'color': kGreen,
        'priority': 'low',
      });
    }

    if (protein < proteinGoal * 0.8) {
      actionItems.add({
        'title': 'Boost Protein',
        'description':
            'Add more protein-rich foods like lean meats, eggs, or legumes to ${isTomorrow ? 'today\'s' : 'tomorrow\'s'} meals.',
        'icon': Icons.fitness_center,
        'color': kBlue,
        'priority': 'medium',
      });
    } else if (protein > proteinGoal * 1.2) {
      actionItems.add({
        'title': 'Reduce Protein',
        'description':
            '${isTomorrow ? 'Today' : 'Tomorrow'} Reduce protein intake to stay within your goal.',
        'icon': Icons.fitness_center,
        'color': kRed,
        'priority': 'medium',
      });
    } else {
      actionItems.add({
        'title': 'Protein Intake',
        'description':
            'You\'ve hit ${((protein / proteinGoal) * 100).round()}% of your protein intake goal ${isTomorrow ? 'today' : 'today'}. ${isTomorrow ? 'Keep up the good work!' : 'Try similar protein intake tomorrow.'} ',
        'icon': Icons.fitness_center,
        'color': kGreen,
        'priority': 'low',
      });
    }

    if (carbs < carbsGoal * 0.8) {
      actionItems.add({
        'title': 'Include More Carbs',
        'description':
              'Add healthy carbohydrates like whole grains, fruits, or vegetables to ${isTomorrow ? 'today\'s' : 'tomorrow\'s'} meals.',
        'icon': Icons.grain,
        'color': kGreen,
        'priority': 'medium',
      });
    } else if (carbs > carbsGoal * 1.2) {
      actionItems.add({
        'title': 'Reduce Carbs',
        'description':
            '${isTomorrow ? 'Today' : 'Tomorrow'} Reduce carb intake to stay within your goal.',
        'icon': Icons.grain,
        'color': kRed,
        'priority': 'medium',
      });
    } else {
      actionItems.add({
        'title': 'Carbs Intake',
        'description':
            'You\'ve hit ${((carbs / carbsGoal) * 100).round()}% of your carbs intake goal ${isTomorrow ? 'today' : 'today'}. ${isTomorrow ? 'Keep up the good work!' : 'Try similar carbs intake tomorrow.'} ',
        'icon': Icons.grain,
        'color': kGreen,
        'priority': 'low',
      });
    }

    if (fat < fatGoal * 0.8) {
      actionItems.add({
        'title': 'Healthy Fats',
        'description':
            'Include healthy fats like nuts, avocados, or olive oil in ${isTomorrow ? 'today\'s' : 'tomorrow\'s'} meals.',
        'icon': Icons.water_drop,
        'color': kPurple,
        'priority': 'medium',
      });
    } else if (fat > fatGoal * 1.2) {
      actionItems.add({
        'title': 'Reduce Fat',
        'description':
            '${isTomorrow ? 'Today' : 'Tomorrow'} Reduce fat intake to stay within your goal.',
        'icon': Icons.water_drop,
        'color': kRed,
        'priority': 'medium',
      });
    } else {
      actionItems.add({
        'title': 'Fat Intake',
        'description':
            'You\'ve hit ${((fat / fatGoal) * 100).round()}% of your fat intake goal ${isTomorrow ? 'today' : 'today'}. ${isTomorrow ? 'Keep up the good work!' : 'Try similar fat intake tomorrow.'} ',
        'icon': Icons.water_drop,
        'color': kGreen,
        'priority': 'low',
      });
    }

    // Meal planning suggestions
    if (!widget.hasMealPlan) {
      actionItems.add({
        'title': 'Plan Tomorrow\'s Meals',
        'description':
            'Take time to plan your meals for tomorrow to stay on track with your nutrition goals.',
        'icon': Icons.calendar_today,
        'color': kAccentLight,
        'priority': 'high',
      });
    }

    // General wellness suggestions
    if (water < 2000) {
      actionItems.add({
        'title': 'Stay Hydrated',
        'description':
            'Aim to drink at least 2000 ml of water ${isTomorrow ? 'today' : 'tomorrow'} to support your metabolism.',
        'icon': Icons.local_drink,
        'color': kBlue,
        'priority': 'medium',
      });
    }

    // If no specific issues, add positive reinforcement
    if (actionItems.length <= 2) {
      actionItems.add({
        'title': 'Great Job Today!',
        'description':
            'You\'re doing well with your nutrition. Keep up the good work tomorrow!',
        'icon': Icons.thumb_up,
        'color': kGreen,
        'priority': 'low',
      });
    }

    return actionItems;
  }

  double _parseMacro(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return kAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final actionItems = _generateActionItems();
    // check if tomorrow is today
    final isTomorrow = DateFormat('yyyy-MM-dd').format(tomorrowDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    // check if we're viewing today's action items
    final isToday = DateFormat('yyyy-MM-dd').format(tomorrowDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: kAccent,
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        title: Text(
          isTomorrow ? 'Today\'s Action Items' : 'Tomorrow\'s Action Items',
          style: textTheme.displaySmall?.copyWith(
            fontSize: getTextScale(7, context),
            color: kWhite,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: kAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Based on ${DateFormat('MMM dd').format(isTomorrow ? DateTime.now().subtract(const Duration(days: 1)) : DateTime.now())}\'s Summary',
                    style: textTheme.titleMedium?.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Text(
                    'Here are your personalized action items for ${isTomorrow ? 'Today' : 'Tomorrow'}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode
                          ? kAccent.withValues(alpha: 0.5)
                          : kDarkGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (isToday) SizedBox(height: getPercentageHeight(2, context)),

            // Tomorrow's action items button - only visible when viewing today's action items
            if (isToday)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(3, context)),
                child: GestureDetector(
                  onTap: () async {
                    try {
                      // Get today's date for the summary data
                      final today = DateTime.now();
                      final todayStr = DateFormat('yyyy-MM-dd').format(today);

                      // Get today's summary data
                      final userId = userService.userId ?? '';
                      Map<String, dynamic> todaySummary = {};

                      if (userId.isNotEmpty) {
                        final summaryDoc = await firestore
                            .collection('users')
                            .doc(userId)
                            .collection('daily_summary')
                            .doc(todayStr)
                            .get();

                        if (summaryDoc.exists) {
                          todaySummary = summaryDoc.data() ?? {};
                        }
                      }

                      // Navigate to tomorrow's action items based on today's data
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TomorrowActionItemsScreen(
                            todaySummary: todaySummary, // Today's data
                            tomorrowDate: DateFormat('yyyy-MM-dd').format(
                                DateTime.now().add(const Duration(
                                    days: 1))), // Tomorrow's date
                            hasMealPlan: false,
                            notificationType: 'manual',
                          ),
                        ),
                      );
                    } catch (e) {
                      print('Error showing tomorrow\'s action items: $e');
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(getPercentageWidth(3, context)),
                    decoration: BoxDecoration(
                      color: kAccentLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kAccentLight.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule,
                          color: kAccentLight,
                          size: getIconScale(4, context),
                        ),
                        SizedBox(width: getPercentageWidth(2, context)),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'View Tomorrow\'s Action Items',
                                style: textTheme.titleMedium?.copyWith(
                                  color: kAccentLight,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                'Based on today\'s summary',
                                style: textTheme.bodySmall?.copyWith(
                                  color: kAccentLight.withValues(alpha: 0.7),
                                  fontSize: getTextScale(2.5, context),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: getPercentageWidth(2, context)),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: kAccentLight,
                          size: getIconScale(3.5, context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Action items list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(getPercentageWidth(4, context)),
                itemCount: actionItems.length,
                itemBuilder: (context, index) {
                  final item = actionItems[index];
                  return Container(
                    margin: EdgeInsets.only(
                        bottom: getPercentageHeight(2, context)),
                    padding: EdgeInsets.all(getPercentageWidth(4, context)),
                    decoration: BoxDecoration(
                      color: isDarkMode ? kDarkGrey : kWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item['color'].withValues(alpha: 0.3),
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
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(
                                  getPercentageWidth(2, context)),
                              decoration: BoxDecoration(
                                color: item['color'].withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item['icon'],
                                color: item['color'],
                                size: getIconScale(6, context),
                              ),
                            ),
                            SizedBox(width: getPercentageWidth(3, context)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'],
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode ? kWhite : kBlack,
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          getPercentageHeight(0.5, context)),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          getPercentageWidth(2, context),
                                      vertical:
                                          getPercentageHeight(0.5, context),
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getPriorityColor(item['priority'])
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      item['priority'].toUpperCase(),
                                      style: textTheme.bodySmall?.copyWith(
                                        color:
                                            _getPriorityColor(item['priority']),
                                        fontWeight: FontWeight.w600,
                                        fontSize: getTextScale(2.5, context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: getPercentageHeight(2, context)),
                        Text(
                          item['description'],
                          style: textTheme.bodyMedium?.copyWith(
                            color: isDarkMode
                                ? kAccent.withValues(alpha: 0.5)
                                : kDarkGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom action buttons
            Container(
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: isDarkMode ? kDarkGrey : kWhite,
                border: Border(
                  top: BorderSide(
                    color: kAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: kAccent),
                      label: Text(
                        'Close',
                        style: textTheme.bodyMedium?.copyWith(color: kAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kAccent),
                        padding: EdgeInsets.symmetric(
                          vertical: getPercentageHeight(1.5, context),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: getPercentageWidth(3, context)),
                  Expanded(
                    child: AppButton(
                      text: 'Plan Meals',
                      onPressed: () {
                        // Navigate to meal planning screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const BottomNavSec(selectedIndex: 4),
                          ),
                        );
                        // You can add navigation to meal planning here
                      },
                      type: AppButtonType.primary,
                      color: kAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
