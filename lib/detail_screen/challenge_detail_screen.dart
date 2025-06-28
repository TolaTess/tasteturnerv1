import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tasteturner/detail_screen/recipe_detail.dart';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../screens/createrecipe_screen.dart';
import '../screens/friend_screen.dart';
import '../screens/user_profile_screen.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';

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

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  late List<Map<String, dynamic>> _posts;
  late int _currentIndex;
  late PageController _pageController;

  bool isLiked = false;
  bool isFollowing = false;
  int likesCount = 0;
  bool hasMeal = false;
  List<String> extractedItems = [];
  Map<String, dynamic> get _currentPostData => _posts[_currentIndex];

  @override
  void initState() {
    super.initState();
    _posts = widget.allPosts ?? [widget.dataSrc];
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadCurrentPostData();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _loadCurrentPostData();
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
    final meal = await mealManager.getMealbyMealID(_currentPostData['id']);
    if (mounted) {
      setState(() {
        hasMeal = meal != null;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    // Real-time post stream for likes
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
        leading: InkWell(
          onTap: () {
            if (widget.screen == 'myPost' ||
                widget.screen == 'share_recipe' ||
                widget.isMessage) {
              Get.back();
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const BottomNavSec(
                  selectedIndex: 2,
                ),
              ),
            );
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
        title: Text(
          textAlign: TextAlign.center,
          capitalizeFirstLetter(getTitle()),
          style: TextStyle(
            fontSize: getTextScale(4, context),
            fontWeight: FontWeight.w600,
            color: kWhite,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black.withOpacity(0.5),
                offset: Offset(0, 0),
              ),
            ],
          ),
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

              return PageView.builder(
                itemCount: imageUrls.length,
                itemBuilder: (context, imageIndex) {
                  final imageUrl = imageUrls[imageIndex];
                  return GestureDetector(
                    onDoubleTap: () {
                      toggleLikePost();
                      // Show heart animation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.favorite, color: kWhite),
                              SizedBox(width: 8),
                              Text(isLiked
                                  ? 'Added to favorites'
                                  : 'Removed from favorites'),
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
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        height: double.infinity,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(
                          intPlaceholderImage,
                          fit: BoxFit.cover,
                          height: double.infinity,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 30, left: 12, right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(1, context)),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: getPercentageWidth(7, context)),
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
                            radius: getResponsiveBoxSize(context, 13, 13),
                            backgroundColor: kAccent.withOpacity(kOpacity),
                            child: Icon(
                              Icons.person,
                              color: kWhite,
                              size: getResponsiveBoxSize(context, 18, 18),
                            ),
                          ),
                        ),
                      if (postUserId == userService.userId && !hasMeal) ...[
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateRecipeScreen(
                                    networkImages: List<String>.from(
                                        _currentPostData['mediaPaths'] ?? []),
                                    mealId: _currentPostData['id'],
                                    screenType: 'post_add'),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: getResponsiveBoxSize(context, 13, 13),
                            backgroundColor: kAccent.withOpacity(kOpacity),
                            child: Icon(
                              Icons.add_circle,
                              color: kWhite,
                              size: getResponsiveBoxSize(context, 18, 18),
                            ),
                          ),
                        ),
                      ],
                      if (postUserId == userService.userId && !hasMeal) ...[
                        SizedBox(width: getPercentageWidth(7, context)),
                      ],
                      if (postUserId != userService.userId) ...[
                        SizedBox(width: getPercentageWidth(7, context)),
                      ],
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
                          Icons.share,
                          size: getResponsiveBoxSize(context, 18, 18),
                        ),
                      ),
                      SizedBox(width: getPercentageWidth(7, context)),
                      if (hasMeal)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailScreen(
                                  mealData: Meal(
                                    mealId: _currentPostData['id'],
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
                            size: getPercentageWidth(4.5, context),
                            color: kAccent,
                          ),
                        ),
                      if (hasMeal)
                        SizedBox(width: getPercentageWidth(7, context)),
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
                                  color: isLiked ? kAccent : null,
                                  size: getPercentageWidth(4.5, context),
                                ),
                              ),
                              SizedBox(width: getPercentageWidth(1, context)),
                              Text(
                                "$likesCount",
                                style: TextStyle(
                                  fontSize: getTextScale(3, context),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(width: getPercentageWidth(7, context)),
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
                            child: Icon(
                              isFollowing
                                  ? Icons.people
                                  : Icons.person_add_alt_1_outlined,
                              color: isFollowing ? kAccentLight : null,
                              size: getPercentageWidth(4.5, context),
                            ),
                          );
                        }),
                      if (postUserId != userService.userId)
                        SizedBox(width: getPercentageWidth(7, context)),
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
                                      selectedIndex: 1,
                                    ));
                              }
                            }
                          },
                          child: Icon(Icons.delete,
                              color: Colors.red,
                              size: getPercentageWidth(4.5, context)),
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
