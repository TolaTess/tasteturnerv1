import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String? subtitle;
  final String? mediaType;
  final List<String> mediaPaths;
  final String? title;
  String? avatar;
  String? username;
  final Timestamp timestamp;
  final List<String> numLikes;
  int numComments;
  bool isPremium;

  Post({
    required this.id,
    required this.userId,
    this.subtitle,
    this.mediaType = '',
    required this.mediaPaths,
    this.title,
    this.avatar,
    this.username,
    required this.timestamp,
    this.numLikes = const [],
    this.numComments = 0,
    this.isPremium = false,
  });

  // Factory method to create Post instance from Firestore document
  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      subtitle: data['subtitle'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      mediaPaths: List<String>.from(data['mediaPaths'] ?? []),
      title: data['title'] ?? '',
      avatar: data['avatar'] ?? '',
      username: data['username'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      numLikes: List<String>.from(data['numLikes'] ?? []),
      numComments: data['numComments'] ?? 0,
      isPremium: data['isPremium'] ?? false,
    );
  }

  // Factory method to create Post instance from Firestore document
  factory Post.fromMap(Map<String, dynamic> data, String docid) {
    return Post(
      id: docid,
      userId: data['userId'] ?? '',
      subtitle: data['subtitle'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      mediaPaths: List<String>.from(data['mediaPaths'] ?? []),
      title: data['title'] ?? '',
      avatar: data['avatar'] ?? '',
      username: data['username'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      numLikes: List<String>.from(data['numLikes'] ?? []),
      numComments: data['numComments'] ?? 0,
      isPremium: data['isPremium'] ?? false,
    );
  }

  // Convert Post instance to Firestore document format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'subtitle': subtitle,
      'mediaType': mediaType,
      'mediaPaths': mediaPaths,
      'title': title,
      'avatar': avatar,
      'username': username,
      'timestamp': timestamp,
      'numLikes': numLikes,
      'numComments': numComments,
      'isPremium': isPremium,
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? title,
    List<String>? mediaPaths,
    Timestamp? timestamp,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
