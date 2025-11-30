import 'package:flutter_test/flutter_test.dart';
import 'package:tasteturner/helper/utils.dart';
import 'package:tasteturner/helper/helper_functions.dart';

void main() {
  group('Helper Functions Tests', () {
    test('capitalizeFirstLetter capitalizes correctly', () {
      expect(capitalizeFirstLetter('hello'), 'Hello');
      expect(capitalizeFirstLetter('world'), 'World');
      expect(capitalizeFirstLetter(''), '');
      expect(capitalizeFirstLetter('hello world'), 'Hello World');
    });

    test('getMealTimeOfDay returns correct meal time', () {
      // We can't easily mock DateTime.now() without a wrapper or library,
      // so we'll test the logic if we extract it, or just basic sanity check if possible.
      // Since getMealTimeOfDay uses DateTime.now() internally, it's hard to test deterministically
      // without refactoring. For now, we'll skip exact time assertions or refactor later.
      // A better approach for the future is to pass DateTime as an argument.

      final mealTime = getMealTimeOfDay();
      expect(mealTime, isNotEmpty);
      expect(['Breakfast', 'Lunch', 'Dinner'], contains(mealTime));
    });

    test('consolidateGroceryAmounts sums correctly', () {
      final items = [
        {'name': 'tomato', 'amount': '100g'},
        {'name': 'tomato', 'amount': '50g'},
        {'name': 'onion', 'amount': '1 piece'},
      ];

      final result = consolidateGroceryAmounts(items);

      expect(result['tomato'], '150g');
      expect(result['onion'], '1piece'); // regex might be simple
    });

    test('removeAllTextJustNumbers cleans strings', () {
      expect(removeAllTextJustNumbers('100g'), '100');
      expect(removeAllTextJustNumbers('abc123xyz'), '123');
      expect(removeAllTextJustNumbers('10-20'), '20'); // Returns higher number
    });
  });
}
