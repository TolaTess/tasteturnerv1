import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../screens/user_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> leaderboardData = [];
  Map<String, dynamic>? currentUserRank;
  bool isLoading = true;
  StreamSubscription? _subscription;
  bool isDineInMode = false; 
  bool showChallengePosts = false;

    loadExcludedIngredients() async {
    await firebaseService.fetchGeneralData();
    final excludedIngredients =
        firebaseService.generalData['excludeIngredients'].toString().split(',');
    if (excludedIngredients.contains('true')) {
      setState(() {
        showChallengePosts = true;
      });
    } else {
      setState(() {
        showChallengePosts = false;
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupDataListeners();
    loadExcludedIngredients();
  }

  void _setupDataListeners() {
    if (isDineInMode) {
      _setupDineInDataListeners();
    } else {
      _setupRegularDataListeners();
    }
  }

  void _setupRegularDataListeners() {
    // Listen to points collection changes
    _subscription = firestore
        .collection('points')
        .where('points', isGreaterThan: 0)
        .orderBy('points', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      _updateLeaderboardData(snapshot);
    });

    // Initial fetch of winners and general data
    _refreshData();
  }

  void _setupDineInDataListeners() {
    // Battle feature removed - no longer listening to battle posts
    // Dine-in leaderboard functionality disabled
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _refreshData() async {
    await helperController.fetchWinners();
    await firebaseService.fetchGeneralData();
    if (mounted) setState(() {});
  }

  Future<void> _updateLeaderboardData(QuerySnapshot snapshot) async {
    try {
      final userId = userService.userId;
      final List<Map<String, dynamic>> data = [];
      int actualRank = 1; // Track actual rank excluding tastyId

      for (var i = 0; i < snapshot.docs.length; i++) {
        final pointsDoc = snapshot.docs[i];
        final pointsData = pointsDoc.data() as Map<String, dynamic>?;
        final docUserId = pointsDoc.id;

        // Fetch user details
        final userDoc =
            await firestore.collection('users').doc(docUserId).get();
        final userData = userDoc.data() as Map<String, dynamic>?;

        final userMap = {
          'id': docUserId,
          'displayName': userData?['displayName'] ?? 'Unknown',
          'profileImage':
              userData?['profileImage']?.toString().isNotEmpty == true
                  ? userData!['profileImage']
                  : intPlaceholderImage,
          'points': pointsData?['points'] ?? 0,
          'rank': actualRank,
          'subtitle': userData?['bio'] ?? 'TASTY FAN',
        };

        // Check if this is the current user (for "Your Ranking" section)
        if (docUserId == userId) {
          currentUserRank = userMap;
        }

        // Only add to main leaderboard if not tastyId
        if (docUserId != tastyId && docUserId != tastyId2 && docUserId != tastyId3 && docUserId != tastyId4) {
          data.add(userMap);
          actualRank++;
        } else {
          // If current user is tastyId, still set their rank for "Your Ranking"
          if (docUserId == userId) {
            currentUserRank = userMap;
          }
        }
      }

      if (mounted) {
        setState(() {
          leaderboardData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    try {
      setState(() => isLoading = true);

      if (isDineInMode && showChallengePosts) {
        // Battle feature removed - dine-in leaderboard disabled
        setState(() {
          isLoading = false;
        });
      } else {
        // Refresh winners data
        await helperController.fetchWinners();

        // Refresh general data (for announce date)
        await firebaseService.fetchGeneralData();

        // Manually trigger a refresh of leaderboard data
        final snapshot = await firestore
            .collection('points')
            .where('points', isGreaterThan: 0)
            .orderBy('points', descending: true)
            .limit(50)
            .get();

        await _updateLeaderboardData(snapshot);
      }

      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _toggleLeaderboardMode() {
    setState(() {
      isDineInMode = !isDineInMode;
      isLoading = true;
      leaderboardData = [];
      currentUserRank = null;
    });

    // Cancel current subscription and setup new listeners
    _subscription?.cancel();
    _setupDataListeners();
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
            expandedHeight: getPercentageHeight(15, context),
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
                      isDineInMode ? 'Dine-In Leaderboard' : 'Leaderboard',
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                    Text(
                      isDineInMode
                          ? 'This Week\'s Challenge Champions'
                          : 'Compete with fellow food lovers',
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),
                    // Toggle Switch
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(2, context),
                        vertical: getPercentageHeight(0.5, context),
                      ),
                      decoration: BoxDecoration(
                        color: kWhite.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: showChallengePosts ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Points',
                            style: textTheme.bodySmall?.copyWith(
                              color: isDineInMode
                                  ? kWhite.withValues(alpha: 0.6)
                                  : kWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: getPercentageWidth(2, context)),
                          GestureDetector(
                            onTap: _toggleLeaderboardMode,
                            child: Container(
                              width: getPercentageWidth(12, context),
                              height: getPercentageHeight(2.5, context),
                              decoration: BoxDecoration(
                                color: isDineInMode
                                    ? kWhite
                                    : kWhite.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: AnimatedAlign(
                                alignment: isDineInMode
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  width: getPercentageWidth(5, context),
                                  height: getPercentageWidth(5, context),
                                  decoration: BoxDecoration(
                                    color: isDineInMode ? kAccent : kWhite,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: getPercentageWidth(2, context)),
                          Text(
                            'Dine-In',
                            style: textTheme.bodySmall?.copyWith(
                              color: isDineInMode
                                  ? kWhite
                                  : kWhite.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ) : const SizedBox.shrink(),
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
                      'Loading rankings...',
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
                      isDineInMode
                          ? Icons.restaurant_outlined
                          : Icons.leaderboard_outlined,
                      size: getIconScale(20, context),
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),
                    Text(
                      isDineInMode
                          ? "No challenge posts this week"
                          : "No users on leaderboard",
                      style: TextStyle(
                        fontSize: getTextScale(4, context),
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isDineInMode) ...[
                      SizedBox(height: getPercentageHeight(1, context)),
                      Text(
                        "Start posting your dine-in challenges!",
                        style: TextStyle(
                          fontSize: getTextScale(3, context),
                          color: Colors.grey.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
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
    final isDarkMode = getThemeProvider(context).isDarkMode;
    if (currentUserRank == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        gradient:  const LinearGradient(
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
                isDineInMode ? Icons.restaurant : Icons.person,
                color: kWhite,
                size: getIconScale(5, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Text(
                isDineInMode ? 'Your Challenge Ranking' : 'Your Ranking',
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
                      isDineInMode
                          ? '${currentUserRank!['totalLikes']} likes • ${currentUserRank!['postCount']} posts'
                          : '${currentUserRank!['points']} points',
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
                if (isDineInMode && user['postCount'] != null)
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

          // Points/Likes
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(3, context),
              vertical: getPercentageHeight(0.5, context),
            ),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isDineInMode
                ? Column(
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
                  )
                : Text(
                    "${user['points']}",
                    style: TextStyle(
                      fontSize: getTextScale(4, context),
                      fontWeight: FontWeight.bold,
                      color: kAccent,
                    ),
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
        decoration: const BoxDecoration(
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
        decoration: const BoxDecoration(
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
        decoration: const BoxDecoration(
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
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
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
