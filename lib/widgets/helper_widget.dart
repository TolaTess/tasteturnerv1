import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../data_models/post_model.dart';
import '../data_models/profilescreen_data.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/helper_files.dart';
import '../helper/utils.dart';
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
          category: widget.selectedCategory.isEmpty
              ? 'general'
              : widget.selectedCategory,
          limit: widget.screenLength * 2, // Load more for better UX
          excludePostId: widget.postId.isNotEmpty ? widget.postId : null,
          includeBattlePosts: true,
        );

        if (result.isSuccess && mounted) {
          setState(() {
            searchContentDatas = result.posts;
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
        category: widget.selectedCategory.isEmpty
            ? 'general'
            : widget.selectedCategory,
        limit: widget.screenLength,
        lastPostId: lastPostId,
        excludePostId: widget.postId.isNotEmpty ? widget.postId : null,
        includeBattlePosts: true,
        useCache: false, // Don't cache pagination
      );

      if (result.isSuccess && mounted) {
        setState(() {
          searchContentDatas.addAll(result.posts);
          lastPostId = result.lastPostId;
          hasMorePosts = result.hasMore;
        });
      }
    } catch (e) {
      print('Error loading more posts: $e');
    }
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
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 1,
                    crossAxisSpacing: 1,
                  ),
                  padding: EdgeInsets.only(
                    bottom: getPercentageHeight(1, context),
                  ),
                  itemCount: itemCount,
                  itemBuilder: (BuildContext ctx, index) {
                    final data = searchContentDatas[index];
                    return SearchContent(
                      dataSrc: data,
                      press: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChallengeDetailScreen(
                            screen: widget.listType,
                            dataSrc: data,
                            allPosts: searchContentDatas,
                            initialIndex: index,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

          // Show All / Load More / Pagination controls
          if (searchContentDatas.isNotEmpty && !isLoading)
            Column(
              children: [
                // Traditional show all toggle for limited content
                if (searchContentDatas.length > widget.screenLength && !showAll)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showAll = true;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: getPercentageHeight(1, context)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: getPercentageWidth(5, context),
                            color: kAccent,
                          ),
                          SizedBox(width: getPercentageWidth(2, context)),
                          Text(
                            'Show All ${searchContentDatas.length} Posts',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: kAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Load more button for pagination (when showing all and more posts available)
                if (showAll && hasMorePosts && widget.listType != "meals")
                  GestureDetector(
                    onTap: _loadMorePosts,
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        vertical: getPercentageHeight(1, context),
                        horizontal: getPercentageWidth(4, context),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: getPercentageHeight(1.5, context),
                        horizontal: getPercentageWidth(6, context),
                      ),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(25),
                        border:
                            Border.all(color: kAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: getPercentageWidth(4, context),
                            color: kAccent,
                          ),
                          SizedBox(width: getPercentageWidth(2, context)),
                          Text(
                            'Load More Posts',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: kAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Collapse button when showing all
                if (showAll && searchContentDatas.length > widget.screenLength)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showAll = false;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: getPercentageHeight(1, context)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            size: getPercentageWidth(5, context),
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: getPercentageWidth(2, context)),
                          Text(
                            'Show Less',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
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
