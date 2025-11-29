import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyPlan {
  final int week;
  final List<String> goals;
  final Map<String, List<String>> mealPlan;
  final Map<String, String> nutritionGuidelines;
  final List<String> tips;

  WeeklyPlan({
    required this.week,
    required this.goals,
    required this.mealPlan,
    required this.nutritionGuidelines,
    required this.tips,
  });

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) {
    // Safely parse mealPlan with type checking
    Map<String, List<String>> mealPlan = {};
    if (json['mealPlan'] != null) {
      final mealPlanData = json['mealPlan'];
      if (mealPlanData is Map) {
        mealPlan = Map<String, List<String>>.from(
          mealPlanData.map(
            (key, value) {
              // Ensure key is String
              final dayKey = key.toString();
              
              // Ensure value is a List
              if (value is List) {
                return MapEntry(dayKey, List<String>.from(value.map((item) => item.toString())));
              } else if (value is String) {
                // Handle case where value is a single string instead of list
                return MapEntry(dayKey, [value]);
              } else {
                // Fallback: convert to list with string representation
                return MapEntry(dayKey, [value.toString()]);
              }
            },
          ),
        );
      } else {
        throw Exception('WeeklyPlan.fromJson: mealPlan must be a Map, got ${mealPlanData.runtimeType}');
      }
    }

    // Safely parse nutritionGuidelines
    Map<String, String> nutritionGuidelines = {};
    if (json['nutritionGuidelines'] != null) {
      final guidelinesData = json['nutritionGuidelines'];
      if (guidelinesData is Map) {
        nutritionGuidelines = Map<String, String>.from(
          guidelinesData.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }
    }

    return WeeklyPlan(
      week: json['week'] is int ? json['week'] : (int.tryParse(json['week'].toString()) ?? 1),
      goals: json['goals'] != null && json['goals'] is List
          ? List<String>.from(json['goals'].map((item) => item.toString()))
          : [],
      mealPlan: mealPlan,
      nutritionGuidelines: nutritionGuidelines,
      tips: json['tips'] != null && json['tips'] is List
          ? List<String>.from(json['tips'].map((item) => item.toString()))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'week': week,
      'goals': goals,
      'mealPlan': mealPlan,
      'nutritionGuidelines': nutritionGuidelines,
      'tips': tips,
    };
  }
}

class Program {
  final String programId;
  final String type;
  final String name;
  final String description;
  final String duration;
  final List<WeeklyPlan> weeklyPlans;
  final List<String> requirements;
  final List<String> recommendations;
  final String userId;
  final DateTime createdAt;
  final DateTime startDate;
  final bool isActive;
  final List<String> benefits;
  final List<String> notAllowed;
  final List<String> programDetails;
  final Map<String, dynamic> portionDetails;
  final bool isPrivate;
  final String? planningConversationId;

  Program({
    required this.programId,
    required this.type,
    required this.name,
    required this.description,
    required this.duration,
    required this.weeklyPlans,
    required this.requirements,
    required this.recommendations,
    required this.userId,
    required this.createdAt,
    required this.startDate,
    this.isActive = true,
    required this.benefits,
    required this.notAllowed,
    required this.programDetails,
    this.portionDetails = const {},
    this.isPrivate = false,
    this.planningConversationId,
  });

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(
      programId: json['programId'] ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      duration: json['duration'] ?? '',
      weeklyPlans: json['weeklyPlans'] != null
          ? (json['weeklyPlans'] as List)
              .map((plan) => WeeklyPlan.fromJson(plan))
              .toList()
          : [],
      requirements: json['requirements'] != null
          ? List<String>.from(json['requirements'])
          : [],
      recommendations: json['recommendations'] != null
          ? List<String>.from(json['recommendations'])
          : [],
      userId: json['userId'] ?? '',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      startDate: json['startDate'] != null
          ? (json['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
      benefits:
          json['benefits'] != null ? List<String>.from(json['benefits']) : [],
      notAllowed: json['notAllowed'] != null
          ? List<String>.from(json['notAllowed'])
          : [],
      programDetails: json['programDetails'] != null
          ? List<String>.from(json['programDetails'])
          : [],
      portionDetails: json['portionDetails'] != null
          ? Map<String, dynamic>.from(json['portionDetails'])
          : {},
      isPrivate: json['isPrivate'] ?? false,
      planningConversationId: json['planningConversationId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'programId': programId,
      'type': type,
      'name': name,
      'description': description,
      'duration': duration,
      'weeklyPlans': weeklyPlans.map((plan) => plan.toJson()).toList(),
      'requirements': requirements,
      'recommendations': recommendations,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'startDate': Timestamp.fromDate(startDate),
      'isActive': isActive,
      'benefits': benefits,
      'notAllowed': notAllowed,
      'programDetails': programDetails,
      'portionDetails': portionDetails,
      'isPrivate': isPrivate,
      if (planningConversationId != null)
        'planningConversationId': planningConversationId,
    };
  }
}
