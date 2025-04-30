import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../pages/edit_goal.dart';
import '../service/battle_management.dart';
import '../service/routine_service.dart';

class DailyRoutineListHorizontal extends StatefulWidget {
  final String userId;
  final DateTime date;
  const DailyRoutineListHorizontal(
      {Key? key, required this.userId, required this.date})
      : super(key: key);

  @override
  State<DailyRoutineListHorizontal> createState() =>
      _DailyRoutineListHorizontalState();
}

class _DailyRoutineListHorizontalState
    extends State<DailyRoutineListHorizontal> {
  final _routineService = RoutineService.instance;
  late Future<List<dynamic>> _routineItems;
  final String today = DateTime.now().toIso8601String().split('T')[0];
  final String yesterday = DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .split('T')[0];
  bool _badgeAwarded = false;

  @override
  void initState() {
    super.initState();
    _routineItems = _loadRoutineItems();
    _checkYesterdayCompletion();
  }

  @override
  void didUpdateWidget(DailyRoutineListHorizontal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _routineItems = _loadRoutineItems();
    }
  }

  bool getCurrentDate(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _checkYesterdayCompletion() async {
    try {
      // Check if we've already shown the notification today
      final prefs = await SharedPreferences.getInstance();
      final notificationShown =
          prefs.getBool('routine_notification_shown_$today') ?? false;
      if (notificationShown) {
        // Load badge status if notification was already shown
        _badgeAwarded = prefs.getBool('routine_badge_$yesterday') ?? false;
        if (_badgeAwarded) setState(() {});
        return;
      }

      // Get yesterday's completion data
      final yesterdayDoc = await FirebaseFirestore.instance
          .collection('userMeals')
          .doc(widget.userId)
          .collection('routine_completed')
          .doc(yesterday)
          .get();

      if (!yesterdayDoc.exists) return;

      // Calculate yesterday's completion percentage
      final yesterdayItems =
          await _routineService.getRoutineItems(widget.userId);
      final yesterdayCompletionStatus =
          Map<String, bool>.from(yesterdayDoc.data() ?? {});

      final yesterdayEnabledItems =
          yesterdayItems.where((item) => item.isEnabled).toList();
      if (yesterdayEnabledItems.isEmpty) return;

      final yesterdayCompletedCount = yesterdayEnabledItems
          .where((item) => yesterdayCompletionStatus[item.title] ?? false)
          .length;
      final yesterdayCompletionPercentage =
          (yesterdayCompletedCount / yesterdayEnabledItems.length) * 100;

      // If yesterday's completion was >= 80%, award badge and save
      if (yesterdayCompletionPercentage >= 80) {
        await prefs.setBool('routine_badge_$yesterday', true);
        setState(() => _badgeAwarded = true);

        // Save badge to Firestore
        await FirebaseFirestore.instance
            .collection('userMeals')
            .doc(widget.userId)
            .collection('badges')
            .doc(yesterday)
            .set({
          'type': 'routine',
          'completionPercentage': yesterdayCompletionPercentage,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Show notification using the app's notification service
        await notificationService.showNotification(
          id: 2003,
          title: '🏆 Daily Routine Champion!',
          body:
              'Amazing! You completed ${yesterdayCompletionPercentage.round()}% of your routine yesterday. Keep up the great work! 10 points awarded!',
        );
        await BattleManagement.instance.updateUserPoints(widget.userId, 10);
      }

      // Mark notification as shown for today
      await prefs.setBool('routine_notification_shown_$today', true);
    } catch (e) {
      print('Error checking yesterday completion: $e');
    }
  }

  Future<List<dynamic>> _loadRoutineItems() async {
    final items = await _routineService.getRoutineItems(widget.userId);
    final completionStatus = await _loadCompletionStatus();
    final result = items.map((item) {
      return {
        'item': item,
        'isCompleted': completionStatus[item.title] ?? false,
      };
    }).toList();

    // Check current day completion percentage and update Firestore if needed
    await _checkCurrentDayCompletion(result);

    return result;
  }

  Future<void> _checkCurrentDayCompletion(List<dynamic> items) async {
    final enabledItems = items.where((item) => item['item'].isEnabled).toList();
    if (enabledItems.isEmpty) return;

    final completedCount =
        enabledItems.where((item) => item['isCompleted']).length;
    final completionPercentage = (completedCount / enabledItems.length) * 100;

    // Update completion status in Firestore if percentage is >= 80%
    if (completionPercentage >= 80) {
      await FirebaseFirestore.instance
          .collection('userMeals')
          .doc(widget.userId)
          .collection('routine_completed')
          .doc(widget.date.toIso8601String().split('T')[0])
          .set({
        'completionPercentage': completionPercentage,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<Map<String, bool>> _loadCompletionStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('userMeals')
          .doc(widget.userId)
          .collection('routine_completed')
          .doc(widget.date.toIso8601String().split('T')[0])
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Convert Timestamp values to boolean based on their existence
        return data.map((key, value) => MapEntry(key, value != null));
      }
      return {};
    } catch (e) {
      print('Error loading completion status: $e');
      return {};
    }
  }

  Future<void> _toggleCompletion(String title, bool currentStatus) async {
    if (!getCurrentDate(widget.date)) {
      // Don't allow toggling for past dates
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('userMeals')
          .doc(widget.userId)
          .collection('routine_completed')
          .doc(widget.date.toIso8601String().split('T')[0]);

      // Get current completion status
      final doc = await docRef.get();
      Map<String, dynamic> updatedData = {};

      if (doc.exists) {
        updatedData = doc.data() as Map<String, dynamic>;
      }

      // Update the status for this routine item
      updatedData[title] = !currentStatus;

      // Save the updated data
      await docRef.set(updatedData, SetOptions(merge: true));

      setState(() {
        _routineItems = _loadRoutineItems();
      });
    } catch (e) {
      print('Error toggling completion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return FutureBuilder<List<dynamic>>(
      future: _routineItems,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: 60,
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final items = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isDarkMode
                ? kDarkGrey.withOpacity(0.9)
                : kWhite.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          !_badgeAwarded ? 'Daily Routine' : 'Routine',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 20,
                          color: kAccent,
                          onPressed: () {
                            Get.to(() => const NutritionSettingsPage());
                          },
                          icon: const Icon(Icons.edit),
                        ),
                      ],
                    ),
                  ),
                  if (_badgeAwarded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          if (_badgeAwarded)
                            Icon(Icons.emoji_events, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Routine Champion! - ${DateFormat('d\'th\' MMM').format(DateTime.parse(yesterday))}',
                            style: const TextStyle(
                              color: kAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index]['item'];
                    final isCompleted = items[index]['isCompleted'];

                    if (!item.isEnabled) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => _toggleCompletion(item.title, isCompleted),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? kAccentLight.withOpacity(0.5)
                                : isDarkMode
                                    ? kDarkGrey
                                    : kWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isCompleted
                                  ? kAccentLight.withOpacity(0.5)
                                  : (isDarkMode ? kLightGrey : kDarkGrey),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: isDarkMode ? kWhite : kBlack,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: kAccentLight,
                                decorationThickness: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
