import 'package:cloud_firestore/cloud_firestore.dart';

class UserMeal {
  final String name; // Example: "Grilled Chicken"
  final String quantity; // Example: "1 1/2 cups"
  final int calories; // Example: 300
  final String mealId; // Can be Meal or MacroData
  final String servings;
  final Map<String, double> macros; // protein, fat, carbs
  final String?
      eatingContext; // e.g., "hunger", "boredom", "stress", "social", "planned", "meal"

  // Decoupled Leftovers - Batch Cooking Support
  final String? originalMealId; // If copied from another date
  final String instanceId; // Unique ID for this specific log instance
  final DateTime? loggedAt; // When this instance was logged
  final bool isInstance; // True if this is a copy/instance

  UserMeal({
    required this.name,
    required this.quantity,
    required this.calories,
    required this.mealId,
    this.servings = '',
    this.macros = const {},
    this.eatingContext,
    this.originalMealId,
    String? instanceId,
    this.loggedAt,
    this.isInstance = false,
  }) : instanceId =
            instanceId ?? DateTime.now().millisecondsSinceEpoch.toString();

  /// Convert UserMeal to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'quantity': quantity,
      'calories': calories,
      'mealId': mealId,
      'servings': servings,
      'macros': macros,
      if (eatingContext != null) 'eatingContext': eatingContext,
      if (originalMealId != null) 'originalMealId': originalMealId,
      'instanceId': instanceId,
      if (loggedAt != null) 'loggedAt': loggedAt!.toIso8601String(),
      'isInstance': isInstance,
    };
  }

  factory UserMeal.fromMap(Map<String, dynamic> data) {
    // Handle macros - convert from dynamic to Map<String, double>
    Map<String, double> macros = {};
    if (data['macros'] != null) {
      final macrosData = data['macros'] as Map<String, dynamic>?;
      if (macrosData != null) {
        macros = macrosData.map((key, value) =>
            MapEntry(key, (value is num) ? value.toDouble() : 0.0));
      }
    }

    // Parse loggedAt timestamp
    DateTime? loggedAt;
    if (data['loggedAt'] != null) {
      if (data['loggedAt'] is String) {
        loggedAt = DateTime.tryParse(data['loggedAt'] as String);
      } else if (data['loggedAt'] is Timestamp) {
        loggedAt = (data['loggedAt'] as Timestamp).toDate();
      }
    }

    return UserMeal(
        name: data['name'],
        quantity: data['quantity'],
        calories: data['calories'],
        mealId: data['mealId'],
        servings: data['servings'],
        macros: macros,
        eatingContext: data['eatingContext'] as String?,
        originalMealId: data['originalMealId'] as String?,
        instanceId: data['instanceId'] as String?,
        loggedAt: loggedAt,
        isInstance: data['isInstance'] as bool? ?? false);
  }

  UserMeal copyWith(Map<String, dynamic> updates) {
    return UserMeal(
        name: updates['name'] ?? name,
        quantity: updates['quantity'] ?? quantity,
        calories: updates['calories'] ?? calories,
        mealId: updates['mealId'] ?? mealId,
        servings: updates['servings'] ?? servings,
        macros: updates['macros'] ?? macros,
        eatingContext: updates['eatingContext'] ?? eatingContext,
        originalMealId: updates['originalMealId'] ?? originalMealId,
        instanceId: updates['instanceId'] ?? instanceId,
        loggedAt: updates['loggedAt'] ?? loggedAt,
        isInstance: updates['isInstance'] ?? isInstance);
  }
}
