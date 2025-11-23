import 'package:cloud_firestore/cloud_firestore.dart';

class HealthJournalEntry {
  final String date;
  final JournalSummary summary;
  final JournalData data;
  final List<String> userNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  HealthJournalEntry({
    required this.date,
    required this.summary,
    required this.data,
    required this.userNotes,
    required this.createdAt,
    this.updatedAt,
  });

  factory HealthJournalEntry.fromFirestore(String date, Map<String, dynamic> json) {
    return HealthJournalEntry(
      date: date,
      summary: JournalSummary.fromMap(json['summary'] as Map<String, dynamic>? ?? {}),
      data: JournalData.fromMap(json['data'] as Map<String, dynamic>? ?? {}),
      userNotes: (json['userNotes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'summary': summary.toMap(),
      'data': data.toMap(),
      'userNotes': userNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
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

  JournalData({
    required this.nutrition,
    required this.activity,
    required this.meals,
    required this.goals,
  });

  factory JournalData.fromMap(Map<String, dynamic> json) {
    return JournalData(
      nutrition: NutritionData.fromMap(json['nutrition'] as Map<String, dynamic>? ?? {}),
      activity: ActivityData.fromMap(json['activity'] as Map<String, dynamic>? ?? {}),
      meals: MealsData.fromMap(json['meals'] as Map<String, dynamic>? ?? {}),
      goals: GoalsData.fromMap(json['goals'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nutrition': nutrition.toMap(),
      'activity': activity.toMap(),
      'meals': meals.toMap(),
      'goals': goals.toMap(),
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

