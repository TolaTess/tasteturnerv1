// import 'package:cloud_firestore/cloud_firestore.dart';

// class Meal {
//   final String mealId;
//   final String name;
//   final List<String> ingredients;
//   final int calories;

//   Meal({
//     required this.mealId,
//     required this.name,
//     required this.ingredients,
//     required this.calories,
//   });

//   factory Meal.fromFirestore(Map<String, dynamic> data) => Meal(
//         mealId: data['mealId'] ?? '',
//         name: data['name'] ?? '',
//         ingredients: List<String>.from(data['ingredients'] ?? []),
//         calories: data['calories'] ?? 0,
//       );

//   Map<String, dynamic> toFirestore() => {
//         'mealId': mealId,
//         'name': name,
//         'ingredients': ingredients,
//         'calories': calories,
//       };
// }

// class MealPlan {
//   final List<Meal> meals;
//   final bool isSpecial;
//   final String? dayType;
//   final DateTime timestamp;

//   MealPlan({
//     required this.meals,
//     required this.isSpecial,
//     this.dayType,
//     required this.timestamp,
//   });

//   factory MealPlan.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return MealPlan(
//       meals: (data['meals'] as List<dynamic>?)
//               ?.map((m) => Meal.fromFirestore(m as Map<String, dynamic>))
//               .toList() ??
//           [],
//       isSpecial: data['isSpecial'] ?? false,
//       dayType: data['dayType'],
//       timestamp: (data['timestamp'] as Timestamp).toDate(),
//     );
//   }

//   Map<String, dynamic> toFirestore() => {
//         'meals': meals.map((m) => m.toFirestore()).toList(),
//         'isSpecial': isSpecial,
//         'dayType': dayType,
//         'timestamp': Timestamp.fromDate(timestamp),
//       };
// }

// class ShareRequest {
//   final String requestId;
//   final String senderId;
//   final String recipientId;
//   final String type;
//   final String? date;
//   final String status;
//   final String chatId;
//   final DateTime timestamp;

//   ShareRequest({
//     required this.requestId,
//     required this.senderId,
//     required this.recipientId,
//     required this.type,
//     this.date,
//     required this.status,
//     required this.chatId,
//     required this.timestamp,
//   });

//   factory ShareRequest.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return ShareRequest(
//       requestId: doc.id,
//       senderId: data['senderId'] ?? '',
//       recipientId: data['recipientId'] ?? '',
//       type: data['type'] ?? '',
//       date: data['date'],
//       status: data['status'] ?? 'pending',
//       chatId: data['chatId'] ?? '',
//       timestamp: (data['timestamp'] as Timestamp).toDate(),
//     );
//   }

//   Map<String, dynamic> toFirestore() => {
//         'senderId': senderId,
//         'recipientId': recipientId,
//         'type': type,
//         'date': date,
//         'status': status,
//         'chatId': chatId,
//         'timestamp': Timestamp.fromDate(timestamp),
//       };
// }

// class SharedCalendar {
//   final String calendarId;
//   final List<String> userIds;
//   final String type;
//   final String? date;
//   final DateTime createdAt;

//   SharedCalendar({
//     required this.calendarId,
//     required this.userIds,
//     required this.type,
//     this.date,
//     required this.createdAt,
//   });

//   factory SharedCalendar.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return SharedCalendar(
//       calendarId: doc.id,
//       userIds: List<String>.from(data['userIds'] ?? []),
//       type: data['type'] ?? '',
//       date: data['date'],
//       createdAt: (data['createdAt'] as Timestamp).toDate(),
//     );
//   }

//   Map<String, dynamic> toFirestore() => {
//         'userIds': userIds,
//         'type': type,
//         'date': date,
//         'createdAt': Timestamp.fromDate(createdAt),
//       };
// }
