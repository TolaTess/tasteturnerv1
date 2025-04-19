import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String? name;
  String? avatar;
  String? username;
  bool? isPremium;
  final List<String> mediaPaths;
  final String? category;
  final List<String> favorites;

  Post({
    required this.id,
    required this.userId,
    this.avatar,
    this.username,
    this.isPremium,
    this.name,
    required this.mediaPaths,
    this.category,
    this.favorites = const [],
  });

  // Factory method to create Post instance from Firestore document
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      mediaPaths: List<String>.from(data['mediaPaths'] ?? []),
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      favorites: List<String>.from(data['favorites'] ?? []),
    );
  }

  // Factory method to create Post instance from Firestore document
  factory Post.fromMap(Map<String, dynamic> data, String docid) {
    return Post(
      id: docid,
      userId: data['userId'] ?? '',
      mediaPaths: List<String>.from(data['mediaPaths'] ?? []),
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      favorites: List<String>.from(data['favorites'] ?? []),
    );
  }

  // Convert Post instance to Firestore document format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'mediaPaths': mediaPaths,
      'name': name,
      'category': category,
      'favorites': favorites,
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? name,
    List<String>? mediaPaths,
    String? category,
    List<String>? favorites,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      name: name ?? this.name,
      category: category ?? this.category,
      favorites: favorites ?? this.favorites,
    );
  }
}
