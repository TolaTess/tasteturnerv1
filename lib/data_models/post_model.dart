import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String? mealId;
  final String userId;
  final String? name;
  String? avatar;
  String? username;
  bool? isPremium;
  final List<String> mediaPaths;
  final String? category;
  final List<String> favorites;
  final DateTime? createdAt;
  final bool? isBattle;
  final String? battleId;
  final bool isVideo;

  Post({
    required this.id,
    this.mealId,
    required this.userId,
    this.avatar,
    this.username,
    this.isPremium,
    this.name,
    required this.mediaPaths,
    this.category,
    this.favorites = const [],
    this.createdAt,
    this.isBattle,
    this.battleId,
    this.isVideo = false,
  });

  // Factory method to create Post instance from Firestore document
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      mealId: data['mealId'] ?? '',
      userId: data['userId'] ?? '',
      mediaPaths: List<String>.from(data['mediaPaths'] ?? []),
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      favorites: List<String>.from(data['favorites'] ?? []),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : data['createdAt'] is String
              ? DateTime.tryParse(data['createdAt'])
              : null,
      isBattle: data['isBattle'] ?? false,
      battleId: data['battleId'] ?? '',
      isVideo: data['isVideo'] ?? false,
    );
  }

  // Factory method to create Post instance from Firestore document
  factory Post.fromMap(Map<String, dynamic> data, String docid) {
    return Post(
      id: docid,
      mealId: data['mealId'] ?? '',
      userId: data['userId'] ?? '',
      mediaPaths: List<String>.from(data['mediaPaths'] ?? []),
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      favorites: List<String>.from(data['favorites'] ?? []),
      createdAt:
          data['createdAt'] != null ? DateTime.parse(data['createdAt']) : null,
      isBattle: data['isBattle'] ?? false,
      battleId: data['battleId'] ?? '',
      isVideo: data['isVideo'] ?? false,
    );
  }

  // Convert Post instance to Firestore document format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'mealId': mealId ?? '',
      'userId': userId,
      'mediaPaths': mediaPaths,
      'name': name ?? '',
      'category': category ?? 'general',
      'favorites': favorites,
      'createdAt': createdAt?.toIso8601String(),
      'isBattle': isBattle ?? false,
      'battleId': battleId ?? '', // Ensure battleId is never null
      'isVideo': isVideo,
    };
  }

  Post copyWith({
    String? id,
    String? mealId,
    String? userId,
    String? name,
    List<String>? mediaPaths,
    String? category,
    List<String>? favorites,
    DateTime? createdAt,
    bool? isBattle,
    String? battleId,
    bool? isVideo,
  }) {
    return Post(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      userId: userId ?? this.userId,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      name: name ?? this.name,
      category: category ?? this.category,
      favorites: favorites ?? this.favorites,
      createdAt: createdAt ?? this.createdAt,
      isBattle: isBattle ?? this.isBattle,
      battleId: battleId ?? this.battleId,
      isVideo: isVideo ?? this.isVideo,
    );
  }
}
