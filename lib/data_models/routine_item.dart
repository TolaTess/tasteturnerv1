class RoutineItem {
  String id;
  String title;
  String value;
  String type;
  bool isEnabled;
  bool isCompleted;

  RoutineItem({
    required this.id,
    required this.title,
    required this.value,
    required this.type,
    this.isEnabled = true,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'value': value,
      'type': type,
      'isEnabled': isEnabled,
      'isCompleted': isCompleted,
    };
  }

  factory RoutineItem.fromMap(Map<String, dynamic> map) {
    return RoutineItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      value: map['value'] ?? '',
      type: map['type'] ?? '',
      isEnabled: map['isEnabled'] ?? true,
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}