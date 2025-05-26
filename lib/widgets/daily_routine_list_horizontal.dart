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

class RoutineController extends GetxController {
  final String userId;
  final DateTime date;
  final _routineService = RoutineService.instance;
  final RxList<Map<String, dynamic>> routineItems =
      <Map<String, dynamic>>[].obs;
  final RxBool badgeAwarded = false.obs;
  final String today = DateTime.now().toIso8601String().split('T')[0];
  final String yesterday = DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .split('T')[0];

  RoutineController({required this.userId, required this.date});

  @override
  void onInit() {
    super.onInit();
    loadRoutineItems();
    checkYesterdayCompletion();
  }

  bool getCurrentDate(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> checkYesterdayCompletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationShown =
          prefs.getBool('routine_notification_shown_$today') ?? false;
      if (notificationShown) {
        badgeAwarded.value = prefs.getBool('routine_badge_$yesterday') ?? false;
        return;
      }
      final yesterdayDoc = await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine_completed')
          .doc(yesterday)
          .get();
      if (!yesterdayDoc.exists) return;
      final yesterdayItems = await _routineService.getRoutineItems(userId);
      final Map<String, dynamic> rawData = yesterdayDoc.data() ?? {};
      final yesterdayCompletionStatus = rawData.map((key, value) {
        if (value is Timestamp) return MapEntry(key, true);
        if (value is num) return MapEntry(key, value > 0);
        return MapEntry(key, value as bool);
      });
      final yesterdayEnabledItems =
          yesterdayItems.where((item) => item.isEnabled).toList();
      if (yesterdayEnabledItems.isEmpty) return;
      final yesterdayCompletedCount = yesterdayEnabledItems
          .where((item) => yesterdayCompletionStatus[item.title] ?? false)
          .length;
      final yesterdayCompletionPercentage =
          (yesterdayCompletedCount / yesterdayEnabledItems.length) * 100;
      if (yesterdayCompletionPercentage >= 80) {
        await prefs.setBool('routine_badge_$yesterday', true);
        badgeAwarded.value = true;
        await firestore
            .collection('userMeals')
            .doc(userId)
            .collection('badges')
            .doc(yesterday)
            .set({
          'type': 'routine',
          'completionPercentage': yesterdayCompletionPercentage,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await notificationService.showNotification(
          id: 2003,
          title: '🏆 Daily Routine Champion!',
          body:
              'Amazing! You completed ${yesterdayCompletionPercentage.round()}% of your routine yesterday. Keep up the great work! 10 points awarded!',
        );
        await BattleManagement.instance.updateUserPoints(userId, 10);
      }
      await prefs.setBool('routine_notification_shown_$today', true);
    } catch (e) {
      print('Error checking yesterday completion: $e');
    }
  }

  Future<void> loadRoutineItems() async {
    final items = await _routineService.getRoutineItems(userId);
    final completionStatus = await _loadCompletionStatus();
    final result = items.map((item) {
      return {
        'item': item,
        'isCompleted': completionStatus[item.title] ?? false,
      };
    }).toList();
    await _checkCurrentDayCompletion(result);
    routineItems.assignAll(result);
  }

  Future<void> _checkCurrentDayCompletion(List<dynamic> items) async {
    final enabledItems = items.where((item) => item['item'].isEnabled).toList();
    if (enabledItems.isEmpty) return;
    final completedCount =
        enabledItems.where((item) => item['isCompleted']).length;
    final completionPercentage = (completedCount / enabledItems.length) * 100;
    if (completionPercentage >= 80) {
      await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine_completed')
          .doc(date.toIso8601String().split('T')[0])
          .set({
        'completionPercentage': completionPercentage,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<Map<String, bool>> _loadCompletionStatus() async {
    try {
      final doc = await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine_completed')
          .doc(date.toIso8601String().split('T')[0])
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data.map(
            (key, value) => MapEntry(key, value != null && value != false));
      }
      return {};
    } catch (e) {
      print('Error loading completion status: $e');
      return {};
    }
  }

  Future<void> toggleCompletion(String title, bool currentStatus) async {
    if (!getCurrentDate(date)) {
      return;
    }
    try {
      final docRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('routine_completed')
          .doc(date.toIso8601String().split('T')[0]);
      final doc = await docRef.get();
      Map<String, dynamic> updatedData = {};
      if (doc.exists) {
        updatedData = doc.data() as Map<String, dynamic>;
      }
      updatedData[title] = !(currentStatus == true);
      await docRef.set(updatedData, SetOptions(merge: true));
      await loadRoutineItems();
    } catch (e) {
      print('Error toggling completion: $e');
    }
  }
}

class DailyRoutineListHorizontal extends StatelessWidget {
  final String userId;
  final DateTime date;
  const DailyRoutineListHorizontal(
      {Key? key, required this.userId, required this.date})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final RoutineController controller = Get.put(
        RoutineController(userId: userId, date: date),
        tag: '$userId-${date.toIso8601String()}');
    return Obx(() {
      final items = controller.routineItems;
      final _badgeAwarded = controller.badgeAwarded.value;
      if (items.isEmpty) {
        return SizedBox(
          height: getPercentageHeight(6.5, context),
          child: Center(child: CircularProgressIndicator(color: kAccent)),
        );
      }
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color:
              isDarkMode ? kDarkGrey.withOpacity(0.9) : kWhite.withOpacity(0.9),
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
                        style: TextStyle(
                          fontSize: getPercentageWidth(4, context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: getPercentageHeight(0.5, context)),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: getPercentageWidth(5, context),
                        color: kAccentLight.withOpacity(0.8),
                        onPressed: () async {
                          await Get.to(() => const NutritionSettingsPage(
                                isRoutineExpand: true,
                              ));
                          controller.loadRoutineItems();
                        },
                        icon: const Icon(Icons.edit),
                      ),
                    ],
                  ),
                ),
                if (_badgeAwarded)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (_badgeAwarded)
                          Icon(
                            Icons.emoji_events,
                            color: kAccentLight.withOpacity(0.8),
                            size: getPercentageWidth(5, context),
                          ),
                        SizedBox(width: getPercentageHeight(0.5, context)),
                        Text(
                          'Routine Champion! - ${DateFormat('d\'th\' MMM').format(DateTime.parse(controller.yesterday))}',
                          style: TextStyle(
                            color: kAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: getPercentageWidth(3, context),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            SizedBox(
              height: getPercentageHeight(4.5, context),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index]['item'];
                  final isCompleted = items[index]['isCompleted'];
                  if (!item.isEnabled) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(0.7, context)),
                    child: InkWell(
                      onTap: () =>
                          controller.toggleCompletion(item.title, isCompleted),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(3, context),
                            vertical: getPercentageHeight(1, context)),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? isDarkMode
                                  ? kLightGrey.withOpacity(0.5)
                                  : kAccentLight.withOpacity(0.5)
                              : isDarkMode
                                  ? kDarkGrey
                                  : kWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCompleted
                                ? isDarkMode
                                    ? kLightGrey.withOpacity(0.5)
                                    : kAccentLight.withOpacity(0.5)
                                : (isDarkMode ? kLightGrey : kDarkGrey),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            capitalizeFirstLetter(item.title),
                            style: TextStyle(
                              color: isDarkMode ? kWhite : kBlack,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor:
                                  isDarkMode ? kWhite : kAccentLight,
                              decorationThickness: 2,
                              fontSize: getPercentageWidth(3, context),
                              fontWeight: FontWeight.w600,
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
    });
  }
}
