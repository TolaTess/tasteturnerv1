import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String? userId = '';
  String? displayName;
  String? bio;
  String? dob;
  String? profileImage;
  List<String> following;
  DateTime? freeTrialDate;
  Map<String, dynamic> settings;
  Map<String, dynamic> preferences;
  String? userType;
  bool isPremium;
  DateTime? created_At;
  final bool? familyMode;
  final List<FamilyMember>? familyMembers;

  UserModel({
    this.userId,
    required this.displayName,
    this.bio = 'Today will be Epic!',
    this.dob = '',
    required this.profileImage,
    this.following = const [],
    this.settings = const {},
    this.preferences = const {},
    this.userType = 'user',
    required this.isPremium,
    this.created_At,
    this.freeTrialDate,
    this.familyMode = false,
    this.familyMembers = const [],
  });

  // Convert from Firestore document snapshot
  factory UserModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;

    // Safely convert settings map
    Map<String, dynamic> settings = {};
    if (data['settings'] != null && data['settings'] is Map) {
      settings = Map<String, dynamic>.from(data['settings']);
    }

    // Safely convert preferences map
    Map<String, dynamic> preferences = {};
    if (data['preferences'] != null && data['preferences'] is Map) {
      preferences = Map<String, dynamic>.from(data['preferences']);
    }

    // Handle created_At as Timestamp or String
    DateTime? createdAt;
    if (data['created_At'] is Timestamp) {
      createdAt = (data['created_At'] as Timestamp).toDate();
    } else if (data['created_At'] is String) {
      createdAt = DateTime.tryParse(data['created_At']);
    }

    DateTime? freeTrialDate;
    if (data['freeTrialDate'] is Timestamp) {
      freeTrialDate = (data['freeTrialDate'] as Timestamp).toDate();
    } else if (data['freeTrialDate'] is String) {
      freeTrialDate = DateTime.tryParse(data['freeTrialDate']);
    }
    return UserModel(
      userId: snapshot.id,
      displayName: data['displayName']?.toString() ?? '',
      bio: data['bio']?.toString() ?? 'Today will be Epic!',
      dob: data['dob']?.toString() ?? '',
      profileImage: data['profileImage']?.toString() ?? '',
      following: List<String>.from(data['following'] ?? []),
      settings: settings,
      preferences: preferences,
      userType: data['userType']?.toString() ?? 'user',
      isPremium: data['isPremium'] as bool? ?? false,
      created_At: createdAt,
      freeTrialDate: freeTrialDate,
      familyMode: data['familyMode'] as bool? ?? false,
      familyMembers: (data['familyMembers'] as List<dynamic>?)
              ?.map((e) => FamilyMember.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // Convert to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'bio': bio,
      'dob': dob,
      'profileImage': profileImage,
      'following': following,
      'settings': settings,
      'preferences': preferences,
      'userType': userType,
      'isPremium': isPremium,
      'created_At': created_At != null ? Timestamp.fromDate(created_At!) : null,
      'freeTrialDate':
          freeTrialDate != null ? Timestamp.fromDate(freeTrialDate!) : null,
      'familyMode': familyMode,
      'familyMembers': familyMembers?.map((f) => f.toMap()).toList(),
    };
  }

  // Convert to JSON-safe map for SharedPreferences
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = toMap();
    // Convert created_At to ISO8601 string for JSON
    if (created_At != null) {
      data['created_At'] = created_At!.toIso8601String();
    }
    if (freeTrialDate != null) {
      data['freeTrialDate'] = freeTrialDate!.toIso8601String();
    }

    if (familyMembers != null) {
      data['familyMembers'] = familyMembers?.map((f) => f.toMap()).toList();
    }
    // Convert preferences map to be JSON-safe
    if (data['preferences'] != null) {
      final preference = Map<String, dynamic>.from(data['preferences']);
      // Convert FieldValue to current timestamp string if present
      if (preference['lastUpdated'] != null && preference['lastUpdated'] is FieldValue) {
        preference['lastUpdated'] = DateTime.now().toIso8601String();
      }
      data['preferences'] = preference;
    }
    return data;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Safely convert settings map
    Map<String, dynamic> settings = {};
    if (map['settings'] != null && map['settings'] is Map) {
      settings = Map<String, dynamic>.from(map['settings']);
    }

    // Safely convert preferences map
    Map<String, dynamic> preferences = {};
    if (map['preferences'] != null && map['preferences'] is Map) {
      preferences = Map<String, dynamic>.from(map['preferences']);
    }

    // Handle created_At as String or Timestamp
    DateTime? createdAt;
    if (map['created_At'] is String) {
      createdAt = DateTime.tryParse(map['created_At']);
    } else if (map['created_At'] is Timestamp) {
      createdAt = (map['created_At'] as Timestamp).toDate();
    }

    DateTime? freeTrialDate;
    if (map['freeTrialDate'] is String) {
      freeTrialDate = DateTime.tryParse(map['freeTrialDate']);
    } else if (map['freeTrialDate'] is Timestamp) {
      freeTrialDate = (map['freeTrialDate'] as Timestamp).toDate();
    }
    return UserModel(
      userId: map['userId']?.toString(),
      displayName: map['displayName']?.toString() ?? '',
      bio: map['bio']?.toString() ?? 'Today will be Epic!',
      dob: map['dob']?.toString() ?? '',
      profileImage: map['profileImage']?.toString() ?? '',
      following: List<String>.from(map['following'] ?? []),
      settings: settings,
      preferences: preferences,
      userType: map['userType']?.toString() ?? 'user',
      isPremium: map['isPremium'] as bool? ?? false,
      created_At: createdAt,
      freeTrialDate: freeTrialDate,
      familyMode: map['familyMode'] as bool? ?? false,
      familyMembers: (map['familyMembers'] as List<dynamic>?)
              ?.map((e) => FamilyMember.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  UserModel copyWith({
    List<FamilyMember>? familyMembers,
  }) {
    return UserModel(
      displayName: displayName ?? this.displayName,
      profileImage: profileImage ?? this.profileImage,
      isPremium: isPremium,
      familyMembers: familyMembers ?? this.familyMembers,
      familyMode: familyMode ?? this.familyMode,
      created_At: created_At ?? this.created_At,
      freeTrialDate: freeTrialDate ?? this.freeTrialDate,
      settings: settings,
      preferences: preferences,
      userType: userType ?? this.userType,
      userId: userId ?? this.userId,
      bio: bio ?? this.bio,
      dob: dob ?? this.dob,
      following: following,
    );
  }
}

class FamilyMember {
  final String name;
  final String ageGroup;
  final String fitnessGoal;
  final String foodGoal;

  FamilyMember({
    required this.name,
    required this.ageGroup,
    required this.fitnessGoal,
    required this.foodGoal,
  });

  factory FamilyMember.fromMap(Map<String, dynamic> map) => FamilyMember(
        name: map['name'] ?? '',
        ageGroup: map['ageGroup'] ?? '',
        fitnessGoal: map['fitnessGoal'] ?? '',
        foodGoal: map['foodGoal'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'ageGroup': ageGroup,
        'fitnessGoal': fitnessGoal,
        'foodGoal': foodGoal,
      };
}
