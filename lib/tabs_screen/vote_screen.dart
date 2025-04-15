import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/category_selector.dart';
import '../service/battle_service.dart';

class VoteScreen extends StatefulWidget {
  final bool isDarkMode;

  const VoteScreen({
    super.key,
    required this.isDarkMode,
  });

  @override
  _VoteScreenState createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> candidates = [];
  int? selectedIndex;
  String selectedCategory = 'all';
  String selectedCategoryId = '';

  @override
  void initState() {
    super.initState();
    _fetchCandidates(selectedCategory);
  }

  void _updateCategoryData(String categoryId, String category) {
    if (mounted) {
      setState(() {
        selectedCategoryId = categoryId;
        selectedCategory = category;
        _fetchCandidates(category);
      });
    }
  }

  /// **Fetch candidates based on `category` from Firestore**
  void _fetchCandidates(String category) async {
    try {
      String categoryFilter = category;
      QuerySnapshot snapshot = await firestore
          .collection('battles')
          .where('category', isEqualTo: categoryFilter.toLowerCase())
          .get();

      List<Map<String, dynamic>> fetchedCandidates = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Get current date's battle data
        final dates = data['dates'] as Map<String, dynamic>;
        final currentDate = DateTime.now().toString().substring(0, 10);
        final currentBattle = dates[currentDate];

        if (currentBattle != null) {
          final participants =
              currentBattle['participants'] as Map<String, dynamic>;

          for (var entry in participants.entries) {
            final userId = entry.key;
            final user = entry.value as Map<String, dynamic>;
            String imageUrl =
                user['image']?.toString().trim() ?? intPlaceholderImage;

            // ✅ Ensure image is a valid URL (not null, empty, or missing "http")
            if (!imageUrl.startsWith('http')) {
              imageUrl = intPlaceholderImage;
            }

            fetchedCandidates.add({
              'id': doc.id,
              'category': data['category'] ?? '',
              'userid': userId,
              'name': user['name'] ?? '',
              'image': imageUrl,
              'votes': List<String>.from(user['votes'] ?? []),
            });
          }
        }
      }

      // Calculate vote percentages for all candidates
      List<Map<String, dynamic>> candidatesWithPercentages = [];
      for (var candidate in fetchedCandidates) {
        double votePercentage =
            await BattleService.instance.calculateUserVotePercentage(
          candidate['userid'],
          category,
        );
        candidatesWithPercentages.add({
          ...candidate,
          'votePercentage': votePercentage,
        });
      }

      // Sort candidates by vote percentage in descending order
      candidatesWithPercentages.sort((a, b) => (b['votePercentage'] as double)
          .compareTo(a['votePercentage'] as double));

      if (mounted) {
        setState(() {
          candidates = candidatesWithPercentages;
        });
      }
    } catch (e) {
      print("Error fetching candidates: $e");
    }
  }

  void _confirmSelection(int index) async {
    final selectedCandidate = candidates[index];

    // Check if user has already voted
    bool hasVoted = await _checkIfUserVoted(selectedCandidate['id']);

    if (hasVoted) {
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'You have already voted in this battle',
          context,
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: widget.isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            'Confirm Vote',
            style: TextStyle(
              color: widget.isDarkMode ? kWhite : kBlack,
            ),
          ),
          content: Text(
            'Are you sure you want to vote for ${selectedCandidate['name']}?',
            style: TextStyle(
              color: widget.isDarkMode ? kWhite : kBlack,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  selectedIndex = index;
                });

                await castVote(selectedCandidate['id'],
                    selectedCandidate['userid'], userService.userId, context);
                Navigator.pop(context);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkIfUserVoted(String battleId) async {
    try {
      final userId = userService.userId;
      if (userId == null) return false;
      return await BattleService.instance.hasUserVoted(battleId, userId);
    } catch (e) {
      print("Error checking vote status: $e");
      return false;
    }
  }

  Future<void> castVote(String battleId, String candidateUserId, String? userId,
      BuildContext context) async {
    try {
      if (userId == null) {
        if (mounted) {
          showTastySnackbar(
            'Please try again.',
            'Please sign in to vote',
            context,
          );
        }
        return;
      }

      if (candidateUserId == userId) {
        if (mounted) {
          showTastySnackbar(
            'Please try again.',
            'You cannot vote for yourself',
            context,
          );
        }
        return;
      }

      await BattleService.instance.castVote(
        battleId: battleId,
        voterId: userId,
        votedForUserId: candidateUserId,
      );

      if (mounted) {
        showTastySnackbar(
          'Success',
          'Thank you for voting!',
          context,
        );
      }
    } catch (e) {
      print("Error casting vote: $e");
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'An error occurred while voting',
          context,
        );
      }
    }
  }

  Future<double> calculateVotePercentage(String userId) async {
    try {
      // Find the candidate in our list
      final candidate = candidates.firstWhere(
        (c) => c['userid'] == userId,
        orElse: () => {'votePercentage': 0.0},
      );
      return candidate['votePercentage'] ?? 0.0;
    } catch (e) {
      print("Error getting vote percentage: $e");
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryDatas = helperController.category;
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              CategorySelector(
                categories: categoryDatas,
                selectedCategoryId: selectedCategoryId,
                onCategorySelected: _updateCategoryData,
                isDarkMode: isDarkMode,
                accentColor: kAccent,
                darkModeAccentColor: kDarkModeAccent,
              ),
              candidates.isEmpty
                  ? const SizedBox(height: 60)
                  : const SizedBox(height: 25),
              if (candidates.isEmpty)
                noItemTastyWidget(
                  "No candidates yet",
                  "",
                  context,
                  false,
                )
              else ...[
                if (candidates.length >= 2)
                  Row(
                    children: [
                      for (int i = 0; i < 2; i++)
                        Expanded(
                          child: FutureBuilder<double>(
                            future: calculateVotePercentage(
                                candidates[i]['userid']),
                            builder: (context, snapshot) {
                              final double votePercentage =
                                  snapshot.data ?? 0.0;
                              return VoteItemCard(
                                item: candidates[i],
                                votePercentage: votePercentage,
                                onTap: () => _confirmSelection(i),
                                isDarkMode: isDarkMode,
                                isLarge: true,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                if (candidates.length > 2) ...[
                  const SizedBox(height: 24),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.6,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: candidates.length - 2,
                    itemBuilder: (context, index) {
                      final actualIndex = index + 2;
                      return FutureBuilder<double>(
                        future: calculateVotePercentage(
                            candidates[actualIndex]['userid']),
                        builder: (context, snapshot) {
                          final double votePercentage = snapshot.data ?? 0.0;
                          return VoteItemCard(
                            item: candidates[actualIndex],
                            votePercentage: votePercentage,
                            onTap: () => _confirmSelection(actualIndex),
                            isDarkMode: isDarkMode,
                            isLarge: false,
                          );
                        },
                      );
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class VoteItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final double votePercentage;
  final VoidCallback onTap;
  final bool isDarkMode;
  final bool isLarge;

  const VoteItemCard({
    super.key,
    required this.item,
    required this.votePercentage,
    required this.onTap,
    required this.isDarkMode,
    required this.isLarge,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkIfUserVoted(item['id']),
      builder: (context, snapshot) {
        final bool hasVoted = snapshot.data ?? false;

        return GestureDetector(
          onTap: hasVoted
              ? () {
                  showTastySnackbar(
                    'Please try again.',
                    'You have already voted in this battle',
                    context,
                  );
                }
              : onTap,
          child: Opacity(
            opacity: hasVoted ? 0.5 : 1.0,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: isLarge ? 8 : 4),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? kDarkModeAccent.withOpacity(0.1)
                    : kWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: isLarge ? 16 : 8),
                      Text(
                        '${votePercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: isLarge ? 32 : 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? kWhite : kBlack,
                        ),
                      ),
                      SizedBox(height: isLarge ? 16 : 8),
                      Container(
                        height: isLarge ? 120 : 60,
                        width: isLarge ? 120 : 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kAccent.withOpacity(0.5),
                            width: isLarge ? 3 : 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            item['image'] ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                getAssetImageForItem(item['image']),
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: isLarge ? 16 : 8),
                      Flexible(
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: isLarge ? 8 : 4),
                          child: Text(
                            capitalizeFirstLetter(item['name'] ?? 'Tasty'),
                            style: TextStyle(
                              fontSize: isLarge ? 18 : 12,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? kWhite : kBlack,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(height: isLarge ? 16 : 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkIfUserVoted(String battleId) async {
    try {
      final userId = userService.userId;
      if (userId == null) return false;
      return await BattleService.instance.hasUserVoted(battleId, userId);
    } catch (e) {
      print("Error checking vote status: $e");
      return false;
    }
  }
}
