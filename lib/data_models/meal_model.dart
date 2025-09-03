import 'package:cloud_firestore/cloud_firestore.dart';

import '../helper/utils.dart';

class Meal {
  final String userId;
  final String title;
  final String? description, type;
  final DateTime createdAt;
  final List<String> mediaPaths;
  final int serveQty, calories;
  final Map<String, String> ingredients, nutritionalInfo, macros, nutrition;
  final List<String> instructions;
  final List<String> categories;
  final String mealId;
  final String? mediaType;
  final String? category;
  final String? cookingMethod;
  final String? cookingTime;
  final Map<String, dynamic>? suggestions;
  final String? status;

  Meal({
    required this.userId,
    required this.title,
    this.description,
    this.type,
    required this.createdAt,
    required this.mediaPaths,
    required this.serveQty,
    required this.calories,
    this.ingredients = const {},
    this.nutritionalInfo = const {},
    this.macros = const {},
    this.instructions = const [],
    this.categories = const [],
    this.mealId = '',
    this.mediaType = 'image',
    this.category,
    this.cookingMethod,
    this.cookingTime,
    this.nutrition = const {},
    this.suggestions,
    this.status,
  });

  // Convert Meal instance to a JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'description': description ?? '',
      'type': type ?? '',
      'createdAt': Timestamp.fromDate(createdAt),
      'mediaPaths': mediaPaths,
      'serveQty': serveQty,
      'calories': calories,
      'ingredients': ingredients,
      'macros': macros,
      'nutritionalInfo': nutritionalInfo,
      'steps': instructions,
      'instructions': instructions,
      'categories': categories,
      'mediaType': mediaType,
      'category': category,
      'cookingMethod': cookingMethod,
      'cookingTime': cookingTime,
      'nutrition': nutrition,
      'suggestions': suggestions,
      'status': status,
    };
  }

  // Create a Meal instance from a JSON
  factory Meal.fromJson(String mealId, Map<String, dynamic> json) {
    return Meal(
      userId: json['userId'] as String? ?? '',
      mealId: mealId as String? ?? 'Unknown id',
      title: json['title'] as String? ?? 'Unknown Title',
      description: json['description'] as String? ?? 'Unknown Description',
      type: json['type'] as String? ?? '',
      createdAt: (json['createdAt'] != null)
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      mediaPaths: List<String>.from(json['mediaPaths'] ?? []),
      serveQty: json['serveQty'] is int
          ? json['serveQty'] as int
          : int.tryParse(removeAllTextJustNumbers(json['serveQty']?.toString() ?? '0')) ?? 1,
      calories: json['calories'] is int
          ? json['calories'] as int
          : int.tryParse(json['calories']?.toString() ?? '0') ?? 0,
      mediaType: json['mediaType'] as String? ?? 'image',
      ingredients: json['ingredients'] is Map
          ? Map<String, String>.from((json['ingredients'] as Map)
              .map((key, value) => MapEntry(key.toString(), value.toString())))
          : {},
      macros: json['macros'] is Map
          ? Map<String, String>.from((json['macros'] as Map)
              .map((key, value) => MapEntry(key.toString(), value.toString())))
          : {},
      nutritionalInfo: json['nutritionalInfo'] is Map
          ? Map<String, String>.from((json['nutritionalInfo'] as Map)
              .map((key, value) => MapEntry(key.toString(), value.toString())))
          : {},
      nutrition: json['nutrition'] is Map
          ? Map<String, String>.from((json['nutrition'] as Map)
              .map((key, value) => MapEntry(key.toString(), value.toString())))
          : {},
      instructions:
          json['steps'] != null ? List<String>.from(json['steps'] as List) : json['instructions'] != null ? List<String>.from(json['instructions'] as List) : [],
          
      categories: json['categories'] != null
          ? List<String>.from(json['categories'] as List)
          : [],
      category: json['category'] as String? ?? '',
      cookingMethod: json['cookingMethod'] as String? ?? '',
      cookingTime: json['cookingTime'] as String? ?? '',
      suggestions: json['suggestions'] is Map
          ? json['suggestions'] as Map<String, dynamic>
          : {},
      status: json['status'] as String? ?? '',
    );
  }

  // CopyWith method
  Meal copyWith({
    String? userId,
    String? mealId,
    String? title,
    String? description,
    String? type,
    DateTime? createdAt,
    String? mediaType,
    List<String>? mediaPaths,
    int? serveQty,
    int? calories,
    Map<String, String>? ingredients,
    Map<String, String>? macros,
    Map<String, String>? nutritionalInfo,
    List<String>? steps,
    List<String>? categories,
    String? category,
    String? cookingMethod,
    String? cookingTime,
    Map<String, String>? nutrition,
    Map<String, dynamic>? suggestions,
    String? status,
  }) {
    return Meal(
      userId: userId ?? this.userId,
      mealId: mealId ?? this.mealId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      mediaType: mediaType ?? this.mediaType,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      serveQty: serveQty ?? this.serveQty,
      calories: calories ?? this.calories,
      ingredients: ingredients ?? this.ingredients,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      macros: macros ?? this.macros,
      instructions: steps ?? this.instructions,
      categories: categories ?? this.categories,
      category: category ?? this.category,
      cookingMethod: cookingMethod ?? this.cookingMethod,
      cookingTime: cookingTime ?? this.cookingTime,
      nutrition: nutrition ?? this.nutrition,
      suggestions: suggestions ?? this.suggestions,
      status: status ?? this.status,
    );
  }
}

class MealWithType {
  final Meal meal;
  final String mealType;
  final String familyMember;
  final String fullMealId;
  MealWithType(
      {required this.meal,
      required this.mealType,
      this.familyMember = '',
      this.fullMealId = ''});

  factory MealWithType.fromMap(Map<String, dynamic> data) {
    return MealWithType(
      meal: Meal.fromJson(data['mealId'], data['meal']),
      mealType: data['mealType'],
      familyMember: data['name'],
      fullMealId: data['fullMealId'],
    );
  }
}
