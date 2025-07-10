class Badge {
  final String id;
  final String title;
  final String description;
  final String icon;
  final BadgeCategory category;
  final BadgeDifficulty difficulty;
  final BadgeCriteria criteria;
  final BadgeRewards rewards;
  final bool isActive;
  final DateTime createdAt;
  final int order;

  Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.difficulty,
    required this.criteria,
    required this.rewards,
    this.isActive = true,
    required this.createdAt,
    required this.order,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'category': category.name,
      'difficulty': difficulty.name,
      'criteria': criteria.toMap(),
      'rewards': rewards.toMap(),
      'isActive': isActive,
      'createdAt': createdAt,
      'order': order,
    };
  }

  factory Badge.fromFirestore(Map<String, dynamic> data) {
    return Badge(
      id: data['id'],
      title: data['title'],
      description: data['description'],
      icon: data['icon'],
      category: BadgeCategory.values.firstWhere(
        (e) => e.name == data['category'],
      ),
      difficulty: BadgeDifficulty.values.firstWhere(
        (e) => e.name == data['difficulty'],
      ),
      criteria: BadgeCriteria.fromMap(data['criteria']),
      rewards: BadgeRewards.fromMap(data['rewards']),
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'].toDate(),
      order: data['order'],
    );
  }
}

enum BadgeCategory {
  consistency,
  nutrition,
  social,
  exploration,
  achievement,
  special
}

enum BadgeDifficulty { easy, medium, hard, legendary }

class BadgeCriteria {
  final String type;
  final int target;
  final String requirement;
  final Map<String, dynamic>? additionalData;

  BadgeCriteria({
    required this.type,
    required this.target,
    required this.requirement,
    this.additionalData,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'target': target,
      'requirement': requirement,
      'additionalData': additionalData,
    };
  }

  factory BadgeCriteria.fromMap(Map<String, dynamic> map) {
    return BadgeCriteria(
      type: map['type'],
      target: map['target'],
      requirement: map['requirement'],
      additionalData: map['additionalData'],
    );
  }
}

class BadgeRewards {
  final int points;
  final List<String>? unlocks;

  BadgeRewards({
    required this.points,
    this.unlocks,
  });

  Map<String, dynamic> toMap() {
    return {
      'points': points,
      'unlocks': unlocks,
    };
  }

  factory BadgeRewards.fromMap(Map<String, dynamic> map) {
    return BadgeRewards(
      points: map['points'],
      unlocks: map['unlocks']?.cast<String>(),
    );
  }
}

class UserBadgeProgress {
  final String badgeId;
  final String userId;
  final bool isEarned;
  final int currentProgress;
  final int targetProgress;
  final DateTime startedAt;
  final DateTime? earnedAt;
  final DateTime lastUpdated;
  final Map<String, dynamic> progressData;

  UserBadgeProgress({
    required this.badgeId,
    required this.userId,
    this.isEarned = false,
    this.currentProgress = 0,
    required this.targetProgress,
    required this.startedAt,
    this.earnedAt,
    required this.lastUpdated,
    this.progressData = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'badgeId': badgeId,
      'userId': userId,
      'isEarned': isEarned,
      'currentProgress': currentProgress,
      'targetProgress': targetProgress,
      'startedAt': startedAt,
      'earnedAt': earnedAt,
      'lastUpdated': lastUpdated,
      'progressData': progressData,
    };
  }

  factory UserBadgeProgress.fromFirestore(Map<String, dynamic> data) {
    return UserBadgeProgress(
      badgeId: data['badgeId'],
      userId: data['userId'],
      isEarned: data['isEarned'] ?? false,
      currentProgress: data['currentProgress'] ?? 0,
      targetProgress: data['targetProgress'],
      startedAt: data['startedAt'].toDate(),
      earnedAt: data['earnedAt']?.toDate(),
      lastUpdated: data['lastUpdated'].toDate(),
      progressData: Map<String, dynamic>.from(data['progressData'] ?? {}),
    );
  }
}
