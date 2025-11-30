import 'package:flutter_test/flutter_test.dart';
import 'package:tasteturner/data_models/program_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Program Model Tests', () {
    test('WeeklyPlan.fromJson parses correctly', () {
      final json = {
        'week': 1,
        'goals': ['Lose weight', 'Eat healthy'],
        'mealPlan': {
          'Monday': ['Oatmeal', 'Salad'],
          'Tuesday': ['Eggs', 'Steak']
        },
        'nutritionGuidelines': {'calories': '2000', 'protein': '150g'},
        'tips': ['Drink water']
      };

      final plan = WeeklyPlan.fromJson(json);

      expect(plan.week, 1);
      expect(plan.goals.length, 2);
      expect(plan.mealPlan['Monday'], contains('Oatmeal'));
      expect(plan.nutritionGuidelines['calories'], '2000');
    });

    test('WeeklyPlan.fromJson handles string meal values', () {
      final json = {
        'week': 1,
        'goals': [],
        'mealPlan': {
          'Monday': 'Oatmeal', // Single string instead of list
        },
        'nutritionGuidelines': {},
        'tips': []
      };

      final plan = WeeklyPlan.fromJson(json);

      expect(plan.mealPlan['Monday'], isA<List<String>>());
      expect(plan.mealPlan['Monday'], contains('Oatmeal'));
    });
  });
}
