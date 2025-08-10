import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../data_models/post_model.dart';
import '../data_models/profilescreen_data.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/helper_files.dart';
import '../helper/utils.dart';
import '../pages/dine_in_leaderboard.dart';
import '../pages/recipe_card_flex.dart';
import '../service/post_service.dart';

import 'loading_screen.dart';
import 'optimized_image.dart';
import 'cached_video_thumbnail.dart';

class SearchContentGrid extends StatefulWidget {
  const SearchContentGrid({
    super.key,
    this.screenLength = 9,
    required this.listType,
    this.postId = '',
    this.selectedCategory = '',
  });

  final int screenLength;
  final String listType;
  final String postId;
  final String selectedCategory;

  @override
  SearchContentGridState createState() => SearchContentGridState();
}

// Make the state class public so it can be accessed for refresh
class SearchContentGridState extends State<SearchContentGrid> {
  bool showAll = false;
  List<Map<String, dynamic>> searchContentDatas = [];
  bool isLoading = true;
  String? lastPostId;
  bool hasMorePosts = false;

  @override
  void initState() {
    super.initState();
    fetchContent();
  }

  @override
  void didUpdateWidget(SearchContentGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refetch content when category changes
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      fetchContent();
    }
  }

  // Method to refresh content (can be called from parent widgets)
  Future<void> refresh() async {
    await fetchContent();
  }

  // Method to fetch content (can be called from parent widgets)
  Future<void> fetchContent() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        searchContentDatas = [];
        lastPostId = null;
        hasMorePosts = false;
      });
    }

    try {
      if (widget.listType == "meals") {
        // Keep existing meals logic
        final snapshot = await firestore
            .collection('meals')
            .get()
            .then((value) => value.docs.map((doc) {
                  final data = doc.data();
                  data['id'] = doc.id;
                  return data;
                }).toList());

        if (mounted) {
          setState(() {
            searchContentDatas = snapshot;
            isLoading = false;
          });
        }
      } else if (widget.listType == "post" ||
          widget.listType == 'battle_post') {
        // Use new PostService for efficient loading
        final postService = PostService.instance;
        final result = await postService.getPostsFeed(
          category:
              widget.selectedCategory.isEmpty ? 'all' : widget.selectedCategory,
          limit: widget.screenLength * 2, // Load more for better UX
          excludePostId: widget.postId.isNotEmpty ? widget.postId : null,
          includeBattlePosts: true,
        );

        if (result.isSuccess && mounted) {
          // Filter out battle posts from current week
          final filteredPosts = _filterOutCurrentWeekBattlePosts(result.posts);

          setState(() {
            searchContentDatas = filteredPosts;
            lastPostId = result.lastPostId;
            hasMorePosts = result.hasMore;
            isLoading = false;
          });
        } else if (mounted) {
          setState(() {
            searchContentDatas = [];
            isLoading = false;
          });
          if (result.error != null) {
            print('Error fetching posts: ${result.error}');
          }
        }
      } else {
        if (mounted) {
          setState(() {
            searchContentDatas = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching content: $e');
      if (mounted) {
        setState(() {
          searchContentDatas = [];
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (!hasMorePosts || lastPostId == null || isLoading) return;

    try {
      final postService = PostService.instance;
      final result = await postService.getPostsFeed(
        category:
            widget.selectedCategory.isEmpty ? 'all' : widget.selectedCategory,
        limit: widget.screenLength,
        lastPostId: lastPostId,
        excludePostId: widget.postId.isNotEmpty ? widget.postId : null,
        includeBattlePosts: true,
        useCache: false, // Don't cache pagination
      );

      if (result.isSuccess && mounted) {
        // Filter out battle posts from current week
        final filteredPosts = _filterOutCurrentWeekBattlePosts(result.posts);

        setState(() {
          searchContentDatas.addAll(filteredPosts);
          lastPostId = result.lastPostId;
          hasMorePosts = result.hasMore;
        });
      }
    } catch (e) {
      print('Error loading more posts: $e');
    }
  }

  /// Filter out battle posts from the current week to avoid duplication
  List<Map<String, dynamic>> _filterOutCurrentWeekBattlePosts(
      List<Map<String, dynamic>> posts) {
    // Calculate current week's Monday and Friday
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    // Set time to start of Monday and end of Friday
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);

    return posts.where((post) {
      // Keep the post if it's not a battle post
      if (post['isBattle'] != true) {
        return true;
      }

      // For battle posts, check if they're from the current week
      if (post['createdAt'] != null) {
        try {
          final postDate = DateTime.parse(post['createdAt']);
          final isInCurrentWeek =
              postDate.isAfter(weekStart) && postDate.isBefore(weekEnd);

          // Remove battle posts from current week (they'll be shown in horizontal list)
          return !isInCurrentWeek;
        } catch (e) {
          // If date parsing fails, keep the post
          return true;
        }
      }

      // If no createdAt, keep the post
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = showAll
        ? searchContentDatas.length
        : (searchContentDatas.length > widget.screenLength
            ? widget.screenLength
            : searchContentDatas.length);

    return SimpleLoadingOverlay(
      isLoading: isLoading && searchContentDatas.isEmpty,
      message: 'Loading posts...',
      progressPercentage: 85,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show empty state only when not loading and no data
          if (searchContentDatas.isEmpty && !isLoading)
            Padding(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              child: noItemTastyWidget("No posts yet.", "", context, false, ''),
            ),

          // Show placeholder content when loading to give overlay something to cover
          if (isLoading && searchContentDatas.isEmpty)
            Container(
              height: getPercentageHeight(90, context), // Give it some height
              width: double.infinity,
              child: const SizedBox(), // Empty but takes space
            ),

          // Show actual content when available
          if (searchContentDatas.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount =
                    (constraints.maxWidth / 120).floor().clamp(3, 4);
                double childAspectRatio =
                    (constraints.maxWidth / crossAxisCount) / 150;

                return Column(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        final item = searchContentDatas[index];
                        return _buildGridItem(context, item, index);
                      },
                    ),
                    if (searchContentDatas.length > widget.screenLength)
                      Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: getPercentageHeight(2, context)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!showAll)
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    showAll = true;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kAccent,
                                  foregroundColor: kWhite,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Show More'),
                              )
                            else
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    showAll = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kAccent,
                                  foregroundColor: kWhite,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Show Less'),
                              ),
                          ],
                        ),
                      ),
                    if (hasMorePosts && showAll)
                      Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: getPercentageHeight(2, context)),
                        child: ElevatedButton(
                          onPressed: _loadMorePosts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccent,
                            foregroundColor: kWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Load More'),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGridItem(
      BuildContext context, Map<String, dynamic> item, int index) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final mediaPaths = List<String>.from(item['mediaPaths'] ?? []);
    final isVideo = item['isVideo'] ?? false;
    final isPremium = item['isPremium'] ?? false;

    return GestureDetector(
      onTap: () {
        if (widget.listType == "meals") {
          Get.to(() =>
              RecipeDetailScreen(mealData: Meal.fromJson(item['id'], item)));
        } else {
          Get.to(() => ChallengeDetailScreen(
                dataSrc: item,
                allPosts: searchContentDatas,
                initialIndex: index,
              ));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isDarkMode ? kWhite.withOpacity(0.1) : kBlack.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Image or video thumbnail
              if (mediaPaths.isNotEmpty)
                isVideo
                    ? CachedVideoThumbnail(
                        videoUrl: mediaPaths.first,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : OptimizedImage(
                        imageUrl: mediaPaths.first,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
              else
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: isDarkMode
                      ? kBlack.withOpacity(0.3)
                      : kWhite.withOpacity(0.3),
                  child: Icon(
                    Icons.image,
                    color: isDarkMode
                        ? kWhite.withOpacity(0.5)
                        : kBlack.withOpacity(0.5),
                  ),
                ),

              // Premium badge
              if (isPremium)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: kWhite,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal list widget for challenge posts
class ChallengePostsHorizontalList extends StatefulWidget {
  const ChallengePostsHorizontalList({super.key});

  @override
  State<ChallengePostsHorizontalList> createState() =>
      _ChallengePostsHorizontalListState();
}

class _ChallengePostsHorizontalListState
    extends State<ChallengePostsHorizontalList> {
  List<Map<String, dynamic>> challengePosts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallengePosts();
  }

  Future<void> _loadChallengePosts() async {
    try {
      final postService = PostService.instance;
      final posts = await postService.getBattlePostsForCurrentWeek(limit: 20);

      if (mounted) {
        setState(() {
          challengePosts = posts;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading battle posts: $e');
      if (mounted) {
        setState(() {
          challengePosts = [];
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if no challenge posts or still loading
    if (isLoading || challengePosts.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(4, context),
            vertical: getPercentageHeight(2, context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: kAccent,
                    size: getIconScale(4, context),
                  ),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Row(
                    children: [
                      Text(
                        'This Week\'s Challenges',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? kWhite : kBlack,
                        ),
                      ),
                      Text(
                        ' (Like to vote)',
                        style: textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: getTextScale(3.5, context),
                          color: kAccentLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              GestureDetector(
                onTap: () {
                  Get.to(() => const DineInLeaderboardScreen());
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(1, context),
                  ),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'View Dine In leaderboard to see who\'s winning!',
                    style: textTheme.bodySmall?.copyWith(
                      color: kAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: getPercentageHeight(20, context),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(4, context)),
            itemCount: challengePosts.length,
            itemBuilder: (context, index) {
              final post = challengePosts[index];
              return _buildChallengePostCard(context, post, index);
            },
          ),
        ),
        SizedBox(height: getPercentageHeight(2, context)),
      ],
    );
  }

  Widget _buildChallengePostCard(
      BuildContext context, Map<String, dynamic> post, int index) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final mediaPaths = List<String>.from(post['mediaPaths'] ?? []);
    final isVideo = post['isVideo'] ?? false;
    final isPremium = post['isPremium'] ?? false;
    final username = post['username'] ?? post['name'] ?? 'Unknown';
    final createdAt =
        post['createdAt'] != null ? DateTime.parse(post['createdAt']) : null;

    return Container(
      width: getPercentageWidth(35, context),
      margin: EdgeInsets.only(right: getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? kWhite.withOpacity(0.1) : kBlack.withOpacity(0.1),
          width: 1,
        ),
        color: isDarkMode ? kBlack.withOpacity(0.3) : kWhite.withOpacity(0.3),
      ),
      child: GestureDetector(
        onTap: () {
          Get.to(() => ChallengeDetailScreen(
                dataSrc: post,
                allPosts: challengePosts,
                initialIndex: index,
              ));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image/Video section
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Stack(
                    children: [
                      if (mediaPaths.isNotEmpty)
                        isVideo
                            ? CachedVideoThumbnail(
                                videoUrl: mediaPaths.first,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : OptimizedImage(
                                imageUrl: mediaPaths.first,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                      else
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: isDarkMode
                              ? kBlack.withOpacity(0.3)
                              : kWhite.withOpacity(0.3),
                          child: Icon(
                            Icons.image,
                            color: isDarkMode
                                ? kWhite.withOpacity(0.5)
                                : kBlack.withOpacity(0.5),
                          ),
                        ),

                      // Premium badge
                      if (isPremium)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.star,
                              color: kWhite,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Info section
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(getPercentageWidth(2, context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null) ...[
                      SizedBox(height: getPercentageHeight(0.5, context)),
                      Text(
                        _formatDate(createdAt),
                        style: textTheme.bodySmall?.copyWith(
                          color: isDarkMode
                              ? kWhite.withOpacity(0.7)
                              : kBlack.withOpacity(0.7),
                          fontSize: getTextScale(2, context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

//Profile Recipe List
class ProfileRecipeList extends StatefulWidget {
  const ProfileRecipeList({
    super.key,
  });

  @override
  State<ProfileRecipeList> createState() => _ProfileRecipeListState();
}

class _ProfileRecipeListState extends State<ProfileRecipeList> {
  List<Meal> demoMealsPlanData = [];

  @override
  void initState() {
    demoMealsPlanData = mealManager.meals;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          //generate user's recipe list
          ...List.generate(
            demoMealsPlanData.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: RecipeCardFlex(
                recipe: demoMealsPlanData[index],
                press: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeDetailScreen(
                      mealData: demoMealsPlanData[
                          index], // Pass the selected meal data
                    ),
                  ),
                ),
                height: 200,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//Story Slider Widget
class StorySlider extends StatelessWidget {
  const StorySlider({
    super.key,
    required this.dataSrc,
    required this.press,
    this.mHeight = 100,
    this.mWidth = 100,
  });

  final BadgeAchievementData dataSrc;
  final VoidCallback press;
  final double mHeight, mWidth;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return GestureDetector(
      onTap: press,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base circle with gradient
          Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: Container(
                  width: getResponsiveBoxSize(context, mWidth, mWidth),
                  height: getResponsiveBoxSize(context, mHeight, mHeight),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        getMealTypeColor('protein').withValues(alpha: 0.1),
                        getMealTypeColor('protein').withValues(alpha: 0.3),
                      ],
                    ),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/vegetable_stamp.jpg'),
                      fit: BoxFit.cover,
                      opacity: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Text centered in circle
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(getPercentageWidth(1, context)),
                child: Transform.rotate(
                  angle:
                      -0.3, // Negative angle for slight counter-clockwise rotation
                  child: Text(
                    dataSrc.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: isDarkMode ? kWhite : kBlack,
                          fontSize: getPercentageWidth(3, context),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchContent extends StatelessWidget {
  const SearchContent({
    super.key,
    required this.dataSrc,
    required this.press,
  });

  final Map<String, dynamic> dataSrc; // ✅ Data source map
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final List<dynamic>? mediaPaths = dataSrc['mediaPaths'] as List<dynamic>?;
    final bool isVideo = dataSrc['isVideo'] == true;

    final String? mediaPath = mediaPaths != null && mediaPaths.isNotEmpty
        ? mediaPaths.first as String
        : extPlaceholderImage;

    final isDietCompatible = dataSrc['category']!.toLowerCase() ==
        userService.currentUser.value?.settings['dietPreference'].toLowerCase();

    // Helper function to check if URL is video
    bool _isVideoUrl(String url) {
      final videoExtensions = ['.mp4', '.mov', '.avi', '.webm', '.mkv', '.flv'];
      return videoExtensions.any((ext) => url.toLowerCase().contains(ext));
    }

    final bool isMediaVideo =
        isVideo || (mediaPath != null && _isVideoUrl(mediaPath));

    // Widget to build video thumbnail
    Widget _buildVideoThumbnail(String videoUrl) {
      return CachedVideoThumbnail(
        videoUrl: videoUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(8),
        placeholder: Container(
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(color: kAccent),
          ),
        ),
        errorWidget: Container(
          color: kBlueLight.withValues(alpha: 0.5),
          child: Center(
            child: Icon(
              Icons.videocam,
              color: isDarkMode ? kWhite : kBlack,
              size: getPercentageWidth(8, context),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: press,
      child: Stack(
        children: [
          // ✅ Media Display (Image or Video thumbnail)
          Container(
            height: MediaQuery.of(context).size.width > 800
                ? getPercentageHeight(18, context)
                : getPercentageHeight(18, context),
            width: MediaQuery.of(context).size.width > 800
                ? getPercentageWidth(33, context)
                : getPercentageWidth(33, context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isMediaVideo && mediaPath != null && mediaPath.isNotEmpty
                  ? Stack(
                      children: [
                        // Video thumbnail
                        _buildVideoThumbnail(mediaPath),
                      ],
                    )
                  : mediaPath != null && mediaPath.isNotEmpty
                      ? OptimizedImage(
                          imageUrl: mediaPath,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: const Center(
                            child: CircularProgressIndicator(color: kAccent),
                          ),
                          errorWidget: Image.asset(
                            intPlaceholderImage,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : Image.asset(
                          intPlaceholderImage,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
            ),
          ),

          // ✅ Multiple Images Overlay Icon
          if (mediaPaths != null && mediaPaths.length > 1 && !isMediaVideo)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.content_copy,
                  color: Colors.white,
                  size: getPercentageWidth(3.5, context),
                ),
              ),
            ),

          // ✅ Video Play Icon (for non-video content that is actually video)
          if (isMediaVideo)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: getPercentageWidth(3.5, context),
                ),
              ),
            ),

          //add diet compatibility indicator
          if (isDietCompatible)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.check,
                  color: kWhite,
                  size: getPercentageWidth(3.5, context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SearchContentPost extends StatelessWidget {
  const SearchContentPost({
    super.key,
    required this.dataSrc,
    required this.press,
  });

  final Post dataSrc; // Assuming Post model
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    final List<String> mediaPaths = dataSrc.mediaPaths;
    final String mediaPath =
        mediaPaths.isNotEmpty ? mediaPaths.first : extPlaceholderImage;
    final bool isVideo = dataSrc.isVideo == true;

    final isDietCompatible = dataSrc.category!.toLowerCase() ==
        userService.currentUser.value?.settings['dietPreference'].toLowerCase();

    // Helper function to check if URL is video
    bool _isVideoUrl(String url) {
      final videoExtensions = ['.mp4', '.mov', '.avi', '.webm', '.mkv', '.flv'];
      return videoExtensions.any((ext) => url.toLowerCase().contains(ext));
    }

    final bool isMediaVideo =
        isVideo || (mediaPath.isNotEmpty && _isVideoUrl(mediaPath));

    // Widget to build video thumbnail
    Widget _buildVideoThumbnail(String videoUrl) {
      return CachedVideoThumbnail(
        videoUrl: videoUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(8),
        placeholder: Container(
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(color: kAccent),
          ),
        ),
        errorWidget: Container(
          color: Colors.grey[800],
          child: Center(
            child: Icon(
              Icons.videocam,
              color: Colors.white,
              size: getPercentageWidth(8, context),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: press,
      child: Stack(
        children: [
          // Media Display (Image or Video thumbnail)
          Container(
            height: getPercentageHeight(33, context),
            width: getPercentageWidth(33, context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isMediaVideo && mediaPath.isNotEmpty
                  ? Stack(
                      children: [
                        // Video thumbnail
                        _buildVideoThumbnail(mediaPath),
                        // Video overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.center,
                                end: Alignment.center,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.play_circle_filled,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: getPercentageWidth(8, context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : mediaPath.isNotEmpty
                      ? OptimizedImage(
                          imageUrl: mediaPath,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: const Center(
                            child: CircularProgressIndicator(color: kAccent),
                          ),
                          errorWidget: Image.asset(
                            intPlaceholderImage,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : Image.asset(
                          intPlaceholderImage,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
            ),
          ),

          // ✅ Multiple Images Icon
          if (mediaPaths.length > 1 && !isMediaVideo)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.content_copy,
                  color: Colors.white,
                  size: getPercentageWidth(3.5, context),
                ),
              ),
            ),

          // ✅ Video Play Icon
          if (isMediaVideo)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: getPercentageWidth(3.5, context),
                ),
              ),
            ),

          // Diet compatibility indicator
          if (isDietCompatible)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.check,
                  color: kWhite,
                  size: getPercentageWidth(3.5, context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
