import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../constants.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../bottom_nav/profile_screen.dart';
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
  @override
  void initState() {
    super.initState();
    _setupDataListeners();
    // Show Tasty popup after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddJoinTutorial();
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
    final categoryDatas = helperController.category;
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Get.to(() => const ProfileScreen()),
          child: Padding(
            padding: const EdgeInsets.only(left: 15),
            child: buildProfileAvatar(
              imageUrl: userService.currentUser!.profileImage ??
                  intPlaceholderImage,
              outerRadius: 20,
              innerRadius: 18,
              imageSize: 20,
            ),
          ),
        ),
        title: Text(
          'Food Inspiration',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode ? Colors.white24 : Colors.black12,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Get.to(
                () => const UploadBattleImageScreen(
                  battleId: battleIdConstant,
                  isMainPost: true,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: 15,
                ),

                //category options
                CategorySelector(
                  categories: categoryDatas,
                  selectedCategoryId: selectedCategoryId,
                  onCategorySelected: _updateCategoryData,
                  isDarkMode: isDarkMode,
                  accentColor: kAccent,
                  darkModeAccentColor: kDarkModeAccent,
                ),

                const SizedBox(
                  height: 20,
                ),

                //Challenge
                ExpansionTile(
                  collapsedIconColor: kAccent,
                  iconColor: kAccent,
                  textColor: kAccent,
                  collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                  initiallyExpanded: true,
                  title: const Text(
                    ingredientBattle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? kDarkModeAccent.withOpacity(kLowOpacity)
                            : kLightGrey.withOpacity(kLowOpacity),
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
                                      : getNextWeekday(
                                          battleList.first['dueDate'] ?? '')),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // GridView for discount data
                          SizedBox(
                            height: 185,
                            child: battleList.isEmpty
                                ? noItemTastyWidget(
                                    "No battles available yet",
                                    "The next battle will start soon. Stay tuned!",
                                    context,
                                    false,
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

                          const SizedBox(height: 20),

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
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const ProfileScreen(),
                                                  ),
                                                );
                                              },
                                              child: const Text(
                                                'Manage in profile screen',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: kAccent,
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
                const SizedBox(height: 15),

                //food challenge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: SearchContentGrid(
                    screenLength: 9,
                    listType: 'battle_post',
                    selectedCategory: selectedCategory,
                  ),
                ),

                const SizedBox(
                  height: 40,
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
                    height: 160,
                  )
                : Image.asset(
                    getAssetImageForItem(dataSrc['image']),
                    fit: BoxFit.cover,
                    height: 160,
                  ),
          ),
        ),
        const SizedBox(height: 10),
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
