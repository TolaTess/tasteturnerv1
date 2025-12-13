import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../screens/user_profile_screen.dart';
import '../service/challenge_service.dart';

class DineInLeaderboardScreen extends StatefulWidget {
  const DineInLeaderboardScreen({super.key});

  @override
  State<DineInLeaderboardScreen> createState() =>
      _DineInLeaderboardScreenState();
}

class _DineInLeaderboardScreenState extends State<DineInLeaderboardScreen>
    with AutomaticKeepAliveClientMixin {
  late ChallengeService challengeService;
  StreamSubscription? _subscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    challengeService = Get.find<ChallengeService>();
    _setupDataListeners();
  }

  void _setupDataListeners() {
    // Listen to challenge service changes
    _subscription = challengeService.currentLeaderboard.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    try {
      await challengeService.refresh();
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
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
                            'Week: ${challengeService.weekRange}',
                            style: textTheme.bodySmall?.copyWith(
                              color: kWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Ingredients: ${challengeService.currentIngredients.join(', ')}',
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
          Obx(() {
            final userRank =
                challengeService.getUserRank(userService.userId ?? '');
            if (userRank == null) return const SizedBox.shrink();

            return SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(getPercentageWidth(4, context)),
                child: userRank.isNotEmpty
                    ? _buildCurrentUserCard(userRank)
                    : const SizedBox.shrink(),
              ),
            );
          }),

          // Loading or Leaderboard Content
          Obx(() {
            if (challengeService.isLoading.value) {
              return SliverFillRemaining(
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
              );
            } else if (challengeService.currentLeaderboard.isEmpty) {
              return SliverFillRemaining(
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
              );
            } else {
              // Leaderboard List
              return SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(4, context),
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = challengeService.currentLeaderboard[index];
                      return _buildLeaderboardItem(user, index + 1);
                    },
                    childCount: challengeService.currentLeaderboard.length,
                  ),
                ),
              );
            }
          }),

          // Bottom spacing
          SliverToBoxAdapter(
            child: SizedBox(height: getPercentageHeight(10, context)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentUserCard(Map<String, dynamic> userRank) {
    return Container(
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
                  "#${userRank['rank']}",
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
                  backgroundImage: _getImageProvider(userRank['profileImage']),
                ),
              ),
              SizedBox(width: getPercentageWidth(3, context)),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizeFirstLetter(
                          userRank['displayName'] ?? 'Unknown'),
                      style: TextStyle(
                        color: kWhite,
                        fontSize: getTextScale(4.5, context),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${userRank['totalLikes']} likes • ${userRank['postCount']} posts',
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
