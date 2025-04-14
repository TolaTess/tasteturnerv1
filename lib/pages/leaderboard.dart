import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fit_hify/constants.dart';
import 'package:flutter/material.dart';

import '../helper/utils.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> leaderboardData = [];
  Map<String, dynamic>? currentUserRank;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      setState(() => isLoading = true);

      final userId = userService.userId;
      final QuerySnapshot snapshot = await firestore
          .collection('users')
          .where('points', isGreaterThan: 0)
          .orderBy('points', descending: true)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> data = [];
      int userRank = 0;

      for (var i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final userData = doc.data() as Map<String, dynamic>?;

        final userMap = {
          'id': doc.id,
          'displayName': userData?['displayName'] ?? 'Unknown',
          'profileImage': userData?['profileImage'] ?? intPlaceholderImage,
          'points': userData?['points'] ?? 0,
          'rank': i + 1,
          'subtitle': userData?['subtitle'] ?? 'ENERGY FAN',
        };

        data.add(userMap);

        if (doc.id == userId) {
          userRank = i + 1;
          currentUserRank = userMap;
        }
      }

      setState(() {
        leaderboardData = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching leaderboard: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
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
                              backgroundImage: NetworkImage(
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
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class LeaderboardItem extends StatelessWidget {
  final int rank;
  final String name;
  final String subtitle;
  final String imageUrl;
  final int points;

  const LeaderboardItem({
    super.key,
    required this.rank,
    required this.name,
    required this.subtitle,
    required this.imageUrl,
    required this.points,
  });

  Widget _buildRankWidget(BuildContext context) {
    if (rank == 1) {
      return Image.asset('assets/images/tasty.png', width: 24, height: 24);
    } else if (rank == 2) {
      return Image.asset('assets/images/tasty.png', width: 24, height: 24);
    } else if (rank == 3) {
      return Image.asset('assets/images/tasty.png', width: 24, height: 24);
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
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(imageUrl),
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
