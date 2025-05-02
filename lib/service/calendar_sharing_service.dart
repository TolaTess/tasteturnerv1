import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../data_models/meal_plan_model.dart';
import '../data_models/user_meal.dart';
import 'package:intl/intl.dart';

class CalendarSharingService extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Observable lists for real-time updates
  final RxList<ShareRequest> shareRequests = <ShareRequest>[].obs;
  final RxList<SharedCalendar> sharedCalendars = <SharedCalendar>[].obs;

  // // Get user's meal plans for a specific date
  // Future<MealPlan?> getUserMealPlan(String userId, DateTime date) async {
  //   try {
  //     final dateStr = DateFormat('yyyy-MM-dd').format(date);
  //     final doc = await _firestore
  //         .collection('mealPlans')
  //         .doc(userId)
  //         .collection('date')
  //         .doc(dateStr)
  //         .get();

  //     if (!doc.exists) return null;
  //     return MealPlan.fromFirestore(doc);
  //   } catch (e) {
  //     print('Error getting meal plan: $e');
  //     return null;
  //   }
  // }

  // Get shared calendars for user
  Stream<List<SharedCalendar>> getSharedCalendars(String userId) {
    print('getSharedCalendars: $userId');
    return _firestore
        .collection('shared_calendars')
        .where('userIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SharedCalendar.fromFirestore(doc))
            .toList());
  }

  // // Get pending share requests
  // Stream<List<ShareRequest>> getPendingShareRequests(String userId) {
  //   return _firestore
  //       .collection('share_requests')
  //       .where('recipientId', isEqualTo: userId)
  //       .where('status', isEqualTo: 'pending')
  //       .snapshots()
  //       .map((snapshot) => snapshot.docs
  //           .map((doc) => ShareRequest.fromFirestore(doc))
  //           .toList());
  // }

  // // Send share request
  // Future<void> sendShareRequest({
  //   required String senderId,
  //   required String recipientId,
  //   required String type,
  //   String? date,
  // }) async {
  //   final batch = _firestore.batch();

  //   // Create request document
  //   final requestRef = _firestore.collection('share_requests').doc();
  //   final chatRef = _firestore.collection('chats').doc();

  //   final request = {
  //     'senderId': senderId,
  //     'recipientId': recipientId,
  //     'type': type,
  //     'date': date,
  //     'status': 'pending',
  //     'chatId': chatRef.id,
  //     'timestamp': FieldValue.serverTimestamp(),
  //   };

  //   batch.set(requestRef, request);

  //   // Create initial chat message
  //   final messageRef = chatRef.collection('messages').doc();
  //   final message = {
  //     'senderId': senderId,
  //     'content':
  //         'Want to share my ${type == "entire_calendar" ? "calendar" : "day on $date"}?',
  //     'requestId': requestRef.id,
  //     'timestamp': FieldValue.serverTimestamp(),
  //   };

  //   batch.set(messageRef, message);

  //   await batch.commit();
  // }

  // // Accept share request
  // Future<void> acceptShareRequest(String requestId) async {
  //   final batch = _firestore.batch();

  //   final requestDoc =
  //       await _firestore.collection('share_requests').doc(requestId).get();
  //   if (!requestDoc.exists) throw Exception('Share request not found');

  //   final request = requestDoc.data()!;

  //   // Update request status
  //   batch.update(requestDoc.reference, {'status': 'accepted'});

  //   // Create shared calendar
  //   final calendarRef = _firestore.collection('shared_calendars').doc();
  //   final calendar = {
  //     'userIds': [request['senderId'], request['recipientId']],
  //     'type': request['type'],
  //     'date': request['date'],
  //     'createdAt': FieldValue.serverTimestamp(),
  //   };

  //   batch.set(calendarRef, calendar);

  //   // Add acceptance message to chat
  //   final messageRef = _firestore
  //       .collection('chats')
  //       .doc(request['chatId'])
  //       .collection('messages')
  //       .doc();

  //   final message = {
  //     'senderId': request['recipientId'],
  //     'content': 'Accepted your calendar share!',
  //     'requestId': requestId,
  //     'timestamp': FieldValue.serverTimestamp(),
  //   };

  //   batch.set(messageRef, message);

  //   await batch.commit();
  // }

  // // Share calendar with users
  // Future<void> shareCalendarWithUsers({
  //   required String ownerId,
  //   required List<String> userIds,
  // }) async {
  //   try {
  //     // Check if owner already has a shared calendar
  //     final existingCalendarsQuery = await _firestore
  //         .collection('shared_calendars')
  //         .where('ownerId', isEqualTo: ownerId)
  //         .get();

  //     DocumentReference calendarRef;

  //     if (existingCalendarsQuery.docs.isNotEmpty) {
  //       // Update existing calendar
  //       calendarRef = existingCalendarsQuery.docs.first.reference;
  //       await calendarRef.update({
  //         'userIds': FieldValue.arrayUnion(userIds),
  //       });
  //     } else {
  //       // Create new shared calendar
  //       calendarRef = _firestore.collection('shared_calendars').doc();
  //       await calendarRef.set({
  //         'ownerId': ownerId,
  //         'userIds': [ownerId, ...userIds],
  //         'createdAt': FieldValue.serverTimestamp(),
  //       });
  //     }
  //   } catch (e) {
  //     print('Error sharing calendar: $e');
  //     throw e;
  //   }
  // }

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
          await _firestore.collection('shared_calendars').doc(calendarId).get();
      if (!calendarDoc.exists) throw Exception('Shared calendar not found');

      final calendar = SharedCalendar.fromFirestore(calendarDoc);
      if (!calendar.userIds.contains(userId))
        throw Exception('User not authorized');

      // Update the meal plan in the shared calendar
      await _firestore
          .collection('shared_calendars')
          .doc(calendarId)
          .collection('date')
          .doc(date)
          .set({
        'meals': meals.map((m) => m.toFirestore()).toList(),
        'isSpecial': isSpecial,
        'dayType': dayType,
        'lastUpdatedBy': userId,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
          await _firestore.collection('shared_calendars').doc(calendarId).get();
      if (!calendarDoc.exists) return {};

      final calendar = SharedCalendar.fromFirestore(calendarDoc);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final Map<String, dynamic> unifiedCalendar = {};

      for (var userId in calendar.userIds) {
        final planDoc = await _firestore
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
      await _firestore.collection('shared_calendars').doc(calendarId).update({
        'userIds': FieldValue.arrayRemove(userIds),
      });
    } catch (e) {
      print('Error removing users from calendar: $e');
      throw e;
    }
  }

  // Get chat messages
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore
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
    final query = await _firestore
        .collection('shared_calendars')
        .where('userIds', arrayContains: userId)
        .get();
    return query.docs.map((doc) => SharedCalendar.fromFirestore(doc)).toList();
  }

  Future<Map<String, List<UserMeal>>> fetchSharedMealsForCalendarAndDate(
      String calendarId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final doc = await _firestore
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
    print('fetchMealsByDateForCalendar: $calendarId');
    final querySnapshot = await _firestore
        .collection('shared_calendars')
        .doc(calendarId)
        .collection('date')
        .get();
    print('querySnapshot: ${querySnapshot.docs.length}');
    if (querySnapshot.docs.isEmpty) return {};

    final result = <String, List<UserMeal>>{};

    for (var doc in querySnapshot.docs) {
      print('doc: ${doc.id}');
      final data = doc.data();
      final meals = (data['meals'] as List<dynamic>?)
              ?.map((m) => UserMeal.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [];
      result[doc.id] = meals; // doc.id is the date string
      print('meals: ${meals.length}');
    }
    print('result: ${result.length}');
    print('result: ${result.keys}');
    return result;
  }
}
