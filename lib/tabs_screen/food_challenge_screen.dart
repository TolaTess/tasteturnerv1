import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/tabs_screen/vote_screen.dart';
import 'dart:async';

import '../constants.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../helper/utils.dart';
import '../screens/profile_screen.dart';
import '../pages/upload_battle.dart';
import '../widgets/countdown.dart';
import '../widgets/helper_widget.dart';
import '../widgets/secondary_button.dart';
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
  bool showBattle = false;
  List<Map<String, dynamic>> _categoryDatasIngredient = [];
  @override
  void initState() {
    super.initState();
    _setupDataListeners();

     // Set default for ingredient category
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
    if (_categoryDatasIngredient.isNotEmpty &&
        selectedCategoryId.isEmpty) {
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
    tastyPopupService.showTutorialPopup(
      context: context,
      tutorialId: 'add_join_button',
      message: 'Tap here to join our weekly food battle!',
      targetKey: _addJoinButtonKey,
      onComplete: () {
        // Optional: Add any actions to perform after the tutorial is completed
      },
    );
  }

  void _setupDataListeners() {
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    await firebaseService.fetchGeneralData();
    await _updateIngredientList(selectedCategory);
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
      _updateIngredientList(category);
    });
  }

  Future<void> _updateIngredientList(String category) async {
    try {
      final newBattleList = await macroManager.getIngredientsBattle(category);
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
                  height: getPercentageHeight(2, context),
                ),

                //category options
                CategorySelector(
                  categories: _categoryDatasIngredient,
                  selectedCategoryId: selectedCategoryId,
                  onCategorySelected: _updateCategoryData,
                  isDarkMode: isDarkMode,
                  accentColor: kAccent,
                  darkModeAccentColor: kDarkModeAccent,
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
                      const Text(
                        ingredientBattle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        showBattle
                            ? 'Join the battle to create a masterpiece!'
                            : 'Next battle will start soon! Check back later!',
                        style: const TextStyle(
                          fontSize: 12,
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
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
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
                              const Icon(
                                Icons.hourglass_top_rounded,
                                color: Color(0xFFDF2D20),
                                size: 20,
                              ),
                              const SizedBox(
                                width: 4,
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
                            height: getPercentageHeight(23, context),
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
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 270,
                                      mainAxisExtent: 212,
                                      crossAxisSpacing: 15,
                                    ),
                                    itemCount: battleList.length,
                                    itemBuilder: (BuildContext ctx, index) {
                                      return DetailItem(
                                        dataSrc: battleList[index],
                                        onTap: () async {
                                          final ingredientId =
                                              battleList[index]['id'];
                                          print('ingredientId: $ingredientId');
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
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: kAccentLight,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          }

                                          // Case 3: Deadline not over and user hasn't joined
                                          return SecondaryButton(
                                            key: _addJoinButtonKey,
                                            text: "Join Now",
                                            press: () async {
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
                        child: const Text(
                          'Get Inspired',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
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

                //food challenge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: SearchContentGrid(
                    screenLength: 9,
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
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: dataSrc['image'].startsWith('http')
                ? Image.network(
                    dataSrc['image'],
                    fit: BoxFit.cover,
                    height: getPercentageHeight(18, context),
                  )
                : Image.asset(
                    getAssetImageForItem(dataSrc['image']),
                    fit: BoxFit.cover,
                    height: getPercentageHeight(18, context),
                  ),
          ),
        ),
        SizedBox(
          height: getPercentageHeight(1.5, context),
        ),
        Text(
          capitalizeFirstLetter(dataSrc['name']),
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.clip,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
