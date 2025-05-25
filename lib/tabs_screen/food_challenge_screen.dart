import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/tabs_screen/vote_screen.dart';
import 'dart:async';

import '../constants.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../helper/utils.dart';
import '../screens/profile_screen.dart';
import '../pages/upload_battle.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/countdown.dart';
import '../widgets/helper_widget.dart';
import '../widgets/premium_widget.dart';
import '../widgets/primary_button.dart';
import '../widgets/category_selector.dart';

class FoodChallengeScreen extends StatefulWidget {
  const FoodChallengeScreen({super.key});

  @override
  State<FoodChallengeScreen> createState() => _FoodChallengeScreenState();
}

class _FoodChallengeScreenState extends State<FoodChallengeScreen> {
  String selectedCategory = 'all';
  String selectedCategoryId = '';
  List<Map<String, dynamic>> battleList = [];
  Timer? _tastyPopupTimer;
  final GlobalKey _addJoinButtonKey = GlobalKey();
  final GlobalKey _addInspirationButtonKey = GlobalKey();
  bool showBattle = false;
  List<Map<String, dynamic>> _categoryDatasIngredient = [];
  @override
  void initState() {
    super.initState();
    _setupDataListeners();

    _categoryDatasIngredient = [...helperController.macros];
    final generalCategory = {
      'id': 'general',
      'name': 'General',
      'category': 'General'
    };
    if (_categoryDatasIngredient.isEmpty ||
        _categoryDatasIngredient.first['id'] != 'general') {
      _categoryDatasIngredient.insert(0, generalCategory);
    }
    if (_categoryDatasIngredient.isNotEmpty && selectedCategoryId.isEmpty) {
      selectedCategoryId = _categoryDatasIngredient[0]['id'] ?? '';
      selectedCategory = _categoryDatasIngredient[0]['name'] ?? '';
    }
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
          arrowDirection: ArrowDirection.UP,
        ),
        TutorialStep(
          tutorialId: 'add_inspiration_button',
          message: 'Add visuals to inspire others!',
          targetKey: _addInspirationButtonKey,
          autoCloseDuration: const Duration(seconds: 5),
          arrowDirection: ArrowDirection.DOWN,
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
    if (!mounted) return;
    setState(() {
      showBattle = battleList.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
    super.dispose();
  }

  void _updateCategoryData(String categoryId, String category) {
    if (!mounted) return;
    setState(() {
      selectedCategoryId = categoryId;
      selectedCategory = category;
    });
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
    final battleDeadline = DateTime.parse(
        firebaseService.generalData['battleDeadline'] ??
            DateTime.now().toString());
    final isBattleDeadlineShow = isDateToday(battleDeadline);

    return Scaffold(
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: getPercentageWidth(4.5, context),
                        ),
                      ),
                      Text(
                        showBattle
                            ? 'Join the battle to create a masterpiece!'
                            : 'Next battle will start soon! Check back later!',
                        style: TextStyle(
                          fontSize: getPercentageWidth(3.5, context),
                          color: kAccentLight,
                        ),
                      ),
                      SizedBox(
                        height: getPercentageHeight(1, context),
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 15),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(kMidOpacity),
                        borderRadius: BorderRadius.circular(10),
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
                                size: getPercentageWidth(5, context),
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
                                            return const Text(
                                              'Deadline Over',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
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
                                                                  selectedCategory),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Text(
                                                !isBattleDeadlineShow
                                                    ? 'Manage in profile screen'
                                                    : 'Vote for your favorite dish!',
                                                style: TextStyle(
                                                  fontSize: getPercentageWidth(
                                                      4, context),
                                                  color: kAccentLight,
                                                  fontWeight: FontWeight.w600,
                                                ),
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
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16,
                                                              color: isDarkMode
                                                                  ? kWhite
                                                                  : kBlack,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
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
                                                          const SizedBox(
                                                              height: 8),
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
                                                              height: 1.4,
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
                                                  final user =
                                                      userService.currentUser;
                                                  await macroManager.joinBattle(
                                                    userId,
                                                    battleId,
                                                    selectedCategory,
                                                    user!.displayName ?? '',
                                                    '',
                                                  );
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
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height: getPercentageHeight(1, context),
                ),
                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : const SizedBox(height: 5),

                // ------------------------------------Premium / Ads------------------------------------

                userService.currentUser?.isPremium ?? false
                    ? const SizedBox.shrink()
                    : PremiumSection(
                        isPremium: userService.currentUser?.isPremium ?? false,
                        titleOne: joinChallenges,
                        titleTwo: premium,
                        isDiv: false,
                      ),

                // ------------------------------------Premium / Ads-------------------------------------
                userService.currentUser?.isPremium ?? false
                    ? SizedBox(
                        height: getPercentageHeight(1.5, context),
                      )
                    : SizedBox(
                        height: getPercentageHeight(2.5, context),
                      ),

                //category options
                CategorySelector(
                  categories: _categoryDatasIngredient,
                  selectedCategoryId: selectedCategoryId,
                  onCategorySelected: _updateCategoryData,
                  isDarkMode: isDarkMode,
                  accentColor: kAccentLight,
                  darkModeAccentColor: kDarkModeAccent,
                ),
                SizedBox(
                  height: getPercentageHeight(1.5, context),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 15.0, right: 5.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Get.to(
                          () => const UploadBattleImageScreen(
                            battleId: battleIdConstant,
                            isMainPost: true,
                          ),
                        ),
                        child: Text(
                          'Get Inspired',
                          style: TextStyle(
                            fontSize: getPercentageWidth(4.5, context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        key: _addInspirationButtonKey,
                        icon: const Icon(Icons.add, color: kAccent),
                        onPressed: () => Get.to(
                          () => const UploadBattleImageScreen(
                            battleId: battleIdConstant,
                            isMainPost: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: getPercentageHeight(1.5, context),
                ),

                //food challenge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: SearchContentGrid(
                    screenLength: 12,
                    listType: 'battle_post',
                    selectedCategory: selectedCategory,
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
            height: 8,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              capitalizeFirstLetter(dataSrc['name']),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
