import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';

import '../constants.dart';

class ChallengeService extends GetxService {
  static ChallengeService get instance => Get.find<ChallengeService>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Challenge data
  final RxMap<String, dynamic> currentChallenge = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> currentLeaderboard =
      <Map<String, dynamic>>[].obs;
  final RxMap<String, dynamic> lastResults = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> notifications =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadChallengeData();
  }

  /// Load current challenge data and leaderboard
  Future<void> loadChallengeData() async {
    try {
      isLoading.value = true;

      final HttpsCallable callable =
          _functions.httpsCallable('getChallengeResults');
      final HttpsCallableResult result = await callable.call();
      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        currentChallenge.value = data['currentChallenge'] ?? {};
        currentLeaderboard.value =
            List<Map<String, dynamic>>.from(data['currentLeaderboard'] ?? []);
        lastResults.value = data['lastResults'] ?? {};

      } else {
        print('Error loading challenge data: ${data['error']}');
        // Fallback to Firestore if function fails
        await _loadFromFirestore();
      }
    } catch (e) {
      print('Error loading challenge data: $e');
      // Fallback to Firestore if function fails
      await _loadFromFirestore();
    } finally {
      isLoading.value = false;
    }
  }

  /// Load data from Firestore (fallback implementation)
  Future<void> _loadFromFirestore() async {
    try {
      // Note: fetchGeneralData removed - challenge_details no longer available from general collection
      // Using empty string as fallback
      final challengeDetails = '';

      // Calculate current week range
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      // Parse challenge details: "07-08-2025,carrot-v,shrimp-p,pork-p,aubergine-v"
      List<Map<String, dynamic>> parsedIngredients = [];
      if (challengeDetails.isNotEmpty) {
        final parts = challengeDetails.split(',');
        if (parts.length >= 5) {
          final ingredientParts = parts.skip(1).toList();
          for (String ingredient in ingredientParts) {
            final cleanName = ingredient.replaceAll(RegExp(r'-[vp]$'), '');
            final type = ingredient.endsWith('-v')
                ? 'vegetable'
                : ingredient.endsWith('-p')
                    ? 'protein'
                    : 'unknown';

            parsedIngredients.add({
              'name': cleanName,
              'type': type,
              'fullName': ingredient,
            });
          }
        }
      }

      currentChallenge.value = {
        'details': challengeDetails,
        'ingredients': parsedIngredients,
        'ingredientNames': parsedIngredients.map((i) => i['name']).toList(),
        'endDate':
            challengeDetails.isNotEmpty ? challengeDetails.split(',')[0] : '',
        'weekStart': '${monday.day}/${monday.month}',
        'weekEnd': '${sunday.day}/${sunday.month}',
      };

      // Load current week's leaderboard from posts
      await _loadCurrentLeaderboard();
    } catch (e) {
      print('Error loading from Firestore: $e');
    }
  }

  /// Load current leaderboard from posts
  Future<void> _loadCurrentLeaderboard() async {
    try {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      final weekStart = DateTime(monday.year, monday.month, monday.day);
      final weekEnd =
          DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);

      // Battle feature removed - return empty snapshot
      final snapshot = await _firestore
          .collection('posts')
          .where('isBattle', isEqualTo: false) // This will return no results since battles are removed
          .limit(0)
          .get();

      final userLikesMap = <String, Map<String, dynamic>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final userId = data['userId'] as String?;
        final favorites = List<String>.from(data['favorites'] ?? []);
        final likesCount = favorites.length;

        // Check if post is from current week
        if (data['createdAt'] != null) {
          try {
            final postDate = DateTime.parse(data['createdAt']);
            if (postDate.isBefore(weekStart) || postDate.isAfter(weekEnd)) {
              continue; // Skip posts outside current week
            }
          } catch (e) {
            continue; // Skip posts with invalid dates
          }
        } else {
          continue; // Skip posts without createdAt
        }

        if (userId != null && likesCount > 0) {
          if (userLikesMap.containsKey(userId)) {
            userLikesMap[userId]!['totalLikes'] += likesCount;
            userLikesMap[userId]!['postCount'] += 1;
          } else {
            userLikesMap[userId] = {
              'userId': userId,
              'totalLikes': likesCount,
              'postCount': 1,
            };
          }
        }
      }

      // Sort and get user details
      final sortedUsers = userLikesMap.values.toList()
        ..sort((a, b) =>
            (b['totalLikes'] as int).compareTo(a['totalLikes'] as int));

      final leaderboard = <Map<String, dynamic>>[];

      for (int i = 0; i < sortedUsers.length; i++) {
        final userData = sortedUsers[i];
        final userDoc =
            await _firestore.collection('users').doc(userData['userId']).get();
        final userDetails = userDoc.data() ?? {};

        leaderboard.add({
          'userId': userData['userId'],
          'displayName': userDetails['displayName'] ?? 'Unknown',
          'profileImage': userDetails['profileImage'] ?? '',
          'totalLikes': userData['totalLikes'],
          'postCount': userData['postCount'],
          'rank': i + 1,
        });
      }

      currentLeaderboard.value = leaderboard;
    } catch (e) {
      print('Error loading current leaderboard: $e');
    }
  }

  /// Get current challenge ingredients (names only)
  List<String> get currentIngredients {
    return List<String>.from(currentChallenge['ingredientNames'] ?? []);
  }

  /// Get current challenge ingredients with type information
  List<Map<String, dynamic>> get currentIngredientsWithType {
    return List<Map<String, dynamic>>.from(
        currentChallenge['ingredients'] ?? []);
  }

  /// Get vegetables only
  List<Map<String, dynamic>> get currentVegetables {
    return currentIngredientsWithType
        .where((ingredient) => ingredient['type'] == 'vegetable')
        .toList();
  }

  /// Get proteins only
  List<Map<String, dynamic>> get currentProteins {
    return currentIngredientsWithType
        .where((ingredient) => ingredient['type'] == 'protein')
        .toList();
  }

  /// Get current challenge end date
  String get challengeEndDate {
    return currentChallenge['endDate'] ?? '';
  }

  /// Get current week range
  String get weekRange {
    final start = currentChallenge['weekStart'] ?? '';
    final end = currentChallenge['weekEnd'] ?? '';
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }
    return '';
  }

  /// Check if user is in current leaderboard
  Map<String, dynamic>? getUserRank(String userId) {
    try {
      return currentLeaderboard.firstWhere(
        (user) => user['userId'] == userId,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      return null;
    }
  }

  /// Get user's position in leaderboard
  int getUserPosition(String userId) {
    final userRank = getUserRank(userId);
    return userRank?['rank'] ?? 0;
  }

  /// Get user's total likes in current challenge
  int getUserLikes(String userId) {
    final userRank = getUserRank(userId);
    return userRank?['totalLikes'] ?? 0;
  }

  /// Load user notifications
  Future<void> loadNotifications(
      {int limit = 20, String? lastNotificationId}) async {
    try {
      final HttpsCallable callable =
          _functions.httpsCallable('getUserNotifications');
      final HttpsCallableResult result = await callable.call({
        'limit': limit,
        'lastNotificationId': lastNotificationId,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        if (lastNotificationId == null) {
          // First load - replace all notifications
          notifications.value =
              List<Map<String, dynamic>>.from(data['notifications'] ?? []);
        } else {
          // Load more - append to existing notifications
          final newNotifications =
              List<Map<String, dynamic>>.from(data['notifications'] ?? []);
          notifications.addAll(newNotifications);
        }
      } else {
        print('Error loading notifications: ${data['error']}');
      }
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final HttpsCallable callable =
          _functions.httpsCallable('markNotificationAsRead');
      final HttpsCallableResult result = await callable.call({
        'notificationId': notificationId,
      });

      final data = result.data as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Get unread notifications count
  int get unreadNotificationsCount {
    return notifications
        .where((notification) => notification['read'] != true)
        .length;
  }

  /// Get last week's winners
  List<Map<String, dynamic>> get lastWeekWinners {
    return List<Map<String, dynamic>>.from(lastResults['winners'] ?? []);
  }

  /// Check if user won last week
  bool didUserWinLastWeek(String userId) {
    return lastWeekWinners.any((winner) => winner['userId'] == userId);
  }

  /// Get user's last week position
  int getUserLastWeekPosition(String userId) {
    final winner = lastWeekWinners.firstWhereOrNull(
      (winner) => winner['userId'] == userId,
    );
    return winner?['position'] ?? 0;
  }

  /// Get user's last week prize
  String getUserLastWeekPrize(String userId) {
    final winner = lastWeekWinners.firstWhereOrNull(
      (winner) => winner['userId'] == userId,
    );
    return winner?['prize'] ?? '';
  }

  /// Refresh all challenge data
  Future<void> refresh() async {
    await loadChallengeData();
    await loadNotifications();
  }

  /// Get challenge status text
  String getChallengeStatusText() {
    if (currentChallenge.isEmpty) {
      return 'Loading challenge...';
    }

    final ingredients = currentIngredients;
    if (ingredients.isEmpty) {
      return 'No active challenge';
    }

    return 'This week\'s ingredients: ${ingredients.join(', ')}';
  }

  /// Get leaderboard status text
  String getLeaderboardStatusText() {
    if (currentLeaderboard.isEmpty) {
      return 'No participants yet';
    }

    return '${currentLeaderboard.length} participants';
  }

  /// Get position emoji
  String getPositionEmoji(int position) {
    switch (position) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '🏅';
    }
  }

  /// Get position text with emoji
  String getPositionText(int position) {
    if (position == 0) return 'Not ranked';

    final suffix = _getOrdinalSuffix(position);
    return '${getPositionEmoji(position)} ${position}$suffix';
  }

  /// Get ordinal suffix (1st, 2nd, 3rd, etc.)
  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) {
      return 'th';
    }
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
