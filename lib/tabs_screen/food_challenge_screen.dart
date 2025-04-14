import 'package:flutter/material.dart';
import 'dart:async';

import '../constants.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../helper/utils.dart';
import '../screens/profile_screen.dart';
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
  String dueDate = '';
  DateTime targetDate = DateTime(2025, 1, 1, 12, 0, 0);
  Timer? _tastyPopupTimer;

  @override
  void initState() {
    super.initState();
    _updateIngredientList(selectedCategory);
    // Show Tasty popup after a short delay
    _tastyPopupTimer = Timer(const Duration(milliseconds: 6000), () {
      if (mounted) {
        tastyPopupService.showTastyPopup(context, 'food_challenge', [], []);
      }
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 50,
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
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ingredientBattle,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 15,
                    ),

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
                              "No battles available",
                              "",
                              context,
                              false,
                            )
                          : GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
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
                                    final ingredientData = await macroManager
                                        .fetchIngredient(ingredientId);

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
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Ingredient not found')),
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 15),

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
                                    final DateTime deadline = DateTime.parse(
                                        battleList.first['dueDate'] ?? '');
                                    final bool isDeadlineOver =
                                        deadline.isBefore(DateTime.now());

                                    // Case 1: Deadline is over
                                    if (isDeadlineOver) {
                                      return Text(
                                        'Deadline Over',
                                        style: const TextStyle(
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
                                      text: "Join Now",
                                      press: () async {
                                        String userId =
                                            userService.userId ?? '';
                                        String battleId = battleList.isNotEmpty
                                            ? battleList.first['categoryId']
                                            : '';

                                        if (userId.isEmpty ||
                                            battleId.isEmpty) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Error: Missing user ID or battle ID')),
                                          );
                                          return;
                                        }

                                        // Show instructions dialog before joining
                                        if (!mounted) return;
                                        bool? shouldJoin =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              backgroundColor: isDarkMode
                                                  ? kDarkGrey
                                                  : kWhite,
                                              title: const Text(
                                                'Food Battle Instructions',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: kAccent,
                                                ),
                                              ),
                                              content: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '🎨 Create a Masterpiece!',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color: isDarkMode
                                                            ? kWhite
                                                            : kBlack,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Rules of the Battle:',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isDarkMode
                                                            ? kWhite
                                                            : kBlack,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
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
                                                        color: Theme.of(context)
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
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: kAccent,
                                                  ),
                                                  child: const Text(
                                                    'Join Battle',
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (shouldJoin == true && mounted) {
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
                                            print("Error joining battle: $e");
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Failed to join battle')),
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
            child: Image.asset(
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
