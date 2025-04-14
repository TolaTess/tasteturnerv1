import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String? userId = '';
  String? displayName;
  String? bio, sex;
  String? profileImage;
  int? points;

  List<String> followers;
  List<String> following;

  Map<String, String> settings;
  String? userType;
  bool isPremium;
  bool? syncHealth;
  String? location;

  UserModel({
    this.userId,
    required this.displayName,
    this.bio = 'Today will be Epic!',
    this.sex = 'female',
    required this.profileImage,
    this.points,
    this.followers = const [],
    this.following = const [],
    this.settings = const {},
    this.userType = 'user',
    required this.isPremium,
    this.syncHealth,
    this.location,
  });

  // Convert from Firestore document snapshot
  factory UserModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;

    // Safely convert settings map
    Map<String, String> settings = {};
    if (data['settings'] != null && data['settings'] is Map) {
      final rawSettings = data['settings'] as Map;
      settings = rawSettings.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
    }

    return UserModel(
      userId: snapshot.id,
      displayName: data['displayName']?.toString() ?? '',
      bio: data['bio']?.toString() ?? 'Today will be Epic!',
      profileImage: data['profileImage']?.toString() ?? '',
      points: data['points'] as int? ?? 0,
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      settings: settings,
      userType: data['userType']?.toString() ?? 'user',
      isPremium: data['isPremium'] as bool? ?? false,
    );
  }

  // Convert to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'bio': bio,
      'profileImage': profileImage,
      'points': points,
      'followers': followers,
      'following': following,
      'settings': settings,
      'userType': userType,
      'isPremium': isPremium,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Safely convert settings map
    Map<String, String> settings = {};
    if (map['settings'] != null && map['settings'] is Map) {
      final rawSettings = map['settings'] as Map;
      settings = rawSettings.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
    }

    return UserModel(
      displayName: map['displayName']?.toString() ?? '',
      bio: map['bio']?.toString() ?? 'Today will be Epic!',
      profileImage: map['profileImage']?.toString() ?? '',
      points: map['points'] as int? ?? 0,
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      settings: settings,
      userType: map['userType']?.toString() ?? 'user',
      isPremium: map['isPremium'] as bool? ?? false,
    );
  }

  UserModel copyWith({
    bool? syncHealth,
  }) {
    return UserModel(
      syncHealth: syncHealth ?? this.syncHealth,
      displayName: displayName ?? this.displayName,
      profileImage: profileImage ?? this.profileImage,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}
