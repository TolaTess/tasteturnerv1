import '../data_models/user_meal.dart';

/// Model for shared meal plan data
class SharedMealPlan {
  final String date;
  final String userId;
  final List<UserMeal> meals;
  final bool isSpecial;
  final String? dayType;
  final String sharedBy;

  SharedMealPlan({
    required this.date,
    required this.userId,
    required this.meals,
    required this.isSpecial,
    this.dayType,
    required this.sharedBy,
  });
}

