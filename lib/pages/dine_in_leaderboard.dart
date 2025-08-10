import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../screens/user_profile_screen.dart';

class DineInLeaderboardScreen extends StatefulWidget {
  const DineInLeaderboardScreen({super.key});

  @override
  State<DineInLeaderboardScreen> createState() =>
      _DineInLeaderboardScreenState();
}

class _DineInLeaderboardScreenState extends State<DineInLeaderboardScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> leaderboardData = [];
  Map<String, dynamic>? currentUserRank;
  bool isLoading = true;
  StreamSubscription? _subscription;
  String weekRange = '';
  String ingredient = '';
  String challengeEndDate = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _calculateWeekRange();
    _setupDataListeners();
    _loadChallengeData();
  }

  Future<void> _loadChallengeData() async {
    await firebaseService.fetchGeneralData();
    final challengeDetails = firebaseService.generalData['challenge_details'];
    if (challengeDetails != null && challengeDetails is String) {
      setState(() {
        ingredient = challengeDetails.split(',').sublist(1).join(', ');
        challengeEndDate = challengeDetails.split(',')[0];
      });
      // Parse the end date for scheduling the points award
      try {
        final endDateParts = challengeEndDate.split('-');
        if (endDateParts.length == 3) {
          final day = int.parse(endDateParts[0]);
          final month = int.parse(endDateParts[1]);
          final year = int.parse(endDateParts[2]);
          final endDateTime =
              DateTime(year, month, day, 12, 0); // 12 PM on end date
          _schedulePointsAward(endDateTime);
        }
      } catch (e) {
        print('Error parsing challenge end date: $e');
      }
    }
  }

  void _calculateWeekRange() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    final mondayFormatted = '${monday.day}/${monday.month}';
    final sundayFormatted = '${sunday.day}/${sunday.month}';

    setState(() {
      weekRange = '$mondayFormatted - $sundayFormatted';
    });
  }

  void _setupDataListeners() {
    // Listen to posts collection changes for battle posts
    _subscription = firestore
        .collection('posts')
        .where('isBattle', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(100) // Get more posts to ensure we have enough for the week
        .snapshots()
        .listen((snapshot) {
      _updateLeaderboardData(snapshot);
    });
  }

  Future<void> _updateLeaderboardData(QuerySnapshot snapshot) async {
    try {
      final userId = userService.userId;
      final Map<String, Map<String, dynamic>> userLikesMap =
          <String, Map<String, dynamic>>{};

      // Calculate current week's Monday and Friday
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      // Set time to start of Monday and end of Friday
      final weekStart = DateTime(monday.year, monday.month, monday.day);
      final weekEnd =
          DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);

      // Process each battle post
      for (var doc in snapshot.docs) {
        final postData = doc.data() as Map<String, dynamic>?;
        if (postData == null) continue;

        // Check if post is from current week
        if (postData['createdAt'] != null) {
          try {
            final postDate = DateTime.parse(postData['createdAt']);
            if (postDate.isBefore(weekStart) || postDate.isAfter(weekEnd)) {
              continue; // Skip posts outside current week
            }
          } catch (e) {
            continue; // Skip posts with invalid dates
          }
        } else {
          continue; // Skip posts without createdAt
        }

        final postUserId = postData['userId'];
        final favorites = List<String>.from(postData['favorites'] ?? []);
        final likesCount = favorites.length;

        if (postUserId != null && likesCount > 0) {
          if (userLikesMap.containsKey(postUserId)) {
            userLikesMap[postUserId]!['totalLikes'] += likesCount;
            userLikesMap[postUserId]!['postCount'] += 1;
          } else {
            userLikesMap[postUserId] = {
              'userId': postUserId,
              'totalLikes': likesCount,
              'postCount': 1,
            };
          }
        }
      }

      // Convert to list and sort by total likes
      final List<Map<String, dynamic>> data = [];
      int actualRank = 1;

      // Sort users by total likes (descending)
      final sortedUsers = userLikesMap.values.toList()
        ..sort((a, b) =>
            (b['totalLikes'] as int).compareTo(a['totalLikes'] as int));

      for (var userData in sortedUsers) {
        final docUserId = userData['userId'] as String;

        // Fetch user details
        final userDoc =
            await firestore.collection('users').doc(docUserId).get();
        final userDataFromFirestore = userDoc.data() as Map<String, dynamic>?;

        final userMap = {
          'id': docUserId,
          'displayName': userDataFromFirestore?['displayName'] ?? 'Unknown',
          'profileImage':
              userDataFromFirestore?['profileImage']?.isNotEmpty == true
                  ? userDataFromFirestore!['profileImage']
                  : intPlaceholderImage,
          'totalLikes': userData['totalLikes'],
          'postCount': userData['postCount'],
          'rank': actualRank,
          'subtitle': userDataFromFirestore?['bio'] ?? 'DINE-IN CHALLENGER',
        };

        // Check if this is the current user
        if (docUserId == userId) {
          currentUserRank = userMap;
        }

        data.add(userMap);
        actualRank++;
      }

      if (mounted) {
        setState(() {
          leaderboardData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error updating dine-in leaderboard: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _schedulePointsAward(DateTime endDateTime) {
    final now = DateTime.now();
    final durationUntilEnd = endDateTime.difference(now);
    if (durationUntilEnd.isNegative) {
      print('Challenge end date is in the past, no points will be awarded.');
      return;
    }
    Timer(durationUntilEnd, () async {
      final winner = leaderboardData.isNotEmpty ? leaderboardData.first : null;
      if (winner == null) {
        print('No winner found, no points will be awarded.');
        return;
      }
      final winnerId = winner['id'];
      const pointsToAward = 100;
      await badgeService.awardPoints(winnerId, pointsToAward,
          reason: "Dine-In Challenge Winner");
             //save into battle_votes collection
        await firestore
            .collection('battle_winners')
            .doc(endDateTime.toString())
            .set({
          'battleId': 'dine-in-challenge',
          'userId': [
            winnerId,
          ],
          'timestamp': DateTime.now(),
        });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    try {
      setState(() => isLoading = true);

      // Manually trigger a refresh of leaderboard data
      final snapshot = await firestore
          .collection('posts')
          .where('isBattle', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      await _updateLeaderboardData(snapshot);

      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error refreshing dine-in leaderboard: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: isDarkMode ? kDarkGrey : kBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: getPercentageHeight(12, context),
            pinned: true,
            elevation: 0,
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  color: kAccent,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: getPercentageHeight(4, context)),
                    Text(
                      'Dine-In Leaderboard',
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                    Text(
                      'This Week\'s Challenge Champions',
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(4, context),
                        vertical: getPercentageHeight(0.5, context),
                      ),
                      decoration: BoxDecoration(
                        color: kWhite.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Week: $weekRange',
                            style: textTheme.bodySmall?.copyWith(
                              color: kWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Ingredients: ${capitalizeFirstLetter(ingredient)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: kWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              onPressed: () => Get.back(),
              icon: Icon(
                Icons.arrow_back_ios,
                color: kWhite,
                size: getIconScale(6, context),
              ),
            ),
            actions: [
              IconButton(
                onPressed: _onRefresh,
                icon: Icon(
                  Icons.refresh,
                  color: kWhite,
                  size: getIconScale(6, context),
                ),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
            ],
          ),

          // Current User Rank (if exists)
          if (currentUserRank != null)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(getPercentageWidth(4, context)),
                child: _buildCurrentUserCard(),
              ),
            ),

          // Loading or Leaderboard Content
          if (isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: kAccent,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),
                    Text(
                      'Loading challenge rankings...',
                      style: TextStyle(
                        color: isDarkMode ? kWhite : kDarkGrey,
                        fontSize: getTextScale(3.5, context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (leaderboardData.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: getIconScale(20, context),
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),
                    Text(
                      "No challenge posts this week",
                      style: TextStyle(
                        fontSize: getTextScale(4, context),
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    Text(
                      "Start posting your dine-in challenges!",
                      style: TextStyle(
                        fontSize: getTextScale(3, context),
                        color: Colors.grey.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Leaderboard List
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(4, context),
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = leaderboardData[index];
                    return _buildLeaderboardItem(user, index + 1);
                  },
                  childCount: leaderboardData.length,
                ),
              ),
            ),

          // Bottom spacing
          SliverToBoxAdapter(
            child: SizedBox(height: getPercentageHeight(10, context)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentUserCard() {
    if (currentUserRank == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kAccent,
            kAccentLight,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kAccent.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant,
                color: kWhite,
                size: getIconScale(5, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Text(
                'Your Challenge Ranking',
                style: TextStyle(
                  color: kWhite.withValues(alpha: 0.9),
                  fontSize: getTextScale(3.5, context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Row(
            children: [
              // Rank Badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(3, context),
                  vertical: getPercentageHeight(1, context),
                ),
                decoration: BoxDecoration(
                  color: kWhite.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  "#${currentUserRank!['rank']}",
                  style: TextStyle(
                    color: kWhite,
                    fontSize: getTextScale(5, context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: getPercentageWidth(3, context)),

              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kWhite, width: 3),
                ),
                child: CircleAvatar(
                  radius: getResponsiveBoxSize(context, 25, 25),
                  backgroundImage:
                      _getImageProvider(currentUserRank!['profileImage']),
                ),
              ),
              SizedBox(width: getPercentageWidth(3, context)),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizeFirstLetter(currentUserRank!['displayName']),
                      style: TextStyle(
                        color: kWhite,
                        fontSize: getTextScale(4.5, context),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${currentUserRank!['totalLikes']} likes • ${currentUserRank!['postCount']} posts',
                      style: TextStyle(
                        color: kWhite.withValues(alpha: 0.9),
                        fontSize: getTextScale(3.5, context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> user, int rank) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final isTopThree = rank <= 3;
    final isCurrentUser = user['id'] == userService.userId;

    return Container(
      margin: EdgeInsets.only(bottom: getPercentageHeight(1.5, context)),
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? (isDarkMode
                ? kAccent.withValues(alpha: 0.2)
                : kAccentLight.withValues(alpha: 0.1))
            : (isDarkMode ? kDarkGrey.withValues(alpha: 0.8) : kWhite),
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(color: kAccent.withValues(alpha: 0.3), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: (isDarkMode ? Colors.black : Colors.grey)
                .withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: getPercentageWidth(12, context),
            child: _buildRankWidget(rank, context),
          ),

          SizedBox(width: getPercentageWidth(3, context)),

          // Avatar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(userId: user['id']),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isTopThree
                    ? Border.all(color: _getRankColor(rank), width: 2)
                    : null,
              ),
              child: CircleAvatar(
                radius: getResponsiveBoxSize(context, 20, 20),
                backgroundImage: getImageProvider(user['profileImage']),
              ),
            ),
          ),

          SizedBox(width: getPercentageWidth(3, context)),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capitalizeFirstLetter(user['displayName']),
                  style: TextStyle(
                    fontSize: getTextScale(4, context),
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user['subtitle'] != null)
                  Text(
                    user['subtitle'],
                    style: TextStyle(
                      fontSize: getTextScale(3, context),
                      color: (isDarkMode ? kWhite : kDarkGrey)
                          .withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  '${user['postCount']} challenge posts',
                  style: TextStyle(
                    fontSize: getTextScale(2.5, context),
                    color: (isDarkMode ? kWhite : kDarkGrey)
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Likes
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(3, context),
              vertical: getPercentageHeight(0.5, context),
            ),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  "${user['totalLikes']}",
                  style: TextStyle(
                    fontSize: getTextScale(4, context),
                    fontWeight: FontWeight.bold,
                    color: kAccent,
                  ),
                ),
                Text(
                  "likes",
                  style: TextStyle(
                    fontSize: getTextScale(2.5, context),
                    color: kAccent.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankWidget(int rank, BuildContext context) {
    if (rank == 1) {
      return Container(
        padding: EdgeInsets.all(getPercentageWidth(2, context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ),
          shape: BoxShape.circle,
        ),
        child: Text(
          '🥇',
          style: TextStyle(fontSize: getTextScale(5, context)),
          textAlign: TextAlign.center,
        ),
      );
    } else if (rank == 2) {
      return Container(
        padding: EdgeInsets.all(getPercentageWidth(2, context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC0C0C0), Color(0xFF808080)],
          ),
          shape: BoxShape.circle,
        ),
        child: Text(
          '🥈',
          style: TextStyle(fontSize: getTextScale(5, context)),
          textAlign: TextAlign.center,
        ),
      );
    } else if (rank == 3) {
      return Container(
        padding: EdgeInsets.all(getPercentageWidth(2, context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
          ),
          shape: BoxShape.circle,
        ),
        child: Text(
          '🥉',
          style: TextStyle(fontSize: getTextScale(5, context)),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      return Container(
        width: getPercentageWidth(8, context),
        height: getPercentageWidth(8, context),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            "$rank",
            style: TextStyle(
              fontSize: getTextScale(4, context),
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
        ),
      );
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Color(0xFFFFD700); // Gold
      case 2:
        return Color(0xFFC0C0C0); // Silver
      case 3:
        return Color(0xFFCD7F32); // Bronze
      default:
        return kAccent;
    }
  }

  ImageProvider _getImageProvider(String? imageUrl) {
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return CachedNetworkImageProvider(imageUrl);
    }
    return AssetImage(intPlaceholderImage);
  }
}
