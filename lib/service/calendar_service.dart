import 'package:cloud_firestore/cloud_firestore.dart';
import '../data_models/meal_plan_model.dart';

class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user's meal plans
  Stream<QuerySnapshot> getUserMealPlans(String userId) {
    return _firestore
        .collection('mealplans')
        .doc(userId)
        .collection('date')
        .snapshots();
  }

  // Get shared calendars for user
  Stream<QuerySnapshot> getSharedCalendars(String userId) {
    return _firestore
        .collection('shared_calendars')
        .where('userIds', arrayContains: userId)
        .snapshots();
  }

  // Get pending share requests
  Stream<QuerySnapshot> getPendingShareRequests(String userId) {
    return _firestore
        .collection('share_requests')
        .where('recipientId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Add or update meal plan
  Future<void> addOrUpdateMealPlan(
      String userId, String date, MealPlan plan) async {
    await _firestore
        .collection('mealplans')
        .doc(userId)
        .collection('date')
        .doc(date)
        .set(plan.toFirestore());
  }

  // Send share request
  Future<void> sendShareRequest({
    required String senderId,
    required String recipientId,
    required String type,
    String? date,
  }) async {
    final batch = _firestore.batch();

    // Create request document
    final requestRef = _firestore.collection('share_requests').doc();
    final chatRef = _firestore.collection('chats').doc();

    final request = {
      'senderId': senderId,
      'recipientId': recipientId,
      'type': type,
      'date': date,
      'status': 'pending',
      'chatId': chatRef.id,
      'timestamp': FieldValue.serverTimestamp(),
    };

    batch.set(requestRef, request);

    // Create initial chat message
    final messageRef = chatRef.collection('messages').doc();
    final message = {
      'senderId': senderId,
      'content':
          'Want to share my ${type == "entire_calendar" ? "calendar" : "day on $date"}?',
      'requestId': requestRef.id,
      'timestamp': FieldValue.serverTimestamp(),
    };

    batch.set(messageRef, message);

    await batch.commit();
  }

  // Accept share request
  Future<void> acceptShareRequest(String requestId) async {
    final batch = _firestore.batch();

    final requestDoc =
        await _firestore.collection('share_requests').doc(requestId).get();
    final request = requestDoc.data()!;

    // Update request status
    batch.update(requestDoc.reference, {'status': 'accepted'});

    // Create shared calendar
    final calendarRef = _firestore.collection('shared_calendars').doc();
    final calendar = {
      'userIds': [request['senderId'], request['recipientId']],
      'type': request['type'],
      'date': request['date'],
      'createdAt': FieldValue.serverTimestamp(),
    };

    batch.set(calendarRef, calendar);

    // Add acceptance message to chat
    final messageRef = _firestore
        .collection('chats')
        .doc(request['chatId'])
        .collection('messages')
        .doc();

    final message = {
      'senderId': request['recipientId'],
      'content': 'Accepted your calendar share!',
      'requestId': requestId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    batch.set(messageRef, message);

    await batch.commit();
  }

  // Get unified calendar for a date
  Future<List<MealPlan>> getUnifiedCalendar(
      String calendarId, String date) async {
    final calendarDoc =
        await _firestore.collection('shared_calendars').doc(calendarId).get();
    if (!calendarDoc.exists) return [];

    final calendar = SharedCalendar.fromFirestore(calendarDoc);
    if (calendar.type == 'specific_date' && calendar.date != date) return [];

    final List<MealPlan> unifiedPlans = [];
    for (var userId in calendar.userIds) {
      final planDoc = await _firestore
          .collection('mealplans')
          .doc(userId)
          .collection('date')
          .doc(date)
          .get();

      if (planDoc.exists) {
        unifiedPlans.add(MealPlan.fromFirestore(planDoc));
      }
    }

    return unifiedPlans;
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
}
