import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../screens/user_profile_screen.dart';
import '../widgets/announcement.dart';

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupDataListeners();
  }

  void _setupDataListeners() {
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

  Future<void> _refreshData() async {
    await helperController.fetchWinners();
    await firebaseService.fetchGeneralData();
    if (mounted) setState(() {});
  }

  Future<void> _updateLeaderboardData(QuerySnapshot snapshot) async {
    try {
      final userId = userService.userId;
      final List<Map<String, dynamic>> data = [];
      int userRank = 0;

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
          'rank': i + 1,
          'subtitle': userData?['subtitle'] ?? 'TASTY FAN',
        };

        data.add(userMap);

        if (docUserId == userId) {
          userRank = i + 1;
          currentUserRank = userMap;
        }
      }

      if (mounted) {
        setState(() {
          leaderboardData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error updating leaderboard: $e');
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

      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error refreshing data: $e');
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
    final winners = helperController.winners;
    final announceDate = DateTime.parse(
        firebaseService.generalData['isAnnounceDate'] ??
            DateTime.now().toString());
    final isAnnounceShow = isDateTodayAfterTime(announceDate);

    return Scaffold(
      backgroundColor: isDarkMode ? kDarkGrey : kBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: getPercentageHeight(10, context),
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
                      'Leaderboard',
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                    Text(
                      'Compete with fellow food lovers',
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
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

          // Winners Announcement
          if (winners.isNotEmpty && isAnnounceShow)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(4, context),
                  vertical: getPercentageHeight(1, context),
                ),
                child: AnnouncementWidget(
                  title: '🏆 Winners of the week 🏆',
                  announcements: winners,
                  height: getPercentageHeight(6, context),
                  onTap: () {},
                ),
              ),
            ),

          // Loading or Leaderboard Content
          if (isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
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
                      Icons.leaderboard_outlined,
                      size: getIconScale(20, context),
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),
                    Text(
                      "No users on leaderboard",
                      style: TextStyle(
                        fontSize: getTextScale(4, context),
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
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
    final isDarkMode = getThemeProvider(context).isDarkMode;
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
                Icons.person,
                color: kWhite,
                size: getIconScale(5, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Text(
                'Your Ranking',
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
                      currentUserRank!['displayName'],
                      style: TextStyle(
                        color: kWhite,
                        fontSize: getTextScale(4.5, context),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${currentUserRank!['points']} points',
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
                  user['displayName'],
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
              ],
            ),
          ),

          // Points
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(3, context),
              vertical: getPercentageHeight(0.5, context),
            ),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
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
      return NetworkImage(imageUrl);
    }
    return AssetImage(intPlaceholderImage);
  }
}
