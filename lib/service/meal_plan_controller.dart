import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../data_models/meal_model.dart';
import 'meal_manager.dart';

class MealPlanController extends GetxController {
  static MealPlanController instance = Get.find();

  // Reactive data
  final RxMap<DateTime, List<MealWithType>> mealPlans =
      <DateTime, List<MealWithType>>{}.obs;
  final RxMap<DateTime, List<MealWithType>> sharedMealPlans =
      <DateTime, List<MealWithType>>{}.obs;
  final RxMap<DateTime, bool> specialMealDays = <DateTime, bool>{}.obs;
  final RxMap<DateTime, String> dayTypes = <DateTime, String>{}.obs;
  final RxMap<DateTime, List<Map<String, dynamic>>> friendsBirthdays =
      <DateTime, List<Map<String, dynamic>>>{}.obs;

  // Alias for backwards compatibility with existing code
  RxMap<DateTime, List<Map<String, dynamic>>> get birthdays => friendsBirthdays;

  // Configuration
  final RxBool showSharedCalendars = false.obs;
  final RxnString selectedSharedCalendarId = RxnString();
  final RxBool isPersonalCalendar = true.obs;
  final RxBool isLoading = false.obs;

  // Stream subscriptions for cleanup
  StreamSubscription? _mealPlansSubscription;
  StreamSubscription? _sharedCalendarSubscription;

  late final MealManager mealManager;

  @override
  void onInit() {
    super.onInit();
    // Safely get MealManager - create if not found
    try {
      mealManager = Get.find<MealManager>();
    } catch (e) {
      // If not found, put it first (Get.put will return existing if already registered)
      if (!Get.isRegistered<MealManager>()) {
        mealManager = Get.put(MealManager());
      } else {
        // If registered but not found, try finding again
        mealManager = Get.find<MealManager>();
      }
    }
    // Initialize with current user if available
    if (userService.userId != null) {
      startListening();
    }
  }

  @override
  void onClose() {
    _mealPlansSubscription?.cancel();
    _sharedCalendarSubscription?.cancel();
    super.onClose();
  }

  void startListening() {
    final userId = userService.userId;
    if (userId == null || userId.isEmpty) return;

    _setupMealPlansListener();
    _loadFriendsBirthdays();
  }

  void _setupMealPlansListener() {
    _mealPlansSubscription?.cancel();
    _sharedCalendarSubscription?.cancel();

    final userId = userService.userId;
    if (userId == null || userId.isEmpty) return;

    isLoading.value = true;

    if (showSharedCalendars.value && selectedSharedCalendarId.value != null) {
      _listenToSharedCalendar();
    } else {
      _listenToPersonalCalendar();
    }
  }

  void _listenToPersonalCalendar() {
    final userId = userService.userId;
    if (userId == null) return;

    isPersonalCalendar.value = true;

    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
    final startDate = DateTime(
        firstDayOfCurrentMonth.year, firstDayOfCurrentMonth.month - 1, 1);
    final endDate = DateTime(
        firstDayOfCurrentMonth.year, firstDayOfCurrentMonth.month + 2, 0);

    _mealPlansSubscription = firestore
        .collection('mealPlans')
        .doc(userId)
        .collection('date')
        .snapshots()
        .listen((snapshot) async {
      await _processMealPlansSnapshot(snapshot, startDate, endDate);
    }, onError: (error) {
      isLoading.value = false;
    });
  }

  void _listenToSharedCalendar() {
    final calendarId = selectedSharedCalendarId.value;
    if (calendarId == null) return;

    isPersonalCalendar.value = false;

    final now = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
    final startDate = DateTime(
        firstDayOfCurrentMonth.year, firstDayOfCurrentMonth.month - 1, 1);
    final endDate = DateTime(
        firstDayOfCurrentMonth.year, firstDayOfCurrentMonth.month + 2, 0);

    _sharedCalendarSubscription = firestore
        .collection('shared_calendars')
        .doc(calendarId)
        .collection('date')
        .snapshots()
        .listen((snapshot) async {
      await _processMealPlansSnapshot(snapshot, startDate, endDate);
    }, onError: (error) {
      isLoading.value = false;
    });
  }

