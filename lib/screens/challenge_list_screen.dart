import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../helper/utils.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/group_list.dart';
import '../widgets/icon_widget.dart';

class ChallengesListScreen extends StatefulWidget {
  const ChallengesListScreen({super.key, required this.isUserScreen});

  final bool isUserScreen;

  @override
  State<ChallengesListScreen> createState() => _ChallengesListScreenState();
}

class _ChallengesListScreenState extends State<ChallengesListScreen> {
  List<Map<String, dynamic>> myChallenge = [];
  List<Map<String, dynamic>> allChallenges = [];
  List<Map<String, dynamic>> displayedChallenges = [];
  List<Meal> demoMealsPlanData = [];

  @override
  void initState() {
    super.initState();
    _updateChallengeList();
    demoMealsPlanData = mealManager.meals;
  }

  void _updateChallengeList() async {
    String userId = userService.userId ?? '';

    myChallenge = await dailyDataController.getMyChallenges(userId);

    allChallenges = await helperController.getAllChallenges();

    if (widget.isUserScreen) {
      displayedChallenges = myChallenge;
    } else {
      displayedChallenges = allChallenges.where((challenge) {
        final List<dynamic> members = challenge['members'] ?? [];
        return !members.contains(userId);
      }).toList();
    }

    setState(() {});
  }

  /// **Join or Leave a Group**
  Future<void> toggleMembership(String groupId) async {
    try {
      DocumentReference groupRef =
          FirebaseFirestore.instance.collection('group_cha').doc(groupId);
      DocumentSnapshot groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        if (mounted) {
          showTastySnackbar(
            'Please try again.',
            'Group not found.',
            context,
          );
        }
        return;
      }

      Map<String, dynamic> groupData =
          groupDoc.data() as Map<String, dynamic>? ?? {};
      List<dynamic> members = groupData['members'] ?? [];

      if (members.contains(userService.userId)) {
        await groupRef.update({
          'members': FieldValue.arrayRemove([userService.userId])
        });
        if (mounted) {
          showTastySnackbar(
            'Success',
            'You left the group.',
            context,
          );
        }
      } else {
        await groupRef.set({
          'members': FieldValue.arrayUnion([userService.userId])
        }, SetOptions(merge: true));

        if (mounted) {
          showTastySnackbar(
            'Success',
            'You joined the group!',
            context,
          );
        }
      }

      _updateChallengeList();
    } catch (e) {
      print("Error updating group membership: $e");
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'Failed to update group membership.',
          context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Home AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back arrow
                    InkWell(
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BottomNavSec(
                                selectedIndex: 3,
                                foodScreenTabIndex: 1,
                              ),
                            ),
                          );
                        }
                      },
                      child: const IconCircleButton(
                        icon: Icons.arrow_back,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.isUserScreen
                              ? "My Challenges"
                              : "All Challenges",
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Show empty message if no challenges
              if (widget.isUserScreen && myChallenge.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 75),
                      const Center(
                        child: Text(
                          "You do not have any Challenge in Progress",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 50),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? kDarkModeAccent.withOpacity(0.08)
                              : kAccent.withOpacity(0.60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ChallengesListScreen(isUserScreen: false),
                          ),
                        ),
                        child: const Center(
                            child: Text("See Rest of the Challenges")),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    ListView.builder(
                      scrollDirection: Axis.vertical,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: displayedChallenges.length,
                      itemBuilder: (context, index) {
                        final challenge = displayedChallenges[index];
                        bool isMember = (challenge['members'] ?? [])
                            .contains(userService.userId);
                        return widget.isUserScreen
                            ? ChallengeItem(
                                dataSrc: challenge,
                                press: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChallengeDetailScreen(
                                      screen: 'group_cha',
                                      dataSrc: challenge,
                                    ),
                                  ),
                                ),
                              )
                            : GroupListItem(
                                dataSrc: challenge,
                                press: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChallengeDetailScreen(
                                      dataSrc: challenge,
                                      screen: 'group_cha',
                                    ),
                                  ),
                                ),
                                pressJoin: () =>
                                    toggleMembership(challenge['id']),
                                isMember: isMember,
                              );
                      },
                    ),
                    !widget.isUserScreen
                        ? const SizedBox.shrink()
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? kDarkModeAccent.withOpacity(0.08)
                                  : kAccent.withOpacity(0.60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            onPressed: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ChallengesListScreen(
                                        isUserScreen: false),
                              ),
                            ),
                            child: const SizedBox(
                                width: 200,
                                child: Align(
                                    alignment: Alignment.center,
                                    child: Text("More Challenges"))),
                          ),
                  ],
                ),

              const SizedBox(height: 72),
            ],
          ),
        ),
      ),
    );
  }
}

class ChallengeItem extends StatelessWidget {
  const ChallengeItem({
    super.key,
    required this.dataSrc,
    required this.press,
  });

  final Map<String, dynamic> dataSrc;
  final VoidCallback press;

  /// **Calculate progress based on startDate and endDate**
  double _calculateProgress(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return 0.0;

    final DateTime now = DateTime.now();
    final DateTime start = DateTime.parse(startDate);
    final DateTime end = DateTime.parse(endDate);

    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end)) return 1.0;

    final int totalDuration = end.difference(start).inDays;
    final int elapsedDays = now.difference(start).inDays;

    return (elapsedDays / totalDuration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Calculate progress using `startDate` and `endDate` from `dataSrc`
    final double progress = _calculateProgress(
      dataSrc['startDate'],
      dataSrc['endDate'],
    );

    final List<dynamic>? mediaPaths = dataSrc['mediaPaths'] as List<dynamic>?;
    final String? mediaPath = mediaPaths != null && mediaPaths.isNotEmpty
        ? mediaPaths.first as String
        : extPlaceholderImage;

    return GestureDetector(
      onTap: press,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Image
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: mediaPath != null &&
                          mediaPath.isNotEmpty &&
                          mediaPath.contains('http')
                      ? DecorationImage(
                          image: NetworkImage(mediaPath),
                          fit: BoxFit.cover,
                        )
                      : const DecorationImage(
                          image: AssetImage(intPlaceholderImage),
                          fit: BoxFit.cover,
                        ),
                ),
                clipBehavior: Clip.hardEdge,
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Text(
                      dataSrc['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // ✅ Progress Bar based on calculated progress
                    LinearProgressIndicator(
                      value: progress,
                      color: kAccent,
                      backgroundColor: Colors.grey[300],
                      minHeight: 5,
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
