import 'package:flutter/material.dart';
import 'package:tasteturner/tabs_screen/vote_screen.dart';
import 'dart:async';

import '../constants.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../helper/utils.dart';
import '../screens/profile_screen.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/countdown.dart';
import '../widgets/premium_widget.dart';
import '../widgets/primary_button.dart';
import '../service/battle_service.dart';

class FoodChallengeScreen extends StatefulWidget {
  const FoodChallengeScreen({super.key});

  @override
  State<FoodChallengeScreen> createState() => _FoodChallengeScreenState();
}

class _FoodChallengeScreenState extends State<FoodChallengeScreen> {
  List<Map<String, dynamic>> battleList = [];
  Timer? _tastyPopupTimer;
  final GlobalKey _addJoinButtonKey = GlobalKey();
  final GlobalKey _addInspirationButtonKey = GlobalKey();
  bool showBattle = false;
  List<Map<String, dynamic>> participants = [];
  bool _isLoadingParticipants = true;
  bool _isPreviousBattle = false;

  @override
  void initState() {
    super.initState();
    _setupDataListeners();
    // Show Tasty popup after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showAddJoinTutorial();
      setState(() {
        showBattle = battleList.isNotEmpty;
      });
    });
  }

  void _showAddJoinTutorial() {
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'food_tab_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'add_join_button',
          message: 'Check weekly battles and join in to win!',
          targetKey: _addJoinButtonKey,
          autoCloseDuration: const Duration(seconds: 5),
        ),
        TutorialStep(
          tutorialId: 'add_inspiration_button',
          message: 'Add visuals to inspire others!',
          targetKey: _addInspirationButtonKey,
          autoCloseDuration: const Duration(seconds: 5),
        ),
      ],
    );
  }

  void _setupDataListeners() {
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    await firebaseService.fetchGeneralData();
    await _updateIngredientList();
    if (battleList.isNotEmpty) {
      await _fetchParticipants('general');
    }
    if (!mounted) return;
    setState(() {
      showBattle = battleList.isNotEmpty;
    });
  }

  Future<void> _fetchParticipants(String category) async {
    if (!mounted) return;
    setState(() {
      _isLoadingParticipants = true;
      _isPreviousBattle = false;
    });

    try {
      final battleId =
          battleList.isNotEmpty ? battleList.first['categoryId'] : null;
      if (battleId == null) {
        if (mounted) {
          setState(() {
            participants = [];
            _isLoadingParticipants = false;
          });
        }
        return;
      }

      var fetchedParticipants =
          await BattleService.instance.getBattleParticipants(battleId);

      if (fetchedParticipants.isEmpty) {
        fetchedParticipants = await BattleService.instance
            .getPreviousBattleParticipants(battleId);
        if (mounted) {
          setState(() {
            _isPreviousBattle = true;
          });
        }
      }

      if (mounted) {
        setState(() {
          participants = fetchedParticipants;
          _isLoadingParticipants = false;
        });
      }
    } catch (e) {
      print("Error fetching participants: $e");
      if (mounted) {
        setState(() {
          _isLoadingParticipants = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateIngredientList() async {
    try {
      final newBattleList = await macroManager.getIngredientsBattle('general');
      if (!mounted) return;
      setState(() {
        battleList = newBattleList;
        showBattle = battleList.isNotEmpty;
      });
    } catch (e) {
      print("Error updating ingredient list: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update ingredients')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final battleDeadline = DateTime.parse(
        firebaseService.generalData['battleDeadline'] ??
            DateTime.now().toString());
    final isBattleDeadlineShow = isDateToday(battleDeadline);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        title: Text(
          'Dine In',
          style: textTheme.displaySmall?.copyWith(
            fontSize: getTextScale(7, context),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: getPercentageHeight(1, context),
                ),
                Center(
                  child: Text(
                    'Join the battle to create a masterpiece!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: kAccent,
                        ),
                  ),
                ),
                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                //Challenge
                ExpansionTile(
                  key: ValueKey(showBattle),
                  collapsedIconColor: kAccent,
                  iconColor: kAccent,
                  textColor: isDarkMode ? kWhite : kDarkGrey,
                  collapsedTextColor: kAccent,
                  initiallyExpanded: showBattle,
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: getPercentageHeight(1, context),
                      ),
                      Text(
                        key: _addJoinButtonKey,
                        ingredientBattle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        showBattle
                            ? 'Join the battle to create a masterpiece!'
                            : 'Next battle will start soon! Check back later!',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: kAccentLight),
                      ),
                      SizedBox(
                        height: getPercentageHeight(1, context),
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context)),
                      padding: EdgeInsets.all(getPercentageWidth(2, context)),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(kMidOpacity),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timer Row
                          Row(
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                color: Color(0xFFDF2D20),
                                size: kIconSizeLarge,
                              ),
                              SizedBox(
                                width: getPercentageWidth(1, context),
                              ),
                              Countdown(
                                  targetDate: battleList.isEmpty
                                      ? DateTime.now()
                                      : battleDeadline),
                            ],
                          ),
                          SizedBox(
                            height: getPercentageHeight(1, context),
                          ),

                          // GridView for discount data
                          SizedBox(
                            height: getPercentageHeight(22, context),
                            child: battleList.isEmpty
                                ? noItemTastyWidget(
                                    "No battles available yet",
                                    "The next battle will start soon. Stay tuned!",
                                    context,
                                    false,
                                    '',
                                  )
                                : GridView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisExtent:
                                          getPercentageHeight(21, context),
                                      crossAxisSpacing:
                                          getPercentageWidth(1, context),
                                      childAspectRatio: 0.1,
                                    ),
                                    itemCount: battleList.length,
                                    itemBuilder: (BuildContext ctx, index) {
                                      return DetailItem(
                                        dataSrc: battleList[index],
                                        onTap: () async {
                                          final ingredientId =
                                              battleList[index]['id'];
                                          final ingredientData =
                                              await macroManager
                                                  .fetchIngredient(
                                                      ingredientId);

                                          if (ingredientData != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    IngredientDetailsScreen(
                                                  item: ingredientData,
                                                  ingredientItems: const [],
                                                  isRefresh: false,
                                                ),
                                              ),
                                            );
                                          } else {
                                            if (mounted) {
                                              showTastySnackbar(
                                                'Please try again.',
                                                'Ingredient not found',
                                                context,
                                              );
                                            }
                                          }
                                        },
                                      );
                                    },
                                  ),
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          //join now button
                          Center(
                            child: battleList.isEmpty
                                ? null
                                : FutureBuilder<bool>(
                                    future: macroManager.isUserInBattle(
                                        userService.userId ?? '',
                                        battleList.first['categoryId']),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const CircularProgressIndicator(
                                          color: kAccent,
                                        );
                                      }

                                      bool isJoined = snapshot.data ?? false;

                                      return Builder(
                                        builder: (context) {
                                          final DateTime deadline =
                                              DateTime.parse(
                                                  battleList.first['dueDate'] ??
                                                      '');
                                          final bool isDeadlineOver =
                                              deadline.isBefore(DateTime.now());

                                          // Case 1: Deadline is over
                                          if (isDeadlineOver) {
                                            return Text(
                                              'Deadline Over',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.w600),
                                            );
                                          }

                                          // Case 2: User has already joined
                                          if (isJoined) {
                                            return GestureDetector(
                                              onTap: () {
                                                if (!isBattleDeadlineShow) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          const ProfileScreen(),
                                                    ),
                                                  );
                                                } else {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          VoteScreen(
                                                              isDarkMode:
                                                                  isDarkMode,
                                                              category:
                                                                  'general'),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Text(
                                                !isBattleDeadlineShow
                                                    ? 'Manage in profile screen'
                                                    : 'Vote for your favorite dish!',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                        color: kAccentLight,
                                                        fontWeight:
                                                            FontWeight.w600),
                                              ),
                                            );
                                          }

                                          // Case 3: Deadline not over and user hasn't joined
                                          return AppButton(
                                            text: "Join Now",
                                            type: AppButtonType.secondary,
                                            onPressed: () async {
                                              String userId =
                                                  userService.userId ?? '';
                                              String battleId =
                                                  battleList.isNotEmpty
                                                      ? battleList
                                                          .first['categoryId']
                                                      : '';

                                              if (userId.isEmpty ||
                                                  battleId.isEmpty) {
                                                if (!mounted) return;
                                                showTastySnackbar(
                                                  'Please try again.',
                                                  'Error: Missing user ID or battle ID',
                                                  context,
                                                );
                                                return;
                                              }

                                              // Show instructions dialog before joining
                                              if (!mounted) return;
                                              bool? shouldJoin =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    backgroundColor: isDarkMode
                                                        ? kDarkGrey
                                                        : kWhite,
                                                    title: const Text(
                                                      'Food Battle Instructions',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: kAccent,
                                                      ),
                                                    ),
                                                    content:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            '🎨 Create a Masterpiece!',
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .titleSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: isDarkMode
                                                                      ? kWhite
                                                                      : kBlack,
                                                                ),
                                                          ),
                                                          SizedBox(
                                                              height:
                                                                  getPercentageHeight(
                                                                      1,
                                                                      context)),
                                                          Text(
                                                            'Rules of the Battle:',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: isDarkMode
                                                                  ? kWhite
                                                                  : kBlack,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                              height:
                                                                  getPercentageHeight(
                                                                      1,
                                                                      context)),
                                                          Text(
                                                            '• Use only the listed ingredients plus:\n'
                                                            '  - Onions\n'
                                                            '  - Herbs\n'
                                                            '  - Spices\n\n'
                                                            '• Create a visually stunning dish\n'
                                                            '• Take a high-quality photo\n'
                                                            '• Submit before the deadline\n\n'
                                                            'Remember: Presentation is key! Users will vote based on appearance.',
                                                            style: TextStyle(
                                                              color: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.color,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(false),
                                                        child: Text(
                                                          'Cancel',
                                                          style: TextStyle(
                                                              color: isDarkMode
                                                                  ? kWhite
                                                                  : kDarkGrey),
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(true),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              kAccent,
                                                        ),
                                                        child: const Text(
                                                          'Join Battle',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );

                                              if (shouldJoin == true &&
                                                  mounted) {
                                                try {
                                                  final user = userService
                                                      .currentUser.value;
                                                  await macroManager.joinBattle(
                                                    userId,
                                                    battleId,
                                                    'general',
                                                    user!.displayName ?? '',
                                                    '',
                                                  );
                                                  await _fetchParticipants(
                                                      'general');
                                                  if (!mounted) return;
                                                  setState(() {});
                                                } catch (e) {
                                                  print(
                                                      "Error joining battle: $e");
                                                  if (!mounted) return;
                                                  showTastySnackbar(
                                                    'Please try again.',
                                                    'Failed to join battle',
                                                    context,
                                                  );
                                                }
                                              }
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getPercentageHeight(2, context)),

                SizedBox(
                  height: getPercentageHeight(1, context),
                ),
                userService.currentUser.value?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : const SizedBox(height: 5),

                // ------------------------------------Premium / Ads------------------------------------

                userService.currentUser.value?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : PremiumSection(
                        isPremium:
                            userService.currentUser.value?.isPremium ?? false,
                        titleOne: joinChallenges,
                        titleTwo: premium,
                        isDiv: false,
                      ),

                // ------------------------------------Premium / Ads-------------------------------------
                userService.currentUser.value?.isPremium ?? false
                    ? SizedBox(
                        height: getPercentageHeight(0.5, context),
                      )
                    : SizedBox(
                        height: getPercentageHeight(1.5, context),
                      ),

                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                if (participants.isNotEmpty)
                  _buildChallengersSection(context, isDarkMode)
                else
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: noItemTastyWidget(
                      "No Challengers Yet",
                      "Be the first to join the battle!",
                      context,
                      false,
                      '',
                    ),
                  ),

                SizedBox(
                  height: getPercentageHeight(7, context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengersSection(BuildContext context, bool isDarkMode) {
    final participantsWithImages = participants
        .where((p) => p['image']?.startsWith('http') ?? false)
        .toList();
    final participantsWithoutImagesCount =
        participants.length - participantsWithImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: getPercentageWidth(4, context)),
          child: Text(
            _isPreviousBattle
                ? 'Previous Battle Challengers'
                : 'Current Challengers',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
          ),
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        SizedBox(
          height: getPercentageHeight(30, context),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: participantsWithImages.length +
                (participantsWithoutImagesCount > 0 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == participantsWithImages.length &&
                  participantsWithoutImagesCount > 0) {
                return Container(
                  decoration: BoxDecoration(
                    color: kDarkGrey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '+$participantsWithoutImagesCount waiting to submit...',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: kWhite),
                      ),
                    ),
                  ),
                );
              }

              final participant = participantsWithImages[index];
              final imageUrl =
                  participant['image'] as String? ?? intPlaceholderImage;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VoteScreen(
                        isDarkMode: isDarkMode,
                        category: 'general',
                        initialCandidateId: participant['userid'],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Image.asset(intPlaceholderImage, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DetailItem extends StatelessWidget {
  const DetailItem({
    super.key,
    required this.dataSrc,
    required this.onTap,
  });

  final Map<String, dynamic> dataSrc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double itemHeight = MediaQuery.of(context).size.height * 0.28;
    final double minHeight = 160;
    final double maxHeight = 260;
    final double usedHeight = itemHeight.clamp(minHeight, maxHeight);
    return SizedBox(
      height: usedHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: dataSrc['image'].startsWith('http')
                    ? Image.network(
                        dataSrc['image'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Image.asset(
                        getAssetImageForItem(dataSrc['image']),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
              ),
            ),
          ),
          SizedBox(
            height: getPercentageHeight(1, context),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(2, context)),
            child: Text(
              capitalizeFirstLetter(dataSrc['name']),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: getTextScale(3.5, context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
