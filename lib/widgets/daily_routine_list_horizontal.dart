import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../service/battle_service.dart';
import '../service/routine_service.dart';
import 'package:tasteturner/data_models/routine_item.dart';

class RoutineController extends GetxController {
  final String userId;
  final DateTime date;
  final _routineService = RoutineService.instance;
  final RxList<Map<String, dynamic>> routineItems =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
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
        await BattleService.instance.updateUserPoints(userId, 10);
      }
      await prefs.setBool('routine_notification_shown_$today', true);
    } catch (e) {
      print('Error checking yesterday completion: $e');
    }
  }

  Future<void> loadRoutineItems() async {
    isLoading.value = true;
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
    isLoading.value = false;
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
      if (title.contains('Water') && !currentStatus == true) {
        await dailyDataController.updateCurrentWater(
            userId, dailyDataController.targetWater.value.toDouble());
      } else if (title.contains('Water') && currentStatus == true) {
        await dailyDataController.updateCurrentWater(
            userId,
            dailyDataController.targetWater.value.toDouble() -
                dailyDataController.currentWater.value.toDouble());
      }

      if (title.contains('Steps') && !currentStatus == true) {
        await dailyDataController.updateCurrentSteps(
            userId, dailyDataController.targetSteps.value.toDouble());
      } else if (title.contains('Steps') && currentStatus == true) {
        await dailyDataController.updateCurrentSteps(
            userId,
            dailyDataController.targetSteps.value.toDouble() -
                dailyDataController.currentSteps.value.toDouble());
      }

      if ((title.contains('Nutrition') || title.contains('Food')) &&
          !currentStatus == true) {
        dailyDataController.updateAllCalories(
            dailyDataController.eatenCalories.value.toDouble(), true);
      } else if ((title.contains('Nutrition') || title.contains('Food')) &&
          currentStatus == true) {
        dailyDataController.updateAllCalories(
            dailyDataController.eatenCalories.value.toDouble(), false);
      }
      await docRef.set(updatedData, SetOptions(merge: true));
      await loadRoutineItems();
    } catch (e) {
      print('Error toggling completion: $e');
    }
  }
}

class DailyRoutineListHorizontal extends StatefulWidget {
  final String userId;
  final DateTime date;
  final bool isCardStyle;

  const DailyRoutineListHorizontal({
    super.key,
    required this.userId,
    required this.date,
    required this.isCardStyle,
  });

  @override
  State<DailyRoutineListHorizontal> createState() =>
      _DailyRoutineListHorizontalState();
}

class _DailyRoutineListHorizontalState
    extends State<DailyRoutineListHorizontal> {
  late final RoutineController controller;
  late final String controllerTag;

  @override
  void initState() {
    super.initState();
    controllerTag = '${widget.userId}-${widget.date.toIso8601String()}';
    if (Get.isRegistered<RoutineController>(tag: controllerTag)) {
      controller = Get.find<RoutineController>(tag: controllerTag);
    } else {
      controller = Get.put(
          RoutineController(userId: widget.userId, date: widget.date),
          tag: controllerTag);
    }
  }

  @override
  void dispose() {
    Get.delete<RoutineController>(tag: controllerTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: kAccent));
      }

      if (controller.routineItems.isEmpty) {
        return Center(
          child: Text(
            'No routines set. Go to settings to add a routine.',
            style: TextStyle(
              fontSize: getTextScale(3.5, context),
              color: isDarkMode ? kWhite.withOpacity(0.5) : Colors.grey,
            ),
          ),
        );
      }

      final routines = controller.routineItems;

      if (widget.isCardStyle) {
        return _buildCardStyle(context, isDarkMode, routines);
      }
      return _buildOriginalStyle(context, isDarkMode, routines);
    });
  }

  Widget _buildCardStyle(BuildContext context, bool isDarkMode,
      List<Map<String, dynamic>> routines) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: routines.length,
      itemBuilder: (context, index) {
        final routineData = routines[index];
        final item = routineData['item'] as RoutineItem;
        final isCompleted = routineData['isCompleted'] as bool;

        if (!item.isEnabled) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => controller.toggleCompletion(item.title, isCompleted),
          child: Container(
            width: getPercentageWidth(30, context),
            margin: EdgeInsets.only(right: getPercentageWidth(1, context)),
            padding: EdgeInsets.all(getPercentageWidth(1, context)),
            decoration: BoxDecoration(
              color: isCompleted
                  ? kAccent.withOpacity(0.3)
                  : kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: getTextScale(3, context),
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: getPercentageHeight(0.5, context)),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: getTextScale(3, context),
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOriginalStyle(BuildContext context, bool isDarkMode,
      List<Map<String, dynamic>> routines) {
    return SizedBox(
      height: getPercentageHeight(20, context),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: routines.length,
        itemBuilder: (context, index) {
          final routineData = routines[index];
          final item = routineData['item'] as RoutineItem;
          final isCompleted = routineData['isCompleted'] as bool;

          if (!item.isEnabled) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(1, context)),
            child: InkWell(
              onTap: () => controller.toggleCompletion(item.title, isCompleted),
              child: Container(
                width: getPercentageWidth(35, context),
                padding: EdgeInsets.all(getPercentageWidth(3, context)),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? isCompleted
                          ? kLightGrey.withOpacity(0.5)
                          : kDarkGrey
                      : isCompleted
                          ? kAccentLight.withOpacity(0.5)
                          : kWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDarkMode
                        ? isCompleted
                            ? kLightGrey.withOpacity(0.5)
                            : kDarkGrey.withOpacity(0.5)
                        : isCompleted
                            ? kAccentLight.withOpacity(0.5)
                            : kDarkGrey.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: getTextScale(3.5, context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isCompleted)
                          const Icon(
                            Icons.check_circle,
                            color: kAccent,
                          )
                      ],
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    Text(
                      item.value,
                      style: TextStyle(
                        fontSize: getTextScale(4.5, context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
