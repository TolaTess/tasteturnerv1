/// Utility functions for ingredient normalization and processing
/// 
/// Provides shared functionality for normalizing ingredient names
/// and combining duplicate ingredients across the codebase.
library ingredient_utils;

/// Normalize ingredient name for comparison (lowercase, no spaces, common substitutions)
/// 
/// This function standardizes ingredient names by:
/// - Converting to lowercase
/// - Removing all whitespace
/// - Removing non-word characters
/// - Handling common ingredient name variations (oils, salts)
/// 
/// Example:
/// ```dart
/// normalizeIngredientName('Olive Oil') // Returns 'oliveoil'
/// normalizeIngredientName('Pink Salt') // Returns 'pinksalt'
/// ```
String normalizeIngredientName(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '') // Remove all whitespace
      .replaceAll(RegExp(r'[^\w]'), '') // Remove non-word characters
      .replaceAll('oilolive', 'oliveoil') // Handle oil variations
      .replaceAll('saltpink', 'pinksalt')
      .replaceAll('saltrock', 'rocksalt')
      .replaceAll('saltsea', 'seasalt');
}

/// Combine multiple ingredients with the same normalized name
/// 
/// When multiple ingredients have the same normalized name (e.g., "olive oil" and "Olive Oil"),
/// this function combines them by:
/// - Selecting the most descriptive name (longest with spaces)
/// - Combining quantities if they have the same unit
/// - Returning the first ingredient if quantities can't be combined
/// 
/// Parameters:
/// - [ingredients]: List of ingredient entries (name, amount pairs) to combine
/// 
/// Returns:
/// - A single MapEntry with the best name and combined amount (if possible)
/// 
/// Example:
/// ```dart
/// final ingredients = [
///   MapEntry('Olive Oil', '2 tbsp'),
///   MapEntry('olive oil', '1 tbsp'),
/// ];
/// final combined = combineIngredients(ingredients);
/// // Returns: MapEntry('Olive Oil', '3tbsp')
/// ```
MapEntry<String, String> combineIngredients(
    List<MapEntry<String, String>> ingredients) {
  if (ingredients.isEmpty) {
    throw ArgumentError('Ingredients list cannot be empty');
  }

  // Use the most descriptive name (longest with spaces)
  String bestName = ingredients.first.key;
  for (final ingredient in ingredients) {
    if (ingredient.key.contains(' ') &&
        ingredient.key.length > bestName.length) {
      bestName = ingredient.key;
    }
  }

  // Try to combine quantities if they have the same unit
  final quantities = <double>[];
  String? commonUnit;
  bool canCombine = true;

  for (final ingredient in ingredients) {
    final amount = ingredient.value.toLowerCase().trim();
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z]*)').firstMatch(amount);

    if (match != null) {
      final quantity = double.tryParse(match.group(1) ?? '0') ?? 0;
      final unit = match.group(2) ?? '';

      if (commonUnit == null) {
        commonUnit = unit;
      } else if (commonUnit != unit && unit.isNotEmpty) {
        // Different units, can't combine
        canCombine = false;
        break;
      }
      quantities.add(quantity);
    } else {
      // Can't parse quantity, can't combine
      canCombine = false;
      break;
    }
  }

  if (canCombine && quantities.isNotEmpty) {
    final totalQuantity = quantities.reduce((a, b) => a + b);
    final combinedAmount = commonUnit != null && commonUnit.isNotEmpty
        ? '$totalQuantity$commonUnit'
        : totalQuantity.toString();
    return MapEntry(bestName, combinedAmount);
  } else {
    // Can't combine, use the first one and add a note about additional ingredients
    final firstAmount = ingredients.first.value;
    final additionalCount = ingredients.length - 1;
    final combinedAmount = additionalCount > 0
        ? '$firstAmount (+$additionalCount more)'
        : firstAmount;
    return MapEntry(bestName, combinedAmount);
  }
}

