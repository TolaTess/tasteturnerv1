import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/meal_plan_model.dart';
import '../data_models/user_meal.dart';
import 'package:intl/intl.dart';

class CalendarSharingService extends GetxController {
  static CalendarSharingService instance = Get.find();
  // Observable lists for real-time updates
  final RxList<ShareRequest> shareRequests = <ShareRequest>[].obs;
  final RxList<SharedCalendar> sharedCalendars = <SharedCalendar>[].obs;

  // Get shared calendars for user
  Stream<List<SharedCalendar>> getSharedCalendars(String userId) {
    print('getSharedCalendars: $userId');
    return firestore
        .collection('shared_calendars')
        .where('userIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedCalendar.fromFirestore(doc))
            .toList());
  }

  // Add or update meal in shared calendar
  Future<void> addOrUpdateSharedMeal({
    required String calendarId,
    required String userId,
    required String date,
    required List<UserMeal> meals,
    bool isSpecial = false,
    String? dayType,
  }) async {
    try {
      final calendarDoc =
          await firestore.collection('shared_calendars').doc(calendarId).get();
      if (!calendarDoc.exists) throw Exception('Shared calendar not found');

      final calendar = SharedCalendar.fromFirestore(calendarDoc);
      if (!calendar.userIds.contains(userId))
        throw Exception('User not authorized');

      // Update the meal plan in the shared calendar
      await newSharedCalendar(calendarId, userId, date, meals, isSpecial,
          dayType ?? '');
    } catch (e) {
      print('Error adding/updating shared meal: $e');
      throw e;
    }
  }

  // Get unified calendar for a date
  Future<Map<String, dynamic>> getUnifiedCalendar(
      String calendarId, DateTime date) async {
    try {
      final calendarDoc =
          await firestore.collection('shared_calendars').doc(calendarId).get();
      if (!calendarDoc.exists) return {};

      final calendar = SharedCalendar.fromFirestore(calendarDoc);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final Map<String, dynamic> unifiedCalendar = {};

      for (var userId in calendar.userIds) {
        final planDoc = await firestore
            .collection('mealPlans')
            .doc(userId)
            .collection('date')
            .doc(dateStr)
            .get();

        if (planDoc.exists) {
          final data = planDoc.data()!;
          unifiedCalendar[userId] = {
            'meals': data['meals'] ?? [],
            'isSpecial': data['isSpecial'] ?? false,
            'dayType': data['dayType'],
            'userId': userId,
          };
        }
      }

      return unifiedCalendar;
    } catch (e) {
      print('Error getting unified calendar: $e');
      throw e;
    }
  }

  // Remove users from shared calendar
  Future<void> removeUsersFromCalendar({
    required String calendarId,
    required List<String> userIds,
  }) async {
    try {
      await firestore.collection('shared_calendars').doc(calendarId).update({
        'userIds': FieldValue.arrayRemove(userIds),
      });
    } catch (e) {
      print('Error removing users from calendar: $e');
      throw e;
    }
  }

  Future<void> newSharedCalendar(
      String calendarId,
      String userId,
      String date,
      List<UserMeal> meals,
      bool isSpecial,
      String dayType) async {
    // Update the meal plan in the shared calendar
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
    await firestore
        .collection('shared_calendars')
        .doc(calendarId)
        .collection('date')
        .doc(dateStr)
        .set({
      'meals': meals.map((m) => m.toFirestore()).toList(),
      'isSpecial': isSpecial,
      'dayType': dayType,
      'lastUpdatedBy': userId,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get chat messages
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  void onInit() {
    super.onInit();
    // Initialize listeners if needed
  }

  @override
  void onClose() {
    // Clean up if needed
    super.onClose();
  }

  Future<List<SharedCalendar>> fetchSharedCalendarsForUser(
      String userId) async {
    final query = await firestore
        .collection('shared_calendars')
        .where('userIds', arrayContains: userId)
        .get();
    return query.docs.map((doc) => SharedCalendar.fromFirestore(doc)).toList();
  }

  Future<String> createSharedCalendar(String userId, String header) async {
    final docRef = await firestore.collection('shared_calendars').add({
      'userIds': [userId],
      'header': header,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': userId,
    });
    return docRef.id;
  }

  Future<SharedCalendar?> fetchSharedCalendarById(String calendarId) async {
    final doc = await firestore.collection('shared_calendars').doc(calendarId).get();
    if (!doc.exists) return null;
    return SharedCalendar.fromFirestore(doc);
  }

  // Get meals for a specific date for a shared calendar
  Future<Map<String, List<UserMeal>>> fetchSharedMealsForCalendarAndDate(
      String calendarId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final doc = await firestore
        .collection('shared_calendars')
        .doc(calendarId)
        .collection('date')
        .doc(dateStr)
        .get();
    if (!doc.exists) return {};
    final data = doc.data()!;
    final userId = data['userId'] ?? '';
    final meals = (data['meals'] as List<dynamic>?)
            ?.map((m) => UserMeal.fromMap(m as Map<String, dynamic>))
            .toList() ??
        [];
    return {userId: meals};
  }

  Future<Map<String, List<UserMeal>>> fetchMealsByDateForCalendar(
      String calendarId) async {
    final querySnapshot = await firestore
        .collection('shared_calendars')
        .doc(calendarId)
        .collection('date')
        .get();
    if (querySnapshot.docs.isEmpty) return {};

    final result = <String, List<UserMeal>>{};

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final meals = (data['meals'] as List<dynamic>?)
              ?.map((m) => UserMeal.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [];
      result[doc.id] = meals; // doc.id is the date string
    }
    return result;
  }
}
