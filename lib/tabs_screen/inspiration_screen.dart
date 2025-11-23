import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/constants.dart';
import 'package:tasteturner/widgets/helper_widget.dart';
import 'package:tasteturner/service/post_service.dart';

import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/info_icon_widget.dart';

class InspirationScreen extends StatefulWidget {
  const InspirationScreen({super.key});

  @override
  State<InspirationScreen> createState() => _InspirationScreenState();
}

class _InspirationScreenState extends State<InspirationScreen> {
  final GlobalKey<SearchContentGridState> _gridKey =
      GlobalKey<SearchContentGridState>();
  final GlobalKey _addDietButtonKey = GlobalKey();
  final GlobalKey _addUploadButtonKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  String selectedGoal = 'all';
  bool showChallengePosts = false;

    loadExcludedIngredients() async {
    await firebaseService.fetchGeneralData();
    final excludedIngredients =
        firebaseService.generalData['excludeIngredients'].toString().split(',');
    if (excludedIngredients.contains('true')) {
      setState(() {
        showChallengePosts = true;
      });
    } else {
      setState(() {
        showChallengePosts = false;
      });
    }
  }

  Future<void> _refreshPosts() async {
    // Clear cache and refresh
    setState(() {
      selectedGoal = 'all';
    });
    PostService.instance.clearCategoryCache('all');

    // Trigger refresh in SearchContentGrid
    if (_gridKey.currentState != null) {
      await _gridKey.currentState!.fetchContent();
    }

    // Show success feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: kWhite, size: 20),
              SizedBox(width: 8),
              Text('Posts refreshed!'),
            ],
          ),
          backgroundColor: kAccent,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddMealTutorial();
      loadExcludedIngredients();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showAddMealTutorial() {
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'inspiration_screen_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'add_diet_button',
          message: 'This icon on a post means it matches your diet!',
          targetKey: _addDietButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_upload_button',
          message: 'Tap here to upload your post!',
          targetKey: _addUploadButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final userGoal = userService.currentUser.value?.settings['dietPreference'];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccent,
        toolbarHeight: getPercentageHeight(10, context),
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "What's on Your Plate?",
                  style: textTheme.displayMedium?.copyWith(fontSize: getTextScale(5.8, context)),
                ),
                SizedBox(width: getPercentageWidth(2, context)),
                InfoIconWidget(
                  title: 'Community Inspiration',
                  description:
                      'Discover and share healthy meal ideas with the community',
                  details: const [
                    {
                      'icon': Icons.check_circle,
                      'title': 'Diet Matches',
                      'description':
                          'Posts marked with this icon match your dietary preferences',
                      'color': kAccent,
                    },
                    {
                      'icon': Icons.people,
                      'title': 'Community Posts',
                      'description': 'See what others are cooking and eating',
                      'color': kAccent,
                    },
                    {
                      'icon': Icons.add_a_photo,
                      'title': 'Share Your Meals',
                      'description':
                          'Upload photos of your healthy meals to inspire others',
                      'color': kAccent,
                    },
                    {
                      'icon': Icons.filter_list,
                      'title': 'Analyze Meals',
                      'description':
                          'Analyze any post with AI and get insights',
                      'color': kAccent,
                    },
                  ],
                  iconColor: isDarkMode ? kWhite : kDarkGrey,
                  tooltip: 'Inspiration Information',
                ),
              ],
            ),
            Row(
              key: _addDietButtonKey,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle,
                    color: kWhite, size: getIconScale(3.5, context)),
                SizedBox(width: 8),
                Text(
                  "Meals that match your $userGoal goal",
                  style: textTheme.bodySmall
                      ?.copyWith(fontSize: getTextScale(2.5, context)),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: CustomFloatingActionButtonLocation(
        verticalOffset: getPercentageHeight(5, context),
        horizontalOffset: getPercentageWidth(2, context),
      ),
      floatingActionButton: FloatingActionButton(
        key: _addUploadButtonKey,
        onPressed: () {
          // Upload functionality removed with battle feature
          // TODO: Add regular post upload if needed
        },
        backgroundColor: kAccent,
        child: Icon(Icons.add_a_photo, color: isDarkMode ? kWhite : kBlack),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        color: kAccent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics:
              AlwaysScrollableScrollPhysics(), // Enables pull-to-refresh even when content is short
          child: Column(
            children: [
              // Challenge posts horizontal list
              // if (showChallengePosts)
              // ChallengePostsHorizontalList(),

              // Main content grid
              SearchContentGrid(
                key: _gridKey,
                screenLength: 24, // Show more images on this dedicated screen
                listType: 'post',
                selectedCategory: selectedGoal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
