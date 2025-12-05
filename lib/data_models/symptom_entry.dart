import 'package:cloud_firestore/cloud_firestore.dart';

class SymptomEntry {
  final String
      type; // e.g., "bloating", "headache", "fatigue", "nausea", "energy", "good"
  final int severity; // 1-5
  final DateTime timestamp;
  final String?
      mealContext; // Which meal (breakfast, lunch, dinner, snack) - deprecated, use mealType instead
  final List<String>
      ingredients; // List of ingredients from meals eaten 2-4 hours before
  final String? mealId; // ID of the meal this symptom is for
  final String?
      instanceId; // Instance ID of the specific meal log (from UserMeal.instanceId)
  final String? mealName; // Name of the meal for display
  final String? mealType; // Type of meal (breakfast, lunch, dinner, snacks)

  SymptomEntry({
    required this.type,
    required this.severity,
    required this.timestamp,
    this.mealContext,
    this.ingredients = const [],
    this.mealId,
    this.instanceId,
    this.mealName,
    this.mealType,
  });

  factory SymptomEntry.fromMap(Map<String, dynamic> json) {
    return SymptomEntry(
      type: json['type'] as String? ?? '',
      severity: (json['severity'] as num?)?.toInt() ?? 1,
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : json['timestamp'] is String
              ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
              : DateTime.now(),
      mealContext: json['mealContext'] as String?,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mealId: json['mealId'] as String?,
      instanceId: json['instanceId'] as String?,
      mealName: json['mealName'] as String?,
      mealType: json['mealType'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'severity': severity,
      'timestamp': Timestamp.fromDate(timestamp),
      if (mealContext != null) 'mealContext': mealContext,
      'ingredients': ingredients,
      if (mealId != null) 'mealId': mealId,
      if (instanceId != null) 'instanceId': instanceId,
      if (mealName != null) 'mealName': mealName,
      if (mealType != null) 'mealType': mealType,
    };
  }
}
