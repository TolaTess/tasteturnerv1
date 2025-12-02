import 'package:cloud_firestore/cloud_firestore.dart';

class HealthJournalEntry {
  final String weekId; // Format: "2024-W01" (ISO week)
  final String date; // Keep for backward compatibility
  final DateTime weekStart;
  final DateTime weekEnd;
  final String status; // 'pending', 'generating', 'completed'
  final DateTime? scheduledFor; // User's preferred generation time
  final JournalSummary summary;
  final JournalData data;
  final List<String> userNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final PlantDiversityData? plantDiversity;

  HealthJournalEntry({
    required this.weekId,
    String? date, // Optional for backward compatibility
    required this.weekStart,
    required this.weekEnd,
    this.status = 'pending',
    this.scheduledFor,
    required this.summary,
    required this.data,
    required this.userNotes,
    required this.createdAt,
    this.updatedAt,
    this.plantDiversity,
  }) : date = date ?? weekId; // Use weekId as fallback for date

  factory HealthJournalEntry.fromFirestore(String weekId, Map<String, dynamic> json) {
    return HealthJournalEntry(
      weekId: weekId,
      date: json['date'] as String? ?? weekId,
      weekStart: (json['weekStart'] as Timestamp?)?.toDate() ??
          (json['date'] != null
              ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
              : DateTime.now()),
      weekEnd: (json['weekEnd'] as Timestamp?)?.toDate() ??
          ((json['weekStart'] as Timestamp?)?.toDate() != null
              ? (json['weekStart'] as Timestamp).toDate().add(const Duration(days: 6))
              : DateTime.now().add(const Duration(days: 6))),
      status: json['status'] as String? ?? 'pending',
      scheduledFor: (json['scheduledFor'] as Timestamp?)?.toDate(),
      summary: JournalSummary.fromMap(json['summary'] as Map<String, dynamic>? ?? {}),
      data: JournalData.fromMap(json['data'] as Map<String, dynamic>? ?? {}),
      userNotes: (json['userNotes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      plantDiversity: json['plantDiversity'] != null
          ? PlantDiversityData.fromMap(json['plantDiversity'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'weekId': weekId,
      'date': date, // Keep for backward compatibility
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'status': status,
      if (scheduledFor != null) 'scheduledFor': Timestamp.fromDate(scheduledFor!),
      'summary': summary.toMap(),
      'data': data.toMap(),
      'userNotes': userNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (plantDiversity != null) 'plantDiversity': plantDiversity!.toMap(),
    };
  }
}

class JournalSummary {
  final String narrative;
  final List<String> highlights;
  final List<String> insights;
  final List<String> suggestions;

  JournalSummary({
    required this.narrative,
    required this.highlights,
    required this.insights,
    required this.suggestions,
  });

  factory JournalSummary.fromMap(Map<String, dynamic> json) {
    return JournalSummary(
      narrative: json['narrative'] as String? ?? '',
      highlights: (json['highlights'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      insights: (json['insights'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      suggestions: (json['suggestions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'narrative': narrative,
      'highlights': highlights,
      'insights': insights,
      'suggestions': suggestions,
    };
  }
}

class JournalData {
  final NutritionData nutrition;
  final ActivityData activity;
  final MealsData meals;
  final GoalsData goals;
  final List<SymptomEntry> symptoms;
  final List<SymptomCorrelation> symptomCorrelations;

  JournalData({
    required this.nutrition,
    required this.activity,
    required this.meals,
    required this.goals,
    this.symptoms = const [],
    this.symptomCorrelations = const [],
  });

  factory JournalData.fromMap(Map<String, dynamic> json) {
    return JournalData(
      nutrition: NutritionData.fromMap(json['nutrition'] as Map<String, dynamic>? ?? {}),
      activity: ActivityData.fromMap(json['activity'] as Map<String, dynamic>? ?? {}),
      meals: MealsData.fromMap(json['meals'] as Map<String, dynamic>? ?? {}),
      goals: GoalsData.fromMap(json['goals'] as Map<String, dynamic>? ?? {}),
      symptoms: (json['symptoms'] as List<dynamic>?)
          ?.map((e) => SymptomEntry.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      symptomCorrelations: (json['symptomCorrelations'] as List<dynamic>?)
          ?.map((e) => SymptomCorrelation.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nutrition': nutrition.toMap(),
      'activity': activity.toMap(),
      'meals': meals.toMap(),
      'goals': goals.toMap(),
      'symptoms': symptoms.map((s) => s.toMap()).toList(),
      'symptomCorrelations': symptomCorrelations.map((c) => c.toMap()).toList(),
    };
  }
}

class NutritionData {
  final MacroData calories;
  final MacroData protein;
  final MacroData carbs;
  final MacroData fat;

  NutritionData({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory NutritionData.fromMap(Map<String, dynamic> json) {
    return NutritionData(
      calories: MacroData.fromMap(json['calories'] as Map<String, dynamic>? ?? {}),
      protein: MacroData.fromMap(json['protein'] as Map<String, dynamic>? ?? {}),
      carbs: MacroData.fromMap(json['carbs'] as Map<String, dynamic>? ?? {}),
      fat: MacroData.fromMap(json['fat'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calories': calories.toMap(),
      'protein': protein.toMap(),
      'carbs': carbs.toMap(),
      'fat': fat.toMap(),
    };
  }
}

class MacroData {
  final double consumed;
  final double goal;
  final double progress;

  MacroData({
    required this.consumed,
    required this.goal,
    required this.progress,
  });

  factory MacroData.fromMap(Map<String, dynamic> json) {
    return MacroData(
      consumed: (json['consumed'] as num?)?.toDouble() ?? 0.0,
      goal: (json['goal'] as num?)?.toDouble() ?? 0.0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'consumed': consumed,
      'goal': goal,
      'progress': progress,
    };
  }
}

class ActivityData {
  final MacroData water;
  final MacroData steps;
  final double routineCompletion;

  ActivityData({
    required this.water,
    required this.steps,
    required this.routineCompletion,
  });

  factory ActivityData.fromMap(Map<String, dynamic> json) {
    return ActivityData(
      water: MacroData.fromMap(json['water'] as Map<String, dynamic>? ?? {}),
      steps: MacroData.fromMap(json['steps'] as Map<String, dynamic>? ?? {}),
      routineCompletion: (json['routineCompletion'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'water': water.toMap(),
      'steps': steps.toMap(),
      'routineCompletion': routineCompletion,
    };
  }
}

class MealsData {
  final List<String> breakfast;
  final List<String> lunch;
  final List<String> dinner;
  final List<String> snacks;

  MealsData({
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snacks,
  });

  factory MealsData.fromMap(Map<String, dynamic> json) {
    return MealsData(
      breakfast: (json['breakfast'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      lunch: (json['lunch'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      dinner: (json['dinner'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      snacks: (json['snacks'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'snacks': snacks,
    };
  }
}

class GoalsData {
  final MacroData calories;
  final MacroData protein;
  final MacroData carbs;
  final MacroData fat;

  GoalsData({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory GoalsData.fromMap(Map<String, dynamic> json) {
    return GoalsData(
      calories: MacroData.fromMap(json['calories'] as Map<String, dynamic>? ?? {}),
      protein: MacroData.fromMap(json['protein'] as Map<String, dynamic>? ?? {}),
      carbs: MacroData.fromMap(json['carbs'] as Map<String, dynamic>? ?? {}),
      fat: MacroData.fromMap(json['fat'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calories': calories.toMap(),
      'protein': protein.toMap(),
      'carbs': carbs.toMap(),
      'fat': fat.toMap(),
    };
  }
}

class SymptomEntry {
  final String type; // e.g., "bloating", "headache", "fatigue", "nausea", "energy", "good"
  final int severity; // 1-5
  final DateTime timestamp;
  final String? mealContext; // Which meal (breakfast, lunch, dinner, snack)
  final List<String> ingredients; // List of ingredients from meals eaten 2-4 hours before

  SymptomEntry({
    required this.type,
    required this.severity,
    required this.timestamp,
    this.mealContext,
    this.ingredients = const [],
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
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'severity': severity,
      'timestamp': Timestamp.fromDate(timestamp),
      if (mealContext != null) 'mealContext': mealContext,
      'ingredients': ingredients,
    };
  }
}

class SymptomCorrelation {
  final String ingredient;
  final String symptom;
  final double frequency; // How many times this correlation occurred
  final double confidence; // 0.0 to 1.0

  SymptomCorrelation({
    required this.ingredient,
    required this.symptom,
    required this.frequency,
    required this.confidence,
  });

  factory SymptomCorrelation.fromMap(Map<String, dynamic> json) {
    return SymptomCorrelation(
      ingredient: json['ingredient'] as String? ?? '',
      symptom: json['symptom'] as String? ?? '',
      frequency: (json['frequency'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ingredient': ingredient,
      'symptom': symptom,
      'frequency': frequency,
      'confidence': confidence,
    };
  }
}

class PlantDiversityData {
  final int uniquePlants;
  final int level; // 1-3 (10, 20, 30+)
  final double progress; // 0.0 to 1.0
  final Map<String, int> categoryBreakdown; // category name -> count
  final List<String> plantNames;

  PlantDiversityData({
    required this.uniquePlants,
    required this.level,
    required this.progress,
    required this.categoryBreakdown,
    required this.plantNames,
  });

  factory PlantDiversityData.fromMap(Map<String, dynamic> json) {
    return PlantDiversityData(
      uniquePlants: (json['uniquePlants'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      categoryBreakdown: json['categoryBreakdown'] is Map
          ? Map<String, int>.from(
              (json['categoryBreakdown'] as Map).map(
                (key, value) => MapEntry(
                  key.toString(),
                  (value as num?)?.toInt() ?? 0,
                ),
              ),
            )
          : {},
      plantNames: (json['plantNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uniquePlants': uniquePlants,
      'level': level,
      'progress': progress,
      'categoryBreakdown': categoryBreakdown,
      'plantNames': plantNames,
    };
  }
}

