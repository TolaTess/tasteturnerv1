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

    final winners = helperController.winners;
    final announceDate = DateTime.parse(
        firebaseService.generalData['isAnnounceDate'] ??
            DateTime.now().toString());
    final isAnnounceShow = isDateTodayAfterTime(announceDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                      if (currentUserRank != null)
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: _getImageProvider(
                                    currentUserRank!['profileImage']),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  currentUserRank!['displayName'],
                                  style: TextStyle(
                                    color: getThemeProvider(context).isDarkMode
                                        ? kWhite
                                        : kBlack,
                                    fontSize: 16,
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
                                  fontSize: 16,
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
                          height: 50,
                          onTap: () {
                            // Handle tap
                          },
                        ),
                        const SizedBox(height: 10),
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
      return const Text(
        '🥇',
        style: TextStyle(
          fontSize: 30,
         
        ),
      );
    } else if (rank == 2) {
      return const Text(
        '🥈',
        style: TextStyle(
          fontSize: 30,
         
        ),
      );
    } else if (rank == 3) {
      return const Text(
        '🥉',
        style: TextStyle(
          fontSize: 30,
        ),
      );
    } else {
      return Text(
        "#$rank",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: getThemeProvider(context).isDarkMode ? kWhite : kBlack,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: _buildRankWidget(context),
          ),
          const SizedBox(width: 12),
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
              radius: 20,
              backgroundImage: getImageProvider(imageUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: getThemeProvider(context).isDarkMode ? kWhite : kBlack,
              ),
            ),
          ),
          Text(
            "$points",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
        ],
      ),
    );
  }
}
