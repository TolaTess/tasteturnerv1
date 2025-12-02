import 'package:flutter/material.dart';
import 'package:tasteturner/constants.dart';
import 'package:tasteturner/widgets/helper_widget.dart';
import 'package:tasteturner/service/post_service.dart';

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
  final ScrollController _scrollController = ScrollController();
  String selectedGoal = 'all';
  bool filterByRecipe = false;

  /// Load excluded ingredients configuration with error handling
  Future<void> loadExcludedIngredients() async {
    if (!mounted) return;

    try {
      // Use local excludeIngredients constant from utils.dart
      // Note: Challenge posts feature is currently disabled
      // This data is kept for potential future use
      debugPrint('Excluded ingredients loaded: ${excludeIngredients.length}');
    } catch (e) {
      debugPrint('Error loading excluded ingredients: $e');
      // Fail silently - not critical for main functionality
    }
  }

  /// Show success snackbar with consistent styling
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: kWhite, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: kAccent,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show info snackbar with consistent styling
  void _showInfoSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        backgroundColor: kAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _refreshPosts() async {
    if (!mounted) return;

    try {
    // Clear cache and refresh
      if (mounted) {
    setState(() {
      selectedGoal = 'all';
    });
      }

    PostService.instance.clearCategoryCache('all');

      // Trigger refresh in SearchContentGrid with null check
      final gridState = _gridKey.currentState;
      if (gridState != null && mounted) {
        await gridState.fetchContent();
    }

    // Show success feedback
      if (mounted) {
        _showSuccessSnackbar('Posts refreshed!');
      }
    } catch (e) {
      debugPrint('Error refreshing posts: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
                Icon(Icons.error_outline, color: kWhite, size: 20),
              SizedBox(width: 8),
                Text('Failed to refresh posts. Please try again.'),
            ],
          ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      }
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
        // Upload button tutorial removed since feature is disabled
      ],
    );
  }

  /// Build the AppBar with title, info icon, and filter button
  PreferredSizeWidget _buildAppBar(
      BuildContext context, TextTheme textTheme, bool isDarkMode,
      String? userGoal) {
    return AppBar(
        backgroundColor: kAccent,
        toolbarHeight: getPercentageHeight(11, context),
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "What's on Your Plate?",
                    style: textTheme.displayMedium
                        ?.copyWith(fontSize: getTextScale(5.3, context)),
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
                        'icon': Icons.auto_awesome,
                        'title': 'Filter by Recipe',
                        'description': 'Filter posts by recipes only',
                        'color': kAccent,
                      },
                      {
                        'icon': Icons.people,
                        'title': 'Community Posts',
                        'description': 'See what others are cooking and eating',
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
                _buildRecipeFilterButton(context, textTheme, isDarkMode),
              ],
            ),
          ),
          _buildDietMatchIndicator(context, textTheme, userGoal),
        ],
      ),
    );
  }

  /// Build recipe filter button
  Widget _buildRecipeFilterButton(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return IconButton(
                    icon: Icon(
                      filterByRecipe
                          ? Icons.restaurant_menu
                          : Icons.restaurant_menu_outlined,
                      color: filterByRecipe
                          ? kAccentLight.withValues(alpha: 0.7)
                          : kWhite.withOpacity(0.7),
                    ),
                    tooltip: 'Show posts with recipes only',
                    onPressed: () {
        if (!mounted) return;

                      setState(() {
                        filterByRecipe = !filterByRecipe;
                      });

                      // Show feedback
        _showInfoSnackbar(
                            filterByRecipe
                                ? 'Showing posts with recipes only'
                                : 'Showing all posts',
        );
      },
    );
  }

  /// Build diet match indicator
  Widget _buildDietMatchIndicator(
      BuildContext context, TextTheme textTheme, String? userGoal) {
    return Row(
              key: _addDietButtonKey,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: kWhite,
                  size: getIconScale(3.5, context),
                ),
        const SizedBox(width: 8),
                Text(
                  "Meals that match your $userGoal goal",
                  style: textTheme.bodySmall
                      ?.copyWith(fontSize: getTextScale(2.5, context)),
                ),
              ],
    );
  }

  /// Build the main body content
  Widget _buildBody(BuildContext context) {
    return RefreshIndicator(
        onRefresh: _refreshPosts,
        color: kAccent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Main content grid
              SearchContentGrid(
                key: _gridKey,
                screenLength: 24, // Show more images on this dedicated screen
                listType: 'post',
                selectedCategory: selectedGoal,
                filterByRecipe: filterByRecipe,
              ),
            ],
          ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final userGoal = userService.currentUser.value?.settings['dietPreference'];

    return Scaffold(
      appBar: _buildAppBar(context, textTheme, isDarkMode, userGoal),
      // Upload button removed - feature is disabled
      body: _buildBody(context),
    );
  }
}
