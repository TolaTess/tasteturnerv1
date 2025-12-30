import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../service/routine_service.dart';
import '../service/symptom_analysis_service.dart';
import '../service/symptom_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/primary_button.dart';
import '../service/cycle_adjustment_service.dart';

// Constants for action item thresholds
class ActionItemConstants {
  static const double calorieLowThreshold = 0.8; // 80% of goal
  static const double calorieHighThreshold = 1.2; // 120% of goal
  static const double macroLowThreshold = 0.8; // 80% of goal
  static const double macroHighThreshold = 1.2; // 120% of goal
  static const double routineLowThreshold = 50.0; // 50% completion
  static const double routineMediumThreshold = 80.0; // 80% completion
  static const double waterGoal = 2000.0; // ml
}

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
  SymptomAnalysisService? _symptomAnalysisService;
  Map<String, dynamic>? _yesterdaySymptomAnalysis;
  List<Map<String, dynamic>>? _yesterdayTopTriggers;
  bool _loadingSymptoms = false;

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

    // Load routine completion data if not already present
    _loadRoutineCompletionData();
    // Load yesterday's symptoms for symptom-based action items
    _loadYesterdaySymptoms();
  }

  Future<void> _loadRoutineCompletionData() async {
    try {
      // Only load if routine completion percentage is not already in today's summary
      if (!widget.todaySummary.containsKey('routineCompletionPercentage')) {
        final userId = userService.userId ?? '';
        if (userId.isNotEmpty) {
          final today = DateTime.now();
          final todayStr = DateFormat('yyyy-MM-dd').format(today);

          // Calculate routine completion percentage
          final routinePercentage =
              await _calculateRoutineCompletionPercentage(userId, todayStr);
          widget.todaySummary['routineCompletionPercentage'] =
              routinePercentage;
        }
      }
    } catch (e) {
      debugPrint('Error loading routine completion data: $e');
    }
  }

  /// Load yesterday's symptoms and analyze patterns
  Future<void> _loadYesterdaySymptoms() async {
    try {
      if (!mounted) return;
      setState(() => _loadingSymptoms = true);

      final userId = userService.userId ?? '';
      if (userId.isEmpty) {
        if (mounted) {
          setState(() => _loadingSymptoms = false);
        }
        return;
      }

      _symptomAnalysisService = SymptomAnalysisService.instance;

      // Get yesterday's date
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

      // Get yesterday's symptoms
      final symptomService = SymptomService.instance;
      final yesterdaySymptoms =
          await symptomService.getSymptomsForDate(userId, yesterday);

      // Only analyze if there were symptoms yesterday
      if (yesterdaySymptoms.isNotEmpty) {
        // Analyze patterns including yesterday (use 7 days for better context)
        final analysis = await _symptomAnalysisService!
            .analyzeSymptomPatterns(userId, days: 7);

        if (mounted && analysis['hasData'] == true) {
          final topTriggers = analysis['topTriggers'] as List<dynamic>?;
          setState(() {
            _yesterdayTopTriggers = topTriggers
                ?.cast<Map<String, dynamic>>()
                .where((t) => t.isNotEmpty)
                .toList();
            _yesterdaySymptomAnalysis = analysis;
          });
        } else if (mounted) {
          // No data available, set to empty
          setState(() {
            _yesterdayTopTriggers = [];
            _yesterdaySymptomAnalysis = null;
          });
        }
      } else {
        // No symptoms yesterday, set to empty
        if (mounted) {
          setState(() {
            _yesterdayTopTriggers = [];
            _yesterdaySymptomAnalysis = null;
            _loadingSymptoms = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading yesterday symptoms: $e');
      // On error, set to empty so prep list still works
      if (mounted) {
        setState(() {
          _yesterdayTopTriggers = [];
          _yesterdaySymptomAnalysis = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSymptoms = false);
      }
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

  List<Map<String, dynamic>> _generateActionItems({required bool isTomorrow}) {
    final List<Map<String, dynamic>> actionItems = [];

    // Get today's data
    final calories = widget.todaySummary['calories'] as int? ?? 0;
    final protein = _parseMacro(widget.todaySummary['protein']);
    final carbs = _parseMacro(widget.todaySummary['carbs']);
    final fat = _parseMacro(widget.todaySummary['fat']);
    final water = _parseMacro(widget.todaySummary['water']);
    // Note: steps removed as it was unused - can be added back if step-based action items are needed
    final routineCompletionPercentage =
        _parseMacro(widget.todaySummary['routineCompletionPercentage']);

    // Get user goals (you might want to fetch these from user service)
    final settings = userService.currentUser.value?.settings;
    final calorieGoal = _parseMacro(settings?['foodGoal']);
    final proteinGoal = _parseMacro(settings?['proteinGoal']);
    final carbsGoal = _parseMacro(settings?['carbsGoal']);
    final fatGoal = _parseMacro(settings?['fatGoal']);

    // Analyze today's performance and suggest tomorrow's actions
    // Add division by zero check
    if (calorieGoal <= 0) {
      // If no calorie goal set, skip calorie analysis
    } else if (calories <
        calorieGoal * ActionItemConstants.calorieLowThreshold) {
      actionItems.add({
        'title': 'Increase Fuel Intake',
        'description':
            'You ${isTomorrow ? 'were' : 'are'} ${(calorieGoal - calories).round()} calories below your goal ${isTomorrow ? 'yesterday' : 'today'}, Chef. Plan for more substantial plates ${isTomorrow ? 'today' : 'tomorrow'}.',
        'icon': Icons.restaurant,
        'color': kAccent,
        'priority': 'high',
      });
    } else if (calories >
        calorieGoal * ActionItemConstants.calorieHighThreshold) {
      actionItems.add({
        'title': 'Reduce Fuel Intake',
        'description':
            'You ${isTomorrow ? 'were' : 'are'} ${(calories - calorieGoal).round()} calories above your goal ${isTomorrow ? 'yesterday' : 'today'}, Chef. Plan for lighter plates ${isTomorrow ? 'today' : 'tomorrow'}.',
        'icon': Icons.restaurant,
        'color': kRed,
        'priority': 'high',
      });
    } else {
      // Add division by zero check
      final caloriePercentage =
          calorieGoal > 0 ? ((calories / calorieGoal) * 100).round() : 0;
      actionItems.add({
        'title': 'Fuel Intake',
        'description':
            'You\'ve hit $caloriePercentage% of your fuel intake goal ${isTomorrow ? 'today' : 'today'}, Chef. ${isTomorrow ? 'Keep up the good work!' : 'Try similar fuel intake tomorrow.'} ',
        'icon': Icons.restaurant,
        'color': kGreen,
        'priority': 'low',
      });
    }

    // Refactored macro analysis using helper method
    _addMacroActionItem(
      actionItems,
      current: protein,
      goal: proteinGoal,
      macroName: 'Protein',
      lowTitle: 'Boost Protein',
      lowDescription:
          'Add more protein-rich foods like lean meats, eggs, or legumes to ${isTomorrow ? 'today\'s' : 'tomorrow\'s'} plates, Chef.',
      highTitle: 'Reduce Protein',
      highDescription:
          '${isTomorrow ? 'Today' : 'Tomorrow'}, Chef: Reduce protein intake to stay within your goal.',
      successTitle: 'Protein Intake',
      icon: Icons.fitness_center,
      color: kBlue,
      isTomorrow: isTomorrow,
    );

    _addMacroActionItem(
      actionItems,
      current: carbs,
      goal: carbsGoal,
      macroName: 'Carbs',
      lowTitle: 'Include More Carbs',
      lowDescription:
          'Add healthy carbohydrates like whole grains, fruits, or vegetables to ${isTomorrow ? 'today\'s' : 'tomorrow\'s'} plates, Chef.',
      highTitle: 'Reduce Carbs',
      highDescription:
          '${isTomorrow ? 'Today' : 'Tomorrow'}, Chef: Reduce carb intake to stay within your goal.',
      successTitle: 'Carbs Intake',
      icon: Icons.grain,
      color: kGreen,
      isTomorrow: isTomorrow,
    );

    _addMacroActionItem(
      actionItems,
      current: fat,
      goal: fatGoal,
      macroName: 'Fat',
      lowTitle: 'Healthy Fats',
      lowDescription:
          'Include healthy fats like nuts, avocados, or olive oil in ${isTomorrow ? 'today\'s' : 'tomorrow\'s'} plates, Chef.',
      highTitle: 'Reduce Fat',
      highDescription:
          '${isTomorrow ? 'Today' : 'Tomorrow'}, Chef: Reduce fat intake to stay within your goal.',
      successTitle: 'Fat Intake',
      icon: Icons.water_drop,
      color: kPurple,
      isTomorrow: isTomorrow,
    );

    // Routine completion suggestions
    if (routineCompletionPercentage < ActionItemConstants.routineLowThreshold) {
      actionItems.add({
        'title': 'Improve Routine Consistency',
        'description':
            'You completed ${routineCompletionPercentage.round()}% of your routine ${isTomorrow ? 'today' : 'today'}. Try to complete at least ${ActionItemConstants.routineLowThreshold.round()}% of your routine tasks ${isTomorrow ? 'today' : 'tomorrow'} for better consistency.',
        'icon': Icons.checklist,
        'color': Colors.orange,
        'priority': 'high',
      });
    } else if (routineCompletionPercentage <
        ActionItemConstants.routineMediumThreshold) {
      actionItems.add({
        'title': 'Boost Routine Completion',
        'description':
            'You completed ${routineCompletionPercentage.round()}% of your routine ${isTomorrow ? 'today' : 'today'}. Aim for ${ActionItemConstants.routineMediumThreshold.round()}% completion ${isTomorrow ? 'today' : 'tomorrow'} to maintain optimal daily habits.',
        'icon': Icons.checklist,
        'color': kAccent,
        'priority': 'medium',
      });
    } else {
      actionItems.add({
        'title': 'Routine Excellence',
        'description':
            'Excellent! You completed ${routineCompletionPercentage.round()}% of your routine ${isTomorrow ? 'today' : 'today'}. Keep up the great consistency ${isTomorrow ? 'today' : 'tomorrow'}!',
        'icon': Icons.checklist,
        'color': kGreen,
        'priority': 'low',
      });
    }

    // Symptom-based action items (only for tomorrow's prep list based on yesterday's data)
    if (isTomorrow && _yesterdaySymptomAnalysis != null) {
      _addSymptomActionItems(actionItems, isTomorrow: isTomorrow);
    }

    // Cycle syncing recommendations
    // Use actual current date for cycle calculations
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final targetDateForCycle =
        isTomorrow ? todayDate : todayDate.add(const Duration(days: 1));
    _addCycleActionItems(actionItems, targetDate: targetDateForCycle);

    // Meal planning suggestions
    if (!widget.hasMealPlan) {
      actionItems.add({
        'title': 'Plan Tomorrow\'s Menu',
        'description':
            'Take time to plan your menu for tomorrow, Chef, to stay on track with your nutrition goals.',
        'icon': Icons.calendar_today,
        'color': kAccentLight,
        'priority': 'high',
      });
    }

    // General wellness suggestions
    if (water < ActionItemConstants.waterGoal) {
      actionItems.add({
        'title': 'Stay Hydrated',
        'description':
            'Aim to drink at least ${ActionItemConstants.waterGoal.round()} ml of water ${isTomorrow ? 'today' : 'tomorrow'}, Chef, to support your metabolism.',
        'icon': Icons.local_drink,
        'color': kBlue,
        'priority': 'medium',
      });
    }

    // If no specific issues, add positive reinforcement
    if (actionItems.length <= 2) {
      actionItems.add({
        'title': 'Great Service Today!',
        'description':
            'You\'re doing well with your nutrition, Chef. Keep up the good work tomorrow!',
        'icon': Icons.thumb_up,
        'color': kGreen,
        'priority': 'low',
      });
    }

    return actionItems;
  }

  /// Helper method to add macro action items (reduces code duplication)
  void _addMacroActionItem(
    List<Map<String, dynamic>> actionItems, {
    required double current,
    required double goal,
    required String macroName,
    required String lowTitle,
    required String lowDescription,
    required String highTitle,
    required String highDescription,
    required String successTitle,
    required IconData icon,
    required Color color,
    required bool isTomorrow,
  }) {
    // Skip if goal is zero or invalid
    if (goal <= 0) return;

    if (current < goal * ActionItemConstants.macroLowThreshold) {
      actionItems.add({
        'title': lowTitle,
        'description': lowDescription,
        'icon': icon,
        'color': color,
        'priority': 'medium',
      });
    } else if (current > goal * ActionItemConstants.macroHighThreshold) {
      actionItems.add({
        'title': highTitle,
        'description': highDescription,
        'icon': icon,
        'color': kRed,
        'priority': 'medium',
      });
    } else {
      // Add division by zero check (already checked goal > 0 above)
      final percentage = ((current / goal) * 100).round();
      actionItems.add({
        'title': successTitle,
        'description':
            'You\'ve hit $percentage% of your ${macroName.toLowerCase()} intake goal ${isTomorrow ? 'today' : 'today'}, Chef. ${isTomorrow ? 'Keep up the good work!' : 'Try similar ${macroName.toLowerCase()} intake tomorrow.'} ',
        'icon': icon,
        'color': kGreen,
        'priority': 'low',
      });
    }
  }

  double _parseMacro(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Add symptom-based action items to the prep list
  void _addSymptomActionItems(
    List<Map<String, dynamic>> actionItems, {
    required bool isTomorrow,
  }) {
    // Only show symptom items when viewing tomorrow's prep list (based on yesterday's data)
    if (!isTomorrow) return;

    // Check if we have symptom analysis data
    if (_yesterdaySymptomAnalysis == null ||
        _yesterdaySymptomAnalysis!['hasData'] != true) {
      return;
    }

    // Add trigger avoidance action item if triggers exist
    if (_yesterdayTopTriggers != null && _yesterdayTopTriggers!.isNotEmpty) {
      // Get top 3 triggers, filter out any invalid entries
      final topTriggers = _yesterdayTopTriggers!
          .where((t) =>
              t['ingredient'] != null &&
              t['mostCommonSymptom'] != null &&
              t['occurrences'] != null)
          .take(3)
          .toList();

      if (topTriggers.isNotEmpty) {
        try {
          final triggerNames = topTriggers
              .map((t) => (t['ingredient'] as String).toLowerCase())
              .join(', ');

          final mostCommonSymptom =
              topTriggers.first['mostCommonSymptom'] as String? ?? 'symptoms';
          final occurrences = topTriggers.first['occurrences'] as int? ?? 0;

          if (triggerNames.isNotEmpty && occurrences > 0) {
            actionItems.add({
              'title': 'Avoid Trigger Ingredients',
              'description':
                  'Yesterday, $triggerNames caused $mostCommonSymptom $occurrences time(s). Consider avoiding these ingredients in today\'s meals, Chef.',
              'icon': Icons.warning_amber_rounded,
              'color': Colors.orange,
              'priority': 'high',
              'triggers': topTriggers, // Store for potential detail view
            });
          }
        } catch (e) {
          debugPrint('Error formatting trigger action item: $e');
        }
      }
    }

    // Check for positive patterns (ingredients that correlate with "good" or "energy")
    try {
      final symptomFrequency = _yesterdaySymptomAnalysis?['symptomFrequency']
          as Map<String, dynamic>?;
      if (symptomFrequency != null) {
        final goodCount = (symptomFrequency['good'] is int
                ? symptomFrequency['good'] as int
                : (symptomFrequency['good'] is String
                    ? int.tryParse(symptomFrequency['good'] as String) ?? 0
                    : 0)) ??
            0;
        final energyCount = (symptomFrequency['energy'] is int
                ? symptomFrequency['energy'] as int
                : (symptomFrequency['energy'] is String
                    ? int.tryParse(symptomFrequency['energy'] as String) ?? 0
                    : 0)) ??
            0;
        final goodSymptoms = goodCount + energyCount;

        if (goodSymptoms > 0) {
          actionItems.add({
            'title': 'Continue Positive Patterns',
            'description':
                'You felt good or energetic $goodSymptoms time(s) yesterday. Keep including ingredients from those meals in today\'s plan, Chef.',
            'icon': Icons.thumb_up,
            'color': kGreen,
            'priority': 'medium',
          });
        }
      }
    } catch (e) {
      debugPrint('Error processing positive patterns: $e');
    }
  }

  /// Add cycle syncing recommendations to action items
  void _addCycleActionItems(
    List<Map<String, dynamic>> actionItems, {
    required DateTime targetDate,
  }) {
    try {
      final user = userService.currentUser.value;
      if (user == null) return;

      final genderRaw = user.settings['gender'] as String?;
      final gender = genderRaw?.toLowerCase() ?? '';
      if (gender == 'male') return;

      final cycleDataRaw = user.settings['cycleTracking'];
      if (cycleDataRaw == null) return;

      if (cycleDataRaw is Map) {
        final cycleData = Map<String, dynamic>.from(cycleDataRaw);
        if (cycleData['isEnabled'] as bool? ?? false) {
          final lastPeriodStartStr = cycleData['lastPeriodStart'] as String?;
          if (lastPeriodStartStr != null) {
            final lastPeriodStart = DateTime.tryParse(lastPeriodStartStr);
            if (lastPeriodStart != null) {
              final cycleLength =
                  (cycleData['cycleLength'] as num?)?.toInt() ?? 28;
              final cycleService = CycleAdjustmentService.instance;

              // Use the actual target date passed to the method
              final phase = cycleService.getCurrentPhase(
                  lastPeriodStart, cycleLength, targetDate);

              final enhancedRecs =
                  cycleService.getEnhancedRecommendations(phase);
              final tips = enhancedRecs['tips'] as List<String>? ?? [];
              final macroInfo = enhancedRecs['macroInfo'] as String?;
              final phaseName = cycleService.getPhaseName(phase);
              final phaseEmoji = cycleService.getPhaseEmoji(phase);
              final phaseColor = cycleService.getPhaseColor(phase);

              // Build description with macro info and tips combined
              String description = '';
              if (macroInfo != null && macroInfo.isNotEmpty) {
                description = macroInfo;
              }

              // Add top 2-3 tips to the description
              if (tips.isNotEmpty) {
                final topTips = tips.take(2).toList();
                if (description.isNotEmpty) {
                  description += '\n\n';
                }
                description += 'Tips:\n';
                for (int i = 0; i < topTips.length; i++) {
                  description += '• ${topTips[i]}';
                  if (i < topTips.length - 1) {
                    description += '\n';
                  }
                }
              }

              // Add single cycle phase action item with combined info
              if (description.isNotEmpty) {
                actionItems.add({
                  'title': 'Cycle Sync: $phaseEmoji $phaseName Phase',
                  'description': description,
                  'icon': Icons.favorite,
                  'color': phaseColor,
                  'priority': 'medium',
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error adding cycle action items: $e');
    }
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

    // Optimize date calculations - calculate once and reuse
    final tomorrowDateStr = DateFormat('yyyy-MM-dd').format(tomorrowDate);
    final todayDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isTomorrow = tomorrowDateStr == todayDateStr;
    final isToday = isTomorrow; // Same calculation, reuse variable

    final actionItems = _generateActionItems(isTomorrow: isTomorrow);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: kAccent,
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        title: Text(
          isTomorrow ? 'Today\'s Prep List' : 'Tomorrow\'s Prep List',
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
                    'Based on ${DateFormat('MMM dd').format(isTomorrow ? DateTime.now().subtract(const Duration(days: 1)) : DateTime.now())}\'s Service Summary',
                    style: textTheme.titleMedium?.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Text(
                    'Here\'s your prep list for ${isTomorrow ? 'today' : 'tomorrow'}, Chef',
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
                      debugPrint('Error showing tomorrow\'s action items: $e');
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
                                'View Tomorrow\'s Prep List',
                                style: textTheme.titleMedium?.copyWith(
                                  color: kAccentLight,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                'Based on today\'s service summary',
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
                        'Back to Station',
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
                      text: 'Plan Menu',
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
