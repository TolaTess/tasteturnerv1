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
import '../widgets/helper_widget.dart';
import '../widgets/icon_widget.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> dataSrc;
  final String screen;

  const ChallengeDetailScreen({
    super.key,
    required this.dataSrc,
    this.screen = 'battle_post',
  });

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  bool isLiked = false;
  bool isFollowing = false;
  int likesCount = 0;
  bool hasMeal = false;

  List<String> extractedItems = [];
  @override
  void initState() {
    if (widget.screen == 'myPost') {
      extractedItems = [widget.dataSrc['id'] ?? ''];
    } else {
      extractedItems = extractSlashedItems(
          widget.dataSrc['title'] ?? widget.dataSrc['name']);
    }
    _loadFavoriteStatus();
    super.initState();

    // Initialize isFollowing
    final targetUserId = widget.dataSrc['userId'] ??
        (extractedItems.isNotEmpty
            ? extractedItems.first
            : ''); // fallback to '' if empty
    isFollowing = friendController.isFollowing(targetUserId);

    _loadMeal();
  }

  Future<void> _loadMeal() async {
    final meal = await mealManager.getMealbyMealID(widget.dataSrc['id']);
    if (mounted) {
      setState(() {
        hasMeal = meal != null;
      });
    }
  }

  Future<void> _loadFavoriteStatus() async {
    final postId = widget.dataSrc['id'] ??
        (extractedItems.isNotEmpty
            ? extractedItems.first
            : ''); // fallback to '' if empty
    final postRef = firestore.collection('posts').doc(postId);
    final postSnapshot = await postRef.get();
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
    final targetUserId = widget.dataSrc['userId'] ??
        (extractedItems.isNotEmpty
            ? extractedItems.first
            : ''); // fallback to '' if empty
    if (isFollowing) {
      await friendController.unfollowFriend(
          userService.userId ?? '', targetUserId, context);
    } else {
      await friendController.followFriend(userService.userId ?? '',
          targetUserId, widget.dataSrc['name'] ?? '', context);
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
        firestore.collection(collectionName).doc(widget.dataSrc['id']);
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
        .doc(widget.dataSrc['id'])
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
      return widget.dataSrc['name']?.toString().isNotEmpty == true
          ? widget.dataSrc['name'].toString()
          : 'Food Battle ${widget.dataSrc['category']?.toString().isNotEmpty == true ? ' - ${widget.dataSrc['category'].toString()}' : ''}';
    } else if (widget.screen == 'myPost') {
      if (widget.dataSrc['name']?.toString().isNotEmpty != true) {
        return widget.dataSrc['senderId'] == userService.userId
            ? 'My Post'
            : 'Post';
      }
      final postName = widget.dataSrc['name'].toString();
      final userName = userService.currentUser?.displayName ?? '';
      return userName == postName ? 'My Post' : postName;
    } else {
      return widget.dataSrc['title']?.toString().isNotEmpty == true
          ? widget.dataSrc['title'].toString()
          : 'Group Challenge';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    // Real-time post stream for likes
    Stream<DocumentSnapshot<Map<String, dynamic>>> postStream() {
      final postId = widget.dataSrc['id'] ??
          (extractedItems.isNotEmpty ? extractedItems.first : '');
      return firestore.collection('posts').doc(postId).snapshots();
    }

    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () {
            if (widget.screen == 'myPost' || widget.screen == 'share_recipe') {
              Get.back();
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const BottomNavSec(
                  selectedIndex: 1,
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
            child: const IconCircleButton(
              isRemoveContainer: true,
            ),
          ),
        ),
        title: Text(
          textAlign: TextAlign.center,
          capitalizeFirstLetter(getTitle()),
          style: TextStyle(
            fontSize: getPercentageWidth(4, context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: getPercentageHeight(1, context)),
              // Challenge Thumbnail
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context)),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double sideLength = constraints.maxWidth; // Make it square

                    final List<String> imageUrls =
                        List<String>.from(widget.dataSrc['mediaPaths'] ?? []);
                    final String? fallbackImage =
                        widget.dataSrc['image'] as String?;

                    // Use fallback image if no array is provided
                    if (imageUrls.isEmpty && fallbackImage != null) {
                      imageUrls.add(fallbackImage);
                    }

                    if (imageUrls.isEmpty) {
                      imageUrls.add(intPlaceholderImage);
                    }

                    return Container(
                      width: sideLength,
                      height: sideLength,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: imageUrls.length == 1
                          ? Image.network(
                              imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                intPlaceholderImage,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Stack(
                              children: [
                                PageView.builder(
                                  itemCount: imageUrls.length,
                                  itemBuilder: (context, index) {
                                    final imageUrl = imageUrls[index];
                                    return Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Image.asset(
                                        intPlaceholderImage,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  },
                                ),
                                // ✅ Multiple Images Overlay Icon
                                if (imageUrls.length > 1)
                                  const Positioned(
                                    top: 15,
                                    right: 15,
                                    child: Icon(
                                      Icons.content_copy,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                              ],
                            ),
                    );
                  },
                ),
              ),

              SizedBox(height: getPercentageHeight(2, context)),

              // Favorite, Download Buttons
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context)),
                child: Center(
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
                            
                            // User Profile
                            if (widget.dataSrc['userId'] != userService.userId)
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(
                                      userId: widget.dataSrc['userId'] ??
                                          (extractedItems.isNotEmpty
                                              ? extractedItems.first
                                              : ''),
                                    ),
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: getPercentageWidth(3, context),
                                  backgroundColor:
                                      kAccent.withOpacity(kOpacity),
                                  child: Icon(
                                    Icons.person,
                                    color: kWhite,
                                    size: getPercentageWidth(4, context),
                                  ),
                                ),
                              ),
                            if (widget.dataSrc['userId'] ==
                                    userService.userId &&
                                !hasMeal) ...[
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreateRecipeScreen(
                                          networkImages: List<String>.from(
                                              widget.dataSrc['mediaPaths'] ??
                                                  []),
                                          mealId: widget.dataSrc['id'],
                                          screenType: 'post_add'),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: getPercentageWidth(3, context),
                                  backgroundColor:
                                      kAccent.withOpacity(kOpacity),
                                  child: Icon(
                                    Icons.add_circle,
                                    color: kWhite,
                                    size: getPercentageWidth(4.5, context),
                                  ),
                                ),
                              ),
                            ],
                            if (widget.dataSrc['userId'] ==
                                    userService.userId &&
                                !hasMeal) ...[
                              SizedBox(width: getPercentageWidth(7, context)),
                            ],
                            if (widget.dataSrc['userId'] !=
                                userService.userId) ...[
                              SizedBox(width: getPercentageWidth(7, context)),
                            ],

                            // Share Icon (Optional - Add functionality if needed)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FriendScreen(
                                      dataSrc: widget.dataSrc,
                                      screen: widget.screen,
                                    ),
                                  ),
                                );
                              },
                                  child: Icon(
                                Icons.share,
                                size: getPercentageWidth(4.5, context),
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
                                          mealId: widget.dataSrc['id'],
                                          userId: widget.dataSrc['userId'],
                                          title: widget.dataSrc['category'],
                                          createdAt: DateTime.now(),
                                          mediaPaths: List<String>.from(
                                              widget.dataSrc['mediaPaths'] ??
                                                  []),
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

                            // Favorite Icon with Toggle (real-time)
                            StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>>(
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
                                        size: getPercentageWidth(4.5  , context),
                                      ),
                                    ),
                                    SizedBox(width: getPercentageWidth(1, context)),
                                    Text("$likesCount",
                                      style: TextStyle(
                                        fontSize: getPercentageWidth(2, context),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            SizedBox(width: getPercentageWidth(7, context)),

                            // Follow Icon with Toggle (real-time)
                            if (widget.dataSrc['userId'] != userService.userId)
                              Obx(() {
                                final targetUserId = widget.dataSrc['userId'] ??
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
                            if (widget.dataSrc['userId'] != userService.userId)
                              SizedBox(width: getPercentageWidth(7, context)),

                            // Delete Icon if it's the user's post
                            if ((widget.dataSrc['userId'] ??
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
                                          fontSize: getPercentageWidth(4, context),
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
                                      postId: widget.dataSrc['id'] ??
                                          (extractedItems.isNotEmpty
                                              ? extractedItems.first
                                              : ''),
                                      userId: userService.userId ?? '',
                                      isBattle:
                                          widget.dataSrc['isBattle'] ?? false,
                                      battleId:
                                          widget.dataSrc['battleId'] ?? '',
                                    );
                                    if (context.mounted) {
                                      Get.to(() => const BottomNavSec(
                                            selectedIndex: 1,
                                          ));
                                    }
                                  }
                                },
                                child:
                                    Icon(Icons.delete,
                                        color: Colors.red,
                                        size: getPercentageWidth(4.5, context)),
                              ),
                            if ((widget.dataSrc['userId'] ??
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
              ),

              SizedBox(height: getPercentageHeight(2, context)),

              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context)),
                child: SearchContentGrid(
                  postId: widget.dataSrc['id'] ?? extractedItems.first,
                  listType: 'battle_post',
                ),
              ),

              SizedBox(height: getPercentageHeight(2, context)),
            ],
          ),
        ),
      ),
    );
  }
}
