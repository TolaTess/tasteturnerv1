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
  final List<String> alt;
  final String image;

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
    this.alt = const [],
    this.image = '',
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
      'alt': alt,
      'image': image,
    };
  }

  // Convert JSON data to MacroData instance
  factory MacroData.fromJson(Map<String, dynamic> json, String id) {
    return MacroData(
      id: id,
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      mediaPaths:
          (json['mediaPaths'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      macros: Map<String, dynamic>.from(json['macros'] ?? {}),
      categories:
          (json['categories'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      features: Map<String, dynamic>.from(json['features'] ?? {}),
      calories: json['calories'] as int? ?? 0,
      techniques: (json['techniques'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [], // Safely cast
      storageOptions: json['storageOptions'] != null
          ? Map<String, String>.from(
              json['storageOptions'] as Map<dynamic, dynamic>)
          : {},
      isAntiInflammatory: json['isAntiInflammatory'] as bool? ?? false,
      isSelected: json['isSelected'] as bool? ?? false,
      alt: (json['alt'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [], // Safely cast
      image: json['image'] ?? '',
    );
  }

  MacroData copyWith({
    String? id,
    String? title,
    String? type,
    List<String>? mediaPaths,
    int? calories,
    Map<String, dynamic>? macros,
    List<String>? categories,
    Map<String, dynamic>? features,
    List<String>? techniques,
    Map<String, String>? storageOptions,
    bool? isAntiInflammatory,
    bool? isSelected,
    List<String>? alt,
    String? image,
  }) {
    return MacroData(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      calories: calories ?? this.calories,
      macros: macros ?? this.macros,
      categories: categories ?? this.categories,
      features: features ?? this.features,
      techniques: techniques ?? this.techniques,
      storageOptions: storageOptions ?? this.storageOptions,
      isAntiInflammatory: isAntiInflammatory ?? this.isAntiInflammatory,
      isSelected: isSelected ?? this.isSelected,
      alt: alt ?? this.alt,
      image: image ?? this.image,
    );
  }
}
