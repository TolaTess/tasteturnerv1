import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../screens/createrecipe_screen.dart';
import '../screens/friend_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/food_analysis_results_screen.dart';
import '../themes/theme_provider.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../widgets/info_icon_widget.dart';
import '../widgets/video_player_widget.dart';
import 'recipe_detail.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> dataSrc;
  final String screen;
  final bool isMessage;
  final List<Map<String, dynamic>>? allPosts;
  final int initialIndex;

  const ChallengeDetailScreen({
    super.key,
    required this.dataSrc,
    this.screen = 'battle_post',
    this.isMessage = false,
    this.allPosts,
    this.initialIndex = 0,
  });

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen>
    with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _posts;
  late int _currentIndex;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fitAnimation;

  bool isLiked = false;
  bool isFollowing = false;
  int likesCount = 0;
  bool hasMeal = false;
  List<String> extractedItems = [];
  Map<String, dynamic> get _currentPostData => _posts[_currentIndex];

  // Video optimization variables
  Set<int> _loadedVideoIndices = {}; // Track which videos are loaded
  Set<int> _preloadedVideoIndices = {}; // Track preloaded videos
  final Set<String> _playingVideos = {}; // Track currently playing videos

  @override
  void initState() {
    super.initState();
    _posts = widget.allPosts ?? [widget.dataSrc];
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fitAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    Future.delayed(const Duration(milliseconds: 100), () {
      _animationController.forward();
    });

    _loadCurrentPostData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();

    // Clean up video tracking
    _loadedVideoIndices.clear();
    _preloadedVideoIndices.clear();
    _playingVideos.clear();

    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Cleanup distant videos to free memory
    _cleanupDistantVideos(index);

    _loadCurrentPostData();
  }

  void _cleanupDistantVideos(int currentIndex) {
    // Remove videos that are more than 2 pages away
    final distantIndices = _loadedVideoIndices
        .where((index) => (index - currentIndex).abs() > 2)
        .toList();

    for (final index in distantIndices) {
      _loadedVideoIndices.remove(index);
      _preloadedVideoIndices.remove(index);
    }
  }

  void _loadCurrentPostData() {
    if (widget.screen == 'myPost') {
      extractedItems = [_currentPostData['id'] ?? ''];
    } else {
      extractedItems = extractSlashedItems(
          _currentPostData['title'] ?? _currentPostData['name']);
    }

    final targetUserId = _currentPostData['userId'] ??
        (extractedItems.isNotEmpty ? extractedItems.first : '');

    setState(() {
      isFollowing = friendController.isFollowing(targetUserId);
    });

    _loadFavoriteStatus();
    _loadMeal();
  }

  Future<void> _loadMeal() async {
    try {
      final mealId = _currentPostData['mealId'];
      if (mealId != null && mealId.toString().isNotEmpty) {
        final meal = await mealManager.getMealbyMealID(mealId);
        if (mounted) {
          setState(() {
            hasMeal = meal != null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            hasMeal = false;
          });
        }
      }
    } catch (e) {
      print('Error loading meal: $e');
      if (mounted) {
        setState(() {
          hasMeal = false;
        });
      }
    }
  }

  bool get _isUserPost {
    return _currentPostData['userId'] == userService.userId;
  }

  // Show dialog to choose between manual recipe creation and AI analysis
  Future<void> _showRecipeChoiceDialog() async {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            'Create Recipe',
            style: TextStyle(
              color: isDarkMode ? kWhite : kBlack,
              fontWeight: FontWeight.w600,
              fontSize: getTextScale(4.5, context),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isUserPost
                    ? 'How would you like to create your recipe?'
                    : 'How would you like to create this recipe?',
                style: TextStyle(
                  color: isDarkMode
                      ? kWhite.withValues(alpha: 0.7)
                      : kBlack.withValues(alpha: 0.7),
                  fontSize: getTextScale(3.5, context),
                ),
              ),
              SizedBox(height: getPercentageHeight(2, context)),

              // Manual recipe option
              if (_isUserPost)
                ListTile(
                  leading: Icon(
                    Icons.edit,
                    color: kAccent,
                    size: getResponsiveBoxSize(context, 24, 24),
                  ),
                  title: Text(
                    'Create Manually',
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kBlack,
                      fontWeight: FontWeight.w500,
                      fontSize: getTextScale(4, context),
                    ),
                  ),
                  subtitle: Text(
                    'Add ingredients and steps yourself',
                    style: TextStyle(
                      color: isDarkMode
                          ? kWhite.withValues(alpha: 0.6)
                          : kBlack.withValues(alpha: 0.6),
                      fontSize: getTextScale(3, context),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _createManualRecipe();
                  },
                ),
              if (_isUserPost)
                SizedBox(height: getPercentageHeight(1, context)),

              // AI analysis option
              ListTile(
                leading: Icon(
                  Icons.auto_awesome,
                  color: canUseAI() ? kAccent : Colors.grey,
                  size: getResponsiveBoxSize(context, 24, 24),
                ),
                title: Row(
                  children: [
                    Text(
                      'AI Analysis',
                      style: TextStyle(
                        color: canUseAI()
                            ? (isDarkMode ? kWhite : kBlack)
                            : Colors.grey,
                        fontWeight: FontWeight.w500,
                        fontSize: getTextScale(4, context),
                      ),
                    ),
                    if (!canUseAI()) ...[
                      SizedBox(width: getPercentageWidth(2, context)),
                      Icon(
                        Icons.lock,
                        color: Colors.grey,
                        size: getResponsiveBoxSize(context, 16, 16),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  canUseAI()
                      ? 'Let AI analyze the food image'
                      : 'Premium feature - Subscribe to unlock',
                  style: TextStyle(
                    color: canUseAI()
                        ? (isDarkMode
                            ? kWhite.withValues(alpha: 0.6)
                            : kBlack.withValues(alpha: 0.6))
                        : Colors.grey,
                    fontSize: getTextScale(3, context),
                  ),
                ),
                onTap: canUseAI()
                    ? () {
                        Navigator.of(context).pop();
                        _analyzeWithAI(isDarkMode);
                      }
                    : () {
                        Navigator.of(context).pop();
                        showPremiumRequiredDialog(context, isDarkMode);
                      },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: kAccent,
                  fontWeight: FontWeight.w500,
                  fontSize: getTextScale(3.5, context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Manual recipe creation (existing flow)
  void _createManualRecipe() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRecipeScreen(
          networkImages:
              List<String>.from(_currentPostData['mediaPaths'] ?? []),
          mealId: _currentPostData['id'],
          screenType: 'post_add',
        ),
      ),
    );
  }

  // AI analysis flow
  Future<void> _analyzeWithAI(bool isDarkMode) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: kAccent),
              SizedBox(height: getPercentageHeight(2, context)),
              Text(
                'Analyzing food image with AI...',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                  fontSize: getTextScale(3.5, context),
                ),
              ),
            ],
          ),
        ),
      );

      // Get the first image from the post
      final mediaPaths =
          List<String>.from(_currentPostData['mediaPaths'] ?? []);
      if (mediaPaths.isEmpty) {
        Navigator.pop(context); // Close loading dialog
        _showErrorDialog('No image found to analyze');
        return;
      }

      final imageUrl = mediaPaths.first;

      // Download the image to create a File object
      final response = await http.get(Uri.parse(imageUrl));
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_analysis_image.jpg');
      await tempFile.writeAsBytes(bytes);

      // Analyze the image with AI
      final analysisResult = await geminiService.analyzeFoodImageWithContext(
        imageFile: tempFile,
        mealType: getMealTimeOfDay(), // Default meal type
      );

      Navigator.pop(context); // Close loading dialog

      // Navigate to food analysis results screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodAnalysisResultsScreen(
            imageFile: tempFile,
            analysisResult: analysisResult,
            postId: _currentPostData['id'] ?? '',
            screen: 'challenge_detail',
          ),
        ),
      );

      // Refresh meal data if analysis was completed
      if (result == true || result == null) {
        // Wait a moment for Firestore to propagate the update
        await Future.delayed(const Duration(milliseconds: 500));
        _loadMeal(); // Refresh meal data to update hasMeal state
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorDialog('AI analysis failed: $e');
    }
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Text(
          'Error',
          style: TextStyle(
            color: isDarkMode ? kWhite : kBlack,
            fontWeight: FontWeight.w600,
            fontSize: getTextScale(4.5, context),
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: isDarkMode
                ? kWhite.withValues(alpha: 0.8)
                : kBlack.withValues(alpha: 0.7),
            fontSize: getTextScale(3.5, context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(
                color: kAccent,
                fontWeight: FontWeight.w500,
                fontSize: getTextScale(3.5, context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFavoriteStatus() async {
    final postId = _currentPostData['id'] ??
        (extractedItems.isNotEmpty ? extractedItems.first : '');
    if (postId == null || postId.isEmpty) {
      setState(() {
        isLiked = false;
        likesCount = 0;
      });
      return;
    }
    final postRef = firestore.collection('posts').doc(postId);
    final postSnapshot = await postRef.get();
    if (!postSnapshot.exists) {
      setState(() {
        isLiked = false;
        likesCount = 0;
      });
      return;
    }
    final currentData = postSnapshot.data() ?? {};
    final List<String> likes =
        List<String>.from(currentData['favorites'] ?? []);
    if (mounted) {
      setState(() {
        isLiked = likes.contains(userService.userId);
        likesCount = likes.length;
      });
    }
  }

  Future<void> toggleFollow() async {
    final targetUserId = _currentPostData['userId'] ??
        (extractedItems.isNotEmpty ? extractedItems.first : '');
    if (isFollowing) {
      await friendController.unfollowFriend(
          userService.userId ?? '', targetUserId, context);
    } else {
      await friendController.followFriend(userService.userId ?? '',
          targetUserId, _currentPostData['name'] ?? '', context);
    }

    // Update the UI immediately
    friendController.toggleFollowStatus(targetUserId);
    if (mounted) {
      setState(() {
        isFollowing = friendController.isFollowing(targetUserId);
      });
    }
  }

  /// ✅ Toggle like status & update Firestore
  Future<void> toggleLikePost() async {
    String collectionName = 'posts';
    var postRef =
        firestore.collection(collectionName).doc(_currentPostData['id']);
    var postSnapshot = await postRef.get();

    // Get current favorites from Firestore to ensure we have the latest data
    final currentData = postSnapshot.data() ?? {};
    List<String> likes = List<String>.from(currentData['favorites'] ?? []);

    if (mounted) {
      setState(() {
        if (likes.contains(userService.userId)) {
          likes.remove(userService.userId ?? '');
          isLiked = false;
          likesCount--;
        } else {
          likes.add(userService.userId ?? '');
          isLiked = true;
          likesCount++;
        }
      });
    }

    // Use the correct collection reference for the update
    await firestore
        .collection(collectionName)
        .doc(_currentPostData['id'])
        .update({'favorites': likes});

    // Refresh like status and count from Firestore
    await _loadFavoriteStatus();
  }

  String getTitle() {
    if (extractedItems.isNotEmpty &&
        extractedItems.length > 1 &&
        extractedItems[1].isNotEmpty) {
      return extractedItems[1];
    }

    if (widget.screen == 'battle_post') {
      return _currentPostData['name']?.toString().isNotEmpty == true
          ? _currentPostData['name'].toString()
          : 'Food Battle ${widget.dataSrc['category']?.toString().isNotEmpty == true ? ' - ${widget.dataSrc['category'].toString()}' : ''}';
    } else if (widget.screen == 'myPost') {
      if (_currentPostData['name']?.toString().isNotEmpty != true) {
        return _currentPostData['senderId'] == userService.userId
            ? 'My Post'
            : 'Post';
      }
      final postName = _currentPostData['name'].toString();
      final userName = userService.currentUser.value?.displayName ?? '';
      return userName == postName ? 'My Post' : postName;
    } else {
      return _currentPostData['title']?.toString().isNotEmpty == true
          ? _currentPostData['title'].toString()
          : 'Group Challenge';
    }
  }

  Widget _buildMediaContent(String url,
      {bool isCurrentPage = true, int? pageIndex}) {
    // Enhanced video detection
    final videoExtensions = ['.mp4', '.mov', '.avi', '.webm', '.mkv', '.flv'];
    final isVideoByExtension =
        videoExtensions.any((ext) => url.toLowerCase().contains(ext));
    final isVideoByData = _currentPostData['isVideo'] == true;
    final isVideo = isVideoByExtension || isVideoByData;

    if (isVideo) {
      return _buildOptimizedVideoPlayer(url,
          isCurrentPage: isCurrentPage, pageIndex: pageIndex);
    }

    return _buildImageContent(url);
  }

  Widget _buildOptimizedVideoPlayer(String url,
      {bool isCurrentPage = true, int? pageIndex}) {
    final shouldAutoPlay = isCurrentPage && pageIndex == _currentIndex;
    final shouldPreload = pageIndex != null &&
        (pageIndex == _currentIndex - 1 || pageIndex == _currentIndex + 1);

    // For non-current pages, show thumbnail with play button
    if (!isCurrentPage && pageIndex != _currentIndex) {
      return _buildVideoThumbnail(url, pageIndex ?? 0);
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: OptimizedVideoPlayerWidget(
        videoUrl: url,
        autoPlay: shouldAutoPlay, // Only auto-play current video
        preload: shouldPreload,
        onVideoLoaded: () {
          if (pageIndex != null) {
            _loadedVideoIndices.add(pageIndex);
          }
        },
        onVideoDisposed: () {
          if (pageIndex != null) {
            _loadedVideoIndices.remove(pageIndex);
            _preloadedVideoIndices.remove(pageIndex);
          }
        },
        // Better performance settings
        enableControls: true,
        showLoadingIndicator: true,
        bufferDuration:
            const Duration(seconds: 3), // Smaller buffer for faster loading
      ),
    );
  }

  Widget _buildVideoThumbnail(String videoUrl, int pageIndex) {
    return Stack(
      children: [
        // Blurred background
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.8),
            child: Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 80,
                color: kWhite.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
        // Thumbnail if available
        Center(
          child: GestureDetector(
            onTap: () {
              // Load video when thumbnail is tapped
              setState(() {
                _currentIndex = pageIndex;
                _pageController.animateToPage(
                  pageIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              });
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                size: 60,
                color: kWhite,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageContent(String url) {
    return Stack(
      children: [
        // Blurred background
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: buildOptimizedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: Image.asset(
                intPlaceholderImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // Main image with natural aspect ratio
        Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: buildOptimizedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  errorWidget: Image.asset(
                    intPlaceholderImage,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    Stream<DocumentSnapshot<Map<String, dynamic>>> postStream() {
      final postId = _currentPostData['id'] ??
          (extractedItems.isNotEmpty ? extractedItems.first : '');
      return firestore.collection('posts').doc(postId).snapshots();
    }

    final postUserId =
        _currentPostData['userId'] ?? _currentPostData['senderId'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        leading: InkWell(
          onTap: () {
            Get.back();
          },
          child: Container(
            width: getPercentageWidth(6, context),
            height: getPercentageWidth(6, context),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: const IconCircleButton(),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'by ${capitalizeFirstLetter(getTitle())}',
              textAlign: TextAlign.center,
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: kWhite,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            InfoIconWidget(
              title: 'Post Details',
              description:
                  'View and interact with posts and community content',
              details: [
                {
                  'icon': Icons.favorite,
                  'title': 'Like Posts',
                  'description':
                      'Double tap or use the heart icon to like posts you enjoy',
                  'color': isDarkMode ? kWhite : kDarkGrey,
                },
                {
                  'icon': Icons.ios_share,
                  'title': 'Share Content',
                  'description': 'Share posts with friends and family',
                  'color': isDarkMode ? kWhite : kDarkGrey,
                },
                {
                  'icon': Icons.auto_awesome,
                  'title': 'Create Recipe',
                  'description':
                      'Analyze food images with AI or create recipes manually',
                  'color': isDarkMode ? kWhite : kDarkGrey,
                },
                {
                  'icon': Icons.restaurant,
                  'title': 'View Recipe',
                  'description':
                      'Access detailed recipe information and cooking instructions',
                  'color': isDarkMode ? kWhite : kDarkGrey,
                },
                {
                  'icon': Icons.person_add_alt_1_outlined,
                  'title': 'Follow Users',
                  'description':
                      'Follow other users to see their posts in your feed',
                  'color': isDarkMode ? kWhite : kDarkGrey,
                },
              ],
              iconColor: kAccent,
              tooltip: 'Challenge Information',
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              final postData = _posts[index];
              final List<String> imageUrls =
                  List<String>.from(postData['mediaPaths'] ?? []);
              final String? fallbackImage = postData['image'] as String?;
              if (imageUrls.isEmpty && fallbackImage != null) {
                imageUrls.add(fallbackImage);
              }
              if (imageUrls.isEmpty) {
                imageUrls.add(intPlaceholderImage);
              }

              // Optimize media loading based on page visibility
              final isCurrentPage = index == _currentIndex;
              final isAdjacentPage = (index - _currentIndex).abs() <= 1;

              return PageView.builder(
                itemCount: imageUrls.length,
                itemBuilder: (context, imageIndex) {
                  final mediaUrl = imageUrls[imageIndex];
                  return GestureDetector(
                    onDoubleTap: () {
                      toggleLikePost();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite_border
                                    : Icons.favorite,
                                color: kWhite,
                                size: getResponsiveBoxSize(context, 23, 23),
                              ),
                              const SizedBox(width: 8),
                              Text(isLiked ? 'Unliked' : 'Liked'),
                            ],
                          ),
                          backgroundColor: kAccent,
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    child: _buildMediaContent(
                      mediaUrl,
                      isCurrentPage: isCurrentPage && isAdjacentPage,
                      pageIndex: index,
                    ),
                  );
                },
              );
            },
          ),
          Padding(
            padding: EdgeInsets.only(
                bottom: getPercentageHeight(15, context),
                left: getPercentageWidth(10, context),
                right: getPercentageWidth(10, context)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(1, context)),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (postUserId != userService.userId)
                        SizedBox(width: getPercentageWidth(5.5, context)),
                      if (postUserId != userService.userId)
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfileScreen(
                                userId: _currentPostData['userId'] ??
                                    (extractedItems.isNotEmpty
                                        ? extractedItems.first
                                        : ''),
                              ),
                            ),
                          ),
                          child: CircleAvatar(
                            radius: getResponsiveBoxSize(context, 19, 19),
                            backgroundColor:
                                kAccent.withValues(alpha: kOpacity),
                            child: CircleAvatar(
                              backgroundImage:
                                  _currentPostData['profileImage'] != null &&
                                          _currentPostData['profileImage']
                                              .toString()
                                              .isNotEmpty &&
                                          _currentPostData['profileImage']
                                              .toString()
                                              .contains('http')
                                      ? CachedNetworkImageProvider(
                                          _currentPostData['profileImage']
                                              .toString())
                                      : const AssetImage(intPlaceholderImage)
                                          as ImageProvider,
                              radius: getResponsiveBoxSize(context, 17, 17),
                            ),
                          ),
                        ),
                      if (postUserId == userService.userId)
                        SizedBox(width: getPercentageWidth(7, context)),
                      if (postUserId != userService.userId)
                        SizedBox(width: getPercentageWidth(5.5, context)),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FriendScreen(
                                dataSrc: _currentPostData,
                                screen: widget.screen,
                              ),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.ios_share,
                          color: kWhite,
                          size: getResponsiveBoxSize(context, 23, 23),
                        ),
                      ),
                      if (!hasMeal && _currentPostData['isVideo'] != true)
                        SizedBox(width: getPercentageWidth(4, context)),
                      if (!hasMeal && _currentPostData['isVideo'] != true)
                        GestureDetector(
                          onTap: () {
                            _showRecipeChoiceDialog();
                          },
                          child: Container(
                            padding: EdgeInsets.all(
                                getPercentageWidth(1.5, context)),
                            decoration: BoxDecoration(
                              color: kWhite.withValues(alpha: kOpacity),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              color: kAccent,
                              size: getResponsiveBoxSize(context, 23, 23),
                            ),
                          ),
                        ),
                      SizedBox(width: getPercentageWidth(5.5, context)),
                      if (hasMeal)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailScreen(
                                  mealData: Meal(
                                    mealId: _currentPostData['mealId'],
                                    userId: _currentPostData['userId'],
                                    title: _currentPostData['category'],
                                    createdAt: DateTime.now(),
                                    mediaPaths: List<String>.from(
                                        _currentPostData['mediaPaths'] ?? []),
                                    serveQty: 1,
                                    calories: 0,
                                  ),
                                  screen: 'share_recipe',
                                ),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.restaurant,
                            size: getResponsiveBoxSize(context, 23, 23),
                            color: kAccent,
                          ),
                        ),
                      if (hasMeal)
                        SizedBox(width: getPercentageWidth(5.5, context)),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: postStream(),
                        builder: (context, snapshot) {
                          final data = snapshot.data?.data() ?? {};
                          final List<String> likes =
                              List<String>.from(data['favorites'] ?? []);
                          final bool isLiked =
                              likes.contains(userService.userId);
                          final int likesCount = likes.length;
                          return Row(
                            children: [
                              GestureDetector(
                                onTap: toggleLikePost,
                                child: Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isLiked ? Colors.red : kWhite,
                                  size: getResponsiveBoxSize(context, 23, 23),
                                ),
                              ),
                              SizedBox(width: getPercentageWidth(1, context)),
                              Text(
                                "$likesCount",
                                style: TextStyle(
                                  fontSize: getTextScale(3, context),
                                  fontWeight: FontWeight.w400,
                                  color: isLiked ? Colors.red : kWhite,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(width: getPercentageWidth(5.5, context)),
                      if (postUserId != userService.userId)
                        Obx(() {
                          final targetUserId = _currentPostData['userId'] ??
                              (extractedItems.isNotEmpty
                                  ? extractedItems.first
                                  : '');
                          final isFollowing =
                              friendController.isFollowing(targetUserId);
                          return GestureDetector(
                            onTap: toggleFollow,
                            child: CircleAvatar(
                              radius: getResponsiveBoxSize(context, 17, 17),
                              backgroundColor:
                                  kAccent.withValues(alpha: kOpacity),
                              child: Icon(
                                isFollowing
                                    ? Icons.people
                                    : Icons.person_add_alt_1_outlined,
                                color: isFollowing ? kAccentLight : kWhite,
                                size: getResponsiveBoxSize(context, 17, 17),
                              ),
                            ),
                          );
                        }),
                      if (postUserId != userService.userId)
                        SizedBox(width: getPercentageWidth(5.5, context)),
                      if ((postUserId ??
                              (extractedItems.isNotEmpty
                                  ? extractedItems.first
                                  : '')) ==
                          userService.userId)
                        GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                backgroundColor:
                                    isDarkMode ? kDarkGrey : kWhite,
                                title: Text(
                                  'Delete Post',
                                  style: TextStyle(
                                    color: isDarkMode ? kWhite : kBlack,
                                    fontWeight: FontWeight.w400,
                                    fontSize: getTextScale(4, context),
                                  ),
                                ),
                                content: Text(
                                    'Are you sure you want to delete this post?',
                                    style: TextStyle(
                                      color: isDarkMode ? kWhite : kBlack,
                                    )),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text(
                                      'Cancel',
                                      style: const TextStyle(
                                        color: kAccent,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await postController.deleteAnyPost(
                                postId: _currentPostData['id'] ??
                                    (extractedItems.isNotEmpty
                                        ? extractedItems.first
                                        : ''),
                                userId: userService.userId ?? '',
                                isBattle: _currentPostData['isBattle'] ?? false,
                                battleId: _currentPostData['battleId'] ?? '',
                              );
                              if (context.mounted) {
                                Get.to(() => const BottomNavSec(
                                      selectedIndex: 2,
                                    ));
                              }
                            }
                          },
                          child: Icon(Icons.delete,
                              color: Colors.red,
                              size: getResponsiveBoxSize(context, 23, 23)),
                        ),
                      if ((postUserId ??
                              (extractedItems.isNotEmpty
                                  ? extractedItems.first
                                  : '')) ==
                          userService.userId)
                        SizedBox(width: getPercentageWidth(7, context)),
                    ],
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
