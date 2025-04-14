class IngredientData {
  final String title;
  final String servingSize;
  final String ingredients;
  final Map<String, String> macros;
  final Map<String, String> features;
  final String? barcode;
  final List<String> mediaPaths;

  IngredientData({
    required this.title,
    required this.mediaPaths,
    required this.servingSize,
    required this.ingredients,
    required this.macros,
    required this.features,
    this.barcode,
  });

  // Create from API response
  factory IngredientData.fromJson(Map<String, dynamic> json) {
    return IngredientData(
      title: json['title'] ?? 'Unknown',
      mediaPaths: json['mediaPaths'] ?? [],
      servingSize: json['servingSize'] ?? '',
      ingredients: json['ingredients'] ?? '',
      macros: Map<String, String>.from(json['macros'] ?? {}),
      features: Map<String, String>.from(json['features'] ?? {}),
      barcode: json['code'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'mediaPaths': mediaPaths,
      'servingSize': servingSize,
      'ingredients': ingredients,
      'macros': macros,
      'features': features,
      'code': barcode,
    };
  }

  // Create a copy with some fields updated
  IngredientData copyWith({
    String? title,
    List<String>? mediaPaths,
    String? servingSize,
    String? ingredients,
    Map<String, String>? macros,
    Map<String, String>? features,
    String? barcode,
  }) {
    return IngredientData(
      title: title ?? this.title,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      servingSize: servingSize ?? this.servingSize,
      ingredients: ingredients ?? this.ingredients,
      macros: macros ?? this.macros,
      features: features ?? this.features,
      barcode: barcode ?? this.barcode,
    );
  }

  // Helper method to get specific macro values
  double getCalories() => double.tryParse(macros['calories'] ?? '0') ?? 0;
  double getProtein() => double.tryParse(macros['protein'] ?? '0') ?? 0;
  double getCarbs() => double.tryParse(macros['carbs'] ?? '0') ?? 0;
  double getFat() => double.tryParse(macros['fat'] ?? '0') ?? 0;
  double getFiber() => double.tryParse(macros['fiber'] ?? '0') ?? 0;

  // Helper method to get brand
  String getBrand() => features['brand'] ?? '';

  // Helper method to get categories
  String getCategories() => features['categories'] ?? '';
}
