import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../data_models/post_model.dart';
import '../data_models/profilescreen_data.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';
import '../widgets/helper_widget.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';
import '../widgets/title_section.dart';
import '../service/post_service.dart';
import '../service/badge_service.dart';
import '../data_models/badge_system_model.dart' as BadgeModel;
import 'badges_screen.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool lastStatus = true;
  bool showAll = false;
  List<Map<String, dynamic>> searchContentDatas = [];
  bool isLoading = true;

  late ScrollController _scrollController;

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
    friendController.updateUserData(widget.userId);
    friendController.fetchFollowing(userService.userId ?? '');
    // Load badges for the viewed user
    BadgeService.instance.loadUserProgress(widget.userId);
    _fetchContent(widget.userId);
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  Future<void> _fetchContent(String userId) async {
    if (mounted) {
      setState(() {
        isLoading = true;
        searchContentDatas = [];
      });
    }

    try {
      // Use new optimized PostService for user posts
      final postService = PostService.instance;
      final result = await postService.getUserPosts(
        userId: userId,
        limit: 50, // Load more posts for profile
        includeUserData: true,
      );

      if (result.isSuccess && mounted) {
        setState(() {
          searchContentDatas = result.posts;
          isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          searchContentDatas = [];
          isLoading = false;
        });
        if (result.error != null) {
          print('Error fetching user posts: ${result.error}');
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

  // Helper function to convert Badge to BadgeAchievementData for compatibility
  BadgeAchievementData _convertBadgeToLegacyFormat(BadgeModel.Badge badge) {
    return BadgeAchievementData(
      title: badge.title,
      description: badge.description,
      userids: [widget.userId], // Single user for this context
      image: tastyImage, // Use default image
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: ValueKey('user_profile_${widget.userId}'),
      body: Obx(() {
        final user = friendController.userProfileData.value;

        // Show loading indicator while user data is being fetched
        if (user == null) {
          return const Center(
            key: ValueKey('loading_center'),
            child: CircularProgressIndicator(
              color: kAccent,
            ),
          );
        }

        String newUserid = widget.userId;

        // Move computation outside to avoid rebuilds during build
        final earnedBadges = BadgeService.instance.earnedBadges;
        final userBadges = earnedBadges.isNotEmpty
            ? earnedBadges.map(_convertBadgeToLegacyFormat).toList()
            : <BadgeAchievementData>[];

        return SafeArea(
          key: ValueKey('safe_area_${widget.userId}'),
          child: CustomScrollView(
              key: ValueKey('scroll_view_${widget.userId}'),
              controller: _scrollController,
              slivers: [
                // AppBar
                SliverAppBar(
                  backgroundColor:
                      themeProvider.isDarkMode ? kDarkGrey : kWhite,
                  pinned: true,
                  centerTitle: true,
                  automaticallyImplyLeading: false,
                  expandedHeight: getPercentageHeight(35, context),
                  title: isShrink
                      ? Text(
                          user.displayName ?? '',
                          style: textTheme.displayMedium?.copyWith(
                            fontSize: getTextScale(4.5, context),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const Text(emptyString),
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarIconBrightness:
                        isShrink ? Brightness.dark : Brightness.light,
                  ),
                  iconTheme: IconThemeData(
                    color: isShrink
                        ? themeProvider.isDarkMode
                            ? kWhite.withOpacity(0.80)
                            : kBlack
                        : themeProvider.isDarkMode
                            ? kLightGrey
                            : kPrimaryColor,
                  ),
                  leading: // Back arrow
                      InkWell(
                    onTap: () => Get.back(),
                    child: const IconCircleButton(
                      isRemoveContainer: true,
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Column(
                      children: [
                        // Header and Follow Buttons

                        Padding(
                          padding: EdgeInsets.only(
                              top: getPercentageHeight(1, context),
                              left: getPercentageWidth(6, context),
                              right: getPercentageWidth(6, context)),
                          child: Container(
                            padding:
                                EdgeInsets.all(getPercentageWidth(2, context)),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              capitalizeFirstLetter(user.displayName ?? ''),
                              style: textTheme.displaySmall?.copyWith(
                                fontSize: getTextScale(7, context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                                top: getPercentageHeight(1, context)),
                            padding: EdgeInsets.only(
                                left: getPercentageWidth(6, context),
                                right: getPercentageWidth(6, context),
                                top: getPercentageHeight(1, context)),
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              // borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                image: getImageProvider(user.profileImage),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                      ],
                    ),
                  ),
                ),

                // Badges Section
                SliverToBoxAdapter(
                  key: ValueKey('content_section_${widget.userId}'),
                  child: Column(
                    key: ValueKey('main_column_${widget.userId}'),
                    children: [
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // Follow Button

                              Obx(() {
                                bool isFollowing =
                                    friendController.isFollowing(newUserid);

                                if (!isFollowing) {
                                  isFollowing = friendController.followingList
                                      .contains(newUserid);
                                }

                                return AppButton(
                                  key: ValueKey(
                                      'follow_button_${widget.userId}'),
                                  height: 4.5,
                                  width: 30,
                                  type: AppButtonType.follow,
                                  text: isFollowing ? 'Unfollow' : follow,
                                  onPressed: () {
                                    if (isFollowing) {
                                      friendController.unfollowFriend(
                                          userService.userId ?? '',
                                          newUserid,
                                          context);
                                    } else {
                                      if (userService.userId == newUserid) {
                                        showTastySnackbar(
                                          'Cannot Follow Yourself',
                                          'You cannot follow yourself.',
                                          context,
                                        );
                                        return;
                                      }
                                      friendController.followFriend(
                                          userService.userId ?? '',
                                          newUserid,
                                          user.displayName ?? '',
                                          context);
                                    }

                                    // Update the UI immediately
                                    friendController
                                        .toggleFollowStatus(newUserid);
                                  },
                                );
                              }),

                              // Message Button
                              Obx(() {
                                bool isFollowing = friendController
                                    .followingList
                                    .contains(newUserid);
                                return AppButton(
                                  key: ValueKey(
                                      'message_button_${widget.userId}'),
                                  height: 4.5,
                                  width: 30,
                                  type: AppButtonType.follow,
                                  text: 'Message',
                                  onPressed: () async {
                                    if (isFollowing) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            friendId: widget.userId,
                                            friend: user,
                                          ),
                                        ),
                                      );
                                    } else {
                                      showTastySnackbar(
                                        'Follow Required',
                                        "You need to be friends before you can start a chat.",
                                        context,
                                        backgroundColor: Colors.redAccent,
                                      );
                                    }
                                  },
                                );
                              }),
                            ],
                          ),
                          SizedBox(
                            height: getPercentageHeight(0.5, context),
                          ),
                        ],
                      ),
                      SizedBox(height: getPercentageHeight(2, context)),
                      if (userBadges.isNotEmpty)
                        TitleSection(
                          title: badges,
                          more: seeAll,
                          press: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BadgesScreen(),
                            ),
                          ),
                        ),
                      SizedBox(height: getPercentageHeight(1, context)),

                      // Badges Slider
                      if (userBadges.isNotEmpty)
                        SizedBox(
                          height: getPercentageHeight(13, context),
                          child: ListView.builder(
                            key: ValueKey('badges_list_${widget.userId}'),
                            itemCount: userBadges.length > 5
                                ? 5
                                : userBadges.length, // Limit to 5 items
                            padding: EdgeInsets.only(
                                left: getPercentageWidth(1, context)),
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, index) {
                              if (index < userBadges.length) {
                                // Display badges for non-user
                                return StorySlider(
                                  key: ValueKey(
                                      'badge_${userBadges[index].title}_$index'),
                                  dataSrc: userBadges[index],
                                  press: () {
                                    // Handle badge click here
                                  },
                                );
                              }
                              return const SizedBox
                                  .shrink(); // Safety fallback (should not be reached)
                            },
                          ),
                        ),
                      SizedBox(height: getPercentageHeight(1, context)),
                      // Search Content Section
                      Builder(
                        builder: (context) {
                          final itemCount = showAll
                              ? searchContentDatas.length
                              : (searchContentDatas.length > 9
                                  ? 9
                                  : searchContentDatas.length);

                          return Column(
                            children: [
                              if (isLoading)
                                Container(
                                  height: getPercentageHeight(30, context),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const CircularProgressIndicator(
                                          color: kAccent,
                                          strokeWidth: 3,
                                        ),
                                        SizedBox(
                                            height: getPercentageHeight(
                                                2, context)),
                                        Text(
                                          'Loading posts...',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (searchContentDatas.isEmpty)
                                Container(
                                  height: getPercentageHeight(20, context),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.photo_library_outlined,
                                          size: getIconScale(12, context),
                                          color: Colors.grey.withOpacity(0.5),
                                        ),
                                        SizedBox(
                                            height: getPercentageHeight(
                                                1, context)),
                                        Text(
                                          "No Posts yet.",
                                          style: TextStyle(
                                            fontSize: getTextScale(4, context),
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                GridView.builder(
                                  key: ValueKey(
                                      'posts_grid_${widget.userId}_${searchContentDatas.length}'),
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing:
                                        getPercentageWidth(0.5, context),
                                    crossAxisSpacing:
                                        getPercentageWidth(0.5, context),
                                  ),
                                  padding: EdgeInsets.only(
                                      top: getPercentageHeight(1, context),
                                      bottom: getPercentageHeight(1, context)),
                                  itemCount: itemCount,
                                  itemBuilder: (BuildContext ctx, index) {
                                    final data = searchContentDatas[index];
                                    // Convert Map to Post for SearchContentPost
                                    final post =
                                        Post.fromMap(data, data['id'] ?? '');
                                    return SearchContentPost(
                                      key: ValueKey(
                                          'post_${data['id'] ?? index}'),
                                      dataSrc: post,
                                      press: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ChallengeDetailScreen(
                                              dataSrc:
                                                  data, // Use Map directly for ChallengeDetailScreen
                                              screen: 'myPost',
                                              allPosts: searchContentDatas,
                                              initialIndex: index,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              if (searchContentDatas.isNotEmpty &&
                                  searchContentDatas.length > 9)
                                GestureDetector(
                                  key: ValueKey(
                                      'show_all_toggle_${widget.userId}'),
                                  onTap: () {
                                    setState(() {
                                      showAll = !showAll;
                                    });
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical:
                                            getPercentageHeight(1, context)),
                                    child: Icon(
                                      showAll
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      size: getPercentageWidth(9, context),
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      SizedBox(height: getPercentageHeight(12, context)),
                    ],
                  ),
                ),
              ]),
        );
      }),
    );
  }
}
