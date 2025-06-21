import 'package:flutter/material.dart';
import 'package:tasteturner/widgets/icon_widget.dart';

import '../constants.dart';
import '../helper/utils.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../service/battle_service.dart';

class VoteScreen extends StatefulWidget {
  final bool isDarkMode;
  final String category;
  final String? initialCandidateId;

  const VoteScreen({
    super.key,
    required this.isDarkMode,
    required this.category,
    this.initialCandidateId,
  });

  @override
  _VoteScreenState createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  List<Map<String, dynamic>> candidates = [];
  PageController? _pageController;
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCandidates(widget.category);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  /// **Fetch candidates based on `category` from Firestore**
  void _fetchCandidates(String category) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await firebaseService.fetchGeneralData();
      QuerySnapshot snapshot = await firestore
          .collection('battles')
          .where('category', isEqualTo: category.toLowerCase())
          .get();

      List<Map<String, dynamic>> fetchedCandidates = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Get current date's battle data
        final dates = data['dates'] as Map<String, dynamic>;

        Map<String, dynamic>? currentBattle;
        final now = DateTime.now();

        // Find the battle that is currently active by checking date ranges
        for (var dateKey in dates.keys) {
          try {
            final startDate = DateTime.parse(dateKey);
            final endDate = startDate.add(const Duration(days: 7));
            if (now.isAfter(startDate) && now.isBefore(endDate)) {
              currentBattle = dates[dateKey];
              break; // Found the active battle
            }
          } catch (e) {
            // Ignore keys that aren't valid dates
          }
        }

        // Fallback to the first entry if no active battle is found
        if (currentBattle == null && dates.isNotEmpty) {
          currentBattle = dates[dates.keys.first];
        }

        if (currentBattle != null) {
          final participants =
              currentBattle['participants'] as Map<String, dynamic>;

          for (var entry in participants.entries) {
            final userId = entry.key;
            final user = entry.value as Map<String, dynamic>;
            final imageUrl = user['image']?.toString().trim() ?? '';

            // Only add candidates with a valid, uploaded image
            if (imageUrl.startsWith('http')) {
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
          _isLoading = false;

          int initialIndex = 0;
          if (widget.initialCandidateId != null) {
            initialIndex = candidates
                .indexWhere((c) => c['userid'] == widget.initialCandidateId);
            if (initialIndex == -1) initialIndex = 0;
          }
          _currentIndex = initialIndex;
          _pageController = PageController(initialPage: initialIndex);
        });
      }
    } catch (e) {
      print("Error fetching candidates: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _confirmSelection() async {
    if (candidates.isEmpty) return;
    final selectedCandidate = candidates[_currentIndex];

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
                Navigator.pop(context);
                await castVote(selectedCandidate['id'],
                    selectedCandidate['userid'], userService.userId, context);
                // Refresh data after voting
                _fetchCandidates(widget.category);
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
            '',
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
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final dateInPast = DateTime.now()
        .isAfter(DateTime.parse(firebaseService.generalData['currentBattle']));

    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: const IconCircleButton(),
        ),
        title: Text(
          'Vote',
          style: TextStyle(
            fontSize: getTextScale(5, context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kAccent))
            : Stack(
                children: [
                  if (dateInPast)
                    noItemTastyWidget(
                      "Previous Battle Has Ended",
                      "The next battle will start soon. Stay tuned!",
                      context,
                      false,
                      '',
                    )
                  else if (candidates.isEmpty || candidates.length <= 1)
                    noItemTastyWidget(
                      candidates.length == 1
                          ? "Waiting for more users to join..."
                          : "No candidates yet",
                      '',
                      context,
                      false,
                      '',
                    )
                  else if (_pageController != null)
                    PageView.builder(
                      controller: _pageController,
                      itemCount: candidates.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final candidate = candidates[index];
                        return VoteCandidatePage(
                          candidate: candidate,
                          isDarkMode: isDarkMode,
                        );
                      },
                    ),
                  if (!dateInPast && candidates.length > 1)
                    Positioned(
                      bottom: getPercentageHeight(2, context),
                      left: 0,
                      right: 0,
                      child: Center(
                        child: FutureBuilder<bool>(
                          future: _checkIfUserVoted(
                              candidates[_currentIndex]['id']),
                          builder: (context, snapshot) {
                            final bool hasVoted = snapshot.data ?? false;
                            return ElevatedButton(
                              onPressed: hasVoted ? null : _confirmSelection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccent,
                                foregroundColor: kWhite,
                                padding: EdgeInsets.symmetric(
                                    horizontal: getPercentageWidth(10, context),
                                    vertical: getPercentageHeight(2, context)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                hasVoted ? 'Voted' : 'Vote for this Dish',
                                style: TextStyle(
                                  fontSize: getTextScale(5, context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class VoteCandidatePage extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final bool isDarkMode;

  const VoteCandidatePage({
    super.key,
    required this.candidate,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final double votePercentage = candidate['votePercentage'] ?? 0.0;
    final String imageUrl = candidate['image'] ?? intPlaceholderImage;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${votePercentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: getTextScale(6, context),
            fontWeight: FontWeight.bold,
            color: isDarkMode ? kWhite : kBlack,
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(4, context),
                vertical: getPercentageHeight(2, context)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: imageUrl.startsWith('http')
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.asset(intPlaceholderImage, fit: BoxFit.cover),
                    )
                  : Image.asset(imageUrl, fit: BoxFit.cover),
            ),
          ),
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Uploaded by ',
              style: TextStyle(
                fontSize: getTextScale(4, context),
                fontWeight: FontWeight.w400,
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
            Text(
              capitalizeFirstLetter(candidate['name'] ?? 'Tasty'),
              style: TextStyle(
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.w600,
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(12, context)), // Space for the floating button
      ],
    );
  }
}
