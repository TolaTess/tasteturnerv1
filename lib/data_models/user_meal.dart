class UserMeal {
  final String name; // Example: "Grilled Chicken"
  final String quantity; // Example: "1 1/2 cups"
  final int calories; // Example: 300
  final String mealId; // Can be Meal or MacroData
  final String servings;

  UserMeal({
    required this.name,
    required this.quantity,
    required this.calories,
    required this.mealId,
    this.servings = '',
  });

  /// Convert UserMeal to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'quantity': quantity,
      'calories': calories,
      'mealId': mealId,
      'servings': servings
    };
  }

  factory UserMeal.fromMap(Map<String, dynamic> data) {
    return UserMeal(
        name: data['name'],
        quantity: data['quantity'],
        calories: data['calories'],
        mealId: data['mealId'],
        servings: data['servings']);
  }

  UserMeal copyWith(Map<String, dynamic> updates) {
    return UserMeal(
        name: updates['name'] ?? name,
        quantity: updates['quantity'] ?? quantity,
        calories: updates['calories'] ?? calories,
        mealId: updates['mealId'] ?? mealId,
        servings: updates['servings'] ?? servings);
  }
}