  Future<void> _processMealPlansSnapshot(
      QuerySnapshot snapshot, DateTime startDate, DateTime endDate) async {
    try {
      // Filter documents by date range
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final dateStr = data?['date'] as String?;
        if (dateStr == null) return false;

        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          return !date.isBefore(startDate) && !date.isAfter(endDate);
        } catch (e) {
          return false;
        }
      }).toList();

      final newMealPlans = <DateTime, List<MealWithType>>{};
      final newSpecialMealDays = <DateTime, bool>{};
      final newDayTypes = <DateTime, String>{};

      for (var doc in filteredDocs) {
        final data = doc.data() as Map<String, dynamic>?;
        final dateStr = data?['date'] as String?;
        if (dateStr == null) continue;

        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          final mealsList = data?['meals'] as List<dynamic>? ?? [];
          final List<MealWithType> mealWithTypes = [];

          for (final item in mealsList) {
            if (item is String && item.contains('/')) {
              final parts = item.split('/');
              final mealId = parts[0];
              String mealType = parts.length > 1 ? parts[1] : '';
              String mealMember = parts.length > 2 ? parts[2] : '';
              
              // Defensive parsing: Handle edge case where format is mealId/familyMemberName (2 parts)
              // Check if second part is a known suffix (bf, lh, dn, sn) or a family member name
              if (parts.length == 2) {
                final secondPart = parts[1].toLowerCase();
                final knownSuffixes = ['bf', 'lh', 'dn', 'sn', 'breakfast', 'lunch', 'dinner', 'snack'];
                if (!knownSuffixes.contains(secondPart)) {
                  // Second part is likely a family member name, not a suffix
                  // Default to 'bf' (breakfast) as per user comment
                  mealType = 'bf';
                  mealMember = parts[1];
                } else {
                  // Second part is a suffix
                  mealType = secondPart;
                  mealMember = '';
                }
              } else if (mealType.isEmpty) {
                // If mealType is empty, default to 'bf' (breakfast) as per user comment
                mealType = 'bf';
              }
              
              final meal = await mealManager.getMealbyMealID(mealId);
              if (meal != null) {
                mealWithTypes.add(MealWithType(
                  meal: meal,
                  mealType: mealType,
                  familyMember: mealMember.toLowerCase(),
                  fullMealId: item,
                ));
              }
            } else {
              final mealId = item;
              final meal = await mealManager.getMealbyMealID(mealId);
              if (meal != null) {
                mealWithTypes.add(MealWithType(
                  meal: meal,
                  mealType: 'bf', // Default to 'bf' (breakfast) when suffix is missing
                  familyMember:
                      userService.currentUser.value?.displayName ?? '',
                  fullMealId: mealId,
                ));
              }
            }
          }

          final isSpecial = data?['isSpecial'] ?? false;
          final dayType = data?['dayType'] ?? 'regular_day';

          if (mealWithTypes.isNotEmpty) {
            newMealPlans[date] = mealWithTypes;
          }
          newDayTypes[date] = dayType;
          if (isSpecial) {
            newSpecialMealDays[date] = true;
          }
        } catch (e) {
          continue;
        }
      }

      // Update reactive maps based on calendar type
      if (isPersonalCalendar.value) {
        mealPlans.value = newMealPlans;
        sharedMealPlans.clear(); // Clear shared data when viewing personal
      } else {
        sharedMealPlans.value = newMealPlans;
        // Keep personal meal plans for comparison/fallback
      }

      specialMealDays.value = newSpecialMealDays;
      dayTypes.value = newDayTypes;
      isLoading.value = false;
    } catch (e) {
      mealPlans.clear();
      sharedMealPlans.clear();
      specialMealDays.clear();
      dayTypes.clear();
      isLoading.value = false;
    }
  }

  Future<void> _loadFriendsBirthdays() async {
    try {
      final userId = userService.userId;
      if (userId == null) return;

      final following = await firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      final now = DateTime.now();
      final currentYear = now.year;
      final newFriendsBirthdays = <DateTime, List<Map<String, dynamic>>>{};

      for (var doc in following.docs) {
        final friendId = doc.id;
        try {
          final friendDoc =
              await firestore.collection('users').doc(friendId).get();
          if (friendDoc.exists) {
            final friendData = friendDoc.data();
            final birthdayStr = friendData?['birthday'] as String?;

            if (birthdayStr != null && birthdayStr.isNotEmpty) {
              final birthday = DateTime.parse(birthdayStr);
              final birthdayThisYear =
                  DateTime(currentYear, birthday.month, birthday.day);

              if (!newFriendsBirthdays.containsKey(birthdayThisYear)) {
                newFriendsBirthdays[birthdayThisYear] = [];
              }

              newFriendsBirthdays[birthdayThisYear]!.add({
                'name': friendData?['displayName'] ?? 'Friend',
                'profileImage': friendData?['profileImage'] ?? '',
                'userId': friendId,
              });
            }
          }
        } catch (e) {
        }
      }

      friendsBirthdays.value = newFriendsBirthdays;
    } catch (e) { 
    }
  }

  // Public methods to control the calendar
  void setShowSharedCalendars(bool show) {
    showSharedCalendars.value = show;
    _setupMealPlansListener();
  }

  void setSelectedSharedCalendar(String? calendarId) {
    selectedSharedCalendarId.value = calendarId;
    if (calendarId != null) {
      showSharedCalendars.value = true;
    }
    _setupMealPlansListener();
  }

  void switchToPersonalCalendar() {
    showSharedCalendars.value = false;
    selectedSharedCalendarId.value = null;
    _setupMealPlansListener();
  }

  // Refresh method for manual refresh
  void refresh() {
    _setupMealPlansListener();
    _loadFriendsBirthdays();
  }

  // Helper methods to get data
  List<MealWithType> getMealsForDate(DateTime date) {
    return mealPlans[date] ?? [];
  }

  bool isSpecialDay(DateTime date) {
    return specialMealDays[date] ?? false;
  }

  String getDayType(DateTime date) {
    return dayTypes[date] ?? 'regular_day';
  }

  List<Map<String, dynamic>> getFriendsBirthdaysForDate(DateTime date) {
    return friendsBirthdays[date] ?? [];
  }
}
