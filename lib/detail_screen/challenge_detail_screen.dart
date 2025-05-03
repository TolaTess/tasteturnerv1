import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../screens/friend_screen.dart';
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

    // Safely handle favorites
    final favorites = List<String>.from(widget.dataSrc['favorites'] ?? []);
    isLiked = favorites.contains(userService.userId);
    likesCount = favorites.length;
  }

  Future<void> _loadFavoriteStatus() async {
    final isFavorite = await firebaseService.isRecipeFavorite(
        userService.userId, widget.dataSrc['id'] ?? extractedItems.first);
    setState(() {
      isLiked = isFavorite;
    });
  }

  Future<void> toggleFollow() async {
    if (isFollowing) {
      friendController.unfollowFriend(userService.userId ?? '',
          widget.dataSrc['userId'] ?? extractedItems.first, context);
    } else {
      friendController.followFriend(userService.userId ?? '',
          widget.dataSrc['userId'] ?? extractedItems.first,
          widget.dataSrc['name'] ?? '',
          context);
    }

    // Update the UI immediately
    friendController
        .toggleFollowStatus(widget.dataSrc['userId'] ?? extractedItems.first);
  }

  /// ✅ Toggle like status & update Firestore
  Future<void> toggleLikePost() async {
    String collectionName = 'posts';
    var postRef =
        firestore.collection(collectionName).doc(widget.dataSrc['id']);
    var postSnapshot = await postRef.get();

    // If not found in posts, try battle_posts collection
    if (!postSnapshot.exists) {
      collectionName = 'battle_post';
      postRef = firestore.collection(collectionName).doc(widget.dataSrc['id']);
      postSnapshot = await postRef.get();

      if (!postSnapshot.exists) {
        print('Document not found in either posts or battle_posts');
        return;
      }
    }

    // Get current favorites from Firestore to ensure we have the latest data
    final currentData = postSnapshot.data() ?? {};
    List<String> likes = List<String>.from(currentData['favorites'] ?? []);

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

    // Use the correct collection reference for the update
    await firestore
        .collection(collectionName)
        .doc(widget.dataSrc['id'])
        .update({'favorites': likes});
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
          : 'Food Battle';
    } else if (widget.screen == 'myPost') {
      if (widget.dataSrc['name']?.toString().isNotEmpty != true) {
        return 'My Post';
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
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () {
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
            width: 30,
            height: 30,
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
          style: const TextStyle(
            fontSize: 18,
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
              const SizedBox(height: 24),
              // Challenge Thumbnail
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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

              const SizedBox(height: 24),

              // Favorite, Download Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: kAccent.withOpacity(0.1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 36),

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
                              child: const Icon(Icons.share),
                            ),

                            const SizedBox(width: 36),

                            // Favorite Icon with Toggle
                            GestureDetector(
                              onTap: toggleLikePost,
                              child: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked ? kRed : null,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "$likesCount",
                            ),

                            const SizedBox(width: 36),

                            // Follow Icon with Toggle
                            GestureDetector(
                              onTap: toggleFollow,
                              child: Icon(
                                isFollowing
                                    ? Icons.person
                                    : Icons.person_add_alt_1_outlined,
                                color: isFollowing ? kRed : null,
                              ),
                            ),
                            const SizedBox(width: 36),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SearchContentGrid(
                  postId: widget.dataSrc['id'] ?? extractedItems.first,
                  listType: widget.screen == 'group_cha'
                      ? 'group_cha'
                      : 'battle_post',
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
