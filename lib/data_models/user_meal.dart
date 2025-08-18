class UserMeal {
  final String name; // Example: "Grilled Chicken"
  final String quantity; // Example: "1 1/2 cups"
  final int calories; // Example: 300
  final String mealId; // Can be Meal or MacroData
  final String servings;
  final Map<String, double> macros; // protein, fat, carbs

  UserMeal({
    required this.name,
    required this.quantity,
    required this.calories,
    required this.mealId,
    this.servings = '',
    this.macros = const {},
  });

  /// Convert UserMeal to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'quantity': quantity,
      'calories': calories,
      'mealId': mealId,
      'servings': servings,
      'macros': macros,
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

    return UserMeal(
        name: data['name'],
        quantity: data['quantity'],
        calories: data['calories'],
        mealId: data['mealId'],
        servings: data['servings'],
        macros: macros);
  }

  UserMeal copyWith(Map<String, dynamic> updates) {
    return UserMeal(
        name: updates['name'] ?? name,
        quantity: updates['quantity'] ?? quantity,
        calories: updates['calories'] ?? calories,
        mealId: updates['mealId'] ?? mealId,
        servings: updates['servings'] ?? servings,
        macros: updates['macros'] ?? macros);
  }
}
