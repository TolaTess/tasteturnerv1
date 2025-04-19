import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:readmore/readmore.dart';

import '../constants.dart';
import '../data_models/post_model.dart';
import '../helper/utils.dart';
import '../pages/comment_section.dart';
import '../screens/friend_screen.dart';
import '../bottom_nav/profile_screen.dart';
import '../screens/user_profile_screen.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/follow_button.dart';
import '../widgets/icon_widget.dart';
import '../widgets/optimized_image.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final String screen;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.screen = 'post',
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post post;
  late ScrollController _scrollController;
  bool lastStatus = true;
  bool isLiked = false;
  int likesCount = 0;
  final TextEditingController _commentController = TextEditingController();

  _scrollListener() {
    if (isShrink != lastStatus) {
      setState(() {
        lastStatus = isShrink;
      });
    }
  }

  bool get isShrink {
    return _scrollController.hasClients &&
        _scrollController.offset > (260 - kToolbarHeight);
  }

  @override
  void initState() {
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    post = widget.post;
    if (widget.post.username == null || widget.post.username!.isEmpty) {
      _checkAndFetchPost();
    }
    super.initState();

    isLiked = post.numLikes.contains(userService.userId);
    likesCount = post.numLikes.length;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkAndFetchPost() async {
    try {
      final DocumentSnapshot postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.id)
          .get();

      if (postSnapshot.exists) {
        setState(() {
          post = Post.fromFirestore(postSnapshot);
        });
      }
    } catch (e) {
      print("Error fetching post details: $e");
    }
  }

  /// ✅ Toggle like status & update Firestore
  Future<void> toggleLikePost() async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
    final postSnapshot = await postRef.get();

    if (!postSnapshot.exists) return;

    List<String> likes = List<String>.from(postSnapshot['numLikes'] ?? []);

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

    await postRef.update({'numLikes': likes});
  }

  void _showCommentsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return CommentSection(postId: post.id);
      },
    );
  }

  /// ✅ Add comment to Firestore & increment count
  Future<void> addComment(String content) async {
    if (content.trim().isEmpty) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
    final commentRef = postRef.collection('comments').doc();

    await commentRef.set({
      'userId': userService.userId,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // ✅ Increment comment count in Firestore
    await postRef.update({
      'numComments': FieldValue.increment(1),
    });

    setState(() {
      post.numComments += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final List<String> imageUrls = List<String>.from(post.mediaPaths);

    if (imageUrls.isEmpty) {
      imageUrls.add(intPlaceholderImage);
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Sliver AppBar with image
            SliverAppBar(
              expandedHeight: 310,
              pinned: true,
              floating: false,
              title: isShrink
                  ? Text(
                      widget.screen == 'post' ? 'Posts' : 'My Posts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                    )
                  : const Text(emptyString),
              leading: InkWell(
                onTap: widget.screen == 'post'
                    ? () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BottomNavSec(
                              selectedIndex: 0,
                              foodScreenTabIndex: 1,
                            ),
                          ),
                        )
                    : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ProfileScreen()),
                        ),
                child: const IconCircleButton(
                  isColorChange: true,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: imageUrls.length == 1
                    ? OptimizedImage(
                        imageUrl: imageUrls.first,
                        fit: BoxFit.cover,
                      )
                    : PageView.builder(
                        itemCount: imageUrls.length,
                        itemBuilder: (context, index) {
                          final imageUrl = imageUrls[index];
                          return OptimizedImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    userService.userId == post.userId
                        ? const SizedBox.shrink()
                        : const SizedBox(height: 3.0),

                    // User Info
                    userService.userId == post.userId
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserProfileScreen(
                                        userId: post.userId,
                                      ),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 23,
                                  backgroundColor: kAccent.withOpacity(kOpacity),
                                  child: CircleAvatar(
                                    backgroundImage: (post.avatar != null &&
                                            post.avatar!.isNotEmpty &&
                                            post.avatar!.contains('http'))
                                        ? NetworkImage(post.avatar!)
                                        : const AssetImage(intPlaceholderImage)
                                            as ImageProvider,
                                    radius: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10.0),
                              Flexible(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UserProfileScreen(
                                          userId: post.userId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      //username
                                      Row(
                                        children: [
                                          Text(
                                            post.username ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 8,
                                          ),

                                          // verified icon
                                          post.isPremium == true
                                              ? const Icon(
                                                  Icons.verified,
                                                  color: kAccent,
                                                  size: 18,
                                                )
                                              : const SizedBox.shrink(),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              // Follow button - Show only if the user is not viewing their own profile
                              if (userService.userId != post.userId)
                                Obx(() {
                                  bool isFollowing =
                                      friendController.isFollowing(post.userId);

                                  // ✅ Properly check if the profile ID is in the following list
                                  if (!isFollowing) {
                                    isFollowing = friendController.followingList
                                        .contains(post.userId);
                                  }

                                  return FollowButton(
                                    h: 30,
                                    w: 80,
                                    title: isFollowing ? 'Unfollow' : follow,
                                    press: () {
                                      if (isFollowing) {
                                        friendController.unfollowFriend(
                                            userService.userId ?? '',
                                            post.userId,
                                            context);
                                      } else {
                                        friendController.followFriend(
                                            userService.userId ?? '',
                                            post.userId,
                                            context);
                                      }

                                      // ✅ Toggle UI immediately for better user experience
                                      friendController
                                          .toggleFollowStatus(post.userId);
                                    },
                                  );
                                }),
                            ],
                          ),

                    // Title
                    userService.userId == post.userId
                        ? const SizedBox.shrink()
                        : const SizedBox(
                            height: 10,
                          ),

                    //button: love, comment, send to, bookmark
                    userService.userId == post.userId
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            child: Row(
                              children: [
                                // ❤️ Like Button
                                GestureDetector(
                                  onTap: toggleLikePost,
                                  child: Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isLiked ? Colors.red : null,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "$likesCount likes",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FriendScreen(
                                          dataSrc: post.toFirestore(),
                                          screen: widget.screen,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.send_outlined,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    userService.userId == post.userId
                        ? const SizedBox.shrink()
                        : const SizedBox(
                            height: 12,
                          ),

                    //content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      child: ReadMoreText(
                        post.title ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                        trimLines: 2,
                        colorClickableText: kAccent,
                        trimMode: TrimMode.Line,
                        trimCollapsedText: 'more',
                        trimExpandedText: '...less',
                        moreStyle: const TextStyle(
                          fontSize: 14,
                          color: kBackgroundColor,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),

                    //number of comments
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: GestureDetector(
                        onTap:
                            _showCommentsBottomSheet, // ✅ Open comments list on tap
                        child: Text(
                          "View all ${post.numComments} comments",
                          style: TextStyle(
                            color: isDarkMode
                                ? kBackgroundColor
                                : kDarkGrey.withValues(alpha: kOpacity),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    //time
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      child: Text(
                        timeAgo(post.timestamp),
                        style: const TextStyle(
                          color: kLightGrey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Related Posts (Staggered Grid View)
            Obx(() {
              if (postController.posts.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(child: Text('No posts available')),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(8.0),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  itemBuilder: (BuildContext context, int index) {
                    final post = postController.posts[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailScreen(
                              post: post,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          children: [
                            OptimizedImage(
                              imageUrl: post.mediaPaths.isNotEmpty
                                  ? post.mediaPaths.first
                                  : extPlaceholderImage,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200,
                            ),
                            if (post.mediaPaths.length > 1)
                              const Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(
                                  Icons.content_copy,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: postController.posts.length,
                ),
              );
            })
          ],
        ),
      ),
    );
  }
}
