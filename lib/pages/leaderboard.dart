import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tasteturner/widgets/icon_widget.dart';

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

    final winners = helperController.winners;
    final announceDate = DateTime.parse(
        firebaseService.generalData['isAnnounceDate'] ??
            DateTime.now().toString());
    final isAnnounceShow = isDateTodayAfterTime(announceDate);

    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const IconCircleButton(),
        ),
        title: Text(
          'Leaderboard',
          style: TextStyle(
              fontSize: getPercentageWidth(3.5, context),
              fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            padding: EdgeInsets.only(
                right: MediaQuery.of(context).size.width > 1100
                    ? getPercentageWidth(2, context)
                    : getPercentageWidth(0.5, context)),
            icon: Icon(Icons.refresh, size: getPercentageWidth(6, context)),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: kAccent))
            : leaderboardData.isEmpty
                ? const Center(child: Text("No users on leaderboard"))
                : Column(
                    children: [
                      SizedBox(height: getPercentageHeight(1, context)),
                      if (currentUserRank != null)
                        Container(
                          margin:
                              EdgeInsets.all(getPercentageWidth(1.6, context)),
                          padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(1.6, context),
                              vertical: getPercentageHeight(1.2, context)),
                          decoration: BoxDecoration(
                            color: kAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "#${currentUserRank!['rank']}",
                                style: TextStyle(
                                  color: getThemeProvider(context).isDarkMode
                                      ? kWhite
                                      : kBlack,
                                  fontSize: getPercentageWidth(3, context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: getPercentageWidth(1.2, context)),
                              CircleAvatar(
                                radius: getPercentageWidth(2, context),
                                backgroundImage: _getImageProvider(
                                    currentUserRank!['profileImage']),
                              ),
                              SizedBox(width: getPercentageWidth(1.2, context)),
                              Expanded(
                                child: Text(
                                  currentUserRank!['displayName'],
                                  style: TextStyle(
                                    color: getThemeProvider(context).isDarkMode
                                        ? kWhite
                                        : kBlack,
                                    fontSize: getPercentageWidth(3, context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                "${currentUserRank!['points']}",
                                style: TextStyle(
                                  color: getThemeProvider(context).isDarkMode
                                      ? kWhite
                                      : kBlack,
                                  fontSize: getPercentageWidth(3, context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (winners.isNotEmpty && isAnnounceShow) ...[
                        AnnouncementWidget(
                          title: '🏆 Winners of the week 🏆',
                          announcements: winners,
                          height: getPercentageHeight(5, context),
                          onTap: () {
                            // Handle tap
                          },
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                      ],
                      Expanded(
                        child: ListView.builder(
                          itemCount: leaderboardData.length,
                          itemBuilder: (context, index) {
                            final user = leaderboardData[index];
                            return LeaderboardItem(
                              rank: index + 1,
                              name: user['displayName'],
                              subtitle: user['subtitle'],
                              imageUrl: user['profileImage'],
                              points: user['points'],
                              id: user['id'],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  ImageProvider _getImageProvider(String? imageUrl) {
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return NetworkImage(imageUrl);
    }
    return AssetImage(intPlaceholderImage);
  }
}

class LeaderboardItem extends StatelessWidget {
  final int rank;
  final String name;
  final String subtitle;
  final String imageUrl;
  final int points;
  final String id;

  const LeaderboardItem({
    super.key,
    required this.rank,
    required this.name,
    required this.subtitle,
    required this.imageUrl,
    required this.points,
    required this.id,
  });

  Widget _buildRankWidget(BuildContext context) {
    if (rank == 1) {
      return Text(
        '🥇',
        style: TextStyle(fontSize: getPercentageWidth(6, context)),
      );
    } else if (rank == 2) {
      return Text(
        '🥈',
        style: TextStyle(fontSize: getPercentageWidth(6, context)),
      );
    } else if (rank == 3) {
      return Text(
        '🥉',
        style: TextStyle(fontSize: getPercentageWidth(6, context)),
      );
    } else {
      return Text(
        "#$rank",
        style: TextStyle(
          fontSize: getPercentageWidth(5, context),
          fontWeight: FontWeight.w600,
          color: getThemeProvider(context).isDarkMode ? kWhite : kBlack,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(1.6, context),
          vertical: getPercentageHeight(0.4, context)),
      child: Row(
        children: [
          SizedBox(
            width: getPercentageWidth(5, context),
            child: _buildRankWidget(context),
          ),
          SizedBox(width: getPercentageWidth(3, context)),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(userId: id),
                ),
              );
            },
            child: CircleAvatar(
              radius: getPercentageWidth(5.5, context),
              backgroundImage: getImageProvider(imageUrl),
            ),
          ),
          SizedBox(width: getPercentageWidth(1.2, context)),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: getPercentageWidth(4, context),
                fontWeight: FontWeight.w600,
                color: getThemeProvider(context).isDarkMode ? kWhite : kBlack,
              ),
            ),
          ),
          Text(
            "$points",
            style: TextStyle(
              fontSize: getPercentageWidth(4, context),
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
        ],
      ),
    );
  }
}
