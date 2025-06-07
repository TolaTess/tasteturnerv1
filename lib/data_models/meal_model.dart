import 'package:cloud_firestore/cloud_firestore.dart';

class Meal {
  final String userId;
  final String title;
  final DateTime createdAt;
  final List<String> mediaPaths;
  final int serveQty, calories;
  final Map<String, String> ingredients, macros;
  final List<String> steps;
  final List<String> categories;
  final String mealId;
  final String? mediaType;
  final String? category;

  Meal({
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.mediaPaths,
    required this.serveQty,
    required this.calories,
    this.ingredients = const {},
    this.macros = const {},
    this.steps = const [],
    this.categories = const [],
    this.mealId = '',
    this.mediaType = 'image',
    this.category,
  });

  // Convert Meal instance to a JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'mediaPaths': mediaPaths,
      'serveQty': serveQty,
      'calories': calories,
      'ingredients': ingredients,
      'macros': macros,
      'steps': steps,
      'categories': categories,
      'mediaType': mediaType,
      'category': category,
    };
  }

  // Create a Meal instance from a JSON
  factory Meal.fromJson(String mealId, Map<String, dynamic> json) {
    return Meal(
      userId: json['userId'] as String? ?? '',
      mealId: mealId as String? ?? 'Unknown id',
      title: json['title'] as String? ?? 'Unknown Title',
      createdAt: (json['createdAt'] != null)
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      mediaPaths: List<String>.from(json['mediaPaths'] ?? []),
      serveQty: json['serveQty'] as int? ?? 0,
      calories: json['calories'] as int? ?? 0,
      mediaType: json['mediaType'] as String? ?? 'image',
      ingredients: json['ingredients'] != null
          ? Map<String, String>.from(json['ingredients'] as Map)
          : {},
      macros: json['macros'] != null
          ? Map<String, String>.from(json['macros'] as Map)
          : {},
      steps:
          json['steps'] != null ? List<String>.from(json['steps'] as List) : [],
      categories: json['categories'] != null
          ? List<String>.from(json['categories'] as List)
          : [],
      category: json['category'] as String? ?? '',
    );
  }

  // CopyWith method
  Meal copyWith({
    String? userId,
    String? mealId,
    String? title,
    DateTime? createdAt,
    String? mediaType,
    List<String>? mediaPaths,
    int? serveQty,
    int? calories,
    Map<String, String>? ingredients,
    Map<String, String>? macros,
    List<String>? steps,
    List<String>? categories,
    String? category,
  }) {
    return Meal(
      userId: userId ?? this.userId,
      mealId: mealId ?? this.mealId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      mediaType: mediaType ?? this.mediaType,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      serveQty: serveQty ?? this.serveQty,
      calories: calories ?? this.calories,
      ingredients: ingredients ?? this.ingredients,
      macros: macros ?? this.macros,
      steps: steps ?? this.steps,
      categories: categories ?? this.categories,
      category: category ?? this.category,
    );
  }
}

class MealWithType {
  final Meal meal;
  final String mealType;
  final String familyMember;
  MealWithType(
      {required this.meal, required this.mealType, this.familyMember = ''});

  factory MealWithType.fromMap(Map<String, dynamic> data) {
    return MealWithType(
      meal: Meal.fromJson(data['mealId'], data['meal']),
      mealType: data['mealType'],
      familyMember: data['name'],
    );
  }
}
