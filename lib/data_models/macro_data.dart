class MacroData {
  String? id = '';
  final String title, type;
  final List<String> mediaPaths;
  final int calories;
  final Map<String, dynamic> macros;
  final List<String> categories;
  final Map<String, dynamic> features;
  final List<String> techniques;
  final Map<String, String> storageOptions;
  final bool isAntiInflammatory;
  bool isSelected;

  MacroData({
    this.id,
    required this.mediaPaths,
    required this.title,
    required this.type,
    this.calories = 0,
    required this.macros,
    required this.categories,
    required this.features,
    this.techniques = const [],
    this.storageOptions = const {},
    this.isAntiInflammatory = false,
    this.isSelected = false,
  });

  // Convert to JSON for storing in Firestore or other NoSQL databases
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaPaths': mediaPaths,
      'title': title,
      'type': type,
      'calories': calories,
      'macros': macros,
      'categories': categories,
      'features': features,
      'techniques': techniques,
      'storageOptions': storageOptions,
      'isAntiInflammatory': isAntiInflammatory,
    };
  }

  // Convert JSON data to MacroData instance
  factory MacroData.fromJson(Map<String, dynamic> json, String id) {
    return MacroData(
      id: id,
      mediaPaths: (json['mediaPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [], // Safely cast to List<String>
      title: json['title'] as String, // Ensure title is String
      type: json['type'] as String, // Ensure type is String
      calories: json['calories'] as int? ?? 0,
      macros: Map<String, dynamic>.from(json['macros'] as Map<dynamic, dynamic>),
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [], // Safely cast
      features:
          Map<String, dynamic>.from(json['features'] as Map<dynamic, dynamic>),
      techniques: (json['techniques'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [], // Safely cast
      storageOptions: json['storageOptions'] != null
          ? Map<String, String>.from(
              json['storageOptions'] as Map<dynamic, dynamic>)
          : {},
      isAntiInflammatory: json['isAntiInflammatory'] as bool? ?? false,
    );
  }
}
