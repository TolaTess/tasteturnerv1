import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_meal.dart';

class MealPlan {
  final String userId;
  final DateTime date;
  final List<UserMeal> meals;
  final bool isSpecial;
  final String? dayType;
  final DateTime timestamp;

  MealPlan({
    required this.userId,
    required this.date,
    required this.meals,
    this.isSpecial = false,
    this.dayType,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory MealPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPlan(
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      meals: (data['meals'] as List<dynamic>?)
              ?.map((m) => UserMeal.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      isSpecial: data['isSpecial'] ?? false,
      dayType: data['dayType'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'date': Timestamp.fromDate(date),
        'meals': meals.map((m) => m.toFirestore()).toList(),
        'isSpecial': isSpecial,
        'dayType': dayType,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}

class ShareRequest {
  final String requestId;
  final String senderId;
  final String recipientId;
  final String type;
  final String? date;
  final String status;
  final String chatId;
  final DateTime timestamp;

  ShareRequest({
    required this.requestId,
    required this.senderId,
    required this.recipientId,
    required this.type,
    this.date,
    required this.status,
    required this.chatId,
    required this.timestamp,
  });

  factory ShareRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShareRequest(
      requestId: doc.id,
      senderId: data['senderId'] ?? '',
      recipientId: data['recipientId'] ?? '',
      type: data['type'] ?? '',
      date: data['date'],
      status: data['status'] ?? 'pending',
      chatId: data['chatId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'senderId': senderId,
        'recipientId': recipientId,
        'type': type,
        'date': date,
        'status': status,
        'chatId': chatId,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}

class SharedCalendar {
  final String calendarId;
  final List<String> userIds;
  final String type;
  final String? date;
  final DateTime createdAt;
  final String header;

  SharedCalendar({
    required this.calendarId,
    required this.userIds,
    required this.type,
    this.date,
    required this.createdAt,
    required this.header,
  });

  factory SharedCalendar.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedCalendar(
      calendarId: doc.id,
      userIds: List<String>.from(data['userIds'] ?? []),
      type: data['type'] ?? 'entire_calendar',
      date: data['date'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      header: data['header'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userIds': userIds,
        'type': type,
        'date': date,
        'createdAt': Timestamp.fromDate(createdAt),
        'header': header,
      };
}
